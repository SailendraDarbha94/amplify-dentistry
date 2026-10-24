import 'package:ampdent_chart_engine/ampdent_chart_engine.dart';
import 'package:ampdent_core/ampdent_core.dart';

/// Clinical family of a procedure as far as the odontogram is concerned.
enum ProcedureKind {
  restoration,
  rootCanal,
  crown,
  extraction,
  implant,
  veneer,
  sealant,
  other,
}

/// Classifies a catalogue code (with its category as a fallback) into the
/// family that decides which overlay the chart draws and whether the pre-op
/// radiograph guard applies.
ProcedureKind classifyProcedure(String code, {ProcedureCategory? category}) {
  final c = code.toUpperCase();
  bool starts(String prefix) => c.startsWith(prefix);
  if (starts('RCT') ||
      c == 'RERCT' ||
      starts('ENDO-') ||
      starts('POST-CORE') ||
      starts('PULP-CAP') ||
      starts('PED-PULP') ||
      c == 'APICO') {
    return ProcedureKind.rootCanal;
  }
  if (starts('CRN-') ||
      starts('BRG-') ||
      c == 'IMP-CROWN' ||
      c == 'PED-SSC' ||
      c == 'PED-STRIP-CROWN') {
    return ProcedureKind.crown;
  }
  if (starts('EXT-') || c == 'PED-EXT') return ProcedureKind.extraction;
  if (c == 'IMP-PLACE') return ProcedureKind.implant;
  if (starts('VNR-') || c == 'SMILE-VNR') return ProcedureKind.veneer;
  if (c == 'PFS') return ProcedureKind.sealant;
  if (starts('COMP-') ||
      starts('GIC-') ||
      starts('INLAY') ||
      starts('ONLAY') ||
      starts('AMAL')) {
    return ProcedureKind.restoration;
  }
  return switch (category) {
    ProcedureCategory.restorative => ProcedureKind.restoration,
    ProcedureCategory.endodontic => ProcedureKind.rootCanal,
    _ => ProcedureKind.other,
  };
}

/// Whether starting a procedure of [kind] needs a pre-operative radiograph
/// on record (or a documented reason). Endodontic, extraction, implant and
/// crown work always do; the catalogue flag extends the rule.
bool procedureNeedsPreOpRadiograph(
  ProcedureKind kind, {
  bool catalogFlag = false,
}) =>
    catalogFlag ||
    kind == ProcedureKind.rootCanal ||
    kind == ProcedureKind.extraction ||
    kind == ProcedureKind.implant ||
    kind == ProcedureKind.crown;

/// Overlay drawn for a procedure, or null when it leaves no mark.
ToothOverlay? overlayForProcedure(ProcedureRecord p, ProcedureKind kind) {
  if (!p.status.showsOnChart || p.status == ProcedureStatus.condition) {
    return null;
  }
  final planned = p.status.isPlanned;
  final started = p.status == ProcedureStatus.inProgress;
  final surfaces = p.surfaces.isEmpty ? null : p.surfaces;
  switch (kind) {
    case ProcedureKind.restoration:
      return ToothOverlay(
        kind: planned
            ? OverlayKind.plannedRestoration
            : OverlayKind.restoration,
        surfaces: surfaces,
      );
    case ProcedureKind.rootCanal:
      return ToothOverlay(
        kind: planned ? OverlayKind.plannedRootCanal : OverlayKind.rootCanal,
      );
    case ProcedureKind.crown:
      return ToothOverlay(
        kind: planned ? OverlayKind.plannedCrown : OverlayKind.crown,
      );
    case ProcedureKind.extraction:
      return ToothOverlay(
        kind: p.status.isDone
            ? OverlayKind.missing
            : OverlayKind.extractionPlanned,
      );
    case ProcedureKind.implant:
      return ToothOverlay(
        kind: planned || started
            ? OverlayKind.plannedImplant
            : OverlayKind.implant,
      );
    case ProcedureKind.veneer:
      return planned
          ? ToothOverlay(
              kind: OverlayKind.plannedRestoration,
              surfaces: surfaces ?? SurfaceSet([ToothSurface.facial]),
            )
          : ToothOverlay(
              kind: OverlayKind.veneer,
              surfaces: surfaces ?? SurfaceSet([ToothSurface.facial]),
            );
    case ProcedureKind.sealant:
      return ToothOverlay(
        kind: planned ? OverlayKind.plannedRestoration : OverlayKind.sealant,
        surfaces: surfaces ?? SurfaceSet([ToothSurface.occlusal]),
      );
    case ProcedureKind.other:
      return null;
  }
}

