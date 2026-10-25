import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_data/ampdent_data.dart';
import 'package:ampdent_messaging/ampdent_messaging.dart';
import 'package:ampdent_mobile/core/cloud_messaging.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;

/// Opens a URI in the matching external app; false when it could not.
typedef LinkLauncher = Future<bool> Function(Uri uri);

/// Default launcher: `url_launcher` in an external application. Any platform
/// failure (plugin missing, no WhatsApp installed) reports false. The log
/// line names only the scheme and host: the URI's query carries the rendered
/// message, which must never reach device logs.
Future<bool> launchExternal(Uri uri) async {
  try {
    return await launcher.launchUrl(
      uri,
      mode: launcher.LaunchMode.externalApplication,
    );
  } on Exception catch (e) {
    const Logger('recall.launch').warning(
      'could not launch ${uri.scheme}://${uri.host} (${e.runtimeType})',
    );
    return false;
  }
}

/// Launcher used to open wa.me / sms: links; override in tests.
final Provider<LinkLauncher> linkLauncherProvider = Provider<LinkLauncher>(
  (ref) => launchExternal,
);

/// Opt-in check for a care-plan reminder (recall, incomplete treatment, lab
/// ready). An active [DataPurpose.recallReminders] consent allows it;
/// otherwise the generic [OptInPolicy] rules apply (appointment reminders or
/// treatment records consent). Minors must route to a recorded guardian.
SendDecision reminderSendDecision({
  required Patient patient,
  required Iterable<DataConsent> consents,
  required DateTime now,
  MessageCategory category = MessageCategory.utility,
}) {
  if (patient.ageStatus(now) == AgeStatus.unknown) {
    return const SendDecision.deny('age_unknown');
  }
  final isMinor = patient.isMinor(now);
  final toGuardian = isMinor && (patient.guardianPhone ?? '').trim().isNotEmpty;
  if (isMinor && !toGuardian) {
    return const SendDecision.deny('minor_not_routed_to_guardian');
  }
  if (category == MessageCategory.utility &&
      hasActiveConsent(consents, DataPurpose.recallReminders)) {
    return const SendDecision.allow('recall_reminders_consent');
  }
  return OptInPolicy.canSend(
    category: category,
    consents: consents,
    isMinorRoutedToGuardian: toGuardian,
    isMinor: isMinor,
  );
}

/// Decides whether a message may go to [patient] given the DPDP ledger.
typedef SendDecider = SendDecision Function({
  required Patient patient,
  required Iterable<DataConsent> consents,
  required DateTime now,
  MessageCategory category,
});

/// Opt-in check for a document link about the patient's own care
/// (prescription, invoice, estimate): the generic [OptInPolicy] rules
/// (appointment-reminder or treatment-records consent). Unlike
/// [reminderSendDecision], a recall-reminders consent alone is not enough.
/// Minors must route to a recorded guardian.
SendDecision documentSendDecision({
  required Patient patient,
  required Iterable<DataConsent> consents,
  required DateTime now,
  MessageCategory category = MessageCategory.utility,
}) {
  if (patient.ageStatus(now) == AgeStatus.unknown) {
    return const SendDecision.deny('age_unknown');
  }
  final isMinor = patient.isMinor(now);
  final toGuardian = isMinor && (patient.guardianPhone ?? '').trim().isNotEmpty;
  return OptInPolicy.canSend(
    category: category,
    consents: consents,
    isMinorRoutedToGuardian: toGuardian,
    isMinor: isMinor,
  );
}

/// Human text for a denied [SendDecision.reason].
String sendDenialText(String reason) => switch (reason) {
  'age_unknown' =>
    'Record the patient\'s date of birth or age first: a minor\'s messages '
        'must go to the guardian',
  'minor_not_routed_to_guardian' =>
    'Patient is under 18 and has no guardian phone on record',
  'transactional_consent_missing' =>
    'No reminder consent on record. Ask the patient and tick '
        'Recall reminders on their profile.',
  'invalid_phone' => 'The phone number is not a valid Indian mobile',
  _ => 'Message not allowed: $reason',
};

/// The link patients tap to book: the clinic's WhatsApp (or phone) until the
/// hosted booking page exists. Never carries clinical content.
Uri bookingLink(Clinic clinic) {
  final wa = clinic.whatsappPhone ?? clinic.phone;
  final e164 = PhoneNumbers.tryNormaliseIndian(wa);
  if (e164 != null) {
    return Uri.parse('https://wa.me/${PhoneNumbers.digitsOnly(e164)}');
  }
  return Uri.parse('tel:${clinic.phone.replaceAll(' ', '')}');
}

/// Outcome of [PatientMessenger.send].
class PatientMessageResult {
  /// Creates a result.
  const PatientMessageResult({
    required this.decision,
    this.log,
    this.launched = false,
    this.queued = false,
  });

