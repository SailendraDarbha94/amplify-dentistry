/// WHO ICD-10 (2019) Chapter XI block K00-K14, "Diseases of oral cavity,
/// salivary glands and jaws", at category level plus the commonly used
/// 4-character subcodes. Descriptions follow the WHO 2019 browser.
library;

part 'icd10/icd10_k00_k07.dart';
part 'icd10/icd10_k08_k14.dart';

/// One ICD-10 code with its WHO description.
class Icd10Code {
  /// Creates a code; [parentCode] is the 3-character category for subcodes.
  const Icd10Code(this.code, this.description, {this.parentCode});

  /// Code such as `K02` or `K02.1`.
  final String code;

  /// WHO description.
  final String description;

  /// Three-character category this subcode belongs to; null for categories.
  final String? parentCode;

  /// True for 3-character category codes.
  bool get isCategory => parentCode == null;

  /// `K02.1` -> `K02`; categories return themselves.
  String get categoryCode => parentCode ?? code;

  /// JSON map.
  Map<String, Object?> toJson() => {
    'code': code,
    'description': description,
    'parentCode': parentCode,
  };

  /// Inverse of [toJson].
  factory Icd10Code.fromJson(Map<String, Object?> json) => Icd10Code(
    json['code'] as String,
    json['description'] as String,
    parentCode: json['parentCode'] as String?,
  );

  @override
  bool operator ==(Object other) => other is Icd10Code && other.code == code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => '$code $description';
}

/// All K00-K14 codes, categories first within each block.
const List<Icd10Code> icd10OralCodes = [...icd10K00ToK07, ...icd10K08ToK14];

/// Looks up a code exactly (case-insensitive); null when unknown.
Icd10Code? icd10ByCode(String code) {
  final upper = code.trim().toUpperCase();
  for (final c in icd10OralCodes) {
    if (c.code == upper) return c;
  }
  return null;
}

/// Subcodes of a 3-character category, in code order.
List<Icd10Code> icd10Children(String categoryCode) {
  final upper = categoryCode.trim().toUpperCase();
  return icd10OralCodes.where((c) => c.parentCode == upper).toList();
}

/// Case-insensitive search by code prefix or any description word. Codes
/// whose code starts with the query rank first, then description matches.
List<Icd10Code> searchIcd10(String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];
  final byCode = <Icd10Code>[];
  final byText = <Icd10Code>[];
  for (final c in icd10OralCodes) {
    if (c.code.toLowerCase().startsWith(q)) {
      byCode.add(c);
    } else if (c.description.toLowerCase().contains(q)) {
      byText.add(c);
    }
  }
  return [...byCode, ...byText];
}
