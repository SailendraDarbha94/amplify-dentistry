import 'dart:io';

import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../notes_providers.dart';
import 'photo_capture_page.dart';
import 'photo_detail_sheet.dart';

/// A pre-operative photo and the latest later photo of the same tooth.
@immutable
class BeforeAfterPair {
  /// Creates the pair.
  const BeforeAfterPair({
    required this.tooth,
    required this.before,
    required this.after,
  });

  /// Shared tooth.
  final ToothId tooth;

  /// Earliest pre-operative image tagged with [tooth].
  final ImageRecord before;

  /// Latest non-pre-operative image tagged with [tooth], captured after
  /// [before].
  final ImageRecord after;
}

/// Pairs photos by tooth: for each tooth with a pre-operative image, the
/// earliest pre-op image is matched to the latest later non-pre-op image.
/// Radiographs pair only with radiographs and photos with photos.
List<BeforeAfterPair> pairPhotos(Iterable<ImageRecord> images) {
  final pairs = <BeforeAfterPair>[];
  final teeth = <ToothId>{for (final i in images) ...i.teeth}.toList()..sort();
  for (final tooth in teeth) {
    for (final radiograph in [false, true]) {
      final tagged = images
          .where(
            (i) => i.teeth.contains(tooth) && i.kind.isRadiograph == radiograph,
          )
          .toList();
      final befores = tagged.where((i) => i.isPreOperative).toList()
        ..sort((a, b) => a.capturedAt.compareTo(b.capturedAt));
      if (befores.isEmpty) continue;
      final before = befores.first;
      final afters =
          tagged
              .where(
                (i) =>
                    !i.isPreOperative &&
                    i.capturedAt.isAfter(before.capturedAt),
              )
              .toList()
            ..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
      if (afters.isEmpty) continue;
      pairs.add(
        BeforeAfterPair(tooth: tooth, before: before, after: afters.first),
      );
    }
  }
  return pairs;
}

/// Thumbnail of a stored image; falls back to a placeholder while resolving
/// or when the file is missing.
class PhotoThumb extends ConsumerWidget {
  /// Creates the thumbnail.
  const PhotoThumb({super.key, required this.image, this.onTap});

  /// Record to show.
  final ImageRecord image;

  /// Tap handler.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = ref.watch(imageFilePathProvider(image.filePath)).value;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: AppRadii.smAll,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('photo-${image.id}'),
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (path != null)
              Image.file(
                File(path),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Icon(
                  image.kind.isRadiograph
                      ? Icons.blur_on
                      : Icons.image_outlined,
                  size: 40,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            Positioned(
              left: 4,
              bottom: 4,
              right: 4,
              child: Wrap(
                spacing: 4,
                children: [
                  StatusBadge(label: imageKindLabel(image.kind), dense: true),
                  if (image.isPreOperative)
                    const StatusBadge(
                      label: 'Pre-op',
                      tone: BadgeTone.info,
                      dense: true,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Gallery tab: before/after pairs by tooth, then every image newest first.
class PhotoGallery extends ConsumerWidget {
  /// Creates the gallery for [patientId].
  const PhotoGallery({super.key, required this.patientId});

  /// Patient.
  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final images = ref.watch(patientImagesProvider(patientId));
    final notation = ref.watch(notationProvider);
    return images.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(message: '$e'),
      data: (list) {
        if (list.isEmpty) {
          return const EmptyState(
            icon: Icons.photo_camera_outlined,
            title: 'No photos yet',
            message:
                'Capture intraoral photos and radiographs, tag the '
                'teeth and mark pre-operative shots to build before/after '
                'pairs.',
          );
        }
        final pairs = pairPhotos(list);
        void open(ImageRecord image) =>
            PhotoDetailSheet.show(context, patientId: patientId, image: image);
        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.md,
            AppSpacing.gutter,
            96,
          ),
          children: [
            if (pairs.isNotEmpty) ...[
              Text(
                'Before / after',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final p in pairs)
                Padding(
                  key: ValueKey(
                    'pair-${p.tooth.storageKey}-${p.before.kind.isRadiograph}',
                  ),
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tooth ${notation.formatPlain(p.tooth)}  ·  '
                        '${AppFormat.date(p.before.capturedAt)} → '
                        '${AppFormat.date(p.after.capturedAt)}',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      SizedBox(
                        height: 140,
                        child: Row(
                          children: [
                            Expanded(
                              child: PhotoThumb(
                                image: p.before,
                                onTap: () => open(p.before),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(Icons.arrow_forward),
                            ),
                            Expanded(
                              child: PhotoThumb(
                                image: p.after,
                                onTap: () => open(p.after),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const Divider(),
            ],
            Text(
              'All images (${list.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 160,
                mainAxisSpacing: AppSpacing.sm,
                crossAxisSpacing: AppSpacing.sm,
              ),
              itemCount: list.length,
              itemBuilder: (context, i) =>
                  PhotoThumb(image: list[i], onTap: () => open(list[i])),
            ),
          ],
        );
      },
    );
  }
}
