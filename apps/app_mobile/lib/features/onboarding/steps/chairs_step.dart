import 'package:ampdent_terminology/ampdent_terminology.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../onboarding_controller.dart';

/// Step 3: chair count and a summary before everything is created.
class ChairsStep extends ConsumerWidget {
  /// Creates the step.
  const ChairsStep({super.key});

  /// Upper bound for a single-location clinic.
  static const int maxChairs = 12;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);
    final theme = Theme.of(context);
    return ListView(
      padding: AppSpacing.screenPadding,
      children: [
        SectionCard(
          title: 'Chairs',
          subtitle:
              'Appointments are booked per chair. You can rename or '
              'add chairs later in Settings.',
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.outlined(
                key: const ValueKey('onboarding-chairs-minus'),
                onPressed: draft.chairCount > 1
                    ? () => controller.update(
                        (d) => d.copyWith(chairCount: d.chairCount - 1),
                      )
                    : null,
                icon: const Icon(Icons.remove),
                iconSize: 28,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: Text(
                  '${draft.chairCount}',
                  key: const ValueKey('onboarding-chairs-count'),
                  style: theme.textTheme.displaySmall,
                ),
              ),
              IconButton.outlined(
                key: const ValueKey('onboarding-chairs-plus'),
                onPressed: draft.chairCount < maxChairs
                    ? () => controller.update(
                        (d) => d.copyWith(chairCount: d.chairCount + 1),
                      )
                    : null,
                icon: const Icon(Icons.add),
                iconSize: 28,
              ),
            ],
          ),
        ),
        const FormGap(height: AppSpacing.lg),
        SectionCard(
          title: 'Summary',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LabeledValue(label: 'Clinic', value: draft.clinicName),
              LabeledValue(
                label: 'Location',
                value: [
                  draft.city,
                  gstStateByCode(draft.stateCode ?? '')?.name ??
                      draft.stateCode ??
                      '',
                ].where((s) => s.isNotEmpty).join(', '),
              ),
              LabeledValue(label: 'Phone', value: draft.phone),
              LabeledValue(label: 'Owner dentist', value: draft.dentistName),
              LabeledValue(
                label: 'Registration number',
                value: draft.registrationNumber,
              ),
              LabeledValue(label: 'Chairs', value: '${draft.chairCount}'),
            ],
          ),
        ),
        const FormGap(height: AppSpacing.lg),
        Text(
          'Everything is stored on this phone. Sync and WhatsApp sending are '
          'added later; your data is exportable at any time.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
