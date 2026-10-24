import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/features/notes/medical_history_model.dart';
import 'package:ampdent_mobile/features/notes/red_flags.dart';
import 'package:ampdent_terminology/ampdent_terminology.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 10, 25);

  group('MedicalHistoryDraft', () {
    test('answers map onto every terminology question key', () {
      var draft = const MedicalHistoryDraft();
      for (final key in medicalHistoryFieldKeys) {
        if (key == 'allergies') continue; // needs an entry, tested below
        draft = draft.answer(key, true);
        expect(draft.isYes(key), isTrue, reason: key);
        draft = draft.answer(key, false);
        expect(draft.isYes(key), isFalse, reason: key);
      }
      final withAllergy = draft.copyWith(
        allergies: const [AllergyEntry(substance: 'Amoxicillin')],
      );
      expect(withAllergy.isYes('allergies'), isTrue);
      expect(withAllergy.answer('allergies', false).allergies, isEmpty);
    });

    test(
      'MRONJ tier is explicit: oral < 5 y is low, IV or oncology higher',
      () {
        const oral = MedicalHistoryDraft(
          antiresorptive: true,
          antiresorptiveName: 'Alendronate',
          antiresorptiveRoute: AntiresorptiveRoute.oral,
          antiresorptiveYears: '2',
        );
        expect(oral.mronjRisk(now), MronjRisk.low);
        expect(
          oral.copyWith(antiresorptiveYears: '6').mronjRisk(now),
          MronjRisk.higher,
        );
        expect(
          oral
              .copyWith(antiresorptiveRoute: AntiresorptiveRoute.intravenous)
              .mronjRisk(now),
          MronjRisk.higher,
        );
        expect(
          oral.copyWith(oncologyTreatment: true).mronjRisk(now),
          MronjRisk.higher,
        );
        expect(
          oral.answer('antiresorptives', false).mronjRisk(now),
          MronjRisk.none,
        );
      },
    );

    test('red-flag banners cover the chairside set with detail text', () {
      const draft = MedicalHistoryDraft(
        anticoagulant: true,
        anticoagulantName: 'Warfarin',
        antiresorptive: true,
        antiresorptiveName: 'Zoledronate',
        antiresorptiveRoute: AntiresorptiveRoute.intravenous,
        diabetes: true,
        hba1c: '9.1',
        pregnant: true,
        pregnancyTrimester: 2,
        allergies: [
          AllergyEntry(
            substance: 'Lignocaine',
            allergyGroup: AllergyGroups.localAnaesthetic,
          ),
          AllergyEntry(
            substance: 'Amoxicillin',
            reaction: 'rash',
            allergyGroup: AllergyGroups.penicillin,
          ),
        ],
      );
      final infos = redFlagInfos(draft.preview(now));
      final flags = infos.map((i) => i.flag).toList();
      expect(
        flags,
        containsAll([
          RedFlag.anticoagulant,
          RedFlag.mronj,
          RedFlag.uncontrolledDiabetes,
          RedFlag.pregnancy,
          RedFlag.allergyLocalAnaesthetic,
          RedFlag.allergyPenicillin,
        ]),
      );
      final mronj = infos.singleWhere((i) => i.flag == RedFlag.mronj);
      expect(mronj.label, 'MRONJ risk: higher');
      expect(mronj.detail, contains('Zoledronate'));
      final pen = infos.singleWhere((i) => i.flag == RedFlag.allergyPenicillin);
      expect(pen.detail, contains('Amoxicillin (rash)'));
      expect(
        infos.singleWhere((i) => i.flag == RedFlag.pregnancy).detail,
        contains('Trimester 2'),
      );
    });

    test('controlled diabetes is not a red flag', () {
      const draft = MedicalHistoryDraft(diabetes: true, hba1c: '6.5');
      expect(draft.preview(now).redFlags, isEmpty);
    });

    test('round-trips through MedicalHistory', () {
      const draft = MedicalHistoryDraft(
        hypertension: true,
        cardiac: true,
        cardiacCondition: 'Stent 2021',
        smoking: SmokingStatus.former,
        alcohol: true,
        otherNotes: 'On amlodipine',
      );
      final history = draft.toHistory(
        id: 'h1',
        clinicId: 'c',
        patientId: 'p',
        recordedBy: 'm',
        now: now,
      );
      final back = MedicalHistoryDraft.fromHistory(history);
      expect(back.hypertension, isTrue);
      expect(back.cardiac, isTrue);
      expect(back.cardiacCondition, 'Stent 2021');
      expect(back.smoking, SmokingStatus.former);
      expect(back.alcohol, isTrue);
      expect(back.otherNotes, 'On amlodipine');
      expect(back.isYes('smoking'), isTrue);
    });
  });
}
