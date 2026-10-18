/// Indian dental procedure catalogue seed.
///
/// Fee ranges come from the research corpus (docs/research/02-product-spec.md
/// and 03-architecture-and-data.md): metro defaults, editable per clinic.
/// All money is integer paise; all codes are unique uppercase-with-hyphens.
library;

import 'package:ampdent_core/ampdent_core.dart';

part 'catalogue/diagnostic_preventive.dart';
part 'catalogue/endodontic_pediatric.dart';
part 'catalogue/implant_cosmetic.dart';
part 'catalogue/oral_surgery.dart';
part 'catalogue/orthodontic_periodontal.dart';
part 'catalogue/other_goods.dart';
part 'catalogue/prosthodontic.dart';
part 'catalogue/restorative.dart';

/// Clinical category of a catalogue procedure. Mirrors the values the core
/// `ProcedureCategory` entity enum is specified to carry; replace with the
/// core enum once `ampdent_core` exports it.
enum ProcedureSeedCategory {
  diagnostic,
  preventive,
  restorative,
  endodontic,
  periodontal,
  prosthodontic,
  oralSurgery,
  orthodontic,
  pediatric,
  implant,
  cosmetic,
  other,
}

/// One seed row of the clinic procedure catalogue.
class ProcedureSeed {
  /// Creates a catalogue seed; fees are integer paise.
  const ProcedureSeed({
    required this.code,
    required this.name,
    required this.laymanName,
    required this.category,
    required this.treatmentArea,
    required this.feeMinPaise,
    required this.feeMaxPaise,
    required this.defaultFeePaise,
    required this.durationMinutes,
    this.gstClass = GstClass.exemptHealthcare,
    this.sacHsnCode = '999312',
    this.stages = const [],
    this.recallInterval,
    this.consentTemplateCode,
    this.requiresPreOpRadiograph = false,
    this.snomedCode,
  });

  /// Unique uppercase code with hyphens, e.g. `RCT-MOL`.
  final String code;

  /// Clinical name shown to the dentist.
  final String name;

  /// Plain-language name printed on estimates and patient messages.
  final String laymanName;

  /// Clinical category.
  final ProcedureSeedCategory category;

  /// Anatomical extent the procedure applies to.
  final TreatmentArea treatmentArea;

  /// Lowest typical fee in paise.
  final int feeMinPaise;

  /// Highest typical fee in paise.
  final int feeMaxPaise;

  /// Default fee in paise used when a clinic has not set its own.
  final int defaultFeePaise;

  /// GST classification of the invoice line.
  final GstClass gstClass;

  /// SAC (services) or HSN (goods) code printed on the invoice line.
  final String sacHsnCode;

  /// Chair time in minutes for scheduling.
  final int durationMinutes;

  /// Multi-sitting stages in order; empty for single-visit procedures.
  final List<String> stages;

  /// Recall interval triggered on completion, if any.
  final RecallInterval? recallInterval;

  /// Code of the consent template to show before starting, if any.
  final String? consentTemplateCode;

  /// Whether a pre-operative radiograph (or documented reason) is required.
  final bool requiresPreOpRadiograph;

  /// SNOMED CT concept id for the procedure, when known.
  final String? snomedCode;

  /// Default fee as [Money].
  Money get defaultFee => Money.paise(defaultFeePaise);

  /// Lowest fee as [Money].
  Money get feeMin => Money.paise(feeMinPaise);

  /// Highest fee as [Money].
  Money get feeMax => Money.paise(feeMaxPaise);

  /// True when the procedure is completed over more than one sitting.
  bool get isMultiSitting => stages.length > 1;

  /// Returns a copy with the given fields replaced.
  ProcedureSeed copyWith({
    String? code,
    String? name,
    String? laymanName,
    ProcedureSeedCategory? category,
    TreatmentArea? treatmentArea,
    int? feeMinPaise,
    int? feeMaxPaise,
    int? defaultFeePaise,
    GstClass? gstClass,
    String? sacHsnCode,
    int? durationMinutes,
    List<String>? stages,
    RecallInterval? recallInterval,
    String? consentTemplateCode,
    bool? requiresPreOpRadiograph,
    String? snomedCode,
  }) => ProcedureSeed(
    code: code ?? this.code,
    name: name ?? this.name,
    laymanName: laymanName ?? this.laymanName,
    category: category ?? this.category,
    treatmentArea: treatmentArea ?? this.treatmentArea,
    feeMinPaise: feeMinPaise ?? this.feeMinPaise,
    feeMaxPaise: feeMaxPaise ?? this.feeMaxPaise,
    defaultFeePaise: defaultFeePaise ?? this.defaultFeePaise,
    gstClass: gstClass ?? this.gstClass,
    sacHsnCode: sacHsnCode ?? this.sacHsnCode,
    durationMinutes: durationMinutes ?? this.durationMinutes,
    stages: stages ?? this.stages,
    recallInterval: recallInterval ?? this.recallInterval,
    consentTemplateCode: consentTemplateCode ?? this.consentTemplateCode,
    requiresPreOpRadiograph:
        requiresPreOpRadiograph ?? this.requiresPreOpRadiograph,
    snomedCode: snomedCode ?? this.snomedCode,
  );

