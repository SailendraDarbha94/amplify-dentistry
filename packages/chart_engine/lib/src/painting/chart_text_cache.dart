import 'package:flutter/painting.dart';

/// Caches laid-out [TextPainter]s by text, size and colour so a repaint never
/// re-shapes text that did not change. Owned by the widget state and handed
/// to each painter instance.
class ChartTextCache {
  ChartTextCache({this.capacity = 512});

  final int capacity;
  final Map<String, TextPainter> _entries = {};

  /// Number of cached painters.
  int get length => _entries.length;

  /// Returns a laid-out painter for [text].
  TextPainter painterFor(
    String text, {
    required double fontSize,
    required Color color,
    FontWeight weight = FontWeight.w500,
    String? fontFamily,
  }) {
    final key =
        '$text|${fontSize.toStringAsFixed(1)}|${color.toARGB32()}|${weight.value}|$fontFamily';
    final cached = _entries[key];
    if (cached != null) return cached;
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          color: color,
          fontWeight: weight,
          fontFamily: fontFamily,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    if (_entries.length >= capacity) {
      _entries.remove(_entries.keys.first)?.dispose();
    }
    _entries[key] = painter;
    return painter;
  }

  /// Paints [text] centred on [centre].
  void paintCentred(
    Canvas canvas,
    String text,
    Offset centre, {
    required double fontSize,
    required Color color,
    FontWeight weight = FontWeight.w500,
    String? fontFamily,
  }) {
    final tp = painterFor(
      text,
      fontSize: fontSize,
      color: color,
      weight: weight,
      fontFamily: fontFamily,
    );
    tp.paint(canvas, centre - Offset(tp.width / 2, tp.height / 2));
  }

  /// Releases every cached painter.
  void dispose() {
    for (final p in _entries.values) {
      p.dispose();
    }
    _entries.clear();
  }
}
