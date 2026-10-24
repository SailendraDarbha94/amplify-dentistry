import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';

/// A red flag with the one-line detail shown under its banner.
@immutable
class RedFlagInfo {
  /// Creates a flag description.
  const RedFlagInfo({
    required this.flag,
    required this.label,
    required this.detail,
  });

  /// The structured flag.
  final RedFlag flag;

  /// Short label (`Anticoagulant`).
  final String label;

  /// Chairside detail (`On warfarin: expect prolonged bleeding`).
  final String detail;
}

/// Short label for a red flag.
String redFlagTitle(RedFlag flag) => switch (flag) {
  RedFlag.anticoagulant => 'Anticoagulant',
  RedFlag.mronj => 'MRONJ risk',
  RedFlag.uncontrolledDiabetes => 'Uncontrolled diabetes',
  RedFlag.pregnancy => 'Pregnant',
  RedFlag.cardiac => 'Cardiac condition',
  RedFlag.bleedingDisorder => 'Bleeding disorder',
  RedFlag.allergyLocalAnaesthetic => 'Local anaesthetic allergy',
  RedFlag.allergyPenicillin => 'Penicillin allergy',
  RedFlag.steroids => 'On steroids',
  RedFlag.epilepsy => 'Epilepsy',
};

/// `None`, `Low` or `Higher`.
String mronjRiskLabel(MronjRisk risk) => switch (risk) {
  MronjRisk.none => 'None',
  MronjRisk.low => 'Low',
  MronjRisk.higher => 'Higher',
};

String _allergySubstances(MedicalHistory history, String group) => history
    .allergies
    .where((a) => a.allergyGroup?.toLowerCase() == group.toLowerCase())
    .map(
      (a) =>
          a.reaction == null ? a.substance : '${a.substance} (${a.reaction})',
    )
    .join(', ');

/// Builds the banner list for a history, in the order of
/// [MedicalHistory.redFlags]. The MRONJ tier is spelled out explicitly.
List<RedFlagInfo> redFlagInfos(MedicalHistory history) {
  return [
    for (final flag in history.redFlags)
      RedFlagInfo(
        flag: flag,
        label: flag == RedFlag.mronj
            ? 'MRONJ risk: ${mronjRiskLabel(history.mronjRisk).toLowerCase()}'
            : redFlagTitle(flag),
        detail: _detailFor(history, flag),
      ),
  ];
}

String _detailFor(MedicalHistory h, RedFlag flag) => switch (flag) {
  RedFlag.anticoagulant =>
    'On ${h.anticoagulant}. Expect prolonged bleeding; do not stop the drug '
        'without the physician.',
  RedFlag.mronj =>
    '${h.antiresorptive}'
        '${h.antiresorptiveRoute == null ? '' : ', ${h.antiresorptiveRoute!.name}'}'
        '${h.antiresorptiveYears == null ? '' : ', ${h.antiresorptiveYears} y'}'
        '${h.oncologyTreatment ? ', oncology' : ''}. '
        'Avoid extractions and implants where possible; refer if higher risk.',
  RedFlag.uncontrolledDiabetes =>
    'HbA1c ${h.hba1c}. Defer elective surgery; infection and healing risk.',
  RedFlag.pregnancy =>
    h.pregnancyTrimester == null
        ? 'Avoid elective radiographs and NSAIDs; check every drug.'
        : 'Trimester ${h.pregnancyTrimester}. Avoid elective radiographs and '
              'NSAIDs; check every drug.',
  RedFlag.cardiac =>
    '${h.cardiacCondition}. Check antibiotic prophylaxis and adrenaline '
        'dose.',
  RedFlag.bleedingDisorder => 'Plan haemostasis before any surgical procedure.',
  RedFlag.allergyLocalAnaesthetic =>
    'Allergic to: ${_allergySubstances(h, 'localAnaesthetic')}.',
  RedFlag.allergyPenicillin =>
    'Allergic to: ${_allergySubstances(h, 'penicillin')}. '
        'Prescribing penicillins is blocked without an override.',
  RedFlag.steroids =>
    'Possible adrenal suppression; consider steroid cover for surgery.',
  RedFlag.epilepsy => 'Keep appointments short; avoid flashing lights.',
};

/// Red banners rendered at the top of the notes page and reusable in the
/// patient header. Renders nothing when [flags] is empty.
class RedFlagBanners extends StatelessWidget {
  /// Creates the banner stack.
  const RedFlagBanners({super.key, required this.flags, this.compact = false});

  /// Flags to show.
  final List<RedFlagInfo> flags;

  /// Hide the detail line (for the compact header).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (flags.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final danger = AppColors.of(context).danger;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final f in flags)
          Container(
            key: ValueKey('red-flag-banner-${f.flag.name}'),
            margin: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.xs,
              AppSpacing.gutter,
              AppSpacing.xs,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: danger.withValues(alpha: 0.12),
              border: Border.all(color: danger),
              borderRadius: AppRadii.mdAll,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, color: danger),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        f.label,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: danger,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (!compact)
                        Text(f.detail, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
