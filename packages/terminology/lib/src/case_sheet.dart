/// BDS case-sheet structure and the structured medical-history questions.
library;

/// One section of the clinical note / case sheet.
class CaseSheetSection {
  /// Creates a section; [parentKey] nests it under another section.
  const CaseSheetSection({
    required this.key,
    required this.title,
    required this.hint,
    this.parentKey,
  });

  /// Stable key stored with the note, e.g. `chiefComplaint`.
  final String key;

  /// Heading shown to the dentist.
  final String title;

  /// Short prompt shown as the empty-field hint.
  final String hint;

  /// Key of the enclosing section for sub-sections; null at top level.
  final String? parentKey;

  /// True when this section sits inside another.
  bool get isSubSection => parentKey != null;

  /// JSON map.
  Map<String, Object?> toJson() => {
    'key': key,
    'title': title,
    'hint': hint,
    'parentKey': parentKey,
  };

  @override
  String toString() => 'CaseSheetSection($key)';
}

/// Standard BDS case-sheet sections in order.
const List<CaseSheetSection> caseSheetSections = [
  CaseSheetSection(
    key: 'chiefComplaint',
    title: 'Chief complaint',
    hint: "In the patient's own words, with duration",
  ),
  CaseSheetSection(
    key: 'historyOfPresentIllness',
    title: 'History of present illness',
    hint: 'Onset, duration, character, aggravating and relieving factors',
  ),
  CaseSheetSection(
    key: 'pastDentalHistory',
    title: 'Past dental history',
    hint: 'Previous treatment, complications, attitude to dental care',
  ),
  CaseSheetSection(
    key: 'pastMedicalHistory',
    title: 'Past medical history',
    hint: 'Systemic illness, hospitalisation, medications, allergies',
  ),
  CaseSheetSection(
    key: 'personalHistory',
    title: 'Personal history',
    hint: 'Diet, brushing habits, tobacco, alcohol, parafunctional habits',
  ),
  CaseSheetSection(
    key: 'extraoralExamination',
    title: 'Extraoral examination',
    hint: 'Facial symmetry, lymph nodes, TMJ, lips, swelling',
  ),
  CaseSheetSection(
    key: 'intraoralExamination',
    title: 'Intraoral examination',
    hint: 'Soft and hard tissue findings',
  ),
  CaseSheetSection(
    key: 'intraoralSoftTissue',
    title: 'Soft tissue',
    hint: 'Mucosa, gingiva, tongue, palate, floor of mouth, saliva',
    parentKey: 'intraoralExamination',
  ),
  CaseSheetSection(
    key: 'intraoralHardTissue',
    title: 'Hard tissue',
    hint: 'Teeth present, caries, restorations, wear, mobility, occlusion',
    parentKey: 'intraoralExamination',
  ),
  CaseSheetSection(
    key: 'provisionalDiagnosis',
    title: 'Provisional diagnosis',
    hint: 'Working diagnosis before investigations (ICD-10 K00-K14)',
  ),
  CaseSheetSection(
    key: 'investigations',
    title: 'Investigations',
    hint: 'Radiographs, vitality tests, blood investigations, biopsy',
  ),
  CaseSheetSection(
    key: 'finalDiagnosis',
    title: 'Final diagnosis',
    hint: 'Confirmed diagnosis with ICD-10 code and tooth numbers',
  ),
  CaseSheetSection(
    key: 'treatmentPlan',
    title: 'Treatment plan',
    hint: 'Phased plan: emergency, control, definitive, maintenance',
  ),
  CaseSheetSection(
    key: 'treatmentDone',
    title: 'Treatment done',
    hint: 'Procedures completed today with tooth numbers and materials',
  ),
  CaseSheetSection(
    key: 'advice',
    title: 'Advice',
    hint: 'Post-operative instructions and prescription',
  ),
  CaseSheetSection(
    key: 'followUp',
    title: 'Follow-up',
    hint: 'Next visit date and purpose',
  ),
];

/// Top-level sections only, in order.
List<CaseSheetSection> get caseSheetTopLevelSections =>
    caseSheetSections.where((s) => !s.isSubSection).toList();

/// Sub-sections of [parentKey], in order.
List<CaseSheetSection> caseSheetSubSections(String parentKey) =>
    caseSheetSections.where((s) => s.parentKey == parentKey).toList();

/// Looks up a section by key; null when unknown.
CaseSheetSection? caseSheetSectionByKey(String key) {
  for (final s in caseSheetSections) {
    if (s.key == key) return s;
  }
  return null;
}

/// Field keys of the structured `MedicalHistory` entity, in question order.
const List<String> medicalHistoryFieldKeys = [
  'diabetes',
  'hypertension',
  'cardiac',
  'bleedingDisorder',
  'anticoagulants',
  'antiresorptives',
  'pregnancy',
  'asthma',
  'epilepsy',
  'thyroid',
  'steroids',
  'hepatitis',
  'hiv',
  'allergies',
  'smoking',
  'alcohol',
];

/// Patient-facing yes/no questions, one per entry of
/// [medicalHistoryFieldKeys] in the same order.
const List<String> medicalHistoryQuestions = [
  'Do you have diabetes? If yes, is it controlled and what is your recent blood sugar / HbA1c?',
  'Do you have high blood pressure? Are you taking medicines for it?',
  'Do you have any heart condition (valve disease, stent, bypass, pacemaker, rheumatic fever)?',
  'Do you bleed for a long time after a cut or have a bleeding disorder?',
  'Are you taking blood thinners (aspirin, clopidogrel, warfarin, apixaban, rivaroxaban)?',
  'Have you ever taken medicines for bone strength or cancer such as bisphosphonates (alendronate, zoledronate) or denosumab?',
  'Are you pregnant, planning pregnancy or breastfeeding?',
  'Do you have asthma or breathing problems? Do you use an inhaler?',
  'Do you have epilepsy or have you ever had fits or seizures?',
  'Do you have a thyroid problem?',
  'Are you taking or have you recently taken steroid tablets or injections?',
  'Have you had jaundice or hepatitis B or C?',
  'Are you HIV positive or do you have any other condition that lowers immunity?',
  'Are you allergic to any medicine (penicillin, sulfa, painkillers), local anaesthetic, latex or food?',
  'Do you smoke or use tobacco in any form (cigarettes, bidi, gutkha, khaini, pan masala)? How much per day?',
  'Do you drink alcohol? How often?',
];

/// Question text for a `MedicalHistory` field key; null when unknown.
String? medicalHistoryQuestionFor(String fieldKey) {
  final index = medicalHistoryFieldKeys.indexOf(fieldKey);
  return index < 0 ? null : medicalHistoryQuestions[index];
}
