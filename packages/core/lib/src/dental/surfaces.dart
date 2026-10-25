import 'package:meta/meta.dart';

import 'tooth_id.dart';

/// Canonical tooth surfaces. Stored as single-letter codes; the clinical label
/// depends on the tooth (O/I, B/F, L/P) and is produced by [labelFor].
///
/// `V` marks a Class V (cervical) lesion; it is drawn separately on the chart
/// and collapsed into the facial surface on any external export, as Open
/// Dental does for claims.
enum ToothSurface {
  mesial('M', 0),
  occlusal('O', 1),
  distal('D', 2),
  facial('F', 3),
  lingual('L', 4),
  classV('V', 5),
  root('R', 6),
  whole('W', 7);

  const ToothSurface(this.code, this.order);

  /// Single-letter canonical code used in storage.
  final String code;

  /// Canonical ordering inside a surface string (M, O, D, F, L, V, R, W).
  final int order;

  /// Clinical label for a given tooth: incisal for anterior teeth, buccal for
  /// posterior teeth, palatal for upper-arch lingual surfaces.
  String labelFor(ToothId tooth) => switch (this) {
    ToothSurface.occlusal => tooth.isAnterior ? 'I' : 'O',
    ToothSurface.facial => tooth.isAnterior ? 'F' : 'B',
    ToothSurface.lingual => tooth.arch == Arch.upper ? 'P' : 'L',
    _ => code,
  };

  String get longName => switch (this) {
    ToothSurface.mesial => 'Mesial',
    ToothSurface.occlusal => 'Occlusal / Incisal',
    ToothSurface.distal => 'Distal',
    ToothSurface.facial => 'Facial / Buccal',
    ToothSurface.lingual => 'Lingual / Palatal',
    ToothSurface.classV => 'Class V (cervical)',
    ToothSurface.root => 'Root',
    ToothSurface.whole => 'Whole tooth',
  };

  /// Whether this surface is one of the five crown faces that an odontogram
  /// renders as a tappable region.
  bool get isCrownFace => order <= 4;

  /// Parses any accepted letter, including the clinical synonyms I, B, P.
  static ToothSurface? fromLetter(String letter) {
    switch (letter.toUpperCase()) {
      case 'M':
        return ToothSurface.mesial;
      case 'O':
      case 'I':
        return ToothSurface.occlusal;
      case 'D':
        return ToothSurface.distal;
      case 'F':
      case 'B':
        return ToothSurface.facial;
      case 'L':
      case 'P':
        return ToothSurface.lingual;
      case 'V':
        return ToothSurface.classV;
      case 'R':
        return ToothSurface.root;
      case 'W':
        return ToothSurface.whole;
    }
    return null;
  }
}

/// An immutable, canonically ordered set of surfaces on one tooth.
@immutable
class SurfaceSet {
  SurfaceSet(Iterable<ToothSurface> surfaces)
    : _surfaces = List.unmodifiable(
        surfaces.toSet().toList()..sort((a, b) => a.order.compareTo(b.order)),
      );

  const SurfaceSet.empty() : _surfaces = const [];

  /// Parses a surface string such as `MOD`, `MIFL`, `B`, `mo d`. Unknown
  /// letters are ignored; use [tryParse] to reject them instead.
  factory SurfaceSet.parse(String code) => SurfaceSet(
    code
        .toUpperCase()
        .split('')
        .map(ToothSurface.fromLetter)
        .whereType<ToothSurface>(),
  );

  static SurfaceSet? tryParse(String code) {
    final letters = code.replaceAll(RegExp(r'\s'), '').toUpperCase().split('');
    final parsed = <ToothSurface>[];
    for (final l in letters) {
      final s = ToothSurface.fromLetter(l);
      if (s == null) return null;
      parsed.add(s);
    }
    return SurfaceSet(parsed);
  }

  final List<ToothSurface> _surfaces;

  List<ToothSurface> get surfaces => _surfaces;
  bool get isEmpty => _surfaces.isEmpty;
  bool get isNotEmpty => _surfaces.isNotEmpty;
  int get length => _surfaces.length;
  bool contains(ToothSurface s) => _surfaces.contains(s);

  /// Storage form: canonical letters in canonical order, e.g. `MOD`.
  String get code => _surfaces.map((s) => s.code).join();

  /// Clinical form for a tooth, e.g. `MID` on an incisor, `MOD` on a molar.
  String labelFor(ToothId tooth) =>
      _surfaces.map((s) => s.labelFor(tooth)).join();

  /// Export form with Class V folded into the facial surface (claims and
  /// FHIR exports have no concept of a V surface).
  String get exportCode {
    final set = _surfaces.toSet();
    if (set.remove(ToothSurface.classV)) set.add(ToothSurface.facial);
    return SurfaceSet(set).code;
  }

  /// Number of surfaces that count for restorative classification
  /// (crown faces only; V, root and whole are excluded).
  int get restorativeSurfaceCount =>
      _surfaces.where((s) => s.isCrownFace).length;

  SurfaceSet toggled(ToothSurface s) => contains(s)
      ? SurfaceSet(_surfaces.where((x) => x != s))
      : SurfaceSet([..._surfaces, s]);

  SurfaceSet union(SurfaceSet other) =>
      SurfaceSet([..._surfaces, ...other._surfaces]);

  @override
  bool operator ==(Object other) => other is SurfaceSet && other.code == code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => 'SurfaceSet($code)';
}

/// The anatomical extent a procedure or finding applies to. Mirrors the
/// treatment-area concept every mature dental PMS uses.
enum TreatmentArea {
  surface,
  tooth,
  quadrant,
  sextant,
  arch,
  toothRange,
  mouth;

  bool get needsTooth =>
      this == TreatmentArea.surface ||
      this == TreatmentArea.tooth ||
      this == TreatmentArea.toothRange;
  bool get needsSurfaces => this == TreatmentArea.surface;
}

/// Sextants numbered 1-6: upper right posterior, upper anterior, upper left
/// posterior, lower left posterior, lower anterior, lower right posterior.
enum Sextant {
  upperRightPosterior(1),
  upperAnterior(2),
  upperLeftPosterior(3),
  lowerLeftPosterior(4),
  lowerAnterior(5),
  lowerRightPosterior(6);

  const Sextant(this.number);
  final int number;

  static Sextant of(ToothId tooth) {
    final anterior = tooth.position <= 3;
    return switch ((tooth.arch, anterior, tooth.side)) {
      (Arch.upper, true, _) => Sextant.upperAnterior,
      (Arch.upper, false, Side.right) => Sextant.upperRightPosterior,
      (Arch.upper, false, Side.left) => Sextant.upperLeftPosterior,
      (Arch.lower, true, _) => Sextant.lowerAnterior,
      (Arch.lower, false, Side.left) => Sextant.lowerLeftPosterior,
      (Arch.lower, false, Side.right) => Sextant.lowerRightPosterior,
    };
  }
}
