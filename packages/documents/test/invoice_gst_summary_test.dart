import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_documents/ampdent_documents.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

void main() {
  group('summariseInvoiceGst', () {
    test('₹1,000 exempt + ₹2,000 at 18% gives CGST 180 and SGST 180', () {
      final invoice = computeInvoiceTotals(
        Invoice(
          id: 'i',
          clinicId: clinic.id,
          patientId: patient.id,
          number: 'X/1',
          documentType: InvoiceDocumentType.invoiceCumBillOfSupply,
          issuedAt: now,
          lines: [
            line(
              id: 'a',
              description: 'RCT',
              unitPrice: const Money.rupees(1000),
            ),
            line(
              id: 'b',
              description: 'Whitening',
              unitPrice: const Money.rupees(2000),
              gstClass: GstClass.cosmeticTaxable,
              taxRatePercent: 18,
            ),
          ],
          issuedBy: dentist.id,
          createdAt: now,
          updatedAt: now,
        ),
      );
      final summary = summariseInvoiceGst(invoice);
      expect(summary.exemptTotal, const Money.rupees(1000));
      expect(summary.rows, hasLength(1));
      final row = summary.rows.single;
      expect(row.ratePercent, 18);
      expect(row.taxableValue, const Money.rupees(2000));
      expect(row.cgst, const Money.rupees(180));
      expect(row.sgst, const Money.rupees(180));
      expect(row.totalTax, const Money.rupees(360));
      expect(row.halfRatePercent, 9);
      expect(summary.taxTotal, invoice.taxTotal);
      expect(invoice.grandTotal, const Money.rupees(3360));
    });

    test('groups by rate, sorted ascending, and reconciles with totals', () {
      final invoice = sampleInvoice();
      final summary = summariseInvoiceGst(invoice);
      expect(summary.rows.map((r) => r.ratePercent), [5, 18]);
      expect(summary.rows.first.taxableValue, const Money.rupees(500));
      expect(summary.rows.first.cgst, const Money.rupees(12, 50));
      expect(summary.rows.first.sgst, const Money.rupees(12, 50));
      expect(summary.exemptTotal, const Money.rupees(1000));
      expect(summary.cgstTotal + summary.sgstTotal, invoice.taxTotal);
    });

    test('odd paisa goes to one half and the sum stays exact', () {
      final invoice = computeInvoiceTotals(
        Invoice(
          id: 'i',
          clinicId: clinic.id,
          patientId: patient.id,
          number: 'X/2',
          documentType: InvoiceDocumentType.taxInvoice,
          issuedAt: now,
          lines: [
            line(
              id: 'a',
              description: 'Goods',
              unitPrice: const Money.paise(101),
              gstClass: GstClass.goods,
              taxRatePercent: 5,
            ),
          ],
          issuedBy: dentist.id,
          createdAt: now,
          updatedAt: now,
        ),
      );
      final row = summariseInvoiceGst(invoice).rows.single;
      expect(row.cgst + row.sgst, invoice.taxTotal);
      expect((row.cgst.paise - row.sgst.paise).abs(), lessThanOrEqualTo(1));
    });

    test('exempt-only invoice has no taxable bands', () {
      final summary = summariseInvoiceGst(sampleReceipt());
      expect(summary.hasTaxableLines, isFalse);
      expect(summary.exemptTotal, const Money.rupees(3500));
      expect(summary.taxTotal, const Money.zero());
    });
  });

  group('suggestDocumentType integration', () {
    test('registered clinic with mixed lines prints invoice-cum-bill', () {
      final invoice = sampleInvoice();
      final type = suggestDocumentType(
        clinicGstRegistered: clinic.isGstRegistered,
        lineClasses: invoice.lines.map((l) => l.gstClass),
      );
      expect(type, InvoiceDocumentType.invoiceCumBillOfSupply);
      expect(invoiceTitle(type), 'INVOICE-CUM-BILL OF SUPPLY');
    });

    test('unregistered clinic prints a receipt', () {
      final type = suggestDocumentType(
        clinicGstRegistered: unregisteredClinic.isGstRegistered,
        lineClasses: sampleReceipt().lines.map((l) => l.gstClass),
      );
      expect(type, InvoiceDocumentType.receipt);
      expect(invoiceTitle(type), 'RECEIPT');
    });

    test('every document type has a title', () {
      for (final type in InvoiceDocumentType.values) {
        expect(invoiceTitle(type), isNotEmpty);
      }
    });
  });
}
