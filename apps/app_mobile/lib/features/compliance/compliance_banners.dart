import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'compliance_labels.dart';
import 'compliance_providers.dart';
import 'compliance_rules.dart';

/// Stacked alert banners: failed spore test, weekly spore test due, licences
/// expiring within [licenceWarningDays]. Renders nothing when all is well.
class ComplianceBanners extends ConsumerWidget {
  /// Creates the banners. [onSporeTap] / [onLicenceTap] switch tabs.
  const ComplianceBanners({super.key, this.onSporeTap, this.onLicenceTap});

  /// Tap on either spore-test banner.
  final VoidCallback? onSporeTap;

  /// Tap on the licence banner.
  final VoidCallback? onLicenceTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final now = ref.watch(clockProvider)();
    final cycles = ref.watch(recentCyclesProvider).value ?? const [];
    final failed = ref.watch(sporeTestFailedProvider);
    final overdue = ref.watch(sporeTestOverdueProvider);
    final licences = ref.watch(attentionLicencesProvider);
    final children = <Widget>[
      if (failed)
        AlertBanner(
          key: const ValueKey('spore-test-failed-banner'),
          color: colors.danger,
          icon: Icons.dangerous_outlined,
          title: 'Last spore test failed',
          message: 'Do not use the autoclave until a passing test is logged.',
          onTap: onSporeTap,
        ),
      if (overdue)
        AlertBanner(
          key: const ValueKey('spore-test-banner'),
          color: colors.warning,
          icon: Icons.biotech_outlined,
          title: 'Weekly spore test due',
          message: _lastSporeMessage(cycles),
          onTap: onSporeTap,
        ),
      if (licences.isNotEmpty)
        AlertBanner(
          key: const ValueKey('licence-expiry-banner'),
          color:
              licences.any(
                (l) => licenceAlertLevel(l, now) == LicenceAlertLevel.expired,
              )
              ? colors.danger
              : colors.warning,
          icon: Icons.badge_outlined,
          title: licences.length == 1
              ? '1 licence needs attention'
              : '${licences.length} licences need attention',
          message: licences.take(2).map((l) => _licenceLine(l, now)).join('\n'),
          onTap: onLicenceTap,
        ),
    ];
    if (children.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final c in children)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: c,
          ),
      ],
    );
  }

  static String _lastSporeMessage(List<SterilisationCycle> cycles) {
    final last = lastSporeTestAt(cycles);
    return last == null
        ? 'No biological indicator recorded yet.'
        : 'Last test ${AppFormat.date(last)}.';
  }

  static String _licenceLine(Licence l, DateTime now) {
    final days = licenceDaysToDue(l, now) ?? 0;
    final when = days < 0
        ? 'expired ${-days} d ago'
        : days == 0
        ? 'due today'
        : 'due in $days d';
    return '${licenceKindLabel(l.kind)} - $when';
  }
}

/// One coloured alert strip with icon, title and message.
class AlertBanner extends StatelessWidget {
  /// Creates the banner.
  const AlertBanner({
    super.key,
    required this.color,
    required this.icon,
    required this.title,
    required this.message,
    this.onTap,
  });

  /// Accent colour.
  final Color color;

  /// Leading icon.
  final IconData icon;

  /// Bold first line.
  final String title;

  /// Supporting text.
  final String message;

  /// Tap target.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: AppRadii.mdAll,
      child: InkWell(
        borderRadius: AppRadii.mdAll,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(color: color),
                    ),
                    Text(message, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
