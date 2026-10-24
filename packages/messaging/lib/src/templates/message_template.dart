import 'package:ampdent_core/ampdent_core.dart';

/// Matches `{variable_name}` placeholders inside a template body.
final RegExp templatePlaceholderPattern = RegExp(r'\{([a-z0-9_]+)\}');

/// An approved outbound message template: a body with `{variable}` slots, the
/// channel and Meta category it was approved under, and the language.
///
/// Bodies never carry clinical content. Anything clinical (prescription,
/// estimate, consent text, after-care sheet) sits behind an authenticated
/// `{link}`; only the procedure name may appear in the text.
class MessageTemplate {
  /// Creates a template. [variables] must list every placeholder in [body].
  const MessageTemplate({
    required this.code,
    required this.channel,
    required this.category,
    this.languageCode = 'en',
    required this.body,
    required this.variables,
    required this.description,
  });

  /// Stable template code (`APPT_REMINDER_24H`), shared with the provider.
  final String code;

  /// Channel the template is approved for.
  final MessageChannel channel;

  /// Meta template category; drives pricing and the opt-in rule applied.
  final MessageCategory category;

  /// BCP-47 language code of the body (`en`, `hi`, `te`).
  final String languageCode;

  /// Body text with `{variable}` placeholders.
  final String body;

  /// Placeholder names the body expects, in order of first appearance.
  final List<String> variables;

  /// What the template is for and when it is sent; shown in the template list.
  final String description;

  /// Placeholder names found by scanning [body], de-duplicated, in order.
  List<String> get placeholdersInBody {
    final seen = <String>{};
    final found = <String>[];
    for (final match in templatePlaceholderPattern.allMatches(body)) {
      final name = match.group(1)!;
      if (seen.add(name)) found.add(name);
    }
    return found;
  }

  /// Whether the body points the reader to an authenticated link.
  bool get hasLink => variables.contains('link');

  /// Declared variables that [values] does not supply.
  List<String> missingVariables(Map<String, String> values) =>
      variables.where((v) => !values.containsKey(v)).toList();

  /// Fills every placeholder from [values].
  ///
  /// Throws [ArgumentError] naming every missing key when any declared
  /// variable is absent; extra keys are ignored.
  String render(Map<String, String> values) {
    final missing = missingVariables(values);
    if (missing.isNotEmpty) {
      throw ArgumentError.value(
        missing.join(', '),
        'values',
        'Template $code is missing variables',
      );
    }
    return body.replaceAllMapped(
      templatePlaceholderPattern,
      (m) => values[m.group(1)!] ?? m.group(0)!,
    );
  }

  /// Returns a copy with the given fields replaced.
  MessageTemplate copyWith({
    String? code,
    MessageChannel? channel,
    MessageCategory? category,
    String? languageCode,
    String? body,
    List<String>? variables,
    String? description,
  }) => MessageTemplate(
    code: code ?? this.code,
    channel: channel ?? this.channel,
    category: category ?? this.category,
    languageCode: languageCode ?? this.languageCode,
    body: body ?? this.body,
    variables: variables ?? this.variables,
    description: description ?? this.description,
  );

  /// JSON form.
  Map<String, Object?> toJson() => {
    'code': code,
    'channel': channel.name,
    'category': category.name,
    'languageCode': languageCode,
    'body': body,
    'variables': variables,
    'description': description,
  };

  /// Parses the JSON form.
  factory MessageTemplate.fromJson(Map<String, Object?> json) =>
      MessageTemplate(
        code: json['code'] as String,
        channel: enumFromJson(MessageChannel.values, json['channel']),
        category: enumFromJson(MessageCategory.values, json['category']),
        languageCode: json['languageCode'] as String? ?? 'en',
        body: json['body'] as String,
        variables: stringListFromJson(json['variables']),
        description: json['description'] as String? ?? '',
      );

  @override
  String toString() => 'MessageTemplate($code, $languageCode)';
}
