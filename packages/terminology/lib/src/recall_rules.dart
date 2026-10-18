/// Procedure-triggered recall defaults (Open Dental recalltrigger model with
/// the NICE CG19 interval menu as the clinic-editable picker).
library;

import 'procedure_catalogue.dart';

/// Kinds of recall a completed procedure can trigger.
abstract final class RecallTypes {
  /// Routine hygiene / check-up recall.
  static const String hygiene = 'hygiene';

  /// Clinical review of completed work (e.g. RCT crown follow-up).
  static const String review = 'review';

  /// Recurring orthodontic adjustment visit.
  static const String orthoAdjustment = 'orthoAdjustment';

  /// Annual implant maintenance review.
  static const String implantReview = 'implantReview';

  /// Post-operative check after extraction or surgery.
  static const String postOp = 'postOp';

  /// All valid values.
  static const List<String> all = [
    hygiene,
    review,
    orthoAdjustment,
    implantReview,
    postOp,
  ];
}

/// One recall rule. A rule matches a procedure when its code is listed in
/// [matchCodes] (exact, or prefix when the entry ends with `*`) or, failing
/// that, when its category equals [matchCategory].
class RecallRule {
  /// Creates a recall rule; [dueAfterDays] is counted from completion.
  const RecallRule({
    required this.type,
    required this.dueAfterDays,
    required this.estimatedValuePaise,
    this.matchCodes,
    this.matchCategory,
    this.recurring = false,
  });

  /// Exact codes or `PREFIX-*` patterns; null to match by category only.
  final List<String>? matchCodes;

  /// Category fallback; null to match by code only.
  final ProcedureSeedCategory? matchCategory;

  /// One of [RecallTypes.all].
  final String type;

  /// Days after completion when the recall falls due.
  final int dueAfterDays;

  /// Estimated rupee value of the recall visit, in paise, for the
  /// "overdue recall value" dashboard number.
  final int estimatedValuePaise;

  /// True when the recall repeats on the same interval (ortho adjustments).
  final bool recurring;

  /// `4 weeks` style label when the interval is a whole number of weeks
  /// under three months, else days or months.
  String get intervalLabel {
    if (dueAfterDays >= 90) {
      final months = (dueAfterDays / 30.44).round();
      return '$months month${months == 1 ? '' : 's'}';
    }
    if (dueAfterDays % 7 == 0 && dueAfterDays >= 14) {
      final weeks = dueAfterDays ~/ 7;
      return '$weeks week${weeks == 1 ? '' : 's'}';
    }
    return '$dueAfterDays day${dueAfterDays == 1 ? '' : 's'}';
  }

  /// Whether this rule's code patterns match [code].
  bool matchesCode(String code) {
    final patterns = matchCodes;
    if (patterns == null) return false;
    for (final p in patterns) {
      if (p.endsWith('*')) {
        if (code.startsWith(p.substring(0, p.length - 1))) return true;
      } else if (p == code) {
        return true;
      }
    }
    return false;
  }

  /// Whether this rule matches [seed] by code or by category.
  bool matches(ProcedureSeed seed) =>
      matchesCode(seed.code) ||
      (matchCategory != null && matchCategory == seed.category);

  /// JSON map.
  Map<String, Object?> toJson() => {
    'matchCodes': matchCodes,
    'matchCategory': matchCategory?.name,
    'type': type,
    'dueAfterDays': dueAfterDays,
    'estimatedValuePaise': estimatedValuePaise,
    'recurring': recurring,
  };

  /// Inverse of [toJson].
  factory RecallRule.fromJson(Map<String, Object?> json) => RecallRule(
    matchCodes: (json['matchCodes'] as List?)?.cast<String>(),
    matchCategory: json['matchCategory'] == null
        ? null
        : ProcedureSeedCategory.values.byName(json['matchCategory'] as String),
    type: json['type'] as String,
    dueAfterDays: json['dueAfterDays'] as int,
    estimatedValuePaise: json['estimatedValuePaise'] as int,
    recurring: json['recurring'] as bool? ?? false,
  );

  @override
  String toString() => 'RecallRule($type, $intervalLabel)';
}

