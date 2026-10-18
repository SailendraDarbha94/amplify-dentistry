import 'package:meta/meta.dart';

import 'json_support.dart';

/// Outbound messaging channel.
enum MessageChannel { whatsapp, sms }

/// WhatsApp template category (drives pricing and opt-in rules).
enum MessageCategory { utility, authentication, marketing, service }

/// Delivery status of an outbound message.
enum MessageStatus { queued, sent, delivered, read, failed, cancelled }

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

  /// Returns a copy with the given fields replaced.
  MessageLog copyWith({
    MessageStatus? status,
    String? providerMessageId,
    String? error,
    int? costPaise,
    DateTime? sentAt,
    DateTime? deliveredAt,
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
  };

  /// Parses the JSON form.
  factory MessageLog.fromJson(Map<String, Object?> json) => MessageLog(
    id: json['id'] as String,
    clinicId: json['clinicId'] as String,
    patientId: json['patientId'] as String?,
    channel: enumFromJson(MessageChannel.values, json['channel']),
    category: enumFromJson(MessageCategory.values, json['category']),
    templateCode: json['templateCode'] as String,
    toPhone: json['toPhone'] as String,
    variables: stringMapFromJson(json['variables']),
    renderedPreview: json['renderedPreview'] as String,
    status: enumFromJson(MessageStatus.values, json['status']),
    providerMessageId: json['providerMessageId'] as String?,
    error: json['error'] as String?,
    costPaise: json['costPaise'] as int?,
    createdAt: dateFromJson(json['createdAt']),
    sentAt: dateFromJsonOrNull(json['sentAt']),
    deliveredAt: dateFromJsonOrNull(json['deliveredAt']),
  );
}
