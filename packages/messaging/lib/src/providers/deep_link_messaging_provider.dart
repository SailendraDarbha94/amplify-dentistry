import 'package:ampdent_core/ampdent_core.dart';

import '../phone/phone_numbers.dart';
import 'messaging_provider.dart';

/// `https://wa.me/<digits>?text=<encoded>` for [e164Phone] and [text].
///
/// wa.me wants the number as digits only (no plus) and the text percent
/// encoded; spaces become `%20`, not `+`.
Uri whatsappDeepLink(String e164Phone, String text) => Uri.parse(
  'https://wa.me/${PhoneNumbers.digitsOnly(e164Phone)}'
  '?text=${Uri.encodeComponent(text)}',
);

/// `sms:<e164>?body=<encoded>` for [e164Phone] and [text]; opens the default
/// SMS app on Android and iOS with the body prefilled.
Uri smsDeepLink(String e164Phone, String text) =>
    Uri.parse('sms:$e164Phone?body=${Uri.encodeComponent(text)}');

/// A rendered message ready to hand to the OS: the log row to persist plus
/// the WhatsApp and SMS URIs the app can launch.
class DeepLinkMessage {
  /// Creates a prepared deep-link message.
  const DeepLinkMessage({
    required this.log,
    required this.whatsappUri,
    required this.smsUri,
  });

  /// Log row, status `queued` until `markLaunched`.
  final MessageLog log;

  /// wa.me link with the rendered text.
  final Uri whatsappUri;

  /// sms: link with the rendered text.
  final Uri smsUri;

  /// The URI matching the request's channel.
  Uri get preferredUri =>
      log.channel == MessageChannel.sms ? smsUri : whatsappUri;
}

/// Solo-clinic v1 fallback until the Cloud API is wired: renders the body and
/// hands the app a wa.me (or sms:) URI to launch from the dentist's own
/// phone. No network call is made here; the message is `sent` only once the
/// caller reports the launch succeeded via [markLaunched].
class DeepLinkMessagingProvider implements MessagingProvider {
  /// Creates a deep-link provider.
  DeepLinkMessagingProvider({
    this._idGenerator = newId,
    this._clock = DateTime.now,
  });

  final IdGenerator _idGenerator;
  final Clock _clock;
  final Map<String, MessageStatus> _statuses = {};
  final Logger _log = const Logger('messaging.deeplink');

  /// Renders [request] and builds the URIs without changing any state.
  DeepLinkMessage prepare(MessageRequest request) {
    final log = request.toLog(id: _idGenerator(), now: _clock());
    return DeepLinkMessage(
      log: log,
      whatsappUri: whatsappDeepLink(log.toPhone, log.renderedPreview),
      smsUri: smsDeepLink(log.toPhone, log.renderedPreview),
    );
  }

  /// Returns the `queued` log for [request]; call [prepare] when the URI is
  /// needed too, then [markLaunched] after the OS opened it.
  @override
  Future<MessageLog> send(MessageRequest request) async {
    final prepared = prepare(request);
    _statuses[prepared.log.id] = MessageStatus.queued;
    return prepared.log;
  }

  /// Marks [log] as `sent` now that the caller launched its URI.
  Future<MessageLog> markLaunched(MessageLog log) async {
    final sent = log.copyWith(status: MessageStatus.sent, sentAt: _clock());
    _statuses[sent.id] = MessageStatus.sent;
    _log.info(
      'launched ${sent.templateCode} to ${PhoneNumbers.mask(sent.toPhone)}',
    );
    return sent;
  }

  /// Marks [log] as `cancelled` when the launch failed or was abandoned.
  Future<MessageLog> markLaunchFailed(MessageLog log, {String? error}) async {
    final failed = log.copyWith(status: MessageStatus.cancelled, error: error);
    _statuses[failed.id] = MessageStatus.cancelled;
    return failed;
  }

  /// Status keyed by log `id` (deep links have no provider id). Unknown ids
  /// report `queued`.
  @override
  Future<MessageStatus> status(String providerMessageId) async =>
      _statuses[providerMessageId] ?? MessageStatus.queued;
}
