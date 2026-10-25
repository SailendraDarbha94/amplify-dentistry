import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'today_kpis.dart';
import 'today_providers.dart';

/// Procedures completed today, behind the production tile.
final Provider<List<ProcedureRecord>> completedTodayProvider =
    Provider<List<ProcedureRecord>>((ref) {
      final procedures = ref.watch(clinicProceduresProvider).value;
      if (procedures == null) return const [];
      return completedOn(procedures, ref.watch(clockProvider)())
        ..sort((a, b) => b.completedAt!.compareTo(a.completedAt!));
    });

/// Accepted plan lines with no appointment, behind the unscheduled tile.
final Provider<List<TreatmentPlanLine>> unscheduledLinesProvider =
    Provider<List<TreatmentPlanLine>>((ref) {
      final plans = ref.watch(acceptedPlansProvider).value;
      final lines = ref.watch(acceptedPlanLinesProvider).value;
      final procedures = ref.watch(clinicProceduresProvider).value;
      final appointments = ref.watch(horizonAppointmentsProvider).value;
      if (plans == null ||
          lines == null ||
          procedures == null ||
          appointments == null) {
        return const [];
      }
      return unscheduledAcceptedLines(
        plans: plans,
        lines: lines,
        procedures: procedures,
        appointments: appointments,
      );
    });

/// Family key for [patientsByIdProvider]: a sorted, comma-joined id list,
/// so equal id sets map to the same provider across rebuilds (a `Set`
/// would not compare equal).
String patientIdsKey(Iterable<String> ids) =>
    (ids.toSet().toList()..sort()).join(',');

/// Patients named in a list of rows, keyed by id; takes a [patientIdsKey].
final patientsByIdProvider =
    StreamProvider.family<Map<String, Patient>, String>((ref, key) {
      if (key.isEmpty) return Stream.value(const {});
      return ref
          .watch(patientRepositoryProvider)
          .watchByIds(key.split(','))
          .map((list) => {for (final p in list) p.id: p});
    });

/// Opens [child] as a modal sheet over the whole app.
Future<void> showTodaySheet(BuildContext context, Widget child) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => FractionallySizedBox(heightFactor: 0.7, child: child),
    );

/// Today's completed procedures with patient and fee. Test key:
/// `completed-today-sheet`, rows `completed-<procedureId>`.
class CompletedTodaySheet extends ConsumerWidget {
  /// Creates the sheet.
  const CompletedTodaySheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings;
    final theme = Theme.of(context);
    final procedures = ref.watch(completedTodayProvider);
    final patients =
        ref
            .watch(
              patientsByIdProvider(
                patientIdsKey(procedures.map((p) => p.patientId)),
              ),
            )
            .value ??
        const {};
    final notation = ref.watch(notationProvider);
    return Column(
      key: const ValueKey('completed-today-sheet'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: AppSpacing.horizontalGutter,
          child: Text(
            "Today's production · "
            '${AppFormat.money(procedures.map((p) => p.netFee).total, showPaise: false)}',
            style: theme.textTheme.titleMedium,
          ),
        ),
        Expanded(
          child: procedures.isEmpty
              ? EmptyState(
                  icon: Icons.trending_up,
                  title: 'Nothing completed yet today',
                )
              : ListView(
                  children: [
                    for (final p in procedures)
                      ListTile(
                        key: ValueKey('completed-${p.id}'),
                        title: Text(p.name),
                        subtitle: Text(
                          [
                            patients[p.patientId]?.displayName ?? s.patient,
                            if (p.tooth != null)
                              notation.formatPlain(p.tooth!)
                            else if (p.teeth.isNotEmpty)
                              notation.formatAll(p.teeth, plain: true),
                            AppFormat.time(p.completedAt!),
                          ].join(' · '),
                        ),
                        trailing: MoneyText(
                          AppFormat.money(p.netFee, showPaise: false),
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          context.push('/patients/${p.patientId}');
                        },
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// Accepted-but-unscheduled plan lines with a one-tap "Book". Test key:
/// `unscheduled-sheet`, buttons `book-<lineId>`.
class UnscheduledPlanSheet extends ConsumerWidget {
  /// Creates the sheet.
  const UnscheduledPlanSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings;
    final theme = Theme.of(context);
    final lines = ref.watch(unscheduledLinesProvider);
    final patients =
        ref
            .watch(
              patientsByIdProvider(
                patientIdsKey(lines.map((l) => l.patientId)),
              ),
            )
            .value ??
        const {};
    return Column(
      key: const ValueKey('unscheduled-sheet'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: AppSpacing.horizontalGutter,
          child: Text(
            'Accepted, not scheduled · '
            '${AppFormat.money(lines.map((l) => l.net).total, showPaise: false)}',
            style: theme.textTheme.titleMedium,
          ),
        ),
        Expanded(
          child: lines.isEmpty
              ? EmptyState(
                  icon: Icons.pending_actions_outlined,
                  title: 'Every accepted plan has an appointment',
                )
              : ListView(
                  children: [
                    for (final l in lines)
                      ListTile(
                        key: ValueKey('unscheduled-${l.id}'),
                        title: Text(l.name),
                        subtitle: Text(
                          [
                            patients[l.patientId]?.displayName ?? s.patient,
                            AppFormat.money(l.net, showPaise: false),
                          ].join(' · '),
                        ),
                        trailing: FilledButton.tonal(
                          key: ValueKey('book-${l.id}'),
                          onPressed: () {
                            Navigator.of(context).pop();
                            context.push(
                              '/schedule/new?patientId=${l.patientId}',
                            );
                          },
                          child: const Text('Book'),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
