import 'package:ampdent_core/ampdent_core.dart';

import '../phone/phone_numbers.dart';
import 'messaging_provider.dart';

/// Offline-first provider: renders the message, writes a `queued`
/// [MessageLog] through the injected [MessageSink] and performs no network
/// call. A sync worker drains the outbox to the Cloud API later.
class OutboxMessagingProvider implements MessagingProvider {
  /// Creates an outbox provider writing through [sink].
  OutboxMessagingProvider(
    this._sink, {
    this._idGenerator = newId,
    this._clock = DateTime.now,
  });

  final MessageSink _sink;
  final IdGenerator _idGenerator;
  final Clock _clock;
  final Map<String, MessageStatus> _statuses = {};
  final Logger _log = const Logger('messaging.outbox');

  @override
  Future<MessageLog> send(MessageRequest request) async {
    final log = request.toLog(id: _idGenerator(), now: _clock());
    await _sink(log);
    _statuses[log.id] = log.status;
    _log.info(
      'queued ${log.templateCode} to ${PhoneNumbers.mask(log.toPhone)}',
    );
    return log;
  }

  /// Status of a row this instance queued, keyed by the log `id` (the outbox
  /// has no provider id yet). Unknown ids report `queued`.
  @override
  Future<MessageStatus> status(String providerMessageId) async =>
      _statuses[providerMessageId] ?? MessageStatus.queued;

  /// Records a status reported back by the sync worker for [logId].
  void recordStatus(String logId, MessageStatus status) =>
      _statuses[logId] = status;
}
