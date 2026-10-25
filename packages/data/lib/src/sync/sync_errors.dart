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
  const SyncFailure(this.kind, this.message, {this.table, this.cause});

  /// Classification.
  final SyncFailureKind kind;

  /// Table name, when the failure is table-specific.
  final String? table;

  /// Human-readable summary (error class, status, table).
  final String message;

  /// Underlying exception, kept for diagnostics only.
  final Object? cause;

  /// Whether a later retry can succeed without changing the payload.
  bool get isTransient => kind == SyncFailureKind.transient;

  @override
  String toString() => 'SyncFailure(${kind.name}, $message)';
}

/// Classifies [error] thrown by a PostgREST request. Server errors (5xx),
/// 408/429 and every non-PostgREST exception (socket, timeout, client) count
/// as transient; other PostgREST errors are rejections.
SyncFailure classifySyncError(Object error, {required String table}) {
  if (error is SyncFailure) return error;
  if (error is PostgrestException) {
    final code = error.code ?? '';
    // Three digits is an HTTP status; five characters is a Postgres code.
    final status = code.length == 3 ? int.tryParse(code) : null;
    final transient =
        (status != null && (status >= 500 || status == 408 || status == 429));
    return SyncFailure(
      transient ? SyncFailureKind.transient : SyncFailureKind.rejected,
      'PostgrestException $code on $table',
      table: table,
      cause: error,
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
