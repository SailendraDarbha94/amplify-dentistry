import 'package:meta/meta.dart';

import '../dental/clinical_enums.dart';
import '../dental/surfaces.dart';
import '../money/money.dart';
import 'json_support.dart';

/// Clinical category of a catalogue procedure.
enum ProcedureCategory {
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

/// A procedure in the clinic's catalogue (fee schedule). Rows with a null
/// [clinicId] are the global seed from `ampdent_terminology`; a clinic copies
/// and overrides them.
@immutable
class CatalogItem {
  /// Creates a catalogue item.
  const CatalogItem({
    required this.id,
    this.clinicId,
    required this.code,
    required this.name,
    required this.laymanName,
    required this.category,
    required this.treatmentArea,
    required this.defaultFee,
    required this.feeMin,
    required this.feeMax,
    this.gstClass = GstClass.exemptHealthcare,
    required this.sacHsnCode,
    this.durationMinutes = 30,
    this.stages = const [],
    this.recallInterval,
    this.consentTemplateCode,
    this.requiresPreOpRadiograph = false,
    this.externalCodes = const {},
    this.isActive = true,
    this.sortOrder = 0,
  });

  /// UUID v4.
  final String id;

  /// Owning clinic; null for the global seed.
  final String? clinicId;

  /// Short internal code (`RCT-1`, `EXT-S`).
  final String code;

  /// Clinical name.
  final String name;

  /// Patient-facing name used on estimates and plans.
  final String laymanName;

  /// Category.
  final ProcedureCategory category;

  /// Anatomical extent the procedure applies to.
  final TreatmentArea treatmentArea;

  /// Default fee.
  final Money defaultFee;

  /// Lower bound of the clinic's usual fee range.
  final Money feeMin;

  /// Upper bound of the clinic's usual fee range.
  final Money feeMax;

  /// GST class every invoice line of this item inherits.
  final GstClass gstClass;

  /// SAC / HSN code printed on invoices.
  final String sacHsnCode;

  /// Typical chair time in minutes.
  final int durationMinutes;

  /// Stage names for multi-sitting work (`Access`, `BMP`, `Obturation`).
  final List<String> stages;

  /// Recall triggered on completion, if any.
  final RecallInterval? recallInterval;

  /// Consent template to use, if consent is required.
  final String? consentTemplateCode;

  /// Whether a pre-operative radiograph should be attached.
  final bool requiresPreOpRadiograph;

  /// Mappings to external systems (`cdt`, `snomed`, `practo`).
  final Map<String, String> externalCodes;

  /// Inactive items are hidden from pickers.
  final bool isActive;

  /// Display order inside the category.
  final int sortOrder;

  /// Whether the procedure is done over more than one sitting.
  bool get isMultiSitting => stages.length > 1;

  /// Returns a copy with the given fields replaced.
  CatalogItem copyWith({
    String? clinicId,
    String? code,
    String? name,
    String? laymanName,
    ProcedureCategory? category,
    TreatmentArea? treatmentArea,
    Money? defaultFee,
    Money? feeMin,
    Money? feeMax,
    GstClass? gstClass,
    String? sacHsnCode,
    int? durationMinutes,
    List<String>? stages,
    RecallInterval? recallInterval,
    String? consentTemplateCode,
    bool? requiresPreOpRadiograph,
    Map<String, String>? externalCodes,
    bool? isActive,
    int? sortOrder,
  }) => CatalogItem(
    id: id,
    clinicId: clinicId ?? this.clinicId,
    code: code ?? this.code,
    name: name ?? this.name,
    laymanName: laymanName ?? this.laymanName,
    category: category ?? this.category,
    treatmentArea: treatmentArea ?? this.treatmentArea,
    defaultFee: defaultFee ?? this.defaultFee,
    feeMin: feeMin ?? this.feeMin,
    feeMax: feeMax ?? this.feeMax,
    gstClass: gstClass ?? this.gstClass,
    sacHsnCode: sacHsnCode ?? this.sacHsnCode,
    durationMinutes: durationMinutes ?? this.durationMinutes,
    stages: stages ?? this.stages,
    recallInterval: recallInterval ?? this.recallInterval,
    consentTemplateCode: consentTemplateCode ?? this.consentTemplateCode,
    requiresPreOpRadiograph:
        requiresPreOpRadiograph ?? this.requiresPreOpRadiograph,
    externalCodes: externalCodes ?? this.externalCodes,
    isActive: isActive ?? this.isActive,
    sortOrder: sortOrder ?? this.sortOrder,
  );

  /// JSON form.
  Map<String, Object?> toJson() => {
    'id': id,
    'clinicId': clinicId,
    'code': code,
    'name': name,
    'laymanName': laymanName,
    'category': category.name,
    'treatmentArea': treatmentArea.name,
    'defaultFee': defaultFee.toJson(),
    'feeMin': feeMin.toJson(),
    'feeMax': feeMax.toJson(),
    'gstClass': gstClass.name,
    'sacHsnCode': sacHsnCode,
    'durationMinutes': durationMinutes,
    'stages': stages,
    'recallInterval': recallInterval?.name,
    'consentTemplateCode': consentTemplateCode,
    'requiresPreOpRadiograph': requiresPreOpRadiograph,
    'externalCodes': externalCodes,
    'isActive': isActive,
    'sortOrder': sortOrder,
  };

  /// Parses the JSON form.
  factory CatalogItem.fromJson(Map<String, Object?> json) => CatalogItem(
    id: json['id'] as String,
    clinicId: json['clinicId'] as String?,
    code: json['code'] as String,
    name: json['name'] as String,
    laymanName: json['laymanName'] as String,
    category: enumFromJson(ProcedureCategory.values, json['category']),
    treatmentArea: enumFromJson(TreatmentArea.values, json['treatmentArea']),
    defaultFee: moneyFromJson(json['defaultFee']),
    feeMin: moneyFromJson(json['feeMin']),
    feeMax: moneyFromJson(json['feeMax']),
    gstClass: enumFromJson(GstClass.values, json['gstClass']),
    sacHsnCode: json['sacHsnCode'] as String,
    durationMinutes: json['durationMinutes'] as int? ?? 30,
    stages: stringListFromJson(json['stages']),
    recallInterval: enumFromJsonOrNull(
      RecallInterval.values,
      json['recallInterval'],
    ),
    consentTemplateCode: json['consentTemplateCode'] as String?,
    requiresPreOpRadiograph: json['requiresPreOpRadiograph'] as bool? ?? false,
    externalCodes: stringMapFromJson(json['externalCodes']),
    isActive: json['isActive'] as bool? ?? true,
    sortOrder: json['sortOrder'] as int? ?? 0,
  );
}
