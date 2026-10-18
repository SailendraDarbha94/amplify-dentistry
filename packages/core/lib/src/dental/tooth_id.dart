import 'package:meta/meta.dart';

/// Permanent or primary (deciduous) dentition.
enum Dentition {
  permanent,
  primary;

  /// Number of tooth positions per quadrant in this dentition.
  int get positionsPerQuadrant => this == Dentition.permanent ? 8 : 5;
}

/// Upper or lower jaw.
enum Arch { upper, lower }

/// Left or right side as seen from the patient's perspective.
enum Side { right, left }

/// The four quadrants. FDI digits: 1-4 permanent, 5-8 primary.
enum Quadrant {
  upperRight(1, Arch.upper, Side.right),
  upperLeft(2, Arch.upper, Side.left),
  lowerLeft(3, Arch.lower, Side.left),
  lowerRight(4, Arch.lower, Side.right);

  const Quadrant(this.permanentDigit, this.arch, this.side);

  /// FDI quadrant digit for permanent teeth (1-4).
  final int permanentDigit;
  final Arch arch;
  final Side side;

  /// FDI quadrant digit for primary teeth (5-8).
  int get primaryDigit => permanentDigit + 4;

  int digitFor(Dentition dentition) =>
      dentition == Dentition.permanent ? permanentDigit : primaryDigit;

  /// Two-letter label used in Palmer notation and UI (`UR`, `UL`, `LL`, `LR`).
  String get label => switch (this) {
        Quadrant.upperRight => 'UR',
        Quadrant.upperLeft => 'UL',
        Quadrant.lowerLeft => 'LL',
        Quadrant.lowerRight => 'LR',
      };

  static Quadrant? fromFdiDigit(int digit) {
    for (final q in Quadrant.values) {
      if (q.permanentDigit == digit || q.primaryDigit == digit) return q;
    }
    return null;
  }
}

/// Morphological tooth class.
enum ToothType { incisor, canine, premolar, molar }

/// A tooth identity. FDI (ISO 3950) two-digit notation is the canonical,
/// stored form; Universal (ADA) and Palmer are derived for display.
///
/// Supernumerary teeth are modelled as the nearest natural tooth plus a
/// [supernumeraryIndex] starting at 1 (FDI itself defines no supernumerary
/// code; this is the product convention, rendered as Universal 51-82 /
/// AS-TS on export).
@immutable
class ToothId implements Comparable<ToothId> {
  const ToothId({
    required this.dentition,
    required this.quadrant,
    required this.position,
    this.supernumeraryIndex = 0,
  })  : assert(position >= 1, 'position starts at 1 (central incisor)'),
        assert(supernumeraryIndex >= 0, 'supernumeraryIndex must be >= 0');

  final Dentition dentition;
  final Quadrant quadrant;

  /// 1 (central incisor) to 8 (third molar) for permanent teeth,
  /// 1 to 5 (second molar) for primary teeth.
  final int position;

  /// 0 for a natural tooth; 1, 2, ... for supernumerary teeth adjacent to it.
  final int supernumeraryIndex;

  bool get isSupernumerary => supernumeraryIndex > 0;
  bool get isPrimary => dentition == Dentition.primary;
  bool get isPermanent => dentition == Dentition.permanent;
  Arch get arch => quadrant.arch;
  Side get side => quadrant.side;

  /// Position of the tooth within the arch counted 1-16 from the patient's
  /// upper-right/lower-right, useful for laying teeth out left to right as the
  /// clinician sees them (patient's right appears on the viewer's left).
  int get archIndex {
    final n = dentition.positionsPerQuadrant;
    return side == Side.right ? n - position + 1 : n + position;
  }

  ToothType get type => switch (dentition) {
        Dentition.permanent => switch (position) {
            1 || 2 => ToothType.incisor,
            3 => ToothType.canine,
            4 || 5 => ToothType.premolar,
            _ => ToothType.molar,
          },
        Dentition.primary => switch (position) {
            1 || 2 => ToothType.incisor,
            3 => ToothType.canine,
            _ => ToothType.molar,
          },
      };

  bool get isAnterior =>
      type == ToothType.incisor || type == ToothType.canine;
  bool get isPosterior => !isAnterior;

  /// Typical number of roots, used for endo defaults and chart drawing.
  int get typicalRootCount {
    if (isAnterior) return 1;
    if (dentition == Dentition.primary) {
      return arch == Arch.upper ? 3 : 2;
    }
    if (type == ToothType.premolar) {
      return (arch == Arch.upper && position == 4) ? 2 : 1;
    }
    return arch == Arch.upper ? 3 : 2;
  }

