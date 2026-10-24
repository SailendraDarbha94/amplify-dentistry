import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_documents/ampdent_documents.dart' show labCaseTypeLabel;
import 'package:ampdent_ui/ampdent_ui.dart';

export 'package:ampdent_documents/ampdent_documents.dart' show labCaseTypeLabel;

/// VITA classical (Lumin) shades, A1 to D4.
const List<String> vitaClassicalShades = [
  'A1',
  'A2',
  'A3',
  'A3.5',
  'A4',
  'B1',
  'B2',
  'B3',
  'B4',
  'C1',
  'C2',
  'C3',
  'C4',
  'D2',
  'D3',
  'D4',
];

/// Commonly prescribed VITA 3D-Master shades (lightness groups 0 to 5).
const List<String> vita3dMasterShades = [
  '0M1',
  '0M2',
  '0M3',
  '1M1',
  '1M2',
  '2L1.5',
  '2L2.5',
  '2M1',
  '2M2',
  '2M3',
  '2R1.5',
  '2R2.5',
  '3L1.5',
  '3L2.5',
  '3M1',
  '3M2',
  '3M3',
  '3R1.5',
  '3R2.5',
  '4L1.5',
  '4L2.5',
  '4M1',
  '4M2',
  '4M3',
  '4R1.5',
  '4R2.5',
  '5M1',
  '5M2',
  '5M3',
];

/// Impression or scan types offered on the case form.
const List<String> impressionTypes = [
  'Alginate',
  'PVS (putty-wash)',
  'PVS (single step)',
  'Polyether',
  'Intraoral scan',
  'Bite registration only',
];

/// Reasons offered when requesting a remake.
const List<String> remakeReasons = [
  'Open margin',
  'High occlusion',
  'Shade mismatch',
  'Poor contact',
  'Fracture',
  'Does not seat',
  'Wrong tooth / design',
];

/// Open statuses in the order the cases list shows them.
const List<LabCaseStatus> labCaseStatusOrder = [
  LabCaseStatus.created,
  LabCaseStatus.sent,
  LabCaseStatus.received,
  LabCaseStatus.qualityChecked,
  LabCaseStatus.remakeRequested,
  LabCaseStatus.fitted,
  LabCaseStatus.cancelled,
];

/// Material choices for a case type (free text is always allowed).
List<String> materialsFor(LabCaseType type) => switch (type) {
  LabCaseType.crownPfm => const [
    'PFM (Ni-Cr)',
    'PFM (Co-Cr)',
    'PFM (precious)',
  ],
  LabCaseType.crownZirconia => const [
    'Monolithic zirconia',
    'Layered zirconia',
    'Multilayer zirconia',
  ],
  LabCaseType.crownMetal => const ['Ni-Cr', 'Co-Cr', 'Gold alloy'],
  LabCaseType.bridge => const ['PFM', 'Zirconia', 'Metal'],
  LabCaseType.inlayOnlay => const [
    'Lithium disilicate',
    'Zirconia',
    'Composite',
    'Gold',
  ],
  LabCaseType.veneer => const [
    'Lithium disilicate',
    'Feldspathic porcelain',
    'Composite',
  ],
  LabCaseType.completeDenture => const [
    'Heat-cure acrylic',
    'High-impact acrylic',
    'Flexible',
  ],
  LabCaseType.partialDenture => const ['Acrylic', 'Flexible'],
  LabCaseType.castPartial => const ['Co-Cr', 'Titanium'],
  LabCaseType.nightGuard => const ['Hard acrylic', 'Soft', 'Dual laminate'],
  LabCaseType.aligner => const ['PETG', 'TPU'],
  LabCaseType.retainer => const ['Hawley', 'Essix (clear)', 'Bonded wire'],
  LabCaseType.implantCrown => const [
    'Zirconia, screw-retained',
    'Zirconia, cement-retained',
    'PFM',
  ],
  LabCaseType.other => const [],
};

/// Case type implied by a procedure catalogue code, or null when the
/// procedure needs no lab work.
LabCaseType? labCaseTypeForProcedureCode(String code) {
  if (code.startsWith('ALIGNER-')) return LabCaseType.aligner;
  if (code.startsWith('BRG-')) return LabCaseType.bridge;
  return switch (code) {
    'CRN-PFM' => LabCaseType.crownPfm,
    'CRN-ZIR' => LabCaseType.crownZirconia,
    'CRN-METAL' => LabCaseType.crownMetal,
    'CRN-EMAX' ||
    'POST-CORE' ||
    'DEN-RELINE' ||
    'DEN-REPAIR' => LabCaseType.other,
    'VNR-CER' || 'SMILE-VNR' => LabCaseType.veneer,
    'INLAY-CER' || 'ONLAY-CER' => LabCaseType.inlayOnlay,
    'IMP-CROWN' => LabCaseType.implantCrown,
    'CD-ACRYLIC' => LabCaseType.completeDenture,
    'RPD-ACRYLIC' => LabCaseType.partialDenture,
    'RPD-CAST' => LabCaseType.castPartial,
    'NIGHT-GUARD' => LabCaseType.nightGuard,
    'ORTHO-RETAINER' => LabCaseType.retainer,
    'PED-SM-BAND-LOOP' || 'PED-HABIT-APPLIANCE' => LabCaseType.other,
    _ => null,
  };
}

