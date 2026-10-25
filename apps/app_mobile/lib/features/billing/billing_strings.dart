import 'package:ampdent_core/ampdent_core.dart';

/// Billing labels that are not in the shared [AppStrings] table yet. Kept
/// as one English map so a translation hook can replace it.
abstract final class BillingStrings {
  /// Page title.
  static const String billing = 'Billing';

  /// Header label above the hero balance.
  static const String outstandingBalance = 'Outstanding balance';

  /// Patient has credit on account.
  static const String creditOnAccount = 'Credit on account';

  /// Tab labels.
  static const String invoices = 'Invoices';
  static const String reports = 'Reports';

  /// Buttons.
  static const String newInvoice = 'New invoice';
  static const String recordPayment = 'Record payment';
  static const String issue = 'Issue invoice';
  static const String refund = 'Refund';
  static const String voidInvoice = 'Void invoice';
  static const String previewPdf = 'Preview / print PDF';
  static const String sendLink = 'Send on WhatsApp';
  static const String openUpiApp = 'Open UPI app';
  static const String familyView = 'Family view';
  static const String familyViewHint =
      'Ledger across patients sharing this guardian phone (read-only)';

  /// Empty states.
  static const String noInvoices = 'No invoices yet';
  static const String noLedgerEntries = 'No ledger entries yet';
  static const String noBillableProcedures = 'Nothing to bill';
  static const String noBillableProceduresHint =
      'Completed procedures that are not on an invoice appear here.';

  /// New invoice page.
  static const String linesTitle = 'Lines';
  static const String totalsTitle = 'Totals';
  static const String subtotal = 'Subtotal';
  static const String taxable = 'Taxable value';
  static const String grandTotal = 'Grand total';
  static const String documentType = 'Document';
  static const String sacHsn = 'SAC/HSN';
  static const String gstClass = 'GST class';
  static const String gstClassOverridden =
      'Differs from the catalogue. Check before issuing.';
  static const String discountTooLarge = 'Discount exceeds the line amount';
  static const String selectAtLeastOneLine = 'Select at least one line';
  static const String noRegisteredClinician =
      'No registered dentist to name on the invoice. Record the treating '
      'dentist\'s registration number in Settings > Members first.';

  /// Payment sheet.
  static const String method = 'Method';
  static const String reference = 'Reference (UTR / cheque no.)';
  static const String cardLast4 = 'Card last 4 digits';
  static const String cardBrand = 'Card network';
  static const String cardLast4Hint = 'Only the last four digits are stored.';
  static const String neverFullCard =
      'Enter only the last 4 digits, never the full card number';
  static const String payTo = 'Pay to';
  static const String upiNotConfigured =
      'No UPI ID in clinic settings. Add one under Settings > Clinic.';
  static const String amountRequired = 'Enter an amount';
  static const String amountExceedsBalance = 'Exceeds the outstanding balance';
  static const String amountExceedsPaid = 'Exceeds the amount paid';
  static const String reasonRequired = 'A reason is required';
  static const String refundReason = 'Reason for refund';
  static const String voidReason = 'Reason for voiding';
  static const String voidWarning =
      'Voiding reverses the charge on the ledger. The invoice stays on '
      'record with its reason.';
  static const String paymentRecorded = 'Payment recorded';
  static const String refundRecorded = 'Refund recorded';
  static const String invoiceIssued = 'Invoice issued';
  static const String invoiceVoided = 'Invoice voided';
  static const String linkQueued = 'Message queued in the log';
  static const String couldNotOpenApp = 'Could not open the app';

  /// Reports tab.
  static const String thisMonth = 'This month (clinic)';
  static const String collections = 'Collections';
  static const String production = 'Production';
  static const String outstanding = 'Outstanding';
  static const String refunds = 'Refunds';
  static const String invoicesIssued = 'Invoices issued';
  static const String byMethod = 'Collections by method';
  static const String aging = 'Aging';

  /// Labels for [InvoiceDocumentType].
  static String documentTypeLabel(InvoiceDocumentType type) => switch (type) {
    InvoiceDocumentType.receipt => 'Receipt',
    InvoiceDocumentType.taxInvoice => 'Tax invoice',
    InvoiceDocumentType.invoiceCumBillOfSupply => 'Invoice-cum-bill of supply',
    InvoiceDocumentType.billOfSupply => 'Bill of supply',
  };

  /// Labels for [InvoiceStatus].
  static String invoiceStatusLabel(InvoiceStatus status) => switch (status) {
    InvoiceStatus.draft => 'Draft',
    InvoiceStatus.issued => 'Issued',
    InvoiceStatus.partiallyPaid => 'Partly paid',
    InvoiceStatus.paid => 'Paid',
    InvoiceStatus.voided => 'Void',
  };

  /// Short labels for [GstClass].
  static String gstClassLabel(GstClass gstClass) => switch (gstClass) {
    GstClass.exemptHealthcare => 'Exempt',
    GstClass.cosmeticTaxable => 'Cosmetic',
    GstClass.goods => 'Goods',
    GstClass.standardTaxable => 'Standard',
  };

  /// Labels for [PaymentMethod].
  static String paymentMethodLabel(PaymentMethod method) => switch (method) {
    PaymentMethod.cash => 'Cash',
    PaymentMethod.upi => 'UPI',
    PaymentMethod.card => 'Card',
    PaymentMethod.netBanking => 'Net banking',
    PaymentMethod.emi => 'EMI',
    PaymentMethod.cheque => 'Cheque',
    PaymentMethod.wallet => 'Wallet',
    PaymentMethod.other => 'Other',
  };

  /// Labels for [LedgerEntryType].
  static String ledgerTypeLabel(LedgerEntryType type) => switch (type) {
    LedgerEntryType.charge => 'Charge',
    LedgerEntryType.payment => 'Payment',
    LedgerEntryType.adjustment => 'Adjustment',
    LedgerEntryType.refund => 'Refund',
  };
}
