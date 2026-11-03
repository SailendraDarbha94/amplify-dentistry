import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_mobile/core/member_invites.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// Hands text to the system share sheet; overridable in tests.
typedef ShareText = Future<void> Function(String text, {String? subject});

/// Default share implementation (share_plus).
Future<void> shareTextWithSharePlus(String text, {String? subject}) async {
  await SharePlus.instance.share(ShareParams(text: text, subject: subject));
}

/// How invite text is shared.
final Provider<ShareText> inviteShareProvider = Provider<ShareText>(
  (ref) => shareTextWithSharePlus,
);

/// Shows a freshly minted invite code with its expiry, copy and share.
class MemberInviteSheet extends ConsumerWidget {
  /// Creates the sheet body; prefer [show].
  const MemberInviteSheet({
    super.key,
    required this.invite,
    required this.member,
    required this.clinicName,
  });

  /// The minted invite.
  final MemberInvite invite;

  /// Member the code is for.
  final ClinicMember member;

  /// Clinic name for the share text.
  final String clinicName;

  /// Opens the sheet.
  static Future<void> show(
    BuildContext context, {
    required MemberInvite invite,
    required ClinicMember member,
    required String clinicName,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => MemberInviteSheet(
      invite: invite,
      member: member,
      clinicName: clinicName,
    ),
  );

  String get _shareText =>
      invite.shareText(clinicName: clinicName, memberName: member.displayName);

  Future<void> _copy(BuildContext context) async {
    // Shown first: the clipboard call answers through a platform channel,
    // which a widget test never completes.
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Code copied')));
    await Clipboard.setData(ClipboardData(text: invite.displayCode));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final share = ref.watch(inviteShareProvider);
    return Padding(
      padding: AppSpacing.screenPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Invite ${member.displayName} to sign in',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'They install AmpDent, sign in with their own email or mobile '
            'number, tap "I have an invite code" and enter this code. Their '
            'phone then joins this clinic; nothing is set up twice.',
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: SelectableText(
              invite.displayCode,
              key: const ValueKey('invite-code'),
              style: theme.textTheme.displaySmall?.copyWith(
                fontFamily: 'monospace',
                letterSpacing: 2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Valid until ${AppFormat.dateTime(invite.expiresAt)}',
            key: const ValueKey('invite-expiry'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('invite-copy'),
                  onPressed: () => _copy(context),
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Copy'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: FilledButton.icon(
                  key: const ValueKey('invite-share'),
                  onPressed: () => share(
                    _shareText,
                    subject: 'AmpDent invite for ${member.displayName}',
                  ),
                  icon: const Icon(Icons.ios_share_outlined),
                  label: const Text('Share'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
