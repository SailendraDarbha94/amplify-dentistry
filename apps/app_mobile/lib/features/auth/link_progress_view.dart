import 'package:ampdent_data/ampdent_data.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/clinic_link.dart';
import 'package:ampdent_mobile/core/member_invites.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the sign-in page shows once signed in: the link check running, the
/// first pull running, a chooser when the user belongs to several clinics
/// or the device holds a different clinic, the failure with a retry, or the
/// explicit choice of a user with no clinic anywhere: create a new clinic
/// or join one with an invite code (never a silent duplicate clinic).
class LinkProgressView extends ConsumerWidget {
  /// Creates the view. [onCreateClinic] leaves for onboarding (also the
  /// "continue offline" way out of a failed check).
  const LinkProgressView({super.key, required this.onCreateClinic});

  /// Leaves the page to create a clinic on this phone.
  final VoidCallback onCreateClinic;

  Future<void> _replace(
    BuildContext context,
    WidgetRef ref,
    RemoteMembership m,
  ) async {
    final ok = await ConfirmSheet.show(
      context,
      title: 'Replace this phone\'s data with ${m.displayName}\'s clinic?',
      message:
          'Everything recorded on this phone so far has never reached the '
          'server and will be discarded. The server clinic is downloaded in '
          'its place. This cannot be undone.',
      confirmLabel: 'Discard local data and continue',
      destructive: true,
      icon: Icons.warning_amber_rounded,
    );
    if (!ok) return;
    await ref.read(clinicLinkProvider.notifier).replaceLocalWith(m);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final link = ref.watch(clinicLinkProvider);
    final user = ref.watch(cloudAuthProvider).user;
    final theme = Theme.of(context);
    final controller = ref.read(clinicLinkProvider.notifier);
    switch (link.phase) {
      case LinkPhase.idle:
      case LinkPhase.checking:
        return _Progress(
          key: const ValueKey('link-checking'),
          text: 'Checking your clinic on the server...',
        );
      case LinkPhase.pulling:
        return _Progress(
          key: const ValueKey('link-pulling'),
          text: link.pulledRows > 0
              ? 'Downloading clinic data (${link.pulledRows} rows so far)...'
              : 'Downloading clinic data...',
        );
      case LinkPhase.linked:
        return _Progress(
          key: const ValueKey('link-done'),
          text: context.strings.loading,
        );
      case LinkPhase.unlinked:
        return _UnlinkedChoice(user: user, onCreateClinic: onCreateClinic);
      case LinkPhase.failed:
        return ListView(
          padding: AppSpacing.screenPadding,
          children: [
            ErrorView(
              key: const ValueKey('link-failed'),
              message: 'Could not link this phone: ${link.error ?? 'error'}',
              onRetry: controller.run,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextButton(
              key: const ValueKey('link-continue-offline'),
              onPressed: onCreateClinic,
              child: Text(MobileStrings.continueOffline),
            ),
          ],
        );
      case LinkPhase.choosing:
        return ListView(
          padding: AppSpacing.screenPadding,
          children: [
            if (user != null)
              Text(
                'Signed in as ${user.label}',
                style: theme.textTheme.bodySmall,
              ),
            const SizedBox(height: AppSpacing.md),
            if (link.hasLocalClinic)
              SectionCard(
                key: const ValueKey('link-conflict'),
                title: 'This phone already holds a clinic',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Your account belongs to a different clinic on the '
                      'server than the one set up on this phone. Keep the '
                      'local clinic and sign out, or discard what is on this '
                      'phone and use a clinic from your account.',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton.tonalIcon(
                      key: const ValueKey('link-keep-local'),
                      onPressed: controller.keepLocalAndSignOut,
                      icon: const Icon(Icons.phone_android),
                      label: const Text(
                        'Keep this phone\'s clinic and sign out',
                      ),
                    ),
                  ],
                ),
              )
            else
              Text(
                'Your account belongs to more than one clinic. Which one '
                'should this phone work with?',
                style: theme.textTheme.bodyMedium,
              ),
            const SizedBox(height: AppSpacing.md),
            for (final m in link.memberships)
              Card(
                child: ListTile(
                  key: ValueKey('link-clinic-${m.clinicId}'),
                  leading: const Icon(Icons.local_hospital_outlined),
                  title: Text(
                    m.displayName.isEmpty ? m.clinicId : m.displayName,
                  ),
                  subtitle: Text('Role: ${m.role}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: link.hasLocalClinic
                      ? () => _replace(context, ref, m)
                      : () => controller.adopt(m),
                ),
              ),
          ],
        );
    }
  }
}

/// Signed in, nothing on the server and nothing on this phone: the user
/// decides. Joining with a code is offered first because a second clinic
/// made by mistake is the costlier error.
class _UnlinkedChoice extends StatelessWidget {
  const _UnlinkedChoice({required this.user, required this.onCreateClinic});

  final AuthUser? user;
  final VoidCallback onCreateClinic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      key: const ValueKey('link-unlinked'),
      padding: AppSpacing.screenPadding,
      children: [
        if (user != null)
          Text('Signed in as ${user!.label}', style: theme.textTheme.bodySmall),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'No clinic is linked to this account yet.',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        const _InviteCodeCard(),
        const SizedBox(height: AppSpacing.lg),
        SectionCard(
          title: 'Start a new clinic',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Only for the clinic owner setting up the first phone. If '
                'your clinic already uses AmpDent, ask its owner for an '
                'invite code instead; a second clinic cannot be merged '
                'later.',
              ),
              const SizedBox(height: AppSpacing.md),
              BigActionButton(
                key: const ValueKey('link-create-clinic'),
                label: 'Create a new clinic',
                icon: Icons.add_business_outlined,
                onPressed: onCreateClinic,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InviteCodeCard extends ConsumerStatefulWidget {
  const _InviteCodeCard();

  @override
  ConsumerState<_InviteCodeCard> createState() => _InviteCodeCardState();
}

class _InviteCodeCardState extends ConsumerState<_InviteCodeCard> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final TextEditingController _code = TextEditingController(
    text: InviteCodes.display(ref.read(inviteClaimProvider).pendingCode ?? ''),
  );

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _claim() async {
    if (!_form.currentState!.validate()) return;
    ref.read(inviteClaimProvider.notifier).setPendingCode(_code.text);
    // The link check claims the pending code first, then adopts.
    await ref.read(clinicLinkProvider.notifier).run();
  }

  @override
  Widget build(BuildContext context) {
    final invite = ref.watch(inviteClaimProvider);
    final theme = Theme.of(context);
    return SectionCard(
      title: 'Join your clinic with an invite code',
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'The clinic owner creates the code from Settings > Members > '
              'Invite to sign in. It is valid for 72 hours.',
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              key: const ValueKey('link-invite-code'),
              controller: _code,
              decoration: const InputDecoration(
                labelText: 'Invite code',
                hintText: 'ABCD-EFGH',
              ),
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              validator: InviteCodes.validate,
              onFieldSubmitted: (_) => _claim(),
            ),
            if (invite.error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                invite.error!,
                key: const ValueKey('link-invite-error'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            BigActionButton(
              key: const ValueKey('link-claim-invite'),
              label: 'Use invite code',
              icon: Icons.vpn_key_outlined,
              loading: invite.busy,
              onPressed: invite.busy ? null : _claim,
            ),
          ],
        ),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.screenPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.lg),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
