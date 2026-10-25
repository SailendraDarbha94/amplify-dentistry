/// This device and its peers in `public.devices`: the platform name sent at
/// registration and the list shown on the account page.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'clinic_link.dart';
import 'providers.dart';

/// `android`, `ios` or `other` for the `devices.platform` column.
String devicePlatformName() => switch (defaultTargetPlatform) {
  TargetPlatform.android => 'android',
  TargetPlatform.iOS => 'ios',
  _ => 'other',
};

/// One row of `public.devices`.
@immutable
class RemoteDevice {
  /// Creates a device.
  const RemoteDevice({
    required this.id,
    required this.platform,
    required this.appVersion,
    required this.lastSeenAt,
    required this.isPrimary,
  });

  /// Device id (the one on the audit trail).
  final String id;

  /// `android`, `ios` or `other`.
  final String platform;

  /// App version at last heartbeat.
  final String appVersion;

  /// Last heartbeat.
  final DateTime? lastSeenAt;

  /// Whether this is the clinic's primary device.
  final bool isPrimary;

  /// Parses a PostgREST row.
  factory RemoteDevice.fromJson(Map<String, Object?> json) => RemoteDevice(
    id: '${json['id']}',
    platform: '${json['platform'] ?? 'other'}',
    appVersion: '${json['app_version'] ?? ''}',
    lastSeenAt: json['last_seen_at'] == null
        ? null
        : DateTime.tryParse('${json['last_seen_at']}')?.toUtc(),
    isPrimary: json['is_primary'] == true,
  );
}

/// Devices registered for the current clinic; empty when not linked.
final FutureProvider<List<RemoteDevice>> remoteDevicesProvider =
    FutureProvider<List<RemoteDevice>>((ref) async {
      final client = ref.watch(cloudClientProvider);
      final clinicId = ref.watch(currentClinicIdProvider);
      final linked =
          clinicId != null &&
          ref.watch(clinicLinkProvider.select((s) => s.isLinkedTo(clinicId)));
      if (client == null || !linked) return const [];
      final rows = await client
          .from('devices')
          .select()
          .eq('clinic_id', clinicId)
          .order('last_seen_at', ascending: false);
      return [for (final r in rows) RemoteDevice.fromJson(r)];
    });