/// Whether a procedure code usually involves a lab case.
bool procedureNeedsLab(String code) =>
    labCaseTypeForProcedureCode(code) != null;

/// Short status label.
String labCaseStatusLabel(LabCaseStatus status) => switch (status) {
  LabCaseStatus.created => 'Created',
  LabCaseStatus.sent => 'Sent',
  LabCaseStatus.received => 'Received',
  LabCaseStatus.qualityChecked => 'QC passed',
  LabCaseStatus.fitted => 'Fitted',
  LabCaseStatus.remakeRequested => 'Remake requested',
  LabCaseStatus.cancelled => 'Cancelled',
};

/// Badge tone per status.
BadgeTone labCaseStatusTone(LabCaseStatus status) => switch (status) {
  LabCaseStatus.created => BadgeTone.neutral,
  LabCaseStatus.sent => BadgeTone.info,
  LabCaseStatus.received => BadgeTone.warning,
  LabCaseStatus.qualityChecked => BadgeTone.success,
  LabCaseStatus.fitted => BadgeTone.completed,
  LabCaseStatus.remakeRequested => BadgeTone.danger,
  LabCaseStatus.cancelled => BadgeTone.neutral,
};

/// Groups cases by status in [labCaseStatusOrder]; within a group overdue
/// cases come first, then by due date, then by creation.
Map<LabCaseStatus, List<LabCase>> groupCasesByStatus(
  Iterable<LabCase> cases,
  DateTime now,
) {
  final out = <LabCaseStatus, List<LabCase>>{
    for (final s in labCaseStatusOrder) s: <LabCase>[],
  };
  for (final c in cases) {
    out[c.status]!.add(c);
  }
  int byDue(LabCase a, LabCase b) {
    final ao = a.isOverdue(now), bo = b.isOverdue(now);
    if (ao != bo) return ao ? -1 : 1;
    final ad = a.dueAt, bd = b.dueAt;
    if (ad != null && bd != null && ad != bd) return ad.compareTo(bd);
    if (ad == null && bd != null) return 1;
    if (ad != null && bd == null) return -1;
    return a.createdAt.compareTo(b.createdAt);
  }

  for (final list in out.values) {
    list.sort(byDue);
  }
  return out;
}

/// Patient-facing name of the work for the LAB_READY_SEAT_APPT message
/// (`{lab_item}`), e.g. `zirconia crown`.
String labItemLabel(LabCase labCase) => switch (labCase.caseType) {
  LabCaseType.crownPfm => 'ceramic crown',
  LabCaseType.crownZirconia => 'zirconia crown',
  LabCaseType.crownMetal => 'metal crown',
  LabCaseType.bridge => 'bridge',
  LabCaseType.inlayOnlay => 'inlay',
  LabCaseType.veneer => 'veneer',
  LabCaseType.completeDenture => 'denture',
  LabCaseType.partialDenture => 'partial denture',
  LabCaseType.castPartial => 'cast partial denture',
  LabCaseType.nightGuard => 'night guard',
  LabCaseType.aligner => 'aligners',
  LabCaseType.retainer => 'retainer',
  LabCaseType.implantCrown => 'implant crown',
  LabCaseType.other => 'lab work',
};

/// `Crown - Zirconia, 16, A2` style one-liner for lists.
String labCaseSummary(LabCase labCase, ToothNotation notation) => [
  labCaseTypeLabel(labCase.caseType),
  if (labCase.teeth.isNotEmpty) notation.formatAll(labCase.teeth, plain: true),
  if (labCase.shade != null && labCase.shade!.isNotEmpty) labCase.shade!,
].join('  ·  ');

/// Parses a comma or space separated list of FDI tooth numbers; returns null
/// when any token is not a tooth.
List<ToothId>? parseTeethInput(String input) {
  final tokens = input
      .split(RegExp(r'[,\s]+'))
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty);
  final out = <ToothId>[];
  for (final t in tokens) {
    final tooth = ToothId.tryParse(t);
    if (tooth == null) return null;
    if (!out.contains(tooth)) out.add(tooth);
  }
  out.sort();
  return out;
}
