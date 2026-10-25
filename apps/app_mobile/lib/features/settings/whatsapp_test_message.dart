import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_messaging/ampdent_messaging.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_mobile/features/recall/patient_messenger.dart'
    show bookingLink;
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Template used for the owner's test send: a plain utility template with
/// no clinical content and no OTP.
const String testMessageTemplateCode = 'WELCOME_NEW_PATIENT';

/// Builds the test request to [member]'s own phone. No patient is attached,
/// so the opt-in decider allows it as a staff message.
MessageRequest buildTestMessageRequest({
  required Clinic clinic,
  required ClinicMember member,
}) => MessageRequest(
  clinicId: clinic.id,
  toPhone: member.phone,
  template: templateByCode(testMessageTemplateCode)!,
  variables: {
    'clinic_name': clinic.name,
    'patient_name': member.displayName,
    'patient_number': 'TEST',
    'link': bookingLink(clinic).toString(),
    'clinic_phone': AppFormat.phone(clinic.whatsappPhone ?? clinic.phone),
  },
);

/// Queues [testMessageTemplateCode] to the signed-in member's phone through
/// the current [MessagingProvider] (the cloud queue when enabled).
Future<MessageLog> sendTestMessage({
  required MessagingProvider messaging,
  required Clinic clinic,
  required ClinicMember member,
}) => messaging.send(buildTestMessageRequest(clinic: clinic, member: member));

/// Card with the "Send test message to my number" action.
class WhatsAppTestMessageCard extends ConsumerStatefulWidget {
  /// Creates the card.
  const WhatsAppTestMessageCard({super.key});

  @override
  ConsumerState<WhatsAppTestMessageCard> createState() =>
      _WhatsAppTestMessageCardState();
}

class _WhatsAppTestMessageCardState
    extends ConsumerState<WhatsAppTestMessageCard> {
  static const Logger _log = Logger('whatsapp-test');
  bool _busy = false;
  MessageLog? _last;

  Future<void> _send() async {
    final clinic = ref.read(currentClinicProvider).value;
    final member = ref.read(currentMemberProvider).value;
    final messenger = ScaffoldMessenger.of(context);
    if (clinic == null || member == null) return;
    setState(() => _busy = true);
    try {
      final log = await sendTestMessage(
        messaging: ref.read(messagingProvider),
        clinic: clinic,
        member: member,
      );
      _log.info('test message queued to ${PhoneNumbers.mask(log.toPhone)}');
      if (mounted) setState(() => _last = log);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Queued for ${AppFormat.phone(log.toPhone)}; the server sends it '
            'within a minute.',
          ),
        ),
      );
    } on FormatException {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Your member phone is not a valid Indian mobile'),
        ),
      );
    } on Object catch (e) {
      _log.warning('test message failed: ${e.runtimeType}');
      messenger.showSnackBar(SnackBar(content: Text('Could not queue: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final member = ref.watch(currentMemberProvider).value;
    final mode = ref.watch(messagingModeProvider);
    final last = _last;
    return SectionCard(
      title: 'Test the pipeline',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            member == null
                ? 'No member selected.'
                : 'Queues the welcome template to your own number '
                      '(${AppFormat.phone(member.phone)}). Watch it go '
                      'queued, sent, delivered in the message log.',
          ),
          const SizedBox(height: AppSpacing.md),
          BigActionButton(
            key: const ValueKey('whatsapp-send-test'),
            label: 'Send test message to my number',
            icon: Icons.send_outlined,
            tonal: true,
            loading: _busy,
            onPressed: _busy || member == null || mode != MessagingMode.cloudApi
                ? null
                : _send,
          ),
          if (last != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Last test: ${last.templateCode} to '
              '${AppFormat.phone(last.toPhone)}, ${last.status.name}',
              key: const ValueKey('whatsapp-test-result'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
