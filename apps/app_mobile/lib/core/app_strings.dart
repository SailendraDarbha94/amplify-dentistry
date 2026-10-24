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

  /// Data-ownership statement shown on the About page.
  static const String dataOwnership =
      'Your clinic owns its data. A full export of every patient record, '
      'invoice, consent and audit event is available at any time from '
      'More > Export, with no fee and no waiting period.';
}