  // ---------------------------------------------------------------------------
  // FDI / ISO 3950
  // ---------------------------------------------------------------------------

  /// Two-digit FDI code, e.g. `11`, `48`, `55`, `85`.
  String get fdi => '${quadrant.digitFor(dentition)}$position';

  /// FDI code plus a supernumerary suffix when relevant, e.g. `11+1`.
  String get storageKey =>
      isSupernumerary ? '$fdi+$supernumeraryIndex' : fdi;

  /// Parses `11`..`48`, `51`..`85`, optionally with a `+n` supernumerary
  /// suffix. Returns null for anything else.
  static ToothId? tryParse(String input) {
    final s = input.trim();
    final match = RegExp(r'^([1-8])([1-8])(?:\+(\d+))?$').firstMatch(s);
    if (match == null) return null;
    final qDigit = int.parse(match.group(1)!);
    final position = int.parse(match.group(2)!);
    final supernumerary =
        match.group(3) == null ? 0 : int.parse(match.group(3)!);
    final dentition = qDigit <= 4 ? Dentition.permanent : Dentition.primary;
    final quadrant = Quadrant.fromFdiDigit(qDigit);
    if (quadrant == null) return null;
    if (position > dentition.positionsPerQuadrant) return null;
    return ToothId(
      dentition: dentition,
      quadrant: quadrant,
      position: position,
      supernumeraryIndex: supernumerary,
    );
  }

  static ToothId parse(String input) {
    final id = tryParse(input);
    if (id == null) {
      throw FormatException('Not a valid FDI tooth code', input);
    }
    return id;
  }

  // ---------------------------------------------------------------------------
  // Universal (ADA)
  // ---------------------------------------------------------------------------

  /// Universal number 1-32 for permanent teeth. Supernumerary permanent teeth
  /// map to 51-82 (base + 50) as Open Dental and SNODENT do.
  int? get universalNumber {
    if (dentition != Dentition.permanent) return null;
    final base = switch (quadrant) {
      Quadrant.upperRight => 9 - position,
      Quadrant.upperLeft => 8 + position,
      Quadrant.lowerLeft => 25 - position,
      Quadrant.lowerRight => 24 + position,
    };
    return isSupernumerary ? base + 50 : base;
  }

  /// Universal letter A-T for primary teeth; supernumerary primary teeth get
  /// an `S` suffix (`AS`-`TS`).
  String? get universalLetter {
    if (dentition != Dentition.primary) return null;
    final index = switch (quadrant) {
      Quadrant.upperRight => 5 - position,
      Quadrant.upperLeft => 4 + position,
      Quadrant.lowerLeft => 15 - position,
      Quadrant.lowerRight => 14 + position,
    };
    final letter = String.fromCharCode('A'.codeUnitAt(0) + index);
    return isSupernumerary ? '${letter}S' : letter;
  }

  /// Universal designation as a string: `1`..`32`, `51`..`82`, `A`..`T`,
  /// `AS`..`TS`.
  String get universal => universalNumber?.toString() ?? universalLetter!;

