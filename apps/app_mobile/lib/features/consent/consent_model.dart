/// Pure logic for procedure consent: placeholder merging, grouping of
/// procedures by template, signer rules (guardian for minors) and the
/// document hash. No Flutter imports so it is unit-testable.
library;

import 'dart:typed_data';

import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_documents/ampdent_documents.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_terminology/ampdent_terminology.dart';

/// Template used when a procedure code has no specific consent template.
const String fallbackConsentTemplateCode = 'GENERAL-EXAM';

/// Template for clinical photography and sharing (DPDP photo use).
const String photoUseTemplateCode = 'PHOTO-USE';

/// Languages offered in the consent language selector. Only languages with
/// at least one shipped template are enabled; the others are the hook for
/// the Hindi and Telugu tables.
const List<(String, String)> consentLanguages = [
  ('en', 'English'),
  ('hi', 'Hindi'),
  ('te', 'Telugu'),
];

/// Whether any consent template exists in [languageCode].
bool consentLanguageAvailable(String languageCode) =>
    consentTemplates.any((t) => t.languageCode == languageCode);

/// User-facing strings for the consent flow (English; translation hook).
abstract final class ConsentStrings {
  /// Block shown when a minor tries to sign for themselves.
  static const String minorCannotSelfSign =
      'Patients under 18 cannot sign for themselves. A parent or guardian '
      'must sign.';

  /// Validation for the mandatory discussion note.
  static const String discussionNoteRequired =
      'Record what you explained (risks, alternatives, questions answered)';

  /// Validation for the signer name.
  static const String signerNameRequired = 'Signer name is required';

  /// Validation for the signature pad.
  static const String signatureRequired = 'A signature is required';

  /// Shown when the acting member cannot take consent.
  static const String dentistRequired =
      'Only a registered dentist can take consent. Switch the acting member '
      'in Settings > Members.';

  /// Label for the read-aloud checkbox.
  static const String readAloud = 'Read aloud and explained by the dentist';

  /// Note appended to the discussion note when read aloud.
  static const String readAloudMarker = '[Read aloud by dentist]';

  /// Explains why only English is selectable.
  static const String languageComing = 'coming soon';
}

/// Human label for a signer relation.
String signerRelationLabel(SignerRelation relation) => switch (relation) {
  SignerRelation.self => 'Patient (self)',
  SignerRelation.parent => 'Parent',
  SignerRelation.guardian => 'Guardian',
  SignerRelation.spouse => 'Spouse',
  SignerRelation.attendant => 'Attendant',
};

/// Maps the free-text guardian relation stored on the patient to a signer
/// capacity; `guardian` when unknown.
SignerRelation signerRelationFromGuardian(String? relation) {
  final r = (relation ?? '').trim().toLowerCase();
  if (r == 'mother' || r == 'father' || r == 'parent') {
    return SignerRelation.parent;
  }
  if (r == 'spouse' || r == 'husband' || r == 'wife') {
    return SignerRelation.spouse;
  }
  return SignerRelation.guardian;
}

/// Removes a leading `Dr.`/`Dr` so templates that print `Dr. {doctor_name}`
/// do not double the title.
String stripDoctorPrefix(String name) =>
    name.replaceFirst(RegExp(r'^\s*Dr\.?\s+', caseSensitive: false), '').trim();

/// Age phrase for `aged {patient_age}`.
String consentAgePhrase(Patient patient, DateTime asOf) {
  final years = patient.ageYears(asOf);
  if (years == null) return 'age not recorded';
  final whole = years.floor();
  return whole == 1 ? '1 year' : '$whole years';
}

/// Gender phrase for `{patient_gender}`.
String consentGenderPhrase(Sex sex) =>
    sex == Sex.unspecified ? 'gender not specified' : AppFormat.sex(sex);

/// Union of the single tooth and tooth lists of [procedures], FDI-sorted.
List<ToothId> teethOfProcedures(Iterable<ProcedureRecord> procedures) {
  final set = <ToothId>{};
  for (final p in procedures) {
    if (p.tooth != null) set.add(p.tooth!);
    set.addAll(p.teeth);
  }
  return set.toList()..sort();
}

