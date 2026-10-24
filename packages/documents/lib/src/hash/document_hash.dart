/// Document hashing.
///
/// Design choice: the hash printed in a document footer is the SHA-256 of the
/// **content model** (the canonical JSON of the entity being printed), not of
/// the PDF bytes. Hashing the bytes would need two render passes and would
/// still change whenever the fonts, layout or generation timestamp change,
/// while the content hash stays identical for the same record however it is
/// re-rendered, which is what an audit needs: the hash binds the printout to
/// the stored row. [sha256Hex] is still provided for callers that want to
/// fingerprint the final bytes (for example when storing `pdfPath`).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Lowercase hex SHA-256 of raw bytes (for fingerprinting a saved PDF).
String sha256Hex(Uint8List bytes) => sha256.convert(bytes).toString();

/// Lowercase hex SHA-256 of a UTF-8 string.
String sha256HexOfString(String text) =>
    sha256.convert(utf8.encode(text)).toString();

/// Serialises [json] canonically: map keys sorted recursively, no whitespace,
/// so two structurally equal models produce byte-identical text.
String canonicalJson(Object? json) => jsonEncode(_canonical(json));

Object? _canonical(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((k) => k.toString()).toList()..sort();
    return {for (final k in keys) k: _canonical(value[k])};
  }
  if (value is Iterable) return value.map(_canonical).toList();
  return value;
}

/// SHA-256 (hex) of the canonical JSON of an entity's `toJson()` output. This
/// is the value stamped in document footers.
String documentContentHash(Map<String, Object?> json) =>
    sha256HexOfString(canonicalJson(json));

/// First [length] hex characters of a hash, upper-cased, for compact footers.
String shortHash(String hex, {int length = 16}) => hex.length <= length
    ? hex.toUpperCase()
    : hex.substring(0, length).toUpperCase();
