import 'package:ampdent_core/ampdent_core.dart';

/// Template code of the general treatment consent. It is obtained once at
/// registration, not chairside, so catalogue items that point at it (exams,
/// scaling, radiographs) do not block the `Mark done` flow; every other
/// template code names a procedure-specific consent that must be on record.
const String generalConsentTemplateCode = 'GENERAL-EXAM';

/// Marker written into the procedure note when work went ahead without a
/// signed consent on record.
const String consentReasonMarker = 'Consent not on record: ';

/// Whether a note carries a documented no-consent reason.
bool hasConsentReason(String? note) =>
    note?.contains(consentReasonMarker) ?? false;

/// Appends a no-consent reason to an existing note.
String appendConsentReason(String? note, String reason) {
  final line = '$consentReasonMarker${reason.trim()}';
  if (note == null || note.trim().isEmpty) return line;
  return '${note.trim()}\n$line';
}

/// Route that opens the consent form for [procedureId] (the template is
/// derived from the procedure's catalogue code there).
String consentRouteFor(String patientId, String procedureId) =>
    '/patients/$patientId/consent/new?procedureIds=$procedureId';

/// Result class of the procedure consent check.
enum ConsentOutcome {
  /// No procedure-specific consent template applies, or the work is already
  /// under way (consent was settled at its first sitting).
  notRequired,

  /// A consent covering the procedure or its template is on record, or a
  /// reason was documented.
  satisfied,

  /// Nothing on record: the clinician must obtain consent or give a reason.
  missing,
}

/// Outcome of [checkProcedureConsent].
class ConsentCheck {
  /// Creates a check result.
  const ConsentCheck({required this.outcome, this.templateCode});

  /// How the guard resolved.
  final ConsentOutcome outcome;

  /// Template the catalogue item asks for, when one applies.
  final String? templateCode;

  /// Whether the clinician must be asked before proceeding.
  bool get blocks => outcome == ConsentOutcome.missing;
}

/// Whether [consent] covers a procedure: it lists [procedureId], or it was
/// signed on the same [templateCode].
bool consentCovers(
  ConsentRecord consent, {
  String? procedureId,
  required String templateCode,
}) =>
    (procedureId != null && consent.procedureIds.contains(procedureId)) ||
    consent.templateCode == templateCode;

/// Decides whether a procedure from [item] may be started (or completed)
/// given the patient's signed [consents]. [procedureId] is null for a
/// procedure that is being created; [note] may already carry a reason.
ConsentCheck checkProcedureConsent({
  required CatalogItem? item,
  String? procedureId,
  String? note,
  bool alreadyStarted = false,
  Iterable<ConsentRecord> consents = const [],
}) {
  final code = item?.consentTemplateCode;
  if (code == null || code == generalConsentTemplateCode || alreadyStarted) {
    return const ConsentCheck(outcome: ConsentOutcome.notRequired);
  }
  if (hasConsentReason(note) ||
      consents.any(
        (c) => consentCovers(c, procedureId: procedureId, templateCode: code),
      )) {
    return ConsentCheck(outcome: ConsentOutcome.satisfied, templateCode: code);
  }
  return ConsentCheck(outcome: ConsentOutcome.missing, templateCode: code);
}

/// [checkProcedureConsent] for an existing procedure row.
ConsentCheck checkExistingProcedureConsent(
  ProcedureRecord procedure, {
  required CatalogItem? item,
  Iterable<ConsentRecord> consents = const [],
}) => checkProcedureConsent(
  item: item,
  procedureId: procedure.id,
  note: procedure.note,
  alreadyStarted: procedure.status == ProcedureStatus.inProgress,
  consents: consents,
);

/// What the clinician chose in the consent guard dialog.
class ConsentResolution {
  /// Proceed now with a typed [reason].
  const ConsentResolution.withReason(this.reason) : getConsent = false;

  /// Leave to the consent form first.
  const ConsentResolution.getConsent() : reason = null, getConsent = true;

  /// Typed reason, when proceeding without consent.
  final String? reason;

  /// Whether the clinician chose to obtain consent first.
  final bool getConsent;

  /// Whether a typed reason is substantial enough to store.
  static bool reasonIsValid(String? reason) =>
      reason != null && reason.trim().length >= 3;
}
