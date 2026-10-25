import 'package:meta/meta.dart';

import 'clinical_enums.dart';
import 'tooth_id.dart';

/// Measurements at one probing site of one tooth in one exam. Depths are in
/// whole millimetres. [gingivalMargin] is signed relative to the CEJ
/// (negative = recession).
@immutable
class PerioSiteReading {
  const PerioSiteReading({
    required this.tooth,
    required this.site,
    this.probingDepth,
    this.gingivalMargin,
    this.bleeding = false,
    this.suppuration = false,
    this.plaque = false,
    this.calculus = false,
    this.mucogingivalJunction,
  });

  final ToothId tooth;
  final PerioSite site;
  final int? probingDepth;
  final int? gingivalMargin;
  final bool bleeding;
  final bool suppuration;
  final bool plaque;
  final bool calculus;

  /// Distance from the gingival margin to the mucogingival junction, mm.
  final int? mucogingivalJunction;

  /// Clinical attachment loss = probing depth - gingival margin, so recession
  /// (negative margin) adds to the loss. Null when either value is missing.
  int? get clinicalAttachmentLoss {
    final pd = probingDepth;
    final gm = gingivalMargin;
    if (pd == null || gm == null) return null;
    return pd - gm;
  }

  /// Recession in mm (0 when the margin is at or above the CEJ).
  int? get recession {
    final gm = gingivalMargin;
    if (gm == null) return null;
    return gm < 0 ? -gm : 0;
  }

  /// Width of keratinised tissue approximated as MGJ distance minus recession
  /// is not derivable without the CEJ-to-MGJ distance; exposed as MGJ only.
  bool get hasAnyValue =>
      probingDepth != null ||
      gingivalMargin != null ||
      bleeding ||
      suppuration ||
      plaque ||
      calculus ||
      mucogingivalJunction != null;

  PerioSiteReading copyWith({
    int? probingDepth,
    int? gingivalMargin,
    bool? bleeding,
    bool? suppuration,
    bool? plaque,
    bool? calculus,
    int? mucogingivalJunction,
  }) => PerioSiteReading(
    tooth: tooth,
    site: site,
    probingDepth: probingDepth ?? this.probingDepth,
    gingivalMargin: gingivalMargin ?? this.gingivalMargin,
    bleeding: bleeding ?? this.bleeding,
    suppuration: suppuration ?? this.suppuration,
    plaque: plaque ?? this.plaque,
    calculus: calculus ?? this.calculus,
    mucogingivalJunction: mucogingivalJunction ?? this.mucogingivalJunction,
  );
}

/// Per-tooth values that are not site-specific.
@immutable
class PerioToothReading {
  const PerioToothReading({
    required this.tooth,
    this.mobility,
    this.furcation,
    this.skipped = false,
    this.isImplant = false,
  });

  final ToothId tooth;
  final MobilityGrade? mobility;
  final FurcationGrade? furcation;

  /// Tooth excluded from this exam (missing, unerupted...).
  final bool skipped;

  /// Implants are probed but never given a BPE score.
  final bool isImplant;
}

/// Whole-mouth summary statistics derived from a set of readings. Nothing in
/// here is stored; recompute from the readings.
@immutable
class PerioSummary {
  const PerioSummary({
    required this.sitesRecorded,
    required this.sitesBleeding,
    required this.sitesWithPlaque,
    required this.sitesPd4Plus,
    required this.sitesPd6Plus,
    required this.maxProbingDepth,
    required this.maxClinicalAttachmentLoss,
    required this.meanProbingDepth,
  });

  factory PerioSummary.from(Iterable<PerioSiteReading> readings) {
    var recorded = 0;
    var bleeding = 0;
    var plaque = 0;
    var pd4 = 0;
    var pd6 = 0;
    var maxPd = 0;
    var maxCal = 0;
    var pdSum = 0;
    var pdCount = 0;
    for (final r in readings) {
      if (!r.hasAnyValue) continue;
      recorded++;
      if (r.bleeding) bleeding++;
      if (r.plaque) plaque++;
      final pd = r.probingDepth;
      if (pd != null) {
        pdSum += pd;
        pdCount++;
        if (pd >= 4) pd4++;
        if (pd >= 6) pd6++;
        if (pd > maxPd) maxPd = pd;
      }
      final cal = r.clinicalAttachmentLoss;
      if (cal != null && cal > maxCal) maxCal = cal;
    }
    return PerioSummary(
      sitesRecorded: recorded,
      sitesBleeding: bleeding,
      sitesWithPlaque: plaque,
      sitesPd4Plus: pd4,
      sitesPd6Plus: pd6,
      maxProbingDepth: maxPd,
      maxClinicalAttachmentLoss: maxCal,
      meanProbingDepth: pdCount == 0 ? 0 : pdSum / pdCount,
    );
  }

  final int sitesRecorded;
  final int sitesBleeding;
  final int sitesWithPlaque;
  final int sitesPd4Plus;
  final int sitesPd6Plus;
  final int maxProbingDepth;
  final int maxClinicalAttachmentLoss;
  final double meanProbingDepth;

  /// Bleeding on probing as a percentage of recorded sites (0-100).
  double get bleedingPercent =>
      sitesRecorded == 0 ? 0 : sitesBleeding * 100 / sitesRecorded;

  double get plaquePercent =>
      sitesRecorded == 0 ? 0 : sitesWithPlaque * 100 / sitesRecorded;

  /// Suggested 2017 AAP/EFP stage from interdental CAL alone. The clinician
  /// confirms it, because staging also needs radiographic bone loss, tooth
  /// loss and complexity factors that the chart does not hold.
  PeriodontitisStage? get suggestedStage {
    if (maxClinicalAttachmentLoss <= 0) return null;
    if (maxClinicalAttachmentLoss <= 2) return PeriodontitisStage.stage1;
    if (maxClinicalAttachmentLoss <= 4) return PeriodontitisStage.stage2;
    // Stage III vs IV needs tooth-loss and function data; suggest III.
    return PeriodontitisStage.stage3;
  }
}

/// Returns the BPE sextant code implied by a set of site readings for that
/// sextant: 4 if any PD > 5.5 mm (>= 6 recorded as whole mm), 3 if any PD in
/// 3.5-5.5 (4-5), 2 if calculus or overhang recorded, 1 if bleeding only,
/// else 0. Furcation is reported separately by the caller as `*`.
BpeCode bpeCodeFor(Iterable<PerioSiteReading> sextantReadings) {
  var anyBleeding = false;
  var anyCalculus = false;
  var code = BpeCode.code0;
  for (final r in sextantReadings) {
    final pd = r.probingDepth;
    if (pd != null && pd >= 6) return BpeCode.code4;
    if (pd != null && pd >= 4) code = BpeCode.code3;
    if (r.calculus) anyCalculus = true;
    if (r.bleeding) anyBleeding = true;
  }
  if (code == BpeCode.code3) return code;
  if (anyCalculus) return BpeCode.code2;
  if (anyBleeding) return BpeCode.code1;
  return BpeCode.code0;
}
