import 'package:ampdent_core/ampdent_core.dart';

/// Provider and opt-in bookkeeping on a [MessageLog].
///
/// Since `MessageLog.provider` and `MessageLog.optInReason` exist, new rows
/// carry both as real fields. Rows queued by older builds stamped the same
/// facts inside `variables` under keys that start with `_`
/// ([LegacyMessageLogKeys]); every reader here falls back to those stamps,
/// so old rows keep their meaning. Template placeholders never start with
/// `_` (see the catalogue tests), and [templateOnly] strips the legacy keys
/// before rendering.
abstract final class MessageLogKeys {
  /// Legacy `variables` key of the provider stamp (`_provider`).
  static const String provider = LegacyMessageLogKeys.provider;

  /// Legacy `variables` key of the opt-in reason stamp (`_opt_in_reason`).
  static const String optInReason = LegacyMessageLogKeys.optInReason;

  /// Rows the sync worker hands to the Meta Cloud API Edge Function.
  static const String cloudApiProvider = 'cloud_api';

  /// Rows launched from the dentist's own phone via wa.me / sms:.
  static const String deepLinkProvider = 'deeplink';

  /// Provider wire name recorded on [log]: the `provider` field, else the
  /// legacy stamp, else null for rows queued before either existed (treat
  /// those as [cloudApiProvider] when draining the outbox).
  static String? providerOf(MessageLog log) =>
      log.provider?.wireName ??
      MessageProvider.tryParse(log.variables[provider])?.wireName;

  /// Whether [log] is for the Cloud API worker (unstamped rows included).
  static bool isCloudApi(MessageLog log) {
    final p = providerOf(log);
    return p == null || p == cloudApiProvider;
  }

  /// Opt-in reason recorded on [log]: the field, else the legacy stamp.
  static String? optInReasonOf(MessageLog log) =>
      log.optInReason ?? log.variables[optInReason];

  /// [variables] plus the legacy reserved keys. Kept for callers that still
  /// build rows for older readers; new rows should set `MessageLog.provider`
  /// and `MessageLog.optInReason` instead.
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
