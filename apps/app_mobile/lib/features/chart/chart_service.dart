import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_data/ampdent_data.dart';

import 'chart_mapping.dart';
import 'preop_guard.dart';

/// Age assumed when a patient has neither a date of birth nor an
/// approximate age: a full permanent dentition including third molars.
const double defaultAdultAgeYears = 30;

/// Result of marking a procedure done: the updated row and any recall it
/// triggered.
class MarkDoneResult {
  /// Creates a result.
  const MarkDoneResult({required this.procedure, this.recall});

  /// The procedure after the status change.
  final ProcedureRecord procedure;

  /// Recall created when the procedure completed, if a rule matched.
  final Recall? recall;

  /// Whether the procedure is now complete (vs. advanced one stage).
  bool get completed => procedure.status == ProcedureStatus.completed;
}

/// Every write the chart feature makes, routed through the repositories
/// with the actor context. Pure of Flutter so it is unit-testable.
class ChartService {
  /// Creates the service.
  const ChartService({
    required this.chart,
    required this.recalls,
    required this.clinics,
    required this.ctx,
    required this.clock,
  });

  /// Odontogram repository.
  final ChartRepository chart;

  /// Recall repository.
  final RecallRepository recalls;

  /// Clinic repository (notation setting).
  final ClinicRepository clinics;

  /// Actor for every write.
  final ActorContext ctx;

  /// Clock, injectable for tests.
  final DateTime Function() clock;

  static const Logger _log = Logger('chart');

  /// Writes age-default tooth states for a patient with an empty chart and
  /// returns the number of records written (0 when a chart existed).
  Future<int> seedAgeDefaults(Patient patient) async {
    final current = await chart.currentStates(patient.id);
    if (current.isNotEmpty) return 0;
    final now = clock().toUtc();
    final age = patient.ageYears(now) ?? defaultAdultAgeYears;
    final defaults = defaultToothStates(ageYears: age);
    for (final entry in defaults.entries) {
      await chart.recordToothState(
        ctx,
        ToothStateRecord(
          id: newId(),
          clinicId: ctx.clinicId,
          patientId: patient.id,
          tooth: entry.key,
          state: entry.value,
          effectiveFrom: now,
          source: ToothStateSource.ageDefault,
          recordedBy: ctx.actorId,
          note: 'Age default (${age.toStringAsFixed(1)} y)',
          createdAt: now,
        ),
      );
    }
    _log.info('seeded ${defaults.length} tooth states for ${patient.id}');
    return defaults.length;
  }

  /// Appends a clinician-recorded tooth state.
  Future<ToothStateRecord> setToothState({
    required String patientId,
    required ToothId tooth,
    required ToothState state,
    String? note,
    String? procedureId,
    ToothStateSource source = ToothStateSource.clinician,
  }) {
    final now = clock().toUtc();
    return chart.recordToothState(
      ctx,
      ToothStateRecord(
        id: newId(),
        clinicId: ctx.clinicId,
        patientId: patientId,
        tooth: tooth,
        state: state,
        effectiveFrom: now,
        source: source,
        procedureId: procedureId,
        recordedBy: ctx.actorId,
        note: (note ?? '').trim().isEmpty ? null : note!.trim(),
        createdAt: now,
      ),
    );
  }

