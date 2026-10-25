import 'package:ampdent_core/ampdent_core.dart';
import 'package:pdf/widgets.dart' as pw;

import '../hash/document_hash.dart';
import '../text/formatters.dart';
import '../text/indian_number_words.dart';
import '../theme/document_theme.dart';
import '../theme/document_widgets.dart';
import 'document_builder.dart';
import 'invoice_gst_summary.dart';

/// Receipt / tax invoice / invoice-cum-bill of supply / bill of supply.
///
/// Shows the line table with SAC/HSN and GST columns, a GST summary grouped by
/// rate with the CGST/SGST split and the exempt total, the amount in words,
/// payments received and the balance. Draft-numbered invoices get a `DRAFT`
/// watermark; an invoice-cum-bill of supply carries the Rule 46A notice.
///
/// The dentist in the letterhead and signature box is the one frozen on the
/// invoice at issue (`Invoice.dentistName` and friends), never the member
/// operating the device, so a receptionist reprinting a receipt still prints
/// the treating dentist's registration number (DCI Code 3.4.1).
class InvoicePdf extends DocumentBuilder {
  /// Creates the builder. [payments] are the payments applied to this
  /// invoice; when omitted only `invoice.amountPaid` is shown.
  InvoicePdf({
    required super.clinic,
    required this.patient,
    required this.invoice,
    this.payments = const [],
    required super.theme,
  });

  /// The billed patient.
  final Patient patient;

  /// The invoice (totals already computed with `computeInvoiceTotals`).
  final Invoice invoice;

  /// Payments received against the invoice.
  final List<Payment> payments;

  /// GST summary derived from the invoice lines.
  late final GstSummary gstSummary = summariseInvoiceGst(invoice);

  /// The treating dentist frozen on the invoice; null for a draft that was
  /// never issued.
  @override
  Signatory? get signatory => Signatory.invoiceDentist(invoice);

  @override
  String get title => invoiceTitle(invoice.documentType);

  @override
  String? get subtitle =>
      'No. ${invoice.number}  |  ${formatDate(invoice.issuedAt)}';

  @override
  String get documentHash => documentContentHash(invoice.toJson());

  @override
  String? get watermark => invoice.isDraftNumber
      ? 'DRAFT'
      : invoice.status == InvoiceStatus.voided
      ? 'VOID'
      : null;

  @override
  String? get footerNote => (signatory?.hasRegistration ?? false)
      ? 'Registration number printed under DCI Code of Ethics 3.4.1. '
            'Computer-generated document.'
      : 'Computer-generated document.';

  @override
  String get suggestedFileName =>
      '${title.replaceAll(' ', '_')}_${invoice.number}.pdf';

