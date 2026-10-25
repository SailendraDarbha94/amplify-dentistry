import 'dart:math';

import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_data/ampdent_data.dart';
import 'package:ampdent_mobile/features/prescriptions/rx_model.dart';
import 'package:ampdent_terminology/ampdent_terminology.dart';
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

    test('a free-typed substance without a group still conflicts', () {
      final typed = history.copyWith(
        allergies: const [
          AllergyEntry(substance: 'amoxicillin', reaction: 'anaphylaxis'),
        ],
      );
      expect(allergyConflicts(typed, amox), isTrue);
      expect(matchingAllergies(typed, amox).single.reaction, 'anaphylaxis');
      // Brand of a related penicillin maps to the group.
      final brand = history.copyWith(
        allergies: const [AllergyEntry(substance: 'Augmentin')],
      );
      expect(allergyConflicts(brand, amox), isTrue);
      // Unrelated substance: nothing to block.
      final other = history.copyWith(
        allergies: const [AllergyEntry(substance: 'Latex')],
      );
      expect(allergyConflicts(other, amox), isFalse);
      // A drug with no group of its own is still matched by name.
      final para = amox.copyWith(allergyGroup: null);
      final paraDrug = Drug(
        id: 'd2',
        genericName: 'Paracetamol',
        brandNames: const ['Dolo 650', 'Crocin'],
        strength: '650 mg',
        form: DrugForm.tablet,
        category: 'analgesic',
        defaultDose: '1 tablet',
        defaultFrequency: 'TDS',
        defaultDurationDays: 3,
        route: 'oral',
      );
      expect(para.allergyGroup, isNotNull, reason: 'copyWith keeps the group');
      expect(
        allergyConflicts(
          history.copyWith(
            allergies: const [AllergyEntry(substance: 'Crocin')],
          ),
          paraDrug,
        ),
        isTrue,
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

  group('schedule history at prescribe time', () {
    final pregabalin = drugFromSeed(drugSeedByCode('PREGAB-75')!);
    final before = DateTime.utc(2026, 10, 1);
    final after = DateTime.utc(2026, 12, 1);
    final prescriber = ClinicMember(
      id: 'm',
      clinicId: 'c',
      displayName: 'Dr. A. Rao',
      role: ClinicRole.ownerDentist,
      registrationNumber: 'A-1',
      phone: '+919000000002',
      createdAt: before,
      updatedAt: before,
    );

    test('a line takes the schedule in force on the prescribe date', () {
      final early = RxLineDraft.fromDrug(pregabalin, at: before);
      expect(early.schedule, DrugSchedule.h);
      expect(early.isScheduleH1, isFalse);
      expect(early.scheduleAt(after), DrugSchedule.h1);
      final late = RxLineDraft.fromDrug(pregabalin, at: after);
      expect(late.schedule, DrugSchedule.h1);
      expect(late.isScheduleH1, isTrue);
      expect(late.scheduleAt(before), DrugSchedule.h);
      // The drug master itself says H1 (its current tag).
      expect(pregabalin.schedule, DrugSchedule.h1);
    });

    test('the stored prescription resolves at the issue time', () {
      final draft = RxDraft(
        lines: [RxLineDraft.fromDrug(pregabalin, at: before)],
      );
      Prescription issue(DateTime now) => draft.toPrescription(
        id: 'rx',
        clinicId: 'c',
        patientId: 'p',
        prescriber: prescriber,
        verificationCode: 'ABC234',
        now: now,
      );
      expect(issue(before).lines.single.schedule, DrugSchedule.h);
      expect(issue(before).hasScheduleH1, isFalse);
      expect(issue(after).lines.single.schedule, DrugSchedule.h1);
      expect(issue(after).hasScheduleH1, isTrue);
    });

    test('a repeat re-resolves the tag for the new date', () {
      final old = RxDraft(lines: [RxLineDraft.fromDrug(pregabalin, at: before)])
          .toPrescription(
            id: 'rx-old',
            clinicId: 'c',
            patientId: 'p',
            prescriber: prescriber,
            verificationCode: 'ABC234',
            now: before,
          );
      expect(old.lines.single.schedule, DrugSchedule.h);
      final repeat = RxDraft.repeatOf(
        old,
        drugs: {pregabalin.id: pregabalin},
        at: after,
      );
      expect(repeat.lines.single.schedule, DrugSchedule.h1);
      // Without the drug master the stored tag is kept as it was printed.
      expect(
        RxDraft.repeatOf(old, at: after).lines.single.schedule,
        DrugSchedule.h,
      );
    });

    test('the patient demographics are frozen on the prescription', () {
      final patient = Patient(
        id: 'p',
        clinicId: 'c',
        patientNumber: 'P-7',
        firstName: 'Asha',
        lastName: 'Rao',
        phone: '+919876543210',
        dateOfBirth: DateTime.utc(1990, 5, 20),
        sex: Sex.female,
        addressLines: const ['4 Park Lane'],
        city: 'Hyderabad',
        createdAt: before,
        updatedAt: before,
      );
      final rx = RxDraft(lines: [RxLineDraft.fromDrug(pregabalin, at: after)])
          .toPrescription(
            id: 'rx',
            clinicId: 'c',
            patientId: 'p',
            prescriber: prescriber,
            verificationCode: 'ABC234',
            now: after,
            patient: patient,
          );
      final snap = rx.patientSnapshot!;
      expect(snap.displayName, 'Asha Rao');
      expect(snap.ageYears, 36);
      expect(snap.sex, Sex.female);
      expect(snap.city, 'Hyderabad');
      expect(snap.guardianName, isNull);
      expect(
        Prescription.fromJson(rx.toJson()).patientSnapshot?.toJson(),
        snap.toJson(),
      );
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
