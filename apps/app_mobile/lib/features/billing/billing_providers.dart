import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_data/ampdent_data.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'billing_reports.dart';
import 'invoice_draft.dart';

/// Identifies one invoice of one patient (route parameters).
typedef InvoiceRef = ({String patientId, String invoiceId});

/// The patient being billed (null when not found).
final billingPatientProvider = StreamProvider.family<Patient?, String>(
  (ref, patientId) => ref.watch(patientRepositoryProvider).watchById(patientId),
);

/// Live invoices of a patient, newest first.
final billingInvoicesProvider = StreamProvider.family<List<Invoice>, String>(
  (ref, patientId) =>
      ref.watch(billingRepositoryProvider).watchInvoices(patientId),
);

/// One invoice, live.
final invoiceProvider = StreamProvider.family<Invoice?, InvoiceRef>(
  (ref, key) => ref
      .watch(billingRepositoryProvider)
      .watchInvoices(key.patientId)
      .map((list) => list.where((i) => i.id == key.invoiceId).firstOrNull),
);

/// Live ledger of a patient, oldest first.
final patientLedgerProvider = StreamProvider.family<List<LedgerEntry>, String>(
  (ref, patientId) =>
      ref.watch(billingRepositoryProvider).watchLedger(patientId),
);

/// Live balance of a patient (positive = owes).
final billingBalanceProvider = StreamProvider.family<Money, String>(
  (ref, patientId) =>
      ref.watch(billingRepositoryProvider).watchPatientBalance(patientId),
);

/// Payments of a patient, newest first; refreshed whenever the ledger moves.
final patientPaymentsProvider = FutureProvider.family<List<Payment>, String>((
  ref,
  patientId,
) {
  ref.watch(patientLedgerProvider(patientId));
  return ref.watch(billingRepositoryProvider).paymentsForPatient(patientId);
});

/// Payments applied to one invoice, oldest first; refreshed with the ledger.
final invoicePaymentsProvider =
    FutureProvider.family<List<Payment>, InvoiceRef>((ref, key) {
      ref.watch(patientLedgerProvider(key.patientId));
      return ref
          .watch(billingRepositoryProvider)
          .paymentsForInvoice(key.invoiceId);
    });

/// Catalogue items of the clinic (global seed merged with overrides) keyed
/// by id, so a procedure's `catalogItemId` resolves to its GST class.
final FutureProvider<Map<String, CatalogItem>> catalogByIdProvider =
    FutureProvider<Map<String, CatalogItem>>((ref) async {
      final clinicId = ref.watch(currentClinicIdProvider);
      final repo = ref.watch(catalogRepositoryProvider);
      final items = <String, CatalogItem>{};
      for (final item in await repo.globalItems()) {
        items[item.id] = item;
      }
      if (clinicId != null) {
        for (final item in await repo.itemsForClinic(clinicId)) {
          items[item.id] = item;
        }
      }
      return items;
    });

/// The clinic's GST rate table, live from settings; India defaults until a
/// clinic has saved its own.
final StreamProvider<GstRateTable> gstRateTableProvider =
    StreamProvider<GstRateTable>((ref) {
      final clinicId = ref.watch(currentClinicIdProvider);
      if (clinicId == null) return Stream.value(GstRateTable.indiaDefaults());
      return ref
          .watch(clinicRepositoryProvider)
          .watchSetting(clinicId, SettingKeys.gstRates)
          .map((json) {
            final rates = json == null
                ? const <GstRate>[]
                : gstRatesFromJson(json);
            return rates.isEmpty
                ? GstRateTable.indiaDefaults()
                : GstRateTable(rates);
          });
    });

/// Billable procedures (completed or in progress) of a patient that are not
/// yet on a non-void invoice. Waits for the invoice list before emitting so a
/// new invoice never preselects already billed work.
final billableProceduresProvider =
    StreamProvider.family<List<ProcedureRecord>, String>((ref, patientId) {
      final invoices = ref.watch(billingInvoicesProvider(patientId));
      if (invoices.isLoading && !invoices.hasValue) {
        return const Stream<List<ProcedureRecord>>.empty();
      }
      final billed = billedProcedureIds(invoices.value ?? const []);
      return ref
          .watch(chartRepositoryProvider)
          .watchProceduresForPatient(patientId)
          .map(
            (list) => [
              for (final p in list)
                if (p.status.isBillable && !billed.contains(p.id)) p,
            ],
          );
    });

/// Patients sharing a guardian phone with [patientId] (the patient first).
final familyMembersProvider = StreamProvider.family<List<Patient>, String>((
  ref,
  patientId,
) {
  final clinicId = ref.watch(currentClinicIdProvider);
  final self = ref.watch(billingPatientProvider(patientId)).value;
  if (clinicId == null || self == null) return Stream.value(const []);
  return ref
      .watch(patientRepositoryProvider)
      .watchAll(clinicId, includeInactive: true)
      .map((all) => familyMembers(self, all));
});

/// One ledger entry together with the patient it belongs to.
typedef FamilyLedgerEntry = ({Patient patient, LedgerEntry entry});

/// Ledger across the whole family, oldest first; refreshed when this
/// patient's ledger moves.
final familyLedgerProvider =
    FutureProvider.family<List<FamilyLedgerEntry>, String>((
      ref,
      patientId,
    ) async {
      ref.watch(patientLedgerProvider(patientId));
      final members = ref.watch(familyMembersProvider(patientId)).value ?? [];
      final billing = ref.watch(billingRepositoryProvider);
      final out = <FamilyLedgerEntry>[];
      for (final m in members) {
        for (final e in await billing.ledger(m.id)) {
          out.add((patient: m, entry: e));
        }
      }
      out.sort((a, b) => a.entry.occurredAt.compareTo(b.entry.occurredAt));
      return out;
    });

/// Clinic-wide month-to-date report. Keyed by the patient whose billing page
/// shows it so it refreshes when that patient's ledger moves.
final billingReportProvider = FutureProvider.family<BillingReport, String>((
  ref,
  patientId,
) async {
  ref.watch(patientLedgerProvider(patientId));
  final month = monthOf(ref.watch(clockProvider)());
  final clinicId = ref.watch(currentClinicIdProvider);
  if (clinicId == null) return BillingReport(month: month);
  final patients = await ref
      .watch(patientRepositoryProvider)
      .watchAll(clinicId, includeInactive: true)
      .first;
  final billing = ref.watch(billingRepositoryProvider);
  final chart = ref.watch(chartRepositoryProvider);
  final payments = <Payment>[];
  final procedures = <ProcedureRecord>[];
  final invoices = <Invoice>[];
  for (final p in patients) {
    payments.addAll(await billing.paymentsForPatient(p.id));
    procedures.addAll(
      await chart.proceduresForPatient(
        p.id,
        statuses: const [ProcedureStatus.completed],
      ),
    );
    invoices.addAll(await billing.invoicesForPatient(p.id));
  }
  return computeBillingReport(
    month: month,
    payments: payments,
    procedures: procedures,
    invoices: invoices,
  );
});
