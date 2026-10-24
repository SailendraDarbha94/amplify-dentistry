import 'package:ampdent_core/ampdent_core.dart';

import 'actor_context.dart';

/// Clinical notes (versioned), medical histories (append-only) and images.
abstract class ClinicalRepository {
  /// Saves a note. An unsigned note is updated in place; saving over a
  /// signed note creates a new version (new id, `version + 1`,
  /// `supersedesNoteId` set, unsigned) and returns it.
  Future<ClinicalNote> saveNote(ActorContext ctx, ClinicalNote note);

  /// Signs a note, freezing it.
  Future<ClinicalNote> signNote(
    ActorContext ctx,
    String noteId, {
    DateTime? at,
  });

  /// Note by id.
  Future<ClinicalNote?> getNote(String id);

  /// Notes for a visit; by default only the latest version of each chain.
  Future<List<ClinicalNote>> notesForVisit(
    String visitId, {
    bool latestOnly = true,
  });

  /// Stream of a patient's notes, newest first (latest versions only).
  Stream<List<ClinicalNote>> watchNotesForPatient(String patientId);

  /// Every version in a note's chain, oldest first.
  Future<List<ClinicalNote>> noteVersions(String noteId);

  /// Appends a medical-history snapshot.
  Future<MedicalHistory> recordMedicalHistory(
    ActorContext ctx,
    MedicalHistory history,
  );

  /// Latest medical history, if any.
  Future<MedicalHistory?> latestMedicalHistory(String patientId);

  /// Stream of the latest medical history.
  Stream<MedicalHistory?> watchLatestMedicalHistory(String patientId);

  /// All snapshots, newest first.
  Future<List<MedicalHistory>> medicalHistories(String patientId);

  /// Adds an image record.
  Future<ImageRecord> addImage(ActorContext ctx, ImageRecord image);

  /// Updates an image record (tags, note, consent link).
  Future<ImageRecord> updateImage(ActorContext ctx, ImageRecord image);

  /// Image by id.
  Future<ImageRecord?> getImage(String id);

  /// Images for a patient, newest first, optionally filtered.
  Future<List<ImageRecord>> imagesForPatient(
    String patientId, {
    ImageKind? kind,
    String? procedureId,
  });

  /// Stream of a patient's images, newest first.
  Stream<List<ImageRecord>> watchImages(String patientId);
}
