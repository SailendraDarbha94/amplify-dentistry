import 'package:ampdent_core/ampdent_core.dart';
import 'package:pdf/widgets.dart' as pw;

import '../hash/document_hash.dart';
import '../text/formatters.dart';
import '../theme/document_widgets.dart';
import 'document_builder.dart';

/// Human-readable label for a lab case type.
String labCaseTypeLabel(LabCaseType type) => switch (type) {
  LabCaseType.crownPfm => 'Crown - PFM',
  LabCaseType.crownZirconia => 'Crown - Zirconia',
  LabCaseType.crownMetal => 'Crown - Metal',
  LabCaseType.bridge => 'Bridge',
  LabCaseType.inlayOnlay => 'Inlay / Onlay',
  LabCaseType.veneer => 'Veneer',
  LabCaseType.completeDenture => 'Complete denture',
  LabCaseType.partialDenture => 'Partial denture',
  LabCaseType.castPartial => 'Cast partial denture',
  LabCaseType.nightGuard => 'Night guard',
  LabCaseType.aligner => 'Aligner',
  LabCaseType.retainer => 'Retainer',
  LabCaseType.implantCrown => 'Implant crown',
  LabCaseType.other => 'Other',
};

/// Lab work authorisation slip sent with the impression. Carries only the
/// patient's name, age and sex (data minimisation: the lab needs nothing
/// else), the case details and a Code 128 barcode of the case id.
class LabSlipPdf extends DocumentBuilder {
  /// Creates the builder.
  LabSlipPdf({
    required super.clinic,
    required ClinicMember super.dentist,
    required this.patient,
    required this.labCase,
    required this.lab,
    required super.theme,
  });

  /// Patient (only name, age and sex are printed).
  final Patient patient;

  /// The lab case.
  final LabCase labCase;

  /// The receiving lab.
  final Lab lab;

  @override
  String get title => 'LAB WORK AUTHORISATION';

  @override
  String? get subtitle =>
      'Case ${shortHash(labCase.id.replaceAll('-', ''), length: 8)}  |  '
      '${formatDate(labCase.sentAt ?? labCase.createdAt)}';

  @override
  String get documentHash => documentContentHash(labCase.toJson());

  @override
  String? get footerNote => labCase.remakeOfCaseId == null
      ? null
      : 'Remake of case ${labCase.remakeOfCaseId}'
            '${labCase.remakeReason == null ? '' : ': ${labCase.remakeReason}'}';

  @override
  String get suggestedFileName =>
      'LabSlip_${labCaseTypeLabel(labCase.caseType).replaceAll(RegExp(r'[^A-Za-z]'), '')}_'
      '${patient.patientNumber}.pdf';

  @override
  List<pw.Widget> buildBody(pw.Context context) {
    final asOf = labCase.sentAt ?? labCase.createdAt;
    return [
      DocumentWidgets.infoColumns(
        theme,
        left: [
          MapEntry('To', lab.name),
          MapEntry('Lab phone', lab.phone ?? lab.whatsappPhone),
          MapEntry('From', clinic.name),
          MapEntry('Clinic phone', clinic.phone),
        ],
        right: [
          MapEntry('Patient', patient.displayName),
          MapEntry('Age / Sex', formatAgeSex(patient, asOf)),
          MapEntry('Dentist', theme.dentistNameLine(dentist!)),
          MapEntry('Status', humanizeEnumName(labCase.status.name)),
        ],
      ),
      DocumentWidgets.section(theme, 'Case'),
      DocumentWidgets.infoColumns(
        theme,
        left: [
          MapEntry('Case type', labCaseTypeLabel(labCase.caseType)),
          MapEntry('Teeth', formatTeeth(labCase.teeth, notation)),
          MapEntry('Material', labCase.material),
          MapEntry('Shade', labCase.shade),
          MapEntry('Impression', labCase.impressionType),
        ],
        right: [
          MapEntry('Sent on', formatDateOrDash(labCase.sentAt)),
          MapEntry('Due on', formatDateOrDash(labCase.dueAt)),
          MapEntry('Received on', formatDateOrDash(labCase.receivedAt)),
          MapEntry(
            'Lab fee',
            labCase.labFee.isZero ? null : formatMoney(labCase.labFee),
          ),
        ],
      ),
      if (labCase.instructions != null && labCase.instructions!.isNotEmpty) ...[
        DocumentWidgets.section(theme, 'Instructions'),
        pw.Text(labCase.instructions!),
      ],
      pw.SizedBox(height: 12),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.BarcodeWidget(
                data: labCase.id,
                barcode: pw.Barcode.code128(),
                width: 200,
                height: 40,
                drawText: false,
              ),
              pw.SizedBox(height: 2),
              pw.Text(labCase.id, style: theme.mutedStyle),
            ],
          ),
          DocumentWidgets.signatureBox(
            theme,
            caption: 'Authorised by',
            lines: [
              theme.dentistNameLine(dentist!),
              theme.registrationLine(dentist!),
            ],
            width: 150,
            height: 40,
          ),
        ],
      ),
    ];
  }
}
