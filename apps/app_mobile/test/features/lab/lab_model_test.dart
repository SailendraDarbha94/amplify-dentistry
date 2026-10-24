import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/features/lab/lab_guards.dart';
import 'package:ampdent_mobile/features/lab/lab_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../recall/feature_harness.dart';

void main() {
  group('canSeat', () {
    test('only received or quality-checked cases can be seated', () {
      for (final status in LabCaseStatus.values) {
        final c = labCaseFixture(id: 'c', status: status);
        final expected =
            status == LabCaseStatus.received ||
            status == LabCaseStatus.qualityChecked;
        expect(canSeat(c), expected, reason: status.name);
        expect(seatBlockReason(c), expected ? isNull : isNotNull);
      }
    });
  });

  group('lab model', () {
    test('shade lists are VITA classical A1-D4 plus 3D-Master', () {
      expect(vitaClassicalShades.first, 'A1');
      expect(vitaClassicalShades.last, 'D4');
      expect(vitaClassicalShades, contains('A3.5'));
      expect(vitaClassicalShades, hasLength(16));
      expect(vita3dMasterShades, contains('2M2'));
      expect(vita3dMasterShades, contains('3R2.5'));
    });

    test('procedure codes map to case types', () {
      expect(labCaseTypeForProcedureCode('CRN-ZIR'), LabCaseType.crownZirconia);
      expect(labCaseTypeForProcedureCode('CRN-PFM'), LabCaseType.crownPfm);
      expect(labCaseTypeForProcedureCode('BRG-PFM-UNIT'), LabCaseType.bridge);
      expect(
        labCaseTypeForProcedureCode('CD-ACRYLIC'),
        LabCaseType.completeDenture,
      );
      expect(labCaseTypeForProcedureCode('ALIGNER-CASE'), LabCaseType.aligner);
      expect(labCaseTypeForProcedureCode('RCT-MOL'), isNull);
      expect(procedureNeedsLab('IMP-CROWN'), isTrue);
      expect(procedureNeedsLab('SCALING-ADULT'), isFalse);
    });

    test('groupCasesByStatus puts overdue cases first within a group', () {
      final now = harnessNow;
      final late = labCaseFixture(
        id: 'late',
        status: LabCaseStatus.sent,
        sentAt: now.subtract(const Duration(days: 10)),
        dueAt: now.subtract(const Duration(days: 2)),
      );
      final onTime = labCaseFixture(
        id: 'ontime',
        status: LabCaseStatus.sent,
        sentAt: now.subtract(const Duration(days: 1)),
        dueAt: now.add(const Duration(days: 4)),
      );
      final fresh = labCaseFixture(id: 'fresh');
      final groups = groupCasesByStatus([onTime, fresh, late], now);
      expect(groups[LabCaseStatus.sent]!.map((c) => c.id), ['late', 'ontime']);
      expect(groups[LabCaseStatus.created]!.single.id, 'fresh');
      expect(groups[LabCaseStatus.received], isEmpty);
    });

    test('parseTeethInput accepts FDI lists and rejects junk', () {
      expect(parseTeethInput('17, 16 15')!.map((t) => t.storageKey), [
        '15',
        '16',
        '17',
      ]);
      expect(parseTeethInput(''), isEmpty);
      expect(parseTeethInput('16, 99'), isNull);
    });

    test('every case type has a label, item name and material list', () {
      for (final t in LabCaseType.values) {
        expect(labCaseTypeLabel(t), isNotEmpty);
        expect(labItemLabel(labCaseFixture(id: 'x', caseType: t)), isNotEmpty);
        expect(materialsFor(t), isA<List<String>>());
      }
    });
  });
}
