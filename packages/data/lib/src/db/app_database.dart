/// The Drift database: every table, the migration strategy and the two
/// constructors (on-device file, in-memory for tests).
///
/// `app_database.g.dart` is generated and gitignored; regenerate it with
/// `dart run melos run gen` from the repo root (or
/// `dart run build_runner build --delete-conflicting-outputs` in
/// `packages/data`).
library;

import 'dart:convert';

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
import 'tables_sync.dart';

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
    SyncStates,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Opens (creating if needed) the on-device database file [name] through
  /// `drift_flutter`, which picks the platform's application-support folder.
  ///
  /// TODO(security): the file is written unencrypted and relies on the OS
  /// sandbox and device lock alone. Chosen approach: SQLCipher through
  /// drift's encrypted `NativeDatabase` (`sqlcipher_flutter_libs` +
  /// `PRAGMA key` in `setup`, key held in the platform keystore), switched
  /// on once PowerSync confirms it can attach to a SQLCipher database.
  /// Tracked in packages/data/README.md ("Encryption at rest").
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

  /// Rows written before v3 stored furcation as the BPE code `*`; the code
  /// no longer exists, so move the marker into `bpe_furcation` and drop it
  /// from the code map (the sextant keeps no numeric code). Part of the v4
  /// upgrade; public only so the rewrite can be exercised in tests.
  Future<void> migrateLegacyBpeFurcation() async {
    final rows = await customSelect(
      'SELECT id, bpe, bpe_furcation FROM perio_exams '
      "WHERE bpe LIKE '%\"*\"%' OR bpe LIKE '%\"furcation\"%'",
    ).get();
    for (final row in rows) {
      final bpeJson = jsonDecode(row.read<String>('bpe'));
      final flagged = {
        ...const SextantSetConverter().fromSql(
          row.readNullable<String>('bpe_furcation') ?? '[]',
        ),
        ...legacyBpeFurcationFromJson(bpeJson),
      };
      await customUpdate(
        'UPDATE perio_exams SET bpe = ?, bpe_furcation = ? WHERE id = ?',
        variables: [
          Variable<String>(
            const BpeMapConverter().toSql(bpeMapFromJson(bpeJson)),
          ),
          Variable<String>(const SextantSetConverter().toSql(flagged)),
          Variable<String>(row.read<String>('id')),
        ],
        updates: {perioExams},
      );
    }
  }

  /// v6 backfill: rows queued before `message_logs.provider` and
  /// `opt_in_reason` existed stamped both inside `variables` under
  /// `_provider` / `_opt_in_reason` (`LegacyMessageLogKeys`). Copies the
  /// stamps into the real columns where those are still null; the stamps
  /// stay in `variables` (the server trigger still reads them, and an older
  /// build may read the row). Public only so the rewrite can be tested.
  Future<int> migrateLegacyMessageLogStamps() async {
    var changed = 0;
    for (final (column, key) in [
      ('provider', LegacyMessageLogKeys.provider),
      ('opt_in_reason', LegacyMessageLogKeys.optInReason),
    ]) {
      final valid = column == 'provider'
          ? ' AND json_extract(variables, ?) IN '
                "('deeplink', 'cloud_api', 'sms_gateway')"
          : '';
      changed += await customUpdate(
        'UPDATE message_logs SET $column = json_extract(variables, ?) '
        'WHERE $column IS NULL AND json_valid(variables) '
        'AND json_extract(variables, ?) IS NOT NULL$valid',
        variables: [
          Variable<String>('\$.$key'),
          Variable<String>('\$.$key'),
          if (valid.isNotEmpty) Variable<String>('\$.$key'),
        ],
        updates: {messageLogs},
      );
    }
    return changed;
  }

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // v2: the treating dentist is frozen on every issued invoice.
        await m.addColumn(invoices, invoices.dentistId);
        await m.addColumn(invoices, invoices.dentistName);
        await m.addColumn(invoices, invoices.dentistQualifications);
        await m.addColumn(invoices, invoices.dentistRegistrationNumber);
        await m.addColumn(invoices, invoices.dentistRegistrationCouncil);
      }
      if (from < 3) {
        // v3: BPE furcation (*) is a per-sextant flag beside the numeric code.
        await m.addColumn(perioExams, perioExams.bpeFurcation);
      }
      if (from < 4) {
        // v4: clinic-added drugs, the patient snapshot frozen on a
        // prescription, the plan binding of an estimate and the recorded
        // refusal of a written estimate.
        await m.addColumn(drugs, drugs.clinicId);
        await m.addColumn(prescriptions, prescriptions.patientSnapshot);
        await m.addColumn(estimates, estimates.planVersion);
        await m.addColumn(estimates, estimates.planSnapshotHash);
        await m.addColumn(
          treatmentPlans,
          treatmentPlans.estimateDeclinedReason,
        );
        await migrateLegacyBpeFurcation();
      }
      if (from < 5) {
        // v5: per-table pull watermarks, device id and clinic link for the
        // Supabase sync engine.
        await m.createTable(syncStates);
      }
      if (from < 6) {
        // v6: the message provider and opt-in reason become real columns
        // (backfilled from the legacy variables stamps); the outbox gains a
        // hold state so a row the server rejects for good is quarantined
        // instead of retried forever.
        await m.addColumn(messageLogs, messageLogs.provider);
        await m.addColumn(messageLogs, messageLogs.optInReason);
        await migrateLegacyMessageLogStamps();
        await m.addColumn(syncOutbox, syncOutbox.status);
        await m.addColumn(syncOutbox, syncOutbox.serverStatusCode);
        await m.addColumn(syncOutbox, syncOutbox.blockedBy);
      }
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
