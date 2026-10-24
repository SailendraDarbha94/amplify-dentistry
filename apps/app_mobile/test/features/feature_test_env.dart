/// Self-contained harness for the plan and consent feature tests: in-memory
/// database, repositories, a provider container with the app overrides and a
/// router that mounts only the feature routes under test (plus a stub
/// patient page), so these tests compile independently of other features.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_data/ampdent_data.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_mobile/core/session.dart';
import 'package:ampdent_mobile/features/consent/consent_service.dart';
import 'package:ampdent_mobile/features/consent/routes.dart';
import 'package:ampdent_mobile/features/consent/signature_pad.dart';
import 'package:ampdent_mobile/features/plan/routes.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:signature/signature.dart';

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

/// Pinned clock for the widget tests.
final DateTime testNow = DateTime.utc(2026, 10, 25, 9);

/// In-memory database, repositories, container and feature router.
class FeatureTestEnv {
  FeatureTestEnv._(this.db, this.signatures)
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
          signatureStoreProvider.overrideWithValue(signatures),
          clockProvider.overrideWithValue(() => testNow),
          signatureExporterProvider.overrideWithValue(fakeSignatureExporter),
        ],
      ) {
    router = GoRouter(
      initialLocation: '/patients/$testPatientId',
      routes: [
        GoRoute(
          path: '/patients/:id',
          builder: (context, state) => Scaffold(
            appBar: AppBar(title: const Text('Patient stub')),
            body: const SizedBox.shrink(),
          ),
        ),
        ...planRoutes,
        ...consentRoutes,
      ],
    );
  }

  /// The open database.
  final AppDatabase db;

  /// In-memory signature store.
  final InMemorySignatureStore signatures;

  /// Repositories over [db].
  final DriftRepositories repos;

  /// Riverpod container with the app overrides.
  final ProviderContainer container;

  /// Router over the feature routes.
  late final GoRouter router;

  /// Opens a fresh environment with a clinic, owner dentist and (optionally)
  /// an adult patient. The global catalogue is seeded when [seedCatalog].
  static Future<FeatureTestEnv> open({
    bool withPatient = true,
    bool seedCatalog = true,
  }) async {
    await initializeDateFormatting('en_IN');
    final db = AppDatabase.inMemory(seedOnOpen: false);
    final repos = DriftRepositories(db);
    await repos.clinics.createClinic(testCtx, testClinic());
    await repos.clinics.upsertMember(testCtx, testDentist());
    if (seedCatalog) await repos.catalog.seedGlobalIfEmpty();
    if (withPatient) {
      await repos.patients.upsert(
        testCtx,
        testPatient(
          patientNumber: await repos.clinics.nextPatientNumber(testCtx),
        ),
      );
    }
    return FeatureTestEnv._(db, InMemorySignatureStore());
  }

  /// Matched location of the top-most route.
  String get location =>
      router.routerDelegate.currentConfiguration.last.matchedLocation;

  /// The widget tree bound to this environment.
  Widget app() => UncontrolledProviderScope(
    container: container,
    child: AppStringsScope(
      strings: AppStrings.en,
      child: MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: router,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [Locale('en', 'IN'), Locale('en')],
        debugShowCheckedModeBanner: false,
      ),
    ),
  );

  /// Pumps the app on a 360 x 800 surface.
  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app());
    await settle(tester);
  }

  /// Navigates and settles.
  Future<void> go(WidgetTester tester, String location) async {
    router.go(location);
    await settle(tester);
  }

  /// Replaces the stored patient.
  Future<Patient> savePatient(Patient patient) =>
      repos.patients.upsert(testCtx, patient);

  /// Releases the container and database.
  Future<void> close() async {
    container.dispose();
    await db.close();
  }
}

/// Stands in for PNG rasterisation (which needs a real engine): encodes
/// the stroke points as bytes so a drawn pad yields a stable signature.
Future<Uint8List?> fakeSignatureExporter(SignatureController c) async {
  if (c.isEmpty) return null;
  return Uint8List.fromList(
    utf8.encode(c.points.map((p) => p.offset.toString()).join(';')),
  );
}

/// Pumps a handful of frames with real durations so database streams
/// resolve.
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

/// An adult patient fixture (DOB 1990-05-20).
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

/// A planned procedure for the fixture patient.
ProcedureRecord plannedProcedure({
  String id = 'proc-rct',
  String code = 'RCT-MOL',
  String name = 'Root canal treatment, molar',
  String tooth = '36',
  Money fee = const Money.rupees(5000),
}) {
  final t = DateTime.utc(2026, 10, 20);
  return ProcedureRecord(
    id: id,
    clinicId: testClinicId,
    patientId: testPatientId,
    catalogItemId: seedId('catalog', code),
    code: code,
    name: name,
    tooth: ToothId.parse(tooth),
    treatmentArea: TreatmentArea.tooth,
    providerId: testDentistId,
    fee: fee,
    plannedAt: t,
    createdAt: t,
    updatedAt: t,
  );
}
