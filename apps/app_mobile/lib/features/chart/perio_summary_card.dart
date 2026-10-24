import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';

import 'chart_strings.dart';

/// `Stage III` for a 2017 AAP/EFP stage.
String stageLabel(PeriodontitisStage stage) => switch (stage) {
  PeriodontitisStage.stage1 => 'Stage I',
  PeriodontitisStage.stage2 => 'Stage II',
  PeriodontitisStage.stage3 => 'Stage III',
  PeriodontitisStage.stage4 => 'Stage IV',
};

/// Whole-mouth summary of the draft (BOP %, deep sites, max CAL) with the
/// suggested stage the clinician may accept, and the last saved exam.
/// Test keys: `perio-accept-stage`.
class PerioSummaryCard extends StatelessWidget {
  /// Creates the card.
  const PerioSummaryCard({
    super.key,
    required this.summary,
    this.acceptedStage,
    required this.onAcceptStage,
    this.lastExam,
  });

  /// Summary of the readings entered so far.
  final PerioSummary summary;

  /// Stage the clinician confirmed.
  final PeriodontitisStage? acceptedStage;

  /// Confirms or clears the suggested stage.
  final ValueChanged<PeriodontitisStage?> onAcceptStage;

  /// Most recent saved exam, for comparison.
  final PerioExam? lastExam;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final suggested = summary.suggestedStage;
    final last = lastExam;
    return SectionCard(
      title: ChartStrings.summary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.xl,
            runSpacing: AppSpacing.sm,
            children: [
              LabeledValue(
                label: ChartStrings.sitesRecorded,
                value: '${summary.sitesRecorded}',
                dense: true,
              ),
              LabeledValue(
                label: ChartStrings.bleedingPercent,
                value: '${summary.bleedingPercent.round()}%',
                dense: true,
              ),
              LabeledValue(
                label: ChartStrings.sitesPd4,
                value: '${summary.sitesPd4Plus}',
                dense: true,
              ),
              LabeledValue(
                label: ChartStrings.sitesPd6,
                value: '${summary.sitesPd6Plus}',
                dense: true,
              ),
              LabeledValue(
                label: ChartStrings.maxCal,
                value: '${summary.maxClinicalAttachmentLoss} mm',
                dense: true,
              ),
            ],
          ),
          if (suggested != null) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${ChartStrings.suggestedStage}: ${stageLabel(suggested)}',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                FilterChip(
                  key: const ValueKey('perio-accept-stage'),
                  label: Text(ChartStrings.acceptStage),
                  selected: acceptedStage == suggested,
                  onSelected: (v) => onAcceptStage(v ? suggested : null),
                ),
              ],
            ),
            Text(
              ChartStrings.stageDisclaimer,
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            last == null
                ? ChartStrings.noExamYet
                : '${ChartStrings.lastExam} ${AppFormat.date(last.examinedAt)}'
                      ' · ${last.summary.sitesRecorded} sites · '
                      'BOP ${last.summary.bleedingPercent.round()}%',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
