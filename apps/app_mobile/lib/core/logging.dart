import 'package:ampdent_core/ampdent_core.dart';
import 'package:flutter/foundation.dart';

/// Installs the app-wide [Logger] sink. Debug builds print every level
/// through [debugPrint]; release builds keep warnings and errors only and
/// drop the rest (a crash reporter can be attached here later).
void installLogging() {
  Logger.minimumLevel = kReleaseMode ? LogLevel.warning : LogLevel.debug;
  Logger.install(_consoleSink);
}

void _consoleSink(
  LogLevel level,
  String tag,
  String message, {
  Object? error,
  StackTrace? stackTrace,
}) {
  final buffer = StringBuffer()
    ..write('[')
    ..write(level.name.toUpperCase())
    ..write('] ')
    ..write(tag)
    ..write(': ')
    ..write(message);
  if (error != null) buffer.write(' | $error');
  debugPrint(buffer.toString());
  if (stackTrace != null && level == LogLevel.error) {
    debugPrint(stackTrace.toString());
  }
}
