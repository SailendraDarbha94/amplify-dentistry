import 'package:ampdent_mobile/core/router.dart'
    show inviteLinkLocation, syncRepairLocation;
import 'package:go_router/go_router.dart';

import 'account_page.dart';
import 'invite_link_page.dart';
import 'sign_in_page.dart';
import 'sync_repair_page.dart';

/// Sign-in, outside the tab shell (step 0 of a fresh install when the cloud
/// is configured; also pushed from the account page later), and the invite
/// deep link that prefills it.
final List<RouteBase> authRoutes = [
  GoRoute(path: '/sign-in', builder: (context, state) => const SignInPage()),
  GoRoute(
    path: '$inviteLinkLocation/:code',
    builder: (context, state) =>
        InviteLinkPage(code: state.pathParameters['code'] ?? ''),
  ),
];

/// Account and sync-repair pages, inside the More branch next to the
/// settings pages.
final List<RouteBase> accountRoutes = [
  GoRoute(
    path: '/settings/account',
    builder: (context, state) => const AccountPage(),
  ),
  GoRoute(
    path: syncRepairLocation,
    builder: (context, state) => const SyncRepairPage(),
  ),
];
