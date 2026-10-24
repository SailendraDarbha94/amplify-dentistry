import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The commitments the clinic can rely on about its own data.
const List<(String, String)> dataOwnershipPoints = [
  (
    'You own every record',
    'Patient records, invoices, consents, prescriptions, images and the audit '
        'log belong to the clinic. AmpDent is the custodian, never the owner.',
  ),
  (
    'Export any time, in open formats',
    'A full export of one patient (PDF record copy plus JSON) or of the whole '
        'clinic (JSON) is available from this screen at any time, with no fee '
        'and no waiting period.',
  ),
  (
    'Works offline',
    'All data lives on this device first. Nothing is held back on a server '
        'you cannot reach.',
  ),
  (
    'Nothing is silently deleted',
    'Clinical rows are never hard-deleted. Every change is recorded in the '
        'audit log with who, when and what changed, as the DCI Code and DPDP '
        'Act expect.',
  ),
  (
    'Record copies within 72 hours',
    'A patient may ask for a copy of their record (DCI Code 3.3.2). Use '
        'Export to produce it on the spot.',
  ),
  (
    'Consent is purpose-scoped',
    'Reminders, recall, marketing and photo use each have their own DPDP '
        'consent, which the patient can withdraw at any time.',
  ),
];

/// Plain-language data ownership statement with a shortcut to Export.
class DataOwnershipPage extends StatelessWidget {
  /// Creates the page.
  const DataOwnershipPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Data ownership')),
      body: ListView(
        padding: AppSpacing.screenPadding,
        children: [
          Text(MobileStrings.dataOwnership, style: theme.textTheme.bodyLarge),
          const SizedBox(height: AppSpacing.lg),
          for (final (title, body) in dataOwnershipPoints)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: AppColors.of(context).success,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: theme.textTheme.titleSmall),
                        Text(body, style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          BigActionButton(
            key: const ValueKey('ownership-export'),
            label: 'Go to Export',
            icon: Icons.download_outlined,
            tonal: true,
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/export'),
          ),
        ],
      ),
    );
  }
}
