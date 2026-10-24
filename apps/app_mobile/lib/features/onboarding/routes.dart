import 'package:go_router/go_router.dart';

import 'onboarding_page.dart';

/// First-run flow, outside the tab shell.
final List<RouteBase> onboardingRoutes = [
  GoRoute(
    path: '/onboarding',
    builder: (context, state) => const OnboardingPage(),
  ),
];