  @override
  List<pw.Widget> buildBody(pw.Context context) {
    final asOf = invoice.issuedAt;
    return [
      _parties(asOf),
      pw.SizedBox(height: 8),
      _linesTable(),
      pw.SizedBox(height: 8),
      _gstSummaryTable(),
      pw.SizedBox(height: 6),
      _totals(),
      pw.SizedBox(height: 4),
      pw.Text(
        'Amount in words: ${rupeesInWords(invoice.grandTotal)}',
        style: theme.boldStyle,
      ),
      if (payments.isNotEmpty) ...[
        DocumentWidgets.section(theme, 'Payments received'),
        _paymentsTable(),
      ],
      if (invoice.documentType == InvoiceDocumentType.invoiceCumBillOfSupply)
        DocumentWidgets.noteBox(theme, rule46ANote),
      if (invoice.notes != null && invoice.notes!.isNotEmpty)
        DocumentWidgets.noteBox(theme, invoice.notes!),
      if (invoice.status == InvoiceStatus.voided)
        DocumentWidgets.noteBox(
          theme,
          'VOIDED${invoice.voidReason == null ? '' : ': ${invoice.voidReason}'}',
        ),
      pw.SizedBox(height: 18),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          DocumentWidgets.signatureBox(
            theme,
            caption: 'For ${clinic.name}',
            lines: [
              if (signatory != null) ...[
                theme.signatoryNameLine(signatory!),
                theme.signatoryRegistrationLine(signatory!),
              ],
            ],
          ),
        ],
      ),
    ];
  }

  pw.Widget _parties(DateTime asOf) => DocumentWidgets.infoColumns(
    theme,
    left: [
      MapEntry('Billed to', patient.displayName),
      MapEntry('Patient No.', patient.patientNumber),
      MapEntry('Age / Sex', formatAgeSex(patient, asOf)),
      MapEntry('Phone', patient.phone),
      MapEntry('Address', formatPatientAddress(patient)),
    ],
    right: [
      MapEntry('Document', title),
      MapEntry('Number', invoice.number),
      MapEntry('Date', formatDate(invoice.issuedAt)),
      MapEntry('Status', humanizeEnumName(invoice.status.name)),
      MapEntry(
        'Place of supply',
        '${clinic.city} (State code ${clinic.stateCode})',
      ),
    ],
  );

  pw.Widget _linesTable() {
    final rows = <List<String>>[];
    var index = 0;
    for (final line in invoice.lines) {
      index++;
      rows.add([
        '$index',
        line.description,
        line.tooth == null ? '-' : formatTooth(line.tooth!, notation),
        '${line.quantity}',
        line.unitPrice.format(symbol: false),
        line.discount.isZero ? '-' : line.discount.format(symbol: false),
        line.sacHsnCode,
        line.gstClass == GstClass.exemptHealthcare
            ? 'Exempt'
            : formatPercent(line.taxRatePercent),
        line.taxableValue.format(symbol: false),
        line.taxAmount.isZero ? '-' : line.taxAmount.format(symbol: false),
        line.lineTotal.format(symbol: false),
      ]);
    }
    return DocumentWidgets.table(
      theme,
      headers: const [
        '#',
        'Description',
        'Tooth',
        'Qty',
        'Rate',
        'Disc.',
        'SAC/HSN',
        'GST',
        'Taxable',
        'Tax',
        'Total',
      ],
      rows: rows,
      rightAligned: const {3, 4, 5, 8, 9, 10},
      centered: const {0, 2, 6, 7},
      columnWidths: const {1: pw.FlexColumnWidth()},
    );
  }

  pw.Widget _gstSummaryTable() {
    final rows = <List<String>>[
      for (final row in gstSummary.rows)
        [
          formatPercent(row.ratePercent),
          row.taxableValue.format(symbol: false),
          'CGST ${formatPercent(row.halfRatePercent)}',
          row.cgst.format(symbol: false),
          'SGST ${formatPercent(row.halfRatePercent)}',
          row.sgst.format(symbol: false),
          row.totalTax.format(symbol: false),
        ],
      if (!gstSummary.exemptTotal.isZero || gstSummary.rows.isEmpty)
        [
          'Exempt (SAC 999312)',
          gstSummary.exemptTotal.format(symbol: false),
          '-',
          '-',
          '-',
          '-',
          '0.00',
        ],
    ];
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('GST summary', style: theme.sectionStyle),
        pw.SizedBox(height: 3),
        DocumentWidgets.table(
          theme,
          headers: const [
            'Rate',
            'Taxable value',
            'CGST',
            'Amount',
            'SGST',
            'Amount',
            'Total tax',
          ],
          rows: rows,
          rightAligned: const {1, 3, 5, 6},
          columnWidths: const {0: pw.FlexColumnWidth()},
        ),
      ],
    );
  }

  pw.Widget _totals() {
    final paid = payments.isEmpty
        ? invoice.amountPaid
        : payments.map((p) => p.isRefund ? -p.amount : p.amount).total;
    final balance = invoice.grandTotal - paid;
    return DocumentWidgets.totals(
      theme,
      [
        MapEntry('Subtotal', formatMoney(invoice.subtotal)),
        if (!invoice.discountTotal.isZero)
          MapEntry('Discount', '- ${formatMoney(invoice.discountTotal)}'),
        MapEntry('Taxable value', formatMoney(invoice.taxableTotal)),
        if (gstSummary.hasTaxableLines) ...[
          MapEntry('CGST', formatMoney(gstSummary.cgstTotal)),
          MapEntry('SGST', formatMoney(gstSummary.sgstTotal)),
        ],
        MapEntry('Grand total', formatMoney(invoice.grandTotal)),
        MapEntry('Paid', formatMoney(paid)),
        MapEntry('Balance due', formatMoney(balance)),
      ],
      emphasisLabels: const {'Grand total', 'Balance due'},
    );
  }

  pw.Widget _paymentsTable() => DocumentWidgets.table(
    theme,
    headers: const ['Date', 'Method', 'Reference', 'Received by', 'Amount'],
    rows: [
      for (final p in payments)
        [
          formatDateTime(p.receivedAt),
          _methodLabel(p),
          p.reference ?? '-',
          p.receivedBy,
          (p.isRefund ? -p.amount : p.amount).format(symbol: false),
        ],
    ],
    rightAligned: const {4},
    columnWidths: const {2: pw.FlexColumnWidth()},
  );

  String _methodLabel(Payment p) {
    final method = formatPaymentMethod(p.method);
    final card = p.cardLast4 == null
        ? ''
        : ' ${p.cardBrand ?? ''} ****${p.cardLast4}'.trimRight();
    return '$method$card${p.isRefund ? ' (refund)' : ''}';
  }
}
