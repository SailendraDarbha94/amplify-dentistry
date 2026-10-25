import 'package:ampdent_core/ampdent_core.dart';
import 'package:drift/drift.dart';

import '../../db/app_database.dart';
import '../actor_context.dart';
import '../perio_repository.dart';
import 'audited_writer.dart';

/// Drift implementation of [PerioRepository].
class DriftPerioRepository extends DatabaseAccessor<AppDatabase>
    with AuditedWriter
    implements PerioRepository {
  /// Creates the repository over [db].
  DriftPerioRepository(super.db);

  $PerioExamsTable get _exams => attachedDatabase.perioExams;
  $PerioSiteReadingsTable get _sites => attachedDatabase.perioSiteReadings;

  @override
  Future<PerioExam> saveExam(ActorContext ctx, PerioExam exam) {
    checkTenant(ctx, exam.clinicId, 'exam.clinicId');
    final seen = <String>{};
    for (final s in exam.sites) {
      if (!seen.add('${s.tooth.storageKey}/${s.site.name}')) {
        throw ArgumentError.value(
          '${s.tooth.fdi} ${s.site.name}',
          'exam.sites',
          'recorded twice in one exam',
        );
      }
    }
    return writeTransaction(() async {
      // Exams are snapshots: a re-examination is a new exam id. Saving an
      // existing id would rewrite history (and would have to replace the
      // flattened readings), so it is refused outright.
      if (await getExam(exam.id) != null) {
        throw StateError(
          'PerioExam ${exam.id} is append-only; record a new exam instead',
        );
      }
      final saved = await audited<PerioExam>(
        ctx: ctx,
        table: _exams,
        entityType: 'PerioExam',
        entityId: exam.id,
        before: null,
        after: exam,
        insertable: exam.toInsertable(),
        toJson: (e) => e.toJson(),
      );
      // Plain inserts: readings are never replaced or removed.
      await indexPerioSites(attachedDatabase, exam);
      return saved;
    });
  }

  /// Flattens [exam]'s sites into `perio_site_readings`, the query index
  /// derived from the `sites` JSON column. Called on every local save and by
  /// the sync puller for every exam pulled from the server (`sites` is the
  /// source of truth; the index never syncs). Idempotent: readings already
  /// present for the exam are left alone.
  static Future<void> indexPerioSites(AppDatabase db, PerioExam exam) =>
      db.batch((b) {
        for (final s in exam.sites) {
          b.insert(
            db.perioSiteReadings,
            PerioSiteReadingsCompanion.insert(
              examId: exam.id,
              clinicId: exam.clinicId,
              patientId: exam.patientId,
              examinedAt: exam.examinedAt,
              tooth: s.tooth,
              site: s.site,
              probingDepth: Value(s.probingDepth),
              gingivalMargin: Value(s.gingivalMargin),
              bleeding: s.bleeding,
              suppuration: s.suppuration,
              plaque: s.plaque,
              calculus: s.calculus,
              mucogingivalJunction: Value(s.mucogingivalJunction),
            ),
            mode: InsertMode.insertOrIgnore,
          );
        }
      });

  @override
  Future<PerioExam?> getExam(String id) =>
      (select(_exams)..where((t) => t.id.equals(id))).getSingleOrNull();

  SimpleSelectStatement<$PerioExamsTable, PerioExam> _forPatient(
    String patientId,
  ) => select(_exams)
    ..where((t) => t.patientId.equals(patientId))
    ..orderBy([(t) => OrderingTerm.desc(t.examinedAt)]);

  @override
  Future<List<PerioExam>> examsForPatient(String patientId) =>
      _forPatient(patientId).get();

  @override
  Stream<List<PerioExam>> watchExams(String patientId) =>
      _forPatient(patientId).watch();

  @override
  Future<PerioExam?> latestExam(String patientId) =>
      (_forPatient(patientId)..limit(1)).getSingleOrNull();

  @override
  Future<List<PerioSitePoint>> siteHistory(
    String patientId,
    ToothId tooth,
    PerioSite site,
  ) async {
    final rows =
        await (select(_sites)
              ..where(
                (t) =>
                    t.patientId.equals(patientId) &
                    t.tooth.equalsValue(tooth) &
                    t.site.equalsValue(site),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.examinedAt)]))
            .get();
    return [
      for (final r in rows)
        PerioSitePoint(
          examId: r.examId,
          examinedAt: r.examinedAt,
          reading: PerioSiteReading(
            tooth: r.tooth,
            site: r.site,
            probingDepth: r.probingDepth,
            gingivalMargin: r.gingivalMargin,
            bleeding: r.bleeding,
            suppuration: r.suppuration,
            plaque: r.plaque,
            calculus: r.calculus,
            mucogingivalJunction: r.mucogingivalJunction,
          ),
        ),
    ];
  }
}
