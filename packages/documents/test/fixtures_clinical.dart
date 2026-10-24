import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_documents/ampdent_documents.dart';
import 'package:ampdent_terminology/ampdent_terminology.dart';

import 'fixtures.dart';

final TreatmentPlan samplePlan = TreatmentPlan(
  id: 'plan-1',
  clinicId: clinic.id,
  patientId: patient.id,
  title: 'Lower right restoration',
  phases: const [
    PlanPhase(index: 0, name: 'Pain relief and endodontics'),
    PlanPhase(index: 1, name: 'Restoration', note: 'After 2 weeks review'),
  ],
  createdBy: dentist.id,
  createdAt: now,
  updatedAt: now,
);

TreatmentPlanLine planLine({
  required String id,
  required String code,
  required String name,
  required String layman,
  required Money fee,
  ToothId? tooth,
  int phase = 0,
  int sequence = 0,
  bool alternative = false,
  String? group,
  GstClass gstClass = GstClass.exemptHealthcare,
}) => TreatmentPlanLine(
  id: id,
  planId: samplePlan.id,
  clinicId: clinic.id,
  patientId: patient.id,
  catalogItemId: 'cat-$code',
  code: code,
  name: name,
  laymanName: layman,
  tooth: tooth,
  treatmentArea: TreatmentArea.tooth,
  phaseIndex: phase,
  sequence: sequence,
  unitFee: fee,
  gstClass: gstClass,
  isAlternative: alternative,
  alternativeGroup: group,
);

final List<TreatmentPlanLine> samplePlanLines = [
  planLine(
    id: 'pl1',
    code: 'RCT-MOL',
    name: 'Root canal treatment - molar',
    layman: 'Root canal (back tooth)',
    fee: const Money.rupees(6000),
    tooth: t('46'),
  ),
  planLine(
    id: 'pl2',
    code: 'CRN-ZIR',
    name: 'Zirconia crown',
    layman: 'Tooth cap (zirconia)',
    fee: const Money.rupees(9000),
    tooth: t('46'),
    phase: 1,
  ),
  planLine(
    id: 'pl3',
    code: 'CRN-PFM',
    name: 'PFM crown',
    layman: 'Tooth cap (metal-ceramic)',
    fee: const Money.rupees(5000),
    tooth: t('46'),
    phase: 1,
    alternative: true,
    group: 'Crown material',
  ),
];

Estimate sampleEstimate({int version = 1}) {
  final lines = [
    for (final l in samplePlanLines.where((l) => !l.isAlternative))
      EstimateLine(
        description: l.laymanName,
        tooth: l.tooth,
        unitFee: l.unitFee,
        gstClass: l.gstClass,
        lineTotal: l.net,
      ),
  ];
  final subtotal = lines.map((l) => l.lineTotal).total;
  return Estimate(
    id: 'est-1',
    clinicId: clinic.id,
    patientId: patient.id,
    planId: samplePlan.id,
    version: version,
    number: 'EST-0042',
    lines: lines,
    subtotal: subtotal,
    discountTotal: const Money.zero(),
    taxTotal: const Money.zero(),
    grandTotal: subtotal,
    issuedAt: now,
    issuedBy: dentist.id,
    justification: version > 1
        ? 'Additional canal found on access; crown upgraded'
        : null,
    validUntil: now.add(const Duration(days: 30)),
    status: EstimateStatus.issued,
    createdAt: now,
  );
}

