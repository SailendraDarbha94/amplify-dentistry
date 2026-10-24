import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'plan_model.dart';
import 'plan_phase_section.dart';
import 'plan_providers.dart';

/// Badge tone for a plan status.
BadgeTone planStatusTone(TreatmentPlanStatus status) => switch (status) {
  TreatmentPlanStatus.active => BadgeTone.planned,
  TreatmentPlanStatus.accepted => BadgeTone.success,
  TreatmentPlanStatus.completed => BadgeTone.completed,
  TreatmentPlanStatus.inactive ||
  TreatmentPlanStatus.saved ||
  TreatmentPlanStatus.superseded => BadgeTone.neutral,
};

/// Treatment plans of a patient, active first, with funnel chips and the
/// pre-tax total; a button starts a new plan.
class PlanListPage extends ConsumerWidget {
  /// Creates the page.
  const PlanListPage({super.key, required this.patientId});

  /// The patient.
  final String patientId;

  Future<void> _newPlan(BuildContext context, WidgetRef ref) async {
    final router = GoRouter.of(context);
    final plan = await ref
        .read(planServiceProvider)
        .createPlan(patientId: patientId, now: ref.read(clockProvider)());
    await router.push('/patients/$patientId/plan/${plan.id}');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings;
    final plans = ref.watch(patientPlansProvider(patientId));
    final procedures =
        ref.watch(planProceduresProvider(patientId)).value ?? const [];
    final appointments =
        ref.watch(planAppointmentsProvider(patientId)).value ?? const [];
    return Scaffold(
      appBar: AppBar(title: Text('${s.treatmentPlan}s')),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('plan-new'),
        onPressed: () => _newPlan(context, ref),
        icon: const Icon(Icons.add),
        label: Text('New ${s.plan.toLowerCase()}'),
      ),
      body: plans.when(
        loading: () => Center(child: Text(s.loading)),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(patientPlansProvider(patientId)),
        ),
        data: (list) => list.isEmpty
            ? EmptyState(
                icon: Icons.assignment_outlined,
                title: s.nothingHere,
                message:
                    'Start a plan from the planned procedures on the chart',
              )
            : ListView(
                padding: const EdgeInsets.only(bottom: 96),
                children: [
                  for (final p in list)
                    _PlanTile(
                      plan: p,
                      procedures: procedures,
                      appointments: appointments,
                      onTap: () =>
                          context.push('/patients/$patientId/plan/${p.id}'),
                    ),
                ],
              ),
      ),
    );
  }
}

class _PlanTile extends ConsumerWidget {
  const _PlanTile({
    required this.plan,
    required this.procedures,
    required this.appointments,
    required this.onTap,
  });

  final TreatmentPlan plan;
  final List<ProcedureRecord> procedures;
  final List<Appointment> appointments;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final lines = ref.watch(planLinesProvider(plan.id)).value ?? const [];
    final funnel = PlanFunnel.of(
      plan: plan,
      lines: lines,
      procedures: procedures,
      appointments: appointments,
    );
    return ListTile(
      key: ValueKey('plan-row-${plan.id}'),
      onTap: onTap,
      isThreeLine: true,
      title: Row(
        children: [
          Expanded(
            child: Text(
              '${plan.title}  v${plan.version}',
              style: theme.textTheme.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          StatusBadge(
            label: AppFormat.enumLabel(plan.status),
            tone: planStatusTone(plan.status),
            dense: true,
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${lines.where((l) => !l.isAlternative).length} procedures  |  '
              '${AppFormat.money(planSubtotal(lines), showPaise: false)}  |  '
              '${AppFormat.date(plan.updatedAt)}',
            ),
            const SizedBox(height: AppSpacing.xs),
            PlanFunnelChips(funnel: funnel),
          ],
        ),
      ),
    );
  }
}
