import 'package:ampdent_core/ampdent_core.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../fonts/document_fonts.dart';
import '../hash/document_hash.dart';
import '../text/formatters.dart';

/// Paper size for a document.
enum DocumentPaper {
  /// 210 x 297 mm: invoices, estimates, consents, record copies.
  a4,

  /// 148 x 210 mm: prescriptions and lab slips.
  a5;

  /// The `pdf` page format for this paper.
  PdfPageFormat get pageFormat =>
      this == DocumentPaper.a4 ? PdfPageFormat.a4 : PdfPageFormat.a5;
}

/// Colours and sizes shared by every document.
abstract final class DocumentColors {
  /// Rule and header fill.
  static const PdfColor ink = PdfColor.fromInt(0xFF1F2933);

  /// Secondary text.
  static const PdfColor muted = PdfColor.fromInt(0xFF616E7C);

  /// Table header background.
  static const PdfColor headerFill = PdfColor.fromInt(0xFFE4E7EB);

  /// Alternate row background.
  static const PdfColor zebra = PdfColor.fromInt(0xFFF5F7FA);

  /// Watermark text.
  static const PdfColor watermark = PdfColor.fromInt(0xFFE4E7EB);

  /// Accent used for titles.
  static const PdfColor accent = PdfColor.fromInt(0xFF0B6E99);
}

/// The clinician named on a document: name, qualifications and council
/// registration (DCI Code 3.4.1). Built from a live [ClinicMember] for
/// documents signed now, or from the fields frozen on an issued row
/// (invoice, prescription) so reprints never pick up whoever is operating
/// the device.
class Signatory {
  /// Creates a signatory.
  const Signatory({
    required this.displayName,
    this.qualifications = const [],
    this.registrationNumber,
    this.registrationCouncil,
    this.phone,
  });

  /// From a clinic member.
  Signatory.member(ClinicMember member)
    : displayName = member.displayName,
      qualifications = member.qualifications,
      registrationNumber = member.registrationNumber,
      registrationCouncil = member.registrationCouncil,
      phone = member.phone;

  /// From the dentist frozen on an invoice; null when none was recorded
  /// (a draft that never reached issue).
  static Signatory? invoiceDentist(Invoice invoice) {
    final name = invoice.dentistName;
    if (invoice.dentistId == null || name == null || name.isEmpty) return null;
    return Signatory(
      displayName: name,
      qualifications: invoice.dentistQualifications,
      registrationNumber: invoice.dentistRegistrationNumber,
      registrationCouncil: invoice.dentistRegistrationCouncil,
    );
  }

  /// Name as printed (`Dr. A. Rao`).
  final String displayName;

  /// Degrees.
  final List<String> qualifications;

  /// Council registration number.
  final String? registrationNumber;

  /// Issuing council.
  final String? registrationCouncil;

  /// Contact phone for the letterhead, when known.
  final String? phone;

  /// Whether a registration number is recorded.
  bool get hasRegistration => (registrationNumber ?? '').trim().isNotEmpty;
}

/// Page chrome every document shares: fonts, paper, margins, the clinic
/// letterhead with the dentist's registration line (DCI Code 3.4.1) and the
/// footer with page numbers, generated-at timestamp and content hash.
class DocumentTheme {
  /// Creates a theme. [generatedAt] defaults to now and is printed in footers.
  DocumentTheme({
    required this.fonts,
    this.paper = DocumentPaper.a4,
    DateTime? generatedAt,
    this.appName = 'AmpDent',
  }) : generatedAt = generatedAt ?? DateTime.now();

  /// Fonts used for all text.
  final DocumentFonts fonts;

  /// Paper size.
  final DocumentPaper paper;

  /// Timestamp printed in the footer.
  final DateTime generatedAt;

  /// Software name printed in the footer.
  final String appName;

  /// Base body font size for this paper.
  double get baseFontSize => paper == DocumentPaper.a4 ? 9 : 8;

  /// Page margin for this paper.
  double get margin => paper == DocumentPaper.a4 ? 36 : 24;

  /// Page format.
  PdfPageFormat get pageFormat => paper.pageFormat;

  /// `pdf` theme data with fonts installed.
  pw.ThemeData get themeData => fonts.themeData(baseSize: baseFontSize);

  /// A copy of this theme on different paper.
  DocumentTheme withPaper(DocumentPaper paper) => DocumentTheme(
    fonts: fonts,
    paper: paper,
    generatedAt: generatedAt,
    appName: appName,
  );

  /// Builds the page theme, optionally with a diagonal [watermark] text
  /// (for example `DRAFT`).
  pw.PageTheme pageTheme({String? watermark}) => pw.PageTheme(
    pageFormat: pageFormat,
    margin: pw.EdgeInsets.all(margin),
    theme: themeData,
    buildBackground: watermark == null
        ? null
        : (context) => pw.Watermark.text(
            watermark,
            style: pw.TextStyle(
              color: DocumentColors.watermark,
              fontWeight: pw.FontWeight.bold,
              fontSize: 120,
            ),
          ),
  );

  // ---------------------------------------------------------------------------
  // Text styles
  // ---------------------------------------------------------------------------

