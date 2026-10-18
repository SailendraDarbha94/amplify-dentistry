/// Dental drug master seed with Indian Drugs and Cosmetics Rules schedule
/// tags and schedule history.
library;

import 'package:ampdent_core/ampdent_core.dart';

part 'drugs/drugs_analgesic.dart';
part 'drugs/drugs_antimicrobial.dart';
part 'drugs/drugs_other.dart';

/// One seed row of the drug master.
class DrugSeed {
  /// Creates a drug seed. [scheduleEffectiveFromIso] is an ISO-8601 date
  /// (kept as a string so the seed list stays `const`); before that date the
  /// drug is treated as [previousSchedule].
  const DrugSeed({
    required this.code,
    required this.genericName,
    required this.brandNames,
    required this.strength,
    required this.form,
    required this.schedule,
    required this.category,
    required this.defaultDose,
    required this.defaultFrequency,
    required this.defaultDurationDays,
    required this.route,
    this.scheduleEffectiveFromIso,
    this.previousSchedule,
    this.allergyGroup,
    this.pregnancyCaution = false,
    this.pediatricCaution = false,
    this.notes,
  });

  /// Unique uppercase code with hyphens, e.g. `AMOX-500`.
  final String code;

  /// INN generic name (combinations joined with `+`).
  final String genericName;

  /// Common Indian brand names for the picker.
  final List<String> brandNames;

  /// Strength label, e.g. `500 mg`.
  final String strength;

  /// Dosage form, e.g. `tablet`, `capsule`, `mouthwash`.
  final String form;

  /// Schedule that applies on or after [scheduleEffectiveFrom] (or always,
  /// when no effective date is set).
  final DrugSchedule schedule;

  /// ISO-8601 date from which [schedule] applies; null when unchanged.
  final String? scheduleEffectiveFromIso;

  /// Schedule that applied before [scheduleEffectiveFrom].
  final DrugSchedule? previousSchedule;

  /// Therapeutic category, e.g. `antibiotic`, `nsaid`.
  final String category;

  /// Default single dose as printed, e.g. `1 tablet`.
  final String defaultDose;

  /// Default frequency in prescription shorthand, e.g. `TDS`.
  final String defaultFrequency;

  /// Default course length in days; 0 for single-use or as-needed items.
  final int defaultDurationDays;

  /// Route, e.g. `oral`, `topical`, `IM/IV`, `infiltration`.
  final String route;

  /// Allergy cross-check group, e.g. `penicillin`, `nsaid`.
  final String? allergyGroup;

  /// Flag to warn when the patient is pregnant or lactating.
  final bool pregnancyCaution;

  /// Flag to warn for paediatric patients.
  final bool pediatricCaution;

  /// Free-text prescribing note.
  final String? notes;

  /// Parsed [scheduleEffectiveFromIso].
  DateTime? get scheduleEffectiveFrom => scheduleEffectiveFromIso == null
      ? null
      : DateTime.parse(scheduleEffectiveFromIso!);

  /// True when a prescription is required under the current schedule.
  bool get requiresPrescription => schedule.requiresPrescription;

  /// Returns a copy with the given fields replaced.
  DrugSeed copyWith({
    String? code,
    String? genericName,
    List<String>? brandNames,
    String? strength,
    String? form,
    DrugSchedule? schedule,
    String? scheduleEffectiveFromIso,
    DrugSchedule? previousSchedule,
    String? category,
    String? defaultDose,
    String? defaultFrequency,
    int? defaultDurationDays,
    String? route,
    String? allergyGroup,
    bool? pregnancyCaution,
    bool? pediatricCaution,
    String? notes,
  }) => DrugSeed(
    code: code ?? this.code,
    genericName: genericName ?? this.genericName,
    brandNames: brandNames ?? this.brandNames,
    strength: strength ?? this.strength,
    form: form ?? this.form,
    schedule: schedule ?? this.schedule,
    scheduleEffectiveFromIso:
        scheduleEffectiveFromIso ?? this.scheduleEffectiveFromIso,
    previousSchedule: previousSchedule ?? this.previousSchedule,
    category: category ?? this.category,
    defaultDose: defaultDose ?? this.defaultDose,
    defaultFrequency: defaultFrequency ?? this.defaultFrequency,
    defaultDurationDays: defaultDurationDays ?? this.defaultDurationDays,
    route: route ?? this.route,
    allergyGroup: allergyGroup ?? this.allergyGroup,
    pregnancyCaution: pregnancyCaution ?? this.pregnancyCaution,
    pediatricCaution: pediatricCaution ?? this.pediatricCaution,
    notes: notes ?? this.notes,
  );

