import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_data/ampdent_data.dart';
import 'package:ampdent_mobile/core/navigation_keys.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_mobile/core/session.dart';
import 'package:ampdent_mobile/features/billing/routes.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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

/// Fixed clock for the billing tests.
final DateTime billingNow = DateTime(2026, 10, 25, 10);

/// In-memory database, repositories and a provider container wired like the
/// app, hosting only the billing routes so the tests do not depend on sibling
/// features compiling. Call [open] in `setUp` and [close] in `tearDown`.
class BillingTestEnv {
  BillingTestEnv._(this.db, this.session)
    : repos = DriftRepositories(db),
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          initialSessionProvider.overrideWithValue(session),
          clockProvider.overrideWithValue(() => billingNow),
        ],
      ) {
    router = GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: '/patients/$testPatientId/billing',
      routes: [
        GoRoute(
          path: '/patients/:id',
          builder: (context, state) => const Scaffold(body: Text('patient')),
        ),
        ...billingRoutes,
      ],
    );
  }

  /// The open database.
  final AppDatabase db;

  /// Repositories over [db].
  final DriftRepositories repos;

  /// Session the pages run under.
  final AppSession session;

  /// Riverpod container with the app overrides.
  final ProviderContainer container;

  /// Router over the billing routes only.
  late final GoRouter router;

  /// Opens a fresh environment with a GST-registered clinic, owner dentist,
  /// one chair, the seed catalogue and an adult patient.
  static Future<BillingTestEnv> open() async {
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
    await repos.patients.upsert(
      testCtx,
      testPatient(
        patientNumber: await repos.clinics.nextPatientNumber(testCtx),
      ),
    );
    return BillingTestEnv._(
      db,
      const AppSession(
        deviceId: testDeviceId,
        clinicId: testClinicId,
        memberId: testDentistId,
      ),
    );
  }

  /// Matched location of the top-most route, including imperative pushes.
  String get location =>
      router.routerDelegate.currentConfiguration.last.matchedLocation;

  /// Pumps the billing routes on a 360 x 800 surface at [location].
  Future<void> pump(WidgetTester tester, String location) async {
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
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            supportedLocales: const [Locale('en', 'IN'), Locale('en')],
          ),
        ),
      ),
    );
    router.go(location);
    await settle(tester);
  }

  /// Navigates and settles.
  Future<void> go(WidgetTester tester, String location) async {
    router.go(location);
    await settle(tester);
  }

  /// Releases the container, router and database.
  Future<void> close() async {
    container.dispose();
    router.dispose();
    await db.close();
  }
}

/// Pumps a handful of frames with real durations so database streams resolve
/// without `pumpAndSettle` spinning on progress indicators.
Future<void> settle(
  WidgetTester tester, {
  int frames = 6,
  Duration step = const Duration(milliseconds: 60),
}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(step);
  }
}

/// A clinic fixture (GST registered, Telangana, with a UPI id).
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
    upiVpa: 'smile@upi',
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
