import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';

import 'chart_mapping.dart';
import 'chart_strings.dart';

/// Procedures in the order the chairside list shows them: in progress,
/// then planned, then done; newest first within a group.
List<ProcedureRecord> orderProceduresForChart(
  Iterable<ProcedureRecord> procedures,
) {
  int rank(ProcedureStatus s) => switch (s) {
    ProcedureStatus.inProgress => 0,
    ProcedureStatus.accepted => 1,
    ProcedureStatus.planned => 1,
    ProcedureStatus.completed => 2,
    _ => 3,
  };
  final out = procedures
      .where((p) => p.status != ProcedureStatus.deleted)
      .toList();
  out.sort((a, b) {
    final r = rank(a.status).compareTo(rank(b.status));
    return r != 0 ? r : b.updatedAt.compareTo(a.updatedAt);
  });
  return out;
}

/// Whether the quick action can move this procedure forward.
bool canMarkDone(ProcedureRecord p) =>
    p.status == ProcedureStatus.planned ||
    p.status == ProcedureStatus.accepted ||
    p.status == ProcedureStatus.inProgress;

/// The patient's procedures with `Mark done` / `Next stage` and
/// `Add to bill` quick actions. Test keys: `proc-done-<id>`,
/// `proc-bill-<id>`.
class ChartProcedureList extends StatelessWidget {
  /// Creates the list.
  const ChartProcedureList({
    super.key,
    required this.procedures,
    required this.notation,
    required this.onMarkDone,
    required this.onAddToBill,
  });

  /// Procedures of the patient (any order).
  final List<ProcedureRecord> procedures;

  /// Display notation.
  final ToothNotation notation;

  /// Advance or complete a procedure.
  final ValueChanged<ProcedureRecord> onMarkDone;

  /// Navigate to billing with the procedure preselected.
  final ValueChanged<ProcedureRecord> onAddToBill;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final ordered = orderProceduresForChart(procedures);
    return SectionCard(
      title: s.procedures,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: ordered.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(
                ChartStrings.noProcedures,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          : Column(
              children: [
                for (final p in ordered)
                  _ProcedureRow(
                    procedure: p,
                    notation: notation,
                    onMarkDone: onMarkDone,
                    onAddToBill: onAddToBill,
                  ),
              ],
            ),
    );
  }
}

class _ProcedureRow extends StatelessWidget {
  const _ProcedureRow({
    required this.procedure,
    required this.notation,
    required this.onMarkDone,
    required this.onAddToBill,
  });

  final ProcedureRecord procedure;
  final ToothNotation notation;
  final ValueChanged<ProcedureRecord> onMarkDone;
  final ValueChanged<ProcedureRecord> onAddToBill;

  BadgeTone _tone(ProcedureStatus status) => switch (status) {
    ProcedureStatus.completed => BadgeTone.completed,
    ProcedureStatus.inProgress => BadgeTone.info,
    ProcedureStatus.planned || ProcedureStatus.accepted => BadgeTone.planned,
    ProcedureStatus.existingCurrentProvider ||
    ProcedureStatus.existingOtherProvider => BadgeTone.existing,
    _ => BadgeTone.neutral,
  };

  @override
  Widget build(BuildContext context) {
    final p = procedure;
    final theme = Theme.of(context);
    final teeth = procedureTeeth(p).toList();
    final where = teeth.isEmpty
        ? AppFormat.enumLabel(p.treatmentArea)
        : (teeth.length == 1
              ? describeToothSurfaces(teeth.first, p.surfaces, notation)
              : notation.formatAll(teeth, plain: true));
    final stage = p.isMultiSitting
        ? 'Stage ${p.stageIndex + 1}/${p.totalStages}'
              '${p.currentStageName.isEmpty ? '' : ': ${p.currentStageName}'}'
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${p.name} · $where',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              StatusBadge(
                label: AppFormat.enumLabel(p.status),
                tone: _tone(p.status),
                dense: true,
              ),
            ],
          ),
          Text(
            [?stage, AppFormat.money(p.netFee, showPaise: false)].join(' · '),
            style: theme.textTheme.bodySmall,
          ),
          if (canMarkDone(p) || p.status.isBillable)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Wrap(
                spacing: AppSpacing.sm,
                children: [
                  if (canMarkDone(p))
                    FilledButton.tonalIcon(
                      key: ValueKey('proc-done-${p.id}'),
                      onPressed: () => onMarkDone(p),
                      icon: const Icon(Icons.check),
                      label: Text(
                        p.isMultiSitting &&
                                p.status == ProcedureStatus.inProgress
                            ? ChartStrings.nextStage
                            : ChartStrings.markDone,
                      ),
                    ),
                  if (p.status.isBillable)
                    OutlinedButton.icon(
                      key: ValueKey('proc-bill-${p.id}'),
                      onPressed: () => onAddToBill(p),
                      icon: const Icon(Icons.receipt_long_outlined),
                      label: Text(ChartStrings.addToBill),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
