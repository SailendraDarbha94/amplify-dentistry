import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'chart_mapping.dart';
import 'chart_providers.dart';

/// One line of a tooth's history (state change, finding or procedure).
class ToothHistoryEntry {
  /// Creates an entry.
  const ToothHistoryEntry({
    required this.at,
    required this.title,
    required this.subtitle,
    required this.badge,
    this.tone = BadgeTone.neutral,
  });

  /// When it happened.
  final DateTime at;

  /// Main text.
  final String title;

  /// Secondary text.
  final String subtitle;

  /// Badge text.
  final String badge;

  /// Badge tone.
  final BadgeTone tone;
}

/// Merges every record touching [tooth] into one list, newest first.
List<ToothHistoryEntry> buildToothHistory({
  required ToothId tooth,
  required ToothNotation notation,
  Iterable<ToothStateRecord> states = const [],
  Iterable<Finding> findings = const [],
  Iterable<ProcedureRecord> procedures = const [],
}) {
  final out = <ToothHistoryEntry>[];
  for (final r in states.where((r) => r.tooth == tooth)) {
    out.add(
      ToothHistoryEntry(
        at: r.effectiveFrom,
        title: AppFormat.enumLabel(r.state),
        subtitle: [
          AppFormat.enumLabel(r.source),
          if (r.note != null) r.note!,
        ].join(' · '),
        badge: 'State',
        tone: BadgeTone.neutral,
      ),
    );
  }
  for (final f in findings.where((f) => f.tooth == tooth)) {
    out.add(
      ToothHistoryEntry(
        at: f.recordedAt,
        title: f.description,
        subtitle: [
          if (f.surfaces.isNotEmpty) f.surfaces.labelFor(tooth),
          if (f.icd10Code != null) f.icd10Code!,
          AppFormat.enumLabel(f.status),
        ].join(' · '),
        badge: 'Finding',
        tone: f.status == FindingStatus.active
            ? BadgeTone.caries
            : BadgeTone.neutral,
      ),
    );
  }
  for (final p in procedures.where((p) => procedureTeeth(p).contains(tooth))) {
    out.add(
      ToothHistoryEntry(
        at: p.completedAt ?? p.startedAt ?? p.plannedAt ?? p.createdAt,
        title: p.name,
        subtitle: [
          if (p.surfaces.isNotEmpty) p.surfaces.labelFor(tooth),
          AppFormat.enumLabel(p.status),
          if (p.isMultiSitting) 'Stage ${p.stageIndex + 1}/${p.totalStages}',
          AppFormat.money(p.netFee, showPaise: false),
        ].join(' · '),
        badge: 'Procedure',
        tone: p.status.isDone
            ? BadgeTone.completed
            : (p.status.isPlanned ? BadgeTone.planned : BadgeTone.info),
      ),
    );
  }
  out.sort((a, b) => b.at.compareTo(a.at));
  return out;
}

/// Every record for one tooth, newest first.
class ToothHistoryTab extends ConsumerWidget {
  /// Creates the tab.
  const ToothHistoryTab({
    super.key,
    required this.patientId,
    required this.tooth,
  });

  /// Patient.
  final String patientId;

  /// Tooth.
  final ToothId tooth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings;
    final notation = ref.watch(notationProvider);
    final entries = buildToothHistory(
      tooth: tooth,
      notation: notation,
      states: ref.watch(toothHistoryProvider(patientId)).value ?? const [],
      findings: ref.watch(chartFindingsProvider(patientId)).value ?? const [],
      procedures:
          ref.watch(chartProceduresProvider(patientId)).value ?? const [],
    );
    if (entries.isEmpty) {
      return EmptyState(icon: Icons.history, title: s.nothingHere);
    }
    return ListView.separated(
      padding: AppSpacing.screenPadding,
      itemCount: entries.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final e = entries[i];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(e.title),
          subtitle: Text('${AppFormat.dateTime(e.at)}\n${e.subtitle}'),
          isThreeLine: true,
          trailing: StatusBadge(label: e.badge, tone: e.tone, dense: true),
        );
      },
    );
  }
}
