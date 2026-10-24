import 'dart:convert';
import 'dart:typed_data';

import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'audit_event_sheet.dart';
import 'audit_filters.dart';

/// Audit events of the clinic in `[from, to)`, newest first (capped).
final auditEventsProvider =
    FutureProvider.family<List<AuditEvent>, (DateTime, DateTime)>((ref, range) {
      final clinicId = ref.watch(currentClinicIdProvider);
      if (clinicId == null) return Future.value(const []);
      final (from, to) = range;
      return ref
          .watch(auditRepositoryProvider)
          .inRange(clinicId, from.toUtc(), to.toUtc(), limit: 2000);
    });

/// Audit log viewer: filter by entity type, actor and date range; tap a row
/// for the before/after diff; share the filtered list as CSV.
class AuditPage extends ConsumerStatefulWidget {
  /// Creates the page.
  const AuditPage({super.key});

  @override
  ConsumerState<AuditPage> createState() => _AuditPageState();
}

class _AuditPageState extends ConsumerState<AuditPage> {
  late AuditFilter _filter = AuditFilter.recent(ref.read(clockProvider)());

  Map<String, String> _actorNames() {
    final members = ref.read(clinicMembersProvider).value ?? const [];
    return {for (final m in members) m.id: m.displayName};
  }

  Future<void> _pickRange() async {
    final now = ref.read(clockProvider)();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 1),
      initialDateRange: DateTimeRange(
        start: _filter.from,
        end: _filter.to.subtract(const Duration(days: 1)),
      ),
    );
    if (picked == null) return;
    setState(() {
      _filter = _filter.copyWith(
        from: DateTime(picked.start.year, picked.start.month, picked.start.day),
        to: DateTime(picked.end.year, picked.end.month, picked.end.day + 1),
      );
    });
  }

  Future<void> _shareCsv(List<AuditEvent> events) async {
    final csv = auditCsv(events, actorNames: _actorNames());
    final name =
        'audit-${_filter.from.toIso8601String().substring(0, 10)}'
        '-${_filter.to.subtract(const Duration(days: 1)).toIso8601String().substring(0, 10)}.csv';
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            Uint8List.fromList(utf8.encode(csv)),
            mimeType: 'text/csv',
            name: name,
          ),
        ],
        fileNameOverrides: [name],
        subject: 'Audit log export',
        text: '${events.length} audit events',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final theme = Theme.of(context);
    final loaded = ref.watch(auditEventsProvider((_filter.from, _filter.to)));
    final all = loaded.value ?? const <AuditEvent>[];
    final events = _filter.apply(all);
    final members = ref.watch(clinicMembersProvider).value ?? const [];
    final names = {for (final m in members) m.id: m.displayName};
    final entityTypes = distinctEntityTypes(all);
    final actorIds = {for (final e in all) e.actorId}.toList()..sort();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit log'),
        actions: [
          IconButton(
            key: const ValueKey('audit-export-csv'),
            tooltip: 'Share CSV',
            icon: const Icon(Icons.ios_share_outlined),
            onPressed: events.isEmpty ? null : () => _shareCsv(events),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.sm,
              AppSpacing.gutter,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        key: const ValueKey('audit-filter-entity'),
                        initialValue: _filter.entityType,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Entity'),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('All'),
                          ),
                          for (final t in entityTypes)
                            DropdownMenuItem<String?>(value: t, child: Text(t)),
                        ],
                        onChanged: (v) => setState(
                          () => _filter = _filter.copyWith(entityType: v),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        key: const ValueKey('audit-filter-actor'),
                        initialValue: _filter.actorId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Actor'),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('All'),
                          ),
                          for (final id in actorIds)
                            DropdownMenuItem<String?>(
                              value: id,
                              child: Text(
                                names[id] ?? id,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (v) => setState(
                          () => _filter = _filter.copyWith(actorId: v),
                        ),
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  key: const ValueKey('audit-filter-range'),
                  onPressed: _pickRange,
                  icon: const Icon(Icons.date_range_outlined),
                  label: Text(
                    '${AppFormat.date(_filter.from)} - '
                    '${AppFormat.date(_filter.to.subtract(const Duration(days: 1)))}'
                    '  ·  ${events.length}',
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: loaded.isLoading && all.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : events.isEmpty
                ? EmptyState(
                    icon: Icons.history_outlined,
                    title: s.nothingHere,
                    message: 'No audit events match these filters.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                    itemCount: events.length,
                    itemBuilder: (context, i) {
                      final e = events[i];
                      return ListTile(
                        key: ValueKey('audit-row-${e.id}'),
                        title: Row(
                          children: [
                            StatusBadge(
                              label: auditActionLabel(e.action),
                              tone: auditTone(e.action),
                              dense: true,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                '${e.entityType}  ·  ${_short(e.entityId)}',
                                style: theme.textTheme.titleSmall,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          '${names[e.actorId] ?? e.actorId}  ·  '
                          '${AppFormat.dateTime(e.occurredAt)}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => AuditEventSheet.show(
                          context,
                          event: e,
                          actorName: names[e.actorId],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  static String _short(String id) => id.length <= 8 ? id : id.substring(0, 8);
}
