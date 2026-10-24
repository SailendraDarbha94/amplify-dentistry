import 'package:ampdent_core/ampdent_core.dart';

/// One GST rate band on an invoice, with the CGST/SGST split (half each, the
/// intra-state case: the patient is an unregistered consumer at the clinic's
/// place of supply, so IGST never applies to a clinic bill).
class GstSummaryRow {
  /// Creates a rate band.
  const GstSummaryRow({
    required this.ratePercent,
    required this.taxableValue,
    required this.cgst,
    required this.sgst,
  });

  /// Total GST rate for the band (e.g. 18).
  final num ratePercent;

  /// Taxable value of all lines in the band.
  final Money taxableValue;

  /// Central GST (half of the tax).
  final Money cgst;

  /// State GST (the other half; carries the odd paisa when the tax is odd).
  final Money sgst;

  /// Total tax for the band.
  Money get totalTax => cgst + sgst;

  /// Half rate shown in the CGST / SGST column headers.
  num get halfRatePercent => ratePercent / 2;
}

/// GST summary of an invoice: taxable bands plus the exempt total.
class GstSummary {
  /// Creates a summary.
  const GstSummary({required this.rows, required this.exemptTotal});

  /// Taxable bands, sorted by rate ascending.
  final List<GstSummaryRow> rows;

  /// Taxable value of exempt (0%) health-care lines.
  final Money exemptTotal;

  /// Whether any band is taxable.
  bool get hasTaxableLines => rows.isNotEmpty;

  /// Total CGST across bands.
  Money get cgstTotal => rows.map((r) => r.cgst).total;

  /// Total SGST across bands.
  Money get sgstTotal => rows.map((r) => r.sgst).total;

  /// Total GST across bands.
  Money get taxTotal => rows.map((r) => r.totalTax).total;
}

/// Groups the invoice lines by GST rate. A line is exempt when its class is
/// [GstClass.exemptHealthcare] or its rate is zero. Uses the per-line
/// `taxableValue` and `taxAmount` already computed by `computeInvoiceTotals`,
/// so the summary always reconciles with the line table.
GstSummary summariseInvoiceGst(Invoice invoice) {
  var exempt = const Money.zero();
  final taxableByRate = <num, Money>{};
  final taxByRate = <num, Money>{};
  for (final line in invoice.lines) {
    final isExempt =
        line.gstClass == GstClass.exemptHealthcare || line.taxRatePercent == 0;
    if (isExempt) {
      exempt += line.taxableValue;
      continue;
    }
    final rate = line.taxRatePercent;
    taxableByRate[rate] =
        (taxableByRate[rate] ?? const Money.zero()) + line.taxableValue;
    taxByRate[rate] = (taxByRate[rate] ?? const Money.zero()) + line.taxAmount;
  }
  final rates = taxableByRate.keys.toList()..sort();
  final rows = <GstSummaryRow>[];
  for (final rate in rates) {
    final halves = taxByRate[rate]!.split(2);
    rows.add(
      GstSummaryRow(
        ratePercent: rate,
        taxableValue: taxableByRate[rate]!,
        cgst: halves[1],
        sgst: halves[0],
      ),
    );
  }
  return GstSummary(rows: rows, exemptTotal: exempt);
}

/// Title printed on an invoice for each document type.
String invoiceTitle(InvoiceDocumentType type) => switch (type) {
  InvoiceDocumentType.receipt => 'RECEIPT',
  InvoiceDocumentType.taxInvoice => 'TAX INVOICE',
  InvoiceDocumentType.invoiceCumBillOfSupply => 'INVOICE-CUM-BILL OF SUPPLY',
  InvoiceDocumentType.billOfSupply => 'BILL OF SUPPLY',
};

/// Rule 46A notice printed on an invoice-cum-bill of supply.
const String rule46ANote =
    'Issued under Rule 46A of the CGST Rules, 2017 as a single '
    'invoice-cum-bill of supply to an unregistered recipient covering both '
    'exempt health-care services (SAC 999312, Notification 12/2017 entry 74) '
    'and taxable supplies. Tax is charged only on the taxable lines shown.';