/// Whether a finding reads as caries (ICDAS code, K02 ICD-10 or wording).
bool findingIsCaries(Finding f) =>
    (f.icdas != null && f.icdas != IcdasCode.sound) ||
    (f.icd10Code?.toUpperCase().startsWith('K02') ?? false) ||
    f.description.toLowerCase().contains('caries');

/// Overlay drawn for a finding, or null for resolved / deleted findings.
ToothOverlay? overlayForFinding(Finding f) {
  if (f.status != FindingStatus.active &&
      f.status != FindingStatus.existingPrior) {
    return null;
  }
  if (f.icdas == IcdasCode.sound) return null;
  final text = f.description.toLowerCase();
  if (findingIsCaries(f)) {
    return ToothOverlay(
      kind: OverlayKind.caries,
      surfaces: f.surfaces.isEmpty ? null : f.surfaces,
    );
  }
  if (text.contains('fractur')) {
    return const ToothOverlay(kind: OverlayKind.fracture);
  }
  if (text.contains('missing')) {
    return const ToothOverlay(kind: OverlayKind.missing);
  }
  return const ToothOverlay(kind: OverlayKind.watch);
}

/// Teeth a procedure applies to: [ProcedureRecord.tooth] or the range.
Iterable<ToothId> procedureTeeth(ProcedureRecord p) =>
    p.tooth != null ? [p.tooth!] : p.teeth;

/// Builds the visual map the [Odontogram] draws: states plus overlays from
/// findings and procedures, with active findings counted into the badge.
Map<ToothId, ToothVisual> buildToothVisuals({
  required Map<ToothId, ToothState> states,
  Iterable<Finding> findings = const [],
  Iterable<ProcedureRecord> procedures = const [],
  Map<String, CatalogItem> catalogById = const {},
}) {
  final visuals = toothVisualsFromStates(states);
  final overlays = <ToothId, List<ToothOverlay>>{};
  final badges = <ToothId, int>{};
  for (final f in findings) {
    final tooth = f.tooth;
    if (tooth == null) continue;
    if (f.status == FindingStatus.active) {
      badges[tooth] = (badges[tooth] ?? 0) + 1;
    }
    final overlay = overlayForFinding(f);
    if (overlay != null) overlays.putIfAbsent(tooth, () => []).add(overlay);
  }
  for (final p in procedures) {
    final item = catalogById[p.catalogItemId];
    final kind = classifyProcedure(p.code, category: item?.category);
    final overlay = overlayForProcedure(p, kind);
    if (overlay == null) continue;
    for (final tooth in procedureTeeth(p)) {
      overlays.putIfAbsent(tooth, () => []).add(overlay);
    }
  }
  for (final entry in overlays.entries) {
    final existing = visuals[entry.key];
    final state = existing?.state ?? ToothState.present;
    // Planned marks paint on top of completed work and findings.
    final sorted = entry.value.toList()
      ..sort((a, b) => (a.kind.isPlanned ? 1 : 0) - (b.kind.isPlanned ? 1 : 0));
    visuals[entry.key] = ToothVisual(
      tooth: entry.key,
      state: state,
      overlays: sorted,
      badgeCount: badges[entry.key] ?? 0,
    );
  }
  for (final entry in badges.entries) {
    if (overlays.containsKey(entry.key)) continue;
    final existing = visuals[entry.key];
    if (existing != null) {
      visuals[entry.key] = existing.copyWith(badgeCount: entry.value);
    }
  }
  return visuals;
}

/// Age below which the chart shows primary and permanent teeth together.
const double mixedDentitionMaxAgeYears = 12.5;

/// Whether the mixed-dentition rows should be on by default: the patient is
/// young enough, or any primary tooth is still charted present.
bool mixedDentitionDefault(double? ageYears, Map<ToothId, ToothState> states) {
  if (ageYears != null && ageYears < mixedDentitionMaxAgeYears) return true;
  return states.entries.any((e) => e.key.isPrimary && e.value.isDrawnPresent);
}

/// Crown faces offered by the surface picker for [tooth], plus class V.
List<ToothSurface> pickableSurfaces(ToothId tooth) => const [
  ToothSurface.mesial,
  ToothSurface.occlusal,
  ToothSurface.distal,
  ToothSurface.facial,
  ToothSurface.lingual,
  ToothSurface.classV,
];

/// `16 (MO)` or just `16` in the given notation.
String describeToothSurfaces(
  ToothId tooth,
  SurfaceSet surfaces,
  ToothNotation notation,
) {
  final label = notation.formatPlain(tooth);
  return surfaces.isEmpty ? label : '$label (${surfaces.labelFor(tooth)})';
}
