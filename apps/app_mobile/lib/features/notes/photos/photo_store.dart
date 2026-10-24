import 'dart:io';

import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_data/ampdent_data.dart';
import 'package:ampdent_documents/ampdent_documents.dart' show sha256Hex;
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

/// Writes a compressed copy of [source] at [targetPath] and returns it.
typedef PhotoCompressor = Future<File> Function(File source, String targetPath);

/// Result of storing a photo file.
@immutable
class StoredPhoto {
  /// Creates the result.
  const StoredPhoto({
    required this.filePath,
    required this.sha256,
    required this.bytes,
  });

  /// Store-relative path (`clinics/<clinicId>/patients/<patientId>/images/<id>.jpg`).
  final String filePath;

  /// Hex SHA-256 of the stored bytes.
  final String sha256;

  /// Stored size in bytes.
  final int bytes;
}

/// File storage for clinical photos. Paths handed out are relative to the
/// store root so the record survives an app-container move.
abstract class PhotoStore {
  /// Compresses and stores [source] for a patient; returns the relative path
  /// and hash.
  Future<StoredPhoto> save(
    File source, {
    required String clinicId,
    required String patientId,
    required String imageId,
  });

  /// Absolute file for a stored path.
  Future<File> resolve(String filePath);
}

/// The app documents directory (default store root on device).
Future<Directory> applicationDocumentsRoot() =>
    getApplicationDocumentsDirectory();

/// JPEG compression that keeps EXIF (capture time, orientation); falls back
/// to a plain copy when the native compressor is unavailable (tests,
/// unsupported formats).
Future<File> compressKeepingExif(File source, String targetPath) async {
  try {
    final result = await FlutterImageCompress.compressAndGetFile(
      source.path,
      targetPath,
      quality: 82,
      minWidth: 2048,
      minHeight: 2048,
      keepExif: true,
    );
    if (result != null) return File(result.path);
  } on Object catch (e) {
    const Logger('photos').warning('compression failed, copying: $e');
  }
  return copyUncompressed(source, targetPath);
}

/// Stores the file byte for byte.
Future<File> copyUncompressed(File source, String targetPath) =>
    source.copy(targetPath);

/// Store rooted at a directory (the app documents directory on device, a
/// temp directory in tests).
class LocalPhotoStore implements PhotoStore {
  /// Creates the store; [compressor] defaults to [compressKeepingExif].
  LocalPhotoStore({required this.root, PhotoCompressor? compressor})
    : compressor = compressor ?? compressKeepingExif;

  /// Supplies the root directory.
  final Future<Directory> Function() root;

  /// Compression step.
  final PhotoCompressor compressor;

  /// Relative path for an image id.
  static String relativePath(
    String clinicId,
    String patientId,
    String imageId,
  ) => 'clinics/$clinicId/patients/$patientId/images/$imageId.jpg';

  @override
  Future<StoredPhoto> save(
    File source, {
    required String clinicId,
    required String patientId,
    required String imageId,
  }) async {
    final rel = relativePath(clinicId, patientId, imageId);
    final target = await resolve(rel);
    await target.parent.create(recursive: true);
    final stored = await compressor(source, target.path);
    final bytes = await stored.readAsBytes();
    return StoredPhoto(
      filePath: rel,
      sha256: sha256Hex(bytes),
      bytes: bytes.length,
    );
  }

  @override
  Future<File> resolve(String filePath) async {
    if (filePath.startsWith('/')) return File(filePath);
    final dir = await root();
    return File('${dir.path}/$filePath');
  }
}

/// Stores a picked file and writes its [ImageRecord] with tooth tags, kind,
/// pre-operative flag and procedure link.
class PhotoSaver {
  /// Creates the saver.
  const PhotoSaver({
    required this.store,
    required this.clinical,
    required this.ctx,
  });

  /// File store.
  final PhotoStore store;

  /// Image records live here.
  final ClinicalRepository clinical;

  /// Actor for the write.
  final ActorContext ctx;

  /// Stores [source] and records it; returns the saved record.
  Future<ImageRecord> save({
    required File source,
    required String patientId,
    required ImageKind kind,
    List<ToothId> teeth = const [],
    bool isPreOperative = false,
    String? procedureId,
    String? visitId,
    String? note,
    DateTime? capturedAt,
    DateTime? now,
  }) async {
    final id = newId();
    final at = (now ?? DateTime.now()).toUtc();
    final stored = await store.save(
      source,
      clinicId: ctx.clinicId,
      patientId: patientId,
      imageId: id,
    );
    final sorted = [...teeth]..sort();
    return clinical.addImage(
      ctx,
      ImageRecord(
        id: id,
        clinicId: ctx.clinicId,
        patientId: patientId,
        visitId: visitId,
        kind: kind,
        filePath: stored.filePath,
        capturedAt: (capturedAt ?? at).toUtc(),
        teeth: sorted,
        isPreOperative: isPreOperative,
        procedureId: procedureId,
        note: note == null || note.trim().isEmpty ? null : note.trim(),
        sha256: stored.sha256,
        createdAt: at,
      ),
    );
  }
}
