import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'document_theme.dart';

/// Small reusable widgets that keep the builders short and consistent.
abstract final class DocumentWidgets {
  /// Section heading with a thin rule underneath.
  static pw.Widget section(DocumentTheme theme, String title) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 10, bottom: 4),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Text(title, style: theme.sectionStyle),
        pw.Divider(thickness: 0.5, color: DocumentColors.muted, height: 4),
      ],
    ),
  );

  /// `Label: value` on one line; skipped when [value] is null or empty.
  static pw.Widget keyValue(DocumentTheme theme, String label, String? value) {
    if (value == null || value.isEmpty) return pw.SizedBox();
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 1.5),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(text: '$label: ', style: theme.boldStyle),
            pw.TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  /// Two-column block of key/value pairs, left and right.
  static pw.Widget infoColumns(
    DocumentTheme theme, {
    required List<MapEntry<String, String?>> left,
    required List<MapEntry<String, String?>> right,
  }) => pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [for (final e in left) keyValue(theme, e.key, e.value)],
        ),
      ),
      pw.SizedBox(width: 12),
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [for (final e in right) keyValue(theme, e.key, e.value)],
        ),
      ),
    ],
  );

  /// Data table with the theme's header fill, zebra rows and compact text.
  /// [rightAligned] column indexes are right-aligned (money, quantities).
  static pw.Widget table(
    DocumentTheme theme, {
    required List<String> headers,
    required List<List<String>> rows,
    Set<int> rightAligned = const {},
    Set<int> centered = const {},
    Map<int, pw.TableColumnWidth>? columnWidths,
  }) {
    final alignments = <int, pw.AlignmentGeometry>{
      for (final i in rightAligned) i: pw.Alignment.centerRight,
      for (final i in centered) i: pw.Alignment.center,
    };
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      headerStyle: theme.tableHeaderStyle,
      headerDecoration: const pw.BoxDecoration(
        color: DocumentColors.headerFill,
      ),
      headerAlignment: pw.Alignment.centerLeft,
      headerAlignments: alignments,
      cellStyle: theme.tableCellStyle,
      cellAlignment: pw.Alignment.centerLeft,
      cellAlignments: alignments,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      oddRowDecoration: const pw.BoxDecoration(color: DocumentColors.zebra),
      border: const pw.TableBorder(
        bottom: pw.BorderSide(color: DocumentColors.muted, width: 0.5),
        horizontalInside: pw.BorderSide(
          color: DocumentColors.headerFill,
          width: 0.4,
        ),
      ),
      columnWidths: columnWidths,
      defaultColumnWidth: const pw.IntrinsicColumnWidth(),
    );
  }

  /// Right-aligned totals block: a list of label/value lines, with the
  /// [emphasisLabels] rows rendered bold.
  static pw.Widget totals(
    DocumentTheme theme,
    List<MapEntry<String, String>> lines, {
    Set<String> emphasisLabels = const {},
    double width = 240,
  }) => pw.Align(
    alignment: pw.Alignment.centerRight,
    child: pw.SizedBox(
      width: width,
      child: pw.Column(
        children: [
          for (final line in lines)
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
              decoration: emphasisLabels.contains(line.key)
                  ? const pw.BoxDecoration(
                      border: pw.Border(
                        top: pw.BorderSide(
                          color: DocumentColors.ink,
                          width: 0.8,
                        ),
                      ),
                    )
                  : null,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    line.key,
                    style: emphasisLabels.contains(line.key)
                        ? theme.boldStyle
                        : null,
                  ),
                  pw.Text(
                    line.value,
                    style: emphasisLabels.contains(line.key)
                        ? theme.boldStyle
                        : null,
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );

  /// Signature box: an empty ruled area (or [image]) with a caption below.
  static pw.Widget signatureBox(
    DocumentTheme theme, {
    required String caption,
    pw.ImageProvider? image,
    List<String> lines = const [],
    double height = 54,
    double width = 170,
  }) => pw.SizedBox(
    width: width,
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          height: height,
          width: width,
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: DocumentColors.ink, width: 0.8),
            ),
          ),
          alignment: pw.Alignment.bottomLeft,
          child: image == null
              ? null
              : pw.Image(image, fit: pw.BoxFit.contain, height: height - 4),
        ),
        pw.SizedBox(height: 2),
        pw.Text(caption, style: theme.boldStyle),
        for (final l in lines) pw.Text(l, style: theme.mutedStyle),
      ],
    ),
  );

  /// A highlighted note box (Rule 46A notice, `Not to be repeated`, etc.).
  static pw.Widget noteBox(DocumentTheme theme, String text) => pw.Container(
    margin: const pw.EdgeInsets.only(top: 6),
    padding: const pw.EdgeInsets.all(6),
    decoration: pw.BoxDecoration(
      color: DocumentColors.zebra,
      border: pw.Border.all(color: DocumentColors.muted, width: 0.5),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
    ),
    child: pw.Text(
      text,
      style: theme.mutedStyle.copyWith(color: DocumentColors.ink),
    ),
  );

  /// Bold inline tag such as `Schedule H1`.
  static pw.Widget tag(DocumentTheme theme, String text) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 1),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: DocumentColors.ink, width: 0.6),
    ),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: theme.baseFontSize - 2,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.black,
      ),
    ),
  );
}
