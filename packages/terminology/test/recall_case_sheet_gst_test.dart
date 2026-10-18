import 'package:ampdent_terminology/ampdent_terminology.dart';
import 'package:test/test.dart';

void main() {
  group('recall rules', () {
    test('all rules use valid types and positive intervals', () {
      for (final r in defaultRecallRules) {
        expect(RecallTypes.all, contains(r.type));
        expect(r.dueAfterDays, greaterThan(0));
        expect(r.matchCodes != null || r.matchCategory != null, isTrue);
      }
    });

    test('SCALING codes get a 6-month hygiene recall', () {
      for (final s in indianProcedureCatalogue.where(
        (s) => s.code.startsWith('SCALING'),
      )) {
        final rule = recallRuleFor(s)!;
        expect(rule.type, RecallTypes.hygiene, reason: s.code);
        expect(rule.dueAfterDays, 180, reason: s.code);
      }
    });

    test('special rules: implant 12 months, ortho 4 weeks, post-op 7 days, RCT 14 days', () {
      final implant = recallRuleFor(procedureSeedByCode('IMP-PLACE')!)!;
      expect(implant.type, RecallTypes.implantReview);
      expect(implant.dueAfterDays, 365);
      expect(implant.intervalLabel, '12 months');

      final ortho = recallRuleFor(procedureSeedByCode('ORTHO-METAL')!)!;
      expect(ortho.type, RecallTypes.orthoAdjustment);
      expect(ortho.dueAfterDays, 28);
      expect(ortho.recurring, isTrue);
      expect(ortho.intervalLabel, '4 weeks');

      final ext = recallRuleFor(procedureSeedByCode('EXT-SIMPLE')!)!;
      expect(ext.type, RecallTypes.postOp);
      expect(ext.dueAfterDays, 7);
      expect(ext.intervalLabel, '7 days');

      final rct = recallRuleFor(procedureSeedByCode('RCT-MOL')!)!;
      expect(rct.type, RecallTypes.review);
      expect(rct.dueAfterDays, 14);

      final perio = recallRuleFor(procedureSeedByCode('PERIO-MAINT')!)!;
      expect(perio.dueAfterDays, 90);
      expect(perio.intervalLabel, '3 months');

      expect(recallRuleFor(procedureSeedByCode('GOODS-MOUTHWASH')!), isNull);
      expect(recallRuleFor(procedureSeedByCode('WHITENING-OFFICE')!), isNull);
    });

    test('recallDueDate adds the interval', () {
      final due = recallDueDate(
        procedureSeedByCode('SCALING-ADULT')!,
        DateTime(2026, 1, 1),
      );
      expect(due, DateTime(2026, 6, 30));
    });

    test('toJson/fromJson round-trips', () {
      for (final r in defaultRecallRules) {
        expect(RecallRule.fromJson(r.toJson()).toJson(), r.toJson());
      }
    });
  });

  group('case sheet', () {
    test('sections are in BDS order with intraoral sub-sections', () {
      final keys = caseSheetTopLevelSections.map((s) => s.key).toList();
      expect(keys, [
        'chiefComplaint',
        'historyOfPresentIllness',
        'pastDentalHistory',
        'pastMedicalHistory',
        'personalHistory',
        'extraoralExamination',
        'intraoralExamination',
        'provisionalDiagnosis',
        'investigations',
        'finalDiagnosis',
        'treatmentPlan',
        'treatmentDone',
        'advice',
        'followUp',
      ]);
      expect(caseSheetSubSections('intraoralExamination').map((s) => s.key), [
        'intraoralSoftTissue',
        'intraoralHardTissue',
      ]);
      final all = caseSheetSections.map((s) => s.key).toList();
      expect(all.toSet().length, all.length);
      for (final s in caseSheetSections) {
        if (s.parentKey != null) {
          expect(caseSheetSectionByKey(s.parentKey!), isNotNull, reason: s.key);
        }
      }
    });

    test('medical history questions align with field keys', () {
      expect(medicalHistoryQuestions.length, medicalHistoryFieldKeys.length);
      expect(medicalHistoryFieldKeys.length, 16);
      expect(
        medicalHistoryQuestionFor('antiresorptives'),
        contains('bisphosphonates'),
      );
      expect(medicalHistoryQuestionFor('nope'), isNull);
    });
  });

  group('GST defaults', () {
    test('state table covers 01-38, 97 with unique codes', () {
      final codes = gstStateCodes.map((s) => s.code).toList();
      expect(codes.toSet().length, codes.length);
      for (var i = 1; i <= 38; i++) {
        expect(gstStateByCode(i.toString()), isNotNull, reason: '$i');
      }
      expect(gstStateByCode('97')!.name, 'Other Territory');
      expect(gstStateByCode('37')!.name, 'Andhra Pradesh');
      expect(gstStateByCode('38')!.name, 'Ladakh');
      expect(gstStateByCode('1')!.name, 'Jammu and Kashmir');
      expect(activeGstStateCodes.any((s) => s.code == '25'), isFalse);
    });

    test(
      'threshold is 20 lakh by default and 10 lakh for the four NE states',
      () {
        expect(gstRegistrationThresholdRupees('27'), 2000000);
        expect(gstRegistrationThresholdRupees('36'), 2000000);
        expect(
          gstRegistrationThresholdRupees('12'),
          2000000,
          reason: 'Arunachal left at 20 lakh',
        );
        for (final code in ['13', '14', '15', '16']) {
          expect(gstRegistrationThresholdRupees(code), 1000000, reason: code);
        }
        expect(gstRegistrationThresholdRupees('7'), 2000000);
      },
    );

    test('GSTIN state extraction', () {
      expect(gstStateCodeFromGstin('27AAPFU0939F1ZV'), '27');
      expect(gstStateCodeFromGstin('bad'), isNull);
    });
  });
}
