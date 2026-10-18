import 'package:meta/meta.dart';

import 'json_support.dart';

/// Severity of a recorded allergy.
enum AllergySeverity { mild, moderate, severe, unknown }

/// Route of an antiresorptive drug; intravenous carries the higher MRONJ
/// risk.
enum AntiresorptiveRoute { oral, intravenous }

/// Smoking status.
enum SmokingStatus { never, former, current }

/// Medication-related osteonecrosis of the jaw risk tier.
enum MronjRisk { none, low, higher }

/// Red flags surfaced on the chart header before any procedure.
enum RedFlag {
  anticoagulant,
  mronj,
  uncontrolledDiabetes,
  pregnancy,
  cardiac,
  bleedingDisorder,
  allergyLocalAnaesthetic,
  allergyPenicillin,
  steroids,
  epilepsy,
}

/// One allergy entry in a medical history.
@immutable
class AllergyEntry {
  /// Creates an allergy entry.
  const AllergyEntry({
    required this.substance,
    this.reaction,
    this.severity = AllergySeverity.unknown,
    this.allergyGroup,
  });

  /// Substance as told by the patient (`Amoxicillin`).
  final String substance;

  /// Reaction described (`rash`, `anaphylaxis`).
  final String? reaction;

  /// Severity.
  final AllergySeverity severity;

  /// Normalised group used for prescribing checks: `penicillin`, `sulfa`,
  /// `nsaid`, `localAnaesthetic`, `latex`.
  final String? allergyGroup;

  /// Returns a copy with the given fields replaced.
  AllergyEntry copyWith({
    String? substance,
    String? reaction,
    AllergySeverity? severity,
    String? allergyGroup,
  }) => AllergyEntry(
    substance: substance ?? this.substance,
    reaction: reaction ?? this.reaction,
    severity: severity ?? this.severity,
    allergyGroup: allergyGroup ?? this.allergyGroup,
  );

  /// JSON form.
  Map<String, Object?> toJson() => {
    'substance': substance,
    'reaction': reaction,
    'severity': severity.name,
    'allergyGroup': allergyGroup,
  };

  /// Parses the JSON form.
  factory AllergyEntry.fromJson(Map<String, Object?> json) => AllergyEntry(
    substance: json['substance'] as String,
    reaction: json['reaction'] as String?,
    severity: enumFromJson(AllergySeverity.values, json['severity']),
    allergyGroup: json['allergyGroup'] as String?,
  );
}

/// Structured medical history taken at a point in time. Append-only: a new
/// row per update so the risk picture at any past visit is reconstructible.
@immutable
class MedicalHistory {
  /// Creates a medical history snapshot.
  const MedicalHistory({
    required this.id,
    required this.clinicId,
    required this.patientId,
    required this.recordedAt,
    required this.recordedBy,
    this.allergies = const [],
    this.medications = const [],
    this.diabetes = false,
    this.hba1c,
    this.hypertension = false,
    this.cardiacCondition,
    this.bleedingDisorder = false,
    this.anticoagulant,
    this.antiresorptive,
    this.antiresorptiveRoute,
    this.antiresorptiveYears,
    this.oncologyTreatment = false,
    this.pregnant = false,
    this.pregnancyTrimester,
    this.asthma = false,
    this.epilepsy = false,
    this.thyroid = false,
    this.steroids = false,
    this.hepatitis = false,
    this.hiv = false,
    this.smoking = SmokingStatus.never,
    this.alcohol = false,
    this.otherNotes,
    required this.createdAt,
  });

  /// UUID v4.
  final String id;

  /// Owning clinic.
  final String clinicId;

  /// Patient.
  final String patientId;

  /// When the history was taken.
  final DateTime recordedAt;

  /// Member who took it.
  final String recordedBy;

  /// Allergies.
  final List<AllergyEntry> allergies;

  /// Current medications (free text per drug).
  final List<String> medications;

  /// Diabetic.
  final bool diabetes;

  /// Latest HbA1c percent, if known.
  final num? hba1c;

  /// Hypertensive.
  final bool hypertension;

  /// Cardiac condition description (null = none).
  final String? cardiacCondition;

  /// Known bleeding disorder.
  final bool bleedingDisorder;

  /// Anticoagulant / antiplatelet drug name (null = none).
  final String? anticoagulant;

