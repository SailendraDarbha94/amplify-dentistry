import 'package:go_router/go_router.dart';

import 'about_page.dart';
import 'chairs_page.dart';
import 'clinic_profile_page.dart';
import 'gst_rates_page.dart';
import 'labs_page.dart';
import 'members_page.dart';
import 'notation_page.dart';
import 'settings_page.dart';
import 'whatsapp_page.dart';

/// Settings root and every configuration page.
final List<RouteBase> settingsRoutes = [
  GoRoute(path: '/settings', builder: (context, state) => const SettingsPage()),
  GoRoute(
    path: '/settings/clinic',
    builder: (context, state) => const ClinicProfilePage(),
  ),
  GoRoute(
    path: '/settings/members',
    builder: (context, state) => const MembersPage(),
  ),
  GoRoute(
    path: '/settings/gst',
    builder: (context, state) => const GstRatesPage(),
  ),
  GoRoute(
    path: '/settings/chairs',
    builder: (context, state) => const ChairsPage(),
  ),
  GoRoute(
    path: '/settings/labs',
    builder: (context, state) => const LabsPage(),
  ),
  GoRoute(
    path: '/settings/notation',
    builder: (context, state) => const NotationPage(),
  ),
  GoRoute(
    path: '/settings/about',
    builder: (context, state) => const AboutPage(),
  ),
  GoRoute(
    path: '/settings/whatsapp',
    builder: (context, state) => const WhatsAppSettingsPage(),
  ),
];
