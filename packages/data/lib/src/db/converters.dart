/// Drift type converters between SQLite storage types and `ampdent_core`
/// value types.
///
/// Storage conventions (mirrored by the Supabase schema):
/// * `Money` is INTEGER paise.
/// * `ToothId` is TEXT `storageKey` (FDI, `11`, `55+1`); lists of teeth are a
///   JSON array of storage keys.
/// * `SurfaceSet` is TEXT canonical code (`MOD`).
/// * Enums are TEXT `.name` (via drift's `textEnum`).
/// * Dates are TEXT ISO-8601 in UTC with fixed millisecond precision
///   (`2026-10-18T09:30:00.000Z`), so lexicographic order equals
///   chronological order and range queries can compare strings directly.
///   Every `DateTime` read back is UTC. See [IsoUtcDateTimeConverter].
/// * Structured lists and maps are JSON TEXT using the entity's own
///   `toJson`/`fromJson`.
library;

import 'dart:convert';

import 'package:ampdent_core/ampdent_core.dart';
import 'package:drift/drift.dart';

/// Encodes a date for storage: UTC, millisecond precision, ISO-8601.
String encodeIsoUtc(DateTime value) => DateTime.fromMillisecondsSinceEpoch(
  value.toUtc().millisecondsSinceEpoch,
  isUtc: true,
).toIso8601String();

/// Decodes a stored ISO-8601 date as UTC.
DateTime decodeIsoUtc(String value) => DateTime.parse(value).toUtc();

/// Stores `DateTime` as fixed-format ISO-8601 UTC text.
class IsoUtcDateTimeConverter extends TypeConverter<DateTime, String>
    with JsonTypeConverter<DateTime, String> {
  /// Const constructor.
  const IsoUtcDateTimeConverter();

  @override
  DateTime fromSql(String fromDb) => decodeIsoUtc(fromDb);

  @override
  String toSql(DateTime value) => encodeIsoUtc(value);
}

/// Stores [Money] as integer paise.
class MoneyConverter extends TypeConverter<Money, int>
    with JsonTypeConverter2<Money, int, Object?> {
  /// Const constructor.
  const MoneyConverter();

  @override
  Money fromSql(int fromDb) => Money.paise(fromDb);

  @override
  int toSql(Money value) => value.paise;

  @override
  Money fromJson(Object? json) => Money.fromJson(json);

  @override
  Object? toJson(Money value) => value.toJson();
}

/// Stores `num` in a REAL column while keeping the Dart type `num`, so
/// entity fields typed `num` map without casts.
class NumConverter extends TypeConverter<num, double>
    with JsonTypeConverter<num, double> {
  /// Const constructor.
  const NumConverter();

  @override
  num fromSql(double fromDb) => fromDb;

  @override
  double toSql(num value) => value.toDouble();
}

/// Stores a [ToothId] as its FDI storage key.
class ToothIdConverter extends TypeConverter<ToothId, String>
    with JsonTypeConverter<ToothId, String> {
  /// Const constructor.
  const ToothIdConverter();

  @override
  ToothId fromSql(String fromDb) => ToothId.parse(fromDb);

  @override
  String toSql(ToothId value) => value.storageKey;
}

/// Stores a list of teeth as a JSON array of FDI storage keys.
class ToothListConverter extends TypeConverter<List<ToothId>, String>
    with JsonTypeConverter2<List<ToothId>, String, Object?> {
  /// Const constructor.
  const ToothListConverter();

  @override
  List<ToothId> fromSql(String fromDb) => teethFromJson(jsonDecode(fromDb));

  @override
  String toSql(List<ToothId> value) => jsonEncode(teethToJson(value));

  @override
  List<ToothId> fromJson(Object? json) => teethFromJson(json);

  @override
  Object? toJson(List<ToothId> value) => teethToJson(value);
}

/// Stores a [SurfaceSet] as its canonical code (`MOD`); empty string for an
/// empty set.
class SurfaceSetConverter extends TypeConverter<SurfaceSet, String>
    with JsonTypeConverter<SurfaceSet, String> {
  /// Const constructor.
  const SurfaceSetConverter();

  @override
  SurfaceSet fromSql(String fromDb) => surfacesFromJson(fromDb);

  @override
  String toSql(SurfaceSet value) => value.code;
}

