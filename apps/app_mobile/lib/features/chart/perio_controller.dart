import 'package:ampdent_chart_engine/ampdent_chart_engine.dart';
import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_data/ampdent_data.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One (tooth, site) cell of the perio grid.
typedef PerioCellKey = (ToothId, PerioSite);

/// Unsaved perio exam being entered on the perio page.
@immutable
class PerioDraft {
  /// Creates a draft.
  const PerioDraft({
    this.sites = const {},
    this.teeth = const {},
    this.bpe = const {},
    this.bpeFurcation = const {},
    this.arch = Arch.upper,
    this.aspect = PerioAspect.facial,
    this.measure = PerioMeasurementType.probingDepth,
    this.recession = true,
    this.chartAll = false,
    this.cursor = 0,
    this.lastEntered,
    this.acceptedStage,
  });

  /// Site readings keyed by (tooth, site).
  final Map<PerioCellKey, PerioSiteReading> sites;

  /// Per-tooth readings (mobility, furcation).
  final Map<ToothId, PerioToothReading> teeth;

  /// BPE code per sextant.
  final Map<Sextant, BpeCode> bpe;

  /// Sextants flagged `*` (furcation involvement) beside their code.
  final Set<Sextant> bpeFurcation;

  /// Arch shown.
  final Arch arch;

  /// Aspect shown.
  final PerioAspect aspect;

  /// What the number pad digits set: probing depth or gingival margin.
  final PerioMeasurementType measure;

  /// When entering gingival margin, store digits as recession (negative,
  /// the common case and the default). The clinician toggles it off for a
  /// margin coronal to the CEJ; the choice persists across saved exams.
  final bool recession;

  /// Clinician override: chart every sextant regardless of BPE.
  final bool chartAll;

  /// Position in the entry sequence (the next site to receive a digit).
  final int cursor;

  /// Sequence index of the site that received the last digit, while the
  /// cursor has only moved on by auto-advance. Flag toggles and Clear apply
  /// to this site, so "enter 5, tap BOP" flags the site just probed.
  final int? lastEntered;

  /// Stage the clinician confirmed, if any.
  final PeriodontitisStage? acceptedStage;

  /// Readings that hold at least one value.
  List<PerioSiteReading> get readings =>
      sites.values.where((r) => r.hasAnyValue).toList();

  /// Live summary of the draft.
  PerioSummary get summary => PerioSummary.from(readings);

  /// Whether anything worth saving was entered.
  bool get hasContent =>
      readings.isNotEmpty || bpe.isNotEmpty || bpeFurcation.isNotEmpty;

  /// BPE code 4 anywhere (or the override) unlocks the whole mouth.
  bool get fullMouthUnlocked =>
      chartAll || bpe.values.any((c) => c == BpeCode.code4);

  /// Whether six-point charting is unlocked for a sextant: full mouth, or
  /// that sextant scored 3 or carries the furcation `*`.
  bool sextantUnlocked(Sextant sextant) =>
      fullMouthUnlocked ||
      bpe[sextant] == BpeCode.code3 ||
      bpeFurcation.contains(sextant);

  /// Returns a copy with the given fields replaced.
  PerioDraft copyWith({
    Map<PerioCellKey, PerioSiteReading>? sites,
    Map<ToothId, PerioToothReading>? teeth,
    Map<Sextant, BpeCode>? bpe,
    Set<Sextant>? bpeFurcation,
    Arch? arch,
    PerioAspect? aspect,
    PerioMeasurementType? measure,
    bool? recession,
    bool? chartAll,
    int? cursor,
    int? lastEntered,
    bool clearLastEntered = false,
    PeriodontitisStage? acceptedStage,
    bool clearStage = false,
  }) => PerioDraft(
    sites: sites ?? this.sites,
    teeth: teeth ?? this.teeth,
    bpe: bpe ?? this.bpe,
    bpeFurcation: bpeFurcation ?? this.bpeFurcation,
    arch: arch ?? this.arch,
    aspect: aspect ?? this.aspect,
    measure: measure ?? this.measure,
    recession: recession ?? this.recession,
    chartAll: chartAll ?? this.chartAll,
    cursor: cursor ?? this.cursor,
    lastEntered: clearLastEntered ? null : (lastEntered ?? this.lastEntered),
    acceptedStage: clearStage ? null : (acceptedStage ?? this.acceptedStage),
  );
}

/// Teeth that can be charted: present (or implant) and in an unlocked
/// sextant.
List<ToothId> chartableTeeth(
  PerioDraft draft,
  Map<ToothId, ToothState> states,
) => [
  for (final e in states.entries)
    if ((e.value.isDrawnPresent || e.value == ToothState.implant) &&
        draft.sextantUnlocked(Sextant.of(e.key)))
      e.key,
];

