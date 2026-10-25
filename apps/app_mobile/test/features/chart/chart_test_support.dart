import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_data/ampdent_data.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_mobile/core/session.dart';
import 'package:ampdent_mobile/features/chart/routes.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Fixed ids used by the fixtures (same values as `test/helpers/test_env`).
const String testClinicId = 'clinic-test';
const String testDentistId = 'member-test';
const String testDeviceId = 'device-test';
const String testPatientId = 'patient-test';

/// Actor used to seed fixtures.
const ActorContext testCtx = ActorContext(
  clinicId: testClinicId,
  actorId: testDentistId,
  deviceId: testDeviceId,
);

/// Route the chart's `Add to bill` action lands on; stubbed here so the
/// chart tests compile independently of the billing feature.
const String billingStubText = 'billing-stub';

/// Route the consent guard's `Get consent` action lands on; stubbed too.
const String consentStubText = 'consent-stub';

/// In-memory database, repositories and a provider container wired like the
/// app, with a router that mounts only the chart routes (plus stubs for the
/// routes the chart navigates to). Independent of the other features so
/// the chart tests compile on their own.
class ChartTestEnv {
  ChartTestEnv._(this.db)
    : repos = DriftRepositories(db),
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          initialSessionProvider.overrideWithValue(
            const AppSession(
              deviceId: testDeviceId,
              clinicId: testClinicId,
              memberId: testDentistId,
            ),
          ),
        ],
      );

  /// The open database.
  final AppDatabase db;

  /// Repositories over [db].
  final DriftRepositories repos;

  /// Riverpod container with the app overrides.
  final ProviderContainer container;

  GoRouter? _router;

  /// Opens a fresh environment with a clinic, owner dentist, one chair, the
  /// seeded global catalogue and an adult patient.
  static Future<ChartTestEnv> open() async {
    await initializeDateFormatting('en_IN');
    final db = AppDatabase.inMemory(seedOnOpen: false);
    final repos = DriftRepositories(db);
    await repos.clinics.createClinic(testCtx, testClinic());
    await repos.clinics.upsertMember(testCtx, testDentist());
    await repos.clinics.upsertChair(
      testCtx,
      const Chair(id: 'chair-1', clinicId: testClinicId, name: 'Chair 1'),
    );
    await repos.catalog.seedGlobalIfEmpty();
    final env = ChartTestEnv._(db);
    await env.addPatient(testPatient());
    return env;
  }

  /// The router (created by [pumpAt]).
  GoRouter get router => _router!;

  /// Matched location of the top-most route, including pushes.
  String get location =>
      router.routerDelegate.currentConfiguration.last.matchedLocation;

  /// Pumps the chart app on a 360 x 800 surface starting at [location].
  Future<void> pumpAt(WidgetTester tester, String location) async {
    final router = GoRouter(
      initialLocation: location,
      routes: [
        ...chartRoutes,
        GoRoute(
          path: '/patients',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('patients-stub'))),
        ),
        GoRoute(
          path: '/patients/:id/billing/invoice/new',
          builder: (context, state) => Scaffold(
            body: Center(child: Text('$billingStubText ${state.uri.query}')),
          ),
        ),
        GoRoute(
          path: '/patients/:id/consent/new',
          builder: (context, state) => Scaffold(
            body: Center(child: Text('$consentStubText ${state.uri.query}')),
          ),
        ),
      ],
    );
    _router = router;
    addTearDown(router.dispose);
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: AppStringsScope(
          strings: AppStrings.en,
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      ),
    );
    await settle(tester, frames: 30);
  }

  /// Navigates and settles.
  Future<void> go(WidgetTester tester, String location) async {
    router.go(location);
    await settle(tester, frames: 30);
  }

  /// Inserts a patient with a freshly minted number.
  Future<Patient> addPatient(Patient patient) async => repos.patients.upsert(
    testCtx,
    patient.copyWith(
      patientNumber: await repos.clinics.nextPatientNumber(testCtx),
    ),
  );

  /// Records a signed procedure consent on [templateCode] for the fixture
  /// patient, covering [procedureIds].
  Future<ConsentRecord> signConsent(
    String templateCode, {
    List<String> procedureIds = const [],
    String patientId = testPatientId,
  }) {
    final t = DateTime.utc(2026, 10, 20, 9);
    return repos.consents.recordConsent(
      testCtx,
      ConsentRecord(
        id: 'consent-$templateCode-${procedureIds.join('-')}',
        clinicId: testClinicId,
        patientId: patientId,
        templateCode: templateCode,
        templateVersionHash: 'hash',
        languageCode: 'en',
        procedureIds: procedureIds,
        renderedText: 'I consent.',
        signerName: 'Asha Rao',
        signerRelation: SignerRelation.self,
        signedAt: t,
        dentistId: testDentistId,
        dentistRegistrationNumber: 'A-12345',
        deviceId: testDeviceId,
        documentHash: 'doc',
        createdAt: t,
      ),
    );
  }

  /// Stores a radiograph of [teeth] captured at [capturedAt].
  Future<ImageRecord> addRadiograph({
    required String id,
    required List<String> teeth,
    required DateTime capturedAt,
    bool isPreOperative = false,
    String patientId = testPatientId,
  }) => repos.clinical.addImage(
    testCtx,
    ImageRecord(
      id: id,
      clinicId: testClinicId,
      patientId: patientId,
      kind: ImageKind.periapical,
      filePath: '/tmp/$id.jpg',
      capturedAt: capturedAt,
      teeth: teeth.map(ToothId.parse).toList(),
      isPreOperative: isPreOperative,
      createdAt: capturedAt,
    ),
  );

  /// Releases the container and database.
  Future<void> close() async {
    container.dispose();
    await db.close();
  }
}

