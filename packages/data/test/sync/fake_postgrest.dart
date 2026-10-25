/// In-memory PostgREST stand-in for the sync tests: enough of the filter,
/// order, limit and upsert semantics for the queries the engine issues, plus
/// the server behaviours that matter for conflicts (server-assigned
/// `updated_at`, invoice numbers minted when a DRAFT- invoice leaves draft,
/// no UPDATE policy on immutable tables).
library;

import 'dart:collection';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// One observed request.
class FakeRequest {
  FakeRequest(this.method, this.table, this.query, this.headers, this.body);

  final String method;
  final String table;
  final Map<String, String> query;
  final Map<String, String> headers;
  final Object? body;

  List<Map<String, Object?>> get rows => [
    for (final r in body is List ? body as List : [body])
      (r as Map).cast<String, Object?>(),
  ];

  String get prefer => headers['Prefer'] ?? headers['prefer'] ?? '';

  @override
  String toString() => '$method $table $query';
}

/// Tables without an UPDATE policy on the server (0006).
const Set<String> fakeNoUpdateTables = {
  'payments',
  'ledger_entries',
  'consent_records',
  'prescriptions',
  'medical_histories',
  'tooth_state_records',
};

class FakePostgrest {
  final Map<String, List<Map<String, Object?>>> tables = {};
  final List<FakeRequest> requests = [];

  /// Status codes to answer the next requests with (each consumed once).
  final Queue<int> failNext = Queue<int>();

  /// Extra latency per request (for concurrency tests).
  Duration latency = Duration.zero;
  int inFlight = 0;
  int maxInFlight = 0;

  int _micros = DateTime.utc(2026, 10, 20, 8).microsecondsSinceEpoch;
  int invoiceCounter = 0;

  http.Client get client => MockClient(handle);

  /// Server timestamp text for [at] (microsecond precision, +00:00).
  static String ts(DateTime at) {
    final iso = at.toUtc().toIso8601String();
    final noZ = iso.substring(0, iso.length - 1);
    final dot = noZ.indexOf('.');
    final base = dot < 0 ? noZ : noZ.substring(0, dot);
    final frac = (dot < 0 ? '' : noZ.substring(dot + 1)).padRight(6, '0');
    return '$base.$frac+00:00';
  }

  /// Next monotonic server timestamp.
  String nextTimestamp() {
    _micros += 1000;
    return ts(DateTime.fromMicrosecondsSinceEpoch(_micros, isUtc: true));
  }

  /// Inserts a server row, assigning `updated_at` unless given.
  Map<String, Object?> seed(
    String table,
    Map<String, Object?> row, {
    String? updatedAt,
  }) {
    final stored = {...row};
    stored['updated_at'] = updatedAt ?? stored['updated_at'] ?? nextTimestamp();
    stored['created_at'] ??= stored['updated_at'];
    (tables[table] ??= []).add(stored);
    return stored;
  }

  List<Map<String, Object?>> rows(String table) => tables[table] ?? const [];

  Map<String, Object?>? row(String table, String id) =>
      rows(table)
          .cast<Map<String, Object?>?>()
          .firstWhere((r) => r!['id'] == id, orElse: () => null);

  List<FakeRequest> requestsFor(String table, {String? method}) => [
    for (final r in requests)
      if (r.table == table && (method == null || r.method == method)) r,
  ];

  Future<http.Response> handle(http.Request req) async {
    inFlight++;
    if (inFlight > maxInFlight) maxInFlight = inFlight;
    try {
      if (latency > Duration.zero) await Future<void>.delayed(latency);
      final table = req.url.pathSegments.last;
      Object? body;
      if (req.body.isNotEmpty) body = jsonDecode(req.body);
      requests.add(
        FakeRequest(
          req.method,
          table,
          req.url.queryParameters,
          req.headers,
          body,
        ),
      );
      final http.Response res;
      if (failNext.isNotEmpty) {
        final code = failNext.removeFirst();
        res = _error(
          code,
          'injected failure',
          pgCode: code == 409 ? '23503' : null,
        );
      } else {
        res = switch (req.method) {
          'POST' => _upsert(table, req, body is List ? body : [body]),
          'GET' => _select(table, req.url.queryParameters),
          _ => _error(405, 'unsupported'),
        };
      }
      // PostgREST's client reads `response.request`; MockClient copies it
      // from the handler's response, so attach it here.
      return http.Response(
        res.body,
        res.statusCode,
        headers: res.headers,
        request: req,
      );
    } finally {
      inFlight--;
    }
  }

  http.Response _error(int status, String message, {String? pgCode}) =>
      http.Response(
        jsonEncode({
          'message': message,
          'code': ?pgCode,
          'details': null,
          'hint': null,
        }),
        status,
        headers: {'content-type': 'application/json'},
      );

