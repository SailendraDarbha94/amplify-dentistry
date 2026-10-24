import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_mobile/features/onboarding/onboarding_controller.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'member_form_sheet.dart';

/// Clinic members: add associates and visiting specialists, edit, deactivate,
/// and switch which member this device acts as.
class MembersPage extends ConsumerWidget {
  /// Creates the page.
  const MembersPage({super.key});

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
                              _ => _deactivate(context, ref, m),
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'switch',
                                child: Text('Act as this member'),
                              ),
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
