import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';

import 'compliance_labels.dart';

/// Bottom sheet that captures one autoclave run. Returns an unsaved
/// [SterilisationCycle] with an empty `cycleNumber` (minted on save).
class CycleFormSheet extends StatefulWidget {
  /// Creates the form.
  const CycleFormSheet({
    super.key,
    required this.clinicId,
    required this.operatorId,
    this.lastAutoclaveName,
    this.clock = DateTime.now,
  });

  /// Owning clinic.
  final String clinicId;

  /// Member logging the cycle.
  final String operatorId;

  /// Pre-fills the autoclave name from the previous cycle.
  final String? lastAutoclaveName;

  /// Clock; override in tests.
  final DateTime Function() clock;

  /// Shows the sheet; resolves to the draft cycle or null when dismissed.
  static Future<SterilisationCycle?> show(
    BuildContext context, {
    required String clinicId,
    required String operatorId,
    String? lastAutoclaveName,
    DateTime Function() clock = DateTime.now,
  }) => showModalBottomSheet<SterilisationCycle>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => CycleFormSheet(
      clinicId: clinicId,
      operatorId: operatorId,
      lastAutoclaveName: lastAutoclaveName,
      clock: clock,
    ),
  );

  @override
  State<CycleFormSheet> createState() => _CycleFormSheetState();
}

class _CycleFormSheetState extends State<CycleFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _autoclave = TextEditingController(
    text: widget.lastAutoclaveName ?? '',
  );
  final _temperature = TextEditingController(text: '134');
  final _pressure = TextEditingController(text: '210');
  final _duration = TextEditingController(text: '4');
  final _load = TextEditingController();
  final _note = TextEditingController();
  SterilisationCycleType _type = SterilisationCycleType.classB;
  bool _chemicalPassed = true;
  BiologicalIndicatorResult _biological = BiologicalIndicatorResult.notDone;

  @override
  void dispose() {
    _autoclave.dispose();
    _temperature.dispose();
    _pressure.dispose();
    _duration.dispose();
    _load.dispose();
    _note.dispose();
    super.dispose();
  }

  String? _optionalNumber(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    return num.tryParse(v.trim()) == null ? context.strings.invalidValue : null;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final now = widget.clock().toUtc();
    String? text(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    Navigator.of(context).pop(
      SterilisationCycle(
        id: newId(),
        clinicId: widget.clinicId,
        cycleNumber: '',
        autoclaveName: _autoclave.text.trim(),
        cycledAt: now,
        cycleType: _type,
        temperatureC: num.tryParse(_temperature.text.trim()),
        pressureKpa: num.tryParse(_pressure.text.trim()),
        durationMinutes: int.tryParse(_duration.text.trim()),
        chemicalIndicatorPassed: _chemicalPassed,
        biologicalIndicatorResult:
            _biological == BiologicalIndicatorResult.notDone
            ? null
            : _biological,
        loadContents: text(_load),
        operatorId: widget.operatorId,
        note: text(_note),
        createdAt: now,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final insets = MediaQuery.viewInsetsOf(context);
    return Padding(
      padding: EdgeInsets.only(bottom: insets.bottom),
      child: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Log sterilisation cycle',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const FormGap(),
              TextFormField(
                key: const ValueKey('cycle-autoclave'),
                controller: _autoclave,
                decoration: const InputDecoration(labelText: 'Autoclave'),
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? s.required : null,
              ),
              const FormGap(),
              ToggleChipGroup<SterilisationCycleType>(
                options: [
                  for (final t in SterilisationCycleType.values)
                    ToggleChipOption(value: t, label: cycleTypeLabel(t)),
                ],
                selected: {_type},
                multiSelect: false,
                allowEmpty: false,
                onChanged: (v) => setState(() => _type = v.first),
              ),
              const FormGap(),
              FormRow(
                children: [
                  TextFormField(
                    key: const ValueKey('cycle-temp'),
                    controller: _temperature,
                    decoration: const InputDecoration(labelText: 'Temp C'),
                    keyboardType: TextInputType.number,
                    validator: _optionalNumber,
                  ),
                  TextFormField(
                    key: const ValueKey('cycle-pressure'),
                    controller: _pressure,
                    decoration: const InputDecoration(labelText: 'kPa'),
                    keyboardType: TextInputType.number,
                    validator: _optionalNumber,
                  ),
                  TextFormField(
                    key: const ValueKey('cycle-duration'),
                    controller: _duration,
                    decoration: const InputDecoration(labelText: 'Hold min'),
                    keyboardType: TextInputType.number,
                    validator: _optionalNumber,
                  ),
                ],
              ),
              const FormGap(),
              SwitchListTile(
                key: const ValueKey('cycle-chemical'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Chemical indicator passed'),
                value: _chemicalPassed,
                onChanged: (v) => setState(() => _chemicalPassed = v),
              ),
              const FormGap(),
              Text(
                'Biological indicator (spore test)',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              ToggleChipGroup<BiologicalIndicatorResult>(
                options: [
                  for (final r in BiologicalIndicatorResult.values)
                    ToggleChipOption(value: r, label: biologicalResultLabel(r)),
                ],
                selected: {_biological},
                multiSelect: false,
                allowEmpty: false,
                onChanged: (v) => setState(() => _biological = v.first),
              ),
              const FormGap(),
              TextFormField(
                key: const ValueKey('cycle-load'),
                controller: _load,
                decoration: const InputDecoration(
                  labelText: 'Load contents',
                  hintText: 'e.g. 4 exam kits, 2 extraction kits',
                ),
              ),
              const FormGap(),
              TextFormField(
                key: const ValueKey('cycle-note'),
                controller: _note,
                decoration: InputDecoration(labelText: s.notes),
              ),
              const SizedBox(height: AppSpacing.lg),
              BigActionButton(
                key: const ValueKey('cycle-save'),
                label: s.save,
                icon: Icons.check,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
