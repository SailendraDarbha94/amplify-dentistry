import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_terminology/ampdent_terminology.dart';
import 'package:flutter/foundation.dart';

/// Allergy groups offered when recording an allergy; the first ten drive
/// prescribing checks, the rest are informational.
const List<String> allergyGroupOptions = [
  AllergyGroups.penicillin,
  AllergyGroups.cephalosporin,
  AllergyGroups.nsaid,
  AllergyGroups.sulfa,
  AllergyGroups.localAnaesthetic,
  AllergyGroups.macrolide,
  AllergyGroups.fluoroquinolone,
  AllergyGroups.opioid,
  AllergyGroups.benzodiazepine,
  AllergyGroups.azole,
  'latex',
  'food',
  'other',
];

/// Human label for an allergy group.
String allergyGroupLabel(String group) => switch (group) {
  AllergyGroups.penicillin => 'Penicillin',
  AllergyGroups.cephalosporin => 'Cephalosporin',
  AllergyGroups.nsaid => 'NSAID / painkiller',
  AllergyGroups.sulfa => 'Sulfa',
  AllergyGroups.localAnaesthetic => 'Local anaesthetic',
  AllergyGroups.macrolide => 'Macrolide',
  AllergyGroups.fluoroquinolone => 'Fluoroquinolone',
  AllergyGroups.opioid => 'Opioid',
  AllergyGroups.benzodiazepine => 'Benzodiazepine',
  AllergyGroups.azole => 'Azole antifungal',
  'latex' => 'Latex',
  'food' => 'Food',
  _ => 'Other',
};

/// Editable copy of a [MedicalHistory]. Yes/no answers follow the sixteen
/// terminology questions (`medicalHistoryFieldKeys`); detail fields are kept
/// as text so the form can hold partial input.
@immutable
class MedicalHistoryDraft {
  /// Creates a draft; everything defaults to "no".
  const MedicalHistoryDraft({
    this.allergies = const [],
    this.medications = const [],
    this.diabetes = false,
    this.hba1c = '',
    this.hypertension = false,
    this.cardiac = false,
    this.cardiacCondition = '',
    this.bleedingDisorder = false,
    this.anticoagulant = false,
    this.anticoagulantName = '',
    this.antiresorptive = false,
    this.antiresorptiveName = '',
    this.antiresorptiveRoute,
    this.antiresorptiveYears = '',
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
    this.otherNotes = '',
  });

  /// Copies the latest stored history; a null history gives an empty draft.
  factory MedicalHistoryDraft.fromHistory(MedicalHistory? h) {
    if (h == null) return const MedicalHistoryDraft();
    return MedicalHistoryDraft(
      allergies: h.allergies,
      medications: h.medications,
      diabetes: h.diabetes,
      hba1c: h.hba1c?.toString() ?? '',
      hypertension: h.hypertension,
      cardiac: (h.cardiacCondition ?? '').isNotEmpty,
      cardiacCondition: h.cardiacCondition ?? '',
      bleedingDisorder: h.bleedingDisorder,
      anticoagulant: (h.anticoagulant ?? '').isNotEmpty,
      anticoagulantName: h.anticoagulant ?? '',
      antiresorptive: (h.antiresorptive ?? '').isNotEmpty,
      antiresorptiveName: h.antiresorptive ?? '',
      antiresorptiveRoute: h.antiresorptiveRoute,
      antiresorptiveYears: h.antiresorptiveYears?.toString() ?? '',
      oncologyTreatment: h.oncologyTreatment,
      pregnant: h.pregnant,
      pregnancyTrimester: h.pregnancyTrimester,
      asthma: h.asthma,
      epilepsy: h.epilepsy,
      thyroid: h.thyroid,
      steroids: h.steroids,
      hepatitis: h.hepatitis,
      hiv: h.hiv,
      smoking: h.smoking,
      alcohol: h.alcohol,
      otherNotes: h.otherNotes ?? '',
    );
  }

  /// Recorded allergies.
  final List<AllergyEntry> allergies;

  /// Current medications.
  final List<String> medications;

  /// Diabetic.
  final bool diabetes;

  /// Recent HbA1c as typed.
  final String hba1c;

  /// Hypertensive.
  final bool hypertension;

  /// Has a cardiac condition.
  final bool cardiac;

  /// Cardiac condition text.
  final String cardiacCondition;

