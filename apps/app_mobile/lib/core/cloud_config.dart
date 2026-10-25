/// Cloud configuration: the Supabase project the app talks to, read from
/// `--dart-define-from-file=env.json` (`SUPABASE_URL`, `SUPABASE_ANON_KEY`).
/// With both values empty the app runs fully offline: `NoopSyncEngine`,
/// deep-link messaging, and "Cloud not configured" in settings.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

/// Version string reported in the `devices` table and on the About page.
const String appBuildVersion = '0.1.0';

/// Supabase project coordinates. Only the anon key ever ships in the app.
@immutable
class CloudConfig {
  /// Creates a config; empty strings mean "not configured".
  const CloudConfig({this.url = '', this.anonKey = ''});

  /// Reads `SUPABASE_URL` and `SUPABASE_ANON_KEY` from the dart-defines.
  const CloudConfig.fromEnvironment()
    : this(
        url: const String.fromEnvironment('SUPABASE_URL'),
        anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
      );

  /// Project URL (`https://<ref>.supabase.co`).
  final String url;

  /// Anon (publishable) key.
  final String anonKey;

  /// Whether both values are present.
  bool get isConfigured => url.trim().isNotEmpty && anonKey.trim().isNotEmpty;

  /// Project ref (the host's first label), for display.
  String get projectRef {
    final host = Uri.tryParse(url)?.host ?? '';
    return host.split('.').first;
  }

  @override
  String toString() =>
      'CloudConfig(${isConfigured ? projectRef : 'not configured'})';
}

/// The cloud configuration; `main` and tests override it.
final Provider<CloudConfig> cloudConfigProvider = Provider<CloudConfig>(
  (ref) => const CloudConfig.fromEnvironment(),
);

/// The Supabase client, or null when the cloud is not configured. `main`
/// overrides it with `Supabase.instance.client`; tests inject a client over
/// a `MockClient`.
final Provider<SupabaseClient?> cloudClientProvider = Provider<SupabaseClient?>(
  (ref) => null,
);

/// Whether a project is configured and a client exists.
final Provider<bool> cloudActiveProvider = Provider<bool>(
  (ref) =>
      ref.watch(cloudConfigProvider).isConfigured &&
      ref.watch(cloudClientProvider) != null,
);

/// Whether the `SyncScheduler` may start its timers. Tests override this to
/// false so the widget binding sees no pending periodic timers.
final Provider<bool> schedulerEnabledProvider = Provider<bool>((ref) => true);
