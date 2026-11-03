/// Device registry heartbeat: `devices.last_seen_at`, `app_version` and
/// `platform` for this install, written at most once per interval.
library;

import 'package:ampdent_core/ampdent_core.dart';
import 'package:supabase/supabase.dart';

import 'sync_errors.dart';
import 'sync_state_repository.dart';

/// Platform value of `devices.platform` (server check constraint); the
/// enum name is the wire value.
enum DevicePlatform {
  /// Android.
  android,

  /// iOS.
  ios,

  /// Anything else (desktop test builds).
  other,
}

/// What the app knows about this install; the engine sends it with the
/// heartbeat.
class DeviceInfo {
  /// Creates the value.
  const DeviceInfo({required this.appVersion, required this.platform});

  /// App version as shown in Settings (`1.2.0+45`; `devices.app_version`).
  final String appVersion;

  /// Platform (`devices.platform`).
  final DevicePlatform platform;

  /// Columns of a `devices` row.
  Map<String, Object?> toJson() => {
    'platform': platform.name,
    'app_version': appVersion,
  };

  @override
  bool operator ==(Object other) =>
      other is DeviceInfo &&
      other.platform == platform &&
      other.appVersion == appVersion;

  @override
  int get hashCode => Object.hash(platform, appVersion);

  @override
  String toString() => 'DeviceInfo(${platform.name} $appVersion)';
}

/// Upserts this device's `devices` row (keyed by the sync-state device id)
/// at most once per [interval]. Failures are logged, never thrown: a
/// heartbeat must not fail a push.
class DeviceHeartbeat {
  /// Creates the heartbeat.
  DeviceHeartbeat({
    required this.client,
    required this.syncState,
    required this.clinicId,
    required this.info,
    this.interval = const Duration(minutes: 15),
    DateTime Function()? clock,
  }) : _clock = clock ?? _utcNow;

  static const Logger _log = Logger('DeviceHeartbeat');

  static DateTime _utcNow() => DateTime.now().toUtc();

  /// Supabase client (REST only).
  final SupabaseClient client;

  /// Holds the device id and the last heartbeat time.
  final SyncStateRepository syncState;

  /// Clinic this device belongs to.
  final String clinicId;

  /// Values sent.
  final DeviceInfo info;

  /// Minimum gap between two heartbeats.
  final Duration interval;

  final DateTime Function() _clock;
  DateTime? _lastBeatAt;

  /// Number of rows written so far (diagnostics and tests).
  int beats = 0;

  /// Sends the heartbeat when the last one is older than [interval] (or
  /// [force] is set). Returns whether a row was written.
  Future<bool> beat({bool force = false}) async {
    final now = _clock();
    final last = _lastBeatAt ??= await syncState.readInstant(
      SyncStateKeys.lastHeartbeatAt,
    );
    if (!force && last != null && now.difference(last) < interval) {
      return false;
    }
    final deviceId = await syncState.ensureDeviceId();
    try {
      await client
          .from('devices')
          .upsert(
            {
              'id': deviceId,
              'clinic_id': clinicId,
              ...info.toJson(),
              'last_seen_at': now.toIso8601String(),
            },
            onConflict: 'id',
            defaultToNull: false,
          );
    } catch (e) {
      final failure = classifySyncError(e, table: 'devices');
      _log.warning('heartbeat skipped: ${failure.message}');
      return false;
    }
    _lastBeatAt = now;
    beats++;
    await syncState.writeInstant(SyncStateKeys.lastHeartbeatAt, now);
    _log.debug('heartbeat written');
    return true;
  }
}
