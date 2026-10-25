/// The clinic's WhatsApp Cloud API configuration on the server: status via
/// `get_whatsapp_status`, writes via `set_whatsapp_config` and
/// `set_whatsapp_enabled`. The access token goes straight to the RPC (and
/// from there to Supabase Vault); nothing here ever stores it on the phone.
library;

import 'package:ampdent_core/ampdent_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import 'clinic_link.dart';
import 'providers.dart';

/// Result of `get_whatsapp_status`.
@immutable
class WhatsAppStatus {
  /// Creates a status.
  const WhatsAppStatus({
    required this.configured,
    required this.enabled,
    this.phoneNumberId,
    this.wabaId,
    this.displayPhone,
    this.updatedAt,
    this.queuedCount = 0,
    this.failedLast24h = 0,
  });

  /// Nothing configured for the clinic yet.
  static const WhatsAppStatus none = WhatsAppStatus(
    configured: false,
    enabled: false,
  );

  /// Whether a phone number id and token are on file.
  final bool configured;

  /// Whether sending is switched on.
  final bool enabled;

  /// Meta phone number id (digits).
  final String? phoneNumberId;

  /// WhatsApp Business Account id.
  final String? wabaId;

  /// Number as shown to patients.
  final String? displayPhone;

  /// Last config change.
  final DateTime? updatedAt;

  /// Cloud API rows waiting on the server.
  final int queuedCount;

  /// Rows that failed in the last 24 hours.
  final int failedLast24h;

  /// Whether the Cloud API provider should be used for sends.
  bool get isActive => configured && enabled;

  /// Parses the RPC's jsonb.
  factory WhatsAppStatus.fromJson(Map<String, Object?> json) => WhatsAppStatus(
    configured: json['configured'] == true,
    enabled: json['enabled'] == true,
    phoneNumberId: json['phoneNumberId'] as String?,
    wabaId: json['wabaId'] as String?,
    displayPhone: json['displayPhone'] as String?,
    updatedAt: json['updatedAt'] == null
        ? null
        : DateTime.tryParse('${json['updatedAt']}')?.toUtc(),
    queuedCount: (json['queuedCount'] as num?)?.toInt() ?? 0,
    failedLast24h: (json['failedLast24h'] as num?)?.toInt() ?? 0,
  );

  /// JSON form (for tests and diagnostics).
  Map<String, Object?> toJson() => {
    'configured': configured,
    'enabled': enabled,
    'phoneNumberId': phoneNumberId,
    'wabaId': wabaId,
    'displayPhone': displayPhone,
    'updatedAt': updatedAt?.toIso8601String(),
    'queuedCount': queuedCount,
    'failedLast24h': failedLast24h,
  };
}

/// Validation for the config form, shared with the tests.
abstract final class WhatsAppConfigValidators {
  /// Digits only, 5-20 long.
  static String? digits(String? value, String label) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return '$label is required';
    if (!RegExp(r'^\d{5,20}$').hasMatch(v)) return '$label must be digits';
    return null;
  }

  /// At least 20 characters (the RPC refuses shorter tokens).
  static String? accessToken(String? value) {
    final v = (value ?? '').trim();
    if (v.length < 20) return 'Paste the permanent access token';
    return null;
  }

  /// 8-128 characters.
  static String? verifyToken(String? value) {
    final v = (value ?? '').trim();
    if (v.length < 8 || v.length > 128) {
      return 'Verify token must be 8 to 128 characters';
    }
    return null;
  }
}

/// RPC wrapper over the public `*_whatsapp_*` functions.
class WhatsAppCloudService {
  /// Creates the service.
  const WhatsAppCloudService(this.client);

  static const Logger _log = Logger('whatsapp-cloud');

  /// Supabase client (RPC only).
  final SupabaseClient client;

  /// Current status for [clinicId].
  Future<WhatsAppStatus> status(String clinicId) async {
    final result = await client.rpc<Object?>(
      'get_whatsapp_status',
      params: {'p_clinic': clinicId},
    );
    if (result is! Map) return WhatsAppStatus.none;
    return WhatsAppStatus.fromJson(result.cast<String, Object?>());
  }

  /// Saves or rotates the configuration. The token is sent once and is not
  /// kept anywhere on the device; callers clear their field afterwards.
  Future<void> saveConfig({
    required String clinicId,
    required String phoneNumberId,
    required String wabaId,
    required String displayPhone,
    required String accessToken,
    required String verifyToken,
  }) async {
    await client.rpc<Object?>(
      'set_whatsapp_config',
      params: {
        'p_clinic': clinicId,
        'p_phone_number_id': phoneNumberId.trim(),
        'p_waba_id': wabaId.trim(),
        'p_display_phone': displayPhone.trim(),
        'p_access_token': accessToken.trim(),
        'p_verify_token': verifyToken.trim(),
      },
    );
    _log.info('whatsapp config saved');
  }

  /// Pauses or resumes sending without touching the token.
  Future<void> setEnabled(String clinicId, bool enabled) async {
    await client.rpc<Object?>(
      'set_whatsapp_enabled',
      params: {'p_clinic': clinicId, 'p_enabled': enabled},
    );
    _log.info('whatsapp ${enabled ? 'enabled' : 'disabled'}');
  }
}

/// The service, or null without a client.
final Provider<WhatsAppCloudService?> whatsappCloudServiceProvider =
    Provider<WhatsAppCloudService?>((ref) {
      final client = ref.watch(cloudClientProvider);
      return client == null ? null : WhatsAppCloudService(client);
    });

/// WhatsApp status of the current clinic; null when the cloud is not
/// configured, nobody is signed in or the device is not linked. Refresh
/// with `ref.invalidate`.
final FutureProvider<WhatsAppStatus?> whatsappStatusProvider =
    FutureProvider<WhatsAppStatus?>((ref) async {
      final service = ref.watch(whatsappCloudServiceProvider);
      final clinicId = ref.watch(currentClinicIdProvider);
      final signedIn = ref.watch(cloudAuthProvider.select((s) => s.isSignedIn));
      if (service == null || clinicId == null || !signedIn) return null;
      final linked = ref.watch(
        clinicLinkProvider.select((s) => s.isLinkedTo(clinicId)),
      );
      if (!linked) return null;
      return service.status(clinicId);
    });
