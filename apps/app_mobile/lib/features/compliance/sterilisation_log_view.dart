import 'dart:convert';
import 'dart:typed_data';

import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'compliance_labels.dart';
import 'compliance_providers.dart';
import 'compliance_rules.dart';
import 'sterilisation_log_text.dart';

/// The sterilisation register: recent cycles newest first and a button that
/// shares the monthly log.
class SterilisationLogView extends ConsumerWidget {
  /// Creates the view.
  const SterilisationLogView({super.key});

  Future<void> _shareMonthlyLog(BuildContext context, WidgetRef ref) async {
    final now = ref.read(clockProvider)();
    final picked = await showModalBottomSheet<(int, int)>(
      context: context,
      showDragHandle: true,
      builder: (context) => MonthPickerSheet(now: now),
    );
    if (picked == null || !context.mounted) return;
    final (year, month) = picked;
    final clinic = await ref.read(currentClinicProvider.future);
    final cycles = await ref.read(monthCyclesProvider((year, month)).future);
    final members = await ref.read(clinicMembersProvider.future);
    final text = sterilisationLogText(
      clinic: clinic,
      year: year,
      month: month,
      cycles: cycles,
      operatorNames: {for (final m in members) m.id: m.displayName},
      generatedAt: now,
    );
    final fileName = sterilisationLogFileName(year, month);
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            Uint8List.fromList(utf8.encode(text)),
            mimeType: 'text/plain',
            name: fileName,
          ),
        ],
        fileNameOverrides: [fileName],
        subject: 'Sterilisation register ${monthNames[month - 1]} $year',
        text: 'Sterilisation register, ${clinic.name}',
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings;
    final cycles = ref.watch(recentCyclesProvider).value;
    if (cycles == null) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.sm,
        AppSpacing.gutter,
        96,
      ),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                cycles.isEmpty
                    ? 'No cycles logged yet'
                    : 'Last cycle ${AppFormat.dateTime(cycles.first.cycledAt)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            OutlinedButton.icon(
              key: const ValueKey('sterilisation-print'),
              onPressed: () => _shareMonthlyLog(context, ref),
              icon: const Icon(Icons.print_outlined),
              label: const Text('Monthly log'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (cycles.isEmpty)
          EmptyState(
            icon: Icons.local_fire_department_outlined,
            title: s.nothingHere,
            message:
                'Log every autoclave run; the weekly spore test is '
                'tracked from here.',
          ),
        for (final c in cycles)
          CycleTile(key: ValueKey('cycle-row-${c.id}'), cycle: c),
      ],
    );
  }
}

/// One sterilisation cycle row.
class CycleTile extends StatelessWidget {
  /// Creates the tile.
  const CycleTile({super.key, required this.cycle});

  /// The cycle.
  final SterilisationCycle cycle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final details = [
      AppFormat.dateTime(cycle.cycledAt),
      if (cycle.temperatureC != null) '${cycle.temperatureC} C',
      if (cycle.pressureKpa != null) '${cycle.pressureKpa} kPa',
      if (cycle.durationMinutes != null) '${cycle.durationMinutes} min',
    ].join('  ·  ');
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(
              cycle.passed ? Icons.check_circle_outline : Icons.error_outline,
              color: cycle.passed ? colors.success : colors.danger,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${cycle.cycleNumber}  ·  ${cycleTypeLabel(cycle.cycleType)}'
                    '  ·  ${cycle.autoclaveName}',
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(details, style: theme.textTheme.bodySmall),
                  if (cycle.loadContents != null &&
                      cycle.loadContents!.isNotEmpty)
                    Text(
                      cycle.loadContents!,
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    children: [
                      StatusBadge(
                        label: cycle.chemicalIndicatorPassed
                            ? 'CI pass'
                            : 'CI fail',
                        tone: cycle.chemicalIndicatorPassed
                            ? BadgeTone.success
                            : BadgeTone.danger,
                        dense: true,
                      ),
                      if (hasSporeTest(cycle))
                        StatusBadge(
                          label:
                              'BI ${biologicalResultLabel(cycle.biologicalIndicatorResult)}',
                          tone: switch (cycle.biologicalIndicatorResult) {
                            BiologicalIndicatorResult.pass => BadgeTone.success,
                            BiologicalIndicatorResult.fail => BadgeTone.danger,
                            _ => BadgeTone.info,
                          },
                          dense: true,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Picks one of the last twelve months; pops `(year, month)`.
class MonthPickerSheet extends StatelessWidget {
  /// Creates the sheet anchored at [now].
  const MonthPickerSheet({super.key, required this.now});

  /// Current instant; the first entry is its month.
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final months = List.generate(12, (i) => DateTime(now.year, now.month - i));
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: AppSpacing.screenPadding,
            child: Text(
              'Share monthly log',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final m in months)
            ListTile(
              key: ValueKey('month-${m.year}-${m.month}'),
              title: Text('${monthNames[m.month - 1]} ${m.year}'),
              onTap: () => Navigator.of(context).pop((m.year, m.month)),
            ),
        ],
      ),
    );
  }
}
