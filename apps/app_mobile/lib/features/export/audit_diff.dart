/// Before/after comparison of audit snapshots.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';

/// One changed field.
@immutable
class DiffEntry {
  /// Creates an entry.
  const DiffEntry({required this.key, this.before, this.after});

  /// Field name.
  final String key;

  /// Previous value (null when added).
  final Object? before;

  /// New value (null when removed).
  final Object? after;

  /// Whether the field did not exist before.
  bool get isAdded => before == null && after != null;

  /// Whether the field was cleared.
  bool get isRemoved => before != null && after == null;
}

/// Compact canonical JSON of a snapshot (keys sorted).
String encodeSnapshot(Map<String, Object?> snapshot) =>
    jsonEncode(_canonical(snapshot));

Object? _canonical(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((k) => k.toString()).toList()..sort();
    return {for (final k in keys) k: _canonical(value[k])};
  }
  if (value is List) return value.map(_canonical).toList();
  return value;
}

/// Fields whose values differ between [before] and [after], sorted by key.
/// A null [before] (create) lists every non-null field of [after]; a null
/// [after] (delete) lists every non-null field of [before]. `updatedAt` is
/// skipped because it changes on every write.
List<DiffEntry> diffSnapshots(
  Map<String, Object?>? before,
  Map<String, Object?>? after,
) {
  if (before == null && after == null) return const [];
  final keys = <String>{...?before?.keys, ...?after?.keys}..remove('updatedAt');
  final sorted = keys.toList()..sort();
  final result = <DiffEntry>[];
  for (final k in sorted) {
    final b = before?[k];
    final a = after?[k];
    if (jsonEncode(_canonical(b)) == jsonEncode(_canonical(a))) continue;
    if (b == null && a == null) continue;
    result.add(DiffEntry(key: k, before: b, after: a));
  }
  return result;
}

/// Short display text for a snapshot value.
String diffValueLabel(Object? value) {
  if (value == null) return '-';
  if (value is String) return value.isEmpty ? '""' : value;
  if (value is num || value is bool) return value.toString();
  if (value is Map && value.length == 1 && value.containsKey('paise')) {
    final paise = value['paise'];
    if (paise is int) {
      final rupees = paise ~/ 100;
      final rest = (paise % 100).abs().toString().padLeft(2, '0');
      return '₹$rupees.$rest';
    }
  }
  return jsonEncode(_canonical(value));
}
