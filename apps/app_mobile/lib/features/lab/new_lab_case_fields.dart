import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';

import 'lab_model.dart';

/// Lab and case-type pickers.
class LabCaseSourceFields extends StatelessWidget {
  /// Creates the fields.
  const LabCaseSourceFields({
    super.key,
    required this.labs,
    required this.labId,
    required this.onLabChanged,
    required this.caseType,
    required this.onCaseTypeChanged,
    required this.procedures,
    required this.procedureId,
    required this.onProcedureChanged,
    required this.notation,
  });

  /// Active labs.
  final List<Lab> labs;

  /// Selected lab.
  final String? labId;

  /// Lab change.
  final ValueChanged<String?> onLabChanged;

  /// Selected case type.
  final LabCaseType caseType;

  /// Case type change.
  final ValueChanged<LabCaseType> onCaseTypeChanged;

  /// The patient's procedures that may need lab work.
  final List<ProcedureRecord> procedures;

  /// Selected procedure, if any.
  final String? procedureId;

  /// Procedure change.
  final ValueChanged<String?> onProcedureChanged;

  /// Tooth notation for procedure labels.
  final ToothNotation notation;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    return FormSection(
      title: 'Work',
      children: [
        if (procedures.isNotEmpty)
          DropdownButtonFormField<String?>(
            isExpanded: true,
            key: const ValueKey('labcase-procedure'),
            initialValue: procedureId,
            decoration: InputDecoration(
              labelText: '${s.procedures} (optional)',
            ),
            items: [
              const DropdownMenuItem<String?>(child: Text('None')),
              for (final p in procedures)
                DropdownMenuItem<String?>(
                  value: p.id,
                  child: Text(
                    p.tooth == null
                        ? p.name
                        : '${p.name} - ${notation.formatPlain(p.tooth!)}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: onProcedureChanged,
          ),
        DropdownButtonFormField<String>(
          isExpanded: true,
          key: const ValueKey('labcase-lab'),
          initialValue: labId,
          decoration: InputDecoration(labelText: s.lab),
          items: [
            for (final l in labs)
              DropdownMenuItem(value: l.id, child: Text(l.name)),
          ],
          validator: (v) => v == null ? 'Choose a lab' : null,
          onChanged: onLabChanged,
        ),
        DropdownButtonFormField<LabCaseType>(
          isExpanded: true,
          key: const ValueKey('labcase-type'),
          initialValue: caseType,
          decoration: const InputDecoration(labelText: 'Case type'),
          items: [
            for (final t in LabCaseType.values)
              DropdownMenuItem(value: t, child: Text(labCaseTypeLabel(t))),
          ],
          onChanged: (v) {
            if (v != null) onCaseTypeChanged(v);
          },
        ),
      ],
    );
  }
}

/// Teeth, material, shade and impression fields.
class LabCaseSpecFields extends StatelessWidget {
  /// Creates the fields.
  const LabCaseSpecFields({
    super.key,
    required this.teeth,
    required this.material,
    required this.caseType,
    required this.shade,
    required this.onShadeChanged,
    required this.impressionType,
    required this.onImpressionChanged,
    required this.instructions,
    required this.fee,
  });

  /// Comma-separated FDI teeth.
  final TextEditingController teeth;

  /// Material text (with suggestions per case type).
  final TextEditingController material;

  /// Selected case type (drives material suggestions).
  final LabCaseType caseType;

  /// Selected shade.
  final String? shade;

  /// Shade change (null clears).
  final ValueChanged<String?> onShadeChanged;

  /// Selected impression type.
  final String? impressionType;

  /// Impression change.
  final ValueChanged<String?> onImpressionChanged;

  /// Free-text instructions.
  final TextEditingController instructions;

  /// Lab fee in rupees.
  final TextEditingController fee;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final materials = materialsFor(caseType);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FormSection(
          title: 'Specification',
          children: [
            TextFormField(
              key: const ValueKey('labcase-teeth'),
              controller: teeth,
              decoration: InputDecoration(
                labelText: '${s.teeth} (FDI, comma separated)',
                hintText: '16, 17',
              ),
              keyboardType: TextInputType.number,
              validator: (v) => parseTeethInput(v ?? '') == null
                  ? 'Use FDI tooth numbers like 16 or 36'
                  : null,
            ),
            TextFormField(
              key: const ValueKey('labcase-material'),
              controller: material,
              decoration: const InputDecoration(labelText: 'Material'),
              textCapitalization: TextCapitalization.sentences,
            ),
            if (materials.isNotEmpty)
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final m in materials)
                    ActionChip(
                      key: ValueKey('labcase-material-$m'),
                      label: Text(m),
                      onPressed: () => material.text = m,
                    ),
                ],
              ),
            DropdownButtonFormField<String?>(
              isExpanded: true,
              key: const ValueKey('labcase-impression'),
              initialValue: impressionType,
              decoration: const InputDecoration(labelText: 'Impression / scan'),
              items: [
                const DropdownMenuItem<String?>(child: Text('-')),
                for (final t in impressionTypes)
                  DropdownMenuItem<String?>(value: t, child: Text(t)),
              ],
              onChanged: onImpressionChanged,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        FormSection(
          title: 'Shade',
          description: shade == null ? 'None chosen' : 'Chosen: $shade',
          trailing: shade == null
              ? null
              : TextButton(
                  onPressed: () => onShadeChanged(null),
                  child: Text(s.clear),
                ),
          children: [
            _ShadeRow(
              title: 'VITA classical',
              shades: vitaClassicalShades,
              selected: shade,
              onSelected: onShadeChanged,
            ),
            _ShadeRow(
              title: 'VITA 3D-Master',
              shades: vita3dMasterShades,
              selected: shade,
              onSelected: onShadeChanged,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        FormSection(
          title: 'Instructions and fee',
          children: [
            TextFormField(
              key: const ValueKey('labcase-instructions'),
              controller: instructions,
              decoration: const InputDecoration(
                labelText: 'Instructions to the lab',
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            TextFormField(
              key: const ValueKey('labcase-fee'),
              controller: fee,
              decoration: InputDecoration(
                labelText: 'Lab fee (rupees)',
                helperText: 'What the lab charges the clinic; for margin',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty || Money.tryParse(v!) != null
                  ? null
                  : s.invalidValue,
            ),
          ],
        ),
      ],
    );
  }
}

class _ShadeRow extends StatelessWidget {
  const _ShadeRow({
    required this.title,
    required this.shades,
    required this.selected,
    required this.onSelected,
  });

  final String title;
  final List<String> shades;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: AppSpacing.xs),
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        children: [
          for (final sh in shades)
            ChoiceChip(
              key: ValueKey('labcase-shade-$sh'),
              label: Text(sh),
              selected: selected == sh,
              onSelected: (on) => onSelected(on ? sh : null),
            ),
        ],
      ),
    ],
  );
}
