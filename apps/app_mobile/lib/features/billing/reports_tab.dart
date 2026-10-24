import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'billing_providers.dart';
import 'billing_reports.dart';
import 'billing_strings.dart';

/// Clinic month-to-date figures: collections, production, outstanding and
/// collections by payment method.
class ReportsTab extends ConsumerWidget {
  /// Creates the tab.
  const ReportsTab({super.key, required this.patientId});

  /// Patient whose page hosts the tab (drives refresh).
  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(billingReportProvider(patientId));
    return report.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(billingReportProvider(patientId)),
      ),
      data: (r) => _ReportBody(report: r),
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.report});

  final BillingReport report;

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMMM yyyy', 'en_IN').format(report.month);
    return ListView(
      padding: AppSpacing.screenPadding,
      children: [
        Text(
          '${BillingStrings.thisMonth} - $monthLabel',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          childAspectRatio: 1.6,
          children: [
            ReportTile(
              key: const ValueKey('report-collections'),
              label: BillingStrings.collections,
              value: AppFormat.money(report.netCollections, showPaise: false),
              icon: Icons.payments_outlined,
            ),
            ReportTile(
              key: const ValueKey('report-production'),
              label: BillingStrings.production,
              value: AppFormat.money(report.production, showPaise: false),
              icon: Icons.medical_services_outlined,
            ),
            ReportTile(
              key: const ValueKey('report-outstanding'),
              label: BillingStrings.outstanding,
              value: AppFormat.money(report.outstanding, showPaise: false),
              icon: Icons.hourglass_bottom_outlined,
            ),
            ReportTile(
              key: const ValueKey('report-invoices'),
              label: BillingStrings.invoicesIssued,
              value: '${report.invoicesIssued}',
              icon: Icons.receipt_long_outlined,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        SectionCard(
          title: BillingStrings.byMethod,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (report.collectionsByMethod.isEmpty)
                Text('-', style: Theme.of(context).textTheme.bodyMedium),
              for (final method in PaymentMethod.values)
                if (report.collectionsByMethod[method] != null)
                  LabeledValue(
                    key: ValueKey('report-method-${method.name}'),
                    label: BillingStrings.paymentMethodLabel(method),
                    value: AppFormat.money(report.collectionsByMethod[method]!),
                    dense: true,
                  ),
              if (!report.refunds.isZero)
                LabeledValue(
                  label: BillingStrings.refunds,
                  value: '-${AppFormat.money(report.refunds)}',
                  dense: true,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A single report figure.
class ReportTile extends StatelessWidget {
  /// Creates the tile.
  const ReportTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  /// Caption.
  final String label;

  /// Pre-formatted figure.
  final String value;

  /// Leading icon.
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(label, style: theme.textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}
