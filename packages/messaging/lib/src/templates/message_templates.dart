import 'package:ampdent_core/ampdent_core.dart';

import 'message_template.dart';
import 'post_op_templates.dart';

// Every default template is English; Hindi and Telugu bodies arrive later
// under the same codes with a different languageCode. No body carries
// clinical content: findings, diagnoses, radiographs and medication details
// live behind the authenticated {link}. Procedure names are allowed.

/// Appointment lifecycle templates (confirmation, reminders, changes).
const List<MessageTemplate> appointmentTemplates = [
  MessageTemplate(
    code: 'APPT_CONFIRM',
    channel: MessageChannel.whatsapp,
    category: MessageCategory.utility,
    body:
        'Hi {patient_name}, your appointment at {clinic_name} is booked for '
        '{appointment_date} at {appointment_time} with Dr. {doctor_name}. '
        'Call {clinic_phone} if you need to change it.',
    variables: [
      'patient_name',
      'clinic_name',
      'appointment_date',
      'appointment_time',
      'doctor_name',
      'clinic_phone',
    ],
    description: 'Sent immediately after an appointment is booked.',
  ),
  MessageTemplate(
    code: 'APPT_REMINDER_24H',
    channel: MessageChannel.whatsapp,
    category: MessageCategory.utility,
    body:
        'Reminder: {patient_name} has an appointment at {clinic_name} '
        'tomorrow, {appointment_date} at {appointment_time} with '
        'Dr. {doctor_name}. Reply 1 to confirm, or call {clinic_phone} to '
        'reschedule.',
    variables: [
      'patient_name',
      'clinic_name',
      'appointment_date',
      'appointment_time',
      'doctor_name',
      'clinic_phone',
    ],
    description: 'Sent 24 hours before the slot; a reply of 1 confirms it.',
  ),
  MessageTemplate(
    code: 'APPT_REMINDER_MORNING',
    channel: MessageChannel.whatsapp,
    category: MessageCategory.utility,
    body:
        'Good morning {patient_name}, this is a reminder of your appointment '
        'today at {appointment_time} at {clinic_name} with Dr. {doctor_name}. '
        'Reply 1 to confirm. Running late? Call {clinic_phone}.',
    variables: [
      'patient_name',
      'appointment_time',
      'clinic_name',
      'doctor_name',
      'clinic_phone',
    ],
    description:
        'Sent on the morning of the appointment; a reply of 1 confirms it.',
  ),
  MessageTemplate(
    code: 'APPT_RESCHEDULED',
    channel: MessageChannel.whatsapp,
    category: MessageCategory.utility,
    body:
        'Hi {patient_name}, your appointment at {clinic_name} has been moved '
        'to {appointment_date} at {appointment_time} with Dr. {doctor_name}. '
        'Call {clinic_phone} if this does not suit you.',
    variables: [
      'patient_name',
      'clinic_name',
      'appointment_date',
      'appointment_time',
      'doctor_name',
      'clinic_phone',
    ],
    description: 'Sent when the clinic or patient moves an appointment.',
  ),
  MessageTemplate(
    code: 'APPT_CANCELLED',
    channel: MessageChannel.whatsapp,
    category: MessageCategory.utility,
    body:
        'Hi {patient_name}, your appointment at {clinic_name} on '
        '{appointment_date} at {appointment_time} has been cancelled. To book '
        'again, call {clinic_phone}.',
    variables: [
      'patient_name',
      'clinic_name',
      'appointment_date',
      'appointment_time',
      'clinic_phone',
    ],
    description: 'Sent when an appointment is cancelled.',
  ),
];

