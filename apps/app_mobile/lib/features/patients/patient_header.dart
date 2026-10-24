import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'patient_providers.dart';

/// Short label for a medical red flag chip.
String redFlagLabel(RedFlag flag) => switch (flag) {
  RedFlag.anticoagulant => 'Anticoagulant',
  RedFlag.mronj => 'MRONJ risk',
  RedFlag.uncontrolledDiabetes => 'Uncontrolled diabetes',
  RedFlag.pregnancy => 'Pregnant',
  RedFlag.cardiac => 'Cardiac',
  RedFlag.bleedingDisorder => 'Bleeding disorder',
  RedFlag.allergyLocalAnaesthetic => 'LA allergy',
  RedFlag.allergyPenicillin => 'Penicillin allergy',
  RedFlag.steroids => 'Steroids',
  RedFlag.epilepsy => 'Epilepsy',
};

/// Patient identity header: name, age/sex, phone, patient number, red flags
/// from the latest medical history and the outstanding balance.
class PatientHeader extends ConsumerWidget {
  /// Creates the header for [patient].
  const PatientHeader({super.key, required this.patient});

  /// The patient.
  final Patient patient;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final now = ref.watch(clockProvider)();
    final balance = ref.watch(patientBalanceProvider(patient.id)).value;
    final history = ref.watch(latestMedicalHistoryProvider(patient.id)).value;
    final flags = history?.redFlags ?? const <RedFlag>[];
    final minor = patient.isMinor(now);
    final messagingPhone = patient.messagingPhone(now);
    return Container(
      width: double.infinity,
      padding: AppSpacing.screenPadding,
      color: theme.colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                child: Text(
                  patient.firstName.isEmpty ? '?' : patient.firstName[0],
                  style: theme.textTheme.titleLarge,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient.displayName,
                      style: theme.textTheme.titleLarge,
                    ),
                    Text(
                      '${AppFormat.ageSex(patient, now)}  ·  '
                      '${patient.patientNumber}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Icon(
                          Icons.phone_outlined,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Flexible(child: PhoneText(patient.phone)),
                      ],
                    ),
                    if (minor && messagingPhone != patient.phone)
                      Text(
                        'Messages go to ${patient.guardianName ?? 'guardian'} '
                        '(${AppFormat.phone(messagingPhone)})',
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Balance', style: theme.textTheme.labelSmall),
                  MoneyText(
                    balance == null ? '-' : AppFormat.money(balance),
                    emphasis: MoneyEmphasis.strong,
                    color: balance != null && balance > const Money.zero()
                        ? colors.danger
                        : null,
                  ),
                ],
              ),
            ],
          ),
          if (minor || flags.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                if (minor)
                  const StatusBadge(
                    label: 'Minor',
                    tone: BadgeTone.info,
                    icon: Icons.child_care,
                  ),
                for (final f in flags)
                  StatusBadge(
                    key: ValueKey('red-flag-${f.name}'),
                    label: redFlagLabel(f),
                    tone: BadgeTone.danger,
                    icon: Icons.warning_amber_rounded,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
