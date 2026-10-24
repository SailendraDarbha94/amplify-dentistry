import 'dart:typed_data';

import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_documents/ampdent_documents.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Everything the lab slip needs besides the case itself.
class LabSlipContext {
  /// Creates the context.
  const LabSlipContext({
    required this.clinic,
    required this.dentist,
    required this.fonts,
    required this.patient,
    required this.lab,
    required this.generatedAt,
  });

  /// Issuing clinic.
  final Clinic clinic;

  /// Authorising dentist (registration number printed).
  final ClinicMember dentist;

  /// Embedded PDF fonts.
  final DocumentFonts fonts;

  /// Patient (name, age and sex only are printed).
  final Patient patient;

  /// Receiving lab.
  final Lab lab;

  /// Timestamp printed in the footer.
  final DateTime generatedAt;

  /// Resolves the context from the app providers; throws when the clinic,
  /// member or fonts are unavailable.
  static Future<LabSlipContext> load(
    WidgetRef ref, {
    required Patient patient,
    required Lab lab,
  }) async => LabSlipContext(
    clinic: await ref.read(currentClinicProvider.future),
    dentist: await ref.read(currentMemberProvider.future),
    fonts: await ref.read(documentFontsProvider.future),
    patient: patient,
    lab: lab,
    generatedAt: ref.read(clockProvider)(),
  );
}

/// Builds the A5 lab work authorisation slip for [labCase].
LabSlipPdf buildLabSlip(LabCase labCase, LabSlipContext c) => LabSlipPdf(
  clinic: c.clinic,
  dentist: c.dentist,
  patient: c.patient,
  labCase: labCase,
  lab: c.lab,
  theme: DocumentTheme(
    fonts: c.fonts,
    generatedAt: c.generatedAt,
  ).withPaper(DocumentPaper.a5),
);

/// Renders and opens the print dialog for the lab slip.
Future<void> printLabSlip(LabCase labCase, LabSlipContext c) async {
  final pdf = buildLabSlip(labCase, c);
  final Uint8List bytes = await pdf.build();
  await printPdf(bytes, name: pdf.suggestedFileName);
}

/// Renders and opens the share sheet for the lab slip (to the lab's
/// WhatsApp, usually).
Future<void> shareLabSlip(LabCase labCase, LabSlipContext c) async {
  final pdf = buildLabSlip(labCase, c);
  final Uint8List bytes = await pdf.build();
  await sharePdf(bytes, filename: pdf.suggestedFileName, subject: pdf.subject);
}
