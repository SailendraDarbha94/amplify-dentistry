/// go_router configuration: a [StatefulShellRoute] with four tab branches
/// (Today, Patients, Schedule, More) and the onboarding flow outside the
/// shell. Every feature registers its own routes in
/// `lib/features/<feature>/routes.dart`; this file only spreads them.
library;

import 'package:ampdent_mobile/features/appointments/routes.dart';
import 'package:ampdent_mobile/features/billing/routes.dart';
import 'package:ampdent_mobile/features/chart/routes.dart';
import 'package:ampdent_mobile/features/compliance/routes.dart';
import 'package:ampdent_mobile/features/consent/routes.dart';
import 'package:ampdent_mobile/features/export/routes.dart';
import 'package:ampdent_mobile/features/lab/routes.dart';
import 'package:ampdent_mobile/features/more/routes.dart';
import 'package:ampdent_mobile/features/notes/routes.dart';
import 'package:ampdent_mobile/features/onboarding/routes.dart';
import 'package:ampdent_mobile/features/patients/routes.dart';
import 'package:ampdent_mobile/features/plan/routes.dart';
import 'package:ampdent_mobile/features/prescriptions/routes.dart';
import 'package:ampdent_mobile/features/recall/routes.dart';
import 'package:ampdent_mobile/features/settings/routes.dart';
import 'package:ampdent_mobile/features/today/routes.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app_shell.dart';
import 'navigation_keys.dart';
import 'providers.dart';

export 'navigation_keys.dart';

/// Where the app lands after launch and after onboarding.
const String homeLocation = '/today';

/// First-run flow location.
const String onboardingLocation = '/onboarding';

/// Decides where a navigation must be redirected given whether a clinic
/// exists. Returns null to allow [location] unchanged.
String? sessionRedirect({required bool hasClinic, required String location}) {
  final onOnboarding = location.startsWith(onboardingLocation);
  if (!hasClinic) return onOnboarding ? null : onboardingLocation;
  return onOnboarding ? homeLocation : null;
}

/// Builds the router. [initialLocation] defaults to [homeLocation]; the
/// redirect sends a fresh install to onboarding regardless.
GoRouter buildRouter({
  required bool Function() hasClinic,
  Listenable? refreshListenable,
  String initialLocation = homeLocation,
}) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: initialLocation,
    debugLogDiagnostics: kDebugMode,
    refreshListenable: refreshListenable,
    redirect: (context, state) => sessionRedirect(
      hasClinic: hasClinic(),
      location: state.matchedLocation,
    ),
    routes: [
      ...onboardingRoutes,
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [...todayRoutes, ...recallRoutes, ...labRoutes],
          ),
          StatefulShellBranch(
            routes: [
              ...patientsRoutes,
              ...chartRoutes,
              ...planRoutes,
              ...consentRoutes,
              ...notesRoutes,
              ...prescriptionsRoutes,
              ...billingRoutes,
            ],
          ),
          StatefulShellBranch(routes: [...appointmentsRoutes]),
          StatefulShellBranch(
            routes: [
              ...moreRoutes,
              ...settingsRoutes,
              ...complianceRoutes,
              ...exportRoutes,
            ],
          ),
        ],
      ),
    ],
  );
}

/// Notifies go_router when the session changes so the redirect re-runs.
class _SessionRefresh extends ChangeNotifier {
  void bump() => notifyListeners();
}

/// The app router, rebuilt never; it re-evaluates redirects when the
/// session changes.
final Provider<GoRouter> routerProvider = Provider<GoRouter>((ref) {
  final refresh = _SessionRefresh();
  ref.listen(appSessionProvider, (previous, next) => refresh.bump());
  final router = buildRouter(
    hasClinic: () => ref.read(appSessionProvider).hasClinic,
    refreshListenable: refresh,
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
