/// Keys and JSON codecs for the per-clinic `settings` table.
library;

import 'dart:convert';

import 'package:ampdent_core/ampdent_core.dart';

/// Well-known setting keys.
abstract final class SettingKeys {
  /// JSON array of GST rate rows (see [gstRatesToJson]).
  static const String gstRates = 'gst.rates';

  /// Tooth notation shown in the UI (`ToothNotation.name`).
  static const String notation = 'display.notation';

  /// Counter behind `P-00001` patient numbers.
  static const String patientNumberCounter = 'counter.patientNumber';

  /// Counter behind local `DRAFT-INV-...` invoice numbers.
  static const String draftInvoiceCounter = 'counter.draftInvoice';

  /// Counter behind local `DRAFT-EST-...` estimate numbers.
  static const String draftEstimateCounter = 'counter.draftEstimate';

  /// Counter behind `SC-00001` sterilisation cycle numbers.
  static const String sterilisationCycleCounter = 'counter.sterilisationCycle';
}

/// JSON form of one [GstRate].
Map<String, Object?> gstRateToJson(GstRate rate) => {
  'gstClass': rate.gstClass.name,
  'ratePercent': rate.ratePercent,
  'inputTaxCreditAllowed': rate.inputTaxCreditAllowed,
  'effectiveFrom': dateToJson(rate.effectiveFrom),
};

/// Parses one [GstRate].
GstRate gstRateFromJson(Map<String, Object?> json) => GstRate(
  gstClass: enumFromJson(GstClass.values, json['gstClass']),
  ratePercent: json['ratePercent'] as num,
  inputTaxCreditAllowed: json['inputTaxCreditAllowed'] as bool,
  effectiveFrom: dateFromJson(json['effectiveFrom']),
);

/// Encodes a rate history as JSON text.
String gstRatesToJson(Iterable<GstRate> rates) =>
    jsonEncode(rates.map(gstRateToJson).toList());

/// Decodes a rate history from JSON text.
List<GstRate> gstRatesFromJson(String json) => (jsonDecode(json) as List)
    .map((e) => gstRateFromJson((e as Map).cast<String, Object?>()))
    .toList();

/// Encodes a counter value.
String counterToJson(int value) => jsonEncode({'value': value});

/// Decodes a counter value (null or malformed input yields 0).
int counterFromJson(String? json) {
  if (json == null) return 0;
  final decoded = jsonDecode(json);
  if (decoded is Map && decoded['value'] is int) return decoded['value'] as int;
  return 0;
}

/// Encodes an enum setting.
String enumSettingToJson(Enum value) => jsonEncode(value.name);

/// Decodes an enum setting, falling back to [fallback].
T enumSettingFromJson<T extends Enum>(
  List<T> values,
  String? json,
  T fallback,
) {
  if (json == null) return fallback;
  return enumFromJsonOrNull(values, jsonDecode(json)) ?? fallback;
}
