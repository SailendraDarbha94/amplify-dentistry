import 'package:ampdent_core/ampdent_core.dart';

import '../phone/phone_numbers.dart';
import '../providers/message_log_keys.dart';
import '../templates/message_template.dart';
import '../templates/message_templates.dart';

// Pure builders for Meta's WhatsApp Cloud API (`POST /<phone_number_id>/
// messages`). No network code: the Edge Function in supabase/functions sends
// the payload produced here from the exported templates.json, and this Dart
// side exists so the app, the sync worker and the tests agree on the shape.

/// Meta template name for a catalogue [code]: `APPT_REMINDER_24H` becomes
/// `appt_reminder_24h`. Meta allows lowercase letters, digits and `_` only.
String metaTemplateName(String code) {
  final broken = code.replaceAllMapped(
    RegExp(r'([a-z])([A-Z])'),
    (m) => '${m[1]}_${m[2]}',
  );
  return broken
      .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
      .toLowerCase()
      .replaceAll(RegExp(r'^_+|_+$'), '');
}

/// Meta template category string for [category].
///
/// Throws [ArgumentError] for [MessageCategory.service]: service messages are
/// free-form replies inside the customer window, never templates.
String metaCategory(MessageCategory category) => switch (category) {
  MessageCategory.utility => 'UTILITY',
  MessageCategory.authentication => 'AUTHENTICATION',
  MessageCategory.marketing => 'MARKETING',
  MessageCategory.service => throw ArgumentError.value(
    category,
    'category',
    'Service messages are free-form replies, not templates',
  ),
};

/// Matches `Reply 1 to confirm` style instructions in a template body.
final RegExp _replyInstruction = RegExp(r'\bReply ([A-Za-z0-9]+) to\b');

/// Quick-reply buttons a template needs so that the instruction in its body
/// (`Reply 1 to confirm`) is a one-tap action in WhatsApp.
List<Map<String, String>> metaQuickReplyButtons(MessageTemplate template) => [
  for (final m in _replyInstruction.allMatches(template.body))
    {'type': 'QUICK_REPLY', 'text': m[1]!},
];

/// [phone] as Meta's `to` field: E.164 digits with the `+` stripped.
///
/// Accepts the number with or without its leading `+`; throws
/// [FormatException] when it is not E.164.
String metaRecipient(String phone) {
  final trimmed = phone.trim();
  final withPlus = trimmed.startsWith('+') ? trimmed : '+$trimmed';
  if (!PhoneNumbers.isE164(withPlus)) {
    throw FormatException('Recipient must be an E.164 number', phone);
  }
  return withPlus.substring(1);
}

/// A template parameter value Meta will accept: no newlines or tabs, no run
/// of four or more spaces, not empty (each of those is a 132012/132018
/// rejection). Throws [ArgumentError] when nothing is left after cleaning.
String metaParameterText(String value) {
  final cleaned = value
      .replaceAll(RegExp(r'[\r\n\t]+'), ' ')
      .replaceAll(RegExp(r' {4,}'), ' ')
      .trim();
  if (cleaned.isEmpty) {
    throw ArgumentError.value(
      value,
      'value',
      'Meta rejects empty template parameters',
    );
  }
  return cleaned;
}

/// The exact Cloud API send payload for [template] filled from [variables]
/// and addressed to [e164Phone]:
///
/// ```json
/// { "messaging_product": "whatsapp", "to": "919876543210",
///   "type": "template",
///   "template": { "name": "appt_reminder_24h", "language": { "code": "en" },
///     "components": [ { "type": "body",
///       "parameters": [ { "type": "text", "text": "..." }, ... ] } ] } }
/// ```
///
/// Parameters follow `template.variables` order (the export's `bodyParams`).
/// Reserved `_` keys in [variables] are ignored. Throws [ArgumentError] when
/// a declared variable is missing and [FormatException] for a bad phone.
Map<String, Object?> buildMetaTemplatePayload({
  required MessageTemplate template,
  required Map<String, String> variables,
  required String e164Phone,
}) {
  final values = MessageLogKeys.templateOnly(variables);
  final missing = template.missingVariables(values);
  if (missing.isNotEmpty) {
    throw ArgumentError.value(
      missing.join(', '),
      'variables',
      'Template ${template.code} is missing variables',
    );
  }
  return {
    'messaging_product': 'whatsapp',
    'to': metaRecipient(e164Phone),
    'type': 'template',
    'template': {
      'name': metaTemplateName(template.code),
      'language': {'code': template.languageCode},
      'components': [
        {
          'type': 'body',
          'parameters': [
            for (final name in template.variables)
              {'type': 'text', 'text': metaParameterText(values[name]!)},
          ],
        },
      ],
    },
  };
}

