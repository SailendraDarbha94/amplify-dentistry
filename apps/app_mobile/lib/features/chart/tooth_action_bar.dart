import 'package:ampdent_chart_engine/ampdent_chart_engine.dart';
import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';

import 'chart_strings.dart';
import 'tooth_sheet.dart';

/// Notation segmented toggle plus the mixed-dentition chip.
/// Test key: `chart-mixed`.
class ChartToolbar extends StatelessWidget {
  /// Creates the toolbar.
  const ChartToolbar({
    super.key,
    required this.notation,
    required this.onNotation,
    required this.mixed,
    required this.onMixed,
  });

  /// Current display notation.
  final ToothNotation notation;

  /// Persists a new notation.
  final ValueChanged<ToothNotation> onNotation;

  /// Whether primary rows are shown.
  final bool mixed;

  /// Toggles the primary rows.
  final ValueChanged<bool> onMixed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: OdontogramNotationToggle(
                value: notation,
                onChanged: onNotation,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          FilterChip(
            key: const ValueKey('chart-mixed'),
            label: Text(ChartStrings.mixedDentition),
            avatar: const Icon(Icons.child_care, size: 18),
            selected: mixed,
            onSelected: onMixed,
          ),
        ],
      ),
    );
  }
}

/// Bottom bar shown while a tooth is selected: its label and the four
/// sheet actions, each a 56 px target.
class ToothActionBar extends StatelessWidget {
  /// Creates the bar.
  const ToothActionBar({
    super.key,
    required this.label,
    required this.onAction,
    required this.onClear,
  });

  /// `Tooth 16 (MO)`.
  final String label;

  /// Opens the sheet on the given tab.
  final ValueChanged<ToothSheetTab> onAction;

  /// Deselects the tooth.
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const actions = <(ToothSheetTab, IconData, String)>[
      (ToothSheetTab.finding, Icons.search, ChartStrings.addFinding),
      (
        ToothSheetTab.procedure,
        Icons.healing_outlined,
        ChartStrings.addProcedure,
      ),
      (ToothSheetTab.state, Icons.swap_horiz, ChartStrings.toothState),
      (ToothSheetTab.history, Icons.history, ChartStrings.history),
    ];
    return Material(
      color: theme.colorScheme.surfaceContainer,
      elevation: 3,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xs,
            AppSpacing.sm,
            AppSpacing.xs,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(label, style: theme.textTheme.titleMedium),
                  ),
                  IconButton(
                    key: const ValueKey('chart-action-clear'),
                    tooltip: ChartStrings.clearSelection,
                    icon: const Icon(Icons.close),
                    onPressed: onClear,
                  ),
                ],
              ),
              Row(
                children: [
                  for (final (tab, icon, text) in actions)
                    Expanded(
                      child: InkWell(
                        key: ValueKey('chart-action-${tab.name}'),
                        borderRadius: AppRadii.mdAll,
                        onTap: () => onAction(tab),
                        child: SizedBox(
                          height: AppSpacing.bigButtonHeight,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(icon, color: theme.colorScheme.primary),
                              Text(text, style: theme.textTheme.labelSmall),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
