import 'tooth_id.dart';

/// Tooth numbering systems supported for display. FDI is always the stored
/// form (see [ToothId]).
enum ToothNotation {
  fdi,
  universal,
  palmer;

  String get label => switch (this) {
    ToothNotation.fdi => 'FDI (ISO 3950)',
    ToothNotation.universal => 'Universal (ADA)',
    ToothNotation.palmer => 'Palmer',
  };

  /// Renders a tooth in this notation. Palmer uses box-drawing glyphs; use
  /// [formatPlain] where glyphs are not wanted (PDF fonts, logs).
  String format(ToothId tooth) => switch (this) {
    ToothNotation.fdi => tooth.storageKey,
    ToothNotation.universal => tooth.universal,
    ToothNotation.palmer => tooth.palmer,
  };

  String formatPlain(ToothId tooth) => switch (this) {
    ToothNotation.fdi => tooth.storageKey,
    ToothNotation.universal => tooth.universal,
    ToothNotation.palmer => tooth.palmerText,
  };

  /// Renders a list of teeth joined by `, ` in this notation, FDI-sorted.
  String formatAll(Iterable<ToothId> teeth, {bool plain = false}) {
    final sorted = teeth.toList()..sort();
    return sorted.map(plain ? formatPlain : format).join(', ');
  }

  /// Parses a tooth written in this notation.
  ToothId? tryParse(String input) => switch (this) {
    ToothNotation.fdi => ToothId.tryParse(input),
    ToothNotation.universal => ToothId.tryParseUniversal(input),
    ToothNotation.palmer => _tryParsePalmer(input),
  };

  static ToothId? _tryParsePalmer(String input) {
    final s = input.trim().toUpperCase().replaceAll(' ', '');
    final match = RegExp(r'^(UR|UL|LL|LR)([1-8A-E])$').firstMatch(s);
    if (match == null) return null;
    final quadrant = Quadrant.values.firstWhere(
      (q) => q.label == match.group(1),
    );
    final symbol = match.group(2)!;
    final digit = int.tryParse(symbol);
    if (digit != null) {
      return ToothId(
        dentition: Dentition.permanent,
        quadrant: quadrant,
        position: digit,
      );
    }
    return ToothId(
      dentition: Dentition.primary,
      quadrant: quadrant,
      position: symbol.codeUnitAt(0) - 'A'.codeUnitAt(0) + 1,
    );
  }
}

/// Parses free text containing tooth codes in any notation, e.g. the
/// `{tooth_numbers}` field of a consent form ("16, 17" or "UR6 UR7" or
/// "3, 14"). Ambiguous inputs are resolved in favour of [preferred].
List<ToothId> parseToothList(
  String input, {
  ToothNotation preferred = ToothNotation.fdi,
}) {
  final tokens = input
      .split(RegExp(r'[,\s;/]+'))
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty);
  final out = <ToothId>[];
  for (final token in tokens) {
    final id =
        preferred.tryParse(token) ??
        ToothNotation.fdi.tryParse(token) ??
        ToothNotation.palmer.tryParse(token) ??
        ToothNotation.universal.tryParse(token);
    if (id != null && !out.contains(id)) out.add(id);
  }
  out.sort();
  return out;
}
