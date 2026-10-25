import 'dart:async';

import 'package:ampdent_data/ampdent_data.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/clinic_link.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_mobile/core/remote_devices.dart';
import 'package:ampdent_mobile/core/router.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Settings > Account: who is signed in, clinic link status, this clinic's
/// devices, last sync, Sync now, sign out (local data is kept).
class AccountPage extends ConsumerWidget {
  /// Creates the page.
  const AccountPage({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final ok = await ConfirmSheet.show(
      context,
      title: 'Sign out of this phone?',
      message:
          'Patient records stay on this phone and keep working offline. '
          'Changes queue up and sync again after you sign back in.',
      confirmLabel: 'Sign out',
      icon: Icons.logout,
    );
    if (!ok) return;
    await ref.read(cloudAuthProvider.notifier).signOut();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configured = ref.watch(cloudActiveProvider);
    final config = ref.watch(cloudConfigProvider);
    final auth = ref.watch(cloudAuthProvider);
    final link = ref.watch(clinicLinkProvider);
    final sync = ref.watch(syncStateProvider).value;
    final devices = ref.watch(remoteDevicesProvider);
    final session = ref.watch(appSessionProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        padding: AppSpacing.screenPadding,
        children: [
          if (!configured)
            SectionCard(
              key: const ValueKey('account-not-configured'),
              title: MobileStrings.cloudNotConfigured,
              child: const Text(MobileStrings.cloudNotConfiguredHelp),
            )
          else if (!auth.isSignedIn)
            SectionCard(
              key: const ValueKey('account-signed-out'),
              title: 'Not signed in',
              subtitle: 'Project ${config.projectRef}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Records stay on this phone. Sign in to sync them to the '
                    'clinic\'s cloud account and to send WhatsApp messages '
                    'through the Cloud API.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  BigActionButton(
                    key: const ValueKey('account-sign-in'),
                    label: 'Sign in',
                    icon: Icons.login,
                    onPressed: () => context.push(signInLocation),
                  ),
                ],
              ),
            )
          else ...[
            SectionCard(
              key: const ValueKey('account-signed-in'),
              title: 'Signed in',
              subtitle: 'Project ${config.projectRef}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LabeledValue(label: 'Account', value: auth.user!.label),
                  LabeledValue(label: 'Device id', value: session.deviceId),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    key: const ValueKey('account-sign-out'),
                    onPressed: () => _signOut(context, ref),
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign out (keeps local data)'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _LinkCard(link: link),
            const SizedBox(height: AppSpacing.lg),
            _SyncCard(sync: sync),
            const SizedBox(height: AppSpacing.lg),
            SectionCard(
              title: 'Devices',
              trailing: IconButton(
                tooltip: 'Refresh',
                onPressed: () => ref.invalidate(remoteDevicesProvider),
                icon: const Icon(Icons.refresh),
              ),
              child: devices.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Could not load devices: $e'),
                data: (list) => list.isEmpty
                    ? const Text('No devices registered yet.')
                    : Column(
                        children: [
                          for (final d in list)
                            ListTile(
                              key: ValueKey('device-${d.id}'),
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                d.platform == 'ios'
                                    ? Icons.phone_iphone
                                    : Icons.phone_android,
                              ),
                              title: Text(
                                d.id == session.deviceId
                                    ? 'This phone'
                                    : '${d.platform} ${d.appVersion}',
                              ),
                              subtitle: Text(
                                d.lastSeenAt == null
                                    ? d.id
                                    : 'Seen ${AppFormat.dateTime(d.lastSeenAt!)}',
                              ),
                              trailing: d.isPrimary
                                  ? const StatusBadge(
                                      label: 'Primary',
                                      tone: BadgeTone.success,
                                      dense: true,
                                    )
                                  : null,
                            ),
                        ],
                      ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: const Text('Setup guide'),
            subtitle: const Text(MobileStrings.setupGuidePath),
            onTap: null,
          ),
        ],
      ),
    );
  }
}

class _LinkCard extends ConsumerWidget {
  const _LinkCard({required this.link});

  final ClinicLinkState link;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(clinicLinkProvider.notifier);
    final (label, tone) = switch (link.phase) {
      LinkPhase.linked => ('Linked', BadgeTone.success),
      LinkPhase.checking || LinkPhase.pulling => ('Working', BadgeTone.info),
      LinkPhase.choosing => ('Needs a choice', BadgeTone.warning),
      LinkPhase.failed => ('Failed', BadgeTone.danger),
      LinkPhase.unlinked => ('No clinic yet', BadgeTone.warning),
      LinkPhase.idle => ('Not checked', BadgeTone.neutral),
    };
    final l = link.link;
    return SectionCard(
      title: 'Clinic link',
      trailing: StatusBadge(
        key: const ValueKey('account-link-status'),
        label: label,
        tone: tone,
        dense: true,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (l != null) ...[
            LabeledValue(
              label: 'Mode',
              value: switch (l.mode) {
                ClinicLinkMode.pushedLocal => 'This phone created the clinic',
                ClinicLinkMode.adoptedRemote => 'Adopted from the server',
              },
            ),
            LabeledValue(
              label: 'Linked',
              value: AppFormat.dateTime(l.linkedAt),
            ),
          ],
          if (link.error != null)
            Text(
              link.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (link.phase == LinkPhase.choosing)
            FilledButton.tonal(
              key: const ValueKey('account-resolve-link'),
              onPressed: () => context.push(signInLocation),
              child: const Text('Choose a clinic'),
            ),
          if (link.phase == LinkPhase.failed ||
              link.phase == LinkPhase.idle ||
              link.phase == LinkPhase.unlinked)
            FilledButton.tonal(
              key: const ValueKey('account-retry-link'),
              onPressed: link.isBusy ? null : controller.run,
              child: const Text('Link now'),
            ),
        ],
      ),
    );
  }
}

class _SyncCard extends ConsumerWidget {
  const _SyncCard({required this.sync});

  final SyncState? sync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = sync;
    final status = s == null
        ? '-'
        : switch (s.status) {
            SyncStatus.idle => 'Idle',
            SyncStatus.pushing => 'Uploading',
            SyncStatus.pulling => 'Downloading',
            SyncStatus.error => 'Error: ${s.error ?? ''}',
            SyncStatus.disabled => 'Waiting for the clinic link',
            SyncStatus.offline => 'Offline (${s.error ?? 'unreachable'})',
          };
    return SectionCard(
      title: 'Sync',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LabeledValue(label: 'Status', value: status),
          LabeledValue(
            label: 'Waiting to upload',
            value: '${s?.pendingCount ?? 0}',
          ),
          LabeledValue(
            label: 'Last sync',
            value: s?.lastSyncedAt == null
                ? 'Never'
                : AppFormat.dateTime(s!.lastSyncedAt!),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            key: const ValueKey('account-sync-now'),
            onPressed: s == null || s.isBusy
                ? null
                : () => unawaited(ref.read(syncNowProvider)()),
            icon: const Icon(Icons.sync),
            label: const Text('Sync now'),
          ),
        ],
      ),
    );
  }
}
