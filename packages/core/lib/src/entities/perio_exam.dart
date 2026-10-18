import 'package:meta/meta.dart';

import '../dental/clinical_enums.dart';
import '../dental/perio.dart';
import '../dental/surfaces.dart';
import 'json_support.dart';

/// JSON support for [PerioSiteReading] (defined in `dental/perio.dart`).
extension PerioSiteReadingJson on PerioSiteReading {
  /// JSON form.
  Map<String, Object?> toJson() => {
    'tooth': tooth.storageKey,
    'site': site.name,
    'probingDepth': probingDepth,
    'gingivalMargin': gingivalMargin,
    'bleeding': bleeding,
    'suppuration': suppuration,
    'plaque': plaque,
    'calculus': calculus,
    'mucogingivalJunction': mucogingivalJunction,
  };
}

/// Parses a [PerioSiteReading] from its JSON form.
PerioSiteReading perioSiteReadingFromJson(Map<String, Object?> json) =>
    PerioSiteReading(
      tooth: toothFromJson(json['tooth']),
      site: enumFromJson(PerioSite.values, json['site']),
      probingDepth: json['probingDepth'] as int?,
      gingivalMargin: json['gingivalMargin'] as int?,
      bleeding: json['bleeding'] as bool? ?? false,
      suppuration: json['suppuration'] as bool? ?? false,
      plaque: json['plaque'] as bool? ?? false,
      calculus: json['calculus'] as bool? ?? false,
      mucogingivalJunction: json['mucogingivalJunction'] as int?,
    );

/// JSON support for [PerioToothReading] (defined in `dental/perio.dart`).
extension PerioToothReadingJson on PerioToothReading {
  /// JSON form.
  Map<String, Object?> toJson() => {
    'tooth': tooth.storageKey,
    'mobility': mobility?.name,
    'furcation': furcation?.name,
    'skipped': skipped,
    'isImplant': isImplant,
  };
}

/// Parses a [PerioToothReading] from its JSON form.
PerioToothReading perioToothReadingFromJson(Map<String, Object?> json) =>
    PerioToothReading(
      tooth: toothFromJson(json['tooth']),
      mobility: enumFromJsonOrNull(MobilityGrade.values, json['mobility']),
      furcation: enumFromJsonOrNull(FurcationGrade.values, json['furcation']),
      skipped: json['skipped'] as bool? ?? false,
      isImplant: json['isImplant'] as bool? ?? false,
    );

/// A periodontal examination: six-point site readings, per-tooth mobility and
/// furcation, BPE screening per sextant and the clinician's stage/grade.
@immutable
class PerioExam {
  /// Creates a perio exam.
  const PerioExam({
    required this.id,
    required this.clinicId,
    required this.patientId,
    this.visitId,
    required this.examinedAt,
    required this.examinerId,
    this.sites = const [],
    this.teeth = const [],
    this.bpe = const {},
    this.stage,
    this.grade,
    this.note,
    required this.createdAt,
  });

  /// UUID v4.
  final String id;

  /// Owning clinic.
  final String clinicId;

  /// Patient.
  final String patientId;

  /// Visit, if any.
  final String? visitId;

  /// Examination time.
  final DateTime examinedAt;

  /// Examining clinician.
  final String examinerId;

  /// Site readings.
  final List<PerioSiteReading> sites;

  /// Per-tooth readings.
  final List<PerioToothReading> teeth;

  /// BPE code per sextant.
  final Map<Sextant, BpeCode> bpe;

  /// 2017 AAP/EFP stage (clinician-entered).
  final PeriodontitisStage? stage;

  /// 2017 AAP/EFP grade (clinician-entered).
  final PeriodontitisGrade? grade;

  /// Note.
  final String? note;

  /// Row creation time.
  final DateTime createdAt;

  /// Derived whole-mouth summary.
  PerioSummary get summary => PerioSummary.from(sites);

  /// Returns a copy with the given fields replaced.
  PerioExam copyWith({
    String? visitId,
    List<PerioSiteReading>? sites,
    List<PerioToothReading>? teeth,
    Map<Sextant, BpeCode>? bpe,
    PeriodontitisStage? stage,
    PeriodontitisGrade? grade,
    String? note,
  }) => PerioExam(
    id: id,
    clinicId: clinicId,
    patientId: patientId,
    visitId: visitId ?? this.visitId,
    examinedAt: examinedAt,
    examinerId: examinerId,
    sites: sites ?? this.sites,
    teeth: teeth ?? this.teeth,
    bpe: bpe ?? this.bpe,
    stage: stage ?? this.stage,
    grade: grade ?? this.grade,
    note: note ?? this.note,
    createdAt: createdAt,
  );

  /// JSON form.
  Map<String, Object?> toJson() => {
    'id': id,
    'clinicId': clinicId,
    'patientId': patientId,
    'visitId': visitId,
    'examinedAt': dateToJson(examinedAt),
    'examinerId': examinerId,
    'sites': sites.map((s) => s.toJson()).toList(),
    'teeth': teeth.map((t) => t.toJson()).toList(),
    'bpe': {for (final e in bpe.entries) e.key.name: e.value.name},
    'stage': stage?.name,
    'grade': grade?.name,
    'note': note,
    'createdAt': dateToJson(createdAt),
  };

  /// Parses the JSON form.
  factory PerioExam.fromJson(Map<String, Object?> json) => PerioExam(
    id: json['id'] as String,
    clinicId: json['clinicId'] as String,
    patientId: json['patientId'] as String,
    visitId: json['visitId'] as String?,
    examinedAt: dateFromJson(json['examinedAt']),
    examinerId: json['examinerId'] as String,
    sites:
        (json['sites'] as List?)
            ?.map(
              (e) =>
                  perioSiteReadingFromJson((e as Map).cast<String, Object?>()),
            )
            .toList() ??
        const [],
    teeth:
        (json['teeth'] as List?)
            ?.map(
              (e) =>
                  perioToothReadingFromJson((e as Map).cast<String, Object?>()),
            )
            .toList() ??
        const [],
    bpe:
        (json['bpe'] as Map?)?.map(
          (k, v) => MapEntry(
            enumFromJson(Sextant.values, k),
            enumFromJson(BpeCode.values, v),
          ),
        ) ??
        const {},
    stage: enumFromJsonOrNull(PeriodontitisStage.values, json['stage']),
    grade: enumFromJsonOrNull(PeriodontitisGrade.values, json['grade']),
    note: json['note'] as String?,
    createdAt: dateFromJson(json['createdAt']),
  );
}
