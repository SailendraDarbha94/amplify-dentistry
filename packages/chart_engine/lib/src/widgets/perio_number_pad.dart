import 'package:ampdent_core/ampdent_core.dart';
import 'package:flutter/material.dart';

/// Glove-friendly entry pad for perio charting: digits 0-15, bleeding /
/// suppuration / plaque toggles for the focused site, clear, back and next.
/// The app owns the cursor; this widget only reports intents.
class PerioNumberPad extends StatelessWidget {
  const PerioNumberPad({
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
    this.maxValue = 15,
    this.buttonHeight = 48,
  });

  /// A depth value 0-[maxValue] was tapped.
  final ValueChanged<int> onDigit;

  /// Advance to the next site in the sequence.
  final VoidCallback onNext;

  /// Go back one site.
  final VoidCallback? onPrevious;

  /// Clear the focused value.
  final VoidCallback? onClear;

  /// A boolean flag for the focused site was toggled (bleeding, suppuration
  /// or plaque).
  final ValueChanged<PerioMeasurementType>? onToggle;
  final bool bleeding;
  final bool suppuration;
  final bool plaque;
  final bool enabled;

  /// Largest selectable depth (probes read to 15 mm).
  final int maxValue;
  final double buttonHeight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GridView.count(
          crossAxisCount: 8,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          childAspectRatio: 1.1,
          children: [
            for (var v = 0; v <= maxValue; v++)
              FilledButton.tonal(
                key: ValueKey('perio-digit-$v'),
                onPressed: enabled ? () => onDigit(v) : null,
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: v >= 6
                      ? scheme.errorContainer
                      : (v >= 4 ? scheme.tertiaryContainer : null),
                ),
                child: Text('$v'),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _flag(
              context,
              'BOP',
              bleeding,
              PerioMeasurementType.bleedingOnProbing,
            ),
            const SizedBox(width: 4),
            _flag(
              context,
              'Sup',
              suppuration,
              PerioMeasurementType.suppuration,
            ),
            const SizedBox(width: 4),
            _flag(context, 'Plaque', plaque, PerioMeasurementType.plaque),
            const Spacer(),
            IconButton(
              tooltip: 'Previous site',
              onPressed: enabled ? onPrevious : null,
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              tooltip: 'Clear',
              onPressed: enabled ? onClear : null,
              icon: const Icon(Icons.backspace_outlined),
            ),
            SizedBox(
              height: buttonHeight,
              child: FilledButton.icon(
                key: const ValueKey('perio-next'),
                onPressed: enabled ? onNext : null,
                icon: const Icon(Icons.chevron_right),
                label: const Text('Next'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _flag(
    BuildContext context,
    String label,
    bool selected,
    PerioMeasurementType type,
  ) => FilterChip(
    key: ValueKey('perio-flag-${type.name}'),
    label: Text(label),
    selected: selected,
    onSelected: enabled && onToggle != null ? (_) => onToggle!(type) : null,
  );
}
