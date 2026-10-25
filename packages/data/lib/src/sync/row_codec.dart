/// Maps Drift rows to the Supabase schema and back, from table metadata
/// alone: SQL names are shared, `Money` columns carry a `_paise` suffix on
/// the server, booleans are integers locally, JSON converters become
/// `jsonb`, and ISO text dates become `timestamptz`/`date`.
library;

import 'dart:convert';

import 'package:ampdent_core/ampdent_core.dart' show Money;
import 'package:drift/drift.dart';

import '../db/converters.dart';

/// Row mapping for one table.
class SyncRowCodec {
  /// Creates the codec for [table]; [jsonTextColumns] are plain text
  /// locally but `jsonb` on the server (`settings.value_json`).
  SyncRowCodec(this.table, {this.jsonTextColumns = const {}});

  /// Drift table metadata.
  final TableInfo<Table, Object?> table;

  /// Local text columns stored as `jsonb` server-side.
  final Set<String> jsonTextColumns;

  /// SQL table name.
  String get tableName => table.actualTableName;

  /// All columns.
  List<GeneratedColumn<Object>> get columns => table.$columns;

  /// Whether the table carries `updated_at` (used for last-writer-wins).
  bool get hasUpdatedAt => columns.any((c) => c.$name == 'updated_at');

  // Nullable columns wrap their converter in drift's private null-aware
  // wrapper, so the checks below go by the column's Dart/JSON types rather
  // than by converter class.

  /// Whether [c] stores a [Money] (integer paise locally, `_paise` column
  /// on the server).
  static bool isMoneyColumn(GeneratedColumn c) =>
      c is GeneratedColumnWithTypeConverter<Money?, int>;

  /// Server column name for [c].
  static String serverColumnName(GeneratedColumn c) =>
      isMoneyColumn(c) ? '${c.$name}_paise' : c.$name;

  /// Whether a text column holds JSON (list/map converter) rather than a
  /// scalar (date, enum name, tooth key, surface code).
  bool isJsonColumn(GeneratedColumn c) {
    if (c.type != DriftSqlType.string) return false;
    if (jsonTextColumns.contains(c.$name)) return true;
    if (c is! GeneratedColumnWithTypeConverter) return false;
    final conv = c.converter;
    return conv is JsonTypeConverter2<Object?, String?, Object?> &&
        conv is! JsonTypeConverter2<Object?, String?, String?>;
  }

  /// Whether a text column is an ISO-8601 UTC date.
  static bool isDateColumn(GeneratedColumn c) =>
      c is GeneratedColumnWithTypeConverter<DateTime?, String>;

  /// Converts a local SQL row (`QueryRow.data`) to the server JSON object.
  /// `updated_at` is never sent: the server assigns it so late offline
  /// writes still land above every device's watermark.
  Map<String, Object?> toServer(
    Map<String, Object?> local, {
    Set<String> exclude = const {},
    Set<String>? only,
  }) {
    final out = <String, Object?>{};
    for (final c in columns) {
      final name = c.$name;
      if (name == 'updated_at' || exclude.contains(name)) continue;
      if (only != null && !only.contains(name)) continue;
      out[serverColumnName(c)] = _encode(c, local[name]);
    }
    return out;
  }

  Object? _encode(GeneratedColumn c, Object? v) {
    if (v == null) return null;
    if (c.type == DriftSqlType.bool) return v is int ? v != 0 : v == true;
    if (isJsonColumn(c) && v is String) return jsonDecode(v);
    return v;
  }

  /// Converts a server row to local SQL values keyed by local column name.
  /// Server columns the device does not know are ignored; local columns the
  /// server did not send are left out (defaults apply).
  Map<String, Object?> fromServer(Map<String, Object?> server) {
    final out = <String, Object?>{};
    for (final c in columns) {
      final sname = serverColumnName(c);
      if (!server.containsKey(sname)) continue;
      out[c.$name] = _decode(c, server[sname]);
    }
    return out;
  }

  Object? _decode(GeneratedColumn c, Object? v) {
    if (v == null) return null;
    switch (c.type) {
      case DriftSqlType.bool:
        return (v is bool ? v : v == 1 || v == 'true') ? 1 : 0;
      case DriftSqlType.int:
      case DriftSqlType.bigInt:
        return v is num ? v.toInt() : int.parse('$v');
      case DriftSqlType.double:
        return v is num ? v.toDouble() : double.parse('$v');
      case DriftSqlType.string:
        if (isDateColumn(c)) return normaliseServerTimestamp('$v');
        // A `jsonb` column whose local form is JSON text: the server value
        // is any JSON (a bare string for `"palmer"`, a number, a map), so it
        // is always re-encoded; a jsonb string must not land as plain text.
        if (jsonTextColumns.contains(c.$name)) return jsonEncode(v);
        if (isJsonColumn(c)) return v is String ? v : jsonEncode(v);
        return v is String ? v : jsonEncode(v);
      default:
        return v;
    }
  }

  /// `INSERT` statement and variables for [values] (local column names).
  (String, List<Variable<Object>>) insertSql(Map<String, Object?> values) {
    final cols = values.keys.toList();
    final sql =
        'INSERT INTO "$tableName" (${cols.map((c) => '"$c"').join(', ')}) '
        'VALUES (${cols.map((_) => '?').join(', ')})';
    return (sql, [for (final c in cols) Variable<Object>(values[c])]);
  }

  /// `UPDATE` statement and variables for [values], matched on [keyColumns].
  (String, List<Variable<Object>>) updateSql(
    Map<String, Object?> values,
    List<String> keyColumns,
  ) {
    final cols = values.keys.where((c) => !keyColumns.contains(c)).toList();
    final sql =
        'UPDATE "$tableName" SET ${cols.map((c) => '"$c" = ?').join(', ')} '
        'WHERE ${keyColumns.map((c) => '"$c" = ?').join(' AND ')}';
    return (
      sql,
      [
        for (final c in cols) Variable<Object>(values[c]),
        for (final c in keyColumns) Variable<Object>(values[c]),
      ],
    );
  }
}

/// Rewrites a server timestamp (`2026-10-18T09:30:00.123456+00:00`) or date
/// (`1990-05-20`) in the local fixed format (UTC, millisecond precision).
String normaliseServerTimestamp(String value) {
  if (value.length == 10) {
    final parts = value.split('-').map(int.parse).toList();
    return encodeIsoUtc(DateTime.utc(parts[0], parts[1], parts[2]));
  }
  return encodeIsoUtc(DateTime.parse(value));
}

/// Parses any ISO-8601 instant (server or local form) as UTC.
DateTime parseInstant(String value) => DateTime.parse(value).toUtc();