/// Document-link templates: invoice, receipt, prescription, estimate, consent.
const List<MessageTemplate> documentLinkTemplates = [
  MessageTemplate(
    code: 'INVOICE_LINK',
    channel: MessageChannel.whatsapp,
    category: MessageCategory.utility,
    body:
        'Hi {patient_name}, your invoice {document_number} from {clinic_name} '
        'for {amount} is ready: {link}. You can pay by UPI from the link or at '
        'the clinic. Questions? Call {clinic_phone}.',
    variables: [
      'patient_name',
      'document_number',
      'clinic_name',
      'amount',
      'link',
      'clinic_phone',
    ],
    description: 'Sent when an invoice is issued.',
  ),
  MessageTemplate(
    code: 'RECEIPT_LINK',
    channel: MessageChannel.whatsapp,
    category: MessageCategory.utility,
    body:
        'Hi {patient_name}, {clinic_name} has received your payment of '
        '{amount} on {payment_date}. Your receipt {document_number} is here: '
        '{link}. Thank you.',
    variables: [
      'patient_name',
      'clinic_name',
      'amount',
      'payment_date',
      'document_number',
      'link',
    ],
    description: 'Sent when a payment is recorded.',
  ),
  MessageTemplate(
    code: 'PRESCRIPTION_LINK',
    channel: MessageChannel.whatsapp,
    category: MessageCategory.utility,
    body:
        'Hi {patient_name}, Dr. {doctor_name} at {clinic_name} has issued '
        'your prescription. View it securely here: {link}.',
    variables: ['patient_name', 'doctor_name', 'clinic_name', 'link'],
    description: 'Sent when a prescription is signed; no drug names in body.',
  ),
  MessageTemplate(
    code: 'ESTIMATE_LINK',
    channel: MessageChannel.whatsapp,
    category: MessageCategory.utility,
    body:
        'Hi {patient_name}, your treatment estimate {document_number} from '
        '{clinic_name} is ready to review: {link}. Call {clinic_phone} to '
        'discuss it.',
    variables: [
      'patient_name',
      'document_number',
      'clinic_name',
      'link',
      'clinic_phone',
    ],
    description: 'Sent when an estimate is issued or revised.',
  ),
  MessageTemplate(
    code: 'CONSENT_LINK',
    channel: MessageChannel.whatsapp,
    category: MessageCategory.utility,
    body:
        'Hi {patient_name}, {clinic_name} needs your consent for '
        '{procedure_name} before treatment. Please read and sign securely '
        'here: {link}.',
    variables: ['patient_name', 'clinic_name', 'procedure_name', 'link'],
    description: 'Sent to collect an e-signed procedure consent remotely.',
  ),
];

/// Follow-up templates: recall, incomplete treatment, lab-ready, review.
const List<MessageTemplate> followUpTemplates = [
  MessageTemplate(
    code: 'RECALL_DUE',
    channel: MessageChannel.whatsapp,
    category: MessageCategory.utility,
    body:
        'Hi {patient_name}, your {recall_type} visit at {clinic_name} is due '
        'on {due_date}. Book a slot here: {link} or call {clinic_phone}.',
    variables: [
      'patient_name',
      'recall_type',
      'clinic_name',
      'due_date',
      'link',
      'clinic_phone',
    ],
    description:
        'Care-plan recall the patient agreed to at the visit; utility, not '
        'marketing.',
  ),
  MessageTemplate(
    code: 'RECALL_OVERDUE',
    channel: MessageChannel.whatsapp,
    category: MessageCategory.utility,
    body:
        'Hi {patient_name}, your {recall_type} visit at {clinic_name} was due '
        'on {due_date} and is still open. Book a slot here: {link} or call '
        '{clinic_phone}.',
    variables: [
      'patient_name',
      'recall_type',
      'clinic_name',
      'due_date',
      'link',
      'clinic_phone',
    ],
    description: 'Second notice for an agreed recall that has passed its date.',
  ),
  MessageTemplate(
    code: 'TREATMENT_INCOMPLETE',
    channel: MessageChannel.whatsapp,
    category: MessageCategory.utility,
    body:
        'Hi {patient_name}, your {procedure_name} at {clinic_name} started on '
        '{started_date} is not yet complete. The next step is {next_step}. '
        'Book here: {link} or call {clinic_phone}.',
    variables: [
      'patient_name',
      'procedure_name',
      'clinic_name',
      'started_date',
      'next_step',
      'link',
      'clinic_phone',
    ],
    description:
        'Nudge for a multi-sitting procedure left open, e.g. a root canal '
        'treatment without its crown.',
  ),
  MessageTemplate(
    code: 'LAB_READY_SEAT_APPT',
    channel: MessageChannel.whatsapp,
    category: MessageCategory.utility,
    body:
        'Hi {patient_name}, your {lab_item} has arrived at {clinic_name} and '
        'is ready to fit. Book your appointment here: {link} or call '
        '{clinic_phone}.',
    variables: [
      'patient_name',
      'lab_item',
      'clinic_name',
      'link',
      'clinic_phone',
    ],
    description: 'Sent when a lab case passes quality check.',
  ),
  MessageTemplate(
    code: 'REVIEW_REQUEST',
    channel: MessageChannel.whatsapp,
    category: MessageCategory.utility,
    body:
        'Hi {patient_name}, thank you for visiting {clinic_name} on '
        '{visit_date}. We would value a minute of your feedback: {link}.',
    variables: ['patient_name', 'clinic_name', 'visit_date', 'link'],
    description:
        'Feedback request about a specific visit, sent to every patient '
        'uniformly with no sentiment gating.',
  ),
];

