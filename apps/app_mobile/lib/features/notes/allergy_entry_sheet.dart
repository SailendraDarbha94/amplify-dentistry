import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';

import 'medical_history_model.dart';

/// Bottom sheet that records one allergy: substance, reaction, severity and
/// the normalised group used for prescribing checks.
class AllergyEntrySheet extends StatefulWidget {
  /// Creates the sheet; [existing] pre-fills it.
  const AllergyEntrySheet({super.key, this.existing});

  /// Entry being edited, or null for a new one.
  final AllergyEntry? existing;

  /// Shows the sheet; returns the entry or null when dismissed.
  static Future<AllergyEntry?> show(
    BuildContext context, {
    AllergyEntry? existing,
  }) => showModalBottomSheet<AllergyEntry>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => AllergyEntrySheet(existing: existing),
  );

  @override
  State<AllergyEntrySheet> createState() => _AllergyEntrySheetState();
}

class _AllergyEntrySheetState extends State<AllergyEntrySheet> {
  late final TextEditingController _substance = TextEditingController(
    text: widget.existing?.substance ?? '',
  );
  late final TextEditingController _reaction = TextEditingController(
    text: widget.existing?.reaction ?? '',
  );
  late AllergySeverity _severity =
      widget.existing?.severity ?? AllergySeverity.unknown;
  late String? _group = widget.existing?.allergyGroup;

  @override
  void dispose() {
    _substance.dispose();
    _reaction.dispose();
    super.dispose();
  }

  void _save() {
    final substance = _substance.text.trim();
    if (substance.isEmpty) return;
    Navigator.of(context).pop(
      AllergyEntry(
        substance: substance,
        reaction: _reaction.text.trim().isEmpty ? null : _reaction.text.trim(),
        severity: _severity,
        allergyGroup: _group,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.lg,
        AppSpacing.gutter,
        AppSpacing.lg + bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Allergy', style: Theme.of(context).textTheme.titleLarge),
            const FormGap(),
            TextField(
              key: const ValueKey('allergy-substance'),
              controller: _substance,
              autofocus: widget.existing == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Substance',
                hintText: 'Amoxicillin, lignocaine, latex...',
              ),
            ),
            const FormGap(),
            TextField(
              key: const ValueKey('allergy-reaction'),
              controller: _reaction,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Reaction (${s.optional})',
                hintText: 'Rash, swelling, breathlessness',
              ),
            ),
            const FormGap(),
            Text('Severity', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            ToggleChipGroup<AllergySeverity>(
              options: [
                for (final v in AllergySeverity.values)
                  ToggleChipOption(value: v, label: AppFormat.enumLabel(v)),
              ],
              selected: {_severity},
              multiSelect: false,
              allowEmpty: false,
              onChanged: (set) => setState(() => _severity = set.first),
            ),
            const FormGap(),
            Text(
              'Group (drives prescribing checks)',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                for (final g in allergyGroupOptions)
                  FilterChip(
                    key: ValueKey('allergy-group-$g'),
                    label: Text(allergyGroupLabel(g)),
                    selected: _group == g,
                    onSelected: (v) => setState(() => _group = v ? g : null),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            BigActionButton(
              key: const ValueKey('allergy-save'),
              label: s.save,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
