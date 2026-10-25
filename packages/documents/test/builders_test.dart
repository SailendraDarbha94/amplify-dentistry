import 'dart:convert';
import 'dart:typed_data';

import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_documents/ampdent_documents.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

import 'fixtures.dart';
import 'fixtures_clinical.dart';

/// A 1x1 transparent PNG, standing in for a captured signature.
final Uint8List tinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

void expectPdf(Uint8List bytes) {
  expect(bytes.length, greaterThan(1000));
  expect(String.fromCharCodes(bytes.sublist(0, 4)), '%PDF');
}

void main() {
  group('DocumentFonts', () {
    test('loads Noto Sans from disk with script fallbacks', () {
      final fonts = testFonts();
      expect(fonts.fallback, hasLength(2));
      expect(fonts.themeData().defaultTextStyle.fontSize, 9);
    });
  });

  group('DocumentTheme', () {
    test('registration line follows DCI Code 3.4.1 wording', () {
      final theme = testTheme();
      expect(theme.registrationLine(dentist), 'Reg. No. TSDC A-12345');
      expect(
        theme.dentistNameLine(dentist),
        'Dr. Priya Sharma, BDS, MDS (Endodontics)',
      );
      final unregistered = ClinicMember(
        id: 'm2',
        clinicId: clinic.id,
        displayName: 'Dr Arjun Rao',
        role: ClinicRole.associateDentist,
        phone: '',
        createdAt: now,
        updatedAt: now,
      );
      expect(theme.registrationLine(unregistered), 'Reg. No. not recorded');
      expect(theme.dentistNameLine(unregistered), 'Dr Arjun Rao');
    });

    test('A5 paper uses smaller type and margins', () {
      final a5 = testTheme(paper: DocumentPaper.a5);
      expect(a5.pageFormat.width, lessThan(testTheme().pageFormat.width));
      expect(a5.baseFontSize, lessThan(testTheme().baseFontSize));
    });
  });

  group('InvoicePdf', () {
    test('renders an invoice-cum-bill of supply on one page', () async {
      final builder = InvoicePdf(
        clinic: clinic,
        patient: patient,
        invoice: sampleInvoice(),
        payments: samplePayments,
        theme: testTheme(),
      );
      expect(builder.title, 'INVOICE-CUM-BILL OF SUPPLY');
      expect(builder.watermark, isNull);
      expect(builder.gstSummary.rows, hasLength(2));
      final bytes = await builder.build();
      expectPdf(bytes);
      expect(builder.pageCount, 1);
      expect(builder.suggestedFileName, endsWith('.pdf'));
    });

    test('prints the dentist frozen on the invoice, not a device member', () {
      final builder = InvoicePdf(
        clinic: clinic,
        patient: patient,
        invoice: sampleInvoice(),
        theme: testTheme(),
      );
      final who = builder.signatory!;
      expect(who.displayName, dentist.displayName);
      expect(who.registrationNumber, 'A-12345');
      expect(who.registrationCouncil, 'TSDC');
      expect(who.qualifications, dentist.qualifications);
      expect(
        testTheme().signatoryRegistrationLine(who),
        'Reg. No. TSDC A-12345',
      );
      expect(builder.footerNote, contains('DCI Code of Ethics 3.4.1'));
      // The issuer (front desk) is not who the document names.
      expect(sampleInvoice().issuedBy, isNot(dentist.id));
      expect(sampleInvoice().hasRegisteredDentist, isTrue);
    });

    test(
      'draft receipt gets a DRAFT watermark and no registration claim',
      () async {
        final builder = InvoicePdf(
          clinic: unregisteredClinic,
          patient: patient,
          invoice: sampleReceipt(),
          theme: testTheme(),
        );
        expect(builder.title, 'RECEIPT');
        expect(builder.watermark, 'DRAFT');
        expect(builder.signatory, isNull);
        expect(builder.footerNote, isNot(contains('DCI')));
        expectPdf(await builder.build());
        expect(builder.pageCount, 1);
      },
    );

    test('every document type renders', () async {
      for (final type in InvoiceDocumentType.values) {
        final builder = InvoicePdf(
          clinic: clinic,
          patient: patient,
          invoice: sampleInvoice(type: type),
          theme: testTheme(),
        );
        expectPdf(await builder.build());
      }
    });
  });

  group('EstimatePdf', () {
    test('renders phases and alternatives on one page', () async {
      final builder = EstimatePdf(
        clinic: clinic,
        dentist: dentist,
        patient: patient,
        estimate: sampleEstimate(version: 2),
        plan: samplePlan,
        planLines: samplePlanLines,
        theme: testTheme(),
      );
      expectPdf(await builder.build());
      expect(builder.pageCount, 1);
      expect(builder.subtitle, contains('v2'));
    });

    test('renders flat lines without a plan', () async {
      final builder = EstimatePdf(
        clinic: clinic,
        dentist: dentist,
        patient: patient,
        estimate: sampleEstimate(),
        theme: testTheme(),
      );
      expectPdf(await builder.build());
      expect(builder.pageCount, 1);
    });
  });

  group('PrescriptionPdf', () {
    test('renders on A5 with QR and Schedule H1 marking', () async {
      final rx = samplePrescription();
      expect(rx.hasScheduleH1, isTrue);
      final builder = PrescriptionPdf(
        clinic: clinic,
        dentist: dentist,
        patient: patient,
        prescription: rx,
        theme: testTheme(paper: DocumentPaper.a5),
      );
      expect(prescriptionQrPayload(rx), 'ampdent:rx:rx-1:K7Q2-9XMA');
      expect(builder.footerNote, contains('Not to be repeated'));
      expectPdf(await builder.build());
      expect(builder.pageCount, 1);
    });

    test('repeatable prescription says so', () {
      final builder = PrescriptionPdf(
        clinic: clinic,
        dentist: dentist,
        patient: patient,
        prescription: samplePrescription().copyWith(isRepeatable: true),
        theme: testTheme(),
      );
      expect(builder.footerNote, contains('Repeatable'));
    });
  });

  group('ConsentPdf', () {
    test('renders the signed consent with signature image', () async {
      final consent = sampleConsent();
      final builder = ConsentPdf(
        clinic: clinic,
        dentist: dentist,
        patient: patient,
        consent: consent,
        signatureImageBytes: tinyPng,
        theme: testTheme(),
      );
      expect(builder.template?.code, 'RCT');
      expect(builder.documentHash, consent.documentHash);
      expectPdf(await builder.build());
      expect(builder.pageCount, inInclusiveRange(1, 3));
    });

    test('renders without a signature image', () async {
      final builder = ConsentPdf(
        clinic: clinic,
        dentist: dentist,
        patient: patient,
        consent: sampleConsent(),
        theme: testTheme(),
      );
      expectPdf(await builder.build());
    });
  });

  group('LabSlipPdf', () {
    test('renders a one-page A5 slip with a barcode', () async {
      final builder = LabSlipPdf(
        clinic: clinic,
        dentist: dentist,
        patient: patient,
        labCase: sampleLabCase(),
        lab: sampleLab,
        theme: testTheme(paper: DocumentPaper.a5),
      );
      expect(labCaseTypeLabel(LabCaseType.crownZirconia), 'Crown - Zirconia');
      expectPdf(await builder.build());
      expect(builder.pageCount, 1);
    });
  });

  group('PatientRecordPdf', () {
    test(
      'renders the record copy with odontogram, history and finances',
      () async {
        final builder = PatientRecordPdf(
          clinic: clinic,
          dentist: dentist,
          patient: patient,
          toothStates: sampleToothStates(),
          findings: sampleFindings(),
          procedures: sampleProcedures(),
          plans: [samplePlan],
          invoices: [sampleInvoice(), sampleReceipt()],
          payments: samplePayments,
          prescriptions: [samplePrescription()],
          consents: [sampleConsent()],
          notes: sampleNotes(),
          perioExams: samplePerioExams(),
          asOf: now,
          theme: testTheme(),
        );
        expectPdf(await builder.build());
        expect(builder.pageCount, inInclusiveRange(1, 3));
      },
    );

    test('renders an empty record without a dentist', () async {
      final builder = PatientRecordPdf(
        clinic: clinic,
        patient: patient,
        asOf: now,
        theme: testTheme(),
      );
      expectPdf(await builder.build());
      expect(builder.pageCount, 1);
    });

    test('history is chronological', () {
      final events = buildPatientHistory(
        notation: ToothNotation.fdi,
        findings: sampleFindings(),
        procedures: sampleProcedures(),
        notes: sampleNotes(),
        perioExams: samplePerioExams(),
      );
      for (var i = 1; i < events.length; i++) {
        expect(
          events[i].occurredAt.isBefore(events[i - 1].occurredAt),
          isFalse,
        );
      }
      expect(events.first.kind, 'Procedure');
      expect(events.first.teeth, '36');
    });
  });

  group('composition', () {
    test('pages from several builders combine into one document', () async {
      final theme = testTheme();
      final doc = pw.Document();
      final estimate = EstimatePdf(
        clinic: clinic,
        dentist: dentist,
        patient: patient,
        estimate: sampleEstimate(),
        plan: samplePlan,
        planLines: samplePlanLines,
        theme: theme,
      );
      final consent = ConsentPdf(
        clinic: clinic,
        dentist: dentist,
        patient: patient,
        consent: sampleConsent(),
        theme: theme,
      );
      for (final page in [...estimate.buildPages(), ...consent.buildPages()]) {
        doc.addPage(page);
      }
      final bytes = await doc.save();
      expectPdf(bytes);
      expect(
        doc.document.pdfPageList.pages.length,
        estimate.pageCount + consent.pageCount,
      );
    });
  });
}
