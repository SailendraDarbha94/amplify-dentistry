import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/features/recall/incomplete_treatment.dart';
import 'package:flutter_test/flutter_test.dart';

import 'feature_harness.dart';

void main() {
  final now = harnessNow;

  ProcedureRecord rct({
    String id = 'rct',
    int daysAgo = 45,
    String tooth = '36',
  }) => procedureFixture(
    id: id,
    code: 'RCT-MOL',
    name: 'Root canal treatment, molar',
    status: ProcedureStatus.completed,
    tooth: tooth,
    completedAt: now.subtract(Duration(days: daysAgo)),
  );

  ProcedureRecord crown({
    String tooth = '36',
    ProcedureStatus status = ProcedureStatus.planned,
    String patientId = testPatientId,
  }) => procedureFixture(
    id: 'crown-$tooth-${status.name}',
    code: 'CRN-ZIR',
    name: 'Zirconia crown',
    status: status,
    tooth: tooth,
    patientId: patientId,
  );

  group('RCT without crown', () {
    test('flags a completed RCT older than 30 days with no crown', () {
      final found = detectIncompleteTreatments([rct()], now: now);
      expect(found, hasLength(1));
      expect(found.single.kind, IncompleteTreatmentKind.rctWithoutCrown);
      expect(found.single.tooth, ToothId.parse('36'));
      expect(found.single.nextStep(ToothNotation.fdi), 'a crown on tooth 36');
    });

    test(
      'a planned, accepted or completed crown on the same tooth clears it',
      () {
        for (final status in [
          ProcedureStatus.planned,
          ProcedureStatus.accepted,
          ProcedureStatus.inProgress,
          ProcedureStatus.completed,
        ]) {
          final found = detectIncompleteTreatments([
            rct(),
            crown(status: status),
          ], now: now);
          expect(
            found.where(
              (f) => f.kind == IncompleteTreatmentKind.rctWithoutCrown,
            ),
            isEmpty,
            reason: 'crown $status should cover the RCT',
          );
        }
      },
    );

    test('a crown on another tooth or another patient does not count', () {
      expect(
        detectIncompleteTreatments([rct(), crown(tooth: '46')], now: now),
        hasLength(1),
      );
      expect(
        detectIncompleteTreatments([
          rct(),
          crown(patientId: 'someone-else'),
        ], now: now),
        hasLength(1),
      );
    });

    test('a deleted or inactive-plan crown does not count', () {
      expect(
        detectIncompleteTreatments([
          rct(),
          crown(status: ProcedureStatus.deleted),
        ], now: now),
        hasLength(1),
      );
      expect(
        detectIncompleteTreatments([
          rct(),
          crown(status: ProcedureStatus.plannedInactive),
        ], now: now),
        hasLength(1),
      );
    });

    test('inside the 30 day grace window nothing is flagged yet', () {
      expect(detectIncompleteTreatments([rct(daysAgo: 20)], now: now), isEmpty);
    });

    test('a bridge unit or implant crown also protects the tooth', () {
      final bridge = procedureFixture(
        id: 'brg',
        code: 'BRG-PFM-UNIT',
        name: 'Bridge unit',
        status: ProcedureStatus.planned,
        tooth: '36',
      );
      expect(detectIncompleteTreatments([rct(), bridge], now: now), isEmpty);
    });
  });

  group('stalled in-progress work', () {
    test('flags inProgress older than 14 days and names the next stage', () {
      final stalled = procedureFixture(
        id: 'rct-ip',
        code: 'RCT-MOL',
        name: 'Root canal treatment, molar',
        status: ProcedureStatus.inProgress,
        startedAt: now.subtract(const Duration(days: 20)),
        totalStages: 3,
        stageNames: const ['Access and BMP', 'Obturation', 'Post-op review'],
      );
      final found = detectIncompleteTreatments([stalled], now: now);
      expect(found.single.kind, IncompleteTreatmentKind.stalledInProgress);
      expect(found.single.nextStep(ToothNotation.fdi), 'obturation');
    });

    test('recent inProgress work is not flagged', () {
      final recent = procedureFixture(
        id: 'recent',
        code: 'RCT-MOL',
        name: 'RCT',
        status: ProcedureStatus.inProgress,
        startedAt: now.subtract(const Duration(days: 3)),
      );
      expect(detectIncompleteTreatments([recent], now: now), isEmpty);
    });

    test('results are oldest first', () {
      final a = procedureFixture(
        id: 'a',
        code: 'RCT-ANT',
        name: 'Root canal treatment, anterior',
        status: ProcedureStatus.inProgress,
        tooth: '11',
        startedAt: now.subtract(const Duration(days: 30)),
      );
      final found = detectIncompleteTreatments([rct(daysAgo: 60), a], now: now);
      expect(found.map((f) => f.procedure.id), ['rct', 'a']);
    });
  });

  test('code classifiers', () {
    expect(isRootCanalCode('RCT-ANT'), isTrue);
    expect(isRootCanalCode('RERCT'), isTrue);
    expect(isRootCanalCode('CRN-ZIR'), isFalse);
    expect(isCrownCode('CRN-PFM'), isTrue);
    expect(isCrownCode('IMP-CROWN'), isTrue);
    expect(isCrownCode('COMP-POST-1'), isFalse);
  });
}
