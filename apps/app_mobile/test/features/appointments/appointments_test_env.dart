/// Self-contained harness for the appointments feature: in-memory database,
/// the app's providers, and a router that mounts only `appointmentsRoutes`
/// (plus a stub patient page). It deliberately does not import
/// `core/router.dart` or `main.dart`, so these tests compile even while
/// other features are mid-change.
library;

import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_data/ampdent_data.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_mobile/core/session.dart';
import 'package:ampdent_mobile/features/appointments/appointment_providers.dart';
import 'package:ampdent_mobile/features/appointments/routes.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Fixed ids used by the fixtures.
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

/// In-memory database, repositories and a provider container wired like the
/// real app, with a recording URI launcher.
class ApptTestEnv {
  ApptTestEnv._(this.db, this.session, this.launched)
    : repos = DriftRepositories(db),
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          initialSessionProvider.overrideWithValue(session),
          uriLauncherProvider.overrideWithValue((uri) async {
            launched.add(uri);
            return true;
          }),
        ],
      );

  /// The open database.
  final AppDatabase db;

  /// Repositories over [db].
  final DriftRepositories repos;

  /// Session the app starts with.
  final AppSession session;

  /// Riverpod container with the app overrides.
  final ProviderContainer container;

  /// Every URI handed to the fake launcher.
  final List<Uri> launched;

  GoRouter? _router;

  /// Opens a fresh environment with a clinic, owner dentist, one chair and
  /// (optionally) an adult patient.
  static Future<ApptTestEnv> open({bool withPatient = true}) async {
    await initializeDateFormatting('en_IN');
    final db = AppDatabase.inMemory(seedOnOpen: false);
    final repos = DriftRepositories(db);
    await repos.clinics.createClinic(testCtx, testClinic());
    await repos.clinics.upsertMember(testCtx, testDentist());
    await repos.clinics.upsertChair(
      testCtx,
      const Chair(id: 'chair-1', clinicId: testClinicId, name: 'Chair 1'),
    );
    if (withPatient) {
      await repos.patients.upsert(
        testCtx,
        testPatient(
          patientNumber: await repos.clinics.nextPatientNumber(testCtx),
        ),
      );
    }
    const session = AppSession(
      deviceId: testDeviceId,
      clinicId: testClinicId,
      memberId: testDentistId,
    );
    return ApptTestEnv._(db, session, []);
  }

  /// Router over the appointments routes and a stub patient page.
  GoRouter get router => _router ??= GoRouter(
    initialLocation: '/schedule',
    routes: [
      ...appointmentsRoutes,
      GoRoute(
        path: '/patients/:id',
        builder: (context, state) => Scaffold(
          appBar: AppBar(title: const Text('Patient')),
          body: Center(child: Text(state.pathParameters['id']!)),
        ),
      ),
    ],
  );

  /// Matched location of the top-most route.
  String get location =>
      router.routerDelegate.currentConfiguration.last.matchedLocation;

  /// Pumps the feature on a 360 x 800 surface and settles the first frame.
  Future<void> pumpApp(WidgetTester tester) async {
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
    await settle(tester);
  }

  /// Navigates and settles.
  Future<void> go(WidgetTester tester, String location) async {
    router.go(location);
    await settle(tester);
  }

  /// Inserts a patient with a freshly minted number.
  Future<Patient> addPatient(Patient patient) async => repos.patients.upsert(
    testCtx,
    patient.copyWith(
      patientNumber: await repos.clinics.nextPatientNumber(testCtx),
    ),
  );

  /// Releases the container, router and database.
  Future<void> close() async {
    container.dispose();
    _router?.dispose();
    await db.close();
  }
}

/// Scrolls the widget with [key] into view, then taps it. Detail pages are
/// longer than the 800 px test surface, so a bare `tap` would miss.
Future<void> tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await settle(tester, frames: 2);
  await tester.tap(finder);
}

/// Pumps a handful of frames with real durations so database streams and
/// animations resolve without `pumpAndSettle`.
Future<void> settle(
  WidgetTester tester, {
  int frames = 6,
  Duration step = const Duration(milliseconds: 60),
}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(step);
  }
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

/// An adult patient fixture.
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

/// A scheduled appointment fixture at [start] (local), 30 minutes long.
Appointment testAppointment(
  DateTime start, {
  String id = 'appt-1',
  String patientId = testPatientId,
  String reason = 'Review',
}) => Appointment(
  id: id,
  clinicId: testClinicId,
  patientId: patientId,
  providerId: testDentistId,
  chairId: 'chair-1',
  startsAt: start.toUtc(),
  endsAt: start.add(const Duration(minutes: 30)).toUtc(),
  reason: reason,
  createdAt: DateTime.utc(2026, 10, 25),
  updatedAt: DateTime.utc(2026, 10, 25),
);

/// An appointment-reminder [DataConsent] row for [patientId].
DataConsent reminderConsent(String patientId, {bool granted = true}) =>
    DataConsent(
      id: 'dc-$patientId',
      clinicId: testClinicId,
      patientId: patientId,
      purpose: DataPurpose.appointmentReminders,
      granted: granted,
      noticeVersion: '1',
      languageCode: 'en',
      channel: 'inClinic',
      grantedAt: DateTime.utc(2026, 10, 20),
      createdAt: DateTime.utc(2026, 10, 20),
    );
