import 'dart:io';

import 'package:ampdent_core/ampdent_core.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Captures or picks a photo of a licence document and copies it into the
/// app's documents directory (`licences/<licenceId>-<timestamp>.<ext>`).
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

  /// Copies [file] into the licences folder and returns the new path.
  Future<String> store(XFile file, {required String licenceId}) async {
    final base = await _baseDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}licences');
    await dir.create(recursive: true);
    final ext = _extensionOf(file.name.isEmpty ? file.path : file.name);
    final stamp = clock().toUtc().millisecondsSinceEpoch;
    final target = '${dir.path}${Platform.pathSeparator}$licenceId-$stamp$ext';
    await file.saveTo(target);
    return target;
  }

  static String _extensionOf(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return '.jpg';
    final ext = name.substring(dot).toLowerCase();
    return ext.length > 5 ? '.jpg' : ext;
  }
}
