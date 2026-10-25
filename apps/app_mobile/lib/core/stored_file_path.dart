import 'dart:io';

/// Whether [path] is absolute (POSIX or Windows drive form).
bool isAbsoluteStoredPath(String path) =>
    path.startsWith('/') || RegExp(r'^[A-Za-z]:[\\/]').hasMatch(path);

/// Resolves a stored file path against the app's documents directory.
///
/// Records store paths relative to that directory (`clinics/<id>/...`),
/// because on iOS the sandbox container path changes on every app update or
/// reinstall and on Android a backup/restore moves the data directory. An
/// absolute path written by an earlier build is used while it still exists;
/// once its container is gone it is re-rooted by the `<folder>/` tail it
/// carries, so the file written under the old container is found again.
Future<File> resolveStoredFile(
  String path, {
  required Future<Directory> Function() root,
  required String folder,
}) async {
  if (!isAbsoluteStoredPath(path)) {
    final dir = await root();
    return File('${dir.path}/$path');
  }
  final file = File(path);
  if (await file.exists()) return file;
  final normalised = path.replaceAll('\\', '/');
  final index = normalised.indexOf('/$folder/');
  if (index < 0) return file;
  final dir = await root();
  return File('${dir.path}${normalised.substring(index)}');
}
