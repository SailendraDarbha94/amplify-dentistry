import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';

import 'chart_strings.dart';

/// Short label for a sextant row.
String sextantLabel(Sextant sextant) => switch (sextant) {
  Sextant.upperRightPosterior => 'UR 4-8',
  Sextant.upperAnterior => 'U 3-3',
  Sextant.upperLeftPosterior => 'UL 4-8',
  Sextant.lowerLeftPosterior => 'LL 4-8',
  Sextant.lowerAnterior => 'L 3-3',
  Sextant.lowerRightPosterior => 'LR 4-8',
};

/// Basic Periodontal Examination entry: one row per sextant of code chips
/// (0-4, exclusive) plus the furcation `*` toggle, which sits beside the
/// code as on the BSP form. Test keys: `bpe-<sextant number>-<code.name>`
/// and `bpe-<sextant number>-furcation`.
class BpeEntry extends StatelessWidget {
  /// Creates the entry card.
  const BpeEntry({
    super.key,
    required this.value,
    this.furcation = const {},
    required this.onChanged,
    required this.onFurcationToggled,
  });

  /// Current code per sextant.
  final Map<Sextant, BpeCode> value;

  /// Sextants flagged for furcation involvement.
  final Set<Sextant> furcation;

  /// Called with the sextant and the new code (null clears it).
  final void Function(Sextant sextant, BpeCode? code) onChanged;

  /// Called when the `*` chip of a sextant is tapped.
  final void Function(Sextant sextant) onFurcationToggled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: ChartStrings.bpeScreening,
      subtitle: ChartStrings.bpeHint,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        children: [
          for (final sextant in Sextant.values)
            Row(
              children: [
                SizedBox(
                  width: 56,
                  child: Text(
                    sextantLabel(sextant),
                    style: theme.textTheme.labelMedium,
                  ),
                ),
                Expanded(
                  child: Wrap(
                    spacing: AppSpacing.xs,
                    children: [
                      for (final code in BpeCode.values)
                        ChoiceChip(
                          key: ValueKey('bpe-${sextant.number}-${code.name}'),
                          label: Text(code.label),
                          labelPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs,
                          ),
                          selected: value[sextant] == code,
                          onSelected: (selected) =>
                              onChanged(sextant, selected ? code : null),
                        ),
                      FilterChip(
                        key: ValueKey('bpe-${sextant.number}-furcation'),
                        label: const Text('*'),
                        tooltip: ChartStrings.bpeFurcation,
                        labelPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                        ),
                        selected: furcation.contains(sextant),
                        onSelected: (_) => onFurcationToggled(sextant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
