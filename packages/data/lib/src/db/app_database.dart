/// The Drift database: every table, the migration strategy and the two
/// constructors (on-device file, in-memory for tests).
///
/// `app_database.g.dart` is generated and gitignored; regenerate it with
/// `dart run melos run gen` from the repo root (or
/// `dart run build_runner build --delete-conflicting-outputs` in
/// `packages/data`).
library;

import 'package:ampdent_core/ampdent_core.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../seed/seeder.dart';
import 'converters.dart';
import 'tables_billing.dart';
import 'tables_chart.dart';
import 'tables_clinic.dart';
import 'tables_misc.dart';
import 'tables_patient.dart';

part 'app_database.g.dart';

/// Local SQLite store. Open with [AppDatabase.open] in the app and
/// [AppDatabase.inMemory] in tests.
@DriftDatabase(
  tables: [
    Clinics,
    Chairs,
    ClinicMembers,
    Settings,
    SyncOutbox,
    AuditEvents,
    Patients,
    Appointments,
    Visits,
    MedicalHistories,
    ClinicalNotes,
    ImageRecords,
    ConsentRecords,
    DataConsents,
    ToothStateRecords,
    Findings,
    CatalogItems,
    Procedures,
    TreatmentPlans,
    TreatmentPlanLines,
    Estimates,
    PerioExams,
    PerioSiteReadings,
    ImplantRecords,
    Invoices,
    Payments,
    Adjustments,
    LedgerEntries,
    Recalls,
    Labs,
    LabCases,
    Drugs,
    Prescriptions,
    MessageLogs,
    SterilisationCycles,
    Licences,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Opens (creating if needed) the on-device database file [name] through
  /// `drift_flutter`, which picks the platform's application-support folder.
  AppDatabase.open(String name, {bool seedOnOpen = true})
    : this.fromExecutor(driftDatabase(name: name), seedOnOpen: seedOnOpen);

  /// An in-memory database for tests. Seeds the global catalogue and drug
  /// master on open unless [seedOnOpen] is false.
  AppDatabase.inMemory({bool seedOnOpen = true})
    : this.fromExecutor(NativeDatabase.memory(), seedOnOpen: seedOnOpen);

  /// Wraps an arbitrary executor (used by the named constructors).
  AppDatabase.fromExecutor(super.executor, {this.seedOnOpen = true});

  /// Whether `beforeOpen` seeds the global procedure catalogue and drug
  /// master when they are empty.
  final bool seedOnOpen;

  static const Logger _log = Logger('AppDatabase');

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      if (details.wasCreated) _log.info('schema created');
      if (seedOnOpen) {
        final report = await Seeder(this).seedGlobal();
        if (report.anyInserted) {
          _log.info(
            'seeded ${report.catalogItemsInserted} catalogue items, '
            '${report.drugsInserted} drugs',
          );
        }
      }
    },
  );
}
