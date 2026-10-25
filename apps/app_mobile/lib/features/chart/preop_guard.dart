import 'package:ampdent_core/ampdent_core.dart';

import 'chart_mapping.dart';

/// Result class of the pre-operative radiograph check.
enum PreOpOutcome {
  /// The procedure does not need a pre-op radiograph (or is already under
  /// way, so the question was settled at its first sitting).
  notRequired,

  /// A radiograph is attached or was found for the tooth and attached.
  satisfied,

  /// Nothing on record: the clinician must attach one or give a reason.
  missing,
}

/// Outcome of [checkPreOpRadiograph] with the image ids to store.
class PreOpCheck {
  /// Creates a check result.
  const PreOpCheck({
    required this.outcome,
    this.attachedImageIds = const [],
    this.candidates = const [],
  });

  /// How the guard resolved.
  final PreOpOutcome outcome;

  /// Image ids that satisfy the guard (existing plus auto-matched).
  final List<String> attachedImageIds;

  /// Radiographs of the patient the clinician may attach manually.
  final List<ImageRecord> candidates;

  /// Whether the clinician must be asked before proceeding.
  bool get blocks => outcome == PreOpOutcome.missing;
}

/// How old a radiograph of the tooth may be and still count as the pre-op
/// film for work starting now (unless it is explicitly marked pre-op).
const Duration preOpRadiographMaxAge = Duration(days: 90);

/// Whether [image] can stand as the pre-operative radiograph for work that
/// starts at [at]: it is flagged pre-op, or it was captured in the
/// [preOpRadiographMaxAge] window before [at]. Films taken after the start
/// never count.
bool radiographCountsAsPreOp(ImageRecord image, DateTime at) {
  if (!image.kind.isRadiograph) return false;
  if (image.isPreOperative) return true;
  final age = at.difference(image.capturedAt);
  return !age.isNegative && age <= preOpRadiographMaxAge;
}

/// Decides whether work of [kind] may start without a pre-op radiograph.
///
/// The guard applies when the kind (or the catalogue flag) requires one and
/// the work has not started yet ([alreadyStarted] is false). Radiographs
/// already linked in [preOpImageIds], a documented reason in [note], or a
/// radiograph of one of [teeth] (or of [procedureId]) among [images] that
/// [radiographCountsAsPreOp] at [at] satisfies it; the last case is
/// auto-attached. Older films are offered as candidates only.
PreOpCheck checkPreOpRadiograph({
  required ProcedureKind kind,
  required DateTime at,
  bool catalogFlag = false,
  bool alreadyStarted = false,
  Iterable<ToothId> teeth = const [],
  String? procedureId,
  List<String> preOpImageIds = const [],
  String? note,
  Iterable<ImageRecord> images = const [],
}) {
  final needed = procedureNeedsPreOpRadiograph(kind, catalogFlag: catalogFlag);
  if (!needed || alreadyStarted) {
    return PreOpCheck(
      outcome: PreOpOutcome.notRequired,
      attachedImageIds: preOpImageIds,
    );
  }
  if (preOpImageIds.isNotEmpty || hasPreOpReason(note)) {
    return PreOpCheck(
      outcome: PreOpOutcome.satisfied,
      attachedImageIds: preOpImageIds,
    );
  }
  final radiographs = images.where((i) => i.kind.isRadiograph).toList();
  final targets = teeth.toSet();
  final matched = radiographs
      .where(
        (i) =>
            radiographCountsAsPreOp(i, at) &&
            ((procedureId != null && i.procedureId == procedureId) ||
                (targets.isNotEmpty && i.teeth.any(targets.contains))),
      )
      .map((i) => i.id)
      .toList();
  if (matched.isNotEmpty) {
    return PreOpCheck(
      outcome: PreOpOutcome.satisfied,
      attachedImageIds: matched,
      candidates: radiographs,
    );
  }
  return PreOpCheck(outcome: PreOpOutcome.missing, candidates: radiographs);
}

/// [checkPreOpRadiograph] for an existing procedure row.
PreOpCheck checkProcedurePreOp(
  ProcedureRecord procedure, {
  required ProcedureKind kind,
  required DateTime at,
  bool catalogFlag = false,
  Iterable<ImageRecord> images = const [],
}) => checkPreOpRadiograph(
  kind: kind,
  at: at,
  catalogFlag: catalogFlag,
  alreadyStarted: procedure.status == ProcedureStatus.inProgress,
  teeth: procedureTeeth(procedure),
  procedureId: procedure.id,
  preOpImageIds: procedure.preOpImageIds,
  note: procedure.note,
  images: images,
);

/// Marker written into the procedure note when no radiograph was taken.
const String preOpReasonMarker = 'Pre-op radiograph not taken: ';

/// Whether a note carries a documented no-radiograph reason.
bool hasPreOpReason(String? note) => note?.contains(preOpReasonMarker) ?? false;

/// Appends a no-radiograph reason to an existing note.
String appendPreOpReason(String? note, String reason) {
  final line = '$preOpReasonMarker${reason.trim()}';
  if (note == null || note.trim().isEmpty) return line;
  return '${note.trim()}\n$line';
}

/// What the clinician chose in the guard dialog.
class PreOpResolution {
  /// Creates a resolution; at least one of the two must be non-empty.
  const PreOpResolution({this.imageIds = const [], this.reason});

  /// Radiographs to attach.
  final List<String> imageIds;

  /// Typed reason when no radiograph is attached.
  final String? reason;

  /// Whether the resolution satisfies the guard.
  bool get isValid =>
      imageIds.isNotEmpty || (reason != null && reason!.trim().length >= 3);
}
