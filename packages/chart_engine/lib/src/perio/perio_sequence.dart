import 'package:ampdent_core/ampdent_core.dart';
import 'package:flutter/foundation.dart';

/// Which side of the arch a perio grid shows: three facial (buccal) sites or
/// three lingual (palatal) sites per tooth.
enum PerioAspect {
  facial,
  lingual;

  /// The three sites on this aspect in mesial-to-distal order.
  List<PerioSite> get sites => this == PerioAspect.facial
      ? const [PerioSite.mesioBuccal, PerioSite.buccal, PerioSite.distoBuccal]
      : const [
          PerioSite.mesioLingual,
          PerioSite.lingual,
          PerioSite.distoLingual,
        ];

  /// Display label.
  String get label => this == PerioAspect.facial ? 'Facial' : 'Lingual';

  /// Whether [site] belongs to this aspect.
  bool contains(PerioSite site) => site.facial == (this == PerioAspect.facial);
}

/// Sites of [tooth] on [aspect] ordered left to right as the clinician views
/// the chart: distal first for right-side teeth, mesial first for left-side
/// teeth (mesial always faces the midline).
List<PerioSite> sitesInViewerOrder(ToothId tooth, PerioAspect aspect) {
  final sites = aspect.sites;
  return tooth.side == Side.right ? sites.reversed.toList() : sites;
}

/// Horizontal order key of a tooth in its arch row (viewer's left = 0).
/// Primary teeth sort just after the permanent tooth they precede.
double perioColumnOrder(ToothId tooth) {
  final anchor = tooth.isPrimary ? tooth.permanentSuccessor! : tooth;
  return anchor.archIndex + (tooth.isPrimary ? 0.5 : 0);
}

/// The auto-advance entry order for one arch and aspect: every present tooth
/// of [arch] in viewer order, three sites each in viewer order.
List<(ToothId, PerioSite)> perioEntrySequence(
  Arch arch,
  PerioAspect aspect,
  List<ToothId> present,
) {
  final teeth = present.where((t) => t.arch == arch).toList()
    ..sort((a, b) => perioColumnOrder(a).compareTo(perioColumnOrder(b)));
  return [
    for (final tooth in teeth)
      for (final site in sitesInViewerOrder(tooth, aspect)) (tooth, site),
  ];
}

/// Immutable position inside an entry sequence.
@immutable
class PerioEntryCursor {
  const PerioEntryCursor(this.sequence, [this.index = 0]);

  final List<(ToothId, PerioSite)> sequence;
  final int index;

  /// The cell at the cursor, or null when the sequence is exhausted.
  (ToothId, PerioSite)? get current =>
      index >= 0 && index < sequence.length ? sequence[index] : null;

  /// True once every site has been visited.
  bool get isAtEnd => index >= sequence.length;

  /// Cursor advanced by one site (clamped one past the end).
  PerioEntryCursor next() =>
      PerioEntryCursor(sequence, (index + 1).clamp(0, sequence.length));

  /// Cursor moved back one site (clamped at zero).
  PerioEntryCursor previous() =>
      PerioEntryCursor(sequence, (index - 1).clamp(0, sequence.length));

  /// Cursor moved to [cell], or unchanged when the cell is not in the sequence.
  PerioEntryCursor jumpTo((ToothId, PerioSite) cell) {
    final i = sequence.indexWhere((e) => e.$1 == cell.$1 && e.$2 == cell.$2);
    return i < 0 ? this : PerioEntryCursor(sequence, i);
  }
}
