import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_data/ampdent_data.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import 'core/app_shell.dart';
import 'core/cloud_auth.dart';
import 'core/cloud_lifecycle.dart';
import 'core/logging.dart';
import 'core/providers.dart';
import 'core/router.dart';
import 'core/session.dart';

/// Database file name on the device.
const String databaseName = 'ampdent.db';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  installLogging();
  await initializeDateFormatting('en_IN');
  final db = AppDatabase.open(databaseName);
  final session = await bootstrapSession(db);
  const config = CloudConfig.fromEnvironment();
  final client = await connectCloud(config);
  final continueOffline = await readContinueOffline(db);
  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        initialSessionProvider.overrideWithValue(session),
        cloudConfigProvider.overrideWithValue(config),
        cloudClientProvider.overrideWithValue(client),
        initialContinueOfflineProvider.overrideWithValue(continueOffline),
      ],
      child: const AmpDentApp(),
    ),
  );
}

/// Initialises `supabase_flutter` (session persistence, auth refresh) when
/// [config] names a project; returns null, and the app runs offline-only,
/// when it does not. Only the anon key is used here.
Future<SupabaseClient?> connectCloud(CloudConfig config) async {
  if (!config.isConfigured) {
    const Logger('cloud').info('no SUPABASE_URL; running offline-only');
    return null;
  }
  try {
    await Supabase.initialize(
      url: config.url,
      publishableKey: config.anonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
    const Logger('cloud').info('connected to ${config.projectRef}');
    return Supabase.instance.client;
  } on Object catch (e, st) {
    const Logger('cloud')
        .error('Supabase init failed: ${e.runtimeType}', stackTrace: st);
    return null;
  }
}

/// Root widget: theme, localisation and router. The first-run gate lives in
/// the router redirect (no clinic -> `/onboarding`).
class AmpDentApp extends ConsumerWidget {
  /// Creates the app.
  const AmpDentApp({super.key});

  /// Locales the app ships with; English (India) first.
  static const List<Locale> supportedLocales = [
    Locale('en', 'IN'),
    Locale('en'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return AppStringsScope(
      strings: AppStrings.en,
      child: CloudLifecycle(
        child: MaterialApp.router(
          title: AppStrings.en.appName,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          routerConfig: router,
          scaffoldMessengerKey: rootScaffoldMessengerKey,
          locale: supportedLocales.first,
          supportedLocales: supportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}
