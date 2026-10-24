import 'package:ampdent_core/ampdent_core.dart';

import 'actor_context.dart';

/// One site reading with the exam it came from, for trend charts.
class PerioSitePoint {
  /// Creates a point.
  const PerioSitePoint({
    required this.examId,
    required this.examinedAt,
    required this.reading,
  });

  /// Exam id.
  final String examId;

  /// Exam time.
  final DateTime examinedAt;

  /// The reading.
  final PerioSiteReading reading;
}

/// Periodontal exams. Exams are append-only snapshots; site readings are
/// also flattened into a queryable table.
abstract class PerioRepository {
  /// Stores an exam (and its flattened site readings).
  Future<PerioExam> saveExam(ActorContext ctx, PerioExam exam);

  /// Exam by id.
  Future<PerioExam?> getExam(String id);

  /// Exams for a patient, newest first.
  Future<List<PerioExam>> examsForPatient(String patientId);

  /// Stream of a patient's exams, newest first.
  Stream<List<PerioExam>> watchExams(String patientId);

  /// Latest exam, if any.
  Future<PerioExam?> latestExam(String patientId);

  /// Readings of one site across exams, oldest first.
  Future<List<PerioSitePoint>> siteHistory(
    String patientId,
    ToothId tooth,
    PerioSite site,
  );
}
