import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_data/ampdent_data.dart';
import 'package:ampdent_messaging/ampdent_messaging.dart';
import 'package:ampdent_mobile/core/cloud_messaging.dart';
import 'package:ampdent_mobile/core/formatting.dart';

/// Which appointment message to send.
enum AppointmentMessageKind {
  /// `APPT_CONFIRM`, sent right after booking.
  confirmation('APPT_CONFIRM'),

  /// `APPT_REMINDER_24H`, sent the day before.
  reminder24h('APPT_REMINDER_24H');

  const AppointmentMessageKind(this.templateCode);

  /// Template code in `ampdent_messaging`.
  final String templateCode;

  /// The template, which always exists in the default set.
  MessageTemplate get template => templateByCode(templateCode)!;
}

/// Launches a URI outside the app; returns whether the OS accepted it.
typedef UriLauncher = Future<bool> Function(Uri uri);

/// Result of one send attempt.
class AppointmentSendOutcome {
  /// Creates an outcome.
  const AppointmentSendOutcome({
    required this.decision,
    this.log,
    this.launchedUri,
    this.appointment,
    this.queued = false,
  });

  /// The opt-in decision; when denied nothing else is set.
  final SendDecision decision;

  /// The persisted message log row (`sent`, `cancelled`, or `queued` for
  /// the Cloud API).
  final MessageLog? log;

  /// The wa.me URI handed to the OS, when the launch succeeded.
  final Uri? launchedUri;

  /// The appointment after stamping, when the send went ahead.
  final Appointment? appointment;

  /// Whether the row was queued for the Cloud API (the server sends it).
  final bool queued;

  /// Whether the message left the phone or is on its way via the server.
  bool get sent => launchedUri != null || queued;
}

/// Human-readable explanation for an [OptInPolicy] denial reason.
String sendDenialMessage(String reason) => switch (reason) {
  'age_unknown' =>
    'Record the patient\'s date of birth or age first: a minor\'s messages '
        'must go to the guardian',
  'transactional_consent_missing' =>
    'No appointment-reminder consent recorded for this patient',
  'minor_not_routed_to_guardian' =>
    'Patient is a minor and has no guardian phone on file',
  _ => 'Messaging is not permitted: $reason',
};

/// Sends appointment confirmations and reminders over the WhatsApp deep link
/// after the DPDP opt-in check, logging every attempt and stamping the
/// appointment's reminder timestamps.
class AppointmentMessenger {
  /// Creates a messenger.
  const AppointmentMessenger({
    required this.messaging,
    required this.logs,
    required this.appointments,
    required this.ctx,
    required this.launch,
    required this.clock,
  });

  /// Provider that renders and logs the message (queued).
  final MessagingProvider messaging;

  /// Log repository used to mark the row sent or cancelled.
  final MessageLogRepository logs;

  /// Appointment repository used to stamp reminder times.
  final AppointmentRepository appointments;

  /// Actor for writes.
  final ActorContext ctx;

  /// Hands the deep link to the OS.
  final UriLauncher launch;

  /// Time source.
  final DateTime Function() clock;

  /// Opt-in decision for a utility message to [patient] given the full
  /// consent ledger. Minors are only messaged through a guardian phone, and
  /// a patient whose age is unknown is not messaged at all (they may be a
  /// minor), matching the care-plan reminder rule.
  static SendDecision decide({
    required Patient patient,
    required Iterable<DataConsent> consents,
    required DateTime now,
  }) {
    final age = patient.ageStatus(now);
    if (age == AgeStatus.unknown) {
      return const SendDecision.deny('age_unknown');
    }
    final minor = age == AgeStatus.minor;
    final guardianPhone = patient.guardianPhone ?? '';
    return OptInPolicy.canSend(
      category: MessageCategory.utility,
      consents: consents,
      isMinor: minor,
      isMinorRoutedToGuardian: minor && guardianPhone.isNotEmpty,
    );
  }

  /// Destination phone: the guardian's for a minor, else the patient's.
  static String destinationPhone(Patient patient, DateTime now) =>
      patient.messagingPhone(now);

