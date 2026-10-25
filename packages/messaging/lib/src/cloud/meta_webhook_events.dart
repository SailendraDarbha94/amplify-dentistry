import 'package:ampdent_core/ampdent_core.dart';

// Parsers for the Meta WhatsApp webhook (`object: whatsapp_business_account`,
// `entry[].changes[].value`). The Edge Function verifies the signature and
// forwards the JSON; this side turns it into typed events and applies status
// transitions to MessageLog rows. No network code.

/// Parses Meta's epoch-seconds string timestamp as UTC.
DateTime metaTimestamp(Object? value) {
  final seconds = value is num ? value.toInt() : int.parse(value as String);
  return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
}

/// `919876543210` (Meta's digits-only id) as E.164 with the plus.
String metaPhoneToE164(String digits) =>
    digits.startsWith('+') ? digits : '+$digits';

/// Rank used to stop late webhooks moving a row backwards.
int _rank(MessageStatus s) => switch (s) {
  MessageStatus.queued => 0,
  MessageStatus.sent => 1,
  MessageStatus.delivered => 2,
  MessageStatus.read => 3,
  MessageStatus.failed => 4,
  MessageStatus.cancelled => 4,
};

/// One `statuses[]` entry: Meta reporting a message as sent, delivered, read
/// or failed.
class MetaStatusEvent {
  /// Creates a status event.
  const MetaStatusEvent({
    required this.providerMessageId,
    required this.status,
    required this.rawStatus,
    required this.recipientPhone,
    required this.timestamp,
    this.phoneNumberId,
    this.conversationId,
    this.pricingCategory,
    this.billable,
    this.errorCode,
    this.errorTitle,
    this.errorDetail,
  });

  /// `wamid...` id returned at send time; matches `MessageLog.providerMessageId`.
  final String providerMessageId;

  /// Mapped delivery status.
  final MessageStatus status;

  /// Meta's own string (`sent`, `delivered`, `read`, `failed`).
  final String rawStatus;

  /// Recipient as E.164 (`+91...`).
  final String recipientPhone;

  /// When Meta recorded the transition (UTC).
  final DateTime timestamp;

  /// `metadata.phone_number_id` of the clinic's WABA number.
  final String? phoneNumberId;

  /// `conversation.id`, when Meta opened or continued a conversation.
  final String? conversationId;

  /// `pricing.category` (`utility`, `marketing`, `authentication`, `service`).
  final String? pricingCategory;

  /// `pricing.billable`.
  final bool? billable;

  /// `errors[0].code` on failure (`131026` undeliverable, `131047` window).
  final int? errorCode;

  /// `errors[0].title` on failure.
  final String? errorTitle;

  /// `errors[0].error_data.details` on failure.
  final String? errorDetail;

  /// Whether this is a failure report.
  bool get isFailure => status == MessageStatus.failed;

  /// Error text for `MessageLog.error`: `131026 Message undeliverable`.
  String? get errorText => errorCode == null && errorTitle == null
      ? null
      : [if (errorCode != null) '$errorCode', ?errorTitle].join(' ');

  /// Maps Meta's status string; null for anything else (`deleted`,
  /// `warning`), which callers ignore.
  static MessageStatus? statusFromMeta(String raw) => switch (raw) {
    'sent' => MessageStatus.sent,
    'delivered' => MessageStatus.delivered,
    'read' => MessageStatus.read,
    'failed' => MessageStatus.failed,
    _ => null,
  };

  /// Parses one `statuses[]` entry; null when its status is not one of the
  /// four tracked values.
  static MetaStatusEvent? tryParse(
    Map<String, Object?> json, {
    String? phoneNumberId,
  }) {
    final raw = json['status'] as String? ?? '';
    final status = statusFromMeta(raw);
    if (status == null) return null;
    final errors = json['errors'] as List?;
    final error = errors == null || errors.isEmpty
        ? null
        : errors.first as Map?;
    final conversation = json['conversation'] as Map?;
    final pricing = json['pricing'] as Map?;
    return MetaStatusEvent(
      providerMessageId: json['id'] as String,
      status: status,
      rawStatus: raw,
      recipientPhone: metaPhoneToE164(json['recipient_id'] as String),
      timestamp: metaTimestamp(json['timestamp']),
      phoneNumberId: phoneNumberId,
      conversationId: conversation?['id'] as String?,
      pricingCategory: pricing?['category'] as String?,
      billable: pricing?['billable'] as bool?,
      errorCode: (error?['code'] as num?)?.toInt(),
      errorTitle: error?['title'] as String?,
      errorDetail: (error?['error_data'] as Map?)?['details'] as String?,
    );
  }

  /// [log] with this status applied, never moving backwards (a late `sent`
  /// after `delivered` is a no-op). `sent` stamps `sentAt`, `delivered` and
  /// `read` stamp `deliveredAt`, `failed` records [errorText].
  MessageLog applyTo(MessageLog log) {
    if (_rank(status) <= _rank(log.status) && status != log.status) return log;
    if (status == log.status) return log;
    return log.copyWith(
      status: status,
      providerMessageId: providerMessageId,
      sentAt: status == MessageStatus.sent ? timestamp : null,
      deliveredAt:
          status == MessageStatus.delivered || status == MessageStatus.read
          ? (log.deliveredAt ?? timestamp)
          : null,
      error: isFailure ? errorText : null,
    );
  }

