import 'dart:typed_data';

import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_documents/ampdent_documents.dart';

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

/// Variables for the `PRESCRIPTION_LINK` template: who issued it and the
/// authenticated link, never a drug name. Sent through `PatientMessenger`,
/// which applies the opt-in policy, routes minors to the guardian and marks
/// the message log row sent or cancelled.
Map<String, String> prescriptionLinkVariables({
  required ClinicMember dentist,
  required Clinic clinic,
  required Patient patient,
  required Prescription prescription,
}) => {
  'patient_name': patient.firstName,
  'doctor_name': dentist.displayName,
  'clinic_name': clinic.name,
  'link': prescriptionLink(prescription),
};