/// Stores `List<String>` as a JSON array.
class StringListConverter extends TypeConverter<List<String>, String>
    with JsonTypeConverter2<List<String>, String, Object?> {
  /// Const constructor.
  const StringListConverter();

  @override
  List<String> fromSql(String fromDb) => stringListFromJson(jsonDecode(fromDb));

  @override
  String toSql(List<String> value) => jsonEncode(value);

  @override
  List<String> fromJson(Object? json) => stringListFromJson(json);

  @override
  Object? toJson(List<String> value) => value;
}

/// Stores `Map<String, String>` as a JSON object.
class StringMapConverter extends TypeConverter<Map<String, String>, String>
    with JsonTypeConverter2<Map<String, String>, String, Object?> {
  /// Const constructor.
  const StringMapConverter();

  @override
  Map<String, String> fromSql(String fromDb) =>
      stringMapFromJson(jsonDecode(fromDb));

  @override
  String toSql(Map<String, String> value) => jsonEncode(value);

  @override
  Map<String, String> fromJson(Object? json) => stringMapFromJson(json);

  @override
  Object? toJson(Map<String, String> value) => value;
}

/// Stores `Map<String, int>` as a JSON object.
class IntMapConverter extends TypeConverter<Map<String, int>, String>
    with JsonTypeConverter2<Map<String, int>, String, Object?> {
  /// Const constructor.
  const IntMapConverter();

  @override
  Map<String, int> fromSql(String fromDb) => intMapFromJson(jsonDecode(fromDb));

  @override
  String toSql(Map<String, int> value) => jsonEncode(value);

  @override
  Map<String, int> fromJson(Object? json) => intMapFromJson(json);

  @override
  Object? toJson(Map<String, int> value) => value;
}

/// Stores a loosely typed JSON object (audit before/after snapshots).
class JsonObjectConverter extends TypeConverter<Map<String, Object?>, String>
    with JsonTypeConverter2<Map<String, Object?>, String, Object?> {
  /// Const constructor.
  const JsonObjectConverter();

  @override
  Map<String, Object?> fromSql(String fromDb) =>
      objectMapFromJson(jsonDecode(fromDb)) ?? const {};

  @override
  String toSql(Map<String, Object?> value) => jsonEncode(value);

  @override
  Map<String, Object?> fromJson(Object? json) =>
      objectMapFromJson(json) ?? const {};

  @override
  Object? toJson(Map<String, Object?> value) => value;
}

/// Stores the patient demographics frozen on a prescription as JSON.
class PatientSnapshotConverter extends TypeConverter<PatientSnapshot, String>
    with JsonTypeConverter2<PatientSnapshot, String, Object?> {
  /// Const constructor.
  const PatientSnapshotConverter();

  @override
  PatientSnapshot fromSql(String fromDb) => fromJson(jsonDecode(fromDb));

  @override
  String toSql(PatientSnapshot value) => jsonEncode(toJson(value));

  @override
  PatientSnapshot fromJson(Object? json) =>
      PatientSnapshot.fromJson((json as Map).cast<String, Object?>());

  @override
  Object? toJson(PatientSnapshot value) => value.toJson();
}

/// Base for converters that store a list of value objects as a JSON array
/// using the object's own `toJson`/`fromJson`.
abstract class JsonListConverter<T> extends TypeConverter<List<T>, String>
    with JsonTypeConverter2<List<T>, String, Object?> {
  /// Const constructor.
  const JsonListConverter();

  /// Parses one element.
  T decode(Map<String, Object?> json);

  /// Serialises one element.
  Map<String, Object?> encode(T value);

  @override
  List<T> fromSql(String fromDb) => fromJson(jsonDecode(fromDb));

  @override
  String toSql(List<T> value) => jsonEncode(toJson(value));

  @override
  List<T> fromJson(Object? json) =>
      (json as List?)
          ?.map((e) => decode((e as Map).cast<String, Object?>()))
          .toList() ??
      const [];

  @override
  Object? toJson(List<T> value) => value.map(encode).toList();
}