/// Pumps frames with real durations so database streams resolve without
/// `pumpAndSettle` (which can spin on indeterminate progress indicators).
Future<void> settle(
  WidgetTester tester, {
  int frames = 6,
  Duration step = const Duration(milliseconds: 60),
}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(step);
  }
}

/// Clears any SnackBar (they overlap the bottom of scrolled lists).
Future<void> dismissSnackBars(WidgetTester tester) async {
  final messengers = find.byType(ScaffoldMessenger);
  if (messengers.evaluate().isNotEmpty) {
    tester.state<ScaffoldMessengerState>(messengers.first).clearSnackBars();
  }
  await settle(tester);
}

/// Dismisses SnackBars, ensures [key] is visible, taps it and settles.
Future<void> tapKey(WidgetTester tester, String key, {int frames = 8}) async {
  await dismissSnackBars(tester);
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await settle(tester, frames: frames);
}

/// A clinic fixture (GST registered, Telangana).
Clinic testClinic() {
  final t = DateTime.utc(2026, 10, 1);
  return Clinic(
    id: testClinicId,
    name: 'Smile Dental',
    city: 'Hyderabad',
    stateCode: '36',
    pincode: '500034',
    phone: '+919000000001',
    whatsappPhone: '+919000000001',
    gstin: '36ABCDE1234F1Z5',
    createdAt: t,
    updatedAt: t,
  );
}

/// The owner dentist fixture.
ClinicMember testDentist() {
  final t = DateTime.utc(2026, 10, 1);
  return ClinicMember(
    id: testDentistId,
    clinicId: testClinicId,
    displayName: 'Dr. A. Rao',
    role: ClinicRole.ownerDentist,
    registrationNumber: 'A-12345',
    registrationCouncil: 'Telangana State Dental Council',
    qualifications: const ['BDS'],
    phone: '+919000000002',
    createdAt: t,
    updatedAt: t,
  );
}

/// An adult patient fixture (born 1990).
Patient testPatient({
  String id = testPatientId,
  String patientNumber = '',
  String firstName = 'Asha',
  String? lastName = 'Rao',
  String phone = '+919876543210',
  DateTime? dateOfBirth,
}) {
  final t = DateTime.utc(2026, 10, 2);
  return Patient(
    id: id,
    clinicId: testClinicId,
    patientNumber: patientNumber,
    firstName: firstName,
    lastName: lastName,
    phone: phone,
    dateOfBirth: dateOfBirth ?? DateTime.utc(1990, 5, 20),
    sex: Sex.female,
    createdAt: t,
    updatedAt: t,
  );
}