/// Holds the perio draft for one patient and applies number-pad intents.
class PerioController extends Notifier<PerioDraft> {
  /// Creates the controller for [patientId].
  PerioController(this.patientId);

  /// Patient being charted.
  final String patientId;

  @override
  PerioDraft build() => const PerioDraft();

  /// Auto-advance sequence for the current arch, aspect and unlocked teeth.
  List<PerioCellKey> sequence(Map<ToothId, ToothState> states) =>
      perioEntrySequence(
        state.arch,
        state.aspect,
        chartableTeeth(state, states),
      );

  /// Cell under the cursor, or null when the sequence is exhausted/empty.
  PerioCellKey? currentCell(Map<ToothId, ToothState> states) =>
      PerioEntryCursor(sequence(states), state.cursor).current;

  /// Cell that flag toggles and Clear act on: the site that received the
  /// last digit while the cursor has only auto-advanced, else the focused
  /// cell.
  PerioCellKey? flagCell(Map<ToothId, ToothState> states) {
    final last = state.lastEntered;
    final seq = sequence(states);
    if (last != null && last >= 0 && last < seq.length) return seq[last];
    return currentCell(states);
  }

  /// Reading at a cell (an empty one when nothing was entered).
  PerioSiteReading readingAt(PerioCellKey cell) =>
      state.sites[cell] ?? PerioSiteReading(tooth: cell.$1, site: cell.$2);

  /// Sets or clears the BPE code of a sextant.
  void setBpe(Sextant sextant, BpeCode? code) {
    final bpe = Map<Sextant, BpeCode>.of(state.bpe);
    if (code == null) {
      bpe.remove(sextant);
    } else {
      bpe[sextant] = code;
    }
    state = state.copyWith(bpe: bpe, cursor: 0, clearLastEntered: true);
  }

  /// Toggles the furcation `*` flag of a sextant (kept beside its code).
  void toggleBpeFurcation(Sextant sextant) {
    final flags = Set<Sextant>.of(state.bpeFurcation);
    if (!flags.remove(sextant)) flags.add(sextant);
    state = state.copyWith(
      bpeFurcation: flags,
      cursor: 0,
      clearLastEntered: true,
    );
  }

  /// Switches arch; the cursor restarts.
  void setArch(Arch arch) =>
      state = state.copyWith(arch: arch, cursor: 0, clearLastEntered: true);

  /// Switches aspect; the cursor restarts.
  void setAspect(PerioAspect aspect) =>
      state = state.copyWith(aspect: aspect, cursor: 0, clearLastEntered: true);

  /// Switches what the digits set.
  void setMeasure(PerioMeasurementType measure) =>
      state = state.copyWith(measure: measure);

  /// Toggles recession sign for gingival margin entry.
  void toggleRecession() => state = state.copyWith(recession: !state.recession);

  /// Toggles the chart-all override.
  void toggleChartAll() => state = state.copyWith(
    chartAll: !state.chartAll,
    cursor: 0,
    clearLastEntered: true,
  );

  void _put(PerioCellKey cell, PerioSiteReading reading) {
    final sites = Map<PerioCellKey, PerioSiteReading>.of(state.sites);
    sites[cell] = reading;
    state = state.copyWith(sites: sites);
  }

  /// Enters a digit for the focused cell and advances the cursor.
  void enterDigit(int value, Map<ToothId, ToothState> states) {
    final cell = currentCell(states);
    if (cell == null) return;
    final current = readingAt(cell);
    final updated = state.measure == PerioMeasurementType.gingivalMargin
        ? current.copyWith(gingivalMargin: state.recession ? -value : value)
        : current.copyWith(probingDepth: value);
    _put(cell, updated);
    final entered = state.cursor;
    final length = sequence(states).length;
    state = state.copyWith(
      cursor: (entered + 1).clamp(0, length),
      lastEntered: entered,
    );
  }

  /// Moves to the next site (explicit navigation; flags follow the cursor).
  void next(Map<ToothId, ToothState> states) {
    final length = sequence(states).length;
    state = state.copyWith(
      cursor: (state.cursor + 1).clamp(0, length),
      clearLastEntered: true,
    );
  }

  /// Moves to the previous site.
  void previous() => state = state.copyWith(
    cursor: (state.cursor - 1).clamp(0, 1 << 20),
    clearLastEntered: true,
  );

  /// Jumps the cursor to a cell when it is in the sequence.
  void jumpTo(PerioCellKey cell, Map<ToothId, ToothState> states) {
    final i = sequence(states)
        .indexWhere((e) => e.$1 == cell.$1 && e.$2 == cell.$2);
    if (i >= 0) state = state.copyWith(cursor: i, clearLastEntered: true);
  }

