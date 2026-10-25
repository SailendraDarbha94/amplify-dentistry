import 'dart:convert';

import 'package:ampdent_core/ampdent_core.dart';
import 'package:test/test.dart';

final _t0 = DateTime.utc(2026, 10, 18, 9, 30);
final _t1 = DateTime.utc(2026, 10, 18, 10, 0);
const _clinic = 'clinic-1';
const _patient = 'patient-1';
const _provider = 'member-1';

/// Serialises, passes through real JSON text, parses and compares maps.
void _roundTrip<T>(
  String name,
  T entity,
  Map<String, Object?> Function(T) toJson,
  T Function(Map<String, Object?>) fromJson,
) {
  test('$name JSON round trip', () {
    final json = toJson(entity);
    final wire = jsonDecode(jsonEncode(json)) as Map<String, dynamic>;
    final parsed = fromJson(wire.cast<String, Object?>());
    expect(toJson(parsed), equals(json));
  });
}

Patient _patient0({
  DateTime? dob,
  String? guardianName,
  String? guardianPhone,
}) => Patient(
  id: _patient,
  clinicId: _clinic,
  patientNumber: 'P-00001',
  firstName: 'Anil',
  lastName: 'Kumar',
  phone: '9000000001',
  dateOfBirth: dob ?? DateTime.utc(1990, 5, 20),
  sex: Sex.male,
  addressLines: const ['12 MG Road'],
  city: 'Hyderabad',
  pincode: '500001',
  guardianName: guardianName,
  guardianPhone: guardianPhone,
  preferredLanguage: 'te',
  tags: const ['vip'],
  createdAt: _t0,
  updatedAt: _t1,
);

InvoiceLine _line(
  String id,
  Money price,
  GstClass gstClass,
  num rate, {
  Money discount = const Money.zero(),
}) => InvoiceLine(
  id: id,
  description: id,
  unitPrice: price,
  discount: discount,
  gstClass: gstClass,
  sacHsnCode: gstClass.defaultCode,
  taxRatePercent: rate,
);

Invoice _invoice(
  String id,
  DateTime issuedAt,
  Money grand,
  Money paid, {
  InvoiceStatus status = InvoiceStatus.issued,
}) => Invoice(
  id: id,
  clinicId: _clinic,
  patientId: _patient,
  number: 'INV-1',
  documentType: InvoiceDocumentType.receipt,
  status: status,
  issuedAt: issuedAt,
  grandTotal: grand,
  amountPaid: paid,
  issuedBy: _provider,
  createdAt: issuedAt,
  updatedAt: issuedAt,
);

TreatmentPlanLine _planLine(
  String id,
  String code,
  Money fee, {
  bool alternative = false,
}) => TreatmentPlanLine(
  id: id,
  planId: 'plan-1',
  clinicId: _clinic,
  patientId: _patient,
  catalogItemId: 'cat-$code',
  code: code,
  name: code,
  laymanName: code,
  tooth: ToothId.parse('16'),
  teeth: [ToothId.parse('16'), ToothId.parse('17')],
  surfaces: SurfaceSet.parse('MOD'),
  treatmentArea: TreatmentArea.tooth,
  unitFee: fee,
  isAlternative: alternative,
  alternativeGroup: alternative ? 'g1' : null,
);