/// Values for every standard consent placeholder. Tooth numbers use the
/// clinic's display [notation] in plain text (no Palmer glyphs).
Map<String, String> consentVariables({
  required Patient patient,
  required ClinicMember dentist,
  required Clinic clinic,
  required Iterable<ToothId> teeth,
  required ToothNotation notation,
  required DateTime now,
}) {
  final toothList = teeth.toList();
  return {
    'name_of_patient': patient.displayName,
    'patient_age': consentAgePhrase(patient, now),
    'patient_gender': consentGenderPhrase(patient.sex),
    'doctor_name': stripDoctorPrefix(dentist.displayName),
    'tooth_numbers': toothList.isEmpty
        ? 'as discussed'
        : notation.formatAll(toothList, plain: true),
    'clinic_name': clinic.name,
    'date': AppFormat.date(now),
    'registration_number': dentist.registrationNumber ?? 'not recorded',
  };
}

/// Renders [template] with [values]; unresolved placeholders stay visible so
/// the dentist notices missing data before signing.
String renderConsentText(
  ConsentTemplate template,
  Map<String, String> values,
) => template.render(values);

/// Procedures that share one consent template, signed as one record.
class ConsentGroup {
  /// Creates a group.
  const ConsentGroup({required this.template, required this.procedures});

  /// Template for this group.
  final ConsentTemplate template;

  /// Procedures covered.
  final List<ProcedureRecord> procedures;

  /// Teeth named in the consent.
  List<ToothId> get teeth => teethOfProcedures(procedures);

  /// Ids of the covered procedures.
  List<String> get procedureIds => [for (final p in procedures) p.id];
}

/// Groups procedures by their consent template (via `consentTemplateFor`),
/// falling back to [fallbackConsentTemplateCode]. Template order follows the
/// first procedure that needs it.
List<ConsentGroup> groupProceduresByTemplate(
  Iterable<ProcedureRecord> procedures,
) {
  final order = <String>[];
  final byCode = <String, List<ProcedureRecord>>{};
  final templates = <String, ConsentTemplate>{};
  for (final p in procedures) {
    final t =
        consentTemplateFor(p.code) ??
        consentTemplateByCode(fallbackConsentTemplateCode);
    if (t == null) continue;
    if (!byCode.containsKey(t.code)) {
      order.add(t.code);
      byCode[t.code] = [];
      templates[t.code] = t;
    }
    byCode[t.code]!.add(p);
  }
  return [
    for (final code in order)
      ConsentGroup(template: templates[code]!, procedures: byCode[code]!),
  ];
}

/// Returns the reason signing must be blocked, or null when it may proceed.
/// A minor can never self-sign (Samira Kohli; DPDP s.9).
String? validateConsentSigning({
  required Patient patient,
  required DateTime now,
  required SignerRelation relation,
  required String signerName,
  required String discussionNote,
  required bool hasSignature,
}) {
  if (patient.isMinor(now) && relation == SignerRelation.self) {
    return ConsentStrings.minorCannotSelfSign;
  }
  if (signerName.trim().isEmpty) return ConsentStrings.signerNameRequired;
  if (discussionNote.trim().isEmpty) {
    return ConsentStrings.discussionNoteRequired;
  }
  if (!hasSignature) return ConsentStrings.signatureRequired;
  return null;
}

/// SHA-256 hex over the rendered text, teeth, signer, timestamp and the
/// signature image (its own SHA-256), canonicalised so re-computation from
/// the stored row reproduces the value printed on the PDF.
String consentDocumentHash({
  required String renderedText,
  required List<ToothId> teeth,
  required String signerName,
  required SignerRelation signerRelation,
  required DateTime signedAt,
  Uint8List? signaturePng,
}) => documentContentHash({
  'renderedText': renderedText,
  'teeth': [for (final t in teeth) t.storageKey],
  'signerName': signerName,
  'signerRelation': signerRelation.name,
  'signedAt': signedAt.toUtc().toIso8601String(),
  'signatureSha256': signaturePng == null ? null : sha256Hex(signaturePng),
});
