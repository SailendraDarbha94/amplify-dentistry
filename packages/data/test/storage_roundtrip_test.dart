import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_data/ampdent_data.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Every entity goes through its table and comes back with identical JSON,
/// which proves the converters and `@UseRowClass` column mapping.
void main() {
  late TestEnv env;

  setUp(() async => env = await TestEnv.open());
  tearDown(() => env.close());

  test('clinic, chair and member', () async {
    final c = await env.repos.clinics.getClinic(clinicId);
    expect(c!.toJson(), equals(clinic().toJson()));
    expect(c.isGstRegistered, isTrue);
    const chair = Chair(
      id: 'chair-1',
      clinicId: clinicId,
      name: 'Chair 1',
      sortOrder: 2,
      isActive: false,
    );
    await env.repos.clinics.upsertChair(ctx, chair);
    final chairs = await env.repos.clinics.chairs(
      clinicId,
      includeInactive: true,
    );
    expect(chairs.single.toJson(), equals(chair.toJson()));
    final m = await env.repos.clinics.getMember(dentistId);
    expect(m!.toJson(), equals(dentist().toJson()));
    expect(m.feeSharePercent, 40);
  });

  test('dates come back as UTC at millisecond precision', () async {
    final local = DateTime(2026, 10, 18, 14, 30, 15, 123, 456);
    final v = visit().copyWith(startedAt: local);
    await env.repos.appointments.startVisit(ctx, v);
    final stored = await env.repos.appointments.getVisit(v.id);
    expect(stored!.startedAt.isUtc, isTrue);
    expect(
      stored.startedAt,
      DateTime.utc(
        2026,
        10,
        18,
        14,
        30,
        15,
        123,
      ).add(local.timeZoneOffset * -1),
    );
    expect(encodeIsoUtc(local), endsWith('Z'));
    expect(encodeIsoUtc(local).length, '2026-10-18T09:00:15.123Z'.length);
  });

  test('converters round trip edge values', () {
    const money = MoneyConverter();
    expect(
      money.fromSql(money.toSql(const Money.paise(-150))),
      const Money.paise(-150),
    );
    const teeth = ToothListConverter();
    final list = [ToothId.parse('11+1'), ToothId.parse('85')];
    expect(teeth.fromSql(teeth.toSql(list)), list);
    const surfaces = SurfaceSetConverter();
    expect(surfaces.fromSql(''), const SurfaceSet.empty());
    expect(
      surfaces.fromSql(surfaces.toSql(SurfaceSet.parse('DOM'))).code,
      'MOD',
    );
    const bpe = BpeMapConverter();
    final map = {Sextant.lowerAnterior: BpeCode.code2};
    expect(bpe.fromSql(bpe.toSql(map)), map);
    // Legacy rows stored the printed label or '*'; the label still loads and
    // the '*' marker (a flag, not a code) is left out of the code map.
    expect(bpe.fromSql('{"upperAnterior":"3","lowerAnterior":"*"}'), {
      Sextant.upperAnterior: BpeCode.code3,
    });
    const furcation = SextantSetConverter();
    expect(furcation.fromSql('[]'), <Sextant>{});
    expect(
      furcation.fromSql(
        furcation.toSql({Sextant.lowerAnterior, Sextant.upperAnterior}),
      ),
      {Sextant.lowerAnterior, Sextant.upperAnterior},
    );
    const json = JsonObjectConverter();
    expect(json.fromSql(json.toSql({'a': 1, 'b': null})), {'a': 1, 'b': null});
    const date = IsoUtcDateTimeConverter();
    expect(date.toSql(DateTime.utc(2026, 1, 1)), '2026-01-01T00:00:00.000Z');
    expect(
      date.fromSql('2026-01-01T05:30:00.000+05:30'),
      DateTime.utc(2026, 1, 1),
    );
  });

  test(
    'v4 upgrade moves the legacy BPE * code into the furcation flag',
    () async {
      final db = env.db;
      // A pre-v3 row, written when '*' was a BpeCode and the flag column did
      // not exist yet (its default is an empty set).
      await db.customStatement(
        'INSERT INTO perio_exams (id, clinic_id, patient_id, examined_at, '
        'examiner_id, sites, teeth, bpe, bpe_furcation, created_at) VALUES '
        "('perio-legacy', '$clinicId', '$patientId', '${encodeIsoUtc(t0)}', "
        "'$dentistId', '[]', '[]', "
        '\'{"upperAnterior":"3","lowerAnterior":"*","upperRightPosterior":"*"}\', '
        "'[\"upperRightPosterior\"]', '${encodeIsoUtc(t0)}')",
      );
      await db.migrateLegacyBpeFurcation();
      final exam = (await env.repos.perio.getExam('perio-legacy'))!;
      expect(exam.bpe, {Sextant.upperAnterior: BpeCode.code3});
      expect(exam.bpeFurcation, {
        Sextant.lowerAnterior,
        Sextant.upperRightPosterior,
      });
      final raw = await db
          .customSelect("SELECT bpe FROM perio_exams WHERE id = 'perio-legacy'")
          .getSingle();
      expect(raw.read<String>('bpe'), '{"upperAnterior":"code3"}');
    },
  );

  test('settings codec', () {
    final rates = defaultGstRates();
    final back = gstRatesFromJson(gstRatesToJson(rates));
    expect(back.length, 4);
    expect(back.map((r) => r.gstClass), rates.map((r) => r.gstClass));
    expect(back.map((r) => r.ratePercent), rates.map((r) => r.ratePercent));
    expect(counterFromJson(counterToJson(7)), 7);
    expect(counterFromJson(null), 0);
    expect(counterFromJson('"junk"'), 0);
    expect(
      enumSettingFromJson(
        ToothNotation.values,
        enumSettingToJson(ToothNotation.palmer),
        ToothNotation.fdi,
      ),
      ToothNotation.palmer,
    );
    expect(
      enumSettingFromJson(ToothNotation.values, null, ToothNotation.fdi),
      ToothNotation.fdi,
    );
  });

  test('seed mapping', () {
    expect(drugFormFromLabel('tablet'), DrugForm.tablet);
    expect(drugFormFromLabel('oral suspension'), DrugForm.suspension);
    expect(drugFormFromLabel('gargle'), DrugForm.mouthwash);
    expect(drugFormFromLabel('mouth paint'), DrugForm.other);
    expect(drugFormFromLabel('topical gel'), DrugForm.gel);
    expect(seedId('drug', 'AMOX-500'), seedId('drug', 'AMOX-500'));
    expect(seedId('drug', 'AMOX-500'), isNot(seedId('catalog', 'AMOX-500')));
    expect(isValidId(seedId('drug', 'AMOX-500')), isTrue);
  });

  test('every remaining entity round trips', () async {
    final r = env.repos;
    await r.appointments.upsert(ctx, appointment());
    expect(
      (await r.appointments.getById('appt-1'))!.toJson(),
      appointment().toJson(),
    );
    await r.appointments.startVisit(ctx, visit());
    expect(
      (await r.appointments.getVisit('visit-1'))!.toJson(),
      visit().toJson(),
    );
    final ts = toothState('ts-1', '55+1', ToothState.present, t0);
    await r.chart.recordToothState(ctx, ts);
    expect(
      (await r.chart.toothStateHistory(patientId)).single.toJson(),
      ts.toJson(),
    );
    await r.chart.addFinding(ctx, finding());
    expect(
      (await r.chart.getFinding('finding-1'))!.toJson(),
      finding().toJson(),
    );
    await r.chart.createProcedure(ctx, procedure());
    expect(
      (await r.chart.getProcedure('proc-1'))!.toJson(),
      procedure().toJson(),
    );
    await r.treatmentPlans.savePlan(ctx, plan(), [planLine()]);
    expect(
      (await r.treatmentPlans.getPlan('plan-1'))!.toJson(),
      plan().toJson(),
    );
    expect(
      (await r.treatmentPlans.linesForPlan('plan-1')).single.toJson(),
      planLine().toJson(),
    );
    await r.consents.recordConsent(ctx, consent());
    expect(
      (await r.consents.getConsent('consent-1'))!.toJson(),
      consent().toJson(),
    );
    await r.consents.recordDataConsent(ctx, dataConsent());
    expect(
      (await r.consents.dataConsentsForPatient(patientId)).single.toJson(),
      dataConsent().toJson(),
    );
    await r.clinical.saveNote(ctx, note());
    expect((await r.clinical.getNote('note-1'))!.toJson(), note().toJson());
    await r.clinical.recordMedicalHistory(ctx, medicalHistory());
    expect(
      (await r.clinical.latestMedicalHistory(patientId))!.toJson(),
      medicalHistory().toJson(),
    );
    await r.perio.saveExam(ctx, perioExam());
    expect((await r.perio.getExam('perio-1'))!.toJson(), perioExam().toJson());
    expect((await r.perio.getExam('perio-1'))!.bpeFurcation, {
      Sextant.upperRightPosterior,
    });
    await r.prescriptions.upsertDrug(ctx, drug());
    expect(
      (await r.prescriptions.getDrug('drug-1'))!.toJson(),
      drug().toJson(),
    );
    await r.prescriptions.issuePrescription(ctx, prescription());
    expect(
      (await r.prescriptions.getPrescription('rx-1'))!.toJson(),
      prescription().toJson(),
    );
    await r.clinical.addImage(ctx, image());
    expect((await r.clinical.getImage('img-1'))!.toJson(), image().toJson());
    await r.labs.upsertLab(ctx, lab());
    await r.labs.createCase(ctx, labCase());
    expect((await r.labs.getCase('case-1'))!.toJson(), labCase().toJson());
    await r.chart.upsertImplant(ctx, implant());
    expect(
      (await r.chart.implantsForPatient(patientId)).single.toJson(),
      implant().toJson(),
    );
    final inv = computeInvoiceTotals(
      draftInvoice(number: 'DRAFT-INV-202610-0001'),
    );
    await r.billing.saveDraft(ctx, inv);
    expect((await r.billing.getInvoice('inv-1'))!.toJson(), inv.toJson());
    await r.billing.issueInvoice(ctx, 'inv-1');
    await r.billing.recordPayment(ctx, payment());
    expect(
      (await r.billing.paymentsForInvoice('inv-1')).single.toJson(),
      payment().toJson(),
    );
    await r.billing.recordAdjustment(ctx, adjustment());
    expect(
      (await r.billing.adjustmentsForPatient(patientId)).single.toJson(),
      adjustment().toJson(),
    );
    final ledger = await r.billing.ledger(patientId);
    expect(ledger, hasLength(3));
    expect(
      LedgerEntry.fromJson(ledger.first.toJson()).toJson(),
      ledger.first.toJson(),
    );
    await r.recalls.upsert(ctx, recall());
    expect((await r.recalls.getById('recall-1'))!.toJson(), recall().toJson());
    await r.messages.enqueue(ctx, message());
    expect((await r.messages.getById('msg-1'))!.toJson(), message().toJson());
    await r.compliance.recordCycle(ctx, cycle());
    expect(
      (await r.compliance.cycles(clinicId)).single.toJson(),
      cycle().toJson(),
    );
    await r.compliance.upsertLicence(ctx, licence());
    expect(
      (await r.compliance.licences(clinicId)).single.toJson(),
      licence().toJson(),
    );
    final events = await r.audit.forEntity(clinicId, 'Patient', patientId);
    expect(
      AuditEvent.fromJson(events.first.toJson()).toJson(),
      events.first.toJson(),
    );
    expect(events.first.after!['firstName'], 'Anil');
  });
}
