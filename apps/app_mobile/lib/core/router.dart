/// go_router configuration: a [StatefulShellRoute] with four tab branches
/// (Today, Patients, Schedule, More) and the onboarding flow outside the
/// shell. Every feature registers its own routes in
/// `lib/features/<feature>/routes.dart`; this file only spreads them.
library;

import 'package:ampdent_mobile/features/appointments/routes.dart';
import 'package:ampdent_mobile/features/auth/routes.dart';
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

/// Sign-in page (step 0 of a fresh install when the cloud is configured;
/// also reachable later from Settings > Account).
const String signInLocation = '/sign-in';

/// Decides where a navigation must be redirected given whether a clinic
/// exists and whether the sign-in gate is up (cloud configured, nobody
/// signed in, no clinic, "continue offline" not chosen). Returns null to
/// allow [location] unchanged. The sign-in page is always reachable.
String? sessionRedirect({
  required bool hasClinic,
  required String location,
  bool signInGate = false,
}) {
  if (location.startsWith(signInLocation)) return null;
  final onOnboarding = location.startsWith(onboardingLocation);
  if (!hasClinic) {
    if (signInGate) return signInLocation;
    return onOnboarding ? null : onboardingLocation;
  }
  return onOnboarding ? homeLocation : null;
}

/// Builds the router. [initialLocation] defaults to [homeLocation]; the
/// redirect sends a fresh install to sign-in or onboarding regardless.
GoRouter buildRouter({
  required bool Function() hasClinic,
  bool Function()? signInGate,
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
      signInGate: signInGate?.call() ?? false,
      location: state.matchedLocation,
    ),
    routes: [
      ...onboardingRoutes,
      ...authRoutes,
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
              ...accountRoutes,
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
  ref.listen(signInGateProvider, (previous, next) => refresh.bump());
  final router = buildRouter(
    hasClinic: () => ref.read(appSessionProvider).hasClinic,
    signInGate: () => ref.read(signInGateProvider),
    refreshListenable: refresh,
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
