/// English labels used only by the chart feature. Kept as one table so a
/// translation hook can swap it without touching the widgets.
abstract final class ChartStrings {
  /// App bar title suffix for the perio page.
  static const String perioChart = 'Perio chart';

  /// Toolbar chip that shows primary teeth alongside permanent ones.
  static const String mixedDentition = 'Mixed';

  /// Tooth action bar buttons.
  static const String addFinding = 'Finding';
  static const String addProcedure = 'Procedure';
  static const String toothState = 'State';
  static const String history = 'History';
  static const String clearSelection = 'Clear selection';

  /// Hint shown when no tooth is selected.
  static const String tapToothHint =
      'Tap a tooth to select it, then tap its surfaces';

  /// Finding kinds.
  static const String caries = 'Caries';
  static const String fracture = 'Fracture';
  static const String mobility = 'Mobility';
  static const String missing = 'Missing';
  static const String other = 'Other';
  static const String icdasSeverity = 'ICDAS severity';
  static const String mobilityGrade = 'Mobility grade';
  static const String alsoMarkMissing = 'Also mark the tooth as missing';
  static const String searchIcd10 = 'Search ICD-10 (K00-K14)';
  static const String description = 'Description';
  static const String note = 'Note';
  static const String noteOptional = 'Note (optional)';
  static const String descriptionRequired = 'Describe the finding';

  /// Procedure tab.
  static const String searchCatalogue = 'Search procedures';
  static const String fee = 'Fee (Rs)';
  static const String feeInvalid = 'Enter a valid fee';
  static const String doneToday = 'Done today';
  static const String stageDoneToday = 'Stage done today';
  static const String allStages = 'All stages complete';
  static const String catalogueEmpty = 'The procedure catalogue is empty';
  static const String chooseAnother = 'Choose another procedure';
  static const String surfacesRequired = 'Select at least one surface';

  /// Tooth state tab.
  static const String currentState = 'Current state';

  /// Procedure quick actions.
  static const String markDone = 'Mark done';
  static const String nextStage = 'Next stage';
  static const String addToBill = 'Add to bill';
  static const String noProcedures = 'No procedures charted yet';
  static const String recallCreated = 'Recall due';
  static const String stageAdvanced = 'Stage advanced';
  static const String procedureCompleted = 'Procedure completed';

  /// Pre-op radiograph guard.
  static const String preOpTitle = 'Pre-operative radiograph';
  static const String preOpBody =
      'This procedure needs a pre-operative radiograph on record before it '
      'starts. Attach one or type the reason it was not taken.';
  static const String preOpAttach = 'Attach a radiograph';
  static const String preOpReason = 'Reason radiograph not taken';
  static const String preOpReasonRequired =
      'Attach a radiograph or give a reason';
  static const String proceed = 'Proceed';

  /// Perio page.
  static const String bpeScreening = 'BPE screening';
  static const String bpeHint =
      'Code 3 unlocks six-point charting for that sextant; code 4 unlocks '
      'the full mouth.';
  static const String chartAll = 'Chart all';
  static const String lockedHint =
      'Enter BPE code 3 or 4 to unlock charting, or turn on Chart all';
  static const String probingDepth = 'PD';
  static const String gingivalMargin = 'GM';
  static const String recession = 'Recession (-)';
  static const String summary = 'Summary';
  static const String sitesRecorded = 'Sites';
  static const String bleedingPercent = 'BOP';
  static const String sitesPd4 = 'PD >= 4';
  static const String sitesPd6 = 'PD >= 6';
  static const String maxCal = 'Max CAL';
  static const String suggestedStage = 'Suggested stage';
  static const String acceptStage = 'Accept';
  static const String stageDisclaimer =
      'Suggestion from CAL only; confirm with bone loss and tooth loss.';
  static const String examSaved = 'Perio exam saved';
  static const String nothingToSave = 'Nothing recorded yet';
  static const String lastExam = 'Last exam';
  static const String noExamYet = 'No perio exam yet';
  static const String upper = 'Upper';
  static const String lower = 'Lower';
}
