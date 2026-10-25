import 'dart:io';

import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../notes_providers.dart';
import 'photo_capture_page.dart';
import 'photo_share.dart';

/// Full-size view of one image with its tags and a share action. Sharing
/// requires an active photo-use data consent (DPDP purpose `photoUse`); its
/// id is stored on the image as `sharingConsentId`. Without one the sheet
/// routes to the patient's data-consent toggles instead of sharing.
class PhotoDetailSheet extends ConsumerWidget {
  /// Creates the sheet.
  const PhotoDetailSheet({
    super.key,
    required this.patientId,
    required this.image,
  });

  /// Patient.
  final String patientId;

  /// Image shown.
  final ImageRecord image;

  /// Shows the sheet.
  static Future<void> show(
    BuildContext context, {
    required String patientId,
    required ImageRecord image,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => PhotoDetailSheet(patientId: patientId, image: image),
  );

  Future<void> _share(BuildContext context, WidgetRef ref) async {
    final consent = await photoShareConsent(
      ref.read(consentRepositoryProvider),
      patientId,
    );
    if (!context.mounted) return;
    if (consent == null) {
      final go = await ConfirmSheet.show(
        context,
        title: 'Photo-use consent needed',
        message:
            'Sharing a clinical photo needs the patient\'s consent to the use '
            'of clinical photos (DPDP). Record it on their profile now?',
        confirmLabel: 'Open profile',
        icon: Icons.privacy_tip_outlined,
      );
      if (go && context.mounted) {
        Navigator.of(context).pop();
        await context.push(dataConsentLocation(patientId));
      }
      return;
    }
    final file = await ref.read(photoStoreProvider).resolve(image.filePath);
    if (!context.mounted) return;
    if (!file.existsSync()) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Image file is missing')));
      return;
    }
    await markPhotoShared(
      ref.read(clinicalRepositoryProvider),
      ref.read(actorContextProvider),
      image,
      consent,
    );
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'image/jpeg')],
        subject:
            '${imageKindLabel(image.kind)} ${AppFormat.date(image.capturedAt)}',
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notation = ref.watch(notationProvider);
    final path = ref.watch(imageFilePathProvider(image.filePath)).value;
    final hasConsent =
        ref.watch(photoUseDataConsentProvider(patientId)).value != null;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.9,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              color: Colors.black,
              alignment: Alignment.center,
              child: path == null
                  ? const CircularProgressIndicator()
                  : InteractiveViewer(
                      child: Image.file(
                        File(path),
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white,
                          size: 64,
                        ),
                      ),
                    ),
            ),
          ),
          Padding(
            padding: AppSpacing.screenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    StatusBadge(label: imageKindLabel(image.kind)),
                    if (image.isPreOperative)
                      const StatusBadge(
                        label: 'Pre-operative',
                        tone: BadgeTone.info,
                      ),
                    if (image.teeth.isNotEmpty)
                      StatusBadge(
                        label: notation.formatAll(image.teeth, plain: true),
                        tone: BadgeTone.planned,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  AppFormat.dateTime(image.capturedAt),
                  style: theme.textTheme.bodyMedium,
                ),
                if (image.note != null)
                  Text(image.note!, style: theme.textTheme.bodyMedium),
                if (image.sha256 != null)
                  Text(
                    'SHA-256 ${image.sha256!.substring(0, 16).toUpperCase()}',
                    style: theme.textTheme.bodySmall,
                  ),
                const SizedBox(height: AppSpacing.md),
                BigActionButton(
                  key: const ValueKey('photo-share'),
                  label: hasConsent
                      ? 'Share photo'
                      : 'Share photo (consent needed)',
                  icon: hasConsent ? Icons.share_outlined : Icons.lock_outline,
                  tonal: !hasConsent,
                  onPressed: () => _share(context, ref),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
