import 'package:ampdent_data/ampdent_data.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/clinic_link.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the sign-in page shows once signed in: the link check running, the
/// first pull running, a chooser when the user belongs to several clinics
/// or the device holds a different clinic, or the failure with a retry.
class LinkProgressView extends ConsumerWidget {
  /// Creates the view; [onDone] leaves the page.
  const LinkProgressView({super.key, required this.onDone});

  /// Called when the user wants to leave without a link (continue offline).
  final VoidCallback onDone;

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
      case LinkPhase.unlinked:
        return _Progress(
          key: const ValueKey('link-done'),
          text: context.strings.loading,
        );
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
              onPressed: onDone,
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
