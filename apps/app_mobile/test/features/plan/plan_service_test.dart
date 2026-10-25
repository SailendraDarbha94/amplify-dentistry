import 'dart:typed_data';

import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/features/consent/consent_model.dart';
import 'package:ampdent_mobile/features/plan/plan_model.dart';
import 'package:ampdent_mobile/features/plan/plan_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../feature_test_env.dart';

void main() {
  late FeatureTestEnv env;
  late PlanService service;
  final now = DateTime.utc(2026, 10, 25, 9);

  setUp(() async {
    env = await FeatureTestEnv.open(withPatient: true);
    await env.repos.catalog.seedGlobalIfEmpty();
    service = PlanService(
      plans: env.repos.treatmentPlans,
      chart: env.repos.chart,
      catalog: env.repos.catalog,
      ctx: testCtx,
    );
  });
  tearDown(() => env.close());

  Future<PlanEditor> planWithRct() async {
    final proc = await env.repos.chart.createProcedure(
      testCtx,
      plannedProcedure(),
    );
    final plan = await service.createPlan(patientId: testPatientId, now: now);
    final editor = PlanEditor(
      plan: plan,
      lines: const [],
    ).addLine(lineFromProcedure(proc, plan: plan));
    return service.save(editor, providerId: testDentistId, now: now);
  }

  test(
    'save links the planned procedure and creates one for catalogue lines',
    () async {
      var editor = await planWithRct();
      expect(editor.lines, hasLength(1));
      final linked = await env.repos.chart.getProcedure('proc-rct');
      expect(linked!.planId, editor.plan.id);
      expect(linked.planLineId, editor.lines.single.id);

      final crown = (await env.repos.catalog.byCode(testClinicId, 'CRN-ZIR'))!;
      editor = editor.addLine(
        lineFromCatalogItem(
          crown,
          plan: editor.plan,
          tooth: ToothId.parse('36'),
          phaseIndex: 1,
        ),
      );
      expect(editor.phases, hasLength(2));
      editor = await service.save(editor, providerId: testDentistId, now: now);
      final procs = await env.repos.chart.proceduresForPatient(testPatientId);
      expect(procs, hasLength(2));
      final crownProc = procs.firstWhere((p) => p.code == 'CRN-ZIR');
      expect(crownProc.status, ProcedureStatus.planned);
      expect(crownProc.fee, crown.defaultFee);
      expect(editor.lines.every((l) => l.procedureId != null), isTrue);
      expect(editor.total, const Money.rupees(5000) + crown.defaultFee);
    },
  );

  test('estimate v2 without justification is blocked', () async {
    final editor = await planWithRct();
    final v1 = await service.issueEstimate(editor.plan.id, now: now);
    expect(v1.version, 1);
    expect(v1.number, startsWith('DRAFT-'));
    expect(v1.grandTotal, const Money.rupees(5000));

    expect(await service.nextEstimateVersion(editor.plan.id), 2);
    expect(PlanService.estimateNeedsJustification(2), isTrue);
    await expectLater(
      service.issueEstimate(editor.plan.id, now: now),
      throwsArgumentError,
    );
    await expectLater(
      service.issueEstimate(editor.plan.id, justification: '   ', now: now),
      throwsArgumentError,
    );
    final v2 = await service.issueEstimate(
      editor.plan.id,
      justification: 'Added crown after discussion',
      now: now,
    );
    expect(v2.version, 2);
    final all = await env.repos.treatmentPlans.estimatesForPlan(editor.plan.id);
    expect(all.first.status, EstimateStatus.superseded);
    expect(all.last.status, EstimateStatus.issued);
  });

  test('accepting a plan sets its procedures to accepted', () async {
    final editor = await planWithRct();
    await service.issueEstimate(editor.plan.id, now: now);
    final patient = (await env.repos.patients.getById(testPatientId))!;
    final signature = Uint8List.fromList(List<int>.generate(32, (i) => i));
    final accepted = await service.accept(
      editor,
      patient: patient,
      signerName: 'Asha Rao',
      relation: SignerRelation.self,
      signaturePng: signature,
      now: now,
    );
    expect(accepted.isAccepted, isTrue);
    expect(accepted.acceptedBySignerName, 'Asha Rao (Patient (self))');
    expect(accepted.acceptedSignatureHash, hasLength(64));
    expect(accepted.snapshotHash, isNotNull);
    final proc = await env.repos.chart.getProcedure('proc-rct');
    expect(proc!.status, ProcedureStatus.accepted);
    expect(proc.acceptedAt, isNotNull);

    final funnel = PlanFunnel.of(
      plan: accepted,
      lines: editor.lines,
      procedures: [proc],
    );
    expect(funnel.accepted, isTrue);
    expect(funnel.scheduled, isFalse);
    expect(funnel.completed, isFalse);
    expect(snapshotIntact(accepted, editor.lines), isTrue);
    expect(
      snapshotIntact(accepted, [
        editor.lines.single.copyWith(unitFee: const Money.rupees(1)),
      ]),
      isFalse,
    );
  });

  test(
    'no written estimate: acceptance needs the patient\'s refusal',
    () async {
      final editor = await planWithRct();
      final patient = (await env.repos.patients.getById(testPatientId))!;
      final signature = Uint8List(4);
      expect(
        await service.estimateGap(editor.plan, editor.lines),
        PlanStrings.estimateRequired,
      );
      await expectLater(
        service.ensureEstimateBeforeTreatment(editor.plan.id),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            PlanStrings.estimateRequired,
          ),
        ),
      );
      await expectLater(
        service.accept(
          editor,
          patient: patient,
          signerName: 'Asha Rao',
          relation: SignerRelation.self,
          signaturePng: signature,
          now: now,
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            PlanStrings.estimateRequired,
          ),
        ),
      );
      expect(
        (await env.repos.treatmentPlans.getPlan(editor.plan.id))!.isAccepted,
        isFalse,
      );
      expect(
        (await env.repos.chart.getProcedure('proc-rct'))!.status,
        ProcedureStatus.planned,
      );

      final accepted = await service.accept(
        editor,
        patient: patient,
        signerName: 'Asha Rao',
        relation: SignerRelation.self,
        signaturePng: signature,
        estimateDeclinedReason: 'Patient did not want a written estimate',
        now: now,
      );
      expect(accepted.isAccepted, isTrue);
      expect(
        accepted.estimateDeclinedReason,
        'Patient did not want a written estimate',
      );
      expect(
        await service.estimateGap(accepted, editor.lines),
        isNull,
        reason: 'the recorded refusal satisfies the gate',
      );
      final events = await env.repos.audit.forEntity(
        testClinicId,
        'TreatmentPlan',
        editor.plan.id,
      );
      expect(events.last.reason, contains('declined a written estimate'));
    },
  );

  test('an estimate is bound to the plan version and snapshot hash', () async {
    final editor = await planWithRct();
    final v1 = await service.issueEstimate(editor.plan.id, now: now);
    expect(v1.planVersion, editor.plan.version);
    expect(
      v1.planSnapshotHash,
      computePlanSnapshotHash(editor.plan, editor.lines),
    );
    expect(estimateMatchesPlan(v1, editor.plan, editor.lines), isTrue);
    final changed = [
      editor.lines.single.copyWith(unitFee: const Money.rupees(1)),
    ];
    expect(estimateMatchesPlan(v1, editor.plan, changed), isFalse);
    expect(estimateMatchesPlan(v1.copyWith(), editor.plan, changed), isFalse);
    // An estimate issued before hashes existed cannot be verified; being a
    // later version it is also the one `latestEstimate` picks.
    final legacy = Estimate(
      id: 'legacy',
      clinicId: testClinicId,
      patientId: testPatientId,
      planId: editor.plan.id,
      version: 2,
      justification: 'Issued before plan binding existed',
      number: 'DRAFT-EST-2',
      subtotal: const Money.zero(),
      discountTotal: const Money.zero(),
      taxTotal: const Money.zero(),
      grandTotal: const Money.zero(),
      issuedAt: now,
      issuedBy: testDentistId,
      status: EstimateStatus.issued,
      createdAt: now,
    );
    expect(estimateMatchesPlan(legacy, editor.plan, changed), isNull);
    expect(latestEstimate([legacy, v1])?.id, 'legacy');
    expect(latestEstimate([v1])?.id, v1.id);
    expect(latestEstimate(const []), isNull);
  });

  test('a patient of unknown age cannot accept', () async {
    final editor = await planWithRct();
    await service.issueEstimate(editor.plan.id, now: now);
    final unknown = Patient(
      id: 'p-unknown',
      clinicId: testClinicId,
      patientNumber: 'P-00009',
      firstName: 'Ravi',
      phone: '+919123456789',
      createdAt: now,
      updatedAt: now,
    );
    await expectLater(
      service.accept(
        editor,
        patient: unknown,
        signerName: 'Ravi',
        relation: SignerRelation.self,
        signaturePng: Uint8List(4),
        now: now,
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          ConsentStrings.ageUnknown,
        ),
      ),
    );
  });

  test(
    'a minor cannot accept for themselves; no signature is refused',
    () async {
      final editor = await planWithRct();
      await service.issueEstimate(editor.plan.id, now: now);
      final minor = (await env.repos.patients.getById(testPatientId))!.copyWith(
        dateOfBirth: DateTime.utc(2016, 1, 1),
        guardianName: 'Lakshmi',
        guardianPhone: '+919123456789',
      );
      await expectLater(
        service.accept(
          editor,
          patient: minor,
          signerName: 'Kiran',
          relation: SignerRelation.self,
          signaturePng: Uint8List(4),
          now: now,
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            ConsentStrings.minorCannotSelfSign,
          ),
        ),
      );
      await expectLater(
        service.accept(
          editor,
          patient: minor,
          signerName: 'Lakshmi',
          relation: SignerRelation.parent,
          now: now,
        ),
        throwsStateError,
      );
      final ok = await service.accept(
        editor,
        patient: minor,
        signerName: 'Lakshmi',
        relation: SignerRelation.parent,
        signaturePng: Uint8List(4),
        now: now,
      );
      expect(ok.isAccepted, isTrue);
    },
  );

  test(
    'present stamps presentedAt once and the editor tracks phases',
    () async {
      var editor = await planWithRct();
      final presented = await service.present(editor, now: now);
      expect(presented.presentedAt, now);
      editor = editor.saved(presented, editor.lines);
      final again = await service.present(
        editor,
        now: now.add(const Duration(days: 1)),
      );
      expect(again.presentedAt, now);

      editor = editor.addPhase('Restore').renamePhase(0, 'Relieve pain');
      expect(editor.phases.map((p) => p.name), ['Relieve pain', 'Restore']);
      editor = editor.moveToPhase(editor.lines.single.id, 1);
      expect(editor.lines.single.phaseIndex, 1);
      expect(editor.subtotals, {1: const Money.rupees(5000)});
      editor = editor.setAlternative(
        editor.lines.single.id,
        alternative: true,
        group: 'Plan B',
      );
      expect(editor.total, const Money.zero());
      expect(editor.alternativesTotal, const Money.rupees(5000));
      expect(editor.alternativeGroups, ['Plan B']);
      expect(editor.dirty, isTrue);
    },
  );

  test('fee range warnings follow the catalogue', () async {
    final item = (await env.repos.catalog.byCode(testClinicId, 'RCT-MOL'))!;
    expect(feeRangeWarning(item.feeMin, item), isNull);
    expect(feeRangeWarning(item.feeMax, item), isNull);
    expect(
      feeRangeWarning(item.feeMin - const Money.rupees(1), item),
      startsWith('Below catalogue minimum'),
    );
    expect(
      feeRangeWarning(item.feeMax + const Money.rupees(1), item),
      startsWith('Above catalogue maximum'),
    );
    expect(feeRangeWarning(const Money.rupees(1), null), isNull);
    expect(gstClassLabel(GstClass.exemptHealthcare), 'GST exempt');
    expect(
      gstClassLabel(GstClass.cosmeticTaxable, ratePercent: 18),
      'Cosmetic, GST 18%',
    );
  });
}
