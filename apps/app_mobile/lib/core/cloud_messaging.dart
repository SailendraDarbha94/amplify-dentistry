/// Messaging through the cloud queue: the DPDP opt-in decider the
/// `CloudQueueMessagingProvider` runs before a row is queued, and the
/// labels the UI shows for a message's provider and delivery status.
library;

import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_data/ampdent_data.dart';
import 'package:ampdent_messaging/ampdent_messaging.dart';
import 'package:ampdent_ui/ampdent_ui.dart' show BadgeTone;

/// Which backend delivers a message.
enum MessagingMode {
  /// wa.me / sms: links opened on the dentist's phone.
  deepLink,

  /// Rows queued for the `whatsapp-send` Edge Function.
  cloudApi,
}

/// Builds the opt-in decider for cloud sends: resolves the patient and the
/// DPDP ledger, requires guardian routing for minors, and allows utility
/// messages on a recall-reminders consent as the care-plan messengers do;
/// otherwise `OptInPolicy.canSend`. Messages without a patient (the owner's
/// own test message) are allowed.
OptInDecider buildCloudOptInDecider({
  required PatientRepository patients,
  required ConsentRepository consents,
  required DateTime Function() clock,
}) => (MessageRequest request) async {
  final patientId = request.patientId;
  if (patientId == null) return const SendDecision.allow('staff_message');
  final patient = await patients.getById(patientId);
  if (patient == null) return const SendDecision.deny('patient_not_found');
  final now = clock();
  if (patient.ageStatus(now) == AgeStatus.unknown) {
    return const SendDecision.deny('age_unknown');
  }
  final isMinor = patient.isMinor(now);
  final guardian = PhoneNumbers.tryNormaliseIndian(patient.guardianPhone ?? '');
  final to = PhoneNumbers.tryNormaliseIndian(request.toPhone);
  final toGuardian = isMinor && guardian != null && guardian == to;
  if (isMinor && !toGuardian) {
    return const SendDecision.deny('minor_not_routed_to_guardian');
  }
  final ledger = await consents.dataConsentsForPatient(patientId);
  if (request.category == MessageCategory.utility &&
      hasActiveConsent(ledger, DataPurpose.recallReminders)) {
    return const SendDecision.allow('recall_reminders_consent');
  }
  return OptInPolicy.canSend(
    category: request.category,
    consents: ledger,
    isMinorRoutedToGuardian: toGuardian,
    isMinor: isMinor,
  );
};

/// Whether [log] was queued for the Cloud API worker (stamped rows only;
/// unstamped legacy rows were deep-link sends from this phone).
bool isCloudApiLog(MessageLog log) =>
    MessageLogKeys.providerOf(log) == MessageLogKeys.cloudApiProvider;

/// `Queued`, `Delivered`, ...
String messageStatusLabel(MessageStatus status) => switch (status) {
  MessageStatus.queued => 'Queued',
  MessageStatus.sent => 'Sent',
  MessageStatus.delivered => 'Delivered',
  MessageStatus.read => 'Read',
  MessageStatus.failed => 'Failed',
  MessageStatus.cancelled => 'Cancelled',
};

/// Badge tone for a delivery status.
BadgeTone messageStatusTone(MessageStatus status) => switch (status) {
  MessageStatus.queued => BadgeTone.warning,
  MessageStatus.sent => BadgeTone.info,
  MessageStatus.delivered => BadgeTone.success,
  MessageStatus.read => BadgeTone.completed,
  MessageStatus.failed => BadgeTone.danger,
  MessageStatus.cancelled => BadgeTone.neutral,
};

/// `via Cloud API` / `from this phone`.
String messageProviderLabel(MessageLog log) =>
    isCloudApiLog(log) ? 'via Cloud API' : 'from this phone';

/// `APPT_REMINDER_24H` -> `Appt reminder 24h`.
String messageTemplateLabel(String code) {
  final words = code.toLowerCase().split('_').where((w) => w.isNotEmpty);
  final text = words.join(' ');
  return text.isEmpty ? code : text[0].toUpperCase() + text.substring(1);
}

/// `WhatsApp` / `SMS`.
String messageChannelLabel(MessageChannel channel) => switch (channel) {
  MessageChannel.whatsapp => 'WhatsApp',
  MessageChannel.sms => 'SMS',
};
