/// Minimal structured logger with no Flutter dependency. The app installs a
/// sink (console in debug, crash reporter later); packages log through it.
/// Never log patient identifiers or clinical text.
enum LogLevel { debug, info, warning, error }

typedef LogSink = void Function(
  LogLevel level,
  String tag,
  String message, {
  Object? error,
  StackTrace? stackTrace,
});

class Logger {
  const Logger(this.tag);

  final String tag;

  static LogSink _sink = _noop;
  static LogLevel minimumLevel = LogLevel.debug;

  static void install(LogSink sink) => _sink = sink;

  static void _noop(
    LogLevel level,
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {}

  void debug(String message) => _log(LogLevel.debug, message);
  void info(String message) => _log(LogLevel.info, message);
  void warning(String message, {Object? error}) =>
      _log(LogLevel.warning, message, error: error);
  void error(String message, {Object? error, StackTrace? stackTrace}) =>
      _log(LogLevel.error, message, error: error, stackTrace: stackTrace);

  void _log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level.index < minimumLevel.index) return;
    _sink(level, tag, message, error: error, stackTrace: stackTrace);
  }
}
