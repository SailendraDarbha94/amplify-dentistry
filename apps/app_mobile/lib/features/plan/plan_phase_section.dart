import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';

import 'plan_model.dart';

/// Presented / accepted / scheduled / completed chips.
class PlanFunnelChips extends StatelessWidget {
  /// Creates the chips.
  const PlanFunnelChips({super.key, required this.funnel, this.dense = true});

  /// Funnel to show.
  final PlanFunnel funnel;

  /// Compact badges.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final steps = <(String, String, bool)>[
      ('presented', 'Presented', funnel.presented),
      ('accepted', s.accepted, funnel.accepted),
      (
        'scheduled',
        funnel.totalCount == 0
            ? 'Scheduled'
            : 'Scheduled ${funnel.scheduledCount}/${funnel.totalCount}',
        funnel.scheduled,
      ),
      (
        'completed',
        funnel.totalCount == 0
            ? s.completed
            : '${s.completed} ${funnel.completedCount}/${funnel.totalCount}',
        funnel.completed,
      ),
    ];
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final (key, label, reached) in steps)
          StatusBadge(
            key: ValueKey('funnel-$key'),
            label: label,
            dense: dense,
            icon: reached ? Icons.check : null,
            tone: reached ? BadgeTone.success : BadgeTone.neutral,
          ),
      ],
    );
  }
}

/// Phase title row with subtotal and a rename action.
class PhaseHeader extends StatelessWidget {
  /// Creates the header.
  const PhaseHeader({
    super.key,
    required this.phase,
    required this.subtotal,
    this.onRename,
  });

  /// The phase.
  final PlanPhase phase;

  /// Net subtotal of the phase's default lines.
  final Money subtotal;

  /// Rename handler; null when read-only.
  final VoidCallback? onRename;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Text(
              phase.name,
              style: theme.textTheme.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          MoneyText(
            AppFormat.money(subtotal, showPaise: false),
            emphasis: MoneyEmphasis.strong,
          ),
          if (onRename != null)
            IconButton(
              key: ValueKey('plan-phase-rename-${phase.index}'),
              tooltip: 'Rename phase',
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: onRename,
            ),
        ],
      ),
    );
  }
}

/// Actions on a line from its overflow menu.
enum PlanLineAction { edit, moveToPhase, toggleAlternative, remove }

/// One plan line: patient-facing name, teeth, fee arithmetic, GST class,
/// fee-range warning and the alternative badge.
class PlanLineTile extends StatelessWidget {
  /// Creates the tile.
  const PlanLineTile({
    super.key,
    required this.line,
    required this.notation,
    this.catalogItem,
    this.gstRatePercent,
    this.onTap,
    this.onAction,
  });

  /// The line.
  final TreatmentPlanLine line;

  /// Clinic display notation.
  final ToothNotation notation;

  /// Catalogue item for the range check.
  final CatalogItem? catalogItem;

  /// GST rate for the line's class (null when unknown).
  final num? gstRatePercent;

  /// Tap handler (edit); null when read-only.
  final VoidCallback? onTap;

  /// Menu handler; null hides the menu.
  final ValueChanged<PlanLineAction>? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final s = context.strings;
    final teeth = [if (line.tooth != null) line.tooth!, ...line.teeth];
    final where = [
      if (teeth.isNotEmpty) notation.formatAll(teeth),
      if (line.surfaces.isNotEmpty) line.surfaces.code,
    ].join(' ');
    final warning = feeRangeWarning(line.unitFee, catalogItem);
    final arithmetic = [
      '${AppFormat.money(line.unitFee, showPaise: false)} x ${line.quantity}',
      if (!line.discount.isZero)
        '- ${AppFormat.money(line.discount, showPaise: false)}',
    ].join(' ');
    return ListTile(
      key: ValueKey('plan-line-${line.id}'),
      onTap: onTap,
      contentPadding: const EdgeInsets.only(left: AppSpacing.xs),
      leading: SizedBox(
        width: 52,
        child: Text(
          where.isEmpty ? '-' : where,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelLarge,
        ),
      ),
      title: Text(
        line.laymanName,
        style: line.isAlternative
            ? theme.textTheme.bodyLarge?.copyWith(color: colors.info)
            : theme.textTheme.bodyLarge,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$arithmetic  |  '
            '${gstClassLabel(line.gstClass, ratePercent: gstRatePercent)}',
          ),
          if (line.isAlternative)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: StatusBadge(
                label: 'Alternative: ${line.alternativeGroup ?? 'Plan B'}',
                tone: BadgeTone.info,
                dense: true,
              ),
            ),
          if (warning != null)
            Text(
              warning,
              key: ValueKey('plan-line-warning-${line.id}'),
              style: theme.textTheme.bodySmall?.copyWith(color: colors.warning),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MoneyText(
            AppFormat.money(line.net, showPaise: false),
            emphasis: MoneyEmphasis.strong,
            color: line.isAlternative ? theme.colorScheme.outline : null,
          ),
          if (onAction != null)
            PopupMenuButton<PlanLineAction>(
              key: ValueKey('plan-line-menu-${line.id}'),
              tooltip: s.more,
              onSelected: onAction,
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: PlanLineAction.edit,
                  child: Text('${s.edit} fee / phase'),
                ),
                const PopupMenuItem(
                  value: PlanLineAction.moveToPhase,
                  child: Text('Move to phase'),
                ),
                PopupMenuItem(
                  value: PlanLineAction.toggleAlternative,
                  child: Text(
                    line.isAlternative
                        ? 'Make default option'
                        : 'Mark as alternative',
                  ),
                ),
                PopupMenuItem(
                  value: PlanLineAction.remove,
                  child: Text('Remove from plan'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Totals card: per-phase subtotals, alternatives and the pre-tax total.
class PlanTotalsCard extends StatelessWidget {
  /// Creates the card.
  const PlanTotalsCard({super.key, required this.editor});

  /// The plan being shown.
  final PlanEditor editor;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final theme = Theme.of(context);
    final subtotals = editor.subtotals;
    return SectionCard(
      title: s.total,
      subtitle:
          'Pre-tax patient estimate. GST, where a line is taxable, is '
          'shown per line and on the estimate.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final p in editor.phases)
            LabeledValue(
              label: p.name,
              value: AppFormat.money(
                subtotals[p.index] ?? const Money.zero(),
                showPaise: false,
              ),
              dense: true,
            ),
          if (!editor.alternativesTotal.isZero)
            LabeledValue(
              label: 'Alternatives (not in total)',
              value: AppFormat.money(
                editor.alternativesTotal,
                showPaise: false,
              ),
              dense: true,
            ),
          const Divider(),
          Row(
            children: [
              Expanded(
                child: Text(s.total, style: theme.textTheme.titleMedium),
              ),
              MoneyText(
                AppFormat.money(editor.total, showPaise: false),
                emphasis: MoneyEmphasis.hero,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
