import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

/// Asset-key prefix under which this package's fonts are bundled.
const String documentFontAssetPrefix =
    'packages/ampdent_documents/assets/fonts';

/// File names of the bundled Noto fonts.
abstract final class DocumentFontFiles {
  /// Noto Sans Regular (Latin, Greek, Cyrillic; includes U+20B9 rupee sign).
  static const String regular = 'NotoSans-Regular.ttf';

  /// Noto Sans Bold.
  static const String bold = 'NotoSans-Bold.ttf';

  /// Noto Sans Devanagari Regular (Hindi fallback).
  static const String devanagari = 'NotoSansDevanagari-Regular.ttf';

  /// Noto Sans Telugu Regular (Telugu fallback).
  static const String telugu = 'NotoSansTelugu-Regular.ttf';
}

/// The TrueType fonts every document is rendered with. Load once per app
/// session with [load] and share the instance across builders.
class DocumentFonts {
  /// Creates a font set from already-parsed PDF fonts.
  const DocumentFonts({
    required this.regular,
    required this.bold,
    this.devanagari,
    this.telugu,
  });

  /// Reads the TTF files directly from [directory] (for tests and CLI tools
  /// that have no Flutter asset bundle). Devanagari and Telugu are optional
  /// and skipped when their file is missing.
  factory DocumentFonts.fromFiles(Directory directory) {
    pw.Font read(String name) => pw.Font.ttf(
      _byteData(File('${directory.path}/$name').readAsBytesSync()),
    );
    pw.Font? readOptional(String name) {
      final file = File('${directory.path}/$name');
      return file.existsSync()
          ? pw.Font.ttf(_byteData(file.readAsBytesSync()))
          : null;
    }

    return DocumentFonts(
      regular: read(DocumentFontFiles.regular),
      bold: read(DocumentFontFiles.bold),
      devanagari: readOptional(DocumentFontFiles.devanagari),
      telugu: readOptional(DocumentFontFiles.telugu),
    );
  }

  /// Loads the bundled fonts through the Flutter asset bundle.
  static Future<DocumentFonts> load() async {
    Future<pw.Font> read(String name) async =>
        pw.Font.ttf(await rootBundle.load('$documentFontAssetPrefix/$name'));
    Future<pw.Font?> readOptional(String name) async {
      try {
        return await read(name);
      } on Object {
        return null;
      }
    }

    return DocumentFonts(
      regular: await read(DocumentFontFiles.regular),
      bold: await read(DocumentFontFiles.bold),
      devanagari: await readOptional(DocumentFontFiles.devanagari),
      telugu: await readOptional(DocumentFontFiles.telugu),
    );
  }

  /// Body font.
  final pw.Font regular;

  /// Bold font for titles, headers and totals.
  final pw.Font bold;

  /// Devanagari fallback, when bundled.
  final pw.Font? devanagari;

  /// Telugu fallback, when bundled.
  final pw.Font? telugu;

  /// Script fallbacks applied after [regular] / [bold].
  List<pw.Font> get fallback => [?devanagari, ?telugu];

  /// A `pdf` theme with these fonts installed and [baseSize] point body text.
  pw.ThemeData themeData({double baseSize = 9}) {
    final base = pw.ThemeData.withFont(
      base: regular,
      bold: bold,
      italic: regular,
      boldItalic: bold,
      fontFallback: fallback,
    );
    return base.copyWith(
      defaultTextStyle: base.defaultTextStyle.copyWith(fontSize: baseSize),
    );
  }

  static ByteData _byteData(Uint8List bytes) => ByteData.sublistView(bytes);
}