  /// The opt-in decision; when denied nothing was logged or launched.
  final SendDecision decision;

  /// The persisted message log row (queued or sent), when allowed.
  final MessageLog? log;

  /// Whether the OS opened the WhatsApp / SMS link.
  final bool launched;

  /// Whether the row was queued for the Cloud API (the server sends it; no
  /// link was opened and the status stays `queued` until the server reports).
  final bool queued;

  /// Whether the message left the device or is on its way via the server.
  bool get sent => log != null && (launched || queued);

  /// Whether a deep link was needed and could not be opened.
  bool get launchFailed => log != null && !launched && !queued;
}

/// Sends one templated utility message to a patient: opt-in check, render
/// through the logged [MessagingProvider], open the deep link, then mark the
/// log row `sent` (or `cancelled` when the link could not open). Log lines
/// carry the template code and a masked phone only, never the message body.
class PatientMessenger {
  static const Logger _log = Logger('recall.messenger');

  /// Creates a messenger.
  const PatientMessenger({
    required this.messaging,
    required this.logs,
    required this.consents,
    required this.ctx,
    required this.launch,
    required this.clock,
  });

  /// Renders and logs the message.
  final MessagingProvider messaging;

  /// Status updates after launch.
  final MessageLogRepository logs;

  /// Source of the patient's DPDP consent ledger.
  final ConsentRepository consents;

  /// Actor for the writes.
  final ActorContext ctx;

  /// Opens the wa.me / sms: link.
  final LinkLauncher launch;

  /// Current time.
  final DateTime Function() clock;

  /// Sends [template] to [patient] (or the guardian for a minor). The
  /// messenger fills `patient_name`, `clinic_name`, `clinic_phone` and
  /// `link`; [variables] supply the rest and override those defaults.
  /// [decide] is the opt-in rule: [reminderSendDecision] for care-plan
  /// reminders (the default), [documentSendDecision] for document links.
  Future<PatientMessageResult> send({
    required Patient patient,
    required Clinic clinic,
    required MessageTemplate template,
    Map<String, String> variables = const {},
    SendDecider decide = reminderSendDecision,
  }) async {
    final now = clock();
    final ledger = await consents.dataConsentsForPatient(patient.id);
    final decision = decide(
      patient: patient,
      consents: ledger,
      now: now,
      category: template.category,
    );
    if (!decision.allowed) return PatientMessageResult(decision: decision);

    final request = MessageRequest(
      clinicId: clinic.id,
      patientId: patient.id,
      toPhone: patient.messagingPhone(now),
      template: template,
      variables: {
        'patient_name': patient.firstName,
        'clinic_name': clinic.name,
        'clinic_phone': clinic.phone,
        'link': bookingLink(clinic).toString(),
        ...variables,
      },
    );
    final MessageLog log;
    try {
      log = await messaging.send(request);
    } on FormatException {
      return const PatientMessageResult(
        decision: SendDecision.deny('invalid_phone'),
      );
    } on OptInRefusedException catch (e) {
      return PatientMessageResult(decision: e.decision);
    }
    if (isCloudApiLog(log)) {
      _log.info(
        'queued ${template.code} to ${PhoneNumbers.mask(log.toPhone)} '
        'for the Cloud API',
      );
      return PatientMessageResult(decision: decision, log: log, queued: true);
    }
    final uri = log.channel == MessageChannel.sms
        ? smsDeepLink(log.toPhone, log.renderedPreview)
        : whatsappDeepLink(log.toPhone, log.renderedPreview);
    final launched = await launch(uri);
    final masked = PhoneNumbers.mask(log.toPhone);
    if (launched) {
      _log.debug('launched ${template.code} to $masked');
    } else {
      _log.info('launch failed ${template.code} to $masked');
    }
    final updated = await logs.updateStatus(
      ctx,
      log.id,
      launched ? MessageStatus.sent : MessageStatus.cancelled,
      error: launched ? null : 'launch_failed',
      at: now,
    );
    return PatientMessageResult(
      decision: decision,
      log: updated,
      launched: launched,
    );
  }
}

/// Messenger bound to the current actor, logged messaging provider and the
/// overridable [linkLauncherProvider].
final Provider<PatientMessenger> patientMessengerProvider =
    Provider<PatientMessenger>(
      (ref) => PatientMessenger(
        messaging: ref.watch(messagingProvider),
        logs: ref.watch(messageLogRepositoryProvider),
        consents: ref.watch(consentRepositoryProvider),
        ctx: ref.watch(actorContextProvider),
        launch: ref.watch(linkLauncherProvider),
        clock: ref.watch(clockProvider),
      ),
    );
