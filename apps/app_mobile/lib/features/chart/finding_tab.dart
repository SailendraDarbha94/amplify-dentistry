import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_terminology/ampdent_terminology.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'chart_providers.dart';
import 'chart_strings.dart';
import 'surface_picker.dart';
import 'tooth_sheet.dart';

/// Quick finding types offered on the sheet.
enum FindingKind { caries, fracture, mobility, missing, other }

/// Label for a finding kind chip.
String findingKindLabel(FindingKind kind) => switch (kind) {
  FindingKind.caries => ChartStrings.caries,
  FindingKind.fracture => ChartStrings.fracture,
  FindingKind.mobility => ChartStrings.mobility,
  FindingKind.missing => ChartStrings.missing,
  FindingKind.other => ChartStrings.other,
};

/// ICD-10 code implied by an ICDAS caries code (enamel vs dentine).
String icd10ForIcdas(IcdasCode? icdas) {
  if (icdas == null) return 'K02.9';
  return icdas.code <= 3 ? 'K02.0' : 'K02.1';
}

/// Records a finding on the selected tooth: ICDAS caries by surface,
/// fracture, mobility, missing, or any ICD-10 K00-K14 code.
/// Test keys: `finding-type-<kind>`, `finding-icdas-<n>`,
/// `finding-mobility-<n>`, `finding-mark-missing`, `finding-icd-search`,
/// `finding-icd-<code>`, `finding-description`, `finding-note`,
/// `finding-save`.
class FindingTab extends ConsumerStatefulWidget {
  /// Creates the tab.
  const FindingTab({
    super.key,
    required this.patientId,
    required this.tooth,
    this.surfaces = const SurfaceSet.empty(),
  });

  /// Patient.
  final String patientId;

  /// Tooth.
  final ToothId tooth;

  /// Surfaces selected on the chart.
  final SurfaceSet surfaces;

  @override
  ConsumerState<FindingTab> createState() => _FindingTabState();
}