  /// Document title (`TAX INVOICE`).
  pw.TextStyle get titleStyle => pw.TextStyle(
    fontSize: baseFontSize + 7,
    fontWeight: pw.FontWeight.bold,
    color: DocumentColors.accent,
    letterSpacing: 1.2,
  );

  /// Clinic name in the letterhead.
  pw.TextStyle get clinicNameStyle => pw.TextStyle(
    fontSize: baseFontSize + 5,
    fontWeight: pw.FontWeight.bold,
    color: DocumentColors.ink,
  );

  /// Section heading.
  pw.TextStyle get sectionStyle => pw.TextStyle(
    fontSize: baseFontSize + 1.5,
    fontWeight: pw.FontWeight.bold,
    color: DocumentColors.ink,
  );

  /// Bold body text.
  pw.TextStyle get boldStyle => pw.TextStyle(fontWeight: pw.FontWeight.bold);

  /// Small grey text.
  pw.TextStyle get mutedStyle =>
      pw.TextStyle(fontSize: baseFontSize - 1.5, color: DocumentColors.muted);

  /// Table header text.
  pw.TextStyle get tableHeaderStyle => pw.TextStyle(
    fontSize: baseFontSize - 1,
    fontWeight: pw.FontWeight.bold,
    color: DocumentColors.ink,
  );

  /// Table body text.
  pw.TextStyle get tableCellStyle => pw.TextStyle(fontSize: baseFontSize - 1);

  // ---------------------------------------------------------------------------
  // Letterhead and footer
  // ---------------------------------------------------------------------------

  /// `Dr. Name, BDS, MDS` for the letterhead.
  String dentistNameLine(ClinicMember dentist) =>
      signatoryNameLine(Signatory.member(dentist));

  /// `Reg. No. <council> <number>` (DCI Code 3.4.1); the council is omitted
  /// when not recorded.
  String registrationLine(ClinicMember dentist) =>
      signatoryRegistrationLine(Signatory.member(dentist));

  /// `Dr. Name, BDS, MDS` for a [Signatory].
  String signatoryNameLine(Signatory who) {
    final name = who.displayName.startsWith('Dr')
        ? who.displayName
        : 'Dr. ${who.displayName}';
    if (who.qualifications.isEmpty) return name;
    return '$name, ${who.qualifications.join(', ')}';
  }

  /// `Reg. No. <council> <number>` for a [Signatory].
  String signatoryRegistrationLine(Signatory who) {
    final number = who.registrationNumber;
    if (number == null || number.isEmpty) return 'Reg. No. not recorded';
    final council = who.registrationCouncil;
    return council == null || council.isEmpty
        ? 'Reg. No. $number'
        : 'Reg. No. $council $number';
  }

  /// Letterhead: clinic name, address, phone, GSTIN on the left; the dentist's
  /// name, qualifications and registration number on the right; then the
  /// document title and optional subtitle. Repeats on every page.
  pw.Widget header(
    pw.Context context, {
    required Clinic clinic,
    Signatory? dentist,
    required String title,
    String? subtitle,
  }) {
    final contact = <String>[
      'Ph: ${clinic.phone}',
      if (clinic.whatsappPhone != null &&
          clinic.whatsappPhone!.isNotEmpty &&
          clinic.whatsappPhone != clinic.phone)
        'WhatsApp: ${clinic.whatsappPhone}',
      if (clinic.email != null && clinic.email!.isNotEmpty) clinic.email!,
    ].join('  |  ');
    final showFull = context.pageNumber == 1;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: 3,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(clinic.name, style: clinicNameStyle),
                  if (showFull &&
                      clinic.legalName != null &&
                      clinic.legalName != clinic.name)
                    pw.Text(clinic.legalName!, style: mutedStyle),
                  if (showFull) pw.Text(formatClinicAddress(clinic)),
                  if (showFull) pw.Text(contact, style: mutedStyle),
                  if (clinic.isGstRegistered)
                    pw.Text('GSTIN: ${clinic.gstin}', style: boldStyle),
                ],
              ),
            ),
            if (dentist != null)
              pw.Expanded(
                flex: 2,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(signatoryNameLine(dentist), style: boldStyle),
                    pw.Text(signatoryRegistrationLine(dentist)),
                    if (showFull && (dentist.phone ?? '').isNotEmpty)
                      pw.Text('Ph: ${dentist.phone}', style: mutedStyle),
                  ],
                ),
              ),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Divider(thickness: 1.2, color: DocumentColors.ink, height: 6),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(title, style: titleStyle),
            if (subtitle != null) pw.Text(subtitle, style: mutedStyle),
          ],
        ),
        pw.SizedBox(height: 6),
      ],
    );
  }

  /// Footer: optional [note] on the left, page `x of y` on the right, then a
  /// line with the generated-at timestamp and the content hash.
  pw.Widget footer(
    pw.Context context, {
    required String documentHash,
    String? note,
  }) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Divider(thickness: 0.6, color: DocumentColors.muted, height: 6),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(child: pw.Text(note ?? '', style: mutedStyle)),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: mutedStyle,
          ),
        ],
      ),
      pw.Text(
        'Generated ${formatDateTime(generatedAt)} by $appName  |  '
        'Document hash SHA-256 ${shortHash(documentHash, length: 32)}',
        style: mutedStyle,
      ),
    ],
  );
}
