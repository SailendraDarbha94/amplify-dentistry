import 'package:go_router/go_router.dart';

import 'account_page.dart';
import 'sign_in_page.dart';

/// Sign-in, outside the tab shell (step 0 of a fresh install when the cloud
/// is configured; also pushed from the account page later).
final List<RouteBase> authRoutes = [
  GoRoute(path: '/sign-in', builder: (context, state) => const SignInPage()),
];

/// Account page, inside the More branch next to the settings pages.
final List<RouteBase> accountRoutes = [
  GoRoute(
    path: '/settings/account',
    builder: (context, state) => const AccountPage(),
  ),
];