  /// Clears the measurement the digits set on the last-entered site (moving
  /// the cursor back to it, as an undo) or on the focused site.
  void clear(Map<ToothId, ToothState> states) {
    final cell = flagCell(states);
    if (cell == null) return;
    final last = state.lastEntered;
    if (last != null) {
      state = state.copyWith(cursor: last, clearLastEntered: true);
    }
    final r = readingAt(cell);
    final gm = state.measure == PerioMeasurementType.gingivalMargin;
    _put(
      cell,
      PerioSiteReading(
        tooth: r.tooth,
        site: r.site,
        probingDepth: gm ? r.probingDepth : null,
        gingivalMargin: gm ? null : r.gingivalMargin,
        bleeding: r.bleeding,
        suppuration: r.suppuration,
        plaque: r.plaque,
        calculus: r.calculus,
        mucogingivalJunction: r.mucogingivalJunction,
      ),
    );
  }

  /// Toggles bleeding / suppuration / plaque / calculus on [flagCell].
  void toggleFlag(PerioMeasurementType type, Map<ToothId, ToothState> states) {
    final cell = flagCell(states);
    if (cell == null) return;
    final r = readingAt(cell);
    final updated = switch (type) {
      PerioMeasurementType.bleedingOnProbing => r.copyWith(
        bleeding: !r.bleeding,
      ),
      PerioMeasurementType.suppuration => r.copyWith(
        suppuration: !r.suppuration,
      ),
      PerioMeasurementType.plaque => r.copyWith(plaque: !r.plaque),
      PerioMeasurementType.calculus => r.copyWith(calculus: !r.calculus),
      _ => r,
    };
    _put(cell, updated);
  }

  /// Cycles a tooth's mobility grade 0 -> 1 -> 2 -> 3 -> 0.
  void cycleMobility(ToothId tooth) {
    final current = state.teeth[tooth] ?? PerioToothReading(tooth: tooth);
    final values = MobilityGrade.values;
    final nextIndex = ((current.mobility?.index ?? -1) + 1) % values.length;
    _putTooth(
      tooth,
      PerioToothReading(
        tooth: tooth,
        mobility: values[nextIndex],
        furcation: current.furcation,
        isImplant: current.isImplant,
      ),
    );
  }

  /// Cycles a tooth's furcation grade 0 -> 1 -> 2 -> 3 -> 0.
  void cycleFurcation(ToothId tooth) {
    final current = state.teeth[tooth] ?? PerioToothReading(tooth: tooth);
    final values = FurcationGrade.values;
    final nextIndex = ((current.furcation?.index ?? -1) + 1) % values.length;
    _putTooth(
      tooth,
      PerioToothReading(
        tooth: tooth,
        mobility: current.mobility,
        furcation: values[nextIndex],
        isImplant: current.isImplant,
      ),
    );
  }

  void _putTooth(ToothId tooth, PerioToothReading reading) {
    final teeth = Map<ToothId, PerioToothReading>.of(state.teeth);
    teeth[tooth] = reading;
    state = state.copyWith(teeth: teeth);
  }

  /// Confirms (or clears) the suggested stage.
  void acceptStage(PeriodontitisStage? stage) =>
      state = state.copyWith(acceptedStage: stage, clearStage: stage == null);

  /// Builds the exam from the draft, flagging absent teeth as skipped and
  /// implants, and persists it. The draft resets afterwards.
  Future<PerioExam> save({
    required ActorContext ctx,
    required PerioRepository repo,
    required DateTime now,
    required Map<ToothId, ToothState> states,
  }) async {
    final at = now.toUtc();
    final teeth = Map<ToothId, PerioToothReading>.of(state.teeth);
    for (final e in states.entries) {
      if (e.value == ToothState.implant) {
        final r = teeth[e.key] ?? PerioToothReading(tooth: e.key);
        teeth[e.key] = PerioToothReading(
          tooth: e.key,
          mobility: r.mobility,
          furcation: r.furcation,
          isImplant: true,
        );
      } else if (e.value.isAbsent && e.key.isPermanent) {
        teeth.putIfAbsent(
          e.key,
          () => PerioToothReading(tooth: e.key, skipped: true),
        );
      }
    }
    final exam = PerioExam(
      id: newId(),
      clinicId: ctx.clinicId,
      patientId: patientId,
      examinedAt: at,
      examinerId: ctx.actorId,
      sites: state.readings,
      teeth: teeth.values.toList(),
      bpe: state.bpe,
      bpeFurcation: state.bpeFurcation,
      stage: state.acceptedStage,
      createdAt: at,
    );
    final saved = await repo.saveExam(ctx, exam);
    state = PerioDraft(recession: state.recession);
    return saved;
  }
}

/// Perio draft per patient.
final perioControllerProvider =
    NotifierProvider.family<PerioController, PerioDraft, String>(
      PerioController.new,
    );
