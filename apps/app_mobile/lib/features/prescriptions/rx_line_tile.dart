import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';

import 'rx_model.dart';

/// One prescription line in the editor or detail view: generic in capitals,
/// strength and form, dose x frequency x days = quantity, Schedule H1 tag,
/// caution chips and an override marker.
class RxLineTile extends StatelessWidget {
  /// Creates the tile.
  const RxLineTile({
    super.key,
    required this.index,
    required this.line,
    this.cautions = const [],
    this.onTap,
    this.onRemove,
  });

  /// 1-based position.
  final int index;

  /// Line.
  final RxLineDraft line;

  /// Caution chip labels.
  final List<String> cautions;

  /// Edit handler.
  final VoidCallback? onTap;

  /// Remove handler (editor only).
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      key: ValueKey('rx-line-$index'),
      onTap: onTap,
      isThreeLine: true,
      leading: CircleAvatar(radius: 16, child: Text('$index')),
      title: Text(
        '${line.genericUpper} ${line.strength}'
        '${line.brandName == null || line.brandName!.isEmpty ? '' : ' (${line.brandName})'}',
        style: theme.textTheme.titleMedium,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${drugFormLabel(line.form)} · ${line.dose} · ${line.frequency} '
            '· ${line.durationDays} d · Qty ${line.effectiveQuantity}'
            '${line.instructions.isEmpty ? '' : ' · ${line.instructions}'}',
          ),
          if (line.isScheduleH1 ||
              line.schedule == DrugSchedule.x ||
              cautions.isNotEmpty ||
              line.overrideReason != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final badge in _badges(context))
                    FittedBox(fit: BoxFit.scaleDown, child: badge),
                ],
              ),
            ),
        ],
      ),
      trailing: onRemove == null
          ? null
          : IconButton(
              key: ValueKey('rx-line-$index-remove'),
              tooltip: 'Remove',
              icon: const Icon(Icons.close),
              onPressed: onRemove,
            ),
    );
  }

  List<Widget> _badges(BuildContext context) => [
    if (line.isScheduleH1)
      StatusBadge(
        key: ValueKey('rx-line-$index-h1'),
        label: scheduleLabel(DrugSchedule.h1),
        tone: BadgeTone.warning,
        dense: true,
      ),
    if (line.schedule == DrugSchedule.x)
      StatusBadge(
        label: scheduleLabel(DrugSchedule.x),
        tone: BadgeTone.danger,
        dense: true,
      ),
    for (final c in cautions)
      StatusBadge(label: c, tone: BadgeTone.warning, dense: true),
    if (line.overrideReason != null)
      StatusBadge(
        key: ValueKey('rx-line-$index-override'),
        label: 'Allergy override',
        tone: BadgeTone.danger,
        icon: Icons.dangerous_outlined,
        dense: true,
      ),
  ];
}
