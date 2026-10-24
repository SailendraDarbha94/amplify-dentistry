import 'package:ampdent_core/ampdent_core.dart';

/// Whether the prosthesis for [labCase] is in the clinic and may be seated:
/// the case has come back from the lab (`received`) or passed quality check
/// (`qualityChecked`). The appointments feature uses this to block confirming
/// a seat appointment before the work has arrived (product spec, item 11).
bool canSeat(LabCase labCase) =>
    labCase.status == LabCaseStatus.received ||
    labCase.status == LabCaseStatus.qualityChecked;

/// Human reason a seat appointment cannot be confirmed for [labCase], or null
/// when [canSeat] is true.
String? seatBlockReason(LabCase labCase) {
  if (canSeat(labCase)) return null;
  return switch (labCase.status) {
    LabCaseStatus.created => 'Lab case has not been sent to the lab yet',
    LabCaseStatus.sent => 'Lab case is still with the lab',
    LabCaseStatus.remakeRequested => 'A remake has been requested',
    LabCaseStatus.fitted => 'Lab work has already been fitted',
    LabCaseStatus.cancelled => 'Lab case was cancelled',
    LabCaseStatus.received || LabCaseStatus.qualityChecked => null,
  };
}
