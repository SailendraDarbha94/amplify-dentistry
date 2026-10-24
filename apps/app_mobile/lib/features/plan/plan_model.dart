/// Pure treatment-plan logic: the in-memory editor, line factories, fee
/// range checks, phase subtotals and the presented/accepted/scheduled/
/// completed funnel. No Flutter imports.
library;

import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/formatting.dart';

export 'plan_funnel.dart';

/// Default title of a new plan.
const String defaultPlanTitle = 'Treatment plan';

/// Placeholder link sent in estimate messages until the patient portal
/// exists; the UI tells the dentist to share the PDF itself.
const String pendingPortalLink = 'https://link.pending';

/// `Phase 1`, `Phase 2`, ...
String defaultPhaseName(int index) => 'Phase ${index + 1}';

/// Short label for a line's GST class with the rate from the clinic table.
String gstClassLabel(GstClass gstClass, {num? ratePercent}) {
  final base = switch (gstClass) {
    GstClass.exemptHealthcare => 'GST exempt',
    GstClass.cosmeticTaxable => 'Cosmetic',
    GstClass.goods => 'Goods',
    GstClass.standardTaxable => 'Taxable',
  };
  if (gstClass == GstClass.exemptHealthcare || ratePercent == null) return base;
  return '$base, GST ${AppFormat.percent(ratePercent)}';
}

/// Where a fee sits against the catalogue range.
enum FeeRangeStatus { within, below, above, unknown }

/// Compares [unitFee] with the catalogue item's min/max.
FeeRangeStatus feeRangeStatus(Money unitFee, CatalogItem? item) {
  if (item == null) return FeeRangeStatus.unknown;
  if (unitFee < item.feeMin) return FeeRangeStatus.below;
  if (unitFee > item.feeMax) return FeeRangeStatus.above;
  return FeeRangeStatus.within;
}

/// Warning text when the fee is outside the catalogue range, else null.
String? feeRangeWarning(
  Money unitFee,
  CatalogItem? item,
) => switch (feeRangeStatus(unitFee, item)) {
  FeeRangeStatus.below =>
    'Below catalogue minimum ${AppFormat.money(item!.feeMin, showPaise: false)}',
  FeeRangeStatus.above =>
    'Above catalogue maximum ${AppFormat.money(item!.feeMax, showPaise: false)}',
  FeeRangeStatus.within || FeeRangeStatus.unknown => null,
};

/// Net subtotal per phase index (alternatives excluded unless asked).
Map<int, Money> phaseSubtotals(
  Iterable<TreatmentPlanLine> lines, {
  bool includeAlternatives = false,
}) {
  final out = <int, Money>{};
  for (final l in lines) {
    if (l.isAlternative && !includeAlternatives) continue;
    out[l.phaseIndex] = (out[l.phaseIndex] ?? const Money.zero()) + l.net;
  }
  return out;
}

/// Phases padded so every index up to [count - 1] exists.
List<PlanPhase> ensurePhases(List<PlanPhase> phases, int count) {
  final byIndex = {for (final p in phases) p.index: p};
  final n = count > phases.length ? count : phases.length;
  return [
    for (var i = 0; i < n; i++)
      byIndex[i] ?? PlanPhase(index: i, name: defaultPhaseName(i)),
  ];
}

/// A plan line built from an existing planned procedure on the chart.
TreatmentPlanLine lineFromProcedure(
  ProcedureRecord procedure, {
  required TreatmentPlan plan,
  CatalogItem? item,
  int phaseIndex = 0,
  int sequence = 0,
  String? id,
}) => TreatmentPlanLine(
  id: id ?? newId(),
  planId: plan.id,
  clinicId: plan.clinicId,
  patientId: plan.patientId,
  catalogItemId: procedure.catalogItemId,
  code: procedure.code,
  name: procedure.name,
  laymanName: item?.laymanName ?? procedure.name,
  tooth: procedure.tooth,
  teeth: procedure.teeth,
  surfaces: procedure.surfaces,
  treatmentArea: procedure.treatmentArea,
  phaseIndex: phaseIndex,
  sequence: sequence,
  unitFee: procedure.fee,
  discount: procedure.discount,
  gstClass: item?.gstClass ?? GstClass.exemptHealthcare,
  isAlternative: procedure.status == ProcedureStatus.plannedInactive,
  procedureId: procedure.id,
  note: procedure.note,
);

