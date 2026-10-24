import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'incomplete_treatment_list.dart';
import 'recall_model.dart';
import 'recall_providers.dart';
import 'recall_row.dart';

/// Recall tab: open recalls grouped Overdue / Due today / Upcoming with the
/// rupee value of each group, a type filter, and an Incomplete tab for
/// stalled treatment.
class RecallPage extends ConsumerWidget {
  /// Creates the page.
  const RecallPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(s.recall),
          bottom: const TabBar(
            tabs: [
              Tab(key: ValueKey('recall-tab-due'), text: 'Due'),
              Tab(key: ValueKey('recall-tab-incomplete'), text: 'Incomplete'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_DueTab(), IncompleteTreatmentList()],
        ),
      ),
    );
  }
}

class _DueTab extends ConsumerWidget {
  const _DueTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings;
    final filter = ref.watch(recallTypeFilterProvider);
    final grouped = ref.watch(groupedRecallsProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.sm,
            AppSpacing.gutter,
            0,
          ),
          child: ToggleChipGroup<RecallType>(
            options: [
              for (final t in RecallType.values)
                ToggleChipOption(value: t, label: recallTypeLabel(t)),
            ],
            selected: filter,
            onChanged: ref.read(recallTypeFilterProvider.notifier).set,
          ),
        ),
        Expanded(
          child: grouped.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorView(
              message: e.toString(),
              onRetry: () => ref.invalidate(recallWindowProvider),
            ),
            data: (groups) {
              final total = groups.values.fold<int>(0, (n, l) => n + l.length);
              if (total == 0) {
                return EmptyState(
                  icon: Icons.notifications_none,
                  title: s.nothingHere,
                  message:
                      'Recalls appear here when a procedure with a recall '
                      'rule is completed.',
                );
              }
              return ListView(
                padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                children: [
                  for (final g in RecallGroup.values)
                    if (groups[g]!.isNotEmpty) ...[
                      RecallGroupHeader(group: g, recalls: groups[g]!),
                      for (final r in groups[g]!)
                        RecallRow(recall: r, group: g),
                    ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Header of one recall group: label, count and summed estimated value.
class RecallGroupHeader extends StatelessWidget {
  /// Creates the header.
  const RecallGroupHeader({
    super.key,
    required this.group,
    required this.recalls,
  });

  /// The group.
  final RecallGroup group;

  /// Rows in the group.
  final List<Recall> recalls;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      key: ValueKey('recall-group-${group.name}'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.lg,
        AppSpacing.gutter,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          StatusBadge(label: group.label, tone: group.tone),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '${recalls.length}',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          MoneyText(
            AppFormat.money(recallGroupValue(recalls), showPaise: false),
            emphasis: MoneyEmphasis.strong,
          ),
        ],
      ),
    );
  }
}
