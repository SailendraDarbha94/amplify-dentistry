import 'package:meta/meta.dart';

import 'json_support.dart';

/// A structured case-sheet note for one visit. Versioned: an amendment is a
/// new note whose [supersedesNoteId] points at the earlier one; nothing is
/// edited in place once [signedAt] is set.
@immutable
class ClinicalNote {
  /// Creates a clinical note.
  const ClinicalNote({
    required this.id,
    required this.clinicId,
    required this.patientId,
    required this.visitId,
    required this.authorId,
    this.chiefComplaint,
    this.historyOfPresentIllness,
    this.pastDentalHistory,
    this.pastMedicalHistory,
    this.personalHistory,
    this.extraoralExam,
    this.intraoralExam,
    this.provisionalDiagnosis,
    this.investigations,
    this.finalDiagnosis,
    this.treatmentDone,
    this.advice,
    this.followUp,
    this.freeText,
    this.version = 1,
    this.supersedesNoteId,
    this.signedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  /// UUID v4.
  final String id;

  /// Owning clinic.
  final String clinicId;

  /// Patient.
  final String patientId;

  /// Visit the note documents.
  final String visitId;

  /// Authoring clinician.
  final String authorId;

  /// C/C.
  final String? chiefComplaint;

  /// HOPI.
  final String? historyOfPresentIllness;

  /// Past dental history.
  final String? pastDentalHistory;

  /// Past medical history (narrative; structured risks live in
  /// `MedicalHistory`).
  final String? pastMedicalHistory;

  /// Habits, diet, brushing.
  final String? personalHistory;

  /// Extra-oral examination.
  final String? extraoralExam;

  /// Intra-oral examination.
  final String? intraoralExam;

  /// Provisional diagnosis.
  final String? provisionalDiagnosis;

  /// Investigations advised / done.
  final String? investigations;

  /// Final diagnosis.
  final String? finalDiagnosis;

  /// Treatment done this visit.
  final String? treatmentDone;

  /// Advice given.
  final String? advice;

  /// Follow-up plan.
  final String? followUp;

  /// Unstructured text for clinics that prefer narrative notes.
  final String? freeText;

  /// 1 for the original, incremented on each amendment.
  final int version;

  /// Earlier version this note replaces.
  final String? supersedesNoteId;

  /// When signed; a signed note is immutable.
  final DateTime? signedAt;

  /// Row creation time.
  final DateTime createdAt;

  /// Last modification time.
  final DateTime updatedAt;

  /// Whether the note has been signed.
  bool get isSigned => signedAt != null;

  /// Returns a copy with the given fields replaced.
  ClinicalNote copyWith({
    String? chiefComplaint,
    String? historyOfPresentIllness,
    String? pastDentalHistory,
    String? pastMedicalHistory,
    String? personalHistory,
    String? extraoralExam,
    String? intraoralExam,
    String? provisionalDiagnosis,
    String? investigations,
    String? finalDiagnosis,
    String? treatmentDone,
    String? advice,
    String? followUp,
    String? freeText,
    int? version,
    String? supersedesNoteId,
    DateTime? signedAt,
    DateTime? updatedAt,
  }) => ClinicalNote(
    id: id,
    clinicId: clinicId,
    patientId: patientId,
    visitId: visitId,
    authorId: authorId,
    chiefComplaint: chiefComplaint ?? this.chiefComplaint,
    historyOfPresentIllness:
        historyOfPresentIllness ?? this.historyOfPresentIllness,
    pastDentalHistory: pastDentalHistory ?? this.pastDentalHistory,
    pastMedicalHistory: pastMedicalHistory ?? this.pastMedicalHistory,
    personalHistory: personalHistory ?? this.personalHistory,
    extraoralExam: extraoralExam ?? this.extraoralExam,
    intraoralExam: intraoralExam ?? this.intraoralExam,
    provisionalDiagnosis: provisionalDiagnosis ?? this.provisionalDiagnosis,
    investigations: investigations ?? this.investigations,
    finalDiagnosis: finalDiagnosis ?? this.finalDiagnosis,
    treatmentDone: treatmentDone ?? this.treatmentDone,
    advice: advice ?? this.advice,
    followUp: followUp ?? this.followUp,
    freeText: freeText ?? this.freeText,
    version: version ?? this.version,
    supersedesNoteId: supersedesNoteId ?? this.supersedesNoteId,
    signedAt: signedAt ?? this.signedAt,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// JSON form.
  Map<String, Object?> toJson() => {
    'id': id,
    'clinicId': clinicId,
    'patientId': patientId,
    'visitId': visitId,
    'authorId': authorId,
    'chiefComplaint': chiefComplaint,
    'historyOfPresentIllness': historyOfPresentIllness,
    'pastDentalHistory': pastDentalHistory,
    'pastMedicalHistory': pastMedicalHistory,
    'personalHistory': personalHistory,
    'extraoralExam': extraoralExam,
    'intraoralExam': intraoralExam,
    'provisionalDiagnosis': provisionalDiagnosis,
    'investigations': investigations,
    'finalDiagnosis': finalDiagnosis,
    'treatmentDone': treatmentDone,
    'advice': advice,
    'followUp': followUp,
    'freeText': freeText,
    'version': version,
    'supersedesNoteId': supersedesNoteId,
    'signedAt': dateToJson(signedAt),
    'createdAt': dateToJson(createdAt),
    'updatedAt': dateToJson(updatedAt),
  };

  /// Parses the JSON form.
  factory ClinicalNote.fromJson(Map<String, Object?> json) => ClinicalNote(
    id: json['id'] as String,
    clinicId: json['clinicId'] as String,
    patientId: json['patientId'] as String,
    visitId: json['visitId'] as String,
    authorId: json['authorId'] as String,
    chiefComplaint: json['chiefComplaint'] as String?,
    historyOfPresentIllness: json['historyOfPresentIllness'] as String?,
    pastDentalHistory: json['pastDentalHistory'] as String?,
    pastMedicalHistory: json['pastMedicalHistory'] as String?,
    personalHistory: json['personalHistory'] as String?,
    extraoralExam: json['extraoralExam'] as String?,
    intraoralExam: json['intraoralExam'] as String?,
    provisionalDiagnosis: json['provisionalDiagnosis'] as String?,
    investigations: json['investigations'] as String?,
    finalDiagnosis: json['finalDiagnosis'] as String?,
    treatmentDone: json['treatmentDone'] as String?,
    advice: json['advice'] as String?,
    followUp: json['followUp'] as String?,
    freeText: json['freeText'] as String?,
    version: json['version'] as int? ?? 1,
    supersedesNoteId: json['supersedesNoteId'] as String?,
    signedAt: dateFromJsonOrNull(json['signedAt']),
    createdAt: dateFromJson(json['createdAt']),
    updatedAt: dateFromJson(json['updatedAt']),
  );
}
