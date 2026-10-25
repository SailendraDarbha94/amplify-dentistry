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

/// Parses a BPE map (`{sextantName: code}`) where the code may be the enum
/// name (`code3`) or the printed label (`3`). A sextant stored with the
/// legacy `*` marker carries no numeric code and is left out; see
/// [legacyBpeFurcationFromJson] for the flag it stands for.
Map<Sextant, BpeCode> bpeMapFromJson(Object? json) {
  final map = json as Map?;
  if (map == null) return const {};
  return {
    for (final e in map.entries)
      if (!BpeCode.isFurcationMarker(e.value))
        enumFromJson(Sextant.values, e.key): BpeCode.parse(e.value),
  };
}

/// Sextants a legacy BPE map (`{sextantName: '*'}`) flagged for furcation
/// before `PerioExam.bpeFurcation` existed.
Set<Sextant> legacyBpeFurcationFromJson(Object? json) {
  final map = json as Map?;
  if (map == null) return const {};
  return {
    for (final e in map.entries)
      if (BpeCode.isFurcationMarker(e.value))
        enumFromJson(Sextant.values, e.key),
  };
}

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
/// furcation, BPE screening per sextant (numeric code plus a furcation `*`
/// flag) and the clinician's stage/grade.
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
    this.bpeFurcation = const {},
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

  /// BPE code per sextant (numeric 0-4).
  final Map<Sextant, BpeCode> bpe;

  /// Sextants with furcation involvement (`*` on the BPE form), recorded
  /// alongside the numeric code in [bpe].
  final Set<Sextant> bpeFurcation;

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
    Set<Sextant>? bpeFurcation,
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
    bpeFurcation: bpeFurcation ?? this.bpeFurcation,
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
    'bpeFurcation': enumListToJson(bpeFurcation),
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
    bpe: bpeMapFromJson(json['bpe']),
    bpeFurcation: {
      ...enumListFromJson(Sextant.values, json['bpeFurcation']),
      ...legacyBpeFurcationFromJson(json['bpe']),
    },
    stage: enumFromJsonOrNull(PeriodontitisStage.values, json['stage']),
    grade: enumFromJsonOrNull(PeriodontitisGrade.values, json['grade']),
    note: json['note'] as String?,
    createdAt: dateFromJson(json['createdAt']),
  );
}
