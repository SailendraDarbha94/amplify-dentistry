import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_ui/ampdent_ui.dart';

/// How many days ahead the recall list looks for "Upcoming" rows.
const int recallUpcomingWindowDays = 30;

/// Buckets of the recall list, in display order.
enum RecallGroup {
  /// Due before today and still open.
  overdue,

  /// Due on the local calendar day of now.
  dueToday,

  /// Due after today, within [recallUpcomingWindowDays].
  upcoming;

  /// Header label.
  String get label => switch (this) {
    RecallGroup.overdue => 'Overdue',
    RecallGroup.dueToday => 'Due today',
    RecallGroup.upcoming => 'Upcoming',
  };

  /// Badge tone for the header.
  BadgeTone get tone => switch (this) {
    RecallGroup.overdue => BadgeTone.danger,
    RecallGroup.dueToday => BadgeTone.warning,
    RecallGroup.upcoming => BadgeTone.info,
  };
}

/// Picks the group of [recall] relative to the local calendar day of [now].
RecallGroup recallGroupFor(Recall recall, DateTime now) {
  final local = now.toLocal();
  final startOfToday = DateTime(local.year, local.month, local.day);
  final endOfToday = startOfToday.add(const Duration(days: 1));
  final due = recall.dueAt.toLocal();
  if (due.isBefore(startOfToday)) return RecallGroup.overdue;
  if (due.isBefore(endOfToday)) return RecallGroup.dueToday;
  return RecallGroup.upcoming;
}

/// Groups open recalls into [RecallGroup]s, each sorted by due date. Every
/// group key is present (possibly empty) so headers render predictably.
Map<RecallGroup, List<Recall>> groupRecalls(
  Iterable<Recall> recalls,
  DateTime now,
) {
  final out = <RecallGroup, List<Recall>>{
    for (final g in RecallGroup.values) g: <Recall>[],
  };
  for (final r in recalls) {
    if (r.status != RecallStatus.due && r.status != RecallStatus.notified) {
      continue;
    }
    out[recallGroupFor(r, now)]!.add(r);
  }
  for (final list in out.values) {
    list.sort((a, b) => a.dueAt.compareTo(b.dueAt));
  }
  return out;
}

/// Sum of `estimatedValue` over [recalls].
Money recallGroupValue(Iterable<Recall> recalls) =>
    recalls.map((r) => r.estimatedValue).total;

/// Keeps only recalls whose type is in [types]; an empty set keeps all.
List<Recall> filterRecallsByType(
  Iterable<Recall> recalls,
  Set<RecallType> types,
) => types.isEmpty
    ? recalls.toList()
    : recalls.where((r) => types.contains(r.type)).toList();

/// Patient-facing label for a recall type (also used as `{recall_type}`).
String recallTypeLabel(RecallType type) => switch (type) {
  RecallType.hygiene => 'Hygiene',
  RecallType.review => 'Review',
  RecallType.orthoAdjustment => 'Ortho adjustment',
  RecallType.implantReview => 'Implant review',
  RecallType.postOp => 'Post-op check',
  RecallType.custom => 'Follow-up',
};

/// Common reasons offered when dismissing a recall.
const List<String> recallDismissReasons = [
  'Patient declined',
  'Moved away',
  'Treated elsewhere',
  'Duplicate recall',
  'Deceased',
];

/// Message template code for a recall reminder given its group.
String recallTemplateCode(RecallGroup group) =>
    group == RecallGroup.overdue ? 'RECALL_OVERDUE' : 'RECALL_DUE';
