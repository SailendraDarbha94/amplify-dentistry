import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_data/ampdent_data.dart';
import 'package:ampdent_messaging/ampdent_messaging.dart';

import 'payment_form_model.dart';

/// Base of the authenticated document links placed in WhatsApp messages. The
/// server mints the signed link on sync; until then the local id-based path
/// is used so the message body never carries clinical or billing detail.
const String documentLinkBase = 'https://ampdent.in/d';

/// Link for an invoice document.
String invoiceLinkUrl(Invoice invoice) =>
    '$documentLinkBase/invoice/${invoice.id}';

/// `INVOICE_LINK` request for an issued invoice, routed to the patient's
/// messaging phone (the guardian for a minor).
MessageRequest invoiceLinkRequest({
  required Clinic clinic,
  required Patient patient,
  required Invoice invoice,
  required DateTime now,
}) => MessageRequest(
  clinicId: clinic.id,
  patientId: patient.id,
  toPhone: patient.messagingPhone(now),
  template: templateByCode('INVOICE_LINK')!,
  variables: {
    'patient_name': patient.displayName,
    'document_number': invoice.number,
    'clinic_name': clinic.name,
    'amount': invoice.grandTotal.format(),
    'link': invoiceLinkUrl(invoice),
    'clinic_phone': clinic.whatsappPhone ?? clinic.phone,
  },
);

/// `RECEIPT_LINK` request after a payment against [invoice].
MessageRequest receiptLinkRequest({
  required Clinic clinic,
  required Patient patient,
  required Invoice invoice,
  required Payment payment,
  required DateTime now,
}) => MessageRequest(
  clinicId: clinic.id,
  patientId: patient.id,
  toPhone: patient.messagingPhone(now),
  template: templateByCode('RECEIPT_LINK')!,
  variables: {
    'patient_name': patient.displayName,
    'clinic_name': clinic.name,
    'amount': payment.amount.format(),
    'payment_date': _dateLabel(payment.receivedAt),
    'document_number': invoice.number,
    'link': invoiceLinkUrl(invoice),
  },
);

/// Picks the receipt template once the invoice is settled, the invoice link
/// otherwise.
MessageRequest documentLinkRequest({
  required Clinic clinic,
  required Patient patient,
  required Invoice invoice,
  Payment? lastPayment,
  required DateTime now,
}) => invoice.status == InvoiceStatus.paid && lastPayment != null
    ? receiptLinkRequest(
        clinic: clinic,
        patient: patient,
        invoice: invoice,
        payment: lastPayment,
        now: now,
      )
    : invoiceLinkRequest(
        clinic: clinic,
        patient: patient,
        invoice: invoice,
        now: now,
      );

String _dateLabel(DateTime value) {
  final d = value.toLocal();
  return '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';
}

/// Issues and voids invoices through the [BillingRepository]. Issuing saves
/// and issues the draft in one repository transaction (minting the `DRAFT-`
/// number, resolving GST rates from the clinic table at issue time, posting
/// the ledger charge and the audit/outbox rows), so a failure can never leave
/// a stranded draft whose procedures disappear from billing.
class InvoiceIssuer {
  /// Creates the issuer.
  const InvoiceIssuer({required this.billing, required this.ctx});

  /// Repository.
  final BillingRepository billing;

  /// Actor for the writes.
  final ActorContext ctx;

  /// Saves [draft] and issues it. Throws [StateError] when it has no lines.
  Future<Invoice> issue(
    Invoice draft, {
    GstRateTable? rates,
    DateTime? at,
  }) async {
    if (draft.lines.isEmpty) throw StateError('An invoice needs a line');
    return billing.issueDraft(ctx, draft, rates: rates, at: at);
  }

  /// Voids [invoiceId]; [reason] must not be blank.
  Future<Invoice> voidInvoice(
    String invoiceId, {
    required String reason,
    DateTime? at,
  }) async {
    final error = PaymentValidators.reason(reason);
    if (error != null) throw ArgumentError.value(reason, 'reason', error);
    return billing.voidInvoice(ctx, invoiceId, reason: reason.trim(), at: at);
  }
}
