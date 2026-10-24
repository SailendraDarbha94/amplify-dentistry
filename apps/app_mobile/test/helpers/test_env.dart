import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_data/ampdent_data.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_mobile/core/router.dart';
import 'package:ampdent_mobile/core/session.dart';
import 'package:ampdent_mobile/main.dart';
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
/// real app. Call [open] in each test and [close] in `tearDown`.
class AppTestEnv {
  AppTestEnv._(this.db, this.session)
    : repos = DriftRepositories(db),
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          initialSessionProvider.overrideWithValue(session),
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

  /// Opens a fresh environment. With [withClinic] a clinic, owner dentist and
  /// one chair exist; with [withPatient] an adult patient as well.
  static Future<AppTestEnv> open({
    bool withClinic = true,
    bool withPatient = false,
  }) async {
    await initializeDateFormatting('en_IN');
    final db = AppDatabase.inMemory(seedOnOpen: false);
    final repos = DriftRepositories(db);
    if (withClinic) {
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
    }
    final session = withClinic
        ? const AppSession(
            deviceId: testDeviceId,
            clinicId: testClinicId,
            memberId: testDentistId,
          )
        : const AppSession(deviceId: testDeviceId);
    return AppTestEnv._(db, session);
  }

  /// The app router from the container.
  GoRouter get router => container.read(routerProvider);

  /// Matched location of the top-most route, including imperative pushes
  /// (go_router's `currentConfiguration.uri` only reflects `go`).
  String get location =>
      router.routerDelegate.currentConfiguration.last.matchedLocation;

  /// The full app widget bound to this environment.
  Widget app() => UncontrolledProviderScope(
    container: container,
    child: const AmpDentApp(),
  );

  /// Pumps the full app on a phone-sized surface (360 x 800 logical px) and
  /// lets the first frame settle.
  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app());
    await settle(tester);
  }

  /// Inserts a patient with a freshly minted number.
  Future<Patient> addPatient(Patient patient) async => repos.patients.upsert(
    testCtx,
    patient.copyWith(
      patientNumber: await repos.clinics.nextPatientNumber(testCtx),
    ),
  );

  /// Navigates and settles.
  Future<void> go(WidgetTester tester, String location) async {
    router.go(location);
    await settle(tester);
  }

  /// Releases the container and database.
  Future<void> close() async {
    container.dispose();
    await db.close();
  }
}

/// Pumps a handful of frames with real durations so database streams and
/// animations resolve without relying on `pumpAndSettle` (which can spin on
/// indeterminate progress indicators).
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
