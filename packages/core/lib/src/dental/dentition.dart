import 'tooth_id.dart';

/// Lifecycle state of a tooth at one position. History is kept as a list of
/// dated state records; this enum is the vocabulary.
enum ToothState {
  /// Erupted and present (default for permanent teeth after eruption age).
  present,

  /// Not yet erupted (developing, or a third molar that may never erupt).
  unerupted,

  /// Partially through the gingiva.
  erupting,

  /// Erupted but impacted / failed to reach occlusion.
  impacted,

  /// Clinically missing with no record of extraction (congenital, unknown).
  missing,

  /// Removed by extraction; the record points to the procedure.
  extracted,

  /// Primary tooth lost naturally.
  exfoliated,

  /// Primary tooth retained past its usual shedding age.
  retainedPrimary,

  /// Position holds an implant fixture instead of a natural tooth.
  implant,

  /// Extra tooth (see ToothId.supernumeraryIndex).
  supernumerary;

  /// Whether a tooth in this state is drawn as a solid tooth on the chart.
  bool get isDrawnPresent =>
      this == ToothState.present ||
      this == ToothState.erupting ||
      this == ToothState.impacted ||
      this == ToothState.retainedPrimary ||
      this == ToothState.supernumerary;

  bool get isAbsent =>
      this == ToothState.missing ||
      this == ToothState.extracted ||
      this == ToothState.exfoliated;
}

/// Typical eruption and shedding ages. Values are population midpoints used
/// only for defaulting a new chart; the clinician overrides per tooth.
class EruptionSchedule {
  const EruptionSchedule._();

  /// Typical eruption age in years for a permanent tooth.
  static double permanentEruptionYears(ToothId tooth) {
    assert(tooth.isPermanent);
    final upper = tooth.arch == Arch.upper;
    return switch (tooth.position) {
      1 => upper ? 7.5 : 6.5,
      2 => upper ? 8.5 : 7.5,
      3 => upper ? 11.5 : 10.0,
      4 => upper ? 10.5 : 10.5,
      5 => upper ? 11.0 : 11.5,
      6 => 6.5,
      7 => 12.5,
      _ => 19.0, // third molars 17-21, often never
    };
  }

  /// Typical eruption age in months for a primary tooth.
  static double primaryEruptionMonths(ToothId tooth) {
    assert(tooth.isPrimary);
    final upper = tooth.arch == Arch.upper;
    return switch (tooth.position) {
      1 => upper ? 10.0 : 8.0,
      2 => upper ? 11.0 : 13.0,
      3 => 19.0,
      4 => 15.0,
      _ => 27.0,
    };
  }

  /// Typical shedding (exfoliation) age in years for a primary tooth.
  static double primarySheddingYears(ToothId tooth) {
    assert(tooth.isPrimary);
    final upper = tooth.arch == Arch.upper;
    return switch (tooth.position) {
      1 => upper ? 7.0 : 6.5,
      2 => upper ? 8.0 : 7.5,
      3 => upper ? 11.0 : 10.0,
      4 => 10.0,
      _ => 11.0,
    };
  }
}

/// Which dentition a chart should show by default for a patient age.
enum DentitionStage {
  primaryOnly,
  mixed,
  permanentOnly;

  static DentitionStage forAgeYears(double ageYears) {
    if (ageYears < 5.5) return DentitionStage.primaryOnly;
    if (ageYears < 12.5) return DentitionStage.mixed;
    return DentitionStage.permanentOnly;
  }
}

/// Default tooth states for a new chart given the patient's age. Every
/// returned entry is a suggestion the clinician confirms or overrides.
///
/// Third molars are left [ToothState.unerupted] until age 21 because many
/// never erupt; marking them present by default would mis-chart most adults.
Map<ToothId, ToothState> defaultToothStates({required double ageYears}) {
  final out = <ToothId, ToothState>{};
  final ageMonths = ageYears * 12;
  for (final tooth in ToothId.primaryTeeth()) {
    final erupt = EruptionSchedule.primaryEruptionMonths(tooth);
    final shed = EruptionSchedule.primarySheddingYears(tooth);
    if (ageYears >= shed) {
      out[tooth] = ToothState.exfoliated;
    } else if (ageMonths >= erupt) {
      out[tooth] = ToothState.present;
    } else {
      out[tooth] = ToothState.unerupted;
    }
  }
  for (final tooth in ToothId.permanentTeeth()) {
    final erupt = EruptionSchedule.permanentEruptionYears(tooth);
    if (tooth.position == 8) {
      out[tooth] = ageYears >= 21 ? ToothState.present : ToothState.unerupted;
    } else if (ageYears >= erupt) {
      out[tooth] = ToothState.present;
    } else if (ageYears >= erupt - 0.75) {
      out[tooth] = ToothState.erupting;
    } else {
      out[tooth] = ToothState.unerupted;
    }
  }
  return out;
}

/// Teeth that should be visible on a chart for the given states: every tooth
/// whose state is drawn present, plus absent permanent teeth (drawn as gaps)
/// so the position stays visible. Unerupted teeth are hidden unless
/// [showUnerupted] is set.
List<ToothId> visibleTeeth(
  Map<ToothId, ToothState> states, {
  bool showUnerupted = false,
}) {
  final out = <ToothId>[];
  for (final entry in states.entries) {
    final state = entry.value;
    if (state.isDrawnPresent) {
      out.add(entry.key);
    } else if (state == ToothState.unerupted && showUnerupted) {
      out.add(entry.key);
    } else if (state.isAbsent && entry.key.isPermanent) {
      out.add(entry.key);
    } else if (state == ToothState.implant) {
      out.add(entry.key);
    }
  }
  out.sort();
  return out;
}
