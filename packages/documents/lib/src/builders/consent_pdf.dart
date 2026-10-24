import 'dart:typed_data';

import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_terminology/ampdent_terminology.dart';
import 'package:pdf/widgets.dart' as pw;

import '../hash/document_hash.dart';
import '../text/formatters.dart';
import '../theme/document_widgets.dart';
import 'document_builder.dart';

/// Signed procedure consent: the exact rendered text the patient saw, the
/// teeth involved, the signer's identity and capacity, OTP verification,
/// the drawn signature, the dentist's countersignature, discussion note,
/// witness, timestamp, device id and the stored document hash.
class ConsentPdf extends DocumentBuilder {
  /// Creates the builder. [signatureImageBytes] is the PNG captured at
  /// signing; when null an empty signature box is printed.
  ConsentPdf({
    required super.clinic,
    required ClinicMember super.dentist,
    required this.patient,
    required this.consent,
    this.signatureImageBytes,
    required super.theme,
  });

  /// The patient the consent concerns.
  final Patient patient;

  /// The signed consent record.
  final ConsentRecord consent;

  /// PNG bytes of the captured signature, if any.
  final Uint8List? signatureImageBytes;

  /// Template looked up from the terminology package, when known.
  ConsentTemplate? get template => consentTemplateByCode(consent.templateCode);

  @override
  String get title => 'INFORMED CONSENT';

  @override
  String? get subtitle =>
      '${template?.title ?? consent.templateCode}  |  '
      '${formatDate(consent.signedAt)}';

  @override
  String get documentHash => consent.documentHash;

  @override
  String? get footerNote =>
      'Template ${consent.templateCode} v${shortHash(consent.templateVersionHash, length: 12)}  |  '
      'Device ${consent.deviceId}  |  Signed ${formatDateTime(consent.signedAt)}';

  @override
  String get suggestedFileName =>
      'Consent_${consent.templateCode}_${patient.patientNumber}.pdf';

  @override
  List<pw.Widget> buildBody(pw.Context context) {
    final asOf = consent.signedAt;
    final signature = signatureImageBytes == null
        ? null
        : pw.MemoryImage(signatureImageBytes!);
    return [
      DocumentWidgets.infoColumns(
        theme,
        left: [
          MapEntry('Patient', patient.displayName),
          MapEntry('Patient No.', patient.patientNumber),
          MapEntry('Age / Sex', formatAgeSex(patient, asOf)),
          MapEntry('Phone', patient.phone),
        ],
        right: [
          MapEntry(
            'Procedure consent',
            template?.title ?? consent.templateCode,
          ),
          MapEntry('Teeth', formatTeeth(consent.teeth, notation)),
          MapEntry('Language', consent.languageCode.toUpperCase()),
          MapEntry('Signed on', formatDateTime(consent.signedAt)),
        ],
      ),
      DocumentWidgets.section(theme, 'Consent as shown to the signer'),
      for (final paragraph in _paragraphs(consent.renderedText))
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Text(paragraph, textAlign: pw.TextAlign.justify),
        ),
      if (consent.discussionNote != null &&
          consent.discussionNote!.isNotEmpty) ...[
        DocumentWidgets.section(theme, 'Discussion note'),
        pw.Text(consent.discussionNote!),
      ],
      DocumentWidgets.section(theme, 'Signer'),
      DocumentWidgets.infoColumns(
        theme,
        left: [
          MapEntry('Name', consent.signerName),
          MapEntry(
            'Relationship',
            humanizeEnumName(consent.signerRelation.name),
          ),
          MapEntry('Phone', consent.signerPhone),
        ],
        right: [
          MapEntry(
            'Phone verification',
            consent.otpVerified ? 'OTP verified' : 'Not OTP verified',
          ),
          MapEntry('Witness', consent.witnessName),
          MapEntry('Device', consent.deviceId),
        ],
      ),
      pw.SizedBox(height: 14),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          DocumentWidgets.signatureBox(
            theme,
            caption: consent.signerName,
            image: signature,
            lines: [
              '${humanizeEnumName(consent.signerRelation.name)}  |  '
                  '${formatDateTime(consent.signedAt)}',
              if (signature == null) 'Signature not captured',
            ],
          ),
          DocumentWidgets.signatureBox(
            theme,
            caption: 'Dentist countersignature',
            lines: [
              theme.dentistNameLine(dentist!),
              'Reg. No. ${consent.dentistRegistrationNumber}',
            ],
          ),
        ],
      ),
      pw.SizedBox(height: 10),
      pw.Text(
        'Document hash SHA-256: ${consent.documentHash}',
        style: theme.mutedStyle,
      ),
      pw.Text(
        'Template version hash: ${consent.templateVersionHash}',
        style: theme.mutedStyle,
      ),
    ];
  }

  List<String> _paragraphs(String text) => text
      .split(RegExp(r'\n\s*\n'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();
}
