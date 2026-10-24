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
    return writeTransaction(() async {
      final before = await getExam(exam.id);
      final saved = await audited(
        ctx: ctx,
        table: _exams,
        entityType: 'PerioExam',
        entityId: exam.id,
        before: before,
        after: exam,
        insertable: exam.toInsertable(),
        toJson: (e) => e.toJson(),
      );
      await batch((b) {
        for (final s in exam.sites) {
          b.insert(
            _sites,
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
            mode: InsertMode.insertOrReplace,
          );
        }
      });
      return saved;
    });
  }

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
