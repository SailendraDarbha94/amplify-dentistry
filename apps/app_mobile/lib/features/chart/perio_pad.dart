import 'package:ampdent_chart_engine/ampdent_chart_engine.dart';
import 'package:ampdent_core/ampdent_core.dart';
import 'package:flutter/material.dart';

/// Narrowest width at which the engine pad's flag row (BOP / Sup / Plaque,
/// previous, clear, next) fits under [perioPadTheme]; below it the pad is
/// scaled down uniformly instead of overflowing.
const double perioPadMinWidth = 432;

/// Compact variant of the app theme for the number pad: tight chip padding,
/// no check marks (selection shows by colour) and zero icon-button padding.
ThemeData perioPadTheme(ThemeData base) => base.copyWith(
  chipTheme: base.chipTheme.copyWith(
    padding: const EdgeInsets.symmetric(horizontal: 2),
    labelPadding: const EdgeInsets.symmetric(horizontal: 4),
    showCheckmark: false,
  ),
  iconButtonTheme: IconButtonThemeData(
    style: IconButton.styleFrom(
      padding: EdgeInsets.zero,
      minimumSize: const Size(40, 48),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      minimumSize: const Size(48, 48),
    ),
  ),
);

/// [PerioNumberPad] made safe for a 360 px phone: the engine lays its flag
/// row out as a fixed `Row`, so this gives it at least [perioPadMinWidth]
/// and scales the whole pad down to the available width when narrower.
/// The digit grid keeps its size (it fills the width either way).
class PerioPad extends StatelessWidget {
  /// Creates the pad wrapper; parameters mirror [PerioNumberPad].
  const PerioPad({
    super.key,
    required this.onDigit,
    required this.onNext,
    this.onPrevious,
    this.onClear,
    this.onToggle,
    this.bleeding = false,
    this.suppuration = false,
    this.plaque = false,
    this.enabled = true,
  });

  /// A depth value was tapped.
  final ValueChanged<int> onDigit;

  /// Advance to the next site.
  final VoidCallback onNext;

  /// Go back one site.
  final VoidCallback? onPrevious;

  /// Clear the focused value.
  final VoidCallback? onClear;

  /// A flag was toggled for the focused site.
  final ValueChanged<PerioMeasurementType>? onToggle;

  /// Flag states of the focused site.
  final bool bleeding;

  /// Suppuration flag of the focused site.
  final bool suppuration;

  /// Plaque flag of the focused site.
  final bool plaque;

  /// Whether the pad accepts input.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < perioPadMinWidth
            ? perioPadMinWidth
            : constraints.maxWidth;
        return Theme(
          data: perioPadTheme(Theme.of(context)),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: width,
              child: PerioNumberPad(
                enabled: enabled,
                bleeding: bleeding,
                suppuration: suppuration,
                plaque: plaque,
                onDigit: onDigit,
                onNext: onNext,
                onPrevious: onPrevious,
                onClear: onClear,
                onToggle: onToggle,
              ),
            ),
          ),
        );
      },
    );
  }
}