Prescription samplePrescription() {
  final amox = drugSeedByCode('AMOX-500')!;
  return Prescription(
    id: 'rx-1',
    clinicId: clinic.id,
    patientId: patient.id,
    prescriberId: dentist.id,
    prescriberName: dentist.displayName,
    prescriberRegistrationNumber: dentist.registrationNumber!,
    prescriberQualifications: dentist.qualifications,
    issuedAt: now,
    diagnosis: 'Irreversible pulpitis 46 (K04.0)',
    lines: [
      PrescriptionLine(
        genericName: amox.genericName,
        brandName: amox.brandNames.first,
        strength: amox.strength,
        form: DrugForm.capsule,
        dose: amox.defaultDose,
        frequency: amox.defaultFrequency,
        durationDays: amox.defaultDurationDays,
        quantity: 15,
        route: amox.route,
        instructions: 'After food',
        schedule: amox.schedule,
      ),
      const PrescriptionLine(
        genericName: 'Tramadol',
        strength: '50 mg',
        form: DrugForm.tablet,
        dose: '1 tab',
        frequency: 'SOS, max BD',
        durationDays: 3,
        quantity: 6,
        route: 'Oral',
        instructions: 'Only for severe pain',
        schedule: DrugSchedule.h1,
      ),
      const PrescriptionLine(
        genericName: 'Chlorhexidine gluconate',
        strength: '0.2% w/v',
        form: DrugForm.mouthwash,
        dose: '10 ml',
        frequency: 'BD',
        durationDays: 7,
        quantity: 1,
        route: 'Topical',
        instructions: 'Rinse for 1 minute, do not swallow',
        schedule: DrugSchedule.otc,
      ),
    ],
    verificationCode: 'K7Q2-9XMA',
    createdAt: now,
  );
}

ConsentRecord sampleConsent() {
  final template = consentTemplateByCode('RCT')!;
  final rendered = template.render({
    'name_of_patient': patient.displayName,
    'patient_age': '36',
    'patient_gender': 'Male',
    'doctor_name': dentist.displayName,
    'tooth_numbers': '46',
    'clinic_name': clinic.name,
    'date': '18 Oct 2026',
    'registration_number': dentist.registrationNumber!,
  });
  return ConsentRecord(
    id: 'consent-1',
    clinicId: clinic.id,
    patientId: patient.id,
    templateCode: template.code,
    templateVersionHash: template.versionHash,
    languageCode: 'en',
    procedureIds: const ['proc-1'],
    planId: samplePlan.id,
    teeth: [t('46')],
    renderedText: rendered,
    signerName: patient.displayName,
    signerRelation: SignerRelation.self,
    signerPhone: patient.phone,
    otpVerified: true,
    signedAt: now,
    dentistId: dentist.id,
    dentistRegistrationNumber: dentist.registrationNumber!,
    discussionNote: 'Explained the three sittings and the need for a crown.',
    witnessName: 'Anita (assistant)',
    deviceId: 'device-ab12',
    documentHash: sha256HexOfString(rendered),
    createdAt: now,
  );
}

final Lab sampleLab = Lab(
  id: 'lab-1',
  clinicId: clinic.id,
  name: 'Precision Dental Lab',
  phone: '+91 80000 22222',
  turnaroundDays: const {'crownZirconia': 5},
);

LabCase sampleLabCase() => LabCase(
  id: '3f1c2b4a-5d6e-4f70-8a9b-0c1d2e3f4a5b',
  clinicId: clinic.id,
  patientId: patient.id,
  procedureId: 'proc-2',
  labId: sampleLab.id,
  caseType: LabCaseType.crownZirconia,
  teeth: [t('46')],
  material: 'Monolithic zirconia',
  shade: 'A2 (Vita Classical)',
  impressionType: 'Digital scan (STL attached)',
  instructions:
      'Full-contour crown, light occlusal contact, polish margins. '
      'Bite registration included.',
  labFee: const Money.rupees(2800),
  status: LabCaseStatus.sent,
  createdAt: now,
  sentAt: now,
  dueAt: now.add(const Duration(days: 7)),
  updatedAt: now,
);

