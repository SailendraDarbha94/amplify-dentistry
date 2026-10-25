import 'dart:io';

import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/stored_file_path.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Captures or picks a photo of a licence document and copies it into the
/// app's documents directory. The licence row stores the store-relative
/// path (`licences/<licenceId>-<timestamp>.<ext>`), resolved against the
/// documents directory at read time so the scan survives an app-container
/// move; absolute paths from earlier builds are re-rooted by [resolve].
class LicenceDocumentStore {
  /// Creates the store. [picker] and [baseDirectory] are injectable for
  /// tests.
  LicenceDocumentStore({
    ImagePicker? picker,
    Future<Directory> Function()? baseDirectory,
    this.clock = DateTime.now,
  }) : _picker = picker ?? ImagePicker(),
       _baseDirectory = baseDirectory ?? getApplicationDocumentsDirectory;

  final ImagePicker _picker;
  final Future<Directory> Function() _baseDirectory;

  /// Clock for file names.
  final DateTime Function() clock;

  static const Logger _log = Logger('licence-documents');

  /// Opens the camera or gallery and stores the chosen image. Returns the
  /// stored path, or null when the user cancelled.
  Future<String?> pickAndStore(
    ImageSource source, {
    required String licenceId,
  }) async {
    final XFile? picked;
    try {
      picked = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 2000,
      );
    } on Object catch (e) {
      _log.warning('image pick failed', error: e);
      return null;
    }
    if (picked == null) return null;
    return store(picked, licenceId: licenceId);
  }

  /// Store-relative path for a licence document.
  static String relativePath(String licenceId, int stamp, String ext) =>
      'licences/$licenceId-$stamp$ext';

  /// Absolute file for a stored path (relative or legacy absolute).
  Future<File> resolve(String path) =>
      resolveStoredFile(path, root: _baseDirectory, folder: 'licences');

  /// Copies [file] into the licences folder and returns the store-relative
  /// path.
  Future<String> store(XFile file, {required String licenceId}) async {
    final ext = _extensionOf(file.name.isEmpty ? file.path : file.name);
    final stamp = clock().toUtc().millisecondsSinceEpoch;
    final rel = relativePath(licenceId, stamp, ext);
    final target = await resolve(rel);
    await target.parent.create(recursive: true);
    await file.saveTo(target.path);
    return rel;
  }

  static String _extensionOf(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return '.jpg';
    final ext = name.substring(dot).toLowerCase();
    return ext.length > 5 ? '.jpg' : ext;
  }
}
