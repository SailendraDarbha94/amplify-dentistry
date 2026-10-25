import 'package:ampdent_core/ampdent_core.dart';

import 'actor_context.dart';

/// Procedure consents and DPDP data consents (never merged).
abstract class ConsentRepository {
  /// Stores a signed procedure consent (immutable thereafter).
  Future<ConsentRecord> recordConsent(ActorContext ctx, ConsentRecord consent);

  /// Consent by id.
  Future<ConsentRecord?> getConsent(String id);

  /// A patient's procedure consents, newest first.
  Future<List<ConsentRecord>> consentsForPatient(String patientId);

  /// Stream of a patient's procedure consents.
  Stream<List<ConsentRecord>> watchConsents(String patientId);

  /// Consents covering a procedure id.
  Future<List<ConsentRecord>> consentsForProcedure(String procedureId);

  /// Records a data-consent grant or refusal event. Append-only: an id that
  /// already exists throws [StateError]; a change of mind is a new row or a
  /// [withdrawDataConsent].
  Future<DataConsent> recordDataConsent(ActorContext ctx, DataConsent consent);

  /// Withdraws a granted data consent.
  Future<DataConsent> withdrawDataConsent(
    ActorContext ctx,
    String id, {
    DateTime? at,
  });

  /// All data-consent events for a patient, newest first.
  Future<List<DataConsent>> dataConsentsForPatient(String patientId);

  /// Stream of data-consent events.
  Stream<List<DataConsent>> watchDataConsents(String patientId);

  /// Latest event per purpose.
  Future<Map<DataPurpose, DataConsent>> latestDataConsents(String patientId);

  /// Whether the latest event for [purpose] is an active grant.
  Future<bool> hasActiveDataConsent(String patientId, DataPurpose purpose);
}
