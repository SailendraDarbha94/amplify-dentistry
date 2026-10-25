/// Storage failures surfaced without the bound row values, so a logged
/// message can never carry patient data.
library;

import 'package:drift/drift.dart';
import 'package:drift/native.dart' show SqliteException;

/// Coarse classification of a SQLite failure, from the primary result code.
enum RepositoryErrorKind {
  /// Primary code 19: a CHECK, NOT NULL, UNIQUE, PRIMARY KEY or FOREIGN KEY
  /// constraint rejected the write.
  constraint,

  /// Primary code 5 or 6: another connection holds the lock.
  busy,

  /// Primary codes 10, 11, 13: I/O error, corrupt file, disk full.
  storage,

  /// Anything else.
  other,
}

/// A storage error with the bound values stripped. `toString()` names the
/// SQLite result code, the table and (for constraints) the constraint's
/// identifiers; it never includes the statement's parameters, so it is safe
/// to log and to show in a crash report.
class RepositoryException implements Exception {
  /// Creates an exception from already sanitised parts.
  const RepositoryException({
    required this.kind,
    required this.extendedResultCode,
    this.table,
    this.constraint,
  });

  /// Builds a sanitised exception from a raw [SqliteException].
  factory RepositoryException.fromSqlite(SqliteException e) {
    final primary = e.extendedResultCode & 0xFF;
    return RepositoryException(
      kind: switch (primary) {
        19 => RepositoryErrorKind.constraint,
        5 || 6 => RepositoryErrorKind.busy,
        10 || 11 || 13 => RepositoryErrorKind.storage,
        _ => RepositoryErrorKind.other,
      },
      extendedResultCode: e.extendedResultCode,
      table: _tableOf(e.causingStatement),
      // sqlite3 puts the constraint text in `message` and SQLite's own
      // detail (when any) in `explanation`; both only name identifiers.
      constraint: _constraintOf(e.message) ?? _constraintOf(e.explanation),
    );
  }

  /// Classification.
  final RepositoryErrorKind kind;

  /// SQLite extended result code (e.g. 2067 `SQLITE_CONSTRAINT_UNIQUE`,
  /// 787 `SQLITE_CONSTRAINT_FOREIGNKEY`, 1299 `SQLITE_CONSTRAINT_NOTNULL`).
  final int extendedResultCode;

  /// Table the failing statement targeted, when it could be read from the
  /// statement text.
  final String? table;

  /// Identifiers of the violated constraint (`patients.clinic_id,
  /// patients.patient_number`), never values.
  final String? constraint;

  /// Primary result code (extended code masked to its low byte).
  int get resultCode => extendedResultCode & 0xFF;

  /// Symbolic name of the extended code when it is a constraint code.
  String get codeName => switch (extendedResultCode) {
    275 => 'SQLITE_CONSTRAINT_CHECK',
    787 => 'SQLITE_CONSTRAINT_FOREIGNKEY',
    1299 => 'SQLITE_CONSTRAINT_NOTNULL',
    1555 => 'SQLITE_CONSTRAINT_PRIMARYKEY',
    2067 => 'SQLITE_CONSTRAINT_UNIQUE',
    _ => 'SQLITE_$extendedResultCode',
  };

  @override
  String toString() {
    final b = StringBuffer('RepositoryException(${kind.name} $codeName');
    if (table != null) b.write(' on $table');
    if (constraint != null) b.write(': $constraint');
    b.write(')');
    return b.toString();
  }

  /// Unwraps drift's wrapper and sanitises a SQLite failure; returns null
  /// when [error] is not a SQLite error (callers rethrow those untouched).
  static RepositoryException? sanitise(Object error) {
    var cause = error;
    if (cause is DriftWrappedException) cause = cause.cause ?? cause;
    if (cause is SqliteException) return RepositoryException.fromSqlite(cause);
    return null;
  }

  static final RegExp _tablePattern = RegExp(
    r'^\s*(?:INSERT\s+(?:OR\s+\w+\s+)?INTO|UPDATE(?:\s+OR\s+\w+)?)\s+"?(\w+)"?',
    caseSensitive: false,
  );

  static String? _tableOf(String? statement) {
    if (statement == null) return null;
    return _tablePattern.firstMatch(statement)?.group(1);
  }

  /// SQLite phrases constraint failures as `KIND constraint failed: a.b,
  /// c.d`; the suffix lists column identifiers only. Anything else is
  /// dropped rather than risk echoing a value.
  static final RegExp _constraintPattern = RegExp(
    r'constraint failed(?::\s*([\w.]+(?:,\s*[\w.]+)*))?',
  );

  static String? _constraintOf(String? explanation) {
    if (explanation == null) return null;
    return _constraintPattern.firstMatch(explanation)?.group(1);
  }
}
