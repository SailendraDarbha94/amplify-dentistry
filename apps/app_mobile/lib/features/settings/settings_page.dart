import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Settings root: links to every configuration page.
class SettingsPage extends ConsumerWidget {
  /// Creates the page.
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings;
    final clinic = ref.watch(currentClinicProvider).value;
    final member = ref.watch(currentMemberProvider).value;
    final notation = ref.watch(notationProvider);
    final entries = <(IconData, String, String, String)>[
      (
        Icons.local_hospital_outlined,
        'Clinic profile',
        clinic == null ? '' : '${clinic.name}, ${clinic.city}',
        '/settings/clinic',
      ),
      (
        Icons.badge_outlined,
        'Members',
        member == null ? '' : 'Acting as ${member.displayName}',
        '/settings/members',
      ),
      (
        Icons.percent_outlined,
        'GST rates',
        clinic?.isGstRegistered == true
            ? 'GSTIN ${clinic!.gstin}'
            : 'Not GST registered; receipts only',
        '/settings/gst',
      ),
      (Icons.chair_outlined, 'Chairs', '', '/settings/chairs'),
      (Icons.science_outlined, 'Labs', '', '/settings/labs'),
      (Icons.grid_on, 'Tooth notation', notation.label, '/settings/notation'),
      (
        Icons.info_outline,
        'About / data ownership',
        'Export is always available',
        '/settings/about',
      ),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(s.settings)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: [
          for (final (icon, title, subtitle, route) in entries)
            ListTile(
              key: ValueKey('settings-$route'),
              leading: Icon(icon),
              title: Text(title),
              subtitle: subtitle.isEmpty ? null : Text(subtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(route),
            ),
        ],
      ),
    );
  }
}
