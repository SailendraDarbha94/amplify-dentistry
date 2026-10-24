import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_data/ampdent_data.dart';
import 'package:ampdent_terminology/ampdent_terminology.dart';
import 'package:flutter/foundation.dart';

/// Case-sheet section keys that carry an ICD-10 picker.
const Set<String> diagnosisSectionKeys = {
  'provisionalDiagnosis',
  'finalDiagnosis',
};

const String _softMarker = 'Soft tissue: ';
const String _hardMarker = 'Hard tissue: ';

/// Composes the intraoral examination field from its general text and the
/// two terminology sub-sections. Empty parts are omitted.
String composeIntraoral({
  required String general,
  required String soft,
  required String hard,
}) => [
  if (general.trim().isNotEmpty) general.trim(),
  if (soft.trim().isNotEmpty) '$_softMarker${soft.trim()}',
  if (hard.trim().isNotEmpty) '$_hardMarker${hard.trim()}',
].join('\n');

/// Splits a stored intraoral field back into (general, soft, hard).
(String, String, String) splitIntraoral(String? stored) {
  if (stored == null || stored.isEmpty) return ('', '', '');
  final general = <String>[];
  final soft = <String>[];
  final hard = <String>[];
  var target = general;
  for (final line in stored.split('\n')) {
    if (line.startsWith(_softMarker)) {
      target = soft;
      target.add(line.substring(_softMarker.length));
    } else if (line.startsWith(_hardMarker)) {
      target = hard;
      target.add(line.substring(_hardMarker.length));
    } else {
      target.add(line);
    }
  }
  return (general.join('\n'), soft.join('\n'), hard.join('\n'));
}

/// Case-sheet text keyed by terminology section key, mapped to and from the
/// [ClinicalNote] columns. The intraoral sub-sections are folded into
/// `intraoralExam`; the treatment-plan section lives in `freeText`.
@immutable
class NoteDraft {
  /// Creates a draft from section texts.
  const NoteDraft({this.sections = const {}});

  /// Loads the sections of an existing note.
  factory NoteDraft.fromNote(ClinicalNote n) {
    final (general, soft, hard) = splitIntraoral(n.intraoralExam);
    return NoteDraft(
      sections: {
        'chiefComplaint': n.chiefComplaint ?? '',
        'historyOfPresentIllness': n.historyOfPresentIllness ?? '',
        'pastDentalHistory': n.pastDentalHistory ?? '',
        'pastMedicalHistory': n.pastMedicalHistory ?? '',
        'personalHistory': n.personalHistory ?? '',
        'extraoralExamination': n.extraoralExam ?? '',
        'intraoralExamination': general,
        'intraoralSoftTissue': soft,
        'intraoralHardTissue': hard,
        'provisionalDiagnosis': n.provisionalDiagnosis ?? '',
        'investigations': n.investigations ?? '',
        'finalDiagnosis': n.finalDiagnosis ?? '',
        'treatmentPlan': n.freeText ?? '',
        'treatmentDone': n.treatmentDone ?? '',
        'advice': n.advice ?? '',
        'followUp': n.followUp ?? '',
      },
    );
  }

  /// Text per section key (missing means empty).
  final Map<String, String> sections;

  /// Text of one section.
  String operator [](String key) => sections[key] ?? '';

  /// Whether every section is blank.
  bool get isEmpty => sections.values.every((v) => v.trim().isEmpty);

  /// Section keys that hold text, in case-sheet order.
  List<String> get filledKeys => [
    for (final s in caseSheetSections)
      if (this[s.key].trim().isNotEmpty) s.key,
  ];

  /// Returns a copy with one section replaced.
  NoteDraft withSection(String key, String text) =>
      NoteDraft(sections: {...sections, key: text});

  /// Appends a line to a section (used by the ICD-10 picker).
  NoteDraft appendLine(String key, String line) {
    final current = this[key].trimRight();
    return withSection(key, current.isEmpty ? line : '$current\n$line');
  }

