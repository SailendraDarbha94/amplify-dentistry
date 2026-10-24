import 'package:ampdent_core/ampdent_core.dart';

import 'actor_context.dart';

/// Clinic (tenant) master data: the clinic row, chairs, members, settings
/// (GST rate history, display notation) and numbering counters.
abstract class ClinicRepository {
  /// Clinic by id.
  Future<Clinic?> getClinic(String clinicId);

  /// Stream of the clinic row.
  Stream<Clinic?> watchClinic(String clinicId);

  /// Creates the clinic and seeds its default settings (GST rates, notation,
  /// counters) in one transaction. [ctx.clinicId] must equal [clinic.id].
  Future<Clinic> createClinic(ActorContext ctx, Clinic clinic);

  /// Updates the clinic row.
  Future<Clinic> updateClinic(ActorContext ctx, Clinic clinic);

  /// Chairs ordered by `sortOrder`.
  Future<List<Chair>> chairs(String clinicId, {bool includeInactive = false});

  /// Stream of chairs ordered by `sortOrder`.
  Stream<List<Chair>> watchChairs(
    String clinicId, {
    bool includeInactive = false,
  });

  /// Creates or updates a chair.
  Future<Chair> upsertChair(ActorContext ctx, Chair chair);

  /// Marks a chair inactive (soft delete).
  Future<Chair> deactivateChair(ActorContext ctx, String chairId);

  /// Members ordered by display name.
  Future<List<ClinicMember>> members(
    String clinicId, {
    bool includeInactive = false,
  });

  /// Stream of members.
  Stream<List<ClinicMember>> watchMembers(
    String clinicId, {
    bool includeInactive = false,
  });

  /// Member by id.
  Future<ClinicMember?> getMember(String memberId);

  /// Creates or updates a member.
  Future<ClinicMember> upsertMember(ActorContext ctx, ClinicMember member);

  /// Marks a member inactive (soft delete).
  Future<ClinicMember> deactivateMember(
    ActorContext ctx,
    String memberId, {
    String? reason,
  });

  /// Raw JSON value of a setting.
  Future<String?> getSetting(String clinicId, String key);

  /// Stream of a setting's raw JSON value.
  Stream<String?> watchSetting(String clinicId, String key);

  /// Writes a setting (audited as a settings change).
  Future<void> setSetting(ActorContext ctx, String key, String valueJson);

  /// GST rate history as a table (India defaults when unset).
  Future<GstRateTable> loadGstRateTable(String clinicId);

  /// GST rate history rows (empty when unset).
  Future<List<GstRate>> loadGstRates(String clinicId);

  /// Replaces the GST rate history.
  Future<void> saveGstRates(ActorContext ctx, List<GstRate> rates);

  /// Display notation (FDI when unset).
  Future<ToothNotation> loadNotation(String clinicId);

  /// Saves the display notation.
  Future<void> saveNotation(ActorContext ctx, ToothNotation notation);

  /// Mints the next patient number: `P-00001`, `P-00002`, ...
  Future<String> nextPatientNumber(ActorContext ctx);

  /// Mints the next local draft invoice number (`DRAFT-INV-yyyyMM-0001`).
  Future<String> nextDraftInvoiceNumber(ActorContext ctx, {DateTime? now});

  /// Mints the next local draft estimate number (`DRAFT-EST-yyyyMM-0001`).
  Future<String> nextDraftEstimateNumber(ActorContext ctx, {DateTime? now});
}
