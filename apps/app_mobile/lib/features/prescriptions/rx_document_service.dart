import 'dart:typed_data';

import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_documents/ampdent_documents.dart';
import 'package:ampdent_messaging/ampdent_messaging.dart';

/// Template code of the WhatsApp message carrying the prescription link.
const String prescriptionLinkTemplateCode = 'PRESCRIPTION_LINK';

/// Authenticated link placeholder for a prescription until the backend
/// serves patient documents: the same `ampdent:rx:<id>:<code>` payload the
/// PDF prints as a QR, so the pharmacist can match the two.
String prescriptionLink(Prescription rx) => prescriptionQrPayload(rx);

/// Renders the prescription PDF on A5 with the prescriber's name,
/// qualifications and registration number from the clinic member.
Future<Uint8List> buildPrescriptionPdf({
  required Clinic clinic,
  required ClinicMember dentist,
  required Patient patient,
  required Prescription prescription,
  required DocumentFonts fonts,
  DateTime? generatedAt,
}) {
  final theme = DocumentTheme(
    fonts: fonts,
    paper: DocumentPaper.a5,
    generatedAt: generatedAt,
  );
  return PrescriptionPdf(
    clinic: clinic,
    dentist: dentist,
    patient: patient,
    prescription: prescription,
    theme: theme,
  ).build();
}

/// Builds the PRESCRIPTION_LINK message for a patient: no drug names in the
/// body, routed to the guardian for minors.
MessageRequest prescriptionLinkRequest({
  required Clinic clinic,
  required ClinicMember dentist,
  required Patient patient,
  required Prescription prescription,
  required DateTime now,
}) {
  final template = templateByCode(prescriptionLinkTemplateCode)!;
  return MessageRequest(
    clinicId: clinic.id,
    patientId: patient.id,
    toPhone: patient.messagingPhone(now),
    template: template,
    variables: {
      'patient_name': patient.firstName,
      'doctor_name': dentist.displayName,
      'clinic_name': clinic.name,
      'link': prescriptionLink(prescription),
    },
  );
}

/// Queues the link message through [messaging] (logged to the message log)
/// and returns the WhatsApp deep link to open.
Future<Uri> sendPrescriptionLink({
  required MessagingProvider messaging,
  required MessageRequest request,
}) async {
  await messaging.send(request);
  return whatsappDeepLink(request.e164Phone, request.render());
}
