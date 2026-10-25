import 'package:meta/meta.dart';

import '../dental/clinical_enums.dart';
import 'json_support.dart';

/// Dosage form of a drug.
enum DrugForm {
  tablet,
  capsule,
  syrup,
  suspension,
  injection,
  mouthwash,
  gel,
  ointment,
  paste,
  drops,
  varnish,
  toothpaste,
  other,
}

/// A drug master entry (seeded from `ampdent_terminology`).
@immutable
class Drug {
  /// Creates a drug.
  const Drug({
    required this.id,
    this.clinicId,
    required this.genericName,
    this.brandNames = const [],
    required this.strength,
    required this.form,
    this.schedule = DrugSchedule.h,
    this.scheduleEffectiveFrom,
    required this.category,
    required this.defaultDose,
    required this.defaultFrequency,
    required this.defaultDurationDays,
    required this.route,
    this.allergyGroup,
    this.pregnancyCaution = false,
    this.pediatricCaution = false,
    this.isActive = true,
  });

  /// UUID v4.
  final String id;

  /// Clinic that added this entry; null for the seeded global master.
  final String? clinicId;

  /// INN / generic name (`Amoxicillin`).
  final String genericName;

  /// Common Indian brand names.
  final List<String> brandNames;

  /// Strength (`500 mg`).
  final String strength;

  /// Dosage form.
  final DrugForm form;

  /// Drugs and Cosmetics Rules schedule.
  final DrugSchedule schedule;

  /// When the current schedule tag took effect.
  final DateTime? scheduleEffectiveFrom;

  /// Therapeutic category (`antibiotic`, `analgesic`).
  final String category;

  /// Default dose (`1 tab`).
  final String defaultDose;

  /// Default frequency (`TDS`, `1-0-1`).
  final String defaultFrequency;

  /// Default course length in days.
  final int defaultDurationDays;

  /// Route (`oral`, `topical`).
  final String route;

  /// Allergy group checked against the patient's history.
  final String? allergyGroup;

  /// Caution in pregnancy.
  final bool pregnancyCaution;

  /// Caution in children.
  final bool pediatricCaution;

  /// Inactive drugs are hidden from pickers.
  final bool isActive;

  /// Returns a copy with the given fields replaced.
  Drug copyWith({
    List<String>? brandNames,
    String? strength,
    DrugForm? form,
    DrugSchedule? schedule,
    DateTime? scheduleEffectiveFrom,
    String? category,
    String? defaultDose,
    String? defaultFrequency,
    int? defaultDurationDays,
    String? route,
    String? allergyGroup,
    bool? pregnancyCaution,
    bool? pediatricCaution,
    bool? isActive,
  }) => Drug(
    id: id,
    clinicId: clinicId,
    genericName: genericName,
    brandNames: brandNames ?? this.brandNames,
    strength: strength ?? this.strength,
    form: form ?? this.form,
    schedule: schedule ?? this.schedule,
    scheduleEffectiveFrom: scheduleEffectiveFrom ?? this.scheduleEffectiveFrom,
    category: category ?? this.category,
    defaultDose: defaultDose ?? this.defaultDose,
    defaultFrequency: defaultFrequency ?? this.defaultFrequency,
    defaultDurationDays: defaultDurationDays ?? this.defaultDurationDays,
    route: route ?? this.route,
    allergyGroup: allergyGroup ?? this.allergyGroup,
    pregnancyCaution: pregnancyCaution ?? this.pregnancyCaution,
    pediatricCaution: pediatricCaution ?? this.pediatricCaution,
    isActive: isActive ?? this.isActive,
  );

  /// JSON form.
  Map<String, Object?> toJson() => {
    'id': id,
    'clinicId': clinicId,
    'genericName': genericName,
    'brandNames': brandNames,
    'strength': strength,
    'form': form.name,
    'schedule': schedule.name,
    'scheduleEffectiveFrom': dateToJson(scheduleEffectiveFrom),
    'category': category,
    'defaultDose': defaultDose,
    'defaultFrequency': defaultFrequency,
    'defaultDurationDays': defaultDurationDays,
    'route': route,
    'allergyGroup': allergyGroup,
    'pregnancyCaution': pregnancyCaution,
    'pediatricCaution': pediatricCaution,
    'isActive': isActive,
  };

  /// Parses the JSON form.
  factory Drug.fromJson(Map<String, Object?> json) => Drug(
    id: json['id'] as String,
    clinicId: json['clinicId'] as String?,
    genericName: json['genericName'] as String,
    brandNames: stringListFromJson(json['brandNames']),
    strength: json['strength'] as String,
    form: enumFromJson(DrugForm.values, json['form']),
    schedule: enumFromJson(DrugSchedule.values, json['schedule']),
    scheduleEffectiveFrom: dateFromJsonOrNull(json['scheduleEffectiveFrom']),
    category: json['category'] as String,
    defaultDose: json['defaultDose'] as String,
    defaultFrequency: json['defaultFrequency'] as String,
    defaultDurationDays: json['defaultDurationDays'] as int,
    route: json['route'] as String,
    allergyGroup: json['allergyGroup'] as String?,
    pregnancyCaution: json['pregnancyCaution'] as bool? ?? false,
    pediatricCaution: json['pediatricCaution'] as bool? ?? false,
    isActive: json['isActive'] as bool? ?? true,
  );
}