  /// Template variables for [appointment].
  static Map<String, String> variablesFor({
    required Appointment appointment,
    required Patient patient,
    required Clinic clinic,
    required ClinicMember provider,
  }) => {
    'patient_name': patient.displayName,
    'clinic_name': clinic.name,
    'appointment_date': AppFormat.date(appointment.startsAt),
    'appointment_time': AppFormat.time(appointment.startsAt),
    'doctor_name': _bareName(provider.displayName),
    'clinic_phone': AppFormat.phone(clinic.whatsappPhone ?? clinic.phone),
  };

  /// Builds the request for [kind] without sending it.
  static MessageRequest buildRequest({
    required AppointmentMessageKind kind,
    required Appointment appointment,
    required Patient patient,
    required Clinic clinic,
    required ClinicMember provider,
    required DateTime now,
  }) => MessageRequest(
    clinicId: appointment.clinicId,
    patientId: patient.id,
    toPhone: destinationPhone(patient, now),
    template: kind.template,
    variables: variablesFor(
      appointment: appointment,
      patient: patient,
      clinic: clinic,
      provider: provider,
    ),
  );

  /// Checks opt-in, logs the message, opens WhatsApp and stamps the
  /// appointment. Never throws for a denied send; launch failures are
  /// recorded on the log row as `cancelled`.
  Future<AppointmentSendOutcome> send({
    required AppointmentMessageKind kind,
    required Appointment appointment,
    required Patient patient,
    required Iterable<DataConsent> consents,
    required Clinic clinic,
    required ClinicMember provider,
  }) async {
    final now = clock();
    final decision = decide(patient: patient, consents: consents, now: now);
    if (!decision.allowed) return AppointmentSendOutcome(decision: decision);

    final request = buildRequest(
      kind: kind,
      appointment: appointment,
      patient: patient,
      clinic: clinic,
      provider: provider,
      now: now,
    );
    final MessageLog queued;
    try {
      queued = await messaging.send(request);
    } on OptInRefusedException catch (e) {
      return AppointmentSendOutcome(decision: e.decision);
    }
    if (isCloudApiLog(queued)) {
      final stamped = await _stamp(kind, appointment, now.toUtc());
      return AppointmentSendOutcome(
        decision: decision,
        log: queued,
        appointment: stamped,
        queued: true,
      );
    }
    final uri = whatsappDeepLink(queued.toPhone, queued.renderedPreview);

    var launched = false;
    String? error;
    try {
      launched = await launch(uri);
    } on Object catch (e) {
      error = e.toString();
    }
    if (!launched) {
      final cancelled = await logs.updateStatus(
        ctx,
        queued.id,
        MessageStatus.cancelled,
        error: error ?? 'launch_refused',
        at: now.toUtc(),
      );
      return AppointmentSendOutcome(decision: decision, log: cancelled);
    }

    final sent = await logs.updateStatus(
      ctx,
      queued.id,
      MessageStatus.sent,
      at: now.toUtc(),
    );
    final stamped = await _stamp(kind, appointment, now.toUtc());
    return AppointmentSendOutcome(
      decision: decision,
      log: sent,
      launchedUri: uri,
      appointment: stamped,
    );
  }

  Future<Appointment> _stamp(
    AppointmentMessageKind kind,
    Appointment appointment,
    DateTime nowUtc,
  ) {
    final latest = appointment;
    final updated = switch (kind) {
      AppointmentMessageKind.reminder24h => latest.copyWith(
        reminder24hSentAt: nowUtc,
        updatedAt: nowUtc,
      ),
      // No dedicated column for the booking confirmation; the message log
      // carries it. Touch updatedAt so the row syncs with the log.
      AppointmentMessageKind.confirmation => latest.copyWith(updatedAt: nowUtc),
    };
    return appointments.upsert(ctx, updated);
  }

  /// `Dr. A. Rao` -> `A. Rao`, since the templates add the title.
  static String _bareName(String displayName) {
    final trimmed = displayName.trim();
    final match = RegExp(
      r'^(Dr\.?|Doctor)\s+',
      caseSensitive: false,
    ).firstMatch(trimmed);
    return match == null ? trimmed : trimmed.substring(match.end);
  }
}
