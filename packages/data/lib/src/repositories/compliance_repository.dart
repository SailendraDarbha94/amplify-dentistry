import 'package:ampdent_core/ampdent_core.dart';

import 'actor_context.dart';

/// Sterilisation register and licence tracking.
abstract class ComplianceRepository {
  /// Records a sterilisation cycle. An empty `cycleNumber` gets a minted
  /// `SC-00001` number.
  Future<SterilisationCycle> recordCycle(
    ActorContext ctx,
    SterilisationCycle cycle,
  );

  /// Cycles in `[from, to)`, newest first.
  Future<List<SterilisationCycle>> cycles(
    String clinicId, {
    DateTime? from,
    DateTime? to,
  });

  /// Stream of the most recent cycles.
  Stream<List<SterilisationCycle>> watchRecentCycles(
    String clinicId, {
    int limit = 50,
  });

  /// Creates or updates a licence.
  Future<Licence> upsertLicence(ActorContext ctx, Licence licence);

  /// Licences of a clinic.
  Future<List<Licence>> licences(String clinicId);

  /// Stream of licences.
  Stream<List<Licence>> watchLicences(String clinicId);

  /// Licences whose expiry or QA due date falls within [withinDays] of
  /// [asOf] (or has passed), soonest first.
  Future<List<Licence>> expiringSoon(
    String clinicId, {
    DateTime? asOf,
    int withinDays = 60,
  });
}
