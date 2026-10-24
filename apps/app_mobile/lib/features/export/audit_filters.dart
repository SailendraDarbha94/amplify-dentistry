/// Audit-log filtering and CSV export; pure functions over [AuditEvent].
library;

import 'package:ampdent_core/ampdent_core.dart';
import 'package:flutter/foundation.dart';

import 'audit_diff.dart';

/// Sentinel for "clear this optional field" in [AuditFilter.copyWith].
const Object clearFilterField = Object();

/// What the audit viewer shows: a date range plus optional entity type,
/// actor and action.
@immutable
class AuditFilter {
  /// Creates a filter over `[from, to)`.
  const AuditFilter({
    required this.from,
    required this.to,
    this.entityType,
    this.actorId,
    this.action,
  });

  /// Default window: the last 30 days up to the end of today.
  factory AuditFilter.recent(DateTime now, {int days = 30}) {
    final l = now.toLocal();
    final endOfToday = DateTime(l.year, l.month, l.day + 1);
    return AuditFilter(
      from: endOfToday.subtract(Duration(days: days + 1)),
      to: endOfToday,
    );
  }

  /// Inclusive start.
  final DateTime from;

  /// Exclusive end.
  final DateTime to;

  /// Entity type name, or null for all.
  final String? entityType;

  /// Actor member id, or null for all.
  final String? actorId;

  /// Action, or null for all.
  final AuditAction? action;

  /// Whether any optional filter is set.
  bool get hasNarrowing =>
      entityType != null || actorId != null || action != null;

  /// Whether [event] passes the optional filters (the range is applied by
  /// the repository query).
  bool matches(AuditEvent event) =>
      (entityType == null || event.entityType == entityType) &&
      (actorId == null || event.actorId == actorId) &&
      (action == null || event.action == action) &&
      !event.occurredAt.isBefore(from) &&
      event.occurredAt.isBefore(to);

  /// Events passing [matches], in the given order.
  List<AuditEvent> apply(Iterable<AuditEvent> events) =>
      events.where(matches).toList();

  /// Returns a copy; pass [clearFilterField] to null an optional field.
  AuditFilter copyWith({
    DateTime? from,
    DateTime? to,
    Object? entityType = clearFilterField,
    Object? actorId = clearFilterField,
    Object? action = clearFilterField,
  }) => AuditFilter(
    from: from ?? this.from,
    to: to ?? this.to,
    entityType: identical(entityType, clearFilterField)
        ? this.entityType
        : entityType as String?,
    actorId: identical(actorId, clearFilterField)
        ? this.actorId
        : actorId as String?,
    action: identical(action, clearFilterField)
        ? this.action
        : action as AuditAction?,
  );
}

/// Distinct entity type names, sorted.
List<String> distinctEntityTypes(Iterable<AuditEvent> events) {
  final set = {for (final e in events) e.entityType};
  return set.toList()..sort();
}

/// Human label for an action.
String auditActionLabel(AuditAction action) => switch (action) {
  AuditAction.create => 'Created',
  AuditAction.update => 'Updated',
  AuditAction.statusChange => 'Status change',
  AuditAction.softDelete => 'Deleted',
  AuditAction.view => 'Viewed',
  AuditAction.export => 'Exported',
  AuditAction.print => 'Printed',
  AuditAction.share => 'Shared',
  AuditAction.login => 'Login',
  AuditAction.logout => 'Logout',
  AuditAction.settingsChange => 'Settings',
};

/// Quotes a CSV cell (RFC 4180): wraps in quotes when it contains a comma,
/// quote or line break, doubling embedded quotes.
String csvEscape(String value) {
  if (!value.contains(RegExp(r'[",\r\n]'))) return value;
  return '"${value.replaceAll('"', '""')}"';
}

/// CSV column headers of [auditCsv].
const List<String> auditCsvHeaders = [
  'occurredAt',
  'action',
  'entityType',
  'entityId',
  'actor',
  'actorId',
  'deviceId',
  'reason',
  'changedFields',
  'before',
  'after',
];

/// Renders events as CSV text with a header row. [actorNames] maps member
/// ids to display names (ids are kept in their own column).
String auditCsv(
  Iterable<AuditEvent> events, {
  Map<String, String> actorNames = const {},
}) {
  final b = StringBuffer()..writeln(auditCsvHeaders.join(','));
  for (final e in events) {
    final cells = <String>[
      e.occurredAt.toUtc().toIso8601String(),
      e.action.name,
      e.entityType,
      e.entityId,
      actorNames[e.actorId] ?? '',
      e.actorId,
      e.deviceId,
      e.reason ?? '',
      diffSnapshots(e.before, e.after).map((d) => d.key).join(';'),
      e.before == null ? '' : encodeSnapshot(e.before!),
      e.after == null ? '' : encodeSnapshot(e.after!),
    ];
    b.writeln(cells.map(csvEscape).join(','));
  }
  return b.toString();
}