  /// Antiresorptive drug name (bisphosphonate, denosumab; null = none).
  final String? antiresorptive;

  /// Route of the antiresorptive.
  final AntiresorptiveRoute? antiresorptiveRoute;

  /// Years on the antiresorptive.
  final num? antiresorptiveYears;

  /// Current or past oncology treatment (chemo / radiotherapy / antiangiogenic).
  final bool oncologyTreatment;

  /// Pregnant.
  final bool pregnant;

  /// Trimester 1-3 when pregnant.
  final int? pregnancyTrimester;

  /// Asthmatic.
  final bool asthma;

  /// Epileptic.
  final bool epilepsy;

  /// Thyroid disorder.
  final bool thyroid;

  /// Long-term steroid use.
  final bool steroids;

  /// Hepatitis B / C.
  final bool hepatitis;

  /// HIV positive.
  final bool hiv;

  /// Smoking status.
  final SmokingStatus smoking;

  /// Regular alcohol use.
  final bool alcohol;

  /// Anything else.
  final String? otherNotes;

  /// Row creation time.
  final DateTime createdAt;

  /// MRONJ risk tier: none without an antiresorptive; higher for intravenous
  /// route, oncology treatment or more than five years oral; else low.
  MronjRisk get mronjRisk {
    if (antiresorptive == null || antiresorptive!.isEmpty) {
      return MronjRisk.none;
    }
    if (antiresorptiveRoute == AntiresorptiveRoute.intravenous ||
        oncologyTreatment ||
        (antiresorptiveYears ?? 0) > 5) {
      return MronjRisk.higher;
    }
    return MronjRisk.low;
  }

  /// Whether any allergy belongs to [group] (case-insensitive).
  bool hasAllergyGroup(String group) => allergies.any(
    (a) => a.allergyGroup?.toLowerCase() == group.toLowerCase(),
  );

  /// Red flags derived from the structured fields, in display order.
  List<RedFlag> get redFlags {
    final out = <RedFlag>[];
    if (anticoagulant != null && anticoagulant!.isNotEmpty) {
      out.add(RedFlag.anticoagulant);
    }
    if (mronjRisk != MronjRisk.none) out.add(RedFlag.mronj);
    if (diabetes && (hba1c ?? 0) >= 8) out.add(RedFlag.uncontrolledDiabetes);
    if (pregnant) out.add(RedFlag.pregnancy);
    if (cardiacCondition != null && cardiacCondition!.isNotEmpty) {
      out.add(RedFlag.cardiac);
    }
    if (bleedingDisorder) out.add(RedFlag.bleedingDisorder);
    if (hasAllergyGroup('localAnaesthetic')) {
      out.add(RedFlag.allergyLocalAnaesthetic);
    }
    if (hasAllergyGroup('penicillin')) out.add(RedFlag.allergyPenicillin);
    if (steroids) out.add(RedFlag.steroids);
    if (epilepsy) out.add(RedFlag.epilepsy);
    return out;
  }

  /// Returns a copy with the given fields replaced.
  MedicalHistory copyWith({
    List<AllergyEntry>? allergies,
    List<String>? medications,
    bool? diabetes,
    num? hba1c,
    bool? hypertension,
    String? cardiacCondition,
    bool? bleedingDisorder,
    String? anticoagulant,
    String? antiresorptive,
    AntiresorptiveRoute? antiresorptiveRoute,
    num? antiresorptiveYears,
    bool? oncologyTreatment,
    bool? pregnant,
    int? pregnancyTrimester,
    bool? asthma,
    bool? epilepsy,
    bool? thyroid,
    bool? steroids,
    bool? hepatitis,
    bool? hiv,
    SmokingStatus? smoking,
    bool? alcohol,
    String? otherNotes,
  }) => MedicalHistory(
    id: id,
    clinicId: clinicId,
    patientId: patientId,
    recordedAt: recordedAt,
    recordedBy: recordedBy,
    allergies: allergies ?? this.allergies,
    medications: medications ?? this.medications,
    diabetes: diabetes ?? this.diabetes,
    hba1c: hba1c ?? this.hba1c,
    hypertension: hypertension ?? this.hypertension,
    cardiacCondition: cardiacCondition ?? this.cardiacCondition,
    bleedingDisorder: bleedingDisorder ?? this.bleedingDisorder,
    anticoagulant: anticoagulant ?? this.anticoagulant,
    antiresorptive: antiresorptive ?? this.antiresorptive,
    antiresorptiveRoute: antiresorptiveRoute ?? this.antiresorptiveRoute,
    antiresorptiveYears: antiresorptiveYears ?? this.antiresorptiveYears,
    oncologyTreatment: oncologyTreatment ?? this.oncologyTreatment,
    pregnant: pregnant ?? this.pregnant,
    pregnancyTrimester: pregnancyTrimester ?? this.pregnancyTrimester,
    asthma: asthma ?? this.asthma,
    epilepsy: epilepsy ?? this.epilepsy,
    thyroid: thyroid ?? this.thyroid,
    steroids: steroids ?? this.steroids,
    hepatitis: hepatitis ?? this.hepatitis,
    hiv: hiv ?? this.hiv,
    smoking: smoking ?? this.smoking,
    alcohol: alcohol ?? this.alcohol,
    otherNotes: otherNotes ?? this.otherNotes,
    createdAt: createdAt,
  );