  /// Parses a Universal designation (`1`-`32`, `51`-`82`, `A`-`T`, `AS`-`TS`).
  static ToothId? tryParseUniversal(String input) {
    final s = input.trim().toUpperCase();
    final number = int.tryParse(s);
    if (number != null) {
      var n = number;
      var supernumerary = 0;
      if (n >= 51 && n <= 82) {
        n -= 50;
        supernumerary = 1;
      }
      if (n < 1 || n > 32) return null;
      for (final q in Quadrant.values) {
        for (var p = 1; p <= 8; p++) {
          final candidate = ToothId(
            dentition: Dentition.permanent,
            quadrant: q,
            position: p,
            supernumeraryIndex: supernumerary,
          );
          if (candidate.universalNumber == number) return candidate;
        }
      }
      return null;
    }
    final letterMatch = RegExp(r'^([A-T])(S?)$').firstMatch(s);
    if (letterMatch == null) return null;
    final supernumerary = letterMatch.group(2)!.isEmpty ? 0 : 1;
    for (final q in Quadrant.values) {
      for (var p = 1; p <= 5; p++) {
        final candidate = ToothId(
          dentition: Dentition.primary,
          quadrant: q,
          position: p,
          supernumeraryIndex: supernumerary,
        );
        if (candidate.universalLetter == s) return candidate;
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Palmer (Zsigmondy-Palmer)
  // ---------------------------------------------------------------------------

  /// Palmer digit or letter without the quadrant glyph: `1`-`8` or `A`-`E`.
  String get palmerSymbol => dentition == Dentition.permanent
      ? '$position'
      : String.fromCharCode('A'.codeUnitAt(0) + position - 1);

  /// Palmer notation rendered with box-drawing glyphs standing in for the
  /// quadrant bracket, e.g. `1┘` (UR1), `└1` (UL1), `1┐` (LR1), `┌1` (LL1).
  String get palmer => switch (quadrant) {
        Quadrant.upperRight => '$palmerSymbol┘',
        Quadrant.upperLeft => '└$palmerSymbol',
        Quadrant.lowerRight => '$palmerSymbol┐',
        Quadrant.lowerLeft => '┌$palmerSymbol',
      };

  /// Palmer notation as plain text, e.g. `UR1`, `LL E`.
  String get palmerText => '${quadrant.label}$palmerSymbol';

  // ---------------------------------------------------------------------------
  // Enumeration helpers
  // ---------------------------------------------------------------------------

  /// All 32 permanent teeth in chart order (UR8..UR1, UL1..UL8, LL8..LL1,
  /// LR1..LR8 is *not* the order; this returns quadrant by quadrant in FDI
  /// order: 18..11, 21..28, 31..38, 41..48 which is the order FDI charts
  /// are read).
  static List<ToothId> permanentTeeth() => _all(Dentition.permanent);

  /// All 20 primary teeth in FDI chart order (55..51, 61..65, 71..75, 81..85).
  static List<ToothId> primaryTeeth() => _all(Dentition.primary);

  static List<ToothId> _all(Dentition dentition) {
    final n = dentition.positionsPerQuadrant;
    final out = <ToothId>[];
    for (final q in [Quadrant.upperRight, Quadrant.upperLeft]) {
      final positions = q.side == Side.right
          ? List.generate(n, (i) => n - i)
          : List.generate(n, (i) => i + 1);
      for (final p in positions) {
        out.add(ToothId(dentition: dentition, quadrant: q, position: p));
      }
    }
    for (final q in [Quadrant.lowerLeft, Quadrant.lowerRight]) {
      final positions = q.side == Side.left
          ? List.generate(n, (i) => n - i)
          : List.generate(n, (i) => i + 1);
      for (final p in positions) {
        out.add(ToothId(dentition: dentition, quadrant: q, position: p));
      }
    }
    return out;
  }

  /// Teeth of one arch laid out as the clinician views the patient:
  /// patient's right on the left of the list.
  static List<ToothId> archRow(Arch arch, Dentition dentition) {
    final n = dentition.positionsPerQuadrant;
    final right = arch == Arch.upper ? Quadrant.upperRight : Quadrant.lowerRight;
    final left = arch == Arch.upper ? Quadrant.upperLeft : Quadrant.lowerLeft;
    return [
      for (var p = n; p >= 1; p--)
        ToothId(dentition: dentition, quadrant: right, position: p),
      for (var p = 1; p <= n; p++)
        ToothId(dentition: dentition, quadrant: left, position: p),
    ];
  }

  /// The primary tooth occupying the same arch position as this permanent
  /// tooth (positions 1-5 only), or null.
  ToothId? get primaryPredecessor {
    if (dentition != Dentition.permanent || position > 5) return null;
    return ToothId(
      dentition: Dentition.primary,
      quadrant: quadrant,
      position: position,
    );
  }

  /// The permanent tooth that succeeds this primary tooth.
  ToothId? get permanentSuccessor {
    if (dentition != Dentition.primary) return null;
    return ToothId(
      dentition: Dentition.permanent,
      quadrant: quadrant,
      position: position,
    );
  }

  ToothId copyWith({
    Dentition? dentition,
    Quadrant? quadrant,
    int? position,
    int? supernumeraryIndex,
  }) =>
      ToothId(
        dentition: dentition ?? this.dentition,
        quadrant: quadrant ?? this.quadrant,
        position: position ?? this.position,
        supernumeraryIndex: supernumeraryIndex ?? this.supernumeraryIndex,
      );

  @override
  int compareTo(ToothId other) {
    if (dentition != other.dentition) {
      return dentition.index.compareTo(other.dentition.index);
    }
    if (quadrant != other.quadrant) {
      return quadrant.permanentDigit.compareTo(other.quadrant.permanentDigit);
    }
    if (position != other.position) return position.compareTo(other.position);
    return supernumeraryIndex.compareTo(other.supernumeraryIndex);
  }

  @override
  bool operator ==(Object other) =>
      other is ToothId &&
      other.dentition == dentition &&
      other.quadrant == quadrant &&
      other.position == position &&
      other.supernumeraryIndex == supernumeraryIndex;

  @override
  int get hashCode =>
      Object.hash(dentition, quadrant, position, supernumeraryIndex);

  @override
  String toString() => 'ToothId($storageKey)';
}
