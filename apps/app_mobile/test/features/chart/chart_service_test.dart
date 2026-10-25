import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/features/chart/chart_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'chart_test_support.dart';

void main() {
  late ChartTestEnv env;
  late DateTime now;

  ChartService service() => ChartService(
    chart: env.repos.chart,
    recalls: env.repos.recalls,
    clinics: env.repos.clinics,
    ctx: testCtx,
    clock: () => now,
  );

  setUp(() async {
    env = await ChartTestEnv.open();
    now = DateTime.utc(2026, 10, 25, 9);
  });
  tearDown(() => env.close());

  ToothId t(String fdi) => ToothId.parse(fdi);

  group('seedAgeDefaults', () {
    test('writes the whole seed in one batch and never twice', () async {
      final patient = (await env.repos.patients.getById(testPatientId))!;
      expect(await service().seedAgeDefaults(patient), 52);
      expect(await service().seedAgeDefaults(patient), 0);
      final history = await env.repos.chart.toothStateHistory(testPatientId);
      expect(history, hasLength(52));
      // Same instant on every row: one write, not 52.
      expect(history.map((r) => r.createdAt).toSet(), hasLength(1));
    });

    test('refreshes stale age defaults when a child grows into the next '
        'dentition stage, keeping clinician records', () async {
      // Kiran is 8 at the first chart open: mixed dentition.
      final child = await env.addPatient(
        testPatient(
          id: 'child-1',
          firstName: 'Kiran',
          dateOfBirth: DateTime.utc(2018, 10, 25),
        ),
      );
      expect(await service().seedAgeDefaults(child), 52);
      var states = await env.repos.chart.currentStates('child-1');
      expect(states[t('55')], ToothState.present);
      expect(states[t('15')], ToothState.unerupted);
      expect(states[t('17')], ToothState.unerupted);
      expect(states[t('16')], ToothState.present);

      // The dentist charts 55 as missing (early loss) and 36 as extracted
      // at a later visit.
      now = DateTime.utc(2026, 11, 2, 9);
      await service().setToothState(
        patientId: 'child-1',
        tooth: t('55'),
        state: ToothState.missing,
      );
      await service().setToothState(
        patientId: 'child-1',
        tooth: t('36'),
        state: ToothState.extracted,
        source: ToothStateSource.procedure,
      );

      // Same stage a year later: nothing to refresh.
      now = DateTime.utc(2027, 10, 25, 9);
      expect(await service().seedAgeDefaults(child), 0);

      // Five years on Kiran is 13: permanent dentition.
      now = DateTime.utc(2031, 10, 25, 9);
      final written = await service().seedAgeDefaults(child);
      expect(written, greaterThan(0));
      states = await env.repos.chart.currentStates('child-1');
      expect(states[t('15')], ToothState.present);
      expect(states[t('17')], ToothState.present);
      expect(states[t('65')], ToothState.exfoliated);
      expect(states[t('18')], ToothState.unerupted);
      // Clinician and procedure records win over the refreshed defaults.
      expect(states[t('55')], ToothState.missing);
      expect(states[t('36')], ToothState.extracted);
      final history = await env.repos.chart.toothStateHistory('child-1');
      final refreshed = history
          .where((r) => r.effectiveFrom.isAtSameMomentAs(now))
          .toList();
      expect(refreshed, hasLength(written));
      expect(
        refreshed.every((r) => r.source == ToothStateSource.ageDefault),
        isTrue,
      );
      expect(refreshed.map((r) => r.tooth), isNot(contains(t('55'))));
      expect(refreshed.map((r) => r.tooth), isNot(contains(t('36'))));
      // Teeth whose default did not change were not rewritten.
      expect(refreshed.map((r) => r.tooth), isNot(contains(t('16'))));
      expect(refreshed.map((r) => r.tooth).toSet(), hasLength(written));

      // Idempotent at the new stage.
      expect(await service().seedAgeDefaults(child), 0);
    });
  });

  group('createRecall', () {
    test(
      'falls back to the catalogue interval on the local calendar date',
      () async {
        final scaling = (await env.repos.catalog.byCode(
          testClinicId,
          'SCALING-ADULT',
        ))!;
        // A code without a terminology rule, so the catalogue interval applies.
        final custom = scaling.copyWith(
          code: 'ZZ-CUSTOM-HYGIENE',
          recallInterval: RecallInterval.sixMonths,
        );
        // Late evening UTC: in any zone east of UTC this is already the next
        // local day, and the recall must follow the local date.
        final completedAt = DateTime.utc(2026, 1, 15, 20, 30);
        final p = await env.repos.chart.createProcedure(
          testCtx,
          ProcedureRecord(
            id: 'proc-custom',
            clinicId: testClinicId,
            patientId: testPatientId,
            catalogItemId: custom.id,
            code: custom.code,
            name: custom.name,
            treatmentArea: custom.treatmentArea,
            status: ProcedureStatus.completed,
            providerId: testDentistId,
            fee: custom.defaultFee,
            completedAt: completedAt,
            createdAt: completedAt,
            updatedAt: completedAt,
          ),
        );
        final recall = (await service().createRecall(p, custom))!;
        expect(recall.triggeredByProcedureId, p.id);
        final due = recall.dueAt.toLocal();
        final completedLocal = completedAt.toLocal();
        expect(due.day, completedLocal.day);
        expect(
          (due.year * 12 + due.month) -
              (completedLocal.year * 12 + completedLocal.month),
          RecallInterval.sixMonths.months,
        );
        expect(due.hour, 0);
        expect(due.minute, 0);
      },
    );
  });

  group('tooth state effects', () {
    test('completing an implant removal leaves the site missing', () async {
      final patient = (await env.repos.patients.getById(testPatientId))!;
      await service().seedAgeDefaults(patient);
      now = now.add(const Duration(days: 1));
      final place = (await env.repos.catalog.byCode(
        testClinicId,
        'IMP-PLACE',
      ))!;
      final remove = (await env.repos.catalog.byCode(
        testClinicId,
        'IMP-REMOVE',
      ))!;
      await service().addProcedure(
        patientId: testPatientId,
        item: place,
        tooth: t('36'),
        fee: place.defaultFee,
        status: ProcedureStatus.completed,
        stageIndex: place.stages.isEmpty ? 0 : place.stages.length - 1,
      );
      expect(
        (await env.repos.chart.currentStates(testPatientId))[t('36')],
        ToothState.implant,
      );
      now = now.add(const Duration(days: 90));
      await service().addProcedure(
        patientId: testPatientId,
        item: remove,
        tooth: t('36'),
        fee: remove.defaultFee,
        status: ProcedureStatus.completed,
        stageIndex: remove.stages.isEmpty ? 0 : remove.stages.length - 1,
      );
      expect(
        (await env.repos.chart.currentStates(testPatientId))[t('36')],
        ToothState.missing,
      );
    });
  });
}