  /// JSON map with enum names and integer paise.
  Map<String, Object?> toJson() => {
    'code': code,
    'name': name,
    'laymanName': laymanName,
    'category': category.name,
    'treatmentArea': treatmentArea.name,
    'feeMinPaise': feeMinPaise,
    'feeMaxPaise': feeMaxPaise,
    'defaultFeePaise': defaultFeePaise,
    'gstClass': gstClass.name,
    'sacHsnCode': sacHsnCode,
    'durationMinutes': durationMinutes,
    'stages': stages,
    'recallInterval': recallInterval?.name,
    'consentTemplateCode': consentTemplateCode,
    'requiresPreOpRadiograph': requiresPreOpRadiograph,
    'snomedCode': snomedCode,
  };

  /// Inverse of [toJson].
  factory ProcedureSeed.fromJson(Map<String, Object?> json) => ProcedureSeed(
    code: json['code'] as String,
    name: json['name'] as String,
    laymanName: json['laymanName'] as String,
    category: ProcedureSeedCategory.values.byName(json['category'] as String),
    treatmentArea: TreatmentArea.values.byName(json['treatmentArea'] as String),
    feeMinPaise: json['feeMinPaise'] as int,
    feeMaxPaise: json['feeMaxPaise'] as int,
    defaultFeePaise: json['defaultFeePaise'] as int,
    gstClass: GstClass.values.byName(json['gstClass'] as String),
    sacHsnCode: json['sacHsnCode'] as String,
    durationMinutes: json['durationMinutes'] as int,
    stages: (json['stages'] as List? ?? const []).cast<String>(),
    recallInterval: json['recallInterval'] == null
        ? null
        : RecallInterval.values.byName(json['recallInterval'] as String),
    consentTemplateCode: json['consentTemplateCode'] as String?,
    requiresPreOpRadiograph: json['requiresPreOpRadiograph'] as bool? ?? false,
    snomedCode: json['snomedCode'] as String?,
  );

  @override
  String toString() => 'ProcedureSeed($code)';
}

/// The full Indian procedure catalogue seed, every category covered.
const List<ProcedureSeed> indianProcedureCatalogue = [
  ...diagnosticProcedures,
  ...preventiveProcedures,
  ...restorativeProcedures,
  ...endodonticProcedures,
  ...pediatricProcedures,
  ...prosthodonticProcedures,
  ...oralSurgeryProcedures,
  ...implantProcedures,
  ...orthodonticProcedures,
  ...periodontalProcedures,
  ...cosmeticProcedures,
  ...otherProcedures,
];

/// Looks up a catalogue seed by code; null when unknown.
ProcedureSeed? procedureSeedByCode(String code) {
  for (final seed in indianProcedureCatalogue) {
    if (seed.code == code) return seed;
  }
  return null;
}

/// All seeds in one category, in catalogue order.
List<ProcedureSeed> proceduresInCategory(ProcedureSeedCategory category) =>
    indianProcedureCatalogue.where((s) => s.category == category).toList();

/// Case-insensitive search over code, name and layman name.
List<ProcedureSeed> searchProcedures(String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];
  return indianProcedureCatalogue
      .where(
        (s) =>
            s.code.toLowerCase().contains(q) ||
            s.name.toLowerCase().contains(q) ||
            s.laymanName.toLowerCase().contains(q),
      )
      .toList();
}

// Private aliases shared by the part files to keep the data compact.
const _cosmetic = GstClass.cosmeticTaxable;
const _goods = GstClass.goods;
const _sacCosmetic = '999722';

const _tooth = TreatmentArea.tooth;
const _surface = TreatmentArea.surface;
const _quadrant = TreatmentArea.quadrant;
const _arch = TreatmentArea.arch;
const _range = TreatmentArea.toothRange;
const _mouth = TreatmentArea.mouth;

/// Standard three-stage RCT sequence.
const List<String> rctStages = [
  'Access and BMP',
  'Obturation',
  'Post-op review',
];

/// Standard three-stage crown sequence.
const List<String> crownStages = [
  'Preparation and impression',
  'Try-in',
  'Cementation',
];

/// Standard denture sequence.
const List<String> dentureStages = [
  'Primary impression',
  'Final impression and jaw relation',
  'Try-in',
  'Insertion',
];
