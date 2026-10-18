/// Lifecycle of a procedure line. Modelled on the status set every mature
/// dental PMS converges on; rows are never deleted, only moved to [deleted].
enum ProcedureStatus {
  /// Treatment-planned on the active plan.
  planned,

  /// Planned on an inactive / alternative plan; hidden from the chart.
  plannedInactive,

  /// Patient accepted the plan line (signed or OTP).
  accepted,

  /// Started but not finished (multi-sitting work such as RCT 1/3).
  inProgress,

  /// Completed by this clinic.
  completed,

  /// Pre-existing work done by this clinic's provider before charting began.
  existingCurrentProvider,

  /// Pre-existing work done elsewhere.
  existingOtherProvider,

  /// Referred out to a specialist.
  referred,

  /// A condition / finding recorded through the procedure flow.
  condition,

  /// Soft-deleted; kept for audit.
  deleted;

  bool get isPlanned => this == planned || this == plannedInactive || this == accepted;
  bool get isExisting => this == existingCurrentProvider || this == existingOtherProvider;
  bool get isDone => this == completed || isExisting;
  bool get isBillable => this == completed || this == inProgress;
  bool get showsOnChart => this != plannedInactive && this != deleted && this != referred;
}

/// Status of a finding (condition) on a tooth or surface.
enum FindingStatus { active, resolved, existingPrior, deleted }

/// ICDAS II caries detection codes (0-6).
enum IcdasCode {
  sound(0, 'Sound'),
  firstVisualChange(1, 'First visual change in enamel'),
  distinctVisualChange(2, 'Distinct visual change in enamel'),
  enamelBreakdown(3, 'Localised enamel breakdown'),
  dentineShadow(4, 'Underlying dark shadow from dentine'),
  distinctCavity(5, 'Distinct cavity with visible dentine'),
  extensiveCavity(6, 'Extensive distinct cavity');

  const IcdasCode(this.code, this.description);
  final int code;
  final String description;

  static IcdasCode fromCode(int code) =>
      IcdasCode.values.firstWhere((c) => c.code == code);
}

/// Tooth mobility, Miller grades 0-3.
enum MobilityGrade {
  none(0),
  grade1(1),
  grade2(2),
  grade3(3);

  const MobilityGrade(this.value);
  final int value;
}

/// Furcation involvement stored 0-3 (Hamp); displayed per clinic preference
/// as Glickman I-IV via [glickmanLabel].
enum FurcationGrade {
  none(0),
  grade1(1),
  grade2(2),
  grade3(3);

  const FurcationGrade(this.value);
  final int value;

  String get glickmanLabel => switch (this) {
        FurcationGrade.none => '-',
        FurcationGrade.grade1 => 'I',
        FurcationGrade.grade2 => 'II',
        FurcationGrade.grade3 => 'III/IV',
      };
}

/// The six periodontal probing sites per tooth.
enum PerioSite {
  mesioBuccal('MB', facial: true),
  buccal('B', facial: true),
  distoBuccal('DB', facial: true),
  mesioLingual('ML', facial: false),
  lingual('L', facial: false),
  distoLingual('DL', facial: false);

  const PerioSite(this.code, {required this.facial});
  final String code;
  final bool facial;
}

/// Measurement types recorded per site (or per tooth for mobility and
/// furcation). Gingival margin is a signed integer in mm relative to the CEJ:
/// negative = recession (margin apical to CEJ), positive = margin coronal to
/// the CEJ. Clinical attachment loss is derived: CAL = PD - GM.
enum PerioMeasurementType {
  probingDepth,
  gingivalMargin,
  bleedingOnProbing,
  suppuration,
  plaque,
  calculus,
  mucogingivalJunction,
  furcation,
  mobility;

  bool get isPerSite => this != furcation && this != mobility;
  bool get isBoolean => this == bleedingOnProbing || this == suppuration || this == plaque || this == calculus;
}

/// UK BSP Basic Periodontal Examination codes per sextant. Code 3 unlocks a
/// six-point chart for that sextant, 4 unlocks full-mouth charting.
enum BpeCode {
  code0('0'),
  code1('1'),
  code2('2'),
  code3('3'),
  code4('4'),
  furcation('*');

  const BpeCode(this.label);
  final String label;

  bool get requiresSextantChart => this == code3;
  bool get requiresFullMouthChart => this == code4;
}

/// 2017 AAP/EFP periodontitis staging and grading (clinician-entered).
enum PeriodontitisStage { stage1, stage2, stage3, stage4 }

enum PeriodontitisGrade { gradeA, gradeB, gradeC }

/// Indian Drugs and Cosmetics Rules schedule tag for a drug master entry.
enum DrugSchedule {
  /// Over the counter / not scheduled.
  otc,

  /// Schedule H: prescription only.
  h,

  /// Schedule H1: prescription only plus a retailer register (antibiotics of
  /// concern, tramadol, benzodiazepines...).
  h1,

  /// Schedule X: narcotics and psychotropics with stricter controls.
  x,

  /// Schedule G: caution label, prescription recommended.
  g;

  bool get requiresPrescription => this != otc;
  bool get blockedForRemotePrescribing => this == x;
}

/// Recall / review intervals per NICE CG19 menu (3-24 months).
enum RecallInterval {
  threeMonths(3),
  sixMonths(6),
  nineMonths(9),
  twelveMonths(12),
  fifteenMonths(15),
  eighteenMonths(18),
  twentyOneMonths(21),
  twentyFourMonths(24);

  const RecallInterval(this.months);
  final int months;
}

/// Role of a clinic member; drives permissions and fee-share rules.
enum ClinicRole {
  ownerDentist,
  associateDentist,
  visitingSpecialist,
  receptionist,
  assistant,
  accountant,
  lab;

  bool get isClinician =>
      this == ownerDentist || this == associateDentist || this == visitingSpecialist;
  bool get canSeeLedger =>
      this == ownerDentist || this == receptionist || this == accountant;
}

/// Appointment lifecycle.
enum AppointmentStatus {
  scheduled,
  confirmed,
  arrived,
  inChair,
  completed,
  cancelled,
  noShow,
  rescheduled;

  bool get occupiesChair =>
      this == scheduled || this == confirmed || this == arrived || this == inChair;
}

/// Lab case workflow.
enum LabCaseStatus {
  created,
  sent,
  received,
  qualityChecked,
  fitted,
  remakeRequested,
  cancelled;

  bool get isOpen => this != fitted && this != cancelled;
}

/// Treatment plan lifecycle (one active plan per patient).
enum TreatmentPlanStatus {
  active,
  inactive,
  saved,
  accepted,
  completed,
  superseded,
}

/// Patient sex as recorded for prescriptions (PCI regulation requires it).
enum Sex { male, female, other, unspecified }
