import 'package:ampdent_data/ampdent_data.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

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
  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        initialSessionProvider.overrideWithValue(session),
      ],
      child: const AmpDentApp(),
    ),
  );
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
      child: MaterialApp.router(
        title: AppStrings.en.appName,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        routerConfig: router,
        locale: supportedLocales.first,
        supportedLocales: supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
