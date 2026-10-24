import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'consent_model.dart';
import 'consent_providers.dart';

/// Location of the clinical photography consent flow for [patientId]. Other
/// features (notes, imaging) push this before sharing a photo.
String photoUseConsentLocation(String patientId) =>
    '/patients/$patientId/consent/new?template=$photoUseTemplateCode';

/// Shows whether the photo-use consent is signed and opens the flow when it
/// is not. Reusable from the notes and imaging screens.
class PhotoUseConsentTile extends ConsumerWidget {
  /// Creates the tile.
  const PhotoUseConsentTile({super.key, required this.patientId});

  /// The patient.
  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consents = ref.watch(patientConsentsProvider(patientId)).value;
    final signed = consents
        ?.where((c) => c.templateCode == photoUseTemplateCode)
        .toList();
    final latest = (signed == null || signed.isEmpty) ? null : signed.first;
    return ListTile(
      key: const ValueKey('consent-photo-use'),
      leading: const Icon(Icons.photo_camera_outlined),
      title: const Text('Clinical photography consent'),
      subtitle: Text(
        latest == null
            ? 'Not signed. Required before photos are shared.'
            : 'Signed ${AppFormat.date(latest.signedAt)}',
      ),
      trailing: latest == null
          ? FilledButton.tonal(
              onPressed: () => context.push(photoUseConsentLocation(patientId)),
              child: const Text('Sign'),
            )
          : const StatusBadge(label: 'Signed', tone: BadgeTone.success),
      onTap: latest == null
          ? () => context.push(photoUseConsentLocation(patientId))
          : () => context.push('/patients/$patientId/consent/${latest.id}'),
    );
  }
}