  @override
  String toString() => 'MetaStatusEvent($rawStatus $providerMessageId)';
}

/// One `messages[]` entry: a patient wrote back (text, quick-reply button or
/// interactive reply). Only the reply text is kept; media is noted by type.
class MetaInboundMessage {
  /// Creates an inbound message.
  const MetaInboundMessage({
    required this.providerMessageId,
    required this.fromPhone,
    required this.timestamp,
    required this.type,
    this.text,
    this.contextMessageId,
    this.phoneNumberId,
  });

  /// `wamid...` of the inbound message.
  final String providerMessageId;

  /// Sender as E.164.
  final String fromPhone;

  /// When it was sent (UTC).
  final DateTime timestamp;

  /// Meta type: `text`, `button`, `interactive`, `image`, `reaction`, ...
  final String type;

  /// Reply text: `text.body`, `button.text` or the interactive reply title.
  final String? text;

  /// `context.id`: the outbound message this replies to, when WhatsApp knows.
  final String? contextMessageId;

  /// `metadata.phone_number_id` the message arrived on.
  final String? phoneNumberId;

  /// Whether the reply is the `1` our reminder templates ask for.
  bool get isConfirmationReply => text?.trim() == '1';

  /// Parses one `messages[]` entry.
  factory MetaInboundMessage.fromJson(
    Map<String, Object?> json, {
    String? phoneNumberId,
  }) {
    final type = json['type'] as String? ?? 'unknown';
    final context = json['context'] as Map?;
    return MetaInboundMessage(
      providerMessageId: json['id'] as String,
      fromPhone: metaPhoneToE164(json['from'] as String),
      timestamp: metaTimestamp(json['timestamp']),
      type: type,
      text: _replyText(type, json),
      contextMessageId: context?['id'] as String?,
      phoneNumberId: phoneNumberId,
    );
  }

  static String? _replyText(String type, Map<String, Object?> json) {
    switch (type) {
      case 'text':
        return (json['text'] as Map?)?['body'] as String?;
      case 'button':
        return (json['button'] as Map?)?['text'] as String?;
      case 'interactive':
        final interactive = json['interactive'] as Map?;
        final kind = interactive?['type'] as String?;
        final reply = kind == null ? null : interactive?[kind] as Map?;
        return reply?['title'] as String?;
      default:
        return null;
    }
  }

  @override
  String toString() => 'MetaInboundMessage($type from $fromPhone)';
}

/// Everything one webhook delivery carried.
class MetaWebhookEvents {
  /// Creates the parsed bundle.
  const MetaWebhookEvents({
    required this.statuses,
    required this.messages,
    this.ignoredStatuses = const [],
  });

  /// Nothing parsed.
  static const MetaWebhookEvents empty = MetaWebhookEvents(
    statuses: [],
    messages: [],
  );

  /// Status transitions, in delivery order.
  final List<MetaStatusEvent> statuses;

  /// Inbound messages, in delivery order.
  final List<MetaInboundMessage> messages;

  /// Raw status strings that were not one of the four tracked values.
  final List<String> ignoredStatuses;

  /// Whether nothing actionable was present.
  bool get isEmpty => statuses.isEmpty && messages.isEmpty;
}

/// Parses a full webhook body: walks `entry[].changes[]`, keeps changes whose
/// `field` is `messages`, and reads `value.statuses` and `value.messages`.
/// Malformed entries are skipped rather than failing the whole delivery.
MetaWebhookEvents parseMetaWebhook(Map<String, Object?> json) {
  final statuses = <MetaStatusEvent>[];
  final messages = <MetaInboundMessage>[];
  final ignored = <String>[];
  for (final entry in (json['entry'] as List?) ?? const []) {
    for (final change in ((entry as Map)['changes'] as List?) ?? const []) {
      final c = change as Map;
      if (c['field'] != null && c['field'] != 'messages') continue;
      final value = c['value'] as Map?;
      if (value == null) continue;
      final phoneNumberId = (value['metadata'] as Map?)?['phone_number_id'];
      final pnid = phoneNumberId as String?;
      for (final s in (value['statuses'] as List?) ?? const []) {
        final map = (s as Map).cast<String, Object?>();
        final event = MetaStatusEvent.tryParse(map, phoneNumberId: pnid);
        if (event == null) {
          ignored.add(map['status'] as String? ?? '');
        } else {
          statuses.add(event);
        }
      }
      for (final m in (value['messages'] as List?) ?? const []) {
        final map = (m as Map).cast<String, Object?>();
        if (map['id'] is! String || map['from'] is! String) continue;
        messages.add(MetaInboundMessage.fromJson(map, phoneNumberId: pnid));
      }
    }
  }
  return MetaWebhookEvents(
    statuses: statuses,
    messages: messages,
    ignoredStatuses: ignored,
  );
}