  /// JSON form.
  Map<String, Object?> toJson() => {
    'id': id,
    'clinicId': clinicId,
    'patientId': patientId,
    'recordedAt': dateToJson(recordedAt),
    'recordedBy': recordedBy,
    'allergies': allergies.map((a) => a.toJson()).toList(),
    'medications': medications,
    'diabetes': diabetes,
    'hba1c': hba1c,
    'hypertension': hypertension,
    'cardiacCondition': cardiacCondition,
    'bleedingDisorder': bleedingDisorder,
    'anticoagulant': anticoagulant,
    'antiresorptive': antiresorptive,
    'antiresorptiveRoute': antiresorptiveRoute?.name,
    'antiresorptiveYears': antiresorptiveYears,
    'oncologyTreatment': oncologyTreatment,
    'pregnant': pregnant,
    'pregnancyTrimester': pregnancyTrimester,
    'asthma': asthma,
    'epilepsy': epilepsy,
    'thyroid': thyroid,
    'steroids': steroids,
    'hepatitis': hepatitis,
    'hiv': hiv,
    'smoking': smoking.name,
    'alcohol': alcohol,
    'otherNotes': otherNotes,
    'createdAt': dateToJson(createdAt),
  };

  /// Parses the JSON form.
  factory MedicalHistory.fromJson(Map<String, Object?> json) => MedicalHistory(
    id: json['id'] as String,
    clinicId: json['clinicId'] as String,
    patientId: json['patientId'] as String,
    recordedAt: dateFromJson(json['recordedAt']),
    recordedBy: json['recordedBy'] as String,
    allergies:
        (json['allergies'] as List?)
            ?.map(
              (e) => AllergyEntry.fromJson((e as Map).cast<String, Object?>()),
            )
            .toList() ??
        const [],
    medications: stringListFromJson(json['medications']),
    diabetes: json['diabetes'] as bool? ?? false,
    hba1c: json['hba1c'] as num?,
    hypertension: json['hypertension'] as bool? ?? false,
    cardiacCondition: json['cardiacCondition'] as String?,
    bleedingDisorder: json['bleedingDisorder'] as bool? ?? false,
    anticoagulant: json['anticoagulant'] as String?,
    antiresorptive: json['antiresorptive'] as String?,
    antiresorptiveRoute: enumFromJsonOrNull(
      AntiresorptiveRoute.values,
      json['antiresorptiveRoute'],
    ),
    antiresorptiveYears: json['antiresorptiveYears'] as num?,
    oncologyTreatment: json['oncologyTreatment'] as bool? ?? false,
    pregnant: json['pregnant'] as bool? ?? false,
    pregnancyTrimester: json['pregnancyTrimester'] as int?,
    asthma: json['asthma'] as bool? ?? false,
    epilepsy: json['epilepsy'] as bool? ?? false,
    thyroid: json['thyroid'] as bool? ?? false,
    steroids: json['steroids'] as bool? ?? false,
    hepatitis: json['hepatitis'] as bool? ?? false,
    hiv: json['hiv'] as bool? ?? false,
    smoking:
        enumFromJsonOrNull(SmokingStatus.values, json['smoking']) ??
        SmokingStatus.never,
    alcohol: json['alcohol'] as bool? ?? false,
    otherNotes: json['otherNotes'] as String?,
    createdAt: dateFromJson(json['createdAt']),
  );
}
