import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// One entry of the More menu.
class MoreMenuEntry {
  /// Creates an entry.
  const MoreMenuEntry({
    required this.icon,
    required this.label,
    required this.route,
    this.description,
  });

  /// Leading icon.
  final IconData icon;

  /// Title.
  final String label;

  /// Destination path.
  final String route;

  /// Optional one-line description.
  final String? description;
}

/// Entries shown on the More page, in order.
const List<MoreMenuEntry> moreMenuEntries = [
  MoreMenuEntry(
    icon: Icons.notifications_outlined,
    label: 'Recall',
    route: '/recall',
    description: 'Patients due for hygiene, review and post-op checks',
  ),
  MoreMenuEntry(
    icon: Icons.science_outlined,
    label: 'Lab cases',
    route: '/lab',
    description: 'Crowns, dentures and aligners out with the lab',
  ),
  MoreMenuEntry(
    icon: Icons.verified_user_outlined,
    label: 'Compliance',
    route: '/compliance',
    description: 'Sterilisation log and licence wallet',
  ),
  MoreMenuEntry(
    icon: Icons.download_outlined,
    label: 'Export',
    route: '/export',
    description: 'Patient and clinic data export',
  ),
  MoreMenuEntry(
    icon: Icons.history_outlined,
    label: 'Audit log',
    route: '/audit',
    description: 'Who changed what, when',
  ),
  MoreMenuEntry(
    icon: Icons.settings_outlined,
    label: 'Settings',
    route: '/settings',
    description: 'Clinic, members, GST, chairs, labs, notation',
  ),
];

/// The More tab: links to recall, lab, compliance, export, audit and
/// settings, with the clinic and acting member on top.
class MorePage extends ConsumerWidget {
  /// Creates the page.
  const MorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings;
    final clinic = ref.watch(currentClinicProvider).value;
    final member = ref.watch(currentMemberProvider).value;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.more)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: [
          if (clinic != null)
            ListTile(
              leading: const Icon(Icons.local_hospital_outlined),
              title: Text(clinic.name, style: theme.textTheme.titleMedium),
              subtitle: Text(
                member == null
                    ? clinic.city
                    : 'Acting as ${member.displayName}  ·  ${clinic.city}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/members'),
            ),
          const Divider(),
          for (final e in moreMenuEntries)
            ListTile(
              key: ValueKey('more-${e.route}'),
              leading: Icon(e.icon),
              title: Text(e.label),
              subtitle: e.description == null ? null : Text(e.description!),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(e.route),
            ),
        ],
      ),
    );
  }
}
