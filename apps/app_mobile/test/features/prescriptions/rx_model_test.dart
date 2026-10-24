import 'dart:math';

import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/features/prescriptions/rx_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('computeQuantity', () {
    int tabs(String freq, int days, {String dose = '1 tablet'}) =>
        computeQuantity(
          dose: dose,
          frequency: freq,
          durationDays: days,
          form: DrugForm.tablet,
        );

    test('1-0-1 x 5 days -> 10', () => expect(tabs('1-0-1', 5), 10));
    test('1-1-1 x 3 days -> 9', () => expect(tabs('1-1-1', 3), 9));
    test('1-1-1-1 x 2 days -> 8', () => expect(tabs('1-1-1-1', 2), 8));
    test('0-0-1 x 7 days -> 7', () => expect(tabs('0-0-1', 7), 7));
    test('TDS x 5 -> 15 and BD x 5 -> 10', () {
      expect(tabs('TDS', 5), 15);
      expect(tabs('BD', 5), 10);
      expect(tabs('OD', 5), 5);
      expect(tabs('QID', 1), 4);
      expect(tabs('HS', 3), 3);
      expect(tabs('TDS after meals', 2), 6);
    });
    test('two tablets per dose doubles; half a tablet rounds up', () {
      expect(tabs('1-0-1', 5, dose: '2 tablets'), 20);
      expect(tabs('1-0-1', 5, dose: '½ tablet'), 5);
      expect(tabs('1-0-1', 3, dose: '1/2 tablet'), 3);
    });
    test('single dose is one dose in total regardless of days', () {
      expect(tabs('single dose', 5), 1);
      expect(tabs('single dose', 5, dose: '2 tablets'), 2);
      expect(tabs('1 h before appointment', 3), 1);
    });
    test('SOS assumes two doses a day', () => expect(tabs('SOS', 3), 6));
    test('syrups, gels and mouthwashes are one pack', () {
      for (final form in [
        DrugForm.syrup,
        DrugForm.gel,
        DrugForm.mouthwash,
        DrugForm.injection,
      ]) {
        expect(
          computeQuantity(
            dose: '10 mL',
            frequency: 'TDS',
            durationDays: 5,
            form: form,
          ),
          1,
          reason: form.name,
        );
      }
    });
    test('capsules count like tablets', () {
      expect(
        computeQuantity(
          dose: '1 capsule',
          frequency: 'TDS',
          durationDays: 5,
          form: DrugForm.capsule,
        ),
        15,
      );
    });
  });

  group('RxLineDraft', () {
    final amox = Drug(
      id: 'd1',
      genericName: 'Amoxicillin',
      brandNames: const ['Mox'],
      strength: '500 mg',
      form: DrugForm.capsule,
      category: 'antibiotic',
      defaultDose: '1 capsule',
      defaultFrequency: 'TDS',
      defaultDurationDays: 5,
      route: 'oral',
      allergyGroup: 'penicillin',
    );

    test('auto quantity follows edits until set by hand', () {
      final line = RxLineDraft.fromDrug(amox);
      expect(line.effectiveQuantity, 15);
      expect(line.copyWith(frequency: '1-0-1').effectiveQuantity, 10);
      expect(line.copyWith(durationDays: 7).effectiveQuantity, 21);
      final manual = line.copyWith(quantity: 12);
      expect(manual.copyWith(durationDays: 10).effectiveQuantity, 12);
      expect(manual.copyWith(clearQuantity: true).effectiveQuantity, 15);
    });

    test('stored line carries the generic in capitals and the quantity', () {
      final stored = RxLineDraft.fromDrug(amox)
          .copyWith(instructions: ' after food ')
          .toLine();
      expect(stored.genericName, 'AMOXICILLIN');
      expect(stored.quantity, 15);
      expect(stored.instructions, 'after food');
      expect(stored.schedule, DrugSchedule.h);
      expect(stored.drugId, 'd1');
    });

    test('schedule H1 is flagged per line and on the draft', () {
      final h1 = RxLineDraft.fromDrug(amox.copyWith(schedule: DrugSchedule.h1));
      expect(h1.isScheduleH1, isTrue);
      expect(RxDraft(lines: [h1]).hasScheduleH1, isTrue);
      expect(
        RxDraft(lines: [RxLineDraft.fromDrug(amox)]).hasScheduleH1,
        isFalse,
      );
    });
  });

  group('allergy and caution helpers', () {
    final amox = Drug(
      id: 'd1',
      genericName: 'Amoxicillin',
      strength: '500 mg',
      form: DrugForm.capsule,
      category: 'antibiotic',
      defaultDose: '1 capsule',
      defaultFrequency: 'TDS',
      defaultDurationDays: 5,
      route: 'oral',
      allergyGroup: 'penicillin',
      pregnancyCaution: false,
      pediatricCaution: true,
    );
    final history = MedicalHistory(
      id: 'h',
      clinicId: 'c',
      patientId: 'p',
      recordedAt: DateTime.utc(2026),
      recordedBy: 'm',
      allergies: const [
        AllergyEntry(substance: 'Penicillin V', allergyGroup: 'Penicillin'),
      ],
      pregnant: true,
      createdAt: DateTime.utc(2026),
    );

    test('conflict is case-insensitive on the group', () {
      expect(allergyConflicts(history, amox), isTrue);
      expect(matchingAllergies(history, amox).single.substance, 'Penicillin V');
      expect(allergyConflicts(null, amox), isFalse);
      expect(
        allergyConflicts(history, amox.copyWith(allergyGroup: 'nsaid')),
        isFalse,
      );
    });

    test('caution labels depend on age and pregnancy', () {
      expect(cautionLabels(drug: amox, history: history, isMinor: true), [
        'Paediatric caution',
      ]);
      final ibu = amox.copyWith(
        pregnancyCaution: true,
        pediatricCaution: false,
      );
      expect(cautionLabels(drug: ibu, history: history, isMinor: false), [
        'Pregnancy caution',
      ]);
      expect(cautionLabels(drug: ibu, history: null, isMinor: false), [
        'Caution in pregnancy',
      ]);
    });
  });

  test('verification code is six unambiguous characters', () {
    final code = generateVerificationCode(Random(7));
    expect(code, hasLength(6));
    expect(code, matches(RegExp('^[$verificationAlphabet]{6}\$')));
    expect(verificationAlphabet.contains('0'), isFalse);
    expect(verificationAlphabet.contains('O'), isFalse);
    expect(verificationAlphabet.contains('I'), isFalse);
  });
}
