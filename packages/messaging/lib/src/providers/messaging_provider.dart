import 'package:ampdent_core/ampdent_core.dart';

import '../cost/message_cost.dart';
import '../phone/phone_numbers.dart';
import '../templates/message_template.dart';

/// Everything needed to send one templated message to one phone.
///
/// Opt-in is decided before a request is built (see `OptInPolicy`); the
/// provider trusts the caller on consent and guardian routing.
class MessageRequest {
  /// Creates a request. [category] defaults to the template's category.
  const MessageRequest({
    required this.clinicId,
    this.patientId,
    required this.toPhone,
    required this.template,
    this.variables = const {},
    this._category,
  });

  /// Sending clinic.
  final String clinicId;

  /// Patient the message concerns (null for staff or lab messages).
  final String? patientId;

  /// Destination phone in any accepted Indian form; normalised on send.
  final String toPhone;

  /// Template to render.
  final MessageTemplate template;

  /// Values for the template's placeholders.
  final Map<String, String> variables;

  final MessageCategory? _category;

  /// Category billed and policed; the template's unless overridden.
  MessageCategory get category => _category ?? template.category;

  /// Channel, taken from the template.
  MessageChannel get channel => template.channel;

  /// Destination as E.164; throws [FormatException] when not an Indian mobile.
  String get e164Phone => PhoneNumbers.normaliseIndian(toPhone);

  /// Renders the template; throws [ArgumentError] on missing variables.
  String render() => template.render(variables);

  /// Builds the [MessageLog] row for this request.
  MessageLog toLog({
    required String id,
    required DateTime now,
    MessageStatus status = MessageStatus.queued,
    String? providerMessageId,
    DateTime? sentAt,
  }) => MessageLog(
    id: id,
    clinicId: clinicId,
    patientId: patientId,
    channel: channel,
    category: category,
    templateCode: template.code,
    toPhone: e164Phone,
    variables: variables,
    renderedPreview: render(),
    status: status,
    providerMessageId: providerMessageId,
    costPaise: estimateCostPaise(category),
    createdAt: now,
    sentAt: sentAt,
  );
}

/// Contract every outbound messaging backend implements: Meta Cloud API,
/// MSG91 SMS, the local outbox and the wa.me deep link all look the same to
/// the app.
abstract class MessagingProvider {
  /// Renders and dispatches [request], returning the log row to persist.
  Future<MessageLog> send(MessageRequest request);

  /// Current delivery status of a message previously returned by [send].
  Future<MessageStatus> status(String providerMessageId);
}

/// Receives each queued [MessageLog]; the data layer persists it to the
/// outbox table and a later sync worker hands it to the real provider.
typedef MessageSink = Future<void> Function(MessageLog log);

/// Produces client-side ids for new log rows (defaults to `newId`).
typedef IdGenerator = String Function();

/// Supplies the current time (defaults to `DateTime.now`).
typedef Clock = DateTime Function();
