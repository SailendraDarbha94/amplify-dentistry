import 'package:ampdent_core/ampdent_core.dart';
import 'package:drift/drift.dart';

import '../../db/app_database.dart';
import '../../db/converters.dart';
import '../actor_context.dart';
import '../billing_repository.dart';
import 'audited_writer.dart';
import 'drift_ledger_methods.dart';
import 'settings_access.dart';

/// Drift implementation of [BillingRepository]. Ledger postings are written
/// inside the same transaction as the invoice issue, payment or adjustment.
class DriftBillingRepository extends DatabaseAccessor<AppDatabase>
    with AuditedWriter, SettingsAccess, DriftLedgerMethods
    implements BillingRepository {
  /// Creates the repository over [db].
  DriftBillingRepository(super.db);

  // ----------------------------------------------------------------------------
  // Invoices
  // ---------------------------------------------------------------------------

  @override
  Future<Invoice> saveDraft(ActorContext ctx, Invoice invoice) {
    checkTenant(ctx, invoice.clinicId, 'invoice.clinicId');
    return writeTransaction(() async {
      final before = await getInvoice(invoice.id);
      if (before != null && before.status != InvoiceStatus.draft) {
        throw StateError('Invoice ${invoice.id} is ${before.status.name}');
      }
      final number = invoice.number.isEmpty
          ? await mintLocalDraftNumber(ctx, 'INV')
          : invoice.number;
      final after = computeInvoiceTotals(
        invoice.copyWith(number: number, status: InvoiceStatus.draft),
      );
      return writeInvoice(ctx, before, after);
    });
  }

  @override
  Future<Invoice> issueDraft(
    ActorContext ctx,
    Invoice draft, {
    GstRateTable? rates,
    DateTime? at,
  }) => writeTransaction(() async {
    // Nested transactions join this one, so the draft row, the issued row,
    // the ledger charge and every audit/outbox row commit together or not
    // at all.
    final saved = await saveDraft(ctx, draft);
    return issueInvoice(ctx, saved.id, rates: rates, at: at);
  });

  @override
  Future<Invoice> issueInvoice(
    ActorContext ctx,
    String invoiceId, {
    GstRateTable? rates,
    DateTime? at,
  }) => writeTransaction(() async {
    final before = await getInvoice(invoiceId);
    if (before == null) throw StateError('Invoice $invoiceId not found');
    checkTenant(ctx, before.clinicId, 'invoice.clinicId');
    if (before.status != InvoiceStatus.draft) {
      throw StateError('Invoice $invoiceId is already ${before.status.name}');
    }
    await _ensureStagesUnbilled(before);
    final now = nowUtc(at);
    final table = rates ?? await loadGstRateTable(before.clinicId);
    final clinic = await (select(
      attachedDatabase.clinics,
    )..where((t) => t.id.equals(before.clinicId))).getSingleOrNull();
    final lines = [
      for (final l in before.lines)
        l.copyWith(
          taxRatePercent: table.rateFor(l.gstClass, at: now).ratePercent,
        ),
    ];
    final number = before.number.isEmpty
        ? await mintLocalDraftNumber(ctx, 'INV', now: now)
        : before.number;
    final dentist = await _treatingDentist(before);
    if (dentist == null) throw const NoRegisteredClinician();
    final issued = computeInvoiceTotals(
      before
          .copyWith(
            number: number,
            lines: lines,
            documentType: suggestDocumentType(
              clinicGstRegistered: clinic?.isGstRegistered ?? false,
              lineClasses: lines.map((l) => l.gstClass),
            ),
            status: InvoiceStatus.issued,
            issuedAt: now,
            updatedAt: now,
          )
          .withDentist(dentist),
    );
    final saved = await writeInvoice(
      ctx,
      before,
      issued,
      action: AuditAction.statusChange,
    );
    await postLedger(
      ctx,
      patientId: issued.patientId,
      type: LedgerEntryType.charge,
      amount: issued.grandTotal,
      referenceId: issued.id,
      description: 'Invoice ${issued.number}',
      at: now,
    );
    return saved;
  });

  /// Throws [StateError] when a line of [invoice] bills a procedure (or a
  /// stage of one) that another non-void invoice of the patient already
  /// carries. A line without a stage bills the whole procedure, so it
  /// collides with any line of that procedure and vice versa.
  Future<void> _ensureStagesUnbilled(Invoice invoice) async {
    final procedureIds = {
      for (final l in invoice.lines)
        if (l.procedureId != null) l.procedureId!,
    };
    if (procedureIds.isEmpty) return;
    final others =
        await (select(invoicesTable)..where(
              (t) =>
                  t.patientId.equals(invoice.patientId) &
                  t.id.equals(invoice.id).not() &
                  t.status.equalsValue(InvoiceStatus.voided).not(),
            ))
            .get();
    for (final other in others) {
      for (final billed in other.lines) {
        final id = billed.procedureId;
        if (id == null || !procedureIds.contains(id)) continue;
        for (final l in invoice.lines) {
          if (l.procedureId != id) continue;
          final collides =
              l.stageIndex == null ||
              billed.stageIndex == null ||
              l.stageIndex == billed.stageIndex;
          if (collides) {
            throw StateError(
              'Procedure $id'
              '${l.stageIndex == null ? '' : ' stage ${l.stageIndex! + 1}'}'
              ' is already billed on ${other.number}',
            );
          }
        }
      }
    }
  }

  /// The clinician named on an invoice: the provider of the billed
  /// procedures (first line first), else the clinic's owner dentist; only a
  /// clinician with a registration number qualifies. Null when none does.
  Future<ClinicMember?> _treatingDentist(Invoice invoice) async {
    final candidateIds = <String>[];
    for (final line in invoice.lines) {
      final procedureId = line.procedureId;
      if (procedureId == null) continue;
      final procedure = await (select(
        attachedDatabase.procedures,
      )..where((t) => t.id.equals(procedureId))).getSingleOrNull();
      if (procedure != null && !candidateIds.contains(procedure.providerId)) {
        candidateIds.add(procedure.providerId);
      }
    }
    final members = attachedDatabase.clinicMembers;
    for (final id in candidateIds) {
      final member = await (select(
        members,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (member != null && _isRegisteredClinician(member)) return member;
    }
    final owners =
        await (select(members)
              ..where(
                (t) =>
                    t.clinicId.equals(invoice.clinicId) &
                    t.role.equalsValue(ClinicRole.ownerDentist) &
                    t.isActive.equals(true),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
            .get();
    for (final owner in owners) {
      if (_isRegisteredClinician(owner)) return owner;
    }
    return null;
  }

  static bool _isRegisteredClinician(ClinicMember m) =>
      m.isClinician && (m.registrationNumber ?? '').trim().isNotEmpty;

  @override
  Future<Invoice> applyServerNumber(
    ActorContext ctx,
    String invoiceId,
    String number, {
    DateTime? at,
  }) => writeTransaction(() async {
    final minted = number.trim();
    if (minted.isEmpty || isDraftNumber(minted)) {
      throw ArgumentError.value(number, 'number', 'must be a minted number');
    }
    final before = await getInvoice(invoiceId);
    if (before == null) throw StateError('Invoice $invoiceId not found');
    checkTenant(ctx, before.clinicId, 'invoice.clinicId');
    if (before.status == InvoiceStatus.draft) {
      throw StateError('Invoice $invoiceId is still a draft');
    }
    if (before.number == minted) return before;
    if (!before.isDraftNumber) {
      throw StateError(
        'Invoice $invoiceId already carries number ${before.number}',
      );
    }
    return writeInvoice(
      ctx,
      before,
      before.copyWith(number: minted, updatedAt: nowUtc(at)),
      action: AuditAction.statusChange,
      reason: 'Server minted invoice number $minted for ${before.number}',
    );
  });

  @override
  Future<Invoice> voidInvoice(
    ActorContext ctx,
    String invoiceId, {
    required String reason,
    DateTime? at,
  }) {
    if (reason.trim().isEmpty) {
      throw ArgumentError.value(reason, 'reason', 'required to void');
    }
    return writeTransaction(() async {
      final before = await getInvoice(invoiceId);
      if (before == null) throw StateError('Invoice $invoiceId not found');
      checkTenant(ctx, before.clinicId, 'invoice.clinicId');
      if (before.status == InvoiceStatus.voided) {
        throw StateError('Invoice $invoiceId is already voided');
      }
      final now = nowUtc(at);
      final wasPosted = before.status != InvoiceStatus.draft;
      final after = before.copyWith(
        status: InvoiceStatus.voided,
        voidReason: reason,
        updatedAt: now,
      );
      final saved = await writeInvoice(
        ctx,
        before,
        after,
        action: AuditAction.statusChange,
        reason: reason,
      );
      if (wasPosted) {
        await postLedger(
          ctx,
          patientId: before.patientId,
          type: LedgerEntryType.adjustment,
          amount: -before.grandTotal,
          referenceId: before.id,
          description: 'Void ${before.number}: $reason',
          at: now,
        );
      }
      return saved;
    });
  }

  @override
  Future<Invoice?> getInvoice(String id) =>
      (select(invoicesTable)..where((t) => t.id.equals(id))).getSingleOrNull();

  SimpleSelectStatement<$InvoicesTable, Invoice> _forPatient(
    String patientId,
  ) => select(invoicesTable)
    ..where((t) => t.patientId.equals(patientId))
    ..orderBy([(t) => OrderingTerm.desc(t.issuedAt)]);

  @override
  Future<List<Invoice>> invoicesForPatient(String patientId) =>
      _forPatient(patientId).get();

  @override
  Stream<List<Invoice>> watchInvoices(String patientId) =>
      _forPatient(patientId).watch();

  @override
  Future<List<Invoice>> invoicesForClinic(
    String clinicId, {
    DateTime? from,
    DateTime? to,
  }) =>
      (select(invoicesTable)
            ..where((t) {
              var where = t.clinicId.equals(clinicId);
              if (from != null) {
                where =
                    where & t.issuedAt.isBiggerOrEqualValue(encodeIsoUtc(from));
              }
              if (to != null) {
                where = where & t.issuedAt.isSmallerThanValue(encodeIsoUtc(to));
              }
              return where;
            })
            ..orderBy([(t) => OrderingTerm.desc(t.issuedAt)]))
          .get();

  @override
  Future<List<Invoice>> outstandingInvoices(String clinicId) =>
      (select(invoicesTable)
            ..where(
              (t) =>
                  t.clinicId.equals(clinicId) &
                  t.status.isInValues(const [
                    InvoiceStatus.issued,
                    InvoiceStatus.partiallyPaid,
                  ]),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.issuedAt)]))
          .get();
}
