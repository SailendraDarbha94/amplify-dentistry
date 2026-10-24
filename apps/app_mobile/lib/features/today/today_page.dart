// Today dashboard. The five home-screen numbers from
// docs/research/02-product-spec.md ("Reports and KPIs") are: today's
// production, this month's collections, overdue recall value,
// accepted-but-unscheduled treatment value and no-show rate.
//
// This build wires the cheap counts (appointments today, patients) and marks
// the rest as coming. The export/reporting agent completes the TODO blocks.

import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_mobile/features/patients/patient_providers.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Appointments whose start falls on the local calendar day of now.
final StreamProvider<List<Appointment>> todaysAppointmentsProvider =
    StreamProvider<List<Appointment>>((ref) {
      final clinicId = ref.watch(currentClinicIdProvider);
      if (clinicId == null) return Stream.value(const []);
      final now = ref.watch(clockProvider)();
      final start = DateTime(now.year, now.month, now.day);
      final end = start.add(const Duration(days: 1));
      return ref
          .watch(appointmentRepositoryProvider)
          .watchRange(clinicId, start.toUtc(), end.toUtc());
    });

/// Rupee value of recalls that are due or overdue right now.
final StreamProvider<Money> overdueRecallValueProvider = StreamProvider<Money>((
  ref,
) {
  final clinicId = ref.watch(currentClinicIdProvider);
  if (clinicId == null) return Stream.value(const Money.zero());
  final now = ref.watch(clockProvider)();
  return ref
      .watch(recallRepositoryProvider)
      .watchDue(clinicId, until: now.toUtc())
      .map((list) => list.map((r) => r.estimatedValue).total);
});

/// Today tab: five KPI tiles and quick actions.
class TodayPage extends ConsumerWidget {
  /// Creates the page.
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings;
    final clinic = ref.watch(currentClinicProvider).value;
    final member = ref.watch(currentMemberProvider).value;
    final now = ref.watch(clockProvider)();
    final appointments = ref.watch(todaysAppointmentsProvider).value;
    final patientCount = ref.watch(patientCountProvider).value;
    final recallValue = ref.watch(overdueRecallValueProvider).value;
    return Scaffold(
      appBar: AppBar(
        title: Text(clinic?.name ?? s.appName),
        actions: [
          IconButton(
            tooltip: s.settings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: ListView(
        padding: AppSpacing.screenPadding,
        children: [
          Text(
            AppFormat.weekdayDate(now),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          if (member != null)
            Text(
              'Good day, ${member.displayName}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          const SizedBox(height: AppSpacing.lg),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 1.5,
            children: [
              KpiTile(
                key: const ValueKey('kpi-appointments'),
                label: 'Appointments today',
                value: appointments == null ? '-' : '${appointments.length}',
                icon: Icons.calendar_today_outlined,
                onTap: () => context.go('/schedule'),
              ),
              KpiTile(
                key: const ValueKey('kpi-patients'),
                label: s.patients,
                value: patientCount == null ? '-' : '$patientCount',
                icon: Icons.people_outline,
                onTap: () => context.go('/patients'),
              ),
              // TODO(export-agent): today's production = sum of completed
              // procedure net fees today (ChartRepository / ledger charges).
              const KpiTile(
                key: ValueKey('kpi-production'),
                label: "Today's production",
                value: MobileStrings.comingInThisBuild,
                icon: Icons.trending_up,
                pending: true,
              ),
              // TODO(export-agent): this month's collections = sum of
              // payments received this month (BillingRepository).
              const KpiTile(
                key: ValueKey('kpi-collections'),
                label: 'Collections this month',
                value: MobileStrings.comingInThisBuild,
                icon: Icons.payments_outlined,
                pending: true,
              ),
              KpiTile(
                key: const ValueKey('kpi-recall'),
                label: 'Overdue recall value',
                value: recallValue == null
                    ? '-'
                    : AppFormat.money(recallValue, showPaise: false),
                icon: Icons.notifications_outlined,
                onTap: () => context.push('/recall'),
              ),
              // TODO(export-agent): accepted-but-unscheduled treatment value
              // (TreatmentPlanRepository: accepted lines with no appointment)
              // and no-show rate (AppointmentRepository, last 30 days).
              const KpiTile(
                key: ValueKey('kpi-unscheduled'),
                label: 'Accepted, not scheduled',
                value: MobileStrings.comingInThisBuild,
                icon: Icons.pending_actions_outlined,
                pending: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Quick actions', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 0.9,
            children: [
              QuickActionTile(
                icon: Icons.person_add_alt_1,
                label: s.newPatient,
                onTap: () => context.push('/patients/new'),
              ),
              QuickActionTile(
                icon: Icons.event_available_outlined,
                label: s.appointment,
                onTap: () => context.push('/schedule/new'),
              ),
              QuickActionTile(
                icon: Icons.notifications_outlined,
                label: s.recall,
                onTap: () => context.push('/recall'),
              ),
              QuickActionTile(
                icon: Icons.science_outlined,
                label: s.lab,
                onTap: () => context.push('/lab'),
              ),
            ],
          ),
          // TODO(appointments-agent): today's appointment list with
          // arrive / in-chair / done actions goes here.
        ],
      ),
    );
  }
}

/// One KPI card. [pending] renders the value muted.
class KpiTile extends StatelessWidget {
  /// Creates a tile.
  const KpiTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.onTap,
    this.pending = false,
  });

  /// Caption.
  final String label;

  /// Headline number or text.
  final String value;

  /// Corner icon.
  final IconData icon;

  /// Tap target.
  final VoidCallback? onTap;

  /// Whether the KPI is not computed yet.
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: muted, size: 20),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: pending
                    ? theme.textTheme.bodyMedium?.copyWith(color: muted)
                    : theme.textTheme.headlineSmall,
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
