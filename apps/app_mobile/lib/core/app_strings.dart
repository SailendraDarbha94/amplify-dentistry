/// User-facing strings. Re-exports the design-system [AppStrings] table so
/// features import one place; Hindi and Telugu tables plug in through
/// [AppStringsScope] later without touching call sites.
library;

import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/widgets.dart';

export 'package:ampdent_ui/ampdent_ui.dart'
    show AppStrings, AppStringsScope, appStringsEn;

/// Convenience accessor: `context.strings.save`.
extension AppStringsContext on BuildContext {
  /// The nearest [AppStrings] table (English when no scope is installed).
  AppStrings get strings => AppStrings.of(this);
}

/// Strings specific to the mobile app that are not in the shared table yet.
/// Kept as a single English map so a translation hook can replace it.
abstract final class MobileStrings {
  /// Shown on every feature page that a later build fills in.
  static const String comingInThisBuild = 'Coming in this build';

  /// Onboarding title.
  static const String setUpYourClinic = 'Set up your clinic';

  /// Validation message for the mandatory council registration number.
  static const String registrationNumberRequired =
      'Registration number is required (DCI Code 3.4.1)';

  /// Validation message for a mandatory guardian on a minor.
  static const String guardianRequiredForMinor =
      'Guardian name and phone are required for patients under 18';

  /// Sign-in page title on a fresh install.
  static const String signInOrContinueOffline = 'Sign in or continue offline';

  /// Link that skips sign-in on a fresh install.
  static const String continueOffline = 'Continue offline';

  /// Shown wherever a cloud feature needs a project that is not set up.
  static const String cloudNotConfigured = 'Cloud not configured';

  /// How to set the cloud up (shown under [cloudNotConfigured]).
  static const String cloudNotConfiguredHelp =
      'Run the app with --dart-define-from-file=env.json carrying '
      'SUPABASE_URL and SUPABASE_ANON_KEY. Until then everything stays on '
      'this phone and WhatsApp messages open from it. See docs/SETUP-CLOUD.md.';

  /// Snackbar when a message was queued for the Cloud API.
  static const String queuedForDelivery =
      'Queued; WhatsApp delivery is handled by the server';

  /// Path of the founder's setup guide in the repository.
  static const String setupGuidePath = 'docs/SETUP-CLOUD.md';

  /// Data-ownership statement shown on the About page.
  static const String dataOwnership =
      'Your clinic owns its data. A full export of every patient record, '
      'invoice, consent and audit event is available at any time from '
      'More > Export, with no fee and no waiting period.';
}