List<ToothStateRecord> sampleToothStates() {
  final defaults = defaultToothStates(ageYears: 36);
  return [
    for (final e in defaults.entries)
      ToothStateRecord(
        id: 'ts-${e.key.storageKey}',
        clinicId: clinic.id,
        patientId: patient.id,
        tooth: e.key,
        state: e.value,
        effectiveFrom: now.subtract(const Duration(days: 400)),
        source: ToothStateSource.ageDefault,
        recordedBy: dentist.id,
        createdAt: now.subtract(const Duration(days: 400)),
      ),
    ToothStateRecord(
      id: 'ts-36-x',
      clinicId: clinic.id,
      patientId: patient.id,
      tooth: t('36'),
      state: ToothState.extracted,
      effectiveFrom: now.subtract(const Duration(days: 100)),
      source: ToothStateSource.procedure,
      procedureId: 'proc-0',
      recordedBy: dentist.id,
      createdAt: now.subtract(const Duration(days: 100)),
    ),
  ];
}

List<Finding> sampleFindings() => [
  Finding(
    id: 'f1',
    clinicId: clinic.id,
    patientId: patient.id,
    tooth: t('46'),
    surfaces: SurfaceSet.parse('MO'),
    icd10Code: 'K02.1',
    description: 'Deep caries approaching pulp',
    icdas: IcdasCode.distinctCavity,
    recordedAt: now.subtract(const Duration(days: 20)),
    recordedBy: dentist.id,
    createdAt: now.subtract(const Duration(days: 20)),
    updatedAt: now.subtract(const Duration(days: 20)),
  ),
];

List<ProcedureRecord> sampleProcedures() => [
  ProcedureRecord(
    id: 'proc-1',
    clinicId: clinic.id,
    patientId: patient.id,
    planId: samplePlan.id,
    planLineId: 'pl1',
    catalogItemId: 'cat-RCT-MOL',
    code: 'RCT-MOL',
    name: 'Root canal treatment - molar',
    tooth: t('46'),
    treatmentArea: TreatmentArea.tooth,
    status: ProcedureStatus.inProgress,
    providerId: dentist.id,
    fee: const Money.rupees(6000),
    stageIndex: 0,
    totalStages: 3,
    stageNames: rctStages,
    startedAt: now,
    createdAt: now,
    updatedAt: now,
  ),
  ProcedureRecord(
    id: 'proc-0',
    clinicId: clinic.id,
    patientId: patient.id,
    catalogItemId: 'cat-EXT-SIMPLE',
    code: 'EXT-SIMPLE',
    name: 'Simple extraction',
    tooth: t('36'),
    treatmentArea: TreatmentArea.tooth,
    status: ProcedureStatus.completed,
    providerId: dentist.id,
    fee: const Money.rupees(1200),
    completedAt: now.subtract(const Duration(days: 100)),
    createdAt: now.subtract(const Duration(days: 100)),
    updatedAt: now.subtract(const Duration(days: 100)),
  ),
];

List<ClinicalNote> sampleNotes() => [
  ClinicalNote(
    id: 'note-1',
    clinicId: clinic.id,
    patientId: patient.id,
    visitId: 'visit-1',
    authorId: dentist.id,
    chiefComplaint: 'Pain in lower right back tooth for 3 days',
    provisionalDiagnosis: 'Irreversible pulpitis 46',
    treatmentDone: 'Access opening and BMP 46',
    advice: 'Avoid chewing on the right side',
    followUp: 'Obturation in 7 days',
    signedAt: now,
    createdAt: now,
    updatedAt: now,
  ),
];

List<PerioExam> samplePerioExams() => [
  PerioExam(
    id: 'perio-1',
    clinicId: clinic.id,
    patientId: patient.id,
    examinedAt: now.subtract(const Duration(days: 20)),
    examinerId: dentist.id,
    sites: [
      PerioSiteReading(
        tooth: t('46'),
        site: PerioSite.mesioBuccal,
        probingDepth: 5,
        gingivalMargin: -1,
        bleeding: true,
      ),
      PerioSiteReading(
        tooth: t('46'),
        site: PerioSite.buccal,
        probingDepth: 3,
        gingivalMargin: 0,
      ),
    ],
    bpe: const {
      Sextant.lowerRightPosterior: BpeCode.code3,
      Sextant.lowerAnterior: BpeCode.code1,
    },
    createdAt: now.subtract(const Duration(days: 20)),
  ),
];
