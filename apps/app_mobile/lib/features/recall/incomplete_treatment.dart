import 'package:ampdent_core/ampdent_core.dart';

/// Days a procedure may sit `inProgress` before it is flagged as stalled.
const int stalledAfterDays = 14;

/// Days after an RCT completes during which a crown may still be planned
/// before the tooth is flagged as unprotected.
const int crownGraceDays = 30;

/// Why a procedure appears on the incomplete-treatment list.
enum IncompleteTreatmentKind {
  /// Multi-sitting work left `inProgress` for over [stalledAfterDays].
  stalledInProgress,

  /// Root canal completed with no crown on the same tooth within
  /// [crownGraceDays].
  rctWithoutCrown;

  /// Short label.
  String get label => switch (this) {
    IncompleteTreatmentKind.stalledInProgress => 'Stalled',
    IncompleteTreatmentKind.rctWithoutCrown => 'RCT without crown',
  };
}

/// One incomplete-treatment finding for the follow-up list.
class IncompleteTreatment {
  /// Creates a finding.
  const IncompleteTreatment({
    required this.procedure,
    required this.kind,
    required this.since,
    this.tooth,
  });

  /// The procedure that is incomplete (the RCT, or the stalled work).
  final ProcedureRecord procedure;

  /// Reason it is listed.
  final IncompleteTreatmentKind kind;

  /// When the clock started: `startedAt` for stalled work, `completedAt`
  /// for an RCT.
  final DateTime since;

  /// Tooth concerned, when single-tooth work.
  final ToothId? tooth;

  /// Patient the procedure belongs to.
  String get patientId => procedure.patientId;

  /// The `{next_step}` text for the TREATMENT_INCOMPLETE template.
  String nextStep(ToothNotation notation) => switch (kind) {
    IncompleteTreatmentKind.rctWithoutCrown =>
      'a crown on tooth ${notation.formatPlain(tooth!)}',
    IncompleteTreatmentKind.stalledInProgress => _nextStage(),
  };

  String _nextStage() {
    final p = procedure;
    final next = p.stageIndex + 1;
    if (p.isMultiSitting && next < p.stageNames.length) {
      return p.stageNames[next].toLowerCase();
    }
    if (p.isMultiSitting && next < p.totalStages) {
      return 'sitting ${next + 1} of ${p.totalStages}';
    }
    return 'completing the ${p.name.toLowerCase()}';
  }
}

/// Whether [code] is a root canal catalogue code (`RCT-*`, `RERCT`).
bool isRootCanalCode(String code) => code.startsWith('RCT-') || code == 'RERCT';

/// Whether [code] is a crown-type restoration that protects an endodontically
/// treated tooth (`CRN-*`, bridge units, implant crown, onlay).
bool isCrownCode(String code) =>
    code.startsWith('CRN-') ||
    code.startsWith('BRG-') ||
    code == 'IMP-CROWN' ||
    code == 'ONLAY-CER';

bool _coversTooth(ProcedureRecord p, ToothId tooth) =>
    p.tooth == tooth || p.teeth.contains(tooth);

bool _countsAsPlanned(ProcedureStatus s) =>
    s != ProcedureStatus.deleted &&
    s != ProcedureStatus.plannedInactive &&
    s != ProcedureStatus.condition;

/// Scans [procedures] (one clinic, any number of patients) and returns the
/// incomplete-treatment findings as of [now], oldest first.
///
/// - `inProgress` rows whose `startedAt` (or `updatedAt`) is more than
///   [stalledAfterDays] ago are stalled.
/// - A `completed` root canal on a single tooth with no crown-type procedure
///   (any live status) on the same tooth for the same patient is flagged once
///   [crownGraceDays] have passed since completion.
List<IncompleteTreatment> detectIncompleteTreatments(
  Iterable<ProcedureRecord> procedures, {
  required DateTime now,
}) {
  final all = procedures.toList();
  final out = <IncompleteTreatment>[];
  final stalledBefore = now.subtract(const Duration(days: stalledAfterDays));
  final crownBefore = now.subtract(const Duration(days: crownGraceDays));

  for (final p in all) {
    if (p.status == ProcedureStatus.inProgress) {
      final since = p.startedAt ?? p.updatedAt;
      if (since.isBefore(stalledBefore)) {
        out.add(
          IncompleteTreatment(
            procedure: p,
            kind: IncompleteTreatmentKind.stalledInProgress,
            since: since,
            tooth: p.tooth,
          ),
        );
      }
      continue;
    }
    if (p.status != ProcedureStatus.completed ||
        !isRootCanalCode(p.code) ||
        p.tooth == null ||
        p.completedAt == null) {
      continue;
    }
    final completedAt = p.completedAt!;
    if (!completedAt.isBefore(crownBefore)) continue;
    final tooth = p.tooth!;
    final crowned = all.any(
      (c) =>
          c.patientId == p.patientId &&
          isCrownCode(c.code) &&
          _countsAsPlanned(c.status) &&
          _coversTooth(c, tooth),
    );
    if (crowned) continue;
    out.add(
      IncompleteTreatment(
        procedure: p,
        kind: IncompleteTreatmentKind.rctWithoutCrown,
        since: completedAt,
        tooth: tooth,
      ),
    );
  }
  out.sort((a, b) => a.since.compareTo(b.since));
  return out;
}
