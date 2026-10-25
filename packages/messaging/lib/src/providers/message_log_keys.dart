import 'package:ampdent_core/ampdent_core.dart';

/// Reserved keys inside `MessageLog.variables`.
///
/// `MessageLog` (in `ampdent_core`) has no `provider` field yet, so the
/// provider that queued a row and the opt-in reason that allowed it travel
/// inside `variables` under keys that start with `_`. Template placeholders
/// never start with `_` (see the catalogue tests), so the keys cannot collide
/// with a body variable, and the Edge Function reads only the template's
/// declared `bodyParams`, so they never reach Meta.
abstract final class MessageLogKeys {
  /// Which backend owns delivery: [cloudApiProvider] or [deepLinkProvider].
  static const String provider = '_provider';

  /// `SendDecision.reason` that allowed the send (DPDP audit trail).
  static const String optInReason = '_opt_in_reason';

  /// Rows the sync worker hands to the Meta Cloud API Edge Function.
  static const String cloudApiProvider = 'cloud_api';

  /// Rows launched from the dentist's own phone via wa.me / sms:.
  static const String deepLinkProvider = 'deeplink';

  /// Provider recorded on [log], or null for rows queued before this key
  /// existed (treat those as [cloudApiProvider] when draining the outbox).
  static String? providerOf(MessageLog log) => log.variables[provider];

  /// Whether [log] is for the Cloud API worker (unstamped rows included).
  static bool isCloudApi(MessageLog log) {
    final p = providerOf(log);
    return p == null || p == cloudApiProvider;
  }

  /// Opt-in reason recorded on [log], if any.
  static String? optInReasonOf(MessageLog log) => log.variables[optInReason];

  /// [variables] plus the reserved keys; template values win no conflicts
  /// because reserved keys are not valid template placeholders in practice.
  static Map<String, String> stamp(
    Map<String, String> variables, {
    required String providerName,
    String? reason,
  }) => {...variables, provider: providerName, optInReason: ?reason};

  /// [variables] without any reserved key: what a template is rendered from.
  static Map<String, String> templateOnly(Map<String, String> variables) => {
    for (final e in variables.entries)
      if (!e.key.startsWith('_')) e.key: e.value,
  };
}
