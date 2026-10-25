import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_mobile/core/router.dart';
import 'package:ampdent_mobile/core/whatsapp_cloud.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'whatsapp_config_form.dart';
import 'whatsapp_test_message.dart';

/// Settings > WhatsApp: which provider is in use, the clinic's Cloud API
/// status from the server, the owner's configuration form (token goes to
/// Vault through the RPC, never stored here), pause/resume, and a test
/// message to the owner's own number.
class WhatsAppSettingsPage extends ConsumerWidget {
  /// Creates the page.
  const WhatsAppSettingsPage({super.key});

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    bool enabled,
  ) async {
    final service = ref.read(whatsappCloudServiceProvider);
    final clinicId = ref.read(currentClinicIdProvider);
    if (service == null || clinicId == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await service.setEnabled(clinicId, enabled);
      ref.invalidate(whatsappStatusProvider);
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not change: $e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configured = ref.watch(cloudActiveProvider);
    final signedIn = ref.watch(cloudAuthProvider.select((a) => a.isSignedIn));
    final mode = ref.watch(messagingModeProvider);
    final status = ref.watch(whatsappStatusProvider);
    final member = ref.watch(currentMemberProvider).value;
    final isOwner = member?.role == ClinicRole.ownerDentist;
    return Scaffold(
      appBar: AppBar(
        title: const Text('WhatsApp'),
        actions: [
          if (configured && signedIn)
            IconButton(
              key: const ValueKey('whatsapp-refresh'),
              tooltip: 'Refresh',
              onPressed: () => ref.invalidate(whatsappStatusProvider),
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: ListView(
        padding: AppSpacing.screenPadding,
        children: [
          _ModeCard(mode: mode),
          const SizedBox(height: AppSpacing.lg),
          if (!configured)
            SectionCard(
              key: const ValueKey('whatsapp-not-configured'),
              title: MobileStrings.cloudNotConfigured,
              child: const Text(MobileStrings.cloudNotConfiguredHelp),
            )
          else if (!signedIn)
            SectionCard(
              key: const ValueKey('whatsapp-signed-out'),
              title: 'Sign in first',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'The Cloud API settings live on the server. Sign in to '
                    'see or change them.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  BigActionButton(
                    label: 'Sign in',
                    icon: Icons.login,
                    onPressed: () => context.push(signInLocation),
                  ),
                ],
              ),
            )
          else
            status.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => ErrorView(
                message: 'Could not read the status: $e',
                onRetry: () => ref.invalidate(whatsappStatusProvider),
              ),
              data: (st) => st == null
                  ? const SectionCard(
                      title: 'Not linked',
                      child: Text(
                        'Link this phone to the clinic (Settings > Account) '
                        'to read the WhatsApp status.',
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _StatusCard(
                          status: st,
                          canToggle: isOwner,
                          onToggle: (v) => _toggle(context, ref, v),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        if (isOwner)
                          const WhatsAppConfigForm()
                        else
                          const SectionCard(
                            title: 'Owner only',
                            child: Text(
                              'Only the clinic owner can enter or change the '
                              'Cloud API credentials.',
                            ),
                          ),
                        const SizedBox(height: AppSpacing.lg),
                        if (st.isActive) const WhatsAppTestMessageCard(),
                      ],
                    ),
            ),
          const SizedBox(height: AppSpacing.lg),
          const ListTile(
            leading: Icon(Icons.menu_book_outlined),
            title: Text('Setup guide'),
            subtitle: Text(
              '${MobileStrings.setupGuidePath} in the repository walks through '
              'the Supabase project, Meta app, templates and billing.',
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.mode});

  final MessagingMode mode;

  @override
  Widget build(BuildContext context) {
    final cloud = mode == MessagingMode.cloudApi;
    return SectionCard(
      title: 'Messages currently go',
      trailing: StatusBadge(
        key: const ValueKey('whatsapp-mode'),
        label: cloud ? 'Cloud API' : 'This phone',
        tone: cloud ? BadgeTone.success : BadgeTone.info,
        dense: true,
      ),
      child: Text(
        cloud
            ? 'Queued on this phone and sent by the server from the clinic\'s '
                  'WhatsApp Business number, with delivery receipts.'
            : 'Through WhatsApp on this phone: the message opens prefilled and '
                  'you press send. Delivery is not tracked.',
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.status,
    required this.canToggle,
    required this.onToggle,
  });

  final WhatsAppStatus status;
  final bool canToggle;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final st = status;
    return SectionCard(
      title: 'Cloud API status',
      trailing: StatusBadge(
        key: const ValueKey('whatsapp-status'),
        label: !st.configured
            ? 'Not configured'
            : st.enabled
            ? 'Enabled'
            : 'Paused',
        tone: !st.configured
            ? BadgeTone.neutral
            : st.enabled
            ? BadgeTone.success
            : BadgeTone.warning,
        dense: true,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (st.configured) ...[
            LabeledValue(
              label: 'Phone number id',
              value: st.phoneNumberId ?? '-',
            ),
            LabeledValue(label: 'WABA id', value: st.wabaId ?? '-'),
            LabeledValue(
              label: 'Display phone',
              value: st.displayPhone == null
                  ? '-'
                  : AppFormat.phone(st.displayPhone!),
            ),
            LabeledValue(
              label: 'Queued on server / failed (24 h)',
              value: '${st.queuedCount} / ${st.failedLast24h}',
            ),
            if (st.updatedAt != null)
              LabeledValue(
                label: 'Updated',
                value: AppFormat.dateTime(st.updatedAt!),
              ),
            SwitchListTile(
              key: const ValueKey('whatsapp-enabled'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Sending enabled'),
              subtitle: const Text(
                'Pause without re-entering the token; queued rows wait.',
              ),
              value: st.enabled,
              onChanged: canToggle ? onToggle : null,
            ),
          ] else
            const Text(
              'No Meta phone number is configured for this clinic yet. Fill '
              'in the form below from the Meta app dashboard.',
            ),
        ],
      ),
    );
  }
}
