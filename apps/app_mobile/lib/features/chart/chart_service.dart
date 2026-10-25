import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_data/ampdent_data.dart';

import 'chart_mapping.dart';
import 'consent_guard.dart';
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

  /// Makes sure a patient's chart carries age-default tooth states.
  ///
  /// On an empty chart every tooth gets an `ageDefault` record for the
  /// patient's current age, written in one batch. On a later open, when the
  /// patient's [DentitionStage] has moved on since the defaults were last
  /// written (a child charted at 8 coming back at 13), the teeth whose
  /// current record is still an age default are re-seeded for the new age.
  /// Records a clinician, procedure or import wrote are never overridden.
  /// Returns the number of records written.
  Future<int> seedAgeDefaults(Patient patient) async {
    final history = await chart.toothStateHistory(patient.id);
    final now = clock().toUtc();
    final age = patient.ageYears(now) ?? defaultAdultAgeYears;
    final defaults = defaultToothStates(ageYears: age);
    if (history.isEmpty) {
      final written = await chart.recordToothStates(ctx, [
        for (final entry in defaults.entries)
          _ageDefaultRecord(patient.id, entry.key, entry.value, age, now),
      ]);
      _log.info('seeded ${written.length} tooth states for ${patient.id}');
      return written.length;
    }
    final latest = _latestPerTooth(history);
    final lastDefault = latest.values
        .where((r) => r.source == ToothStateSource.ageDefault)
        .fold<DateTime?>(
          null,
          (acc, r) => acc == null || r.effectiveFrom.isAfter(acc)
              ? r.effectiveFrom
              : acc,
        );
    if (lastDefault == null) return 0;
    final seededAge = patient.ageYears(lastDefault) ?? defaultAdultAgeYears;
    if (DentitionStage.forAgeYears(seededAge) ==
        DentitionStage.forAgeYears(age)) {
      return 0;
    }
    final refresh = <ToothStateRecord>[
      for (final entry in defaults.entries)
        if (_isAgeDefaultOrAbsent(latest[entry.key]) &&
            latest[entry.key]?.state != entry.value)
          _ageDefaultRecord(patient.id, entry.key, entry.value, age, now),
    ];
    if (refresh.isEmpty) return 0;
    await chart.recordToothStates(ctx, refresh);
    _log.info(
      'refreshed ${refresh.length} age-default tooth states for '
      '${patient.id} (${seededAge.toStringAsFixed(1)} -> '
      '${age.toStringAsFixed(1)} y)',
    );
    return refresh.length;
  }

  static bool _isAgeDefaultOrAbsent(ToothStateRecord? record) =>
      record == null || record.source == ToothStateSource.ageDefault;

  /// Latest record per tooth from a history ordered oldest first.
  static Map<ToothId, ToothStateRecord> _latestPerTooth(
    Iterable<ToothStateRecord> history,
  ) {
    final latest = <ToothId, ToothStateRecord>{};
    for (final r in history) {
      latest[r.tooth] = r;
    }
    return latest;
  }

  ToothStateRecord _ageDefaultRecord(
    String patientId,
    ToothId tooth,
    ToothState state,
    double age,
    DateTime now,
  ) => ToothStateRecord(
    id: newId(),
    clinicId: ctx.clinicId,
    patientId: patientId,
    tooth: tooth,
    state: state,
    effectiveFrom: now,
    source: ToothStateSource.ageDefault,
    recordedBy: ctx.actorId,
    note: 'Age default (${age.toStringAsFixed(1)} y)',
    createdAt: now,
  );

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
  /// [consentReason] comes from the consent guard, [preOpReason] and
  /// [preOpImageIds] from the radiograph guard; all are stored on the row
  /// before the status change.
  Future<MarkDoneResult> markDone(
    ProcedureRecord procedure, {
    CatalogItem? item,
    String? consentReason,
    String? preOpReason,
    List<String>? preOpImageIds,
  }) async {
    var current = procedure;
    final consent = consentReason?.trim() ?? '';
    final reason = preOpReason?.trim() ?? '';
    final images = preOpImageIds ?? const <String>[];
    final addImages = images.where((id) => !current.preOpImageIds.contains(id));
    if (consent.isNotEmpty || reason.isNotEmpty || addImages.isNotEmpty) {
      var note = current.note;
      if (consent.isNotEmpty) note = appendConsentReason(note, consent);
      if (reason.isNotEmpty) note = appendPreOpReason(note, reason);
      current = await chart.updateProcedure(
        ctx,
        current.copyWith(
          note: note,
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
  /// state change implied by extractions, implant placement and implant
  /// removal (which leaves the site missing, not implant).
  Future<Recall?> _afterStatusChange(
    ProcedureRecord p,
    CatalogItem? item,
  ) async {
    if (p.status != ProcedureStatus.completed) return null;
    final kind = classifyProcedure(p.code, category: item?.category);
    final toothState = switch (kind) {
      ProcedureKind.extraction => ToothState.extracted,
      ProcedureKind.implant => ToothState.implant,
      ProcedureKind.explant => ToothState.missing,
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
    // Due on the same calendar day N months on, in the device's local
    // calendar: a procedure finished at 23:30 IST belongs to that local
    // date, not to the UTC date (which is already the previous day).
    final completedLocal = completedOn.toLocal();
    final dueAt = DateTime(
      completedLocal.year,
      completedLocal.month + interval.months,
      completedLocal.day,
    ).toUtc();
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
        dueAt: dueAt,
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
