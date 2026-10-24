import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_mobile/core/router.dart';
import 'package:ampdent_mobile/core/session.dart';
import 'package:ampdent_mobile/features/recall/patient_messenger.dart';
import 'package:ampdent_mobile/features/recall/reason_sheet.dart';
import 'package:ampdent_mobile/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/test_env.dart';

export '../../helpers/test_env.dart';

/// Wednesday 21 Oct 2026, 10:00 local: the pinned "now" of these tests.
final DateTime harnessNow = DateTime(2026, 10, 21, 10);

/// [AppTestEnv] plus a provider container that pins the clock and records
/// every deep link the recall and lab features try to open.
class FeatureHarness {
  FeatureHarness._(this.env, this.container, this.launched, this.now);

  /// Database, repositories and fixtures.
  final AppTestEnv env;

  /// Container with the feature overrides.
  final ProviderContainer container;

  /// URIs handed to the link launcher, in order.
  final List<Uri> launched;

  /// The pinned clock.
  final DateTime now;

  /// Opens a harness; see [AppTestEnv.open] for the fixture flags.
  static Future<FeatureHarness> open({
    DateTime? now,
    bool withPatient = true,
    bool launchSucceeds = true,
    String initialLocation = '/recall',
  }) async {
    final env = await AppTestEnv.open(withPatient: withPatient);
    final launched = <Uri>[];
    final clock = now ?? harnessNow;
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(env.db),
        initialSessionProvider.overrideWithValue(env.session),
        clockProvider.overrideWithValue(() => clock),
        linkLauncherProvider.overrideWithValue((uri) async {
          launched.add(uri);
          return launchSucceeds;
        }),
        // Start on the feature under test so pages owned by other features
        // (and their test-font layout quirks) stay out of these tests.
        routerProvider.overrideWith((ref) {
          final router = buildRouter(
            hasClinic: () => ref.read(appSessionProvider).hasClinic,
            initialLocation: initialLocation,
          );
          ref.onDispose(router.dispose);
          return router;
        }),
      ],
    );
    return FeatureHarness._(env, container, launched, clock);
  }

  /// The app router.
  GoRouter get router => container.read(routerProvider);

  /// Matched location of the top-most route.
  String get location =>
      router.routerDelegate.currentConfiguration.last.matchedLocation;

  /// Pumps the app on a 360 x 800 surface.
  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AmpDentApp(),
      ),
    );
    await settle(tester);
  }

  /// Navigates and settles.
  Future<void> go(WidgetTester tester, String location) async {
    router.go(location);
    await settle(tester, frames: 8);
  }

  /// Scrolls the list inside [page] until [target] is built and visible.
  Future<void> scrollTo(
    WidgetTester tester,
    Finder target, {
    required Type page,
    double delta = 160,
  }) async {
    final scrollable = find
        .descendant(of: find.byType(page), matching: find.byType(Scrollable))
        .last;
    await tester.scrollUntilVisible(target, delta, scrollable: scrollable);
    await settle(tester, frames: 2);
  }

  /// Picks [chip] in an open [ReasonSheet] and confirms it.
  Future<void> confirmReason(WidgetTester tester, String chip) async {
    await scrollTo(
      tester,
      find.byKey(ValueKey('reason-chip-$chip')),
      page: ReasonSheet,
    );
    await tester.tap(find.byKey(ValueKey('reason-chip-$chip')));
    await settle(tester, frames: 2);
    await scrollTo(
      tester,
      find.byKey(const ValueKey('reason-confirm')),
      page: ReasonSheet,
    );
    await tester.tap(find.byKey(const ValueKey('reason-confirm')));
    await settle(tester, frames: 12);
  }

  /// Grants (or declines) a DPDP purpose for the test patient.
  Future<DataConsent> consent(
    DataPurpose purpose, {
    bool granted = true,
    String patientId = testPatientId,
  }) => env.repos.consents.recordDataConsent(
    testCtx,
    DataConsent(
      id: newId(),
      clinicId: testClinicId,
      patientId: patientId,
      purpose: purpose,
      granted: granted,
      noticeVersion: '1',
      languageCode: 'en',
      channel: 'inClinic',
      grantedAt: now.toUtc(),
      createdAt: now.toUtc(),
    ),
  );

  /// Releases everything.
  Future<void> close() async {
    container.dispose();
    await env.close();
  }
}

/// A recall fixture due at [dueAt].
Recall recallFixture({
  required String id,
  required DateTime dueAt,
  RecallType type = RecallType.hygiene,
  Money value = const Money.rupees(1500),
  String patientId = testPatientId,
  RecallStatus status = RecallStatus.due,
}) {
  final t = DateTime.utc(2026, 10, 1);
  return Recall(
    id: id,
    clinicId: testClinicId,
    patientId: patientId,
    type: type,
    dueAt: dueAt.toUtc(),
    status: status,
    estimatedValue: value,
    note: 'Scaling (6 months)',
    createdAt: t,
    updatedAt: t,
  );
}

/// A procedure fixture.
ProcedureRecord procedureFixture({
  required String id,
  required String code,
  required String name,
  required ProcedureStatus status,
  String patientId = testPatientId,
  String? tooth = '36',
  DateTime? startedAt,
  DateTime? completedAt,
  int totalStages = 1,
  List<String> stageNames = const [],
  int stageIndex = 0,
}) {
  final t = DateTime.utc(2026, 9, 1);
  final toothId = tooth == null ? null : ToothId.parse(tooth);
  return ProcedureRecord(
    id: id,
    clinicId: testClinicId,
    patientId: patientId,
    catalogItemId: 'cat-$code',
    code: code,
    name: name,
    tooth: toothId,
    teeth: [?toothId],
    treatmentArea: TreatmentArea.tooth,
    status: status,
    providerId: testDentistId,
    fee: const Money.rupees(5000),
    totalStages: totalStages,
    stageNames: stageNames,
    stageIndex: stageIndex,
    startedAt: startedAt?.toUtc(),
    completedAt: completedAt?.toUtc(),
    createdAt: t,
    updatedAt: (completedAt ?? startedAt ?? t).toUtc(),
  );
}

/// A lab fixture with uniform 5 working-day turnaround.
Lab labFixture({String id = 'lab-1', int days = 5}) => Lab(
  id: id,
  clinicId: testClinicId,
  name: 'Precision Dental Lab',
  phone: '+919000000009',
  whatsappPhone: '+919000000009',
  turnaroundDays: {for (final t in LabCaseType.values) t.name: days},
);

/// A lab case fixture.
LabCase labCaseFixture({
  required String id,
  String labId = 'lab-1',
  String patientId = testPatientId,
  LabCaseType caseType = LabCaseType.crownZirconia,
  LabCaseStatus status = LabCaseStatus.created,
  DateTime? sentAt,
  DateTime? dueAt,
  String? procedureId,
}) {
  final t = DateTime.utc(2026, 10, 10, 9);
  return LabCase(
    id: id,
    clinicId: testClinicId,
    patientId: patientId,
    procedureId: procedureId,
    labId: labId,
    caseType: caseType,
    teeth: [ToothId.parse('16')],
    material: 'Monolithic zirconia',
    shade: 'A2',
    status: status,
    sentAt: sentAt?.toUtc(),
    dueAt: dueAt?.toUtc(),
    labFee: const Money.rupees(2500),
    createdAt: t,
    updatedAt: t,
  );
}
