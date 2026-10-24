import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_mobile/features/patients/patient_providers.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'lab_directory.dart';
import 'lab_model.dart';
import 'lab_providers.dart';

/// Lab tab: open cases grouped by status with overdue highlighting, and the
/// labs directory.
class LabCasesPage extends ConsumerWidget {
  /// Creates the page.
  const LabCasesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(s.lab),
          bottom: const TabBar(
            tabs: [
              Tab(key: ValueKey('lab-tab-cases'), text: 'Cases'),
              Tab(key: ValueKey('lab-tab-labs'), text: 'Labs'),
            ],
          ),
        ),
        body: const TabBarView(children: [_CasesTab(), LabDirectoryList()]),
      ),
    );
  }
}

class _CasesTab extends ConsumerWidget {
  const _CasesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings;
    final now = ref.watch(clockProvider)();
    final cases = ref.watch(openLabCasesProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('lab-new-case'),
        onPressed: () => context.push('/lab/new'),
        icon: const Icon(Icons.add),
        label: Text('New ${s.labCase.toLowerCase()}'),
      ),
      body: cases.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(openLabCasesProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.science_outlined,
              title: s.nothingHere,
              message:
                  'No lab work is out. Start a case from a crown, bridge '
                  'or denture procedure.',
            );
          }
          final groups = groupCasesByStatus(list, now);
          final overdue = list.where((c) => c.isOverdue(now)).length;
          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              if (overdue > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.gutter,
                    AppSpacing.md,
                    AppSpacing.gutter,
                    0,
                  ),
                  child: StatusBadge(
                    key: const ValueKey('lab-overdue-count'),
                    label: '$overdue ${s.overdue.toLowerCase()}',
                    tone: BadgeTone.danger,
                    icon: Icons.warning_amber_outlined,
                  ),
                ),
              for (final status in labCaseStatusOrder)
                if (groups[status]!.isNotEmpty) ...[
                  Padding(
                    key: ValueKey('lab-group-${status.name}'),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.gutter,
                      AppSpacing.lg,
                      AppSpacing.gutter,
                      AppSpacing.xs,
                    ),
                    child: Row(
                      children: [
                        StatusBadge(
                          label: labCaseStatusLabel(status),
                          tone: labCaseStatusTone(status),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          '${groups[status]!.length}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                  for (final c in groups[status]!)
                    LabCaseTile(labCase: c, now: now),
                ],
            ],
          );
        },
      ),
    );
  }
}

/// One lab case in the list: patient, work summary, lab and due date.
class LabCaseTile extends ConsumerWidget {
  /// Creates the tile.
  const LabCaseTile({super.key, required this.labCase, required this.now});

  /// The case.
  final LabCase labCase;

  /// Reference time for overdue highlighting.
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings;
    final theme = Theme.of(context);
    final notation = ref.watch(notationProvider);
    final patient = ref.watch(patientProvider(labCase.patientId)).value;
    final lab = ref.watch(labProvider(labCase.labId)).value;
    final overdue = labCase.isOverdue(now);
    final danger = AppColors.of(context).danger;
    final due = labCase.dueAt;
    return ListTile(
      key: ValueKey('lab-case-row-${labCase.id}'),
      leading: Icon(
        overdue ? Icons.warning_amber_rounded : Icons.science_outlined,
        color: overdue ? danger : null,
      ),
      title: Text(patient?.displayName ?? s.loading),
      subtitle: Text(
        [
          labCaseSummary(labCase, notation),
          if (lab != null) lab.name,
          if (due != null)
            overdue
                ? '${s.overdue}: ${s.due.toLowerCase()} ${AppFormat.shortDate(due)}'
                : '${s.due} ${AppFormat.shortDate(due)}',
        ].join('\n'),
        style: overdue
            ? theme.textTheme.bodyMedium?.copyWith(color: danger)
            : null,
      ),
      isThreeLine: true,
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/lab/${labCase.id}'),
    );
  }
}
