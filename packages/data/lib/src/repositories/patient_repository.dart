import 'package:ampdent_core/ampdent_core.dart';

import 'actor_context.dart';

/// Patients of a clinic. Rows are never deleted; `isActive` hides them.
abstract class PatientRepository {
  /// Stream of patients, newest first, optionally filtered by [query]
  /// (name, phone or patient number, case-insensitive substring).
  Stream<List<Patient>> watchAll(
    String clinicId, {
    String? query,
    bool includeInactive = false,
  });

  /// Patient by id.
  Future<Patient?> getById(String id);

  /// Stream of one patient.
  Stream<Patient?> watchById(String id);

  /// Stream of the given patients (any order), for lists that resolve ids.
  Stream<List<Patient>> watchByIds(Iterable<String> ids);

  /// Creates or updates a patient (audited).
  Future<Patient> upsert(ActorContext ctx, Patient patient);

  /// Searches active patients by name, phone or patient number.
  Future<List<Patient>> search(String clinicId, String query, {int limit = 50});

  /// Active patients with exactly this phone (or alternate phone).
  Future<List<Patient>> findByPhone(String clinicId, String phone);

  /// Patient by clinic-local number.
  Future<Patient?> findByNumber(String clinicId, String patientNumber);

  /// Marks a patient inactive (soft delete, audited with [reason]).
  Future<Patient> deactivate(ActorContext ctx, String id, {String? reason});

  /// Number of active patients.
  Future<int> count(String clinicId);
}