  http.Response _upsert(String table, http.Request req, List body) {
    final keys = (req.url.queryParameters['on_conflict'] ?? 'id').split(',');
    final prefer = req.headers['Prefer'] ?? req.headers['prefer'] ?? '';
    final ignore = prefer.contains('ignore-duplicates');
    final store = tables[table] ??= [];
    for (final raw in body) {
      final row = (raw as Map).cast<String, Object?>();
      final existing = store.cast<Map<String, Object?>?>().firstWhere(
        (r) => keys.every((k) => r![k] == row[k]),
        orElse: () => null,
      );
      if (existing == null) {
        final stored = {...row};
        stored['updated_at'] ??= nextTimestamp();
        stored['created_at'] ??= stored['updated_at'];
        _invoiceHook(table, stored, null);
        store.add(stored);
      } else if (!ignore) {
        if (fakeNoUpdateTables.contains(table)) {
          return _error(
            403,
            'new row violates row-level security policy for table "$table"',
            pgCode: '42501',
          );
        }
        final oldNumber = existing['number'];
        existing.addAll(row);
        existing['updated_at'] = nextTimestamp();
        _invoiceHook(table, existing, oldNumber);
      }
    }
    return http.Response('', 201);
  }

  void _invoiceHook(String table, Map<String, Object?> row, Object? oldNumber) {
    if (table != 'invoices') return;
    if (oldNumber is String && !oldNumber.startsWith('DRAFT-')) {
      row['number'] = oldNumber;
    }
    final number = '${row['number']}';
    if (row['status'] != 'draft' && number.startsWith('DRAFT-')) {
      invoiceCounter++;
      row['number'] =
          'INV/2026-27/${invoiceCounter.toString().padLeft(4, '0')}';
    }
  }

  http.Response _select(String table, Map<String, String> q) {
    var result = List<Map<String, Object?>>.from(rows(table));
    for (final e in q.entries) {
      switch (e.key) {
        case 'select':
        case 'order':
        case 'limit':
        case 'offset':
        case 'on_conflict':
        case 'columns':
          continue;
        case 'or':
          result = result
              .where((r) => _logic(_unwrap(e.value), r, isOr: true))
              .toList();
        case 'and':
          result = result
              .where((r) => _logic(_unwrap(e.value), r, isOr: false))
              .toList();
        default:
          result = result.where((r) => _filter(e.key, e.value, r)).toList();
      }
    }
    final order = q['order'];
    if (order != null) {
      final terms = order.split(',').map((t) => t.split('.')).toList();
      result.sort((a, b) {
        for (final t in terms) {
          final c = '${a[t[0]]}'.compareTo('${b[t[0]]}');
          if (c != 0) return t.length > 1 && t[1] == 'desc' ? -c : c;
        }
        return 0;
      });
    }
    final offset = int.tryParse(q['offset'] ?? '') ?? 0;
    if (offset > 0) result = result.skip(offset).toList();
    final limit = int.tryParse(q['limit'] ?? '');
    if (limit != null) result = result.take(limit).toList();
    final select = q['select'];
    if (select != null && select != '*') {
      final cols = select.split(',');
      result = [
        for (final r in result) {for (final c in cols) c: r[c]},
      ];
    }
    return http.Response(
      jsonEncode(result),
      200,
      headers: {'content-type': 'application/json'},
    );
  }

  static String _unwrap(String s) =>
      s.startsWith('(') && s.endsWith(')') ? s.substring(1, s.length - 1) : s;

  bool _logic(String expr, Map<String, Object?> row, {required bool isOr}) {
    final parts = _splitTopLevel(expr);
    final results = parts.map((p) {
      if (p.startsWith('and(')) {
        return _logic(p.substring(4, p.length - 1), row, isOr: false);
      }
      if (p.startsWith('or(')) {
        return _logic(p.substring(3, p.length - 1), row, isOr: true);
      }
      final dot = p.indexOf('.');
      return _filter(p.substring(0, dot), p.substring(dot + 1), row);
    });
    return isOr ? results.any((b) => b) : results.every((b) => b);
  }

  static List<String> _splitTopLevel(String s) {
    final out = <String>[];
    var depth = 0;
    var start = 0;
    var quoted = false;
    for (var i = 0; i < s.length; i++) {
      final ch = s[i];
      if (ch == '"') quoted = !quoted;
      if (quoted) continue;
      if (ch == '(') depth++;
      if (ch == ')') depth--;
      if (ch == ',' && depth == 0) {
        out.add(s.substring(start, i));
        start = i + 1;
      }
    }
    out.add(s.substring(start));
    return out;
  }

  /// `op.value` against a column.
  bool _filter(String column, String spec, Map<String, Object?> row) {
    final dot = spec.indexOf('.');
    final op = spec.substring(0, dot);
    var value = spec.substring(dot + 1);
    if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
      value = value.substring(1, value.length - 1);
    }
    final actual = row[column];
    switch (op) {
      case 'eq':
        return '$actual' == value;
      case 'neq':
        return '$actual' != value;
      case 'gt':
        return actual != null && '$actual'.compareTo(value) > 0;
      case 'gte':
        return actual != null && '$actual'.compareTo(value) >= 0;
      case 'lt':
        return actual != null && '$actual'.compareTo(value) < 0;
      case 'lte':
        return actual != null && '$actual'.compareTo(value) <= 0;
      case 'is':
        return value == 'null' ? actual == null : '$actual' == value;
      default:
        throw UnsupportedError('operator $op');
    }
  }
}
