import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/features/consent/consent_model.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../feature_test_env.dart';

void main() {
  late FeatureTestEnv env;

  setUp(() async {
    env = await FeatureTestEnv.open(seedCatalog: false);
    await env.repos.chart.createProcedure(testCtx, plannedProcedure());
  });
  tearDown(() => env.close());

  String renderedText(WidgetTester tester) => tester
      .widget<Text>(
        find.byKey(const ValueKey('consent-text'), skipOffstage: false),
      )
      .data!;

  /// Scrolls the page list programmatically (a drag from the centre would
  /// land on the consent text box, which has its own scrollable) until the
  /// widget with [key] is built, then brings it fully on screen.
  Future<void> reveal(WidgetTester tester, Key key) async {
    final anywhere = find.byKey(key, skipOffstage: false);
    for (var i = 0; i < 30 && anywhere.evaluate().isEmpty; i++) {
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      position.jumpTo(position.pixels + 250);
      await settle(tester, frames: 2);
    }
    await tester.ensureVisible(anywhere);
    await settle(tester, frames: 2);
  }

  testWidgets('adult signs an RCT consent naming tooth 36', (tester) async {
    await env.pumpApp(tester);
    await env.go(
      tester,
      '/patients/$testPatientId/consent/new?procedureIds=proc-rct',
    );
    await settle(tester, frames: 10);
    expect(find.text('RCT'), findsWidgets);
    expect(renderedText(tester), contains('tooth numbered 36'));
    expect(renderedText(tester), contains('Dr. A. Rao'));
    expect(renderedText(tester), isNot(contains('{')));

    // Self is preselected for an adult and nothing is blocked.
    await reveal(tester, const ValueKey('consent-relation-self'));
    expect(find.byKey(const ValueKey('consent-minor-block')), findsNothing);
    final selfChip = tester.widget<ChoiceChip>(
      find.byKey(const ValueKey('consent-relation-self')),
    );
    expect(selfChip.selected, isTrue);

    // Without the discussion note the save is refused.
    await tester.tap(find.byKey(const ValueKey('consent-sign')));
    await settle(tester, frames: 4);
    expect(find.text(ConsentStrings.discussionNoteRequired), findsOneWidget);
    expect(await env.repos.consents.consentsForPatient(testPatientId), isEmpty);
    // Clear the snack bar; it sits over the pinned Sign button.
    ScaffoldMessenger.of(
      tester.element(find.byKey(const ValueKey('consent-sign'))),
    ).clearSnackBars();
    await settle(tester, frames: 10);

    await reveal(tester, const ValueKey('consent-discussion'));
    await tester.enterText(
      find.byKey(const ValueKey('consent-discussion')),
      'Explained pain, swelling and the extraction alternative',
    );
    await reveal(tester, const ValueKey('consent-read-aloud'));
    await tester.tap(find.byKey(const ValueKey('consent-read-aloud')));
    await reveal(tester, const ValueKey('consent-signature'));
    await tester.drag(
      find.byKey(const ValueKey('consent-signature')),
      const Offset(90, 25),
    );
    await settle(tester, frames: 2);
    await tester.tap(find.byKey(const ValueKey('consent-sign')));
    await settle(tester, frames: 15);

    final saved = await env.repos.consents.consentsForPatient(testPatientId);
    expect(saved, hasLength(1));
    final c = saved.single;
    expect(c.templateCode, 'RCT');
    expect(c.teeth.map((t) => t.fdi), ['36']);
    expect(c.procedureIds, ['proc-rct']);
    expect(c.renderedText, contains('tooth numbered 36'));
    expect(c.signerRelation, SignerRelation.self);
    expect(c.dentistRegistrationNumber, 'A-12345');
    expect(c.discussionNote, endsWith(ConsentStrings.readAloudMarker));
    expect(c.signatureImagePath, isNotNull);
    expect(await env.signatures.read(c.signatureImagePath!), isNotNull);
    expect(env.location, '/patients/$testPatientId/consent/${c.id}');
    expect(find.text('Signed'), findsWidgets);
    expect(find.byKey(const ValueKey('consent-pdf')), findsOneWidget);
  });

  testWidgets('a minor cannot self-sign; the guardian is preselected', (
    tester,
  ) async {
    final patient = (await env.repos.patients.getById(testPatientId))!;
    await env.savePatient(
      patient.copyWith(
        dateOfBirth: DateTime.utc(2016, 3, 1),
        guardianName: 'Lakshmi',
        guardianRelation: 'Mother',
        guardianPhone: '+919123456789',
      ),
    );
    await env.pumpApp(tester);
    await env.go(
      tester,
      '/patients/$testPatientId/consent/new?procedureIds=proc-rct',
    );
    await settle(tester, frames: 10);
    expect(renderedText(tester), contains('aged 10 years'));
    await reveal(tester, const ValueKey('consent-relation-parent'));
    final parentChip = tester.widget<ChoiceChip>(
      find.byKey(const ValueKey('consent-relation-parent')),
    );
    expect(parentChip.selected, isTrue);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('consent-signer-name')))
          .controller!
          .text,
      'Lakshmi',
    );

    await reveal(tester, const ValueKey('consent-relation-self'));
    await tester.tap(find.byKey(const ValueKey('consent-relation-self')));
    await settle(tester, frames: 2);
    expect(
      find.byKey(const ValueKey('consent-minor-block'), skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.text(ConsentStrings.minorCannotSelfSign, skipOffstage: false),
      findsOneWidget,
    );
    final sign = tester.widget<BigActionButton>(
      find.byKey(const ValueKey('consent-sign')),
    );
    expect(sign.onPressed, isNull);
    expect(await env.repos.consents.consentsForPatient(testPatientId), isEmpty);
  });

  testWidgets('picker offers the photo-use template and the list links to it', (
    tester,
  ) async {
    await env.pumpApp(tester);
    await env.go(tester, '/patients/$testPatientId/consent');
    expect(find.byKey(const ValueKey('consent-photo-use')), findsOneWidget);
    expect(
      find.text('Not signed. Required before photos are shared.'),
      findsOneWidget,
    );

    await env.go(tester, '/patients/$testPatientId/consent/new');
    expect(find.byKey(const ValueKey('consent-pick-proc-rct')), findsOneWidget);
    await reveal(tester, const ValueKey('consent-template-PHOTO-USE'));
    await tester.tap(find.byKey(const ValueKey('consent-template-PHOTO-USE')));
    await settle(tester, frames: 2);
    await tester.tap(find.byKey(const ValueKey('consent-continue')));
    await settle(tester, frames: 6);
    expect(renderedText(tester), contains('clinical photographs'));
    expect(find.text('Clinical Photography and Sharing'), findsOneWidget);
  });
}