  String? _nullable(String key) {
    final v = this[key].trim();
    return v.isEmpty ? null : v;
  }

  /// Builds the note row; [existing] keeps id, visit, author, version and
  /// signature fields so the repository can decide whether to version it.
  ClinicalNote toNote({
    required String id,
    required String clinicId,
    required String patientId,
    required String visitId,
    required String authorId,
    required DateTime now,
    ClinicalNote? existing,
  }) {
    final intraoral = composeIntraoral(
      general: this['intraoralExamination'],
      soft: this['intraoralSoftTissue'],
      hard: this['intraoralHardTissue'],
    );
    return ClinicalNote(
      id: existing?.id ?? id,
      clinicId: clinicId,
      patientId: patientId,
      visitId: existing?.visitId ?? visitId,
      authorId: existing?.authorId ?? authorId,
      chiefComplaint: _nullable('chiefComplaint'),
      historyOfPresentIllness: _nullable('historyOfPresentIllness'),
      pastDentalHistory: _nullable('pastDentalHistory'),
      pastMedicalHistory: _nullable('pastMedicalHistory'),
      personalHistory: _nullable('personalHistory'),
      extraoralExam: _nullable('extraoralExamination'),
      intraoralExam: intraoral.isEmpty ? null : intraoral,
      provisionalDiagnosis: _nullable('provisionalDiagnosis'),
      investigations: _nullable('investigations'),
      finalDiagnosis: _nullable('finalDiagnosis'),
      treatmentDone: _nullable('treatmentDone'),
      advice: _nullable('advice'),
      followUp: _nullable('followUp'),
      freeText: _nullable('treatmentPlan'),
      version: existing?.version ?? 1,
      supersedesNoteId: existing?.supersedesNoteId,
      signedAt: existing?.signedAt,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
  }
}

/// `K02.1 Caries of dentine`.
String icd10Label(Icd10Code code) => '${code.code} ${code.description}';

/// Saves notes through the repositories: finds or opens the patient's visit,
/// writes the note and signs it. Editing a signed note yields a new version
/// (the repository appends `version + 1` with `supersedesNoteId`).
class NoteSaver {
  /// Creates the saver.
  const NoteSaver({
    required this.clinical,
    required this.appointments,
    required this.ctx,
  });

  /// Notes and history repository.
  final ClinicalRepository clinical;

  /// Visits live here.
  final AppointmentRepository appointments;

  /// Actor for every write.
  final ActorContext ctx;

  /// The open visit of [patientId], or a new one started now.
  Future<Visit> ensureVisit(String patientId, {DateTime? now}) async {
    final open = await appointments.openVisit(patientId);
    if (open != null) return open;
    final at = (now ?? DateTime.now()).toUtc();
    return appointments.startVisit(
      ctx,
      Visit(
        id: newId(),
        clinicId: ctx.clinicId,
        patientId: patientId,
        providerId: ctx.actorId,
        startedAt: at,
        createdAt: at,
        updatedAt: at,
      ),
    );
  }

  /// Writes [draft]; returns the stored note, which has a new id when
  /// [existing] was already signed.
  Future<ClinicalNote> save({
    required String patientId,
    required NoteDraft draft,
    ClinicalNote? existing,
    DateTime? now,
  }) async {
    final at = (now ?? DateTime.now()).toUtc();
    final visitId =
        existing?.visitId ?? (await ensureVisit(patientId, now: at)).id;
    final note = draft.toNote(
      id: newId(),
      clinicId: ctx.clinicId,
      patientId: patientId,
      visitId: visitId,
      authorId: ctx.actorId,
      now: at,
      existing: existing,
    );
    return clinical.saveNote(ctx, note);
  }

  /// Signs and locks a note.
  Future<ClinicalNote> sign(String noteId, {DateTime? now}) =>
      clinical.signNote(ctx, noteId, at: now?.toUtc());
}