void main() {
  group('JSON round trips', () {
    _roundTrip(
      'Clinic',
      Clinic(
        id: _clinic,
        name: 'Smile Dental',
        legalName: 'Smile Dental LLP',
        addressLines: const ['1 Jubilee Hills'],
        city: 'Hyderabad',
        stateCode: '36',
        pincode: '500033',
        phone: '04012345678',
        gstin: '36AAAAA0000A1Z5',
        upiVpa: 'smile@upi',
        createdAt: _t0,
        updatedAt: _t1,
      ),
      (c) => c.toJson(),
      Clinic.fromJson,
    );
    _roundTrip(
      'Chair',
      const Chair(id: 'chair-1', clinicId: _clinic, name: 'Chair 1'),
      (c) => c.toJson(),
      Chair.fromJson,
    );
    _roundTrip(
      'ClinicMember',
      ClinicMember(
        id: _provider,
        clinicId: _clinic,
        displayName: 'Dr. Rao',
        role: ClinicRole.ownerDentist,
        registrationNumber: 'A-1234',
        registrationCouncil: 'TSDC',
        qualifications: const ['BDS', 'MDS'],
        phone: '9000000000',
        feeSharePercent: 40,
        createdAt: _t0,
        updatedAt: _t1,
      ),
      (m) => m.toJson(),
      ClinicMember.fromJson,
    );
    _roundTrip('Patient', _patient0(), (p) => p.toJson(), Patient.fromJson);
    _roundTrip(
      'Appointment',
      Appointment(
        id: 'appt-1',
        clinicId: _clinic,
        patientId: _patient,
        providerId: _provider,
        chairId: 'chair-1',
        startsAt: _t0,
        endsAt: _t1,
        reason: 'Pain UL6',
        plannedProcedureIds: const ['proc-1'],
        source: AppointmentSource.whatsapp,
        confirmedAt: _t0,
        createdAt: _t0,
        updatedAt: _t1,
      ),
      (a) => a.toJson(),
      Appointment.fromJson,
    );
    _roundTrip(
      'Visit',
      Visit(
        id: 'visit-1',
        clinicId: _clinic,
        patientId: _patient,
        providerId: _provider,
        appointmentId: 'appt-1',
        startedAt: _t0,
        chiefComplaint: 'Pain',
        createdAt: _t0,
        updatedAt: _t1,
      ),
      (v) => v.toJson(),
      Visit.fromJson,
    );
    _roundTrip(
      'ToothStateRecord',
      ToothStateRecord(
        id: 'ts-1',
        clinicId: _clinic,
        patientId: _patient,
        tooth: ToothId.parse('55+1'),
        state: ToothState.supernumerary,
        effectiveFrom: _t0,
        source: ToothStateSource.clinician,
        recordedBy: _provider,
        createdAt: _t0,
      ),
      (r) => r.toJson(),
      ToothStateRecord.fromJson,
    );
    _roundTrip(
      'Finding',
      Finding(
        id: 'f-1',
        clinicId: _clinic,
        patientId: _patient,
        tooth: ToothId.parse('26'),
        surfaces: SurfaceSet.parse('MO'),
        icd10Code: 'K02.1',
        description: 'Caries of dentine',
        icdas: IcdasCode.distinctCavity,
        recordedAt: _t0,
        recordedBy: _provider,
        createdAt: _t0,
        updatedAt: _t1,
      ),
      (f) => f.toJson(),
      Finding.fromJson,
    );
    _roundTrip(
      'CatalogItem',
      const CatalogItem(
        id: 'cat-1',
        code: 'RCT',
        name: 'Root canal treatment',
        laymanName: 'Root canal',
        category: ProcedureCategory.endodontic,
        treatmentArea: TreatmentArea.tooth,
        defaultFee: Money.rupees(4500),
        feeMin: Money.rupees(3500),
        feeMax: Money.rupees(7000),
        sacHsnCode: '999312',
        durationMinutes: 60,
        stages: ['Access', 'BMP', 'Obturation'],
        recallInterval: RecallInterval.sixMonths,
        consentTemplateCode: 'rct',
        requiresPreOpRadiograph: true,
        externalCodes: {'cdt': 'D3330'},
      ),
      (c) => c.toJson(),
      CatalogItem.fromJson,
    );
    _roundTrip(
      'ProcedureRecord',
      ProcedureRecord(
        id: 'proc-1',
        clinicId: _clinic,
        patientId: _patient,
        catalogItemId: 'cat-1',
        code: 'RCT',
        name: 'Root canal treatment',
        tooth: ToothId.parse('26'),
        surfaces: const SurfaceSet.empty(),
        treatmentArea: TreatmentArea.tooth,
        status: ProcedureStatus.inProgress,
        providerId: _provider,
        fee: const Money.rupees(4500),
        discount: const Money.rupees(500),
        stageIndex: 1,
        totalStages: 3,
        stageNames: const ['Access', 'BMP', 'Obturation'],
        startedAt: _t0,
        createdAt: _t0,
        updatedAt: _t1,
      ),
      (p) => p.toJson(),
      ProcedureRecord.fromJson,
    );
    _roundTrip(
      'TreatmentPlan',
      TreatmentPlan(
        id: 'plan-1',
        clinicId: _clinic,
        patientId: _patient,
        title: 'Full mouth rehab',
        phases: const [PlanPhase(index: 0, name: 'Pain relief')],
        presentedAt: _t0,
        createdBy: _provider,
        createdAt: _t0,
        updatedAt: _t1,
      ),
      (p) => p.toJson(),
      TreatmentPlan.fromJson,
    );
    _roundTrip(
      'TreatmentPlanLine',
      _planLine('l-1', 'RCT', const Money.rupees(4500)),
      (l) => l.toJson(),
      TreatmentPlanLine.fromJson,
    );
    _roundTrip(
      'Estimate',
      Estimate(
        id: 'est-1',
        clinicId: _clinic,
        patientId: _patient,
        planId: 'plan-1',
        version: 2,
        number: 'DRAFT-EST-202610-0001',
        lines: [
          EstimateLine(
            description: 'Root canal',
            tooth: ToothId.parse('26'),
            unitFee: const Money.rupees(4500),
            gstClass: GstClass.exemptHealthcare,
            lineTotal: const Money.rupees(4500),
          ),
        ],
        subtotal: const Money.rupees(4500),
        discountTotal: const Money.zero(),
        taxTotal: const Money.zero(),
        grandTotal: const Money.rupees(4500),
        issuedAt: _t0,
        issuedBy: _provider,
        justification: 'Added crown',
        status: EstimateStatus.issued,
        createdAt: _t0,
      ),
      (e) => e.toJson(),
      Estimate.fromJson,
    );
    _roundTrip(
      'ConsentRecord',
      ConsentRecord(
        id: 'con-1',
        clinicId: _clinic,
        patientId: _patient,
        templateCode: 'rct',
        templateVersionHash: 'abc',
        languageCode: 'te',
        procedureIds: const ['proc-1'],
        teeth: [ToothId.parse('26')],
        renderedText: 'I consent...',
        signerName: 'Anil Kumar',
        signerRelation: SignerRelation.self,
        otpVerified: true,
        signedAt: _t0,
        dentistId: _provider,
        dentistRegistrationNumber: 'A-1234',
        deviceId: 'dev-1',
        documentHash: 'deadbeef',
        createdAt: _t0,
      ),
      (c) => c.toJson(),
      ConsentRecord.fromJson,
    );
    _roundTrip(
      'DataConsent',
      DataConsent(
        id: 'dc-1',
        clinicId: _clinic,
        patientId: _patient,
        purpose: DataPurpose.appointmentReminders,
        granted: true,
        noticeVersion: 'v1',
        languageCode: 'en',
        channel: 'inClinic',
        grantedAt: _t0,
        createdAt: _t0,
      ),
      (d) => d.toJson(),
      DataConsent.fromJson,
    );
    _roundTrip(
      'ClinicalNote',
      ClinicalNote(
        id: 'note-1',
        clinicId: _clinic,
        patientId: _patient,
        visitId: 'visit-1',
        authorId: _provider,
        chiefComplaint: 'Pain',
        finalDiagnosis: 'Irreversible pulpitis 26',
        signedAt: _t1,
        createdAt: _t0,
        updatedAt: _t1,
      ),
      (n) => n.toJson(),
      ClinicalNote.fromJson,
    );
    _roundTrip(
      'MedicalHistory',
      MedicalHistory(
        id: 'mh-1',
        clinicId: _clinic,
        patientId: _patient,
        recordedAt: _t0,
        recordedBy: _provider,
        allergies: const [
          AllergyEntry(
            substance: 'Amoxicillin',
            reaction: 'rash',
            severity: AllergySeverity.moderate,
            allergyGroup: 'penicillin',
          ),
        ],
        medications: const ['Metformin'],
        diabetes: true,
        hba1c: 7.5,
        antiresorptive: 'Alendronate',
        antiresorptiveRoute: AntiresorptiveRoute.oral,
        antiresorptiveYears: 2,
        smoking: SmokingStatus.former,
        createdAt: _t0,
      ),
      (m) => m.toJson(),
      MedicalHistory.fromJson,
    );
    _roundTrip(
      'PerioExam',
      PerioExam(
        id: 'perio-1',
        clinicId: _clinic,
        patientId: _patient,
        examinedAt: _t0,
        examinerId: _provider,
        sites: [
          PerioSiteReading(
            tooth: ToothId.parse('16'),
            site: PerioSite.mesioBuccal,
            probingDepth: 5,
            gingivalMargin: -1,
            bleeding: true,
          ),
        ],
        teeth: [
          PerioToothReading(
            tooth: ToothId.parse('16'),
            mobility: MobilityGrade.grade1,
            furcation: FurcationGrade.grade2,
          ),
        ],
        bpe: const {
          Sextant.upperRightPosterior: BpeCode.code3,
          Sextant.lowerAnterior: BpeCode.furcation,
        },
        stage: PeriodontitisStage.stage2,
        grade: PeriodontitisGrade.gradeB,
        createdAt: _t0,
      ),
      (p) => p.toJson(),
      PerioExam.fromJson,
    );
    _roundTrip(
      'Drug',
      Drug(
        id: 'drug-1',
        genericName: 'Amoxicillin',
        brandNames: const ['Mox'],
        strength: '500 mg',
        form: DrugForm.capsule,
        schedule: DrugSchedule.h1,
        scheduleEffectiveFrom: DateTime.utc(2014, 3, 1),
        category: 'antibiotic',
        defaultDose: '1 cap',
        defaultFrequency: 'TDS',
        defaultDurationDays: 5,
        route: 'oral',
        allergyGroup: 'penicillin',
        pregnancyCaution: false,
      ),
      (d) => d.toJson(),
      Drug.fromJson,
    );
    _roundTrip(
      'Prescription',
      Prescription(
        id: 'rx-1',
        clinicId: _clinic,
        patientId: _patient,
        prescriberId: _provider,
        prescriberName: 'Dr. Rao',
        prescriberRegistrationNumber: 'A-1234',
        prescriberQualifications: const ['BDS'],
        issuedAt: _t0,
        diagnosis: 'Pulpitis',
        lines: const [
          PrescriptionLine(
            drugId: 'drug-1',
            genericName: 'Amoxicillin',
            strength: '500 mg',
            form: DrugForm.capsule,
            dose: '1 cap',
            frequency: 'TDS',
            durationDays: 5,
            quantity: 15,
            route: 'oral',
            schedule: DrugSchedule.h1,
          ),
        ],
        verificationCode: 'K7Q2',
        createdAt: _t0,
      ),
      (r) => r.toJson(),
      Prescription.fromJson,
    );
    _roundTrip(
      'ImageRecord',
      ImageRecord(
        id: 'img-1',
        clinicId: _clinic,
        patientId: _patient,
        kind: ImageKind.periapical,
        filePath: '/x/img.jpg',
        capturedAt: _t0,
        teeth: [ToothId.parse('26'), ToothId.parse('27')],
        isPreOperative: true,
        procedureId: 'proc-1',
        createdAt: _t0,
      ),
      (i) => i.toJson(),
      ImageRecord.fromJson,
    );
    _roundTrip(
      'Lab',
      const Lab(
        id: 'lab-1',
        clinicId: _clinic,
        name: 'Precision Dental Lab',
        phone: '9111111111',
        turnaroundDays: {'crownZirconia': 5},
      ),
      (l) => l.toJson(),
      Lab.fromJson,
    );
    _roundTrip(
      'LabCase',
      LabCase(
        id: 'case-1',
        clinicId: _clinic,
        patientId: _patient,
        procedureId: 'proc-1',
        labId: 'lab-1',
        caseType: LabCaseType.crownZirconia,
        teeth: [ToothId.parse('26')],
        shade: 'A2',
        labFee: const Money.rupees(2500),
        status: LabCaseStatus.sent,
        createdAt: _t0,
        sentAt: _t0,
        dueAt: _t1,
        updatedAt: _t1,
      ),
      (c) => c.toJson(),
      LabCase.fromJson,
    );
    _roundTrip(
      'ImplantRecord',
      ImplantRecord(
        id: 'imp-1',
        clinicId: _clinic,
        patientId: _patient,
        tooth: ToothId.parse('36'),
        brand: 'Osstem',
        diameterMm: 4.5,
        lengthMm: 10,
        lotNumber: 'LOT123',
        placedAt: _t0,
        insertionTorqueNcm: 35,
        createdAt: _t0,
        updatedAt: _t1,
      ),
      (i) => i.toJson(),
      ImplantRecord.fromJson,
    );
    _roundTrip(
      'Invoice',
      computeInvoiceTotals(
        _invoice('inv-1', _t0, const Money.zero(), const Money.zero()).copyWith(
          lines: [
            _line('a', const Money.rupees(1000), GstClass.cosmeticTaxable, 18),
          ],
          dentistId: _provider,
          dentistName: 'Dr. Rao',
          dentistQualifications: const ['BDS', 'MDS'],
          dentistRegistrationNumber: 'A-1234',
          dentistRegistrationCouncil: 'TSDC',
        ),
      ),
      (i) => i.toJson(),
      Invoice.fromJson,
    );
    _roundTrip(
      'Payment',
      Payment(
        id: 'pay-1',
        clinicId: _clinic,
        patientId: _patient,
        invoiceId: 'inv-1',
        amount: const Money.rupees(1000),
        method: PaymentMethod.card,
        gatewayToken: 'tok_x',
        cardLast4: '4242',
        cardBrand: 'Visa',
        receivedAt: _t0,
        receivedBy: _provider,
        createdAt: _t0,
      ),
      (p) => p.toJson(),
      Payment.fromJson,
    );
    _roundTrip(
      'Adjustment',
      Adjustment(
        id: 'adj-1',
        clinicId: _clinic,
        patientId: _patient,
        type: AdjustmentType.discount,
        amount: const Money.rupees(200),
        reason: 'Senior citizen',
        approvedBy: _provider,
        createdAt: _t0,
      ),
      (a) => a.toJson(),
      Adjustment.fromJson,
    );
    _roundTrip(
      'LedgerEntry',
      LedgerEntry(
        id: 'le-1',
        clinicId: _clinic,
        patientId: _patient,
        entryType: LedgerEntryType.payment,
        amount: const Money.rupees(-1000),
        referenceId: 'pay-1',
        occurredAt: _t0,
        description: 'Card payment',
      ),
      (l) => l.toJson(),
      LedgerEntry.fromJson,
    );
    _roundTrip(
      'Recall',
      Recall(
        id: 'rec-1',
        clinicId: _clinic,
        patientId: _patient,
        type: RecallType.hygiene,
        triggeredByProcedureId: 'proc-1',
        dueAt: _t1,
        interval: RecallInterval.sixMonths,
        estimatedValue: const Money.rupees(800),
        createdAt: _t0,
        updatedAt: _t1,
      ),
      (r) => r.toJson(),
      Recall.fromJson,
    );
    _roundTrip(
      'MessageLog',
      MessageLog(
        id: 'msg-1',
        clinicId: _clinic,
        patientId: _patient,
        channel: MessageChannel.whatsapp,
        category: MessageCategory.utility,
        templateCode: 'appt_reminder_24h',
        toPhone: '9000000001',
        variables: const {'1': 'Anil', '2': '10:00'},
        renderedPreview: 'Hi Anil, reminder 10:00',
        status: MessageStatus.delivered,
        costPaise: 1150,
        createdAt: _t0,
        sentAt: _t0,
        deliveredAt: _t1,
      ),
      (m) => m.toJson(),
      MessageLog.fromJson,
    );
    _roundTrip(
      'SterilisationCycle',
      SterilisationCycle(
        id: 'ster-1',
        clinicId: _clinic,
        cycleNumber: '2026-0412',
        autoclaveName: 'Autoclave A',
        cycledAt: _t0,
        cycleType: SterilisationCycleType.classB,
        temperatureC: 134,
        pressureKpa: 210.5,
        durationMinutes: 18,
        biologicalIndicatorResult: BiologicalIndicatorResult.pass,
        operatorId: _provider,
        createdAt: _t0,
      ),
      (s) => s.toJson(),
      SterilisationCycle.fromJson,
    );
    _roundTrip(
      'Licence',
      Licence(
        id: 'lic-1',
        clinicId: _clinic,
        kind: LicenceKind.aerbRegistration,
        identifier: 'AERB/123',
        expiresAt: DateTime.utc(2027, 1, 1),
        createdAt: _t0,
        updatedAt: _t1,
      ),
      (l) => l.toJson(),
      Licence.fromJson,
    );
    _roundTrip(
      'AuditEvent',
      AuditEvent(
        id: 'audit-1',
        clinicId: _clinic,
        actorId: _provider,
        action: AuditAction.statusChange,
        entityType: 'ProcedureRecord',
        entityId: 'proc-1',
        before: const {'status': 'planned'},
        after: const {'status': 'completed', 'n': 1},
        deviceId: 'dev-1',
        occurredAt: _t0,
      ),
      (a) => a.toJson(),
      AuditEvent.fromJson,
    );
  });

  group('Patient', () {
    final asOf = DateTime.utc(2026, 10, 18);
    test('isMinor from DOB and from approximate age', () {
      expect(_patient0(dob: DateTime.utc(2015, 1, 1)).isMinor(asOf), isTrue);
      expect(_patient0(dob: DateTime.utc(1990, 1, 1)).isMinor(asOf), isFalse);
      final approx = Patient(
        id: 'p',
        clinicId: _clinic,
        patientNumber: 'P-2',
        firstName: 'Kid',
        phone: '9',
        approxAgeYears: 16,
        ageRecordedAt: DateTime.utc(2023, 10, 18),
        createdAt: _t0,
        updatedAt: _t0,
      );
      expect(approx.ageYears(asOf), closeTo(19, 0.05));
      expect(approx.isMinor(asOf), isFalse);
      expect(approx.copyWith(ageRecordedAt: asOf).isMinor(asOf), isTrue);
    });

    test('requiresGuardian only for minors without a guardian', () {
      final minor = _patient0(dob: DateTime.utc(2015, 1, 1));
      expect(minor.requiresGuardian(asOf), isTrue);
      final withGuardian = _patient0(
        dob: DateTime.utc(2015, 1, 1),
        guardianName: 'Sita',
        guardianPhone: '9888888888',
      );
      expect(withGuardian.requiresGuardian(asOf), isFalse);
      expect(_patient0().requiresGuardian(asOf), isFalse);
    });

    test('messagingPhone routes to the guardian for a minor', () {
      final minor = _patient0(
        dob: DateTime.utc(2015, 1, 1),
        guardianName: 'Sita',
        guardianPhone: '9888888888',
      );
      expect(minor.messagingPhone(asOf), '9888888888');
      final adult = _patient0(guardianPhone: '9888888888');
      expect(adult.messagingPhone(asOf), '9000000001');
      expect(_patient0().displayName, 'Anil Kumar');
    });
  });

  test('currentToothStates picks the latest record per tooth', () {
    ToothStateRecord rec(String id, String tooth, ToothState s, int year) =>
        ToothStateRecord(
          id: id,
          clinicId: _clinic,
          patientId: _patient,
          tooth: ToothId.parse(tooth),
          state: s,
          effectiveFrom: DateTime.utc(year),
          source: ToothStateSource.clinician,
          recordedBy: _provider,
          createdAt: DateTime.utc(year),
        );
    final states = currentToothStates([
      rec('c', '16', ToothState.extracted, 2025),
      rec('a', '16', ToothState.present, 2020),
      rec('b', '26', ToothState.present, 2020),
    ]);
    expect(states[ToothId.parse('16')], ToothState.extracted);
    expect(states[ToothId.parse('26')], ToothState.present);
    expect(states.length, 2);
  });

  group('Invoice dentist', () {
    test('withDentist freezes the member; drafts have no dentist', () {
      final draft = _invoice(
        'inv-d',
        _t0,
        const Money.zero(),
        const Money.zero(),
        status: InvoiceStatus.draft,
      );
      expect(draft.hasRegisteredDentist, isFalse);
      final member = ClinicMember(
        id: 'member-9',
        clinicId: _clinic,
        displayName: 'Dr. Rao',
        role: ClinicRole.associateDentist,
        registrationNumber: 'B-77',
        registrationCouncil: 'KSDC',
        qualifications: const ['BDS'],
        phone: '9000000000',
        createdAt: _t0,
        updatedAt: _t0,
      );
      final issued = draft.withDentist(member);
      expect(issued.dentistId, 'member-9');
      expect(issued.dentistName, 'Dr. Rao');
      expect(issued.dentistQualifications, ['BDS']);
      expect(issued.dentistRegistrationNumber, 'B-77');
      expect(issued.dentistRegistrationCouncil, 'KSDC');
      expect(issued.hasRegisteredDentist, isTrue);
      // The issuer is unchanged: who raised the bill is a separate fact.
      expect(issued.issuedBy, _provider);
      expect(
        issued
            .withDentist(member.copyWith(registrationNumber: ''))
            .hasRegisteredDentist,
        isFalse,
      );
      // Legacy JSON without the dentist fields still parses.
      final json = issued.toJson()
        ..remove('dentistId')
        ..remove('dentistName')
        ..remove('dentistQualifications')
        ..remove('dentistRegistrationNumber')
        ..remove('dentistRegistrationCouncil');
      final legacy = Invoice.fromJson(json);
      expect(legacy.dentistId, isNull);
      expect(legacy.dentistQualifications, isEmpty);
      expect(legacy.hasRegisteredDentist, isFalse);
    });
  });

  group('Invoice maths', () {
    test('computeInvoiceTotals: exempt line plus 18% line', () {
      final inv = computeInvoiceTotals(
        _invoice('i', _t0, const Money.zero(), const Money.zero()).copyWith(
          lines: [
            _line(
              'rct',
              const Money.rupees(1500),
              GstClass.exemptHealthcare,
              0,
            ),
            _line(
              'bleach',
              const Money.rupees(1000),
              GstClass.cosmeticTaxable,
              18,
            ),
          ],
        ),
      );
      expect(inv.lines[0].taxAmount, const Money.zero());
      expect(inv.lines[0].lineTotal, const Money.rupees(1500));
      expect(inv.lines[1].taxableValue, const Money.rupees(1000));
      expect(inv.lines[1].taxAmount, const Money.rupees(180));
      expect(inv.lines[1].lineTotal, const Money.rupees(1180));
      expect(inv.subtotal, const Money.rupees(2500));
      expect(inv.discountTotal, const Money.zero());
      expect(inv.taxableTotal, const Money.rupees(2500));
      expect(inv.taxTotal, const Money.rupees(180));
      expect(inv.grandTotal, const Money.rupees(2680));
      expect(inv.balance, const Money.rupees(2680));
    });

    test('computeInvoiceTotals applies quantity and discount before tax', () {
      final inv = computeInvoiceTotals(
        _invoice('i', _t0, const Money.zero(), const Money.zero()).copyWith(
          lines: [
            _line(
              'x',
              const Money.rupees(500),
              GstClass.goods,
              5,
              discount: const Money.rupees(100),
            ).copyWith(quantity: 2),
          ],
        ),
      );
      expect(inv.lines.single.taxableValue, const Money.rupees(900));
      expect(inv.lines.single.taxAmount, const Money.rupees(45));
      expect(inv.subtotal, const Money.rupees(1000));
      expect(inv.discountTotal, const Money.rupees(100));
      expect(inv.grandTotal, const Money.rupees(945));
    });

    test('suggestDocumentType covers all four branches', () {
      expect(
        suggestDocumentType(
          clinicGstRegistered: false,
          lineClasses: [GstClass.cosmeticTaxable],
        ),
        InvoiceDocumentType.receipt,
      );
      expect(
        suggestDocumentType(
          clinicGstRegistered: true,
          lineClasses: [GstClass.exemptHealthcare, GstClass.exemptHealthcare],
        ),
        InvoiceDocumentType.billOfSupply,
      );
      expect(
        suggestDocumentType(
          clinicGstRegistered: true,
          lineClasses: [GstClass.exemptHealthcare, GstClass.goods],
        ),
        InvoiceDocumentType.invoiceCumBillOfSupply,
      );
      expect(
        suggestDocumentType(
          clinicGstRegistered: true,
          lineClasses: [GstClass.cosmeticTaxable, GstClass.standardTaxable],
        ),
        InvoiceDocumentType.taxInvoice,
      );
    });

    test('isDraftNumber', () {
      expect(
        _invoice(
          'i',
          _t0,
          const Money.zero(),
          const Money.zero(),
        ).copyWith(number: 'DRAFT-INV-202610-0001').isDraftNumber,
        isTrue,
      );
      expect(
        _invoice(
          'i',
          _t0,
          const Money.zero(),
          const Money.zero(),
        ).isDraftNumber,
        isFalse,
      );
    });
  });

  group('Ledger', () {
    test('agingBuckets groups outstanding balances by age', () {
      final asOf = DateTime.utc(2026, 10, 18);
      Invoice aged(String id, int daysAgo, int rupees, {int paid = 0}) =>
          _invoice(
            id,
            asOf.subtract(Duration(days: daysAgo)),
            Money.rupees(rupees),
            Money.rupees(paid),
          );
      final buckets = agingBuckets([
        aged('a', 10, 100),
        aged('b', 45, 200),
        aged('c', 75, 300),
        aged('d', 120, 400),
        aged('e', 120, 400, paid: 400),
        aged('f', 5, 999).copyWith(status: InvoiceStatus.draft),
        aged('g', 5, 999).copyWith(status: InvoiceStatus.voided),
      ], asOf);
      expect(buckets.keys.toList(), ['0-30', '31-60', '61-90', '90+']);
      expect(buckets['0-30'], const Money.rupees(100));
      expect(buckets['31-60'], const Money.rupees(200));
      expect(buckets['61-90'], const Money.rupees(300));
      expect(buckets['90+'], const Money.rupees(400));
    });

    test('ledgerBalance sums signed amounts', () {
      LedgerEntry e(String id, LedgerEntryType t, int paise) => LedgerEntry(
        id: id,
        clinicId: _clinic,
        patientId: _patient,
        entryType: t,
        amount: Money.paise(paise),
        referenceId: id,
        occurredAt: _t0,
        description: id,
      );
      expect(
        ledgerBalance([
          e('1', LedgerEntryType.charge, 268000),
          e('2', LedgerEntryType.payment, -100000),
          e('3', LedgerEntryType.adjustment, -20000),
        ]),
        const Money.rupees(1480),
      );
      expect(ledgerBalance(const []), const Money.zero());
    });
  });

  group('computeDueDate', () {
    final friday = DateTime(2026, 10, 16);
    test('fixture is a Friday', () {
      expect(friday.weekday, DateTime.friday);
    });
    test('skips Sundays', () {
      expect(computeDueDate(friday, 3), DateTime(2026, 10, 20));
    });
    test('skips a holiday too', () {
      expect(
        computeDueDate(friday, 3, holidays: {DateTime(2026, 10, 19)}),
        DateTime(2026, 10, 21),
      );
    });
    test('respects a different weekly off', () {
      expect(
        computeDueDate(friday, 2, weeklyOffWeekday: DateTime.saturday),
        DateTime(2026, 10, 19),
      );
    });
  });

  group('MedicalHistory', () {
    MedicalHistory mh({
      String? antiresorptive,
      AntiresorptiveRoute? route,
      num? years,
      bool oncology = false,
      bool diabetes = false,
      num? hba1c,
      List<AllergyEntry> allergies = const [],
      String? anticoagulant,
      bool pregnant = false,
    }) => MedicalHistory(
      id: 'mh',
      clinicId: _clinic,
      patientId: _patient,
      recordedAt: _t0,
      recordedBy: _provider,
      antiresorptive: antiresorptive,
      antiresorptiveRoute: route,
      antiresorptiveYears: years,
      oncologyTreatment: oncology,
      diabetes: diabetes,
      hba1c: hba1c,
      allergies: allergies,
      anticoagulant: anticoagulant,
      pregnant: pregnant,
      createdAt: _t0,
    );

    test('mronjRisk tiers', () {
      expect(mh().mronjRisk, MronjRisk.none);
      expect(
        mh(
          antiresorptive: 'Alendronate',
          route: AntiresorptiveRoute.oral,
          years: 3,
        ).mronjRisk,
        MronjRisk.low,
      );
      expect(
        mh(
          antiresorptive: 'Alendronate',
          route: AntiresorptiveRoute.oral,
          years: 6,
        ).mronjRisk,
        MronjRisk.higher,
      );
      expect(
        mh(
          antiresorptive: 'Zoledronate',
          route: AntiresorptiveRoute.intravenous,
          years: 1,
        ).mronjRisk,
        MronjRisk.higher,
      );
      expect(
        mh(
          antiresorptive: 'Denosumab',
          route: AntiresorptiveRoute.oral,
          oncology: true,
        ).mronjRisk,
        MronjRisk.higher,
      );
    });

    test('redFlags', () {
      expect(mh().redFlags, isEmpty);
      expect(mh(diabetes: true, hba1c: 7.9).redFlags, isEmpty);
      expect(mh(diabetes: true, hba1c: 8).redFlags, [
        RedFlag.uncontrolledDiabetes,
      ]);
      final flags = mh(
        anticoagulant: 'Warfarin',
        antiresorptive: 'Alendronate',
        route: AntiresorptiveRoute.oral,
        pregnant: true,
        allergies: const [
          AllergyEntry(
            substance: 'Lignocaine',
            allergyGroup: 'localAnaesthetic',
          ),
          AllergyEntry(substance: 'Amoxicillin', allergyGroup: 'penicillin'),
        ],
      ).redFlags;
      expect(flags, [
        RedFlag.anticoagulant,
        RedFlag.mronj,
        RedFlag.pregnancy,
        RedFlag.allergyLocalAnaesthetic,
        RedFlag.allergyPenicillin,
      ]);
    });
  });

  group('Treatment plan', () {
    final plan = TreatmentPlan(
      id: 'plan-1',
      clinicId: _clinic,
      patientId: _patient,
      title: 'Plan',
      createdBy: _provider,
      createdAt: _t0,
      updatedAt: _t0,
    );
    final lines = [
      _planLine('l-1', 'RCT', const Money.rupees(4500)),
      _planLine('l-2', 'CROWN', const Money.rupees(6000)),
      _planLine('l-3', 'CROWN-Z', const Money.rupees(9000), alternative: true),
    ];

    test('planSubtotal excludes alternatives by default', () {
      expect(planSubtotal(lines), const Money.rupees(10500));
      expect(
        planSubtotal(lines, includeAlternatives: true),
        const Money.rupees(19500),
      );
    });

    test('computePlanSnapshotHash is order independent and content bound', () {
      final h1 = computePlanSnapshotHash(plan, lines);
      final h2 = computePlanSnapshotHash(plan, lines.reversed);
      expect(h1, h2);
      expect(h1, hasLength(64));
      final changed = [
        lines[0].copyWith(unitFee: const Money.rupees(4600)),
        lines[1],
        lines[2],
      ];
      expect(computePlanSnapshotHash(plan, changed), isNot(h1));
      expect(
        computePlanSnapshotHash(plan.copyWith(version: 2), lines),
        isNot(h1),
      );
    });
  });

  group('Misc helpers', () {
    test('Appointment.overlaps and duration', () {
      Appointment a(int startMin, int endMin) => Appointment(
        id: '$startMin',
        clinicId: _clinic,
        patientId: _patient,
        providerId: _provider,
        startsAt: _t0.add(Duration(minutes: startMin)),
        endsAt: _t0.add(Duration(minutes: endMin)),
        createdAt: _t0,
        updatedAt: _t0,
      );
      expect(a(0, 30).duration, const Duration(minutes: 30));
      expect(a(0, 30).overlaps(a(15, 45)), isTrue);
      expect(a(0, 30).overlaps(a(30, 60)), isFalse);
    });

    test('ProcedureRecord stage helpers', () {
      final p = ProcedureRecord(
        id: 'p',
        clinicId: _clinic,
        patientId: _patient,
        catalogItemId: 'c',
        code: 'RCT',
        name: 'RCT',
        treatmentArea: TreatmentArea.tooth,
        providerId: _provider,
        fee: const Money.rupees(4500),
        discount: const Money.rupees(500),
        stageIndex: 1,
        totalStages: 3,
        stageNames: const ['Access', 'BMP', 'Obturation'],
        createdAt: _t0,
        updatedAt: _t0,
      );
      expect(p.isMultiSitting, isTrue);
      expect(p.currentStageName, 'BMP');
      expect(p.copyWith(stageNames: const []).currentStageName, 'Stage 2/3');
      expect(p.netFee, const Money.rupees(4000));
    });

    test('Prescription.hasScheduleH1 and Licence.daysToExpiry', () {
      const h1 = PrescriptionLine(
        genericName: 'Amoxicillin',
        strength: '500 mg',
        form: DrugForm.capsule,
        dose: '1',
        frequency: 'TDS',
        durationDays: 5,
        quantity: 15,
        route: 'oral',
        schedule: DrugSchedule.h1,
      );
      final rx = Prescription(
        id: 'rx',
        clinicId: _clinic,
        patientId: _patient,
        prescriberId: _provider,
        prescriberName: 'Dr',
        prescriberRegistrationNumber: 'A',
        issuedAt: _t0,
        lines: const [h1],
        verificationCode: 'X',
        createdAt: _t0,
      );
      expect(rx.hasScheduleH1, isTrue);
      expect(rx.copyWith(lines: const []).hasScheduleH1, isFalse);
      final lic = Licence(
        id: 'l',
        clinicId: _clinic,
        kind: LicenceKind.fireNoc,
        identifier: 'F',
        expiresAt: DateTime.utc(2026, 11, 17),
        createdAt: _t0,
        updatedAt: _t0,
      );
      expect(lic.daysToExpiry(DateTime.utc(2026, 10, 18)), 30);
      expect(lic.copyWith().daysToExpiry(DateTime.utc(2026, 12, 18)), -31);
    });
  });
}
