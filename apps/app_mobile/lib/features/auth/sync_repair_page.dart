import 'dart:async';

import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_data/ampdent_data.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_mobile/core/sync_repair.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Settings > Account & sync > Changes needing attention: every change the
/// server rejected (quarantined) and the ones waiting behind it (blocked),
/// each with Retry and "Discard my change" (confirmed). Labels are entity
/// names and short labels, never clinical content.
class SyncRepairPage extends ConsumerWidget {
  /// Creates the page.
  const SyncRepairPage({super.key});

  static const Logger _log = Logger('sync-repair');

  Future<void> _retry(BuildContext context, WidgetRef ref, SyncProblem p) =>
      _act(context, ref, 'retry', () async {
        final n = await ref.read(syncRepairServiceProvider)!.retry(p.id);
        return n == 1 ? 'Re-queued 1 change' : 'Re-queued $n changes';
      });

  Future<void> _discard(
    BuildContext context,
    WidgetRef ref,
    SyncProblem p,
  ) async {
    // Short on purpose: a bottom sheet gets 9/16 of a 360 x 800 screen.
    final ok = await ConfirmSheet.show(
      context,
      title: 'Discard this change?',
      message:
          '${p.entityType} ${p.entityLabel}: never uploaded; the server\'s '
          'copy replaces it where one exists.',
      confirmLabel: 'Discard my change',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    await _act(context, ref, 'discard', () async {
      final outcome = await ref
          .read(syncRepairServiceProvider)!
          .discardLocalChange(p.id, ref.read(actorContextProvider));
      return 'Discarded ${outcome.entriesDiscarded} '
          '${outcome.entriesDiscarded == 1 ? 'change' : 'changes'}: '
          '${outcome.rowsRestored} restored from the server, '
          '${outcome.rowsRejected} kept on this phone as rejected';
    });
  }

  /// Runs [action], reports its summary (or why it failed) in a SnackBar and
  /// syncs afterwards so a re-queued row goes out right away.
  Future<void> _act(
    BuildContext context,
    WidgetRef ref,
    String step,
    Future<String> Function() action,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final fallback = context.strings.somethingWentWrong;
    if (ref.read(syncRepairServiceProvider) == null) return;
    String text;
    try {
      text = await action();
    } on SyncFailure catch (e) {
      _log.warning('$step failed: ${e.message}');
      text = e.isTransient
          ? 'Could not reach the server; try again when online'
          : e.message;
    } on Object catch (e, st) {
      _log.error('$step failed: ${e.runtimeType}', stackTrace: st);
      text = fallback;
    }
    messenger.showSnackBar(
      SnackBar(key: ValueKey('repair-$step-result'), content: Text(text)),
    );
    ref.invalidate(syncProblemsProvider);
    unawaited(ref.read(syncNowProvider)());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings;
    final theme = Theme.of(context);
    final service = ref.watch(syncRepairServiceProvider);
    final count = ref.watch(syncProblemCountProvider).value ?? 0;
    final problems = ref.watch(syncProblemsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Changes needing attention')),
      body: service == null
          ? ListView(
              padding: AppSpacing.screenPadding,
              children: [
                SectionCard(
                  key: const ValueKey('repair-unavailable'),
                  title: count == 0
                      ? 'Nothing needs attention'
                      : MobileStrings.changesNeedAttention(count),
                  child: Text(
                    count == 0
                        ? 'Every change on this phone was accepted.'
                        : 'Sign in and link this phone (Settings > Account & '
                              'sync) to review, retry or discard them.',
                  ),
                ),
              ],
            )
          : problems.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorView(
                message: e is SyncFailure ? e.message : e.toString(),
                onRetry: () => ref.invalidate(syncProblemsProvider),
              ),
              data: (list) => list.isEmpty
                  ? EmptyState(
                      key: const ValueKey('repair-empty'),
                      icon: Icons.cloud_done_outlined,
                      title: s.nothingHere,
                      message: 'Every change on this phone was accepted.',
                    )
                  : ListView(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                      children: [
                        Padding(
                          padding: AppSpacing.screenPadding,
                          child: Text(
                            'The server refused these changes (a rule or a '
                            'permission on its side) and this phone holds '
                            'back the rows that depend on them. Fix the '
                            'record and retry, or discard the change made '
                            'here.',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        for (final p in list)
                          _ProblemCard(
                            problem: p,
                            onRetry: () => _retry(context, ref, p),
                            onDiscard: () => _discard(context, ref, p),
                          ),
                      ],
                    ),
            ),
    );
  }
}

class _ProblemCard extends StatelessWidget {
  const _ProblemCard({
    required this.problem,
    required this.onRetry,
    required this.onDiscard,
  });

  final SyncProblem problem;
  final VoidCallback onRetry;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final p = problem;
    final theme = Theme.of(context);
    final detail = p.isQuarantined
        ? (p.error ?? 'Rejected by the server')
        : 'Waiting behind a rejected change it depends on';
    return Card(
      key: ValueKey('repair-row-${p.id}'),
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.gutter,
        vertical: AppSpacing.xs,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${p.entityType}: ${p.entityLabel}',
                    style: theme.textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                StatusBadge(
                  label: p.isQuarantined
                      ? (p.statusCode == null
                            ? 'Rejected'
                            : 'Rejected ${p.statusCode}')
                      : 'Blocked',
                  tone: p.isQuarantined ? BadgeTone.danger : BadgeTone.warning,
                  dense: true,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(detail, style: theme.textTheme.bodySmall),
            Text(
              'Changed ${AppFormat.dateTime(p.changedAt)}'
              '${p.attempts > 0 ? '  ·  ${p.attempts} attempts' : ''}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    key: ValueKey('repair-retry-${p.id}'),
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    key: ValueKey('repair-discard-${p.id}'),
                    onPressed: onDiscard,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Discard my change'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
