/// PDF documents for the AmpDent dental platform: invoice/receipt, estimate,
/// prescription, consent, lab slip and the patient record copy, rendered with
/// the `pdf` package and printed or shared through `printing`.
///
/// Every document carries the clinic letterhead, the dentist's name,
/// qualifications and registration number (DCI Code 3.4.1), page numbers, a
/// generated-at timestamp and a SHA-256 content hash in the footer.
library;

export 'src/builders/consent_pdf.dart';
export 'src/builders/document_builder.dart';
export 'src/builders/estimate_pdf.dart';
export 'src/builders/invoice_gst_summary.dart';
export 'src/builders/invoice_pdf.dart';
export 'src/builders/lab_slip_pdf.dart';
export 'src/builders/patient_record_history.dart';
export 'src/builders/patient_record_pdf.dart';
export 'src/builders/prescription_pdf.dart';
export 'src/fonts/document_fonts.dart';
export 'src/hash/document_hash.dart';
export 'src/print/print_service.dart';
export 'src/text/formatters.dart';
export 'src/text/indian_number_words.dart';
export 'src/theme/document_theme.dart';
export 'src/theme/document_widgets.dart';