/// Default rules in precedence order: code-specific rules first, then
/// category fallbacks. The first match wins.
const List<RecallRule> defaultRecallRules = [
  // Hygiene: 6 months after scaling, exams and fluoride.
  RecallRule(
    matchCodes: ['SCALING-*', 'CONS-NEW', 'CONS-PERIODIC', 'FLUORIDE-*', 'PFS'],
    type: RecallTypes.hygiene,
    dueAfterDays: 180,
    estimatedValuePaise: 1200 * 100,
  ),
  // Perio maintenance: 3 months.
  RecallRule(
    matchCodes: ['PERIO-SRP', 'PERIO-MAINT', 'PERIO-LOCAL-DRUG'],
    type: RecallTypes.hygiene,
    dueAfterDays: 90,
    estimatedValuePaise: 1500 * 100,
  ),
  // Ortho adjustment: every 4 weeks while in active treatment.
  RecallRule(
    matchCodes: [
      'ORTHO-METAL',
      'ORTHO-CERAMIC',
      'ORTHO-SELF-LIG',
      'ORTHO-LINGUAL',
      'ALIGNER-*',
      'ORTHO-ADJ',
      'ORTHO-EXPANDER',
      'ORTHO-MYOFUNCTIONAL',
    ],
    type: RecallTypes.orthoAdjustment,
    dueAfterDays: 28,
    estimatedValuePaise: 500 * 100,
    recurring: true,
  ),
  // Implant review: 12 months.
  RecallRule(
    matchCodes: ['IMP-*'],
    matchCategory: ProcedureSeedCategory.implant,
    type: RecallTypes.implantReview,
    dueAfterDays: 365,
    estimatedValuePaise: 1000 * 100,
  ),
  // RCT -> crown follow-up at 14 days.
  RecallRule(
    matchCodes: ['RCT-*', 'RERCT', 'POST-CORE', 'POST-CORE-CAST', 'ENDO-*'],
    type: RecallTypes.review,
    dueAfterDays: 14,
    estimatedValuePaise: 5000 * 100,
  ),
  // Post-op check 7 days after extraction / surgery.
  RecallRule(
    matchCodes: ['EXT-*', 'OS-*', 'APICO', 'PED-EXT', 'PERIO-FLAP'],
    matchCategory: ProcedureSeedCategory.oralSurgery,
    type: RecallTypes.postOp,
    dueAfterDays: 7,
    estimatedValuePaise: 0,
  ),
  // Perio surgery and grafts: review at 3 months.
  RecallRule(
    matchCategory: ProcedureSeedCategory.periodontal,
    type: RecallTypes.hygiene,
    dueAfterDays: 90,
    estimatedValuePaise: 1500 * 100,
  ),
  // Crowns, bridges and dentures: review at 12 months.
  RecallRule(
    matchCodes: ['CRN-*', 'BRG-*', 'CD-*', 'RPD-*'],
    matchCategory: ProcedureSeedCategory.prosthodontic,
    type: RecallTypes.review,
    dueAfterDays: 365,
    estimatedValuePaise: 500 * 100,
  ),
  // Paediatric work: 6-month hygiene recall.
  RecallRule(
    matchCategory: ProcedureSeedCategory.pediatric,
    type: RecallTypes.hygiene,
    dueAfterDays: 180,
    estimatedValuePaise: 700 * 100,
  ),
  // Preventive and diagnostic fallbacks: 6 months.
  RecallRule(
    matchCategory: ProcedureSeedCategory.preventive,
    type: RecallTypes.hygiene,
    dueAfterDays: 180,
    estimatedValuePaise: 1200 * 100,
  ),
  RecallRule(
    matchCategory: ProcedureSeedCategory.diagnostic,
    type: RecallTypes.hygiene,
    dueAfterDays: 180,
    estimatedValuePaise: 1200 * 100,
  ),
];

/// First default rule that matches [seed]; null when the procedure should
/// not trigger a recall (cosmetic, goods, repairs...).
RecallRule? recallRuleFor(ProcedureSeed seed) {
  for (final rule in defaultRecallRules) {
    if (rule.matchesCode(seed.code)) return rule;
  }
  for (final rule in defaultRecallRules) {
    if (rule.matchCategory != null && rule.matchCategory == seed.category) {
      return rule;
    }
  }
  return null;
}

/// Due date for [seed] completed on [completedOn], or null without a rule.
DateTime? recallDueDate(ProcedureSeed seed, DateTime completedOn) {
  final rule = recallRuleFor(seed);
  if (rule == null) return null;
  return completedOn.add(Duration(days: rule.dueAfterDays));
}
