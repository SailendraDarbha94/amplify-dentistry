import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_mobile/features/notes/notes_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'export_service.dart';

/// The export service wired to the real repositories, embedded fonts, the
/// photo store (image paths are store-relative), the temp directory and the
/// system share sheet.
final Provider<ExportService> exportServiceProvider = Provider<ExportService>(
  (ref) => ExportService(
    export: ref.watch(exportRepositoryProvider),
    clinics: ref.watch(clinicRepositoryProvider),
    loadFonts: () => ref.read(documentFontsProvider.future),
    outputDirectory: getTemporaryDirectory,
    share: shareWithSharePlus,
    resolveImage: ref.watch(photoStoreProvider).resolve,
    clock: ref.watch(clockProvider),
  ),
);
