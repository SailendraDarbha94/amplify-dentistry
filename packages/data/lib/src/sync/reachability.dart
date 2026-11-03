/// Server reachability probe for the sync scheduler. Pure Dart: one short
/// request against the Supabase Auth health endpoint, no platform plugin.
library;

import 'dart:async';

import 'package:ampdent_core/ampdent_core.dart';
import 'package:http/http.dart' as http;

/// Answers "can this device reach the project right now?" with a `HEAD`
/// (falling back to `GET` when the server does not allow `HEAD`) against
/// `<SUPABASE_URL>/auth/v1/health`, bounded by [timeout]. Any response
/// below 500 counts as reachable; a timeout, a socket error or a 5xx does
/// not.
class Reachability {
  /// Creates the probe for the project at [supabaseUrl].
  Reachability({
    required Uri supabaseUrl,
    this.client,
    this.timeout = const Duration(seconds: 3),
  }) : healthUrl = healthUrlFor(supabaseUrl);

  /// `<supabaseUrl>/auth/v1/health`, tolerating a trailing slash.
  static Uri healthUrlFor(Uri supabaseUrl) {
    var base = supabaseUrl.path;
    if (base.endsWith('/')) base = base.substring(0, base.length - 1);
    return supabaseUrl.replace(path: '$base/auth/v1/health', query: null);
  }

  static const Logger _log = Logger('Reachability');

  /// The probed URL.
  final Uri healthUrl;

  /// Request timeout.
  final Duration timeout;

  /// Client to probe with (a `MockClient` in tests); null opens and closes
  /// a fresh one per probe.
  final http.Client? client;

  /// Result of the last probe, null before the first.
  bool? lastResult;

  /// When the last probe finished.
  DateTime? lastProbedAt;

  /// Runs the probe.
  Future<bool> probe() async {
    final c = client ?? http.Client();
    try {
      var status = await _status(c, 'HEAD');
      if (status == 405 || status == 404 || status == 501) {
        status = await _status(c, 'GET');
      }
      return _record(status < 500);
    } on TimeoutException {
      _log.debug('probe timed out');
      return _record(false);
    } on http.ClientException catch (e) {
      _log.debug('probe failed: ${e.runtimeType}');
      return _record(false);
    } catch (e) {
      _log.debug('probe failed: ${e.runtimeType}');
      return _record(false);
    } finally {
      if (client == null) c.close();
    }
  }

  Future<int> _status(http.Client client, String method) async {
    final req = http.Request(method, healthUrl);
    final res = await client.send(req).timeout(timeout);
    // Drain the body so the connection can be reused.
    await res.stream.drain<void>().timeout(timeout, onTimeout: () {});
    return res.statusCode;
  }

  bool _record(bool reachable) {
    lastResult = reachable;
    lastProbedAt = DateTime.now().toUtc();
    return reachable;
  }
}