class _FindingTabState extends ConsumerState<FindingTab> {
  FindingKind _kind = FindingKind.caries;
  IcdasCode? _icdas;
  MobilityGrade _mobility = MobilityGrade.grade1;
  bool _markMissing = true;
  Icd10Code? _icd10;
  String _icdQuery = '';
  late SurfaceSet _surfaces = widget.surfaces;
  final TextEditingController _description = TextEditingController();
  final TextEditingController _note = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _description.dispose();
    _note.dispose();
    super.dispose();
  }

  ({String description, String? icd10, IcdasCode? icdas, SurfaceSet surfaces})?
  _compose() {
    switch (_kind) {
      case FindingKind.caries:
        final severity = _icdas == null ? '' : ' ICDAS ${_icdas!.code}';
        return (
          description: '${ChartStrings.caries}$severity',
          icd10: icd10ForIcdas(_icdas),
          icdas: _icdas,
          surfaces: _surfaces,
        );
      case FindingKind.fracture:
        return (
          description: 'Fractured tooth',
          icd10: null,
          icdas: null,
          surfaces: _surfaces,
        );
      case FindingKind.mobility:
        return (
          description: 'Mobility grade ${_mobility.value}',
          icd10: null,
          icdas: null,
          surfaces: const SurfaceSet.empty(),
        );
      case FindingKind.missing:
        return (
          description: 'Missing tooth',
          icd10: 'K08.1',
          icdas: null,
          surfaces: const SurfaceSet.empty(),
        );
      case FindingKind.other:
        final text = _description.text.trim();
        if (text.isEmpty) return null;
        return (
          description: text,
          icd10: _icd10?.code,
          icdas: null,
          surfaces: _surfaces,
        );
    }
  }

  Future<void> _save() async {
    final composed = _compose();
    if (composed == null) {
      setState(() => _error = ChartStrings.descriptionRequired);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final service = ref.read(chartServiceProvider);
    try {
      await service.addFinding(
        patientId: widget.patientId,
        tooth: widget.tooth,
        surfaces: composed.surfaces,
        description: composed.description,
        icdas: composed.icdas,
        icd10Code: composed.icd10,
        note: _note.text,
      );
      if (_kind == FindingKind.missing && _markMissing) {
        await service.setToothState(
          patientId: widget.patientId,
          tooth: widget.tooth,
          state: ToothState.missing,
          note: _note.text,
        );
      }
      if (!mounted) return;
      Navigator.of(context)
          .pop(ToothSheetResult('${composed.description} recorded'));
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final theme = Theme.of(context);
    return ListView(
      padding: AppSpacing.screenPadding,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            for (final kind in FindingKind.values)
              ChoiceChip(
                key: ValueKey('finding-type-${kind.name}'),
                label: Text(findingKindLabel(kind)),
                selected: _kind == kind,
                onSelected: (_) => setState(() => _kind = kind),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        ..._kindFields(theme, s),
        const SizedBox(height: AppSpacing.md),
        TextField(
          key: const ValueKey('finding-note'),
          controller: _note,
          decoration: InputDecoration(labelText: ChartStrings.noteOptional),
          textCapitalization: TextCapitalization.sentences,
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              _error!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        BigActionButton(
          key: const ValueKey('finding-save'),
          label: s.save,
          loading: _saving,
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }

  List<Widget> _kindFields(ThemeData theme, AppStrings s) {
    switch (_kind) {
      case FindingKind.caries:
        return [
          FormSection(
            title: ChartStrings.icdasSeverity,
            children: [
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final code in IcdasCode.values)
                    if (code != IcdasCode.sound)
                      ChoiceChip(
                        key: ValueKey('finding-icdas-${code.code}'),
                        label: Text('${code.code}'),
                        tooltip: code.description,
                        selected: _icdas == code,
                        onSelected: (_) => setState(
                          () => _icdas = _icdas == code ? null : code,
                        ),
                      ),
                ],
              ),
              if (_icdas != null)
                Text(_icdas!.description, style: theme.textTheme.bodySmall),
            ],
          ),
          const FormGap(),
          FormSection(
            title: s.surface,
            children: [
              SurfacePicker(
                tooth: widget.tooth,
                value: _surfaces,
                onChanged: (v) => setState(() => _surfaces = v),
              ),
            ],
          ),
        ];
      case FindingKind.fracture:
        return [
          FormSection(
            title: s.surface,
            description: s.optional,
            children: [
              SurfacePicker(
                tooth: widget.tooth,
                value: _surfaces,
                onChanged: (v) => setState(() => _surfaces = v),
              ),
            ],
          ),
        ];
      case FindingKind.mobility:
        return [
          FormSection(
            title: ChartStrings.mobilityGrade,
            children: [
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  for (final grade in MobilityGrade.values)
                    if (grade != MobilityGrade.none)
                      ChoiceChip(
                        key: ValueKey('finding-mobility-${grade.value}'),
                        label: Text('${grade.value}'),
                        selected: _mobility == grade,
                        onSelected: (_) => setState(() => _mobility = grade),
                      ),
                ],
              ),
            ],
          ),
        ];
      case FindingKind.missing:
        return [
          SwitchListTile(
            key: const ValueKey('finding-mark-missing'),
            contentPadding: EdgeInsets.zero,
            title: Text(ChartStrings.alsoMarkMissing),
            value: _markMissing,
            onChanged: (v) => setState(() => _markMissing = v),
          ),
        ];
      case FindingKind.other:
        final results = _icdQuery.trim().isEmpty
            ? const <Icd10Code>[]
            : searchIcd10(_icdQuery).take(8).toList();
        return [
          SearchField(
            key: const ValueKey('finding-icd-search'),
            hintText: ChartStrings.searchIcd10,
            debounce: Duration.zero,
            onChanged: (q) => setState(() => _icdQuery = q),
          ),
          for (final code in results)
            ListTile(
              key: ValueKey('finding-icd-${code.code}'),
              dense: true,
              leading: Text(code.code, style: theme.textTheme.labelLarge),
              title: Text(code.description),
              selected: _icd10 == code,
              onTap: () => setState(() {
                _icd10 = code;
                _icdQuery = '';
                if (_description.text.trim().isEmpty) {
                  _description.text = code.description;
                }
              }),
            ),
          if (_icd10 != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: [
                  StatusBadge(label: _icd10!.code, tone: BadgeTone.info),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(_icd10!.description)),
                  IconButton(
                    tooltip: s.clear,
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _icd10 = null),
                  ),
                ],
              ),
            ),
          TextField(
            key: const ValueKey('finding-description'),
            controller: _description,
            decoration: InputDecoration(labelText: ChartStrings.description),
            textCapitalization: TextCapitalization.sentences,
          ),
          const FormGap(),
          FormSection(
            title: s.surface,
            description: s.optional,
            children: [
              SurfacePicker(
                tooth: widget.tooth,
                value: _surfaces,
                onChanged: (v) => setState(() => _surfaces = v),
              ),
            ],
          ),
        ];
    }
  }
}