/// Send payload for a queued [log], looking its template up by code (English
/// catalogue) unless [template] is given. Throws [StateError] when the code is
/// unknown, so a worker never sends a template Meta has not approved.
Map<String, Object?> metaPayloadForLog(
  MessageLog log, {
  MessageTemplate? template,
}) {
  final resolved = template ?? templateByCode(log.templateCode);
  if (resolved == null) {
    throw StateError('No template for code ${log.templateCode}');
  }
  return buildMetaTemplatePayload(
    template: resolved,
    variables: log.variables,
    e164Phone: log.toPhone,
  );
}

/// Successful `POST /messages` response: the provider message id to store on
/// the log row and the WhatsApp id Meta resolved the number to.
class MetaSendResult {
  /// Creates a result.
  const MetaSendResult({
    required this.messageId,
    this.waId,
    this.messageStatus,
  });

  /// `messages[0].id` (`wamid.HBg...`); becomes `MessageLog.providerMessageId`.
  final String messageId;

  /// `contacts[0].wa_id`, digits only.
  final String? waId;

  /// `messages[0].message_status` (`accepted` or `held_for_quality_assessment`).
  final String? messageStatus;

  /// Whether Meta is holding the message pending quality review.
  bool get heldForQuality => messageStatus == 'held_for_quality_assessment';

  /// Parses the success body; throws [FormatException] if no id is present.
  factory MetaSendResult.fromJson(Map<String, Object?> json) {
    final messages = json['messages'] as List?;
    final first = messages == null || messages.isEmpty
        ? null
        : messages.first as Map?;
    final id = first?['id'] as String?;
    if (id == null) {
      throw const FormatException('Meta send response carries no message id');
    }
    final contacts = json['contacts'] as List?;
    final contact = contacts == null || contacts.isEmpty
        ? null
        : contacts.first as Map?;
    return MetaSendResult(
      messageId: id,
      waId: contact?['wa_id'] as String?,
      messageStatus: first?['message_status'] as String?,
    );
  }
}

/// Graph API error body (`{ "error": { code, message, ... } }`) as an
/// exception the sync worker can classify.
class MetaApiError implements Exception {
  /// Creates an error.
  const MetaApiError({
    required this.code,
    required this.message,
    this.subcode,
    this.type,
    this.details,
    this.fbTraceId,
  });

  /// Graph error code (`131026`).
  final int code;

  /// Human-readable summary.
  final String message;

  /// `error_subcode`, when present.
  final int? subcode;

  /// `type` (`OAuthException`).
  final String? type;

  /// `error_data.details`, Meta's longer explanation.
  final String? details;

  /// `fbtrace_id`, quote it when raising a ticket with Meta.
  final String? fbTraceId;

  /// Codes worth retrying with backoff: throttling and transient faults.
  static const Set<int> retryableCodes = {
    1, // unknown API error
    2, // service temporarily unavailable
    4, // API too many calls
    80007, // rate limit
    130429, // rate limit hit
    131000, // something went wrong
    131016, // service overloaded
    131048, // spam rate limit
    131056, // pair rate limit
    133004, // server temporarily unavailable
  };

  /// Whether the worker should retry later instead of failing the row.
  bool get isRetryable => retryableCodes.contains(code);

  /// Parses the error body; returns null when [json] is not an error body.
  static MetaApiError? tryParse(Map<String, Object?> json) {
    final error = json['error'] as Map?;
    if (error == null) return null;
    final data = error['error_data'] as Map?;
    return MetaApiError(
      code: (error['code'] as num?)?.toInt() ?? 0,
      message: error['message'] as String? ?? 'Unknown Meta error',
      subcode: (error['error_subcode'] as num?)?.toInt(),
      type: error['type'] as String?,
      details: data?['details'] as String?,
      fbTraceId: error['fbtrace_id'] as String?,
    );
  }

  @override
  String toString() =>
      'MetaApiError($code${subcode == null ? '' : '/$subcode'}: $message)';
}

/// Interprets a `POST /messages` response body: returns the result or throws
/// the [MetaApiError] it carries.
MetaSendResult parseMetaSendResponse(Map<String, Object?> json) {
  final error = MetaApiError.tryParse(json);
  if (error != null) throw error;
  return MetaSendResult.fromJson(json);
}
