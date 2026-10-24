import 'package:flutter/widgets.dart';

/// Spacing scale in logical pixels. Use these instead of literal numbers so
/// every screen breathes the same way.
abstract final class AppSpacing {
  /// 4 px: tight gaps inside a chip or between an icon and its label.
  static const double xs = 4;

  /// 8 px: gaps between related controls.
  static const double sm = 8;

  /// 12 px: card inner padding on dense lists.
  static const double md = 12;

  /// 16 px: the default screen gutter and card padding.
  static const double lg = 16;

  /// 24 px: separation between sections.
  static const double xl = 24;

  /// 32 px: top-of-screen breathing room and empty states.
  static const double xxl = 32;

  /// Horizontal gutter at the screen edge.
  static const double gutter = lg;

  /// Minimum touch target on any interactive control (Material and gloves).
  static const double minTapTarget = 48;

  /// Height of the primary full-width action button.
  static const double bigButtonHeight = 56;

  /// Default screen padding.
  static const EdgeInsets screenPadding = EdgeInsets.all(lg);

  /// Default card padding.
  static const EdgeInsets cardPadding = EdgeInsets.all(lg);

  /// Horizontal-only gutter padding.
  static const EdgeInsets horizontalGutter = EdgeInsets.symmetric(
    horizontal: lg,
  );
}

/// Corner radii used across the design system.
abstract final class AppRadii {
  /// 8 px: chips, badges and small controls.
  static const double sm = 8;

  /// 12 px: cards, inputs and buttons.
  static const double md = 12;

  /// 16 px: bottom sheets and dialogs.
  static const double lg = 16;

  /// Fully rounded (pills).
  static const double pill = 999;

  /// [BorderRadius] for [sm].
  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));

  /// [BorderRadius] for [md].
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));

  /// [BorderRadius] for [lg].
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));

  /// [BorderRadius] for [pill].
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));

  /// Top-only [lg] radius for bottom sheets.
  static const BorderRadius sheetTop = BorderRadius.vertical(
    top: Radius.circular(lg),
  );
}
