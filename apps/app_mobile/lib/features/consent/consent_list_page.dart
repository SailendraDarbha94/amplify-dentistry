import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'consent_form_sections.dart';
import 'consent_providers.dart';
import 'photo_use_consent.dart';

/// Signed consents of a patient, newest first, with the photo-use entry
/// point and a button to take a new consent.
class ConsentListPage extends ConsumerWidget {
  /// Creates the page.
  const ConsentListPage({super.key, required this.patientId});

  /// The patient.
  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings;
    final consents = ref.watch(patientConsentsProvider(patientId));
    final notation = ref.watch(notationProvider);
    final base = '/patients/$patientId/consent';
    return Scaffold(
      appBar: AppBar(title: Text('${s.consent}s')),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('consent-new'),
        onPressed: () => context.push('$base/new'),
        icon: const Icon(Icons.draw_outlined),
        label: Text('New ${s.consent.toLowerCase()}'),
      ),
      body: consents.when(
        loading: () => Center(child: Text(s.loading)),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(patientConsentsProvider(patientId)),
        ),
        data: (list) => ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            PhotoUseConsentTile(patientId: patientId),
            const Divider(height: 1),
            if (list.isEmpty)
              EmptyState(
                icon: Icons.draw_outlined,
                title: s.nothingHere,
                message: 'No consent signed yet',
              )
            else
              for (final c in list)
                ListTile(
                  key: ValueKey('consent-row-${c.id}'),
                  leading: const Icon(Icons.verified_outlined),
                  title: Text(consentSummary(c, notation)),
                  subtitle: Text(consentSignedLine(c)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('$base/${c.id}'),
                ),
          ],
        ),
      ),
    );
  }
}
