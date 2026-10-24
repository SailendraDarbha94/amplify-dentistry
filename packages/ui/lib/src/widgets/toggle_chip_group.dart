import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// One option in a [ToggleChipGroup].
@immutable
class ToggleChipOption<T> {
  /// Creates an option.
  const ToggleChipOption({required this.value, required this.label, this.icon});

  /// Value reported in the selection set.
  final T value;

  /// Chip text.
  final String label;

  /// Optional leading icon.
  final IconData? icon;
}

/// Wrapping group of filter chips with single- or multi-select. Reports the
/// whole selection on every change so callers stay stateless.
class ToggleChipGroup<T> extends StatelessWidget {
  /// Creates a chip group.
  const ToggleChipGroup({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.multiSelect = true,
    this.allowEmpty = true,
    this.spacing = AppSpacing.sm,
  });

  /// Options in display order.
  final List<ToggleChipOption<T>> options;

  /// Currently selected values.
  final Set<T> selected;

  /// Receives the new selection.
  final ValueChanged<Set<T>> onChanged;

  /// Allow more than one selected value.
  final bool multiSelect;

  /// When false, tapping the only selected chip keeps it selected.
  final bool allowEmpty;

  /// Gap between chips.
  final double spacing;

  void _toggle(T value) {
    final next = Set<T>.of(selected);
    if (next.contains(value)) {
      if (!allowEmpty && next.length == 1) return;
      next.remove(value);
    } else {
      if (!multiSelect) next.clear();
      next.add(value);
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: [
        for (final option in options)
          FilterChip(
            label: Text(option.label),
            avatar: option.icon == null ? null : Icon(option.icon, size: 18),
            selected: selected.contains(option.value),
            onSelected: (_) => _toggle(option.value),
          ),
      ],
    );
  }
}
