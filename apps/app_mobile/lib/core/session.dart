import 'dart:convert';

import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_data/ampdent_data.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// App-level setting keys stored in the per-clinic `settings` table.
abstract final class AppSettingKeys {
  /// Stable id of this device, generated on first run and never changed.
  static const String deviceId = 'device.id';

  /// Member the app acts as (single-user device; switchable in settings).
  static const String activeMemberId = 'session.activeMemberId';
}

/// Who the app is acting as on this device. [clinicId] is null until the
/// first-run onboarding has created a clinic.
@immutable
class AppSession {
  /// Creates a session.
  const AppSession({required this.deviceId, this.clinicId, this.memberId});

  /// Device id (persisted under [AppSettingKeys.deviceId] once a clinic
  /// exists; before that it lives in memory and is written by onboarding).
  final String deviceId;

  /// Current clinic, or null on a fresh install.
  final String? clinicId;

  /// Member performing writes, or null when no clinic exists yet.
  final String? memberId;

  /// Whether onboarding has completed.
  bool get hasClinic => clinicId != null && clinicId!.isNotEmpty;

  /// Actor for repository writes; throws when onboarding is incomplete.
  ActorContext get actor {
    if (!hasClinic || memberId == null) {
      throw StateError('No clinic on this device yet; complete onboarding');
    }
    return ActorContext(
      clinicId: clinicId!,
      actorId: memberId!,
      deviceId: deviceId,
    );
  }

  /// Returns a copy with the given fields replaced.
  AppSession copyWith({String? clinicId, String? memberId}) => AppSession(
    deviceId: deviceId,
    clinicId: clinicId ?? this.clinicId,
    memberId: memberId ?? this.memberId,
  );

  @override
  String toString() =>
      'AppSession(clinic: $clinicId, member: $memberId, device: $deviceId)';
}

/// Lists every clinic row in the local store (a device normally holds one).
Future<List<Clinic>> listLocalClinics(AppDatabase db) =>
    db.select(db.clinics).get();

/// Resolves the session for this device from the local database: the first
/// clinic, its persisted device id (minted and stored when missing) and the
/// active member (persisted choice, else the owner dentist, else the first
/// active member).
Future<AppSession> bootstrapSession(AppDatabase db) async {
  const log = Logger('session');
  final clinics = await listLocalClinics(db);
  if (clinics.isEmpty) {
    log.info('no clinic yet; first run');
    return AppSession(deviceId: newId());
  }
  final clinic = clinics.first;
  final repo = DriftClinicRepository(db);
  final members = await repo.members(clinic.id);
  final memberId = await _resolveMemberId(repo, clinic.id, members);
  var deviceId = decodeStringSetting(
    await repo.getSetting(clinic.id, AppSettingKeys.deviceId),
  );
  if (deviceId == null || deviceId.isEmpty) {
    deviceId = newId();
    await repo.setSetting(
      ActorContext(
        clinicId: clinic.id,
        actorId: memberId ?? 'system',
        deviceId: deviceId,
      ),
      AppSettingKeys.deviceId,
      encodeStringSetting(deviceId),
    );
  }
  return AppSession(
    deviceId: deviceId,
    clinicId: clinic.id,
    memberId: memberId,
  );
}

Future<String?> _resolveMemberId(
  ClinicRepository repo,
  String clinicId,
  List<ClinicMember> members,
) async {
  final stored = decodeStringSetting(
    await repo.getSetting(clinicId, AppSettingKeys.activeMemberId),
  );
  if (stored != null && members.any((m) => m.id == stored)) return stored;
  for (final m in members) {
    if (m.role == ClinicRole.ownerDentist) return m.id;
  }
  return members.isEmpty ? null : members.first.id;
}

/// Encodes a plain string for the JSON-valued settings table.
String encodeStringSetting(String value) => jsonEncode(value);

/// Decodes a string setting; null or malformed input yields null.
String? decodeStringSetting(String? json) {
  if (json == null) return null;
  try {
    final decoded = jsonDecode(json);
    return decoded is String ? decoded : null;
  } on FormatException {
    return null;
  }
}

/// Initial session resolved in `main` before the widget tree is built;
/// overridden there and in tests.
final Provider<AppSession> initialSessionProvider = Provider<AppSession>(
  (ref) => throw UnimplementedError(
    'initialSessionProvider must be overridden with bootstrapSession()',
  ),
);

/// Mutable session state: updated when onboarding completes and when the
/// active member is switched.
final NotifierProvider<AppSessionNotifier, AppSession> appSessionProvider =
    NotifierProvider<AppSessionNotifier, AppSession>(AppSessionNotifier.new);

/// Holds the [AppSession] and persists changes to it.
class AppSessionNotifier extends Notifier<AppSession> {
  @override
  AppSession build() => ref.watch(initialSessionProvider);

  /// Marks onboarding complete and persists device id and active member.
  Future<void> activate({
    required ClinicRepository clinics,
    required String clinicId,
    required String memberId,
  }) async {
    final ctx = ActorContext(
      clinicId: clinicId,
      actorId: memberId,
      deviceId: state.deviceId,
    );
    await clinics.setSetting(
      ctx,
      AppSettingKeys.deviceId,
      encodeStringSetting(state.deviceId),
    );
    await clinics.setSetting(
      ctx,
      AppSettingKeys.activeMemberId,
      encodeStringSetting(memberId),
    );
    state = state.copyWith(clinicId: clinicId, memberId: memberId);
  }

  /// Switches the member the device acts as and persists the choice.
  Future<void> switchMember({
    required ClinicRepository clinics,
    required String memberId,
  }) async {
    await clinics.setSetting(
      state.actor,
      AppSettingKeys.activeMemberId,
      encodeStringSetting(memberId),
    );
    state = state.copyWith(memberId: memberId);
  }
}
