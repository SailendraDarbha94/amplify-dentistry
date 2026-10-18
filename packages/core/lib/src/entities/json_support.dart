/// Shared JSON conventions for every entity: ISO-8601 dates, enum `.name`,
/// [ToothId] via `storageKey`, [SurfaceSet] via `code`, [Money] via its own
/// `toJson`/`fromJson`. Kept in one place so Drift, Supabase and export code
/// agree on the wire format.
library;

import '../dental/surfaces.dart';
import '../dental/tooth_id.dart';
import '../money/money.dart';

/// Serialises a date as ISO-8601 (null passes through).
String? dateToJson(DateTime? value) => value?.toIso8601String();

/// Parses a required ISO-8601 date.
DateTime dateFromJson(Object? value) => DateTime.parse(value as String);

/// Parses an optional ISO-8601 date.
DateTime? dateFromJsonOrNull(Object? value) =>
    value == null ? null : DateTime.parse(value as String);

/// Looks an enum constant up by `.name`; throws [FormatException] on unknown.
T enumFromJson<T extends Enum>(List<T> values, Object? name) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  throw FormatException('Unknown ${values.first.runtimeType} name', name);
}

/// Looks an enum constant up by `.name`, null when the input is null.
T? enumFromJsonOrNull<T extends Enum>(List<T> values, Object? name) =>
    name == null ? null : enumFromJson(values, name);

/// Serialises a list of enums to their names.
List<String> enumListToJson(Iterable<Enum> values) =>
    values.map((e) => e.name).toList();

/// Parses a list of enum names (null input yields an empty list).
List<T> enumListFromJson<T extends Enum>(List<T> values, Object? json) =>
    (json as List?)?.map((e) => enumFromJson(values, e)).toList() ?? const [];

/// Serialises a tooth as its FDI storage key (null passes through).
String? toothToJson(ToothId? tooth) => tooth?.storageKey;

/// Parses a required FDI storage key.
ToothId toothFromJson(Object? value) => ToothId.parse(value as String);

/// Parses an optional FDI storage key.
ToothId? toothFromJsonOrNull(Object? value) =>
    value == null ? null : ToothId.parse(value as String);

/// Serialises a list of teeth as FDI storage keys.
List<String> teethToJson(Iterable<ToothId> teeth) =>
    teeth.map((t) => t.storageKey).toList();

/// Parses a list of FDI storage keys (null yields an empty list).
List<ToothId> teethFromJson(Object? json) =>
    (json as List?)?.map((e) => ToothId.parse(e as String)).toList() ??
    const [];

/// Serialises a surface set as its canonical code.
String surfacesToJson(SurfaceSet surfaces) => surfaces.code;

/// Parses a surface code; null or empty yields [SurfaceSet.empty].
SurfaceSet surfacesFromJson(Object? value) {
  final code = value as String?;
  if (code == null || code.isEmpty) return const SurfaceSet.empty();
  return SurfaceSet.parse(code);
}

/// Parses a required [Money] value.
Money moneyFromJson(Object? value) => Money.fromJson(value);

/// Parses an optional [Money] value.
Money? moneyFromJsonOrNull(Object? value) =>
    value == null ? null : Money.fromJson(value);

/// Parses a list of strings (null yields an empty list).
List<String> stringListFromJson(Object? json) =>
    (json as List?)?.cast<String>().toList() ?? const [];

/// Parses a string-to-string map (null yields an empty map).
Map<String, String> stringMapFromJson(Object? json) =>
    (json as Map?)?.map((k, v) => MapEntry(k as String, v as String)) ??
    const {};

/// Parses a string-to-int map (null yields an empty map).
Map<String, int> intMapFromJson(Object? json) =>
    (json as Map?)?.map((k, v) => MapEntry(k as String, v as int)) ?? const {};

/// Parses a loosely typed JSON object (null passes through).
Map<String, Object?>? objectMapFromJson(Object? json) =>
    (json as Map?)?.map((k, v) => MapEntry(k as String, v));