/// A plan line built from a catalogue item at its default fee.
TreatmentPlanLine lineFromCatalogItem(
  CatalogItem item, {
  required TreatmentPlan plan,
  ToothId? tooth,
  List<ToothId> teeth = const [],
  SurfaceSet surfaces = const SurfaceSet.empty(),
  int phaseIndex = 0,
  int sequence = 0,
  String? id,
}) => TreatmentPlanLine(
  id: id ?? newId(),
  planId: plan.id,
  clinicId: plan.clinicId,
  patientId: plan.patientId,
  catalogItemId: item.id,
  code: item.code,
  name: item.name,
  laymanName: item.laymanName,
  tooth: tooth,
  teeth: teeth,
  surfaces: surfaces,
  treatmentArea: item.treatmentArea,
  phaseIndex: phaseIndex,
  sequence: sequence,
  unitFee: item.defaultFee,
  gstClass: item.gstClass,
);

/// The chart procedure that backs a plan line (created on save when the
/// line did not come from an existing procedure).
ProcedureRecord procedureFromLine(
  TreatmentPlanLine line, {
  required String providerId,
  required DateTime now,
  CatalogItem? item,
  String? id,
}) {
  final stages = item?.stages ?? const <String>[];
  return ProcedureRecord(
    id: id ?? newId(),
    clinicId: line.clinicId,
    patientId: line.patientId,
    planId: line.planId,
    planLineId: line.id,
    catalogItemId: line.catalogItemId,
    code: line.code,
    name: line.name,
    tooth: line.tooth,
    teeth: line.teeth,
    surfaces: line.surfaces,
    treatmentArea: line.treatmentArea,
    status: line.isAlternative
        ? ProcedureStatus.plannedInactive
        : ProcedureStatus.planned,
    providerId: providerId,
    fee: line.unitFee.times(line.quantity),
    discount: line.discount,
    totalStages: stages.isEmpty ? 1 : stages.length,
    stageNames: stages,
    plannedAt: now,
    note: line.note,
    createdAt: now,
    updatedAt: now,
  );
}

/// Copy of [base] where the alternative fields may be cleared (plain
/// `copyWith` cannot set them back to null).
TreatmentPlanLine lineWith(
  TreatmentPlanLine base, {
  int? phaseIndex,
  int? quantity,
  Money? unitFee,
  Money? discount,
  bool? isAlternative,
  String? alternativeGroup,
  String? note,
}) {
  final alt = isAlternative ?? base.isAlternative;
  return TreatmentPlanLine(
    id: base.id,
    planId: base.planId,
    clinicId: base.clinicId,
    patientId: base.patientId,
    catalogItemId: base.catalogItemId,
    code: base.code,
    name: base.name,
    laymanName: base.laymanName,
    tooth: base.tooth,
    teeth: base.teeth,
    surfaces: base.surfaces,
    treatmentArea: base.treatmentArea,
    phaseIndex: phaseIndex ?? base.phaseIndex,
    sequence: base.sequence,
    quantity: quantity ?? base.quantity,
    unitFee: unitFee ?? base.unitFee,
    discount: discount ?? base.discount,
    gstClass: base.gstClass,
    isAlternative: alt,
    alternativeGroup: alt
        ? ((alternativeGroup ?? base.alternativeGroup)?.trim().isEmpty ?? true
              ? null
              : (alternativeGroup ?? base.alternativeGroup)!.trim())
        : null,
    procedureId: base.procedureId,
    note: note == null ? base.note : (note.trim().isEmpty ? null : note.trim()),
  );
}

/// Immutable in-memory plan being edited. Every mutation returns a new
/// editor with [dirty] set; the page saves through `PlanService`.
class PlanEditor {
  /// Creates an editor.
  const PlanEditor({
    required this.plan,
    required this.lines,
    this.dirty = false,
  });

  /// The plan header.
  final TreatmentPlan plan;

  /// Live lines ordered by phase then sequence.
  final List<TreatmentPlanLine> lines;

  /// Whether there are unsaved edits.
  final bool dirty;

