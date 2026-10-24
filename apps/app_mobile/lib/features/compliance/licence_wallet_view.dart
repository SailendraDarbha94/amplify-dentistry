import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'compliance_labels.dart';
import 'compliance_providers.dart';
import 'compliance_rules.dart';
import 'licence_form_sheet.dart';

/// Badge tone for a licence alert level.
BadgeTone licenceTone(LicenceAlertLevel level) => switch (level) {
  LicenceAlertLevel.none => BadgeTone.neutral,
  LicenceAlertLevel.ok => BadgeTone.success,
  LicenceAlertLevel.expiringSoon => BadgeTone.warning,
  LicenceAlertLevel.expired => BadgeTone.danger,
};

/// Short badge text for a licence at [now].
String licenceStatusLabel(Licence licence, DateTime now) {
  final days = licenceDaysToDue(licence, now);
  if (days == null) return 'No expiry';
  if (days < 0) return 'Expired';
  if (days == 0) return 'Due today';
  if (days <= licenceWarningDays) return 'Due in $days d';
  return 'Valid';
}

/// Licence wallet: every registration with its expiry and QA dates.
class LicenceWalletView extends ConsumerWidget {
  /// Creates the view.
  const LicenceWalletView({super.key});

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    Licence licence,
  ) async {
    final ctx = ref.read(actorContextProvider);
    final draft = await LicenceFormSheet.show(
      context,
      clinicId: ctx.clinicId,
      existing: licence,
      clock: ref.read(clockProvider),
    );
    if (draft == null) return;
    await ref.read(complianceRepositoryProvider).upsertLicence(ctx, draft);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings;
    final now = ref.watch(clockProvider)();
    final licences = ref.watch(licencesProvider).value;
    if (licences == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (licences.isEmpty) {
      return EmptyState(
        icon: Icons.badge_outlined,
        title: s.nothingHere,
        message:
            'Add AERB, biomedical waste, clinical establishment and '
            'other registrations to get expiry reminders.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.sm,
        AppSpacing.gutter,
        96,
      ),
      children: [
        for (final l in sortLicences(licences))
          LicenceTile(
            key: ValueKey('licence-row-${l.id}'),
            licence: l,
            now: now,
            onTap: () => _edit(context, ref, l),
          ),
      ],
    );
  }
}

/// One licence row.
class LicenceTile extends StatelessWidget {
  /// Creates the tile.
  const LicenceTile({
    super.key,
    required this.licence,
    required this.now,
    this.onTap,
  });

  /// The licence.
  final Licence licence;

  /// Reference instant for the status badge.
  final DateTime now;

  /// Tap target (edit).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final level = licenceAlertLevel(licence, now);
    final lines = <String>[
      licence.identifier,
      if (licence.authority != null && licence.authority!.isNotEmpty)
        licence.authority!,
      if (licence.expiresAt != null)
        'Expires ${AppFormat.date(licence.expiresAt!)}',
      if (licence.qaDueAt != null) 'QA due ${AppFormat.date(licence.qaDueAt!)}',
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          licence.documentPath == null
              ? Icons.badge_outlined
              : Icons.photo_library_outlined,
        ),
        title: Text(licenceKindLabel(licence.kind)),
        subtitle: Text(lines.join('\n'), style: theme.textTheme.bodySmall),
        isThreeLine: lines.length > 1,
        trailing: StatusBadge(
          label: licenceStatusLabel(licence, now),
          tone: licenceTone(level),
          dense: true,
        ),
      ),
    );
  }
}