  /// Records a finding on a tooth (or the mouth when [tooth] is null).
  Future<Finding> addFinding({
    required String patientId,
    ToothId? tooth,
    SurfaceSet surfaces = const SurfaceSet.empty(),
    required String description,
    IcdasCode? icdas,
    String? icd10Code,
    String? note,
    String? visitId,
  }) {
    final now = clock().toUtc();
    return chart.addFinding(
      ctx,
      Finding(
        id: newId(),
        clinicId: ctx.clinicId,
        patientId: patientId,
        visitId: visitId,
        tooth: tooth,
        surfaces: surfaces,
        icd10Code: icd10Code,
        description: description.trim(),
        icdas: icdas,
        recordedAt: now,
        recordedBy: ctx.actorId,
        note: (note ?? '').trim().isEmpty ? null : note!.trim(),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  /// Creates a procedure from a catalogue item. [status] is `planned`,
  /// `inProgress` (a stage done today on multi-sitting work) or
  /// `completed`. Completion triggers the recall and tooth-state effects.
  Future<MarkDoneResult> addProcedure({
    required String patientId,
    required CatalogItem item,
    ToothId? tooth,
    List<ToothId> teeth = const [],
    SurfaceSet surfaces = const SurfaceSet.empty(),
    required Money fee,
    ProcedureStatus status = ProcedureStatus.planned,
    int stageIndex = 0,
    String? note,
    List<String> preOpImageIds = const [],
    String? visitId,
  }) async {
    final now = clock().toUtc();
    final totalStages = item.stages.isEmpty ? 1 : item.stages.length;
    final record = ProcedureRecord(
      id: newId(),
      clinicId: ctx.clinicId,
      patientId: patientId,
      visitId: visitId,
      catalogItemId: item.id,
      code: item.code,
      name: item.name,
      tooth: tooth,
      teeth: teeth,
      surfaces: surfaces,
      treatmentArea: item.treatmentArea,
      status: status,
      providerId: ctx.actorId,
      fee: fee,
      stageIndex: stageIndex.clamp(0, totalStages - 1),
      totalStages: totalStages,
      stageNames: item.stages,
      plannedAt: now,
      startedAt: status == ProcedureStatus.planned ? null : now,
      completedAt: status == ProcedureStatus.completed ? now : null,
      note: (note ?? '').trim().isEmpty ? null : note!.trim(),
      preOpImageIds: preOpImageIds,
      createdAt: now,
      updatedAt: now,
    );
    final created = await chart.createProcedure(ctx, record);
    final recall = await _afterStatusChange(created, item);
    return MarkDoneResult(procedure: created, recall: recall);
  }

  /// Marks a procedure done: advances one stage on multi-sitting work
  /// (completing on the last stage) or completes single-sitting work.
  /// [preOpReason] and [preOpImageIds] come from the radiograph guard and
  /// are stored on the row before the status change.
  Future<MarkDoneResult> markDone(
    ProcedureRecord procedure, {
    CatalogItem? item,
    String? preOpReason,
    List<String>? preOpImageIds,
  }) async {
    var current = procedure;
    final reason = preOpReason?.trim() ?? '';
    final images = preOpImageIds ?? const <String>[];
    final addImages = images.where((id) => !current.preOpImageIds.contains(id));
    if (reason.isNotEmpty || addImages.isNotEmpty) {
      current = await chart.updateProcedure(
        ctx,
        current.copyWith(
          note: reason.isEmpty
              ? current.note
              : appendPreOpReason(current.note, reason),
          preOpImageIds: [...current.preOpImageIds, ...addImages],
          updatedAt: clock().toUtc(),
        ),
      );
    }
    final at = clock().toUtc();
    final updated = current.isMultiSitting
        ? await chart.advanceStage(ctx, current.id, at: at)
        : await chart.setProcedureStatus(
            ctx,
            current.id,
            ProcedureStatus.completed,
            at: at,
          );
    final recall = await _afterStatusChange(updated, item);
    return MarkDoneResult(procedure: updated, recall: recall);
  }

  /// Side effects of a completed procedure: recall creation and the tooth
  /// state change implied by extractions and implant placement.
  Future<Recall?> _afterStatusChange(
    ProcedureRecord p,
    CatalogItem? item,
  ) async {
    if (p.status != ProcedureStatus.completed) return null;
    final kind = classifyProcedure(p.code, category: item?.category);
    final toothState = switch (kind) {
      ProcedureKind.extraction => ToothState.extracted,
      ProcedureKind.implant => ToothState.implant,
      _ => null,
    };
    if (toothState != null) {
      for (final tooth in procedureTeeth(p)) {
        await setToothState(
          patientId: p.patientId,
          tooth: tooth,
          state: toothState,
          procedureId: p.id,
          source: ToothStateSource.procedure,
        );
      }
    }
    return createRecall(p, item);
  }

  /// Creates the recall a completed procedure implies: the terminology rule
  /// first, then the catalogue item's own interval as a fallback. A
  /// procedure triggers at most one recall: when one already exists for
  /// [p] it is returned unchanged.
  Future<Recall?> createRecall(ProcedureRecord p, CatalogItem? item) async {
    final existing = await recalls.forProcedure(p.id);
    if (existing != null) return existing;
    final completedOn = p.completedAt ?? clock().toUtc();
    final fromRule = await recalls.createFromProcedure(
      ctx,
      p,
      completedOn: completedOn,
    );
    if (fromRule != null) return fromRule;
    final interval = item?.recallInterval;
    if (interval == null) return null;
    final now = clock().toUtc();
    final type =
        item!.category == ProcedureCategory.preventive ||
            item.category == ProcedureCategory.periodontal
        ? RecallType.hygiene
        : (item.category == ProcedureCategory.implant
              ? RecallType.implantReview
              : RecallType.review);
    return recalls.upsert(
      ctx,
      Recall(
        id: newId(),
        clinicId: ctx.clinicId,
        patientId: p.patientId,
        type: type,
        triggeredByProcedureId: p.id,
        dueAt: DateTime.utc(
          completedOn.year,
          completedOn.month + interval.months,
          completedOn.day,
        ),
        interval: interval,
        estimatedValue: item.defaultFee,
        note: '${item.name} (${interval.months} months)',
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  /// Persists the display notation as the clinic default.
  Future<void> saveNotation(ToothNotation notation) =>
      clinics.saveNotation(ctx, notation);
}