  /// JSON map with enum names and ISO dates.
  Map<String, Object?> toJson() => {
    'code': code,
    'genericName': genericName,
    'brandNames': brandNames,
    'strength': strength,
    'form': form,
    'schedule': schedule.name,
    'scheduleEffectiveFrom': scheduleEffectiveFromIso,
    'previousSchedule': previousSchedule?.name,
    'category': category,
    'defaultDose': defaultDose,
    'defaultFrequency': defaultFrequency,
    'defaultDurationDays': defaultDurationDays,
    'route': route,
    'allergyGroup': allergyGroup,
    'pregnancyCaution': pregnancyCaution,
    'pediatricCaution': pediatricCaution,
    'notes': notes,
  };

  /// Inverse of [toJson].
  factory DrugSeed.fromJson(Map<String, Object?> json) => DrugSeed(
    code: json['code'] as String,
    genericName: json['genericName'] as String,
    brandNames: (json['brandNames'] as List? ?? const []).cast<String>(),
    strength: json['strength'] as String,
    form: json['form'] as String,
    schedule: DrugSchedule.values.byName(json['schedule'] as String),
    scheduleEffectiveFromIso: json['scheduleEffectiveFrom'] as String?,
    previousSchedule: json['previousSchedule'] == null
        ? null
        : DrugSchedule.values.byName(json['previousSchedule'] as String),
    category: json['category'] as String,
    defaultDose: json['defaultDose'] as String,
    defaultFrequency: json['defaultFrequency'] as String,
    defaultDurationDays: json['defaultDurationDays'] as int,
    route: json['route'] as String,
    allergyGroup: json['allergyGroup'] as String?,
    pregnancyCaution: json['pregnancyCaution'] as bool? ?? false,
    pediatricCaution: json['pediatricCaution'] as bool? ?? false,
    notes: json['notes'] as String?,
  );

  @override
  String toString() => 'DrugSeed($code)';
}

/// Schedule that applies to [drug] on [at]: [DrugSeed.previousSchedule]
/// before [DrugSeed.scheduleEffectiveFrom], otherwise [DrugSeed.schedule].
DrugSchedule scheduleAt(DrugSeed drug, DateTime at) {
  final from = drug.scheduleEffectiveFrom;
  if (from != null && at.isBefore(from)) {
    return drug.previousSchedule ?? drug.schedule;
  }
  return drug.schedule;
}

/// The dental drug master seed.
const List<DrugSeed> dentalDrugMaster = [
  ...antimicrobialDrugs,
  ...analgesicDrugs,
  ...otherDentalDrugs,
];

/// Looks up a drug seed by code; null when unknown.
DrugSeed? drugSeedByCode(String code) {
  for (final d in dentalDrugMaster) {
    if (d.code == code) return d;
  }
  return null;
}

/// Case-insensitive search over generic name, brand names and code.
List<DrugSeed> searchDrugs(String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];
  return dentalDrugMaster
      .where(
        (d) =>
            d.code.toLowerCase().contains(q) ||
            d.genericName.toLowerCase().contains(q) ||
            d.brandNames.any((b) => b.toLowerCase().contains(q)),
      )
      .toList();
}

/// Drugs in an allergy group, for cross-checking against patient allergies.
List<DrugSeed> drugsInAllergyGroup(String group) =>
    dentalDrugMaster.where((d) => d.allergyGroup == group).toList();

/// Allergy group names used in the master.
abstract final class AllergyGroups {
  /// Penicillins including amoxicillin-clavulanate.
  static const String penicillin = 'penicillin';

  /// Cephalosporins (cefixime, cefuroxime, ceftriaxone).
  static const String cephalosporin = 'cephalosporin';

  /// Non-steroidal anti-inflammatories.
  static const String nsaid = 'nsaid';

  /// Sulfonamide-related drugs.
  static const String sulfa = 'sulfa';

  /// Local anaesthetics (amide class).
  static const String localAnaesthetic = 'localAnaesthetic';

  /// Macrolides.
  static const String macrolide = 'macrolide';

  /// Fluoroquinolones.
  static const String fluoroquinolone = 'fluoroquinolone';

  /// Opioids.
  static const String opioid = 'opioid';

  /// Benzodiazepines.
  static const String benzodiazepine = 'benzodiazepine';

  /// Azole antifungals.
  static const String azole = 'azole';
}
