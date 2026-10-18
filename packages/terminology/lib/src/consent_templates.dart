/// Procedure consent templates and DPDP data-processing notice templates.
///
/// Bodies use `{placeholder}` tokens. A template's [versionHash] binds the
/// code, version and exact body so a signed `ConsentRecord` can prove which
/// text the patient saw.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

part 'consent/additional_templates.dart';
part 'consent/ported_templates.dart';

final RegExp _placeholderPattern = RegExp(r'\{([a-z_]+)\}');

/// Shared rendering and hashing for template kinds.
abstract class RenderableTemplate {
  /// Const base constructor.
  const RenderableTemplate();

  /// Unique uppercase code, e.g. `RCT`.
  String get code;

  /// Template version, bumped whenever [body] changes.
  String get version;

  /// Template body with `{placeholder}` tokens.
  String get body;

  /// BCP-47 language code, e.g. `en`.
  String get languageCode;

  /// Replaces every `{key}` for which [values] has an entry. Unknown tokens
  /// are left in place so [unresolvedPlaceholders] can report them.
  String render(Map<String, String> values) =>
      body.replaceAllMapped(_placeholderPattern, (m) {
        final key = m.group(1)!;
        return values.containsKey(key) ? values[key]! : m.group(0)!;
      });

  /// Placeholder names present in [body] (in order of first appearance).
  List<String> get placeholdersInBody {
    final seen = <String>[];
    for (final m in _placeholderPattern.allMatches(body)) {
      final key = m.group(1)!;
      if (!seen.contains(key)) seen.add(key);
    }
    return seen;
  }

  /// Placeholders in [body] that [values] does not supply.
  List<String> unresolvedPlaceholders(Map<String, String> values) =>
      placeholdersInBody.where((p) => !values.containsKey(p)).toList();

  /// Hex SHA-256 of `code + version + body`; stable across runs.
  String get versionHash =>
      sha256.convert(utf8.encode('$code$version$body')).toString();
}

/// A procedure consent template (Samira Kohli standard: nature, purpose,
/// risks, alternatives, follow-up).
class ConsentTemplate extends RenderableTemplate {
  /// Creates a consent template.
  const ConsentTemplate({
    required this.code,
    required this.title,
    required this.languageCode,
    required this.body,
    required this.placeholders,
    required this.version,
    required this.procedureCodes,
  });

  @override
  final String code;

  /// Heading shown above the body.
  final String title;

  @override
  final String languageCode;

  @override
  final String body;

  /// Placeholders the body expects (the UI collects these).
  final List<String> placeholders;

  @override
  final String version;

  /// Catalogue procedure codes that default to this template.
  final List<String> procedureCodes;

  /// Returns a copy with the given fields replaced.
  ConsentTemplate copyWith({
    String? code,
    String? title,
    String? languageCode,
    String? body,
    List<String>? placeholders,
    String? version,
    List<String>? procedureCodes,
  }) => ConsentTemplate(
    code: code ?? this.code,
    title: title ?? this.title,
    languageCode: languageCode ?? this.languageCode,
    body: body ?? this.body,
    placeholders: placeholders ?? this.placeholders,
    version: version ?? this.version,
    procedureCodes: procedureCodes ?? this.procedureCodes,
  );

  /// JSON map.
  Map<String, Object?> toJson() => {
    'code': code,
    'title': title,
    'languageCode': languageCode,
    'body': body,
    'placeholders': placeholders,
    'version': version,
    'procedureCodes': procedureCodes,
  };

  /// Inverse of [toJson].
  factory ConsentTemplate.fromJson(Map<String, Object?> json) =>
      ConsentTemplate(
        code: json['code'] as String,
        title: json['title'] as String,
        languageCode: json['languageCode'] as String,
        body: json['body'] as String,
        placeholders: (json['placeholders'] as List? ?? const [])
            .cast<String>(),
        version: json['version'] as String,
        procedureCodes: (json['procedureCodes'] as List? ?? const [])
            .cast<String>(),
      );

  @override
  String toString() => 'ConsentTemplate($code v$version)';
}

/// A DPDP Act 2023 s.5 notice: purposes, how to withdraw, grievance route.
/// Kept separate from [ConsentTemplate] because data consent and procedure
/// consent are different objects (`DataConsent` vs `ConsentRecord`).
class DataNoticeTemplate extends RenderableTemplate {
  /// Creates a data notice template.
  const DataNoticeTemplate({
    required this.code,
    required this.title,
    required this.languageCode,
    required this.body,
    required this.placeholders,
    required this.version,
    required this.purposes,
  });

  @override
  final String code;

  /// Heading shown above the body.
  final String title;

  @override
  final String languageCode;

  @override
  final String body;

  /// Placeholders the body expects.
  final List<String> placeholders;

  @override
  final String version;

  /// Purpose keys the notice covers (each becomes a `DataConsent` row).
  final List<String> purposes;

  /// JSON map.
  Map<String, Object?> toJson() => {
    'code': code,
    'title': title,
    'languageCode': languageCode,
    'body': body,
    'placeholders': placeholders,
    'version': version,
    'purposes': purposes,
  };

  /// Inverse of [toJson].
  factory DataNoticeTemplate.fromJson(Map<String, Object?> json) =>
      DataNoticeTemplate(
        code: json['code'] as String,
        title: json['title'] as String,
        languageCode: json['languageCode'] as String,
        body: json['body'] as String,
        placeholders: (json['placeholders'] as List? ?? const [])
            .cast<String>(),
        version: json['version'] as String,
        purposes: (json['purposes'] as List? ?? const []).cast<String>(),
      );

  @override
  String toString() => 'DataNoticeTemplate($code v$version)';
}

/// Every seed consent template (ported English set plus additions).
const List<ConsentTemplate> consentTemplates = [
  ...portedConsentTemplates,
  ...additionalConsentTemplates,
];

/// Every seed data-processing notice.
const List<DataNoticeTemplate> dataNoticeTemplates = [dpdpDataProcessingNotice];

/// Looks up a consent template by code; null when unknown.
ConsentTemplate? consentTemplateByCode(String code) {
  for (final t in consentTemplates) {
    if (t.code == code) return t;
  }
  return null;
}

/// The default consent template for a catalogue procedure code, by the
/// template's [ConsentTemplate.procedureCodes] mapping; null when none.
ConsentTemplate? consentTemplateFor(String procedureCode) {
  for (final t in consentTemplates) {
    if (t.procedureCodes.contains(procedureCode)) return t;
  }
  return null;
}
