import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_mobile/features/patients/patient_providers.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'plan_builder_actions.dart';
import 'plan_model.dart';
import 'plan_phase_section.dart';
import 'plan_providers.dart';

/// Menu entries of the builder's app bar.
enum PlanMenuAction { rename, present, estimate, estimates, accept, revise }

/// The plan builder: phases with lines, per-phase subtotals, the pre-tax
/// total, funnel chips, and the present / estimate / accept / revise flows.
class PlanBuilderPage extends ConsumerStatefulWidget {
  /// Creates the page.
  const PlanBuilderPage({
    super.key,
    required this.patientId,
    required this.planId,
  });

  /// The patient.
  final String patientId;

  /// The plan.
  final String planId;

  @override
  ConsumerState<PlanBuilderPage> createState() => _PlanBuilderPageState();
}

class _PlanBuilderPageState extends ConsumerState<PlanBuilderPage>
    with PlanBuilderActions {
  @override
  PlanEditor? editor;

  @override
  bool busy = false;

  @override
  String? loadError;

  @override
  Patient? patient;

  @override
  Clinic? clinic;

  @override
  ClinicMember? dentist;

  @override
  void initState() {
    super.initState();
    loadPlan();
  }

  Future<void> _onMenu(PlanMenuAction action) => switch (action) {
    PlanMenuAction.rename => renamePlan(),
    PlanMenuAction.present => presentPlan(),
    PlanMenuAction.estimate => issueEstimateAndPreview(),
    PlanMenuAction.estimates => openEstimates(),
    PlanMenuAction.accept => acceptPlan(),
    PlanMenuAction.revise => revisePlan(),
  };

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final e = editor;
    if (e == null) {
      return loadError == null
          ? LoadingScaffold(message: s.loading)
          : Scaffold(
              appBar: AppBar(),
              body: ErrorView(message: loadError, onRetry: loadPlan),
            );
    }
    patient = ref.watch(patientProvider(widget.patientId)).value;
    clinic = ref.watch(currentClinicProvider).value;
    dentist = ref.watch(currentMemberProvider).value;
    final notation = ref.watch(notationProvider);
    final catalogById = ref.watch(catalogByIdProvider);
    final rates = ref.watch(gstRateTableProvider).value;
    final procedures =
        ref.watch(planProceduresProvider(widget.patientId)).value ?? const [];
    final appointments =
        ref.watch(planAppointmentsProvider(widget.patientId)).value ?? const [];
    final estimates =
        ref.watch(planEstimatesProvider(e.plan.id)).value ?? const [];
    final funnel = PlanFunnel.of(
      plan: e.plan,
      lines: e.lines,
      procedures: procedures,
      appointments: appointments,
    );
    final frozen = e.isFrozen;
    final now = ref.watch(clockProvider)();
    return Scaffold(
      appBar: AppBar(
        title: Text('${e.plan.title}  v${e.plan.version}'),
        actions: [
          PopupMenuButton<PlanMenuAction>(
            key: const ValueKey('plan-menu'),
            enabled: !busy,
            onSelected: _onMenu,
            itemBuilder: (_) => [
              if (!frozen)
                const PopupMenuItem(
                  key: ValueKey('plan-menu-rename'),
                  value: PlanMenuAction.rename,
                  child: Text('Rename plan'),
                ),
              if (!frozen && e.plan.presentedAt == null)
                const PopupMenuItem(
                  key: ValueKey('plan-menu-present'),
                  value: PlanMenuAction.present,
                  child: Text('Mark as presented'),
                ),
              PopupMenuItem(
                key: const ValueKey('plan-menu-estimate'),
                value: PlanMenuAction.estimate,
                child: Text(
                  estimates.isEmpty
                      ? 'Save estimate'
                      : 'Save estimate v${estimates.length + 1}',
                ),
              ),
              if (estimates.isNotEmpty)
                PopupMenuItem(
                  key: const ValueKey('plan-menu-estimates'),
                  value: PlanMenuAction.estimates,
                  child: Text('${s.estimate}s (${estimates.length})'),
                ),
              if (!frozen)
                PopupMenuItem(
                  key: const ValueKey('plan-menu-accept'),
                  value: PlanMenuAction.accept,
                  enabled: e.lines.any((l) => !l.isAlternative),
                  child: const Text('Accept with signature'),
                ),
              if (e.plan.isAccepted)
                const PopupMenuItem(
                  key: ValueKey('plan-menu-revise'),
                  value: PlanMenuAction.revise,
                  child: Text('Revise (new version)'),
                ),
            ],
          ),
        ],
      ),
      floatingActionButton: frozen
          ? null
          : FloatingActionButton.extended(
              key: const ValueKey('plan-add-line'),
              onPressed: busy ? null : () => addLineTo(0),
              icon: const Icon(Icons.add),
              label: const Text('Add line'),
            ),
      bottomNavigationBar: frozen
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            s.total,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          MoneyText(
                            AppFormat.money(e.total, showPaise: false),
                            emphasis: MoneyEmphasis.strong,
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      key: const ValueKey('plan-save'),
                      onPressed: e.dirty && !busy ? saveEditor : null,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(e.dirty ? s.save : 'Saved'),
                    ),
                  ],
                ),
              ),
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          PlanFunnelChips(funnel: funnel),
          if (frozen)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Container(
                key: const ValueKey('plan-frozen-banner'),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: AppRadii.mdAll,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        e.plan.isAccepted
                            ? 'Accepted by ${e.plan.acceptedBySignerName ?? '-'} '
                                  'on ${AppFormat.dateOrDash(e.plan.acceptedAt)}. '
                                  'Lines are frozen; revise to change.'
                            : 'Superseded by a newer version.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (e.plan.presentedAt != null && !e.plan.isAccepted)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                'Presented ${AppFormat.date(e.plan.presentedAt!)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          for (final phase in e.phases) ...[
            PhaseHeader(
              phase: phase,
              subtotal: e.subtotals[phase.index] ?? const Money.zero(),
              onRename: frozen ? null : () => renamePhase(phase),
            ),
            for (final line in e.linesInPhase(phase.index))
              PlanLineTile(
                line: line,
                notation: notation,
                catalogItem: catalogById[line.catalogItemId],
                gstRatePercent: rates
                    ?.rateFor(line.gstClass, at: now)
                    .ratePercent,
                onTap: frozen ? null : () => editLine(line),
                onAction: frozen ? null : (a) => onLineAction(line, a),
              ),
            if (!frozen)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: ValueKey('plan-add-line-${phase.index}'),
                  onPressed: busy ? null : () => addLineTo(phase.index),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text('Add to ${phase.name}'),
                ),
              ),
          ],
          if (!frozen)
            OutlinedButton.icon(
              key: const ValueKey('plan-add-phase'),
              onPressed: busy
                  ? null
                  : () => setState(() => editor = e.addPhase()),
              icon: const Icon(Icons.playlist_add),
              label: const Text('Add phase'),
            ),
          const SizedBox(height: AppSpacing.lg),
          PlanTotalsCard(editor: e),
        ],
      ),
    );
  }
}
