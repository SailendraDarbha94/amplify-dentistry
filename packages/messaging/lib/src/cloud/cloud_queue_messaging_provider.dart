import 'dart:async';

import 'package:ampdent_core/ampdent_core.dart';

import '../optin/opt_in_policy.dart';
import '../phone/phone_numbers.dart';
import '../providers/message_log_keys.dart';
import '../providers/messaging_provider.dart';

/// Decides opt-in for a request: the app resolves the patient's `DataConsent`
/// ledger and guardian routing, then calls `OptInPolicy.canSend`.
typedef OptInDecider = FutureOr<SendDecision> Function(MessageRequest request);

/// Reads the latest status of a row by log id or provider message id; the
/// data layer backs it with the `message_logs` table that sync keeps fresh.
typedef StatusLookup = FutureOr<MessageStatus?> Function(String id);

/// Thrown by [CloudQueueMessagingProvider.send] when opt-in denies the send.
/// Nothing is written through the sink.
class OptInRefusedException implements Exception {
  /// Creates the exception.
  const OptInRefusedException(this.decision, this.templateCode);

  /// The negative decision (`reason` names the rule: `marketing_consent_missing`).
  final SendDecision decision;

  /// Template that was refused.
  final String templateCode;

  /// Short reason code for the UI.
  String get reason => decision.reason;

  @override
  String toString() => 'OptInRefusedException($templateCode: $reason)';
}

/// Offline-first Cloud API provider: renders the template for the preview,
/// enforces opt-in through the injected [OptInDecider], and emits a `queued`
/// [MessageLog] stamped `_provider: cloud_api` through the [MessageSink]. The
/// data layer persists the row; sync uploads it and the Edge Function sends
/// it with `buildMetaTemplatePayload`'s shape. No network call is made here.
class CloudQueueMessagingProvider implements MessagingProvider {
  /// Creates a provider writing through [sink] after [decide] allows.
  CloudQueueMessagingProvider(
    this._sink, {
    required this._decide,
    this._statusLookup,
    this._idGenerator = newId,
    this._clock = DateTime.now,
  });

  final MessageSink _sink;
  final OptInDecider _decide;
  final StatusLookup? _statusLookup;
  final IdGenerator _idGenerator;
  final Clock _clock;
  final Map<String, MessageStatus> _queuedHere = {};
  final Logger _log = const Logger('messaging.cloud_queue');

  /// Checks opt-in, renders, and queues. Throws [OptInRefusedException] when
  /// denied, [ArgumentError] on missing variables, [FormatException] on a bad
  /// phone; the sink is called only after all three pass.
  @override
  Future<MessageLog> send(MessageRequest request) async {
    final decision = await _decide(request);
    if (!decision.allowed) {
      _log.info(
        'refused ${request.template.code} '
        '(${request.category.name}): ${decision.reason}',
      );
      throw OptInRefusedException(decision, request.template.code);
    }
    final stamped = request.copyWith(
      variables: MessageLogKeys.stamp(
        request.variables,
        providerName: MessageLogKeys.cloudApiProvider,
        reason: decision.reason,
      ),
    );
    final log = stamped.toLog(id: _idGenerator(), now: _clock());
    await _sink(log);
    _queuedHere[log.id] = log.status;
    _log.info(
      'queued ${log.templateCode} to ${PhoneNumbers.mask(log.toPhone)} '
      'for cloud_api',
    );
    return log;
  }

  /// Status from the injected lookup (by log id or provider message id),
  /// else what this instance queued, else `queued`.
  @override
  Future<MessageStatus> status(String providerMessageId) async {
    final looked = await _statusLookup?.call(providerMessageId);
    return looked ?? _queuedHere[providerMessageId] ?? MessageStatus.queued;
  }
}
