import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';

/// Multi-select tooth picker laid out as the clinician views the patient
/// (upper arch above lower, patient's right on the left), labelled in the
/// clinic notation. Primary teeth can be shown for mixed dentition.
class ToothPickerSheet extends StatefulWidget {
  /// Creates the picker.
  const ToothPickerSheet({
    super.key,
    required this.notation,
    this.initial = const {},
    this.showPrimary = false,
  });

  /// Display notation.
  final ToothNotation notation;

  /// Pre-selected teeth.
  final Set<ToothId> initial;

  /// Start with primary teeth visible.
  final bool showPrimary;

  /// Shows the sheet; returns the selection or null when dismissed.
  static Future<Set<ToothId>?> show(
    BuildContext context, {
    required ToothNotation notation,
    Set<ToothId> initial = const {},
    bool showPrimary = false,
  }) => showModalBottomSheet<Set<ToothId>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ToothPickerSheet(
      notation: notation,
      initial: initial,
      showPrimary: showPrimary,
    ),
  );

  @override
  State<ToothPickerSheet> createState() => _ToothPickerSheetState();
}

class _ToothPickerSheetState extends State<ToothPickerSheet> {
  late final Set<ToothId> _selected = {...widget.initial};
  late bool _primary = widget.showPrimary;

  void _toggle(ToothId t) => setState(() {
    _selected.contains(t) ? _selected.remove(t) : _selected.add(t);
  });

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.lg,
        AppSpacing.gutter,
        AppSpacing.gutter,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(s.teeth, style: theme.textTheme.titleLarge),
                ),
                FilterChip(
                  key: const ValueKey('tooth-picker-primary'),
                  label: const Text('Primary teeth'),
                  selected: _primary,
                  onSelected: (v) => setState(() => _primary = v),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _selected.isEmpty
                  ? 'Tap the teeth in this photo'
                  : widget.notation.formatAll(
                      _selected.toList()..sort(),
                      plain: true,
                    ),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            _row(ToothId.archRow(Arch.upper, Dentition.permanent)),
            if (_primary) ...[
              const SizedBox(height: AppSpacing.xs),
              _row(ToothId.archRow(Arch.upper, Dentition.primary)),
              const SizedBox(height: AppSpacing.md),
              _row(ToothId.archRow(Arch.lower, Dentition.primary)),
              const SizedBox(height: AppSpacing.xs),
            ] else
              const SizedBox(height: AppSpacing.md),
            _row(ToothId.archRow(Arch.lower, Dentition.permanent)),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                TextButton(
                  onPressed: () => setState(_selected.clear),
                  child: Text(s.clear),
                ),
                const Spacer(),
                FilledButton(
                  key: const ValueKey('tooth-picker-done'),
                  onPressed: () => Navigator.of(context).pop(_selected),
                  child: Text(s.done),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(List<ToothId> teeth) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final cell = (constraints.maxWidth - 8) / teeth.length;
        return Row(
          children: [
            for (var i = 0; i < teeth.length; i++) ...[
              if (i == teeth.length ~/ 2) const SizedBox(width: 8),
              SizedBox(
                width: cell,
                height: 48,
                child: _ToothCell(
                  key: ValueKey('tooth-${teeth[i].storageKey}'),
                  label: widget.notation.formatPlain(teeth[i]),
                  selected: _selected.contains(teeth[i]),
                  primary: teeth[i].isPrimary,
                  onTap: () => _toggle(teeth[i]),
                  theme: theme,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ToothCell extends StatelessWidget {
  const _ToothCell({
    super.key,
    required this.label,
    required this.selected,
    required this.primary,
    required this.onTap,
    required this.theme,
  });

  final String label;
  final bool selected;
  final bool primary;
  final VoidCallback onTap;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.all(1),
      child: Material(
        color: selected
            ? scheme.primary
            : primary
            ? scheme.surfaceContainerHigh
            : scheme.surfaceContainerLow,
        borderRadius: AppRadii.smAll,
        child: InkWell(
          borderRadius: AppRadii.smAll,
          onTap: onTap,
          child: Center(
            child: FittedBox(
              child: Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: selected ? scheme.onPrimary : scheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