/// JSON list of [EstimateLine].
class EstimateLinesConverter extends JsonListConverter<EstimateLine> {
  /// Const constructor.
  const EstimateLinesConverter();

  @override
  EstimateLine decode(Map<String, Object?> json) => EstimateLine.fromJson(json);

  @override
  Map<String, Object?> encode(EstimateLine value) => value.toJson();
}

/// JSON list of [InvoiceLine].
class InvoiceLinesConverter extends JsonListConverter<InvoiceLine> {
  /// Const constructor.
  const InvoiceLinesConverter();

  @override
  InvoiceLine decode(Map<String, Object?> json) => InvoiceLine.fromJson(json);

  @override
  Map<String, Object?> encode(InvoiceLine value) => value.toJson();
}

/// JSON list of [PrescriptionLine].
class PrescriptionLinesConverter extends JsonListConverter<PrescriptionLine> {
  /// Const constructor.
  const PrescriptionLinesConverter();

  @override
  PrescriptionLine decode(Map<String, Object?> json) =>
      PrescriptionLine.fromJson(json);

  @override
  Map<String, Object?> encode(PrescriptionLine value) => value.toJson();
}

/// JSON list of [PlanPhase].
class PlanPhasesConverter extends JsonListConverter<PlanPhase> {
  /// Const constructor.
  const PlanPhasesConverter();

  @override
  PlanPhase decode(Map<String, Object?> json) => PlanPhase.fromJson(json);

  @override
  Map<String, Object?> encode(PlanPhase value) => value.toJson();
}

/// JSON list of [AllergyEntry].
class AllergiesConverter extends JsonListConverter<AllergyEntry> {
  /// Const constructor.
  const AllergiesConverter();

  @override
  AllergyEntry decode(Map<String, Object?> json) => AllergyEntry.fromJson(json);

  @override
  Map<String, Object?> encode(AllergyEntry value) => value.toJson();
}

/// JSON list of [PerioSiteReading].
class PerioSitesConverter extends JsonListConverter<PerioSiteReading> {
  /// Const constructor.
  const PerioSitesConverter();

  @override
  PerioSiteReading decode(Map<String, Object?> json) =>
      perioSiteReadingFromJson(json);

  @override
  Map<String, Object?> encode(PerioSiteReading value) => value.toJson();
}

/// JSON list of [PerioToothReading].
class PerioTeethConverter extends JsonListConverter<PerioToothReading> {
  /// Const constructor.
  const PerioTeethConverter();

  @override
  PerioToothReading decode(Map<String, Object?> json) =>
      perioToothReadingFromJson(json);

  @override
  Map<String, Object?> encode(PerioToothReading value) => value.toJson();
}

/// Stores BPE codes per sextant as a JSON object of enum names.
class BpeMapConverter extends TypeConverter<Map<Sextant, BpeCode>, String>
    with JsonTypeConverter2<Map<Sextant, BpeCode>, String, Object?> {
  /// Const constructor.
  const BpeMapConverter();

  @override
  Map<Sextant, BpeCode> fromSql(String fromDb) => fromJson(jsonDecode(fromDb));

  @override
  String toSql(Map<Sextant, BpeCode> value) => jsonEncode(toJson(value));

  @override
  Map<Sextant, BpeCode> fromJson(Object? json) => bpeMapFromJson(json);

  @override
  Object? toJson(Map<Sextant, BpeCode> value) => {
    for (final e in value.entries) e.key.name: e.value.name,
  };
}

/// Stores a set of sextants (BPE furcation flags) as a JSON array of names.
class SextantSetConverter extends TypeConverter<Set<Sextant>, String>
    with JsonTypeConverter2<Set<Sextant>, String, Object?> {
  /// Const constructor.
  const SextantSetConverter();

  @override
  Set<Sextant> fromSql(String fromDb) => fromJson(jsonDecode(fromDb));

  @override
  String toSql(Set<Sextant> value) => jsonEncode(toJson(value));

  @override
  Set<Sextant> fromJson(Object? json) =>
      enumListFromJson(Sextant.values, json).toSet();

  @override
  Object? toJson(Set<Sextant> value) => enumListToJson(value);
}
