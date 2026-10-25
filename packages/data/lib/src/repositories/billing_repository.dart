import 'package:ampdent_core/ampdent_core.dart';

import 'actor_context.dart';

/// Thrown by [BillingRepository.issueInvoice] when no registered clinician
/// can be named on the document: neither the billed procedures' providers
/// nor the clinic's owner dentist is a clinician with a council registration
/// number (DCI Code 3.4.1 requires it on every receipt).
class NoRegisteredClinician implements Exception {
  /// Creates the error.
  const NoRegisteredClinician();

  @override
  String toString() =>
      'No registered dentist to name on the invoice. Record the registration '
      'number of the treating dentist in Settings > Members first.';
}

/// Invoices, payments, adjustments and the patient ledger. Ledger postings
/// are written in the same transaction as the invoice issue, payment or
/// adjustment they mirror.
abstract class BillingRepository {
  /// Saves a draft invoice (status `draft`, totals recomputed). An empty
  /// `number` gets a minted `DRAFT-` number. Throws [StateError] when the
  /// stored invoice is no longer a draft.
  Future<Invoice> saveDraft(ActorContext ctx, Invoice invoice);

  /// Issues a draft: resolves tax rates per line from the clinic's GST rate
  /// table (or [rates]), recomputes totals, picks the document type from
  /// the clinic's GST registration, freezes the treating dentist on the row
  /// (the billed procedures' provider, else the clinic's owner dentist;
  /// throws [NoRegisteredClinician] when neither has a registration number)
  /// and posts the charge to the ledger. Throws [StateError] when a line
  /// bills a procedure stage that a non-void invoice already carries.
  Future<Invoice> issueInvoice(
    ActorContext ctx,
    String invoiceId, {
    GstRateTable? rates,
    DateTime? at,
  });

  /// Saves [draft] and issues it in one transaction: the invoice row, the
  /// procedure stages it marks billed (its lines), the ledger charge and the
  /// audit/outbox rows are all written or none are, so a failure can never
  /// strand a `DRAFT-` invoice whose procedures vanish from billing. Same
  /// rules and errors as [saveDraft] followed by [issueInvoice].
  Future<Invoice> issueDraft(
    ActorContext ctx,
    Invoice draft, {
    GstRateTable? rates,
    DateTime? at,
  });

  /// Writes the server-minted [number] over a `DRAFT-` number once the
  /// first sync has assigned it, audited as a status change, so later local
  /// writes replay the real number and the printed receipt matches the
  /// server. Throws [ArgumentError] for a `DRAFT-` [number], [StateError]
  /// for a draft invoice or when a different number is already minted; a
  /// repeat of the same number is a no-op.
  Future<Invoice> applyServerNumber(
    ActorContext ctx,
    String invoiceId,
    String number, {
    DateTime? at,
  });

  /// Voids an issued invoice. [reason] is required (ArgumentError when
  /// empty); a reversing ledger adjustment is posted.
  Future<Invoice> voidInvoice(
    ActorContext ctx,
    String invoiceId, {
    required String reason,
    DateTime? at,
  });

  /// Invoice by id.
  Future<Invoice?> getInvoice(String id);

  /// A patient's invoices, newest first.
  Future<List<Invoice>> invoicesForPatient(String patientId);

  /// Stream of a patient's invoices, newest first.
  Stream<List<Invoice>> watchInvoices(String patientId);

  /// Issued or partially paid invoices of the clinic.
  Future<List<Invoice>> outstandingInvoices(String clinicId);

  /// Invoices of the whole clinic issued in `[from, to)` (both optional),
  /// newest first; drafts included so a month report can skip them itself.
  Future<List<Invoice>> invoicesForClinic(
    String clinicId, {
    DateTime? from,
    DateTime? to,
  });

  /// Payments (and refunds) of the whole clinic received in `[from, to)`,
  /// newest first.
  Future<List<Payment>> paymentsForClinic(
    String clinicId, {
    DateTime? from,
    DateTime? to,
  });

  /// Records a payment (or refund when `isRefund`), posts it to the ledger
  /// and, when linked to an invoice, updates `amountPaid` and the status
  /// (`partiallyPaid` / `paid`).
  ///
  /// Validation ([ArgumentError]): the amount must be positive; a payment
  /// linked to an invoice must carry that invoice's patient and may not
  /// exceed its balance unless [allowAdvance] is set (the excess then stays
  /// as credit on the ledger); an unlinked payment is an advance and needs
  /// no flag; a refund may not exceed the invoice's `amountPaid` (or, when
  /// unlinked, the patient's credit on account).
  Future<Payment> recordPayment(
    ActorContext ctx,
    Payment payment, {
    bool allowAdvance = false,
  });

  /// Payments for a patient, newest first.
  Future<List<Payment>> paymentsForPatient(String patientId);

  /// Payments applied to an invoice.
  Future<List<Payment>> paymentsForInvoice(String invoiceId);

  /// Records an adjustment and posts it to the ledger (discounts and
  /// write-offs as credits, refunds as debits, corrections as given;
  /// specialist shares are stored but not posted to the patient ledger).
  Future<Adjustment> recordAdjustment(ActorContext ctx, Adjustment adjustment);

  /// Adjustments for a patient, newest first.
  Future<List<Adjustment>> adjustmentsForPatient(String patientId);

  /// Ledger postings for a patient, oldest first.
  Future<List<LedgerEntry>> ledger(String patientId);

  /// Stream of a patient's ledger, oldest first.
  Stream<List<LedgerEntry>> watchLedger(String patientId);

  /// Patient balance (positive = owes).
  Future<Money> patientBalance(String patientId);

  /// Stream of the patient balance.
  Stream<Money> watchPatientBalance(String patientId);

  /// Outstanding balances bucketed by age (`agingBucketKeys`).
  Future<Map<String, Money>> aging(String clinicId, {DateTime? asOf});
}
