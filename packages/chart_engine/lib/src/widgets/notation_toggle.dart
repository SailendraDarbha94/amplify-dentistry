import 'package:ampdent_core/ampdent_core.dart';
import 'package:flutter/material.dart';

/// Segmented buttons switching between FDI, Universal and Palmer labels.
class OdontogramNotationToggle extends StatelessWidget {
  const OdontogramNotationToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final ToothNotation value;
  final ValueChanged<ToothNotation> onChanged;

  /// Short label per notation.
  static String shortLabel(ToothNotation n) => switch (n) {
    ToothNotation.fdi => 'FDI',
    ToothNotation.universal => 'Universal',
    ToothNotation.palmer => 'Palmer',
  };

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ToothNotation>(
      showSelectedIcon: false,
      segments: [
        for (final n in ToothNotation.values)
          ButtonSegment<ToothNotation>(
            value: n,
            label: Text(shortLabel(n)),
            tooltip: n.label,
          ),
      ],
      selected: {value},
      onSelectionChanged: (set) {
        if (set.isNotEmpty) onChanged(set.first);
      },
    );
  }
}
