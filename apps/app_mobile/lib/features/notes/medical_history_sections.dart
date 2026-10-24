import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';

import 'allergy_entry_sheet.dart';
import 'medical_history_model.dart';
import 'red_flags.dart';

/// Detail inputs shown under a question once it is answered "yes".
/// Returns null for questions with no detail.
class MedicalHistoryDetail extends StatelessWidget {
  /// Creates the detail block for [fieldKey].
  const MedicalHistoryDetail({
    super.key,
    required this.fieldKey,
    required this.draft,
    required this.onChanged,
    required this.now,
  });

  /// Terminology question key.
  final String fieldKey;

  /// Current answers.
  final MedicalHistoryDraft draft;

  /// Replaces the draft.
  final ValueChanged<MedicalHistoryDraft> onChanged;

  /// Clock for the MRONJ preview.
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final child = switch (fieldKey) {
      'diabetes' => _text(
        key: 'mh-hba1c',
        label: 'Recent HbA1c (%)',
        value: draft.hba1c,
        keyboard: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (v) => onChanged(draft.copyWith(hba1c: v)),
        helper: 'HbA1c of 8 or more is flagged as uncontrolled',
      ),
      'cardiac' => _text(
        key: 'mh-cardiac-condition',
        label: 'Condition',
        value: draft.cardiacCondition,
        onChanged: (v) => onChanged(draft.copyWith(cardiacCondition: v)),
      ),
      'anticoagulants' => _text(
        key: 'mh-anticoagulant',
        label: 'Blood thinner',
        value: draft.anticoagulantName,
        onChanged: (v) => onChanged(draft.copyWith(anticoagulantName: v)),
      ),
      'antiresorptives' => _antiresorptive(context),
      'pregnancy' => _pregnancy(context),
      'allergies' => _allergies(context),
      'smoking' => _smoking(context),
      _ => null,
    };
    if (child == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        0,
        AppSpacing.gutter,
        AppSpacing.md,
      ),
      child: child,
    );
  }

  Widget _text({
    required String key,
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
    TextInputType? keyboard,
    String? helper,
  }) => TextFormField(
    key: ValueKey(key),
    initialValue: value,
    keyboardType: keyboard,
    textCapitalization: TextCapitalization.sentences,
    decoration: InputDecoration(labelText: label, helperText: helper),
    onChanged: onChanged,
  );

  Widget _antiresorptive(BuildContext context) {
    final risk = draft.mronjRisk(now);
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _text(
          key: 'mh-antiresorptive',
          label: 'Drug (alendronate, zoledronate, denosumab...)',
          value: draft.antiresorptiveName,
          onChanged: (v) => onChanged(draft.copyWith(antiresorptiveName: v)),
        ),
        const FormGap(),
        ToggleChipGroup<AntiresorptiveRoute>(
          options: const [
            ToggleChipOption(value: AntiresorptiveRoute.oral, label: 'Oral'),
            ToggleChipOption(
              value: AntiresorptiveRoute.intravenous,
              label: 'Intravenous',
            ),
          ],
          selected: {
            if (draft.antiresorptiveRoute != null) draft.antiresorptiveRoute!,
          },
          multiSelect: false,
          onChanged: (set) => onChanged(
            set.isEmpty
                ? draft.copyWith(clearRoute: true)
                : draft.copyWith(antiresorptiveRoute: set.first),
          ),
        ),
        const FormGap(),
        _text(
          key: 'mh-antiresorptive-years',
          label: 'Years on the drug',
          value: draft.antiresorptiveYears,
          keyboard: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (v) => onChanged(draft.copyWith(antiresorptiveYears: v)),
        ),
        SwitchListTile(
          key: const ValueKey('mh-oncology'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Given for cancer (oncology dose)'),
          value: draft.oncologyTreatment,
          onChanged: (v) => onChanged(draft.copyWith(oncologyTreatment: v)),
        ),
        Row(
          children: [
            Text(
              'MRONJ risk group: ',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            StatusBadge(
              key: const ValueKey('mh-mronj-tier'),
              label: mronjRiskLabel(risk),
              tone: switch (risk) {
                MronjRisk.none => BadgeTone.neutral,
                MronjRisk.low => BadgeTone.warning,
                MronjRisk.higher => BadgeTone.danger,
              },
            ),
          ],
        ),
        Text(
          'Higher: intravenous route, oncology dose or more than 5 years oral.',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: colors.warning),
        ),
      ],
    );
  }

  Widget _pregnancy(BuildContext context) => Row(
    children: [
      Text('Trimester', style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(width: AppSpacing.md),
      Expanded(
        child: ToggleChipGroup<int>(
          options: const [
            ToggleChipOption(value: 1, label: '1st'),
            ToggleChipOption(value: 2, label: '2nd'),
            ToggleChipOption(value: 3, label: '3rd'),
          ],
          selected: {
            if (draft.pregnancyTrimester != null) draft.pregnancyTrimester!,
          },
          multiSelect: false,
          onChanged: (set) => onChanged(
            set.isEmpty
                ? draft.copyWith(clearTrimester: true)
                : draft.copyWith(pregnancyTrimester: set.first),
          ),
        ),
      ),
    ],
  );

  Widget _smoking(BuildContext context) => ToggleChipGroup<SmokingStatus>(
    options: const [
      ToggleChipOption(value: SmokingStatus.current, label: 'Current'),
      ToggleChipOption(value: SmokingStatus.former, label: 'Former'),
    ],
    selected: {draft.smoking},
    multiSelect: false,
    allowEmpty: false,
    onChanged: (set) => onChanged(draft.copyWith(smoking: set.first)),
  );

  Widget _allergies(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < draft.allergies.length; i++)
          ListTile(
            key: ValueKey('mh-allergy-$i'),
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.warning_amber_rounded, color: colors.danger),
            title: Text(draft.allergies[i].substance),
            subtitle: Text(
              [
                if (draft.allergies[i].allergyGroup != null)
                  allergyGroupLabel(draft.allergies[i].allergyGroup!),
                AppFormat.enumLabel(draft.allergies[i].severity),
                if (draft.allergies[i].reaction != null)
                  draft.allergies[i].reaction!,
              ].join(' · '),
            ),
            trailing: IconButton(
              tooltip: 'Remove',
              icon: const Icon(Icons.close),
              onPressed: () => onChanged(
                draft.copyWith(allergies: [...draft.allergies]..removeAt(i)),
              ),
            ),
            onTap: () async {
              final edited = await AllergyEntrySheet.show(
                context,
                existing: draft.allergies[i],
              );
              if (edited == null) return;
              final next = [...draft.allergies];
              next[i] = edited;
              onChanged(draft.copyWith(allergies: next));
            },
          ),
        OutlinedButton.icon(
          key: const ValueKey('mh-allergy-add'),
          icon: const Icon(Icons.add),
          label: const Text('Add allergy'),
          onPressed: () async {
            final entry = await AllergyEntrySheet.show(context);
            if (entry == null) return;
            onChanged(draft.copyWith(allergies: [...draft.allergies, entry]));
          },
        ),
      ],
    );
  }
}