  /// Bleeding disorder.
  final bool bleedingDisorder;

  /// On a blood thinner.
  final bool anticoagulant;

  /// Blood thinner name.
  final String anticoagulantName;

  /// On an antiresorptive (bisphosphonate / denosumab).
  final bool antiresorptive;

  /// Antiresorptive name.
  final String antiresorptiveName;

  /// Oral or intravenous.
  final AntiresorptiveRoute? antiresorptiveRoute;

  /// Years on the drug as typed.
  final String antiresorptiveYears;

  /// Antiresorptive given for cancer.
  final bool oncologyTreatment;

  /// Pregnant.
  final bool pregnant;

  /// 1, 2 or 3.
  final int? pregnancyTrimester;

  /// Asthma.
  final bool asthma;

  /// Epilepsy.
  final bool epilepsy;

  /// Thyroid disorder.
  final bool thyroid;

  /// Steroid therapy.
  final bool steroids;

  /// Hepatitis B/C.
  final bool hepatitis;

  /// HIV or immunocompromise.
  final bool hiv;

  /// Tobacco use.
  final SmokingStatus smoking;

  /// Alcohol use.
  final bool alcohol;

  /// Anything else.
  final String otherNotes;

  /// Yes/no answer for a terminology question key.
  bool isYes(String fieldKey) => switch (fieldKey) {
    'diabetes' => diabetes,
    'hypertension' => hypertension,
    'cardiac' => cardiac,
    'bleedingDisorder' => bleedingDisorder,
    'anticoagulants' => anticoagulant,
    'antiresorptives' => antiresorptive,
    'pregnancy' => pregnant,
    'asthma' => asthma,
    'epilepsy' => epilepsy,
    'thyroid' => thyroid,
    'steroids' => steroids,
    'hepatitis' => hepatitis,
    'hiv' => hiv,
    'allergies' => allergies.isNotEmpty,
    'smoking' => smoking != SmokingStatus.never,
    'alcohol' => alcohol,
    _ => false,
  };

  /// Sets the yes/no answer for a question key. Saying "no" clears the
  /// detail that belongs to that question.
  MedicalHistoryDraft answer(String fieldKey, bool yes) => switch (fieldKey) {
    'diabetes' => copyWith(diabetes: yes, hba1c: yes ? hba1c : ''),
    'hypertension' => copyWith(hypertension: yes),
    'cardiac' => copyWith(
      cardiac: yes,
      cardiacCondition: yes ? cardiacCondition : '',
    ),
    'bleedingDisorder' => copyWith(bleedingDisorder: yes),
    'anticoagulants' => copyWith(
      anticoagulant: yes,
      anticoagulantName: yes ? anticoagulantName : '',
    ),
    'antiresorptives' => copyWith(
      antiresorptive: yes,
      antiresorptiveName: yes ? antiresorptiveName : '',
      antiresorptiveYears: yes ? antiresorptiveYears : '',
      oncologyTreatment: yes && oncologyTreatment,
      clearRoute: !yes,
    ),
    'pregnancy' => copyWith(pregnant: yes, clearTrimester: !yes),
    'asthma' => copyWith(asthma: yes),
    'epilepsy' => copyWith(epilepsy: yes),
    'thyroid' => copyWith(thyroid: yes),
    'steroids' => copyWith(steroids: yes),
    'hepatitis' => copyWith(hepatitis: yes),
    'hiv' => copyWith(hiv: yes),
    'allergies' => yes ? this : copyWith(allergies: const []),
    'smoking' => copyWith(
      smoking: yes ? SmokingStatus.current : SmokingStatus.never,
    ),
    'alcohol' => copyWith(alcohol: yes),
    _ => this,
  };

