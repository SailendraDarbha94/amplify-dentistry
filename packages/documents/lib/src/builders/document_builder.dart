import 'dart:typed_data';

import 'package:ampdent_core/ampdent_core.dart';
import 'package:pdf/widgets.dart' as pw;

import '../theme/document_theme.dart';

/// Base for every PDF builder. Subclasses describe their pages through
/// [buildPages]; the base turns them into a [pw.Document] (cached, so the
/// same builder can be inspected, composed and saved) and into bytes.
///
/// To compose several documents into one file, call [buildPages] on each
/// builder and add the pages to your own [pw.Document].
abstract class DocumentBuilder {
  /// Creates a builder for [clinic] rendered with [theme].
  DocumentBuilder({required this.clinic, required this.theme, this.dentist});

  /// The clinic whose letterhead is printed.
  final Clinic clinic;

  /// The dentist named on the document (registration line); null only for
  /// documents that are not signed by one clinician (record copies).
  final ClinicMember? dentist;

  /// Who is printed in the letterhead and the signature box: [dentist] by
  /// default. Builders whose row freezes the clinician (invoices) override
  /// this so a reprint never depends on the device's current member.
  Signatory? get signatory =>
      dentist == null ? null : Signatory.member(dentist!);

  /// Page chrome and fonts.
  final DocumentTheme theme;

  pw.Document? _document;

  /// Document title printed under the letterhead, e.g. `TAX INVOICE`.
  String get title;

  /// Optional subtitle on the right of the title (document number, date).
  String? get subtitle => null;

  /// Hex SHA-256 of the content model, stamped in the footer.
  String get documentHash;

  /// Short footer note (left of the page number).
  String? get footerNote => null;

  /// Watermark text, e.g. `DRAFT`; null for none.
  String? get watermark => null;

  /// File name suggested when sharing or saving.
  String get suggestedFileName;

  /// PDF metadata subject.
  String get subject => title;

  /// Body widgets laid out across pages by [pw.MultiPage].
  List<pw.Widget> buildBody(pw.Context context);

  /// The pages of this document (one multi-page flow by default). Override to
  /// add extra pages.
  List<pw.Page> buildPages() => [
    pw.MultiPage(
      pageTheme: theme.pageTheme(watermark: watermark),
      header: (context) => theme.header(
        context,
        clinic: clinic,
        dentist: signatory,
        title: title,
        subtitle: subtitle,
      ),
      footer: (context) =>
          theme.footer(context, documentHash: documentHash, note: footerNote),
      build: buildBody,
      maxPages: 200,
    ),
  ];

  /// The composed document; built on first access and cached.
  pw.Document get document {
    final existing = _document;
    if (existing != null) return existing;
    final who = signatory;
    final doc = pw.Document(
      title: title,
      author: who == null
          ? clinic.name
          : '${theme.signatoryNameLine(who)}, ${clinic.name}',
      creator: theme.appName,
      producer: theme.appName,
      subject: subject,
    );
    for (final page in buildPages()) {
      doc.addPage(page);
    }
    _document = doc;
    return doc;
  }

  /// Renders the document and returns the PDF bytes.
  Future<Uint8List> build() => document.save();

  /// Number of pages after composition (forces composition).
  int get pageCount => document.document.pdfPageList.pages.length;

  /// Tooth display notation for this clinic.
  ToothNotation get notation => clinic.defaultNotation;
}
