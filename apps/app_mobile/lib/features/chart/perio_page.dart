import 'package:ampdent_chart_engine/ampdent_chart_engine.dart';
import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bpe_entry.dart';
import 'chart_providers.dart';
import 'chart_strings.dart';
import 'perio_controller.dart';
import 'perio_pad.dart';
import 'perio_summary_card.dart';

/// Periodontal charting: BPE screening per sextant, six-point grid for the
/// unlocked sextants with a glove-friendly number pad that auto-advances,
/// and the live summary. Saves an append-only [PerioExam].
/// Test keys: `perio-save`, `perio-arch-<arch>`, `perio-aspect-<aspect>`,
/// `perio-measure-<type>`, `perio-recession`, `perio-chart-all`,
/// `perio-chart`, plus the `bpe-*` and `perio-digit-*` keys of the inner
/// widgets.
class PerioPage extends ConsumerWidget {
  /// Creates the page.
  const PerioPage({super.key, required this.patientId});

  /// Patient.
  final String patientId;

  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    Map<ToothId, ToothState> states,
  ) async {
    final controller = ref.read(perioControllerProvider(patientId).notifier);
    try {
      final exam = await controller.save(
        ctx: ref.read(actorContextProvider),
        repo: ref.read(perioRepositoryProvider),
        now: ref.read(clockProvider)(),
        states: states,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${ChartStrings.examSaved} · ${exam.summary.sitesRecorded} sites',
          ),
        ),
      );
    } on Object catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings;
    final seed = ref.watch(chartSeedProvider(patientId));
    final statesAsync = ref.watch(toothStatesProvider(patientId));
    if (seed.isLoading || statesAsync.isLoading) {
      return LoadingScaffold(message: s.loading);
    }
    final states = statesAsync.value ?? const <ToothId, ToothState>{};
    final draft = ref.watch(perioControllerProvider(patientId));
    final controller = ref.read(perioControllerProvider(patientId).notifier);
    final notation = ref.watch(notationProvider);
    final exams = ref.watch(perioExamsProvider(patientId)).value ?? const [];
    final sequence = controller.sequence(states);
    final cell = PerioEntryCursor(sequence, draft.cursor).current;
    final flagCell = controller.flagCell(states);
    final reading = flagCell == null ? null : controller.readingAt(flagCell);
    return Scaffold(
      appBar: AppBar(
        title: Text(ChartStrings.perioChart),
        actions: [
          IconButton(
            key: const ValueKey('perio-save'),
            tooltip: s.save,
            icon: const Icon(Icons.save_outlined),
            onPressed: draft.hasContent
                ? () => _save(context, ref, states)
                : null,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          AppSpacing.sm,
          AppSpacing.sm,
          AppSpacing.xl,
        ),
        children: [
          BpeEntry(
            value: draft.bpe,
            furcation: draft.bpeFurcation,
            onChanged: controller.setBpe,
            onFurcationToggled: controller.toggleBpeFurcation,
          ),
          const SizedBox(height: AppSpacing.sm),
          _PerioControls(draft: draft, controller: controller),
          const SizedBox(height: AppSpacing.sm),
          if (sequence.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                ChartStrings.lockedHint,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          else
            PerioChart(
              key: const ValueKey('perio-chart'),
              arch: draft.arch,
              aspect: draft.aspect,
              states: {
                for (final e in states.entries)
                  if (draft.sextantUnlocked(Sextant.of(e.key))) e.key: e.value,
              },
              readings: draft.readings,
              toothReadings: draft.teeth.values.toList(),
              focusedCell: cell,
              notation: notation,
              onCellTap: (tooth, site, type) {
                if (type == PerioMeasurementType.mobility) {
                  controller.cycleMobility(tooth);
                } else if (type == PerioMeasurementType.furcation) {
                  controller.cycleFurcation(tooth);
                } else if (site != null) {
                  if (type.isPerSite && !type.isBoolean) {
                    controller.setMeasure(type);
                  }
                  controller.jumpTo((tooth, site), states);
                }
              },
            ),
          const SizedBox(height: AppSpacing.sm),
          PerioSummaryCard(
            summary: draft.summary,
            acceptedStage: draft.acceptedStage,
            onAcceptStage: controller.acceptStage,
            lastExam: exams.isEmpty ? null : exams.first,
          ),
        ],
      ),
      bottomNavigationBar: Material(
        color: Theme.of(context).colorScheme.surfaceContainer,
        elevation: 3,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.xs,
              AppSpacing.sm,
              AppSpacing.xs,
            ),
            child: PerioPad(
              enabled: cell != null,
              bleeding: reading?.bleeding ?? false,
              suppuration: reading?.suppuration ?? false,
              plaque: reading?.plaque ?? false,
              onDigit: (v) => controller.enterDigit(v, states),
              onNext: () => controller.next(states),
              onPrevious: controller.previous,
              onClear: () => controller.clear(states),
              onToggle: (type) => controller.toggleFlag(type, states),
            ),
          ),
        ),
      ),
    );
  }
}

class _PerioControls extends StatelessWidget {
  const _PerioControls({required this.draft, required this.controller});

  final PerioDraft draft;
  final PerioController controller;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ChoiceChip(
          key: const ValueKey('perio-arch-upper'),
          label: Text(ChartStrings.upper),
          selected: draft.arch == Arch.upper,
          onSelected: (_) => controller.setArch(Arch.upper),
        ),
        ChoiceChip(
          key: const ValueKey('perio-arch-lower'),
          label: Text(ChartStrings.lower),
          selected: draft.arch == Arch.lower,
          onSelected: (_) => controller.setArch(Arch.lower),
        ),
        for (final aspect in PerioAspect.values)
          ChoiceChip(
            key: ValueKey('perio-aspect-${aspect.name}'),
            label: Text(aspect.label),
            selected: draft.aspect == aspect,
            onSelected: (_) => controller.setAspect(aspect),
          ),
        ChoiceChip(
          key: const ValueKey('perio-measure-probingDepth'),
          label: Text(ChartStrings.probingDepth),
          selected: draft.measure == PerioMeasurementType.probingDepth,
          onSelected: (_) =>
              controller.setMeasure(PerioMeasurementType.probingDepth),
        ),
        ChoiceChip(
          key: const ValueKey('perio-measure-gingivalMargin'),
          label: Text(ChartStrings.gingivalMargin),
          selected: draft.measure == PerioMeasurementType.gingivalMargin,
          onSelected: (_) =>
              controller.setMeasure(PerioMeasurementType.gingivalMargin),
        ),
        if (draft.measure == PerioMeasurementType.gingivalMargin)
          FilterChip(
            key: const ValueKey('perio-recession'),
            label: Text(
              draft.recession ? ChartStrings.recession : ChartStrings.coronal,
            ),
            selected: draft.recession,
            onSelected: (_) => controller.toggleRecession(),
          ),
        FilterChip(
          key: const ValueKey('perio-chart-all'),
          label: Text(ChartStrings.chartAll),
          selected: draft.chartAll,
          onSelected: (_) => controller.toggleChartAll(),
        ),
      ],
    );
  }
}
