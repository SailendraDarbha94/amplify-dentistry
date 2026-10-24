import 'dart:ui';

/// Colours for the periodontal chart grid.
class PerioStyle {
  const PerioStyle({
    required this.brightness,
    required this.gridLine,
    required this.headerBackground,
    required this.cellBackground,
    required this.absentColumn,
    required this.text,
    required this.mutedText,
    required this.depthNormal,
    required this.depthWarning,
    required this.depthSevere,
    required this.bleedingDot,
    required this.suppurationDot,
    required this.plaqueDot,
    required this.focusedCell,
    required this.recession,
    this.fontSize = 12.0,
    this.fontFamily,
  });

  final Brightness brightness;
  final Color gridLine;
  final Color headerBackground;
  final Color cellBackground;

  /// Shading for the column of an absent / skipped tooth.
  final Color absentColumn;
  final Color text;
  final Color mutedText;

  /// Probing depth 0-3 mm.
  final Color depthNormal;

  /// Probing depth 4-5 mm (amber).
  final Color depthWarning;

  /// Probing depth 6 mm and above (red).
  final Color depthSevere;
  final Color bleedingDot;
  final Color suppurationDot;
  final Color plaqueDot;

  /// Fill behind the focused cell.
  final Color focusedCell;

  /// Text colour for a negative gingival margin (recession).
  final Color recession;
  final double fontSize;
  final String? fontFamily;

  /// Threshold colour for a probing depth: >= 6 severe, >= 4 warning.
  Color depthColor(int? depth) {
    if (depth == null) return mutedText;
    if (depth >= 6) return depthSevere;
    if (depth >= 4) return depthWarning;
    return depthNormal;
  }

  /// Picks the variant for [brightness].
  static PerioStyle of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  /// Light theme palette.
  static const PerioStyle light = PerioStyle(
    brightness: Brightness.light,
    gridLine: Color(0xFFD6D9DE),
    headerBackground: Color(0xFFF2F4F7),
    cellBackground: Color(0xFFFFFFFF),
    absentColumn: Color(0xFFEDEEF0),
    text: Color(0xFF212121),
    mutedText: Color(0xFF9E9E9E),
    depthNormal: Color(0xFF212121),
    depthWarning: Color(0xFFF59E0B),
    depthSevere: Color(0xFFD32F2F),
    bleedingDot: Color(0xFFD32F2F),
    suppurationDot: Color(0xFFF59E0B),
    plaqueDot: Color(0xFF1E6FD9),
    focusedCell: Color(0x33FFB300),
    recession: Color(0xFFB71C1C),
  );

  /// Dark theme palette.
  static const PerioStyle dark = PerioStyle(
    brightness: Brightness.dark,
    gridLine: Color(0xFF474C54),
    headerBackground: Color(0xFF2B2F36),
    cellBackground: Color(0xFF1E2126),
    absentColumn: Color(0xFF2A2D32),
    text: Color(0xFFE6E8EB),
    mutedText: Color(0xFF8A8F96),
    depthNormal: Color(0xFFE6E8EB),
    depthWarning: Color(0xFFFFB300),
    depthSevere: Color(0xFFEF5350),
    bleedingDot: Color(0xFFEF5350),
    suppurationDot: Color(0xFFFFB300),
    plaqueDot: Color(0xFF64A5FF),
    focusedCell: Color(0x33FFC107),
    recession: Color(0xFFEF9A9A),
  );
}
