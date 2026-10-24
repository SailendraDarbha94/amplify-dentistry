import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_data/ampdent_data.dart';
import 'package:ampdent_mobile/features/prescriptions/prescription_issuer.dart';
import 'package:ampdent_mobile/features/prescriptions/rx_line_sheet.dart';
import 'package:ampdent_mobile/features/prescriptions/rx_model.dart';
import 'package:ampdent_terminology/ampdent_terminology.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_env.dart';

final String _amoxId = seedId('drug', 'AMOX-500');
final DateTime _now = DateTime.utc(2026, 10, 25, 11);

Future<void> _recordPenicillinAllergy(AppTestEnv env) =>
    env.repos.clinical.recordMedicalHistory(
      testCtx,
      MedicalHistory(
        id: 'mh-1',
        clinicId: testClinicId,
        patientId: testPatientId,
        recordedAt: _now,
        recordedBy: testDentistId,
        allergies: const [
          AllergyEntry(
            substance: 'Amoxicillin',
            reaction: 'rash',
            severity: AllergySeverity.moderate,
            allergyGroup: AllergyGroups.penicillin,
          ),
        ],
        createdAt: _now,
      ),
    );

void main() {
  late AppTestEnv env;

  setUp(() async {
    env = await AppTestEnv.open(withPatient: true);
    await env.repos.prescriptions.seedDrugMasterIfEmpty();
  });
  tearDown(() => env.close());

  group('PrescriptionIssuer', () {
    test('issues with a 6-char code and audits allergy overrides', () async {
      final amox = (await env.repos.prescriptions.getDrug(_amoxId))!;
      final issuer = PrescriptionIssuer(
        prescriptions: env.repos.prescriptions,
        audit: env.repos.audit,
        ctx: testCtx,
        codeGenerator: () => 'ABC234',
      );
      final rx = await issuer.issue(
        draft: RxDraft(
          diagnosis: 'K04.7 Periapical abscess',
          lines: [
            RxLineDraft.fromDrug(amox)
                .copyWith(overrideReason: 'Tolerated in 2024, rash was viral'),
          ],
        ),
        patientId: testPatientId,
        prescriber: testDentist(),
        now: _now,
      );
      expect(rx.verificationCode, 'ABC234');
      expect(rx.prescriberRegistrationNumber, 'A-12345');
      expect(rx.prescriberQualifications, ['BDS']);
      expect(rx.lines.single.genericName, 'AMOXICILLIN');
      expect(rx.lines.single.quantity, 15);
      final events = await env.repos.audit.forEntity(
        testClinicId,
        'prescription',
        rx.id,
      );
      expect(
        events.any(
          (e) =>
              e.reason == 'Allergy override: Tolerated in 2024, rash was viral',
        ),
        isTrue,
      );
      expect(
        await env.repos.prescriptions.byVerificationCode('ABC234'),
        isNotNull,
      );
    });

    test('refuses a prescriber without a registration number', () async {
      final amox = (await env.repos.prescriptions.getDrug(_amoxId))!;
      final issuer = PrescriptionIssuer(
        prescriptions: env.repos.prescriptions,
        audit: env.repos.audit,
        ctx: testCtx,
      );
      await expectLater(
        issuer.issue(
          draft: RxDraft(lines: [RxLineDraft.fromDrug(amox)]),
          patientId: testPatientId,
          prescriber: testDentist().copyWith(registrationNumber: ''),
          now: _now,
        ),
        throwsA(isA<MissingRegistrationNumber>()),
      );
      await expectLater(
        issuer.issue(
          draft: const RxDraft(),
          patientId: testPatientId,
          prescriber: testDentist(),
        ),
        throwsArgumentError,
      );
    });
  });

  group('Prescription editor', () {
    Future<void> openEditor(WidgetTester tester) async {
      await env.pumpApp(tester);
      await env.go(tester, '/patients/$testPatientId/prescriptions/new');
      await settle(tester);
    }

    /// Scrolls the line sheet until [finder] is visible, then taps it.
    Future<void> tapInSheet(WidgetTester tester, Finder finder) async {
      await tester.scrollUntilVisible(
        finder,
        120,
        scrollable: find
            .descendant(
              of: find.byType(RxLineSheet),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await settle(tester, frames: 2);
      await tester.tap(finder);
    }

    Future<void> pickAmoxicillin(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('rx-add-drug')));
      await settle(tester);
      await tester.enterText(find.byKey(const ValueKey('drug-search')), 'amox');
      await settle(tester);
      await tester.tap(find.byKey(ValueKey('drug-$_amoxId')));
      await settle(tester);
    }

    testWidgets('allergy conflict blocks until a reason is given', (
      tester,
    ) async {
      await _recordPenicillinAllergy(env);
      await openEditor(tester);
      await pickAmoxicillin(tester);

      expect(
        find.byKey(const ValueKey('allergy-block-dialog')),
        findsOneWidget,
      );
      final confirm = find.byKey(const ValueKey('allergy-override-confirm'));
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);

      // Backing out adds nothing.
      await tester.tap(find.byKey(const ValueKey('allergy-override-cancel')));
      await settle(tester);
      expect(find.byKey(const ValueKey('rx-line-1')), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.descendant(
                of: find.byKey(const ValueKey('rx-save')),
                matching: find.byType(FilledButton),
              ),
            )
            .onPressed,
        isNull,
      );

      // A short reason still blocks; a real one unlocks.
      await pickAmoxicillin(tester);
      await tester.enterText(
        find.byKey(const ValueKey('allergy-override-reason')),
        'ok',
      );
      await settle(tester, frames: 2);
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      await tester.enterText(
        find.byKey(const ValueKey('allergy-override-reason')),
        'Tolerated amoxicillin in 2024; rash was viral',
      );
      await settle(tester, frames: 2);
      expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
      await tester.tap(confirm);
      await settle(tester);

      // Line sheet: 1 capsule TDS x 5 d -> 15, switch to 1-0-1 -> 10.
      expect(find.byKey(const ValueKey('rx-line-save')), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('rx-quantity')))
            .controller!
            .text,
        '15',
      );
      await tapInSheet(tester, find.byKey(const ValueKey('rx-freq-1-0-1')));
      await settle(tester, frames: 2);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('rx-quantity')))
            .controller!
            .text,
        '10',
      );
      await tapInSheet(tester, find.byKey(const ValueKey('rx-line-save')));
      await settle(tester);

      expect(find.byKey(const ValueKey('rx-line-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('rx-line-1-override')), findsOneWidget);
      expect(find.textContaining('AMOXICILLIN 500 mg'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('rx-save')));
      await settle(tester, frames: 12);

      final issued = await env.repos.prescriptions.prescriptionsForPatient(
        testPatientId,
      );
      expect(issued, hasLength(1));
      expect(issued.single.verificationCode, hasLength(6));
      expect(issued.single.lines.single.quantity, 10);
      expect(issued.single.lines.single.frequency, '1-0-1');
      expect(
        env.location,
        '/patients/$testPatientId/prescriptions/${issued.single.id}',
      );
      expect(
        find.byKey(const ValueKey('rx-verification-code')),
        findsOneWidget,
      );
      final events = await env.repos.audit.forEntity(
        testClinicId,
        'prescription',
        issued.single.id,
      );
      expect(
        events.any((e) => e.reason?.startsWith('Allergy override') ?? false),
        isTrue,
      );
    });

    testWidgets('no allergy: drug goes straight to the line sheet', (
      tester,
    ) async {
      await openEditor(tester);
      await pickAmoxicillin(tester);
      expect(find.byKey(const ValueKey('allergy-block-dialog')), findsNothing);
      expect(find.byKey(const ValueKey('rx-line-save')), findsOneWidget);
      await tapInSheet(tester, find.byKey(const ValueKey('rx-line-save')));
      await settle(tester);
      expect(find.byKey(const ValueKey('rx-line-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('rx-line-1-override')), findsNothing);
    });

    testWidgets('repeat copies the lines of an earlier prescription', (
      tester,
    ) async {
      final amox = (await env.repos.prescriptions.getDrug(_amoxId))!;
      final rx =
          await PrescriptionIssuer(
            prescriptions: env.repos.prescriptions,
            audit: env.repos.audit,
            ctx: testCtx,
          ).issue(
            draft: RxDraft(
              diagnosis: 'Pericoronitis',
              lines: [RxLineDraft.fromDrug(amox)],
            ),
            patientId: testPatientId,
            prescriber: testDentist(),
            now: _now,
          );
      await env.pumpApp(tester);
      await env.go(
        tester,
        '/patients/$testPatientId/prescriptions/new?repeatOf=${rx.id}',
      );
      await settle(tester, frames: 10);
      expect(find.text('Repeat prescription'), findsOneWidget);
      expect(find.byKey(const ValueKey('rx-line-1')), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('rx-diagnosis')))
            .controller!
            .text,
        'Pericoronitis',
      );
    });
  });
}
