import 'package:ampdent_core/ampdent_core.dart';
import 'package:drift/drift.dart';

import '../../db/app_database.dart';
import '../../db/converters.dart';
import '../actor_context.dart';
import '../billing_repository.dart';
import 'audited_writer.dart';
import 'settings_access.dart';

/// Payment, adjustment and ledger half of [BillingRepository] plus the
/// shared write helpers, mixed into `DriftBillingRepository`.
mixin DriftLedgerMethods
    on DatabaseAccessor<AppDatabase>, AuditedWriter, SettingsAccess
    implements BillingRepository {
  /// Invoices table.
  $InvoicesTable get invoicesTable => attachedDatabase.invoices;
  $PaymentsTable get _payments => attachedDatabase.payments;
  $AdjustmentsTable get _adjustments => attachedDatabase.adjustments;
  $LedgerEntriesTable get _ledger => attachedDatabase.ledgerEntries;

  /// Upserts an invoice row and audits it.
  Future<Invoice> writeInvoice(
    ActorContext ctx,
    Invoice? before,
    Invoice after, {
    AuditAction? action,
    String? reason,
  }) => audited(
    ctx: ctx,
    table: invoicesTable,
    entityType: 'Invoice',
    entityId: after.id,
    before: before,
    after: after,
    insertable: after.toInsertable(),
    toJson: (i) => i.toJson(),
    action: action,
    reason: reason,
  );

  /// Appends one ledger posting (audited) inside the current transaction.
  Future<LedgerEntry> postLedger(
    ActorContext ctx, {
    required String patientId,
    required LedgerEntryType type,
    required Money amount,
    required String referenceId,
    required String description,
    required DateTime at,
  }) {
    final entry = LedgerEntry(
      id: newId(),
      clinicId: ctx.clinicId,
      patientId: patientId,
      entryType: type,
      amount: amount,
      referenceId: referenceId,
      occurredAt: at,
      description: description,
    );
    return audited<LedgerEntry>(
      ctx: ctx,
      table: _ledger,
      entityType: 'LedgerEntry',
      entityId: entry.id,
      before: null,
      after: entry,
      insertable: entry.toInsertable(),
      toJson: (e) => e.toJson(),
    );
  }

  // ---------------------------------------------------------------------------
  // Payments and adjustments
  // ---------------------------------------------------------------------------

  @override
  Future<Payment> recordPayment(
    ActorContext ctx,
    Payment payment, {
    bool allowAdvance = false,
  }) {
    checkTenant(ctx, payment.clinicId, 'payment.clinicId');
    if (payment.amount <= const Money.zero()) {
      throw ArgumentError.value(payment.amount, 'amount', 'must be positive');
    }
    return writeTransaction(() async {
      final existing = await (select(
        _payments,
      )..where((t) => t.id.equals(payment.id))).getSingleOrNull();
      if (existing != null) {
        throw StateError('Payment ${payment.id} is append-only');
      }
      final now = payment.receivedAt.toUtc();
      final invoiceId = payment.invoiceId;
      final invoice = invoiceId == null ? null : await getInvoice(invoiceId);
      if (invoiceId != null) {
        if (invoice == null) throw StateError('Invoice $invoiceId not found');
        _validateAgainstInvoice(payment, invoice, allowAdvance: allowAdvance);
      } else if (payment.isRefund) {
        final credit = -(await patientBalance(payment.patientId));
        if (payment.amount > credit) {
          throw ArgumentError.value(
            payment.amount,
            'amount',
            'refund exceeds the credit on account (${credit.format()})',
          );
        }
      }
      final saved = await audited<Payment>(
        ctx: ctx,
        table: _payments,
        entityType: 'Payment',
        entityId: payment.id,
        before: null,
        after: payment,
        insertable: payment.toInsertable(),
        toJson: (p) => p.toJson(),
      );
      await postLedger(
        ctx,
        patientId: payment.patientId,
        type: payment.isRefund
            ? LedgerEntryType.refund
            : LedgerEntryType.payment,
        amount: payment.isRefund ? payment.amount : -payment.amount,
        referenceId: payment.id,
        description:
            '${payment.isRefund ? 'Refund' : 'Payment'} '
            '(${payment.method.name})'
            '${payment.reference == null ? '' : ' ${payment.reference}'}',
        at: now,
      );
      if (invoice != null) {
        final paid = payment.isRefund
            ? invoice.amountPaid - payment.amount
            : invoice.amountPaid + payment.amount;
        final status = paid >= invoice.grandTotal
            ? InvoiceStatus.paid
            : paid > const Money.zero()
            ? InvoiceStatus.partiallyPaid
            : InvoiceStatus.issued;
        await writeInvoice(
          ctx,
          invoice,
          invoice.copyWith(amountPaid: paid, status: status, updatedAt: now),
          action: AuditAction.statusChange,
        );
      }
      return saved;
    });
  }

  /// Rejects a payment that does not fit [invoice]: another patient's
  /// invoice, a draft or voided invoice, an overpayment without the advance
  /// flag, or a refund larger than what was paid.
  void _validateAgainstInvoice(
    Payment payment,
    Invoice invoice, {
    required bool allowAdvance,
  }) {
    if (invoice.patientId != payment.patientId) {
      throw ArgumentError.value(
        payment.patientId,
        'patientId',
        'invoice ${invoice.number} belongs to another patient',
      );
    }
    if (invoice.status == InvoiceStatus.draft ||
        invoice.status == InvoiceStatus.voided) {
      throw StateError(
        'Cannot apply a payment to a ${invoice.status.name} invoice',
      );
    }
    if (payment.isRefund) {
      if (payment.amount > invoice.amountPaid) {
        throw ArgumentError.value(
          payment.amount,
          'amount',
          'refund exceeds the amount paid (${invoice.amountPaid.format()})',
        );
      }
    } else if (!allowAdvance && payment.amount > invoice.balance) {
      throw ArgumentError.value(
        payment.amount,
        'amount',
        'exceeds the invoice balance (${invoice.balance.format()}); '
            'record the excess as an advance',
      );
    }
  }

  @override
  Future<List<Payment>> paymentsForPatient(String patientId) =>
      (select(_payments)
            ..where((t) => t.patientId.equals(patientId))
            ..orderBy([(t) => OrderingTerm.desc(t.receivedAt)]))
          .get();

  @override
  Future<List<Payment>> paymentsForClinic(
    String clinicId, {
    DateTime? from,
    DateTime? to,
  }) =>
      (select(_payments)
            ..where((t) {
              var where = t.clinicId.equals(clinicId);
              if (from != null) {
                where =
                    where &
                    t.receivedAt.isBiggerOrEqualValue(encodeIsoUtc(from));
              }
              if (to != null) {
                where =
                    where & t.receivedAt.isSmallerThanValue(encodeIsoUtc(to));
              }
              return where;
            })
            ..orderBy([(t) => OrderingTerm.desc(t.receivedAt)]))
          .get();

  @override
  Future<List<Payment>> paymentsForInvoice(String invoiceId) =>
      (select(_payments)
            ..where((t) => t.invoiceId.equals(invoiceId))
            ..orderBy([(t) => OrderingTerm.asc(t.receivedAt)]))
          .get();

  @override
  Future<Adjustment> recordAdjustment(ActorContext ctx, Adjustment adjustment) {
    checkTenant(ctx, adjustment.clinicId, 'adjustment.clinicId');
    if (adjustment.reason.trim().isEmpty) {
      throw ArgumentError.value(adjustment.reason, 'reason', 'required');
    }
    return writeTransaction(() async {
      final existing = await (select(
        _adjustments,
      )..where((t) => t.id.equals(adjustment.id))).getSingleOrNull();
      if (existing != null) {
        throw StateError('Adjustment ${adjustment.id} is append-only');
      }
      final now = adjustment.createdAt.toUtc();
      final saved = await audited<Adjustment>(
        ctx: ctx,
        table: _adjustments,
        entityType: 'Adjustment',
        entityId: adjustment.id,
        before: null,
        after: adjustment,
        insertable: adjustment.toInsertable(),
        toJson: (a) => a.toJson(),
      );
      final Money? posted = switch (adjustment.type) {
        AdjustmentType.discount ||
        AdjustmentType.writeOff => -adjustment.amount,
        AdjustmentType.refund => adjustment.amount,
        AdjustmentType.correction => adjustment.amount,
        AdjustmentType.specialistShare => null,
      };
      if (posted != null) {
        await postLedger(
          ctx,
          patientId: adjustment.patientId,
          type: adjustment.type == AdjustmentType.refund
              ? LedgerEntryType.refund
              : LedgerEntryType.adjustment,
          amount: posted,
          referenceId: adjustment.id,
          description: '${adjustment.type.name}: ${adjustment.reason}',
          at: now,
        );
      }
      return saved;
    });
  }

  @override
  Future<List<Adjustment>> adjustmentsForPatient(String patientId) =>
      (select(_adjustments)
            ..where((t) => t.patientId.equals(patientId))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  // ---------------------------------------------------------------------------
  // Ledger and aging
  // ---------------------------------------------------------------------------

  SimpleSelectStatement<$LedgerEntriesTable, LedgerEntry> _ledgerQuery(
    String patientId,
  ) => select(_ledger)
    ..where((t) => t.patientId.equals(patientId))
    ..orderBy([(t) => OrderingTerm.asc(t.occurredAt)]);

  @override
  Future<List<LedgerEntry>> ledger(String patientId) =>
      _ledgerQuery(patientId).get();

  @override
  Stream<List<LedgerEntry>> watchLedger(String patientId) =>
      _ledgerQuery(patientId).watch();

  @override
  Future<Money> patientBalance(String patientId) async =>
      ledgerBalance(await ledger(patientId));

  @override
  Stream<Money> watchPatientBalance(String patientId) =>
      watchLedger(patientId).map(ledgerBalance);

  @override
  Future<Map<String, Money>> aging(String clinicId, {DateTime? asOf}) async =>
      agingBuckets(await outstandingInvoices(clinicId), nowUtc(asOf));
}