/// Authentication and onboarding templates.
const List<MessageTemplate> accountTemplates = [
  MessageTemplate(
    code: 'OTP_AUTH',
    channel: MessageChannel.whatsapp,
    category: MessageCategory.authentication,
    body:
        '{otp} is your {clinic_name} verification code. It expires in '
        '{expiry_minutes} minutes. Do not share it with anyone.',
    variables: ['otp', 'clinic_name', 'expiry_minutes'],
    description: 'One-time code for signing a consent or opening a link.',
  ),
  MessageTemplate(
    code: 'OTP_AUTH_SMS',
    channel: MessageChannel.sms,
    category: MessageCategory.authentication,
    body:
        '{otp} is your {clinic_name} verification code. It expires in '
        '{expiry_minutes} minutes. Do not share it with anyone.',
    variables: ['otp', 'clinic_name', 'expiry_minutes'],
    description: 'SMS fallback for the one-time code (DLT-registered text).',
  ),
  MessageTemplate(
    code: 'WELCOME_NEW_PATIENT',
    channel: MessageChannel.whatsapp,
    category: MessageCategory.utility,
    body:
        'Welcome to {clinic_name}, {patient_name}. Your patient number is '
        '{patient_number}. Save this number for appointment updates. Our '
        'privacy notice is here: {link}. Call {clinic_phone} anytime.',
    variables: [
      'clinic_name',
      'patient_name',
      'patient_number',
      'link',
      'clinic_phone',
    ],
    description: 'Sent once when a patient record is created.',
  ),
];

/// Every default English template, in catalogue order.
const List<MessageTemplate> defaultTemplates = [
  ...appointmentTemplates,
  ...postOpTemplates,
  ...documentLinkTemplates,
  ...followUpTemplates,
  ...accountTemplates,
];

/// Looks a default template up by [code] (and optional [languageCode]).
MessageTemplate? templateByCode(String code, {String languageCode = 'en'}) {
  for (final t in defaultTemplates) {
    if (t.code == code && t.languageCode == languageCode) return t;
  }
  return null;
}

/// Default templates approved under [category].
List<MessageTemplate> templatesInCategory(MessageCategory category) =>
    defaultTemplates.where((t) => t.category == category).toList();

/// Default templates approved for [channel].
List<MessageTemplate> templatesForChannel(MessageChannel channel) =>
    defaultTemplates.where((t) => t.channel == channel).toList();
