import 'package:meta/meta.dart';

import 'json_support.dart';

/// Outbound messaging channel.
enum MessageChannel { whatsapp, sms }

/// WhatsApp template category (drives pricing and opt-in rules).
enum MessageCategory { utility, authentication, marketing, service }

/// Delivery status of an outbound message.
enum MessageStatus { queued, sent, delivered, read, failed, cancelled }

/// Which backend owns delivery of a [MessageLog]. [wireName] is the value
/// stored locally and on the server (`message_logs.provider`, whose check
/// constraint also reserves `sms_gateway` for MSG91).
enum MessageProvider {
  /// Launched from the dentist's own phone via `wa.me` / `sms:`.
  deeplink('deeplink'),

  /// Queued for the server's WhatsApp Cloud API sender.
  cloudApi('cloud_api'),

  /// Reserved for the SMS gateway (MSG91); mirrors the server constraint.
  smsGateway('sms_gateway');

  const MessageProvider(this.wireName);

  /// Storage and wire value (`cloud_api`, not the Dart name).
  final String wireName;

  /// Parses a wire name or a Dart enum name; null for null or unknown input.
  static MessageProvider? tryParse(Object? value) {
    if (value is! String) return null;
    for (final p in values) {
      if (p.wireName == value || p.name == value) return p;
    }
    return null;
  }

  /// Parses a wire name or a Dart enum name; throws [FormatException] on
  /// unknown input.
  static MessageProvider parse(Object? value) =>
      tryParse(value) ??
      (throw FormatException('Unknown MessageProvider', value));
}

/// Reserved `MessageLog.variables` keys used before [MessageLog.provider]
/// and [MessageLog.optInReason] existed; [MessageLog.fromJson] still reads
/// them so rows written by older builds keep their meaning.
abstract final class LegacyMessageLogKeys {
  /// Provider wire name under `variables`.
  static const String provider = '_provider';

  /// Opt-in reason under `variables`.
  static const String optInReason = '_opt_in_reason';
}

/// One outbound message in the outbox / delivery log. The body is a template
/// plus variables; no clinical content is ever put in a message.
@immutable
class MessageLog {
  /// Creates a message log row.
  const MessageLog({
    required this.id,
    required this.clinicId,
    this.patientId,
    required this.channel,
    required this.category,
    required this.templateCode,
    required this.toPhone,
    this.variables = const {},
    required this.renderedPreview,
    this.status = MessageStatus.queued,
    this.providerMessageId,
    this.error,
    this.costPaise,
    required this.createdAt,
    this.sentAt,
    this.deliveredAt,
    this.provider,
    this.optInReason,
  });

  /// UUID v4.
  final String id;

  /// Owning clinic.
  final String clinicId;

  /// Patient the message concerns, if any.
  final String? patientId;

  /// Channel.
  final MessageChannel channel;

  /// Template category.
  final MessageCategory category;

  /// Approved template code (`appt_reminder_24h`).
  final String templateCode;

  /// Destination phone (guardian's for minors).
  final String toPhone;

  /// Template variables by placeholder name.
  final Map<String, String> variables;

  /// Rendered text for display in the log.
  final String renderedPreview;

  /// Delivery status.
  final MessageStatus status;

  /// Provider's message id once accepted.
  final String? providerMessageId;

  /// Provider error text on failure.
  final String? error;

  /// Billed cost in paise, when known.
  final int? costPaise;

  /// Row creation (queue) time.
  final DateTime createdAt;

  /// When handed to the provider.
  final DateTime? sentAt;

  /// When the provider reported delivery.
  final DateTime? deliveredAt;

  /// Backend that owns delivery; null on rows queued before the field
  /// existed (see [LegacyMessageLogKeys]) and treated as the server default
  /// (`deeplink`) there.
  final MessageProvider? provider;

  /// `SendDecision.reason` that allowed the send (DPDP audit trail), if the
  /// provider recorded one.
  final String? optInReason;

  /// Returns a copy with the given fields replaced.
  MessageLog copyWith({
    MessageStatus? status,
    String? providerMessageId,
    String? error,
    int? costPaise,
    DateTime? sentAt,
    DateTime? deliveredAt,
    MessageProvider? provider,
    String? optInReason,
  }) => MessageLog(
    id: id,
    clinicId: clinicId,
    patientId: patientId,
    channel: channel,
    category: category,
    templateCode: templateCode,
    toPhone: toPhone,
    variables: variables,
    renderedPreview: renderedPreview,
    status: status ?? this.status,
    providerMessageId: providerMessageId ?? this.providerMessageId,
    error: error ?? this.error,
    costPaise: costPaise ?? this.costPaise,
    createdAt: createdAt,
    sentAt: sentAt ?? this.sentAt,
    deliveredAt: deliveredAt ?? this.deliveredAt,
    provider: provider ?? this.provider,
    optInReason: optInReason ?? this.optInReason,
  );

  /// JSON form.
  Map<String, Object?> toJson() => {
    'id': id,
    'clinicId': clinicId,
    'patientId': patientId,
    'channel': channel.name,
    'category': category.name,
    'templateCode': templateCode,
    'toPhone': toPhone,
    'variables': variables,
    'renderedPreview': renderedPreview,
    'status': status.name,
    'providerMessageId': providerMessageId,
    'error': error,
    'costPaise': costPaise,
    'createdAt': dateToJson(createdAt),
    'sentAt': dateToJson(sentAt),
    'deliveredAt': dateToJson(deliveredAt),
    'provider': provider?.wireName,
    'optInReason': optInReason,
  };

  /// Parses the JSON form. `provider` and `optInReason` fall back to the
  /// legacy `variables._provider` / `variables._opt_in_reason` stamps so
  /// rows written before the fields existed parse the same way.
  factory MessageLog.fromJson(Map<String, Object?> json) {
    final variables = stringMapFromJson(json['variables']);
    return MessageLog(
      id: json['id'] as String,
      clinicId: json['clinicId'] as String,
      patientId: json['patientId'] as String?,
      channel: enumFromJson(MessageChannel.values, json['channel']),
      category: enumFromJson(MessageCategory.values, json['category']),
      templateCode: json['templateCode'] as String,
      toPhone: json['toPhone'] as String,
      variables: variables,
      renderedPreview: json['renderedPreview'] as String,
      status: enumFromJson(MessageStatus.values, json['status']),
      providerMessageId: json['providerMessageId'] as String?,
      error: json['error'] as String?,
      costPaise: json['costPaise'] as int?,
      createdAt: dateFromJson(json['createdAt']),
      sentAt: dateFromJsonOrNull(json['sentAt']),
      deliveredAt: dateFromJsonOrNull(json['deliveredAt']),
      provider:
          MessageProvider.tryParse(json['provider']) ??
          MessageProvider.tryParse(variables[LegacyMessageLogKeys.provider]),
      optInReason:
          json['optInReason'] as String? ??
          variables[LegacyMessageLogKeys.optInReason],
    );
  }
}
