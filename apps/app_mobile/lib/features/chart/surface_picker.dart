import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';

import 'chart_mapping.dart';

/// Chips for the surfaces of one tooth, labelled per tooth type (O/I, B/F,
/// L/P). Test keys: `chart-surface-<canonical code>`.
class SurfacePicker extends StatelessWidget {
  /// Creates the picker.
  const SurfacePicker({
    super.key,
    required this.tooth,
    required this.value,
    required this.onChanged,
  });

  /// Tooth whose surfaces are offered.
  final ToothId tooth;

  /// Currently selected surfaces.
  final SurfaceSet value;

  /// Called with the toggled set.
  final ValueChanged<SurfaceSet> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        for (final surface in pickableSurfaces(tooth))
          FilterChip(
            key: ValueKey('chart-surface-${surface.code}'),
            label: Text(surface.labelFor(tooth)),
            tooltip: surface.longName,
            selected: value.contains(surface),
            onSelected: (_) => onChanged(value.toggled(surface)),
          ),
      ],
    );
  }
}
