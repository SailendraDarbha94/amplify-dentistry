import 'dart:async';

/// A FIFO mutex: [synchronized] runs one body at a time, in call order.
/// Push and pull share one so they never interleave on the database or
/// the watermarks.
class AsyncMutex {
  Future<void> _tail = Future<void>.value();

  /// Whether a body is currently running or queued.
  bool get isLocked => _locked;
  bool _locked = false;

  /// Runs [body] once every earlier caller has finished.
  Future<T> synchronized<T>(Future<T> Function() body) {
    final previous = _tail;
    final completer = Completer<void>();
    _tail = completer.future;
    return previous.then((_) async {
      _locked = true;
      try {
        return await body();
      } finally {
        _locked = false;
        completer.complete();
      }
    });
  }
}
