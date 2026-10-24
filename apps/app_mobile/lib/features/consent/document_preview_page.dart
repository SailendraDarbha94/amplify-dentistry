import 'dart:typed_data';

import 'package:ampdent_documents/ampdent_documents.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

/// Renders a PDF with the embedded document fonts and shows it with the
/// platform print and share actions. [render] receives the loaded fonts and
/// returns the PDF bytes; it runs once per preview.
class DocumentPreviewPage extends ConsumerWidget {
  /// Creates the preview.
  const DocumentPreviewPage({
    super.key,
    required this.title,
    required this.fileName,
    required this.render,
    this.actions = const [],
    this.footer,
  });

  /// App bar title.
  final String title;

  /// File name used when sharing.
  final String fileName;

  /// Builds the PDF bytes from the loaded fonts.
  final Future<Uint8List> Function(DocumentFonts fonts) render;

  /// Extra app bar actions (for example a WhatsApp send button).
  final List<Widget> actions;

  /// Optional widget pinned under the preview (hints, send buttons).
  final Widget? footer;

  /// Pushes a preview on the root navigator so it covers the bottom bar.
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String fileName,
    required Future<Uint8List> Function(DocumentFonts fonts) render,
    List<Widget> actions = const [],
    Widget? footer,
  }) => Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      builder: (_) => DocumentPreviewPage(
        title: title,
        fileName: fileName,
        render: render,
        actions: actions,
        footer: footer,
      ),
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fonts = ref.watch(documentFontsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: fonts.when(
        loading: () => Center(child: Text(context.strings.loading)),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(documentFontsProvider),
        ),
        data: (f) => Column(
          children: [
            Expanded(
              child: PdfPreview(
                build: (_) => render(f),
                pdfFileName: fileName,
                canChangePageFormat: false,
                canChangeOrientation: false,
                canDebug: false,
                allowPrinting: true,
                allowSharing: true,
              ),
            ),
            ?footer,
          ],
        ),
      ),
    );
  }
}