  /// Accepted or superseded plans cannot be edited; revise instead.
  bool get isFrozen =>
      plan.isAccepted || plan.status == TreatmentPlanStatus.superseded;

  /// Phases, padded to cover every line.
  List<PlanPhase> get phases {
    var max = 0;
    for (final l in lines) {
      if (l.phaseIndex + 1 > max) max = l.phaseIndex + 1;
    }
    return ensurePhases(plan.phases, max == 0 ? 1 : max);
  }

  /// Net total of the default (non-alternative) lines, pre-tax.
  Money get total => planSubtotal(lines);

  /// Net total of the alternative lines, pre-tax.
  Money get alternativesTotal =>
      planSubtotal(lines, includeAlternatives: true) - total;

  /// Net subtotal per phase index (default lines).
  Map<int, Money> get subtotals => phaseSubtotals(lines);

  /// Lines in a phase, in sequence.
  List<TreatmentPlanLine> linesInPhase(int index) =>
      lines.where((l) => l.phaseIndex == index).toList()
        ..sort((a, b) => a.sequence.compareTo(b.sequence));

  /// Distinct alternative group names in use.
  List<String> get alternativeGroups => {
    for (final l in lines)
      if (l.alternativeGroup != null && l.alternativeGroup!.isNotEmpty)
        l.alternativeGroup!,
  }.toList()..sort();

  PlanEditor _with({TreatmentPlan? plan, List<TreatmentPlanLine>? lines}) =>
      PlanEditor(
        plan: plan ?? this.plan,
        lines: lines ?? this.lines,
        dirty: true,
      );

  /// Replaces the header after a save (clears [dirty]).
  PlanEditor saved(TreatmentPlan plan, List<TreatmentPlanLine> lines) =>
      PlanEditor(plan: plan, lines: lines);

  /// Appends [line] at the end of its phase.
  PlanEditor addLine(TreatmentPlanLine line) {
    final inPhase = linesInPhase(line.phaseIndex);
    final seq = inPhase.isEmpty ? 0 : inPhase.last.sequence + 1;
    return _with(
      plan: plan.copyWith(
        phases: ensurePhases(plan.phases, line.phaseIndex + 1),
      ),
      lines: [
        ...lines,
        line.copyWith(sequence: seq),
      ],
    );
  }

  /// Replaces the line with the same id.
  PlanEditor updateLine(TreatmentPlanLine line) => _with(
    plan: plan.copyWith(phases: ensurePhases(plan.phases, line.phaseIndex + 1)),
    lines: [for (final l in lines) l.id == line.id ? line : l],
  );

  /// Drops a line (the repository soft-removes it on save).
  PlanEditor removeLine(String lineId) =>
      _with(lines: lines.where((l) => l.id != lineId).toList());

  /// Moves a line to the end of another phase.
  PlanEditor moveToPhase(String lineId, int phaseIndex) {
    final line = lines.firstWhere((l) => l.id == lineId);
    if (line.phaseIndex == phaseIndex) return this;
    final inPhase = linesInPhase(phaseIndex);
    final seq = inPhase.isEmpty ? 0 : inPhase.last.sequence + 1;
    return updateLine(line.copyWith(phaseIndex: phaseIndex, sequence: seq));
  }

  /// Marks or clears a line as an alternative in [group].
  PlanEditor setAlternative(
    String lineId, {
    required bool alternative,
    String? group,
  }) {
    final line = lines.firstWhere((l) => l.id == lineId);
    return updateLine(
      lineWith(line, isAlternative: alternative, alternativeGroup: group),
    );
  }

  /// Adds a phase after the last one.
  PlanEditor addPhase([String? name]) {
    final current = phases;
    return _with(
      plan: plan.copyWith(
        phases: [
          ...current,
          PlanPhase(
            index: current.length,
            name: name ?? defaultPhaseName(current.length),
          ),
        ],
      ),
    );
  }

  /// Renames a phase.
  PlanEditor renamePhase(int index, String name) => _with(
    plan: plan.copyWith(
      phases: [
        for (final p in phases) p.index == index ? p.copyWith(name: name) : p,
      ],
    ),
  );

  /// Changes the title.
  PlanEditor setTitle(String title) => _with(plan: plan.copyWith(title: title));
}
