import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

/// Opens the platform print dialog for already-rendered PDF [bytes].
Future<void> printPdf(Uint8List bytes, {String name = 'Document'}) async {
  await Printing.layoutPdf(onLayout: (_) async => bytes, name: name);
}

/// Opens the platform share sheet for already-rendered PDF [bytes].
Future<void> sharePdf(
  Uint8List bytes, {
  String filename = 'document.pdf',
  String? subject,
}) async {
  await Printing.sharePdf(bytes: bytes, filename: filename, subject: subject);
}

/// Full-screen preview of a PDF with print and share actions. Pass either
/// pre-rendered [bytes] or a [builder] callback that renders for the chosen
/// page format.
class PdfPreviewPage extends StatelessWidget {
  /// Creates a preview page.
  const PdfPreviewPage({
    super.key,
    required this.title,
    this.bytes,
    this.builder,
    this.fileName,
    this.initialPageFormat,
  }) : assert(bytes != null || builder != null, 'Provide bytes or builder');

  /// App bar title.
  final String title;

  /// Pre-rendered PDF bytes.
  final Uint8List? bytes;

  /// Renders the PDF for a page format (used when [bytes] is null).
  final Future<Uint8List> Function(PdfPageFormat format)? builder;

  /// File name used when sharing.
  final String? fileName;

  /// Initial paper size in the preview.
  final PdfPageFormat? initialPageFormat;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: PdfPreview(
      build: (format) async => bytes ?? await builder!(format),
      pdfFileName: fileName,
      initialPageFormat: initialPageFormat,
      canChangePageFormat: false,
      canChangeOrientation: false,
      canDebug: false,
      allowPrinting: true,
      allowSharing: true,
    ),
  );
}
