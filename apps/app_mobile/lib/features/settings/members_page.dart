import 'dart:async';

import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/clinic_link.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_mobile/core/member_invites.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_mobile/features/onboarding/onboarding_controller.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import 'member_form_sheet.dart';
import 'member_invite_sheet.dart';

/// Clinic members: add associates and visiting specialists, edit, deactivate,
/// invite a member to sign in on their own phone, and switch which member
/// this device acts as.
class MembersPage extends ConsumerWidget {
  /// Creates the page.
  const MembersPage({super.key});

  static const Logger _log = Logger('members');

  /// Mints an invite code for [member] and shows it. Needs the cloud, a
  /// signed-in owner and a linked phone; otherwise says what is missing.
  Future<void> _invite(
    BuildContext context,
    WidgetRef ref,
    ClinicMember member,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final fallback = context.strings.somethingWentWrong;
    final service = ref.read(memberInviteServiceProvider);
    final clinicId = ref.read(actorContextProvider).clinicId;
    final linked = ref.read(clinicLinkProvider).isLinkedTo(clinicId);
    if (service == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text(MobileStrings.cloudNotConfigured)),
      );
      return;
    }
    if (!ref.read(cloudAuthProvider).isSignedIn || !linked) {
      messenger.showSnackBar(
        const SnackBar(
          key: ValueKey('invite-needs-link'),
          content: Text(
            'Sign in and link this phone first (Settings > Account & sync)',
          ),
        ),
      );
      return;
    }
    final MemberInvite invite;
    try {
      invite = await service.create(clinicId: clinicId, memberId: member.id);
    } on PostgrestException catch (e) {
      _log.info('invite refused (${e.code ?? '-'})');
      messenger.showSnackBar(
        SnackBar(
          key: const ValueKey('invite-refused'),
          content: Text(e.message),
        ),
      );
      return;
    } on Object catch (e, st) {
      _log.error('invite failed: ${e.runtimeType}', stackTrace: st);
      messenger.showSnackBar(SnackBar(content: Text(fallback)));
      return;
    }
    if (!context.mounted) return;
    await MemberInviteSheet.show(
      context,
      invite: invite,
      member: member,
      clinicName: ref.read(currentClinicProvider).value?.name ?? 'the clinic',
    );
  }

  /// Clears the account bound to [member] on the server (`unlink_member`,
  /// owner only) so a lost phone or number can be re-invited, then syncs so
  /// the row comes back without its binding. Same preconditions as
  /// [_invite]; the server's refusal (no account, own row, not the owner)
  /// is shown as is.
  Future<void> _unlink(
    BuildContext context,
    WidgetRef ref,
    ClinicMember member,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final fallback = context.strings.somethingWentWrong;
    final service = ref.read(memberInviteServiceProvider);
    final clinicId = ref.read(actorContextProvider).clinicId;
    final linked = ref.read(clinicLinkProvider).isLinkedTo(clinicId);
    if (service == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text(MobileStrings.cloudNotConfigured)),
      );
      return;
    }
    if (!ref.read(cloudAuthProvider).isSignedIn || !linked) {
      messenger.showSnackBar(
        const SnackBar(
          key: ValueKey('unlink-needs-link'),
          content: Text(
            'Sign in and link this phone first (Settings > Account & sync)',
          ),
        ),
      );
      return;
    }
    // Short on purpose: a bottom sheet gets 9/16 of a 360 x 800 screen.
    final ok = await ConfirmSheet.show(
      context,
      title: 'Unlink ${member.displayName}?',
      message:
          'Their phone stops seeing this clinic; nothing they recorded is '
          'removed. Invite them again for a new account.',
      confirmLabel: 'Unlink account',
      destructive: true,
    );
    if (!ok) return;
    try {
      await service.unlink(memberId: member.id);
    } on PostgrestException catch (e) {
      _log.info('unlink refused (${e.code ?? '-'})');
      messenger.showSnackBar(
        SnackBar(
          key: const ValueKey('unlink-refused'),
          content: Text(e.message),
        ),
      );
      return;
    } on Object catch (e, st) {
      _log.error('unlink failed: ${e.runtimeType}', stackTrace: st);
      messenger.showSnackBar(SnackBar(content: Text(fallback)));
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        key: const ValueKey('unlink-done'),
        content: Text(
          '${member.displayName} unlinked; use "Invite to sign in" for a '
          'new code',
        ),
      ),
    );
    unawaited(ref.read(syncNowProvider)());
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final ctx = ref.read(actorContextProvider);
    final clinic = ref.read(currentClinicProvider).value;
    final member = await MemberFormSheet.show(
      context,
      clinicId: ctx.clinicId,
      defaultCouncil: OnboardingService.defaultCouncilName(clinic?.stateCode),
    );
    if (member != null) {
      await ref.read(clinicRepositoryProvider).upsertMember(ctx, member);
    }
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    ClinicMember existing,
  ) async {
    final ctx = ref.read(actorContextProvider);
    final member = await MemberFormSheet.show(
      context,
      clinicId: ctx.clinicId,
      existing: existing,
    );
    if (member != null) {
      await ref.read(clinicRepositoryProvider).upsertMember(ctx, member);
    }
  }

  Future<void> _switchTo(
    BuildContext context,
    WidgetRef ref,
    ClinicMember member,
  ) async {
    final ok = await ConfirmSheet.show(
      context,
      title: 'Act as ${member.displayName}?',
      message:
          'New records and audit events will be signed by this member '
          'until you switch again.',
      confirmLabel: 'Switch',
      icon: Icons.swap_horiz,
    );
    if (!ok) return;
    await ref
        .read(appSessionProvider.notifier)
        .switchMember(
          clinics: ref.read(clinicRepositoryProvider),
          memberId: member.id,
        );
  }

  Future<void> _deactivate(
    BuildContext context,
    WidgetRef ref,
    ClinicMember member,
  ) async {
    final ok = await ConfirmSheet.show(
      context,
      title: 'Deactivate ${member.displayName}?',
      message: 'They stay on historical records but cannot be selected.',
      confirmLabel: 'Deactivate',
      destructive: true,
    );
    if (!ok) return;
    await ref
        .read(clinicRepositoryProvider)
        .deactivateMember(
          ref.read(actorContextProvider),
          member.id,
          reason: 'Deactivated from settings',
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings;
    final members = ref.watch(clinicMembersProvider);
    final activeId = ref.watch(appSessionProvider).memberId;
    final cloud = ref.watch(cloudActiveProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Members')),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('members-add'),
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.person_add_alt_1),
        label: Text(s.add),
      ),
      body: members.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(message: e.toString()),
        data: (list) => list.isEmpty
            ? EmptyState(
                icon: Icons.badge_outlined,
                title: s.nothingHere,
                message: 'Add the dentists and staff who use this app.',
              )
            : ListView.separated(
                padding: const EdgeInsets.only(bottom: 96),
                itemCount: list.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final m = list[i];
                  final active = m.id == activeId;
                  return ListTile(
                    key: ValueKey('member-row-${m.id}'),
                    leading: CircleAvatar(
                      backgroundColor: active
                          ? Theme.of(context).colorScheme.primary
                          : null,
                      foregroundColor: active
                          ? Theme.of(context).colorScheme.onPrimary
                          : null,
                      child: Text(
                        m.displayName.isEmpty ? '?' : m.displayName[0],
                      ),
                    ),
                    title: Text(m.displayName),
                    subtitle: Text(
                      [
                        clinicRoleLabel(m.role),
                        if (m.registrationNumber != null)
                          'Reg. ${m.registrationNumber}',
                        if (m.feeSharePercent != null)
                          '${AppFormat.percent(m.feeSharePercent!)} share',
                        AppFormat.phone(m.phone),
                      ].join('  ·  '),
                    ),
                    isThreeLine: true,
                    trailing: active
                        ? const StatusBadge(
                            label: 'Active',
                            tone: BadgeTone.success,
                            dense: true,
                          )
                        : PopupMenuButton<String>(
                            key: ValueKey('member-menu-${m.id}'),
                            onSelected: (v) => switch (v) {
                              'switch' => _switchTo(context, ref, m),
                              'edit' => _edit(context, ref, m),
                              'invite' => _invite(context, ref, m),
                              'unlink' => _unlink(context, ref, m),
                              _ => _deactivate(context, ref, m),
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'switch',
                                child: Text('Act as this member'),
                              ),
                              if (cloud) ...[
                                PopupMenuItem(
                                  key: ValueKey('member-invite-${m.id}'),
                                  value: 'invite',
                                  child: const Text('Invite to sign in'),
                                ),
                                PopupMenuItem(
                                  key: ValueKey('member-unlink-${m.id}'),
                                  value: 'unlink',
                                  child: const Text('Unlink account'),
                                ),
                              ],
                              PopupMenuItem(value: 'edit', child: Text(s.edit)),
                              if (m.role != ClinicRole.ownerDentist)
                                const PopupMenuItem(
                                  value: 'deactivate',
                                  child: Text('Deactivate'),
                                ),
                            ],
                          ),
                    onTap: () => _edit(context, ref, m),
                  );
                },
              ),
      ),
    );
  }
}
