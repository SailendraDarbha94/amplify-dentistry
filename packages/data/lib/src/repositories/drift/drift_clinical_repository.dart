import 'package:ampdent_core/ampdent_core.dart';
import 'package:drift/drift.dart';

import '../../db/app_database.dart';
import '../actor_context.dart';
import '../clinical_repository.dart';
import 'audited_writer.dart';

/// Drift implementation of [ClinicalRepository].
class DriftClinicalRepository extends DatabaseAccessor<AppDatabase>
    with AuditedWriter
    implements ClinicalRepository {
  /// Creates the repository over [db].
  DriftClinicalRepository(super.db);

  $ClinicalNotesTable get _notes => attachedDatabase.clinicalNotes;
  $MedicalHistoriesTable get _histories => attachedDatabase.medicalHistories;
  $ImageRecordsTable get _images => attachedDatabase.imageRecords;

  // ---------------------------------------------------------------------------
  // Notes
  // ---------------------------------------------------------------------------

  Future<ClinicalNote> _writeNote(
    ActorContext ctx,
    ClinicalNote? before,
    ClinicalNote after, {
    AuditAction? action,
  }) {
    checkTenant(ctx, after.clinicId, 'note.clinicId');
    return audited(
      ctx: ctx,
      table: _notes,
      entityType: 'ClinicalNote',
      entityId: after.id,
      before: before,
      after: after,
      insertable: after.toInsertable(),
      toJson: (n) => n.toJson(),
      action: action,
    );
  }

  @override
  Future<ClinicalNote> saveNote(ActorContext ctx, ClinicalNote note) =>
      writeTransaction(() async {
        final before = await getNote(note.id);
        if (before == null || !before.isSigned) {
          return _writeNote(ctx, before, note);
        }
        final now = nowUtc();
        final next = ClinicalNote(
          id: newId(),
          clinicId: note.clinicId,
          patientId: note.patientId,
          visitId: note.visitId,
          authorId: ctx.actorId,
          chiefComplaint: note.chiefComplaint,
          historyOfPresentIllness: note.historyOfPresentIllness,
          pastDentalHistory: note.pastDentalHistory,
          pastMedicalHistory: note.pastMedicalHistory,
          personalHistory: note.personalHistory,
          extraoralExam: note.extraoralExam,
          intraoralExam: note.intraoralExam,
          provisionalDiagnosis: note.provisionalDiagnosis,
          investigations: note.investigations,
          finalDiagnosis: note.finalDiagnosis,
          treatmentDone: note.treatmentDone,
          advice: note.advice,
          followUp: note.followUp,
          freeText: note.freeText,
          version: before.version + 1,
          supersedesNoteId: before.id,
          createdAt: now,
          updatedAt: now,
        );
        return _writeNote(ctx, null, next);
      });

  @override
  Future<ClinicalNote> signNote(
    ActorContext ctx,
    String noteId, {
    DateTime? at,
  }) => writeTransaction(() async {
    final before = await getNote(noteId);
    if (before == null) throw StateError('Note $noteId not found');
    if (before.isSigned) return before;
    final now = nowUtc(at);
    return _writeNote(
      ctx,
      before,
      before.copyWith(signedAt: now, updatedAt: now),
      action: AuditAction.statusChange,
    );
  });

  @override
  Future<ClinicalNote?> getNote(String id) =>
      (select(_notes)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Keeps only notes that no other note in [all] supersedes.
  static List<ClinicalNote> _latestOnly(List<ClinicalNote> all) {
    final superseded = {
      for (final n in all)
        if (n.supersedesNoteId != null) n.supersedesNoteId!,
    };
    return all.where((n) => !superseded.contains(n.id)).toList();
  }

  @override
  Future<List<ClinicalNote>> notesForVisit(
    String visitId, {
    bool latestOnly = true,
  }) async {
    final all =
        await (select(_notes)
              ..where((t) => t.visitId.equals(visitId))
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
            .get();
    return latestOnly ? _latestOnly(all) : all;
  }

  @override
  Stream<List<ClinicalNote>> watchNotesForPatient(String patientId) =>
      (select(_notes)
            ..where((t) => t.patientId.equals(patientId))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch()
          .map(_latestOnly);

  @override
  Future<List<ClinicalNote>> noteVersions(String noteId) async {
    final start = await getNote(noteId);
    if (start == null) return const [];
    final all = await notesForVisit(start.visitId, latestOnly: false);
    final byId = {for (final n in all) n.id: n};
    var root = start;
    while (root.supersedesNoteId != null &&
        byId.containsKey(root.supersedesNoteId)) {
      root = byId[root.supersedesNoteId]!;
    }
    final chain = <ClinicalNote>[root];
    var current = root;
    while (true) {
      final next = all.where((n) => n.supersedesNoteId == current.id).toList();
      if (next.isEmpty) break;
      current = next.first;
      chain.add(current);
    }
    return chain;
  }

  // ---------------------------------------------------------------------------
  // Medical histories
  // ---------------------------------------------------------------------------

  @override
  Future<MedicalHistory> recordMedicalHistory(
    ActorContext ctx,
    MedicalHistory history,
  ) {
    checkTenant(ctx, history.clinicId, 'history.clinicId');
    return writeTransaction(() async {
      final existing = await (select(
        _histories,
      )..where((t) => t.id.equals(history.id))).getSingleOrNull();
      if (existing != null) {
        throw StateError('Medical history ${history.id} is append-only');
      }
      return audited<MedicalHistory>(
        ctx: ctx,
        table: _histories,
        entityType: 'MedicalHistory',
        entityId: history.id,
        before: null,
        after: history,
        insertable: history.toInsertable(),
        toJson: (h) => h.toJson(),
      );
    });
  }

  SimpleSelectStatement<$MedicalHistoriesTable, MedicalHistory> _histQuery(
    String patientId,
  ) => select(_histories)
    ..where((t) => t.patientId.equals(patientId))
    ..orderBy([
      (t) => OrderingTerm.desc(t.recordedAt),
      (t) => OrderingTerm.desc(t.createdAt),
    ]);

  @override
  Future<MedicalHistory?> latestMedicalHistory(String patientId) =>
      (_histQuery(patientId)..limit(1)).getSingleOrNull();

  @override
  Stream<MedicalHistory?> watchLatestMedicalHistory(String patientId) =>
      (_histQuery(patientId)..limit(1)).watchSingleOrNull();

  @override
  Future<List<MedicalHistory>> medicalHistories(String patientId) =>
      _histQuery(patientId).get();

  // ---------------------------------------------------------------------------
  // Images
  // ---------------------------------------------------------------------------

  Future<ImageRecord> _writeImage(ActorContext ctx, ImageRecord image) {
    checkTenant(ctx, image.clinicId, 'image.clinicId');
    return writeTransaction(
      () async => audited(
        ctx: ctx,
        table: _images,
        entityType: 'ImageRecord',
        entityId: image.id,
        before: await getImage(image.id),
        after: image,
        insertable: image.toInsertable(),
        toJson: (i) => i.toJson(),
      ),
    );
  }

  @override
  Future<ImageRecord> addImage(ActorContext ctx, ImageRecord image) =>
      _writeImage(ctx, image);

  @override
  Future<ImageRecord> updateImage(ActorContext ctx, ImageRecord image) =>
      _writeImage(ctx, image);

  @override
  Future<ImageRecord?> getImage(String id) =>
      (select(_images)..where((t) => t.id.equals(id))).getSingleOrNull();

  @override
  Future<List<ImageRecord>> imagesForPatient(
    String patientId, {
    ImageKind? kind,
    String? procedureId,
  }) =>
      (select(_images)
            ..where((t) {
              var where = t.patientId.equals(patientId);
              if (kind != null) where = where & t.kind.equalsValue(kind);
              if (procedureId != null) {
                where = where & t.procedureId.equals(procedureId);
              }
              return where;
            })
            ..orderBy([(t) => OrderingTerm.desc(t.capturedAt)]))
          .get();

  @override
  Stream<List<ImageRecord>> watchImages(String patientId) =>
      (select(_images)
            ..where((t) => t.patientId.equals(patientId))
            ..orderBy([(t) => OrderingTerm.desc(t.capturedAt)]))
          .watch();
}
