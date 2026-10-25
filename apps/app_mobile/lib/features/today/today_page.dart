// Today dashboard. The five home-screen numbers from
// docs/research/02-product-spec.md ("Reports and KPIs") are: today's
// production, this month's collections, overdue recall value,
// accepted-but-unscheduled treatment value and no-show rate. Below them:
// today's appointment list with "Start visit" and quick actions. The
// pending-sync banner belongs to the app shell, not to this page.

import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_mobile/features/compliance/compliance_providers.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'today_appointments.dart';
import 'today_kpis.dart';
import 'today_providers.dart';
import 'today_sheets.dart';

export 'today_providers.dart'
    show overdueRecallValueProvider, todaysAppointmentsProvider;

/// Today tab: five KPI tiles, today's appointments, quick actions.
class TodayPage extends ConsumerWidget {
  /// Creates the page.
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings;
    final theme = Theme.of(context);
    final clinic = ref.watch(currentClinicProvider).value;
    final member = ref.watch(currentMemberProvider).value;
    final now = ref.watch(clockProvider)();
    final appointments = ref.watch(todaysAppointmentsProvider).value;
    final kpis = ref.watch(todayKpisProvider);
    final alerts = ref.watch(complianceAlertCountProvider);
    String money(TodayKpis? k, Money Function(TodayKpis) pick) =>
        k == null ? '-' : AppFormat.money(pick(k), showPaise: false);
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
          Text(AppFormat.weekdayDate(now), style: theme.textTheme.labelLarge),
          if (member != null)
            Text(
              'Good day, ${member.displayName}',
              style: theme.textTheme.headlineSmall,
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
                key: const ValueKey('kpi-production'),
                label: "Today's production",
                value: money(kpis, (k) => k.productionToday),
                icon: Icons.trending_up,
                pending: kpis == null,
                onTap: () =>
                    showTodaySheet(context, const CompletedTodaySheet()),
              ),
              KpiTile(
                key: const ValueKey('kpi-collections'),
                label: 'Collections this month',
                value: money(kpis, (k) => k.collectionsThisMonth),
                icon: Icons.payments_outlined,
                pending: kpis == null,
              ),
              KpiTile(
                key: const ValueKey('kpi-recall'),
                label: 'Overdue recall value',
                value: money(kpis, (k) => k.overdueRecallValue),
                icon: Icons.notifications_outlined,
                pending: kpis == null,
                onTap: () => context.push('/recall'),
              ),
              KpiTile(
                key: const ValueKey('kpi-unscheduled'),
                label: 'Accepted, not scheduled',
                value: money(kpis, (k) => k.acceptedUnscheduledValue),
                icon: Icons.pending_actions_outlined,
                pending: kpis == null,
                onTap: () =>
                    showTodaySheet(context, const UnscheduledPlanSheet()),
              ),
              KpiTile(
                key: const ValueKey('kpi-noshow'),
                label: 'No-show rate this month',
                value: kpis == null ? '-' : formatRate(kpis.noShowRate),
                semanticLabel: noShowSemanticLabel(kpis),
                icon: Icons.person_off_outlined,
                pending: kpis == null,
                onTap: () => context.go('/schedule'),
              ),
              KpiTile(
                key: const ValueKey('kpi-appointments'),
                label: 'Appointments today',
                value: appointments == null ? '-' : '${appointments.length}',
                icon: Icons.calendar_today_outlined,
                pending: appointments == null,
                onTap: () => context.go('/schedule'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Quick actions', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 0.85,
            children: [
              QuickActionTile(
                key: const ValueKey('qa-new-patient'),
                icon: Icons.person_add_alt_1,
                label: s.newPatient,
                onTap: () => context.push('/patients/new'),
              ),
              QuickActionTile(
                key: const ValueKey('qa-new-appointment'),
                icon: Icons.event_available_outlined,
                label: s.appointment,
                onTap: () => context.push('/schedule/new'),
              ),
              QuickActionTile(
                key: const ValueKey('qa-recall'),
                icon: Icons.notifications_outlined,
                label: s.recall,
                onTap: () => context.push('/recall'),
              ),
              QuickActionTile(
                key: const ValueKey('qa-lab'),
                icon: Icons.science_outlined,
                label: s.lab,
                onTap: () => context.push('/lab'),
              ),
              QuickActionTile(
                key: const ValueKey('qa-compliance'),
                icon: Icons.verified_user_outlined,
                label: 'Compliance',
                badgeCount: alerts == 0 ? null : alerts,
                color: alerts == 0 ? null : AppColors.of(context).warning,
                onTap: () => context.push('/compliance'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text("Today's appointments", style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          const TodayAppointmentList(),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

/// One KPI card. [pending] renders the value muted while it loads.
class KpiTile extends StatelessWidget {
  /// Creates a tile.
  const KpiTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.onTap,
    this.pending = false,
    this.semanticLabel,
  });

  /// Caption.
  final String label;

  /// Headline number or text.
  final String value;

  /// Screen-reader text replacing the visible value and caption when the
  /// value alone (a dash) would not read as anything.
  final String? semanticLabel;

  /// Corner icon.
  final IconData icon;

  /// Tap target.
  final VoidCallback? onTap;

  /// Whether the KPI is still loading.
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final card = Card(
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
                    ? theme.textTheme.titleMedium?.copyWith(color: muted)
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
    final semantic = semanticLabel;
    if (semantic == null) return card;
    return Semantics(
      container: true,
      label: semantic,
      button: onTap != null,
      onTap: onTap,
      child: ExcludeSemantics(child: card),
    );
  }
}
