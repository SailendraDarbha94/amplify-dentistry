/// Error classification for the sync engine. Messages name tables, counts
/// and error classes only; no row contents ever reach a log or the UI.
library;

import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:supabase/supabase.dart';

/// Why a push or pull stopped.
enum SyncFailureKind {
  /// Network unreachable, timeout or a 5xx from the server: retry later.
  transient,

  /// The server rejected the request (4xx, constraint or policy violation):
  /// retrying the same payload will fail again.
  rejected,

  /// No access token (signed out) or the clinic is not linked yet.
  notReady,
}

/// A sync step failed. [message] is safe to show and log.
class SyncFailure implements Exception {
  /// Creates a failure.
  const SyncFailure(
    this.kind,
    this.message, {
    this.table,
    this.cause,
    this.statusCode,
  });

  /// Classification.
  final SyncFailureKind kind;

  /// HTTP status the server answered with, when known. PostgREST hides the
  /// status behind the Postgres error code it returns, so for those the
  /// value is inferred from the code class (see [inferHttpStatus]).
  final int? statusCode;

  /// Table name, when the failure is table-specific.
  final String? table;

  /// Human-readable summary (error class, status, table).
  final String message;

  /// Underlying exception, kept for diagnostics only.
  final Object? cause;

  /// Whether a later retry can succeed without changing the payload.
  bool get isTransient => kind == SyncFailureKind.transient;

  /// Whether the server rejected the payload for good: a 4xx other than
  /// 401/408/429, or a Postgres constraint / policy error. Such rows are
  /// quarantined by the pusher instead of retried.
  bool get isPermanent => kind == SyncFailureKind.rejected;

  /// The server's own error text, trimmed, without `details` (which can
  /// quote the row's values). Null for non-PostgREST failures.
  String? get serverMessage {
    final c = cause;
    if (c is! PostgrestException) return null;
    final m = c.message.trim();
    return m.length > 200 ? '${m.substring(0, 200)}...' : m;
  }

  @override
  String toString() => 'SyncFailure(${kind.name}, $message)';
}

/// Postgres error codes PostgREST answers with 401 (expired or invalid JWT).
const Set<String> _authCodes = {'PGRST301', 'PGRST302', 'PGRST303'};

/// Best-effort HTTP status for a PostgREST [code]: the status itself when
/// the body carried none, else the class PostgREST maps the Postgres code
/// to (`23xxx` constraints -> 409, `42501` RLS -> 403, other `42xxx` ->
/// 404, `22xxx` bad input -> 400, `PGRST1xx` -> 400, `PGRST3xx` -> 401).
int? inferHttpStatus(String code) {
  if (code.length == 3) return int.tryParse(code);
  if (_authCodes.contains(code)) return 401;
  if (code.startsWith('PGRST3')) return 401;
  if (code.startsWith('PGRST')) return 400;
  if (code.startsWith('23')) return 409;
  if (code == '42501') return 403;
  if (code.startsWith('42')) return 404;
  if (code.startsWith('22')) return 400;
  if (code.startsWith('P0')) return 400;
  return null;
}

/// Classifies [error] thrown by a PostgREST request. Server errors (5xx),
/// 408/429 and every non-PostgREST exception (socket, timeout, client) count
/// as transient; 401 (and the PGRST30x JWT codes) mean the session must be
/// refreshed, not the payload fixed, so they are [SyncFailureKind.notReady];
/// every other PostgREST error is a rejection of the payload.
SyncFailure classifySyncError(Object error, {required String table}) {
  if (error is SyncFailure) return error;
  if (error is PostgrestException) {
    final code = error.code ?? '';
    final status = inferHttpStatus(code);
    final transient =
        status != null && (status >= 500 || status == 408 || status == 429);
    final auth = status == 401;
    return SyncFailure(
      transient
          ? SyncFailureKind.transient
          : auth
          ? SyncFailureKind.notReady
          : SyncFailureKind.rejected,
      'PostgrestException $code on $table',
      table: table,
      cause: error,
      statusCode: status,
    );
  }
  if (error is TimeoutException || error is http.ClientException) {
    return SyncFailure(
      SyncFailureKind.transient,
      '${error.runtimeType} on $table',
      table: table,
      cause: error,
    );
  }
  return SyncFailure(
    SyncFailureKind.transient,
    '${error.runtimeType} on $table',
    table: table,
    cause: error,
  );
}

/// Exponential backoff schedule for transient failures.
class BackoffPolicy {
  /// Creates a policy: `initial * multiplier^attempt`, capped at [max], for
  /// at most [maxAttempts] attempts per batch.
  const BackoffPolicy({
    this.initial = const Duration(seconds: 1),
    this.multiplier = 2,
    this.max = const Duration(seconds: 30),
    this.maxAttempts = 4,
  });

  /// Delay before the first retry.
  final Duration initial;

  /// Growth factor per retry.
  final double multiplier;

  /// Longest delay.
  final Duration max;

  /// Attempts per batch before the push gives up for this run.
  final int maxAttempts;

  /// Delay before retry number [attempt] (1-based).
  Duration delayFor(int attempt) {
    var micros = initial.inMicroseconds.toDouble();
    for (var i = 1; i < attempt; i++) {
      micros *= multiplier;
    }
    final d = Duration(microseconds: micros.round());
    return d > max ? max : d;
  }
}
