import 'package:ampdent_core/ampdent_core.dart';
import 'package:pdf/widgets.dart' as pw;

import '../hash/document_hash.dart';
import '../text/formatters.dart';
import '../theme/document_theme.dart';
import '../theme/document_widgets.dart';
import 'document_builder.dart';

/// Builds the QR payload for a prescription: `ampdent:rx:<id>:<code>`.
String prescriptionQrPayload(Prescription prescription) =>
    'ampdent:rx:${prescription.id}:${prescription.verificationCode}';

/// Prescription (Rx) under the Drugs and Cosmetics Rules (Rule 65) and the
/// DCI Code: generic names in capitals (Code 3.5), patient name, age, sex and
/// address, dose, frequency, duration and total quantity, `Not to be
/// repeated` unless repeatable, Schedule H1 marking, and the prescriber's
/// name, qualifications, registration number and signature.
class PrescriptionPdf extends DocumentBuilder {
  /// Creates the builder. Prefers A5 paper unless the theme overrides it.
  PrescriptionPdf({
    required super.clinic,
    required ClinicMember super.dentist,
    required this.patient,
    required this.prescription,
    required super.theme,
    this.showQr = true,
  });

  /// The patient.
  final Patient patient;

  /// The prescription.
  final Prescription prescription;

  /// Whether to print the verification QR code.
  final bool showQr;

  @override
  String get title => 'PRESCRIPTION';

  @override
  String? get subtitle =>
      'Date ${formatDate(prescription.issuedAt)}  |  '
      'Code ${prescription.verificationCode}';

  @override
  String get documentHash =>
      prescription.documentHash ?? documentContentHash(prescription.toJson());

  @override
  String? get footerNote => prescription.isRepeatable
      ? 'Repeatable as directed by the prescriber.'
      : 'Not to be repeated (Drugs and Cosmetics Rules, Rule 65(11)).';

  @override
  String get suggestedFileName => 'Rx_${prescription.verificationCode}.pdf';

  /// Demographics printed on the document: the snapshot frozen at issue, so
  /// a reprint matches the signed original; the live [patient] only for rows
  /// issued before the snapshot existed.
  PatientSnapshot get printedPatient =>
      prescription.patientSnapshot ??
      PatientSnapshot.of(patient, prescription.issuedAt);

  @override
  List<pw.Widget> buildBody(pw.Context context) {
    final p = printedPatient;
    final age = p.ageYears == null ? 'Age unknown' : '${p.ageYears} y';
    final address = [
      ...p.addressLines.where((l) => l.trim().isNotEmpty),
      if (p.city != null && p.city!.isNotEmpty) p.city!,
      if (p.pincode != null && p.pincode!.isNotEmpty) p.pincode!,
    ].join(', ');
    return [
      DocumentWidgets.infoColumns(
        theme,
        left: [
          MapEntry('Patient', p.displayName),
          MapEntry('Age / Sex', '$age / ${formatSex(p.sex)}'),
          MapEntry('Address', address),
          MapEntry('Phone', p.phone),
        ],
        right: [
          MapEntry('Patient No.', p.patientNumber),
          MapEntry('Date', formatDate(prescription.issuedAt)),
          MapEntry('Diagnosis', prescription.diagnosis),
          if (p.guardianName != null) MapEntry('Guardian', p.guardianName),
        ],
      ),
      pw.SizedBox(height: 6),
      pw.Text(
        'Rx',
        style: pw.TextStyle(
          fontSize: theme.baseFontSize + 14,
          fontWeight: pw.FontWeight.bold,
          color: DocumentColors.accent,
        ),
      ),
      pw.SizedBox(height: 2),
      _linesTable(),
      if (prescription.hasScheduleH1)
        DocumentWidgets.noteBox(
          theme,
          'Items marked Schedule H1 are to be sold by retail on this '
          'prescription only and recorded in the Schedule H1 register.',
        ),
      pw.SizedBox(height: 6),
      pw.Row(
        children: [
          DocumentWidgets.tag(
            theme,
            prescription.isRepeatable
                ? 'MAY BE REPEATED'
                : 'NOT TO BE REPEATED',
          ),
          pw.SizedBox(width: 6),
          if (prescription.dispensedByClinic)
            DocumentWidgets.tag(theme, 'DISPENSED BY CLINIC'),
        ],
      ),
      pw.SizedBox(height: 18),
      _prescriberBlock(),
    ];
  }

  pw.Widget _linesTable() {
    final rows = <List<String>>[];
    for (var i = 0; i < prescription.lines.length; i++) {
      final l = prescription.lines[i];
      final brand = l.brandName == null || l.brandName!.isEmpty
          ? ''
          : ' (${l.brandName})';
      final h1 = l.schedule == DrugSchedule.h1 ? '  [Schedule H1]' : '';
      rows.add([
        '${i + 1}',
        '${l.genericName.toUpperCase()}$brand$h1\n'
            '${l.strength}  ${humanizeEnumName(l.form.name)}',
        l.dose,
        l.frequency,
        '${l.durationDays} d',
        '${l.quantity}',
        l.route,
        l.instructions ?? '-',
      ]);
    }
    return DocumentWidgets.table(
      theme,
      headers: const [
        '#',
        'Drug',
        'Dose',
        'Frequency',
        'Duration',
        'Qty',
        'Route',
        'Instructions',
      ],
      rows: rows,
      rightAligned: const {5},
      centered: const {0, 4},
      columnWidths: const {1: pw.FlexColumnWidth(3), 7: pw.FlexColumnWidth(2)},
    );
  }

  pw.Widget _prescriberBlock() {
    final qualifications = prescription.prescriberQualifications.isEmpty
        ? dentist!.qualifications
        : prescription.prescriberQualifications;
    final name = prescription.prescriberName.startsWith('Dr')
        ? prescription.prescriberName
        : 'Dr. ${prescription.prescriberName}';
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        if (showQr)
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.BarcodeWidget(
                data: prescriptionQrPayload(prescription),
                barcode: pw.Barcode.qrCode(),
                width: 64,
                height: 64,
                drawText: false,
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Verify: ${prescription.verificationCode}',
                style: theme.mutedStyle,
              ),
            ],
          )
        else
          pw.Text('Verification code: ${prescription.verificationCode}'),
        DocumentWidgets.signatureBox(
          theme,
          caption: qualifications.isEmpty
              ? name
              : '$name, ${qualifications.join(', ')}',
          lines: [
            'Reg. No. '
                    '${dentist!.registrationCouncil ?? ''} '
                    '${prescription.prescriberRegistrationNumber}'
                .trim(),
            'Signature and date',
          ],
        ),
      ],
    );
  }
}
