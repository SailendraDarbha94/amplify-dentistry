import 'dart:io';

import 'package:image_picker/image_picker.dart';

/// Where a photo comes from.
enum PhotoOrigin { camera, gallery }

/// Picks a photo file; the default implementation wraps `image_picker`,
/// tests inject a fake that returns a prepared file.
abstract class PhotoSource {
  /// Returns the picked file, or null when the user cancelled.
  Future<File?> pick(PhotoOrigin origin);
}

/// `image_picker` backed source. Full-resolution capture; compression is the
/// store's job so EXIF survives.
class ImagePickerPhotoSource implements PhotoSource {
  /// Creates the source.
  const ImagePickerPhotoSource();

  @override
  Future<File?> pick(PhotoOrigin origin) async {
    final picked = await ImagePicker().pickImage(
      source: origin == PhotoOrigin.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      requestFullMetadata: true,
    );
    return picked == null ? null : File(picked.path);
  }
}

/// Source that always returns the same file (tests and previews).
class FixedPhotoSource implements PhotoSource {
  /// Creates a source returning [file].
  const FixedPhotoSource(this.file);

  /// The file to return; null simulates a cancelled picker.
  final File? file;

  @override
  Future<File?> pick(PhotoOrigin origin) async => file;
}