  /// Builds the immutable snapshot to append.
  MedicalHistory toHistory({
    required String id,
    required String clinicId,
    required String patientId,
    required String recordedBy,
    required DateTime now,
  }) => MedicalHistory(
    id: id,
    clinicId: clinicId,
    patientId: patientId,
    recordedAt: now,
    recordedBy: recordedBy,
    allergies: allergies,
    medications: medications,
    diabetes: diabetes,
    hba1c: diabetes ? num.tryParse(hba1c.trim()) : null,
    hypertension: hypertension,
    cardiacCondition: cardiac && cardiacCondition.trim().isNotEmpty
        ? cardiacCondition.trim()
        : (cardiac ? 'Cardiac condition (unspecified)' : null),
    bleedingDisorder: bleedingDisorder,
    anticoagulant: anticoagulant
        ? (anticoagulantName.trim().isEmpty
              ? 'Blood thinner (unspecified)'
              : anticoagulantName.trim())
        : null,
    antiresorptive: antiresorptive
        ? (antiresorptiveName.trim().isEmpty
              ? 'Antiresorptive (unspecified)'
              : antiresorptiveName.trim())
        : null,
    antiresorptiveRoute: antiresorptive ? antiresorptiveRoute : null,
    antiresorptiveYears: antiresorptive
        ? num.tryParse(antiresorptiveYears.trim())
        : null,
    oncologyTreatment: antiresorptive && oncologyTreatment,
    pregnant: pregnant,
    pregnancyTrimester: pregnant ? pregnancyTrimester : null,
    asthma: asthma,
    epilepsy: epilepsy,
    thyroid: thyroid,
    steroids: steroids,
    hepatitis: hepatitis,
    hiv: hiv,
    smoking: smoking,
    alcohol: alcohol,
    otherNotes: otherNotes.trim().isEmpty ? null : otherNotes.trim(),
    createdAt: now,
  );

  /// Preview of the snapshot for live red flags (ids are placeholders).
  MedicalHistory preview(DateTime now) => toHistory(
    id: 'preview',
    clinicId: 'preview',
    patientId: 'preview',
    recordedBy: 'preview',
    now: now,
  );

  /// MRONJ tier the current answers imply.
  MronjRisk mronjRisk(DateTime now) => preview(now).mronjRisk;

  /// Returns a copy with the given fields replaced.
  MedicalHistoryDraft copyWith({
    List<AllergyEntry>? allergies,
    List<String>? medications,
    bool? diabetes,
    String? hba1c,
    bool? hypertension,
    bool? cardiac,
    String? cardiacCondition,
    bool? bleedingDisorder,
    bool? anticoagulant,
    String? anticoagulantName,
    bool? antiresorptive,
    String? antiresorptiveName,
    AntiresorptiveRoute? antiresorptiveRoute,
    bool clearRoute = false,
    String? antiresorptiveYears,
    bool? oncologyTreatment,
    bool? pregnant,
    int? pregnancyTrimester,
    bool clearTrimester = false,
    bool? asthma,
    bool? epilepsy,
    bool? thyroid,
    bool? steroids,
    bool? hepatitis,
    bool? hiv,
    SmokingStatus? smoking,
    bool? alcohol,
    String? otherNotes,
  }) => MedicalHistoryDraft(
    allergies: allergies ?? this.allergies,
    medications: medications ?? this.medications,
    diabetes: diabetes ?? this.diabetes,
    hba1c: hba1c ?? this.hba1c,
    hypertension: hypertension ?? this.hypertension,
    cardiac: cardiac ?? this.cardiac,
    cardiacCondition: cardiacCondition ?? this.cardiacCondition,
    bleedingDisorder: bleedingDisorder ?? this.bleedingDisorder,
    anticoagulant: anticoagulant ?? this.anticoagulant,
    anticoagulantName: anticoagulantName ?? this.anticoagulantName,
    antiresorptive: antiresorptive ?? this.antiresorptive,
    antiresorptiveName: antiresorptiveName ?? this.antiresorptiveName,
    antiresorptiveRoute: clearRoute
        ? null
        : antiresorptiveRoute ?? this.antiresorptiveRoute,
    antiresorptiveYears: antiresorptiveYears ?? this.antiresorptiveYears,
    oncologyTreatment: oncologyTreatment ?? this.oncologyTreatment,
    pregnant: pregnant ?? this.pregnant,
    pregnancyTrimester: clearTrimester
        ? null
        : pregnancyTrimester ?? this.pregnancyTrimester,
    asthma: asthma ?? this.asthma,
    epilepsy: epilepsy ?? this.epilepsy,
    thyroid: thyroid ?? this.thyroid,
    steroids: steroids ?? this.steroids,
    hepatitis: hepatitis ?? this.hepatitis,
    hiv: hiv ?? this.hiv,
    smoking: smoking ?? this.smoking,
    alcohol: alcohol ?? this.alcohol,
    otherNotes: otherNotes ?? this.otherNotes,
  );
}
