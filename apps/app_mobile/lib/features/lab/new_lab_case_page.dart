import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_mobile/features/patients/patient_providers.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'lab_actions.dart';
import 'lab_model.dart';
import 'lab_providers.dart';
import 'new_lab_case_fields.dart';

/// New lab case. Without a `patientId` the page first asks for the patient;
/// with a `procedureId` the teeth and case type are prefilled from it.
class NewLabCasePage extends ConsumerStatefulWidget {
  /// Creates the page.
  const NewLabCasePage({super.key, this.patientId, this.procedureId});

  /// Patient, when launched from a patient or procedure.
  final String? patientId;

  /// Procedure the work is for.
  final String? procedureId;

  @override
  ConsumerState<NewLabCasePage> createState() => _NewLabCasePageState();
}

class _NewLabCasePageState extends ConsumerState<NewLabCasePage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _teeth = TextEditingController();
  final TextEditingController _material = TextEditingController();
  final TextEditingController _instructions = TextEditingController();
  final TextEditingController _fee = TextEditingController();
  String? _patientId;
  String? _procedureId;
  String? _labId;
  LabCaseType _caseType = LabCaseType.crownZirconia;
  String? _shade;
  String? _impression;
  bool _prefilled = false;
  bool _saving = false;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _patientId = widget.patientId;
    _procedureId = widget.procedureId;
  }

  @override
  void dispose() {
    for (final c in [_teeth, _material, _instructions, _fee]) {
      c.dispose();
    }
    super.dispose();
  }

  void _applyProcedure(ProcedureRecord? p) {
    _procedureId = p?.id;
    if (p == null) return;
    final teeth = p.teeth.isNotEmpty
        ? p.teeth
        : [if (p.tooth != null) p.tooth!];
    _teeth.text = teeth.map((t) => t.storageKey).join(', ');
    final type = labCaseTypeForProcedureCode(p.code);
    if (type != null) _caseType = type;
  }

  void _prefillOnce(List<ProcedureRecord> procedures, List<Lab> labs) {
    if (_prefilled) return;
    _prefilled = true;
    _labId ??= labs.isEmpty ? null : labs.first.id;
    if (_procedureId != null) {
      final match = procedures.where((p) => p.id == _procedureId);
      if (match.isNotEmpty) _applyProcedure(match.first);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final patientId = _patientId;
    final labId = _labId;
    if (patientId == null || labId == null) return;
    setState(() => _saving = true);
    final ctx = ref.read(actorContextProvider);
    final now = ref.read(clockProvider)().toUtc();
    final feeText = _fee.text.trim();
    final labCase = LabCase(
      id: newId(),
      clinicId: ctx.clinicId,
      patientId: patientId,
      procedureId: _procedureId,
      labId: labId,
      caseType: _caseType,
      teeth: parseTeethInput(_teeth.text) ?? const [],
      material: _material.text.trim().isEmpty ? null : _material.text.trim(),
      shade: _shade,
      impressionType: _impression,
      instructions: _instructions.text.trim().isEmpty
          ? null
          : _instructions.text.trim(),
      labFee: feeText.isEmpty
          ? const Money.zero()
          : Money.tryParse(feeText) ?? const Money.zero(),
      createdAt: now,
      updatedAt: now,
    );
    try {
      final created = await ref.read(labCaseActionsProvider).create(labCase);
      ref.invalidate(patientLabCasesProvider(patientId));
      if (!mounted) return;
      context.pushReplacement('/lab/${created.id}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final patientId = _patientId;
    return Scaffold(
      appBar: AppBar(title: Text('New ${s.labCase.toLowerCase()}')),
      body: patientId == null
          ? _PatientPicker(
              query: _search,
              onQuery: (q) => setState(() => _search = q),
              onPick: (p) => setState(() => _patientId = p.id),
            )
          : _buildForm(context, patientId),
    );
  }

  Widget _buildForm(BuildContext context, String patientId) {
    final s = context.strings;
    final patient = ref.watch(patientProvider(patientId)).value;
    final labs = ref.watch(labDirectoryProvider).value;
    final procedures = ref.watch(patientProceduresProvider(patientId)).value;
    final notation = ref.watch(notationProvider);
    if (labs == null || procedures == null) {
      return const Center(child: CircularProgressIndicator());
    }
    _prefillOnce(procedures, labs);
    if (labs.isEmpty) {
      return EmptyState(
        icon: Icons.science_outlined,
        title: 'No lab yet',
        message: 'Add a lab under Lab > Labs before creating a case.',
        action: FilledButton(
          onPressed: () => context.pop(),
          child: Text(s.back),
        ),
      );
    }
    final candidates = procedures
        .where(
          (p) =>
              p.status != ProcedureStatus.deleted &&
              (procedureNeedsLab(p.code) || p.id == _procedureId),
        )
        .toList();
    final lab = labs.where((l) => l.id == _labId).firstOrNull;
    final turnaround = lab?.turnaroundFor(_caseType);
    final now = ref.watch(clockProvider)();
    return Form(
      key: _formKey,
      child: ListView(
        padding: AppSpacing.screenPadding,
        children: [
          if (patient != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_outline),
              title: Text(patient.displayName),
              subtitle: Text(AppFormat.phone(patient.phone)),
              trailing: widget.patientId == null
                  ? TextButton(
                      onPressed: () => setState(() => _patientId = null),
                      child: Text(s.edit),
                    )
                  : null,
            ),
          LabCaseSourceFields(
            labs: labs,
            labId: _labId,
            onLabChanged: (v) => setState(() => _labId = v),
            caseType: _caseType,
            onCaseTypeChanged: (v) => setState(() => _caseType = v),
            procedures: candidates,
            procedureId: _procedureId,
            onProcedureChanged: (id) => setState(
              () => _applyProcedure(
                candidates.where((p) => p.id == id).firstOrNull,
              ),
            ),
            notation: notation,
          ),
          if (turnaround != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                'If sent today, due ${AppFormat.date(computeDueDate(now, turnaround))} '
                '($turnaround working days, Sundays skipped)',
                key: const ValueKey('labcase-due-preview'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          LabCaseSpecFields(
            teeth: _teeth,
            material: _material,
            caseType: _caseType,
            shade: _shade,
            onShadeChanged: (v) => setState(() => _shade = v),
            impressionType: _impression,
            onImpressionChanged: (v) => setState(() => _impression = v),
            instructions: _instructions,
            fee: _fee,
          ),
          const SizedBox(height: AppSpacing.xl),
          BigActionButton(
            key: const ValueKey('labcase-save'),
            label: s.save,
            icon: Icons.check,
            loading: _saving,
            onPressed: _saving ? null : _save,
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

class _PatientPicker extends ConsumerWidget {
  const _PatientPicker({
    required this.query,
    required this.onQuery,
    required this.onPick,
  });

  final String query;
  final ValueChanged<String> onQuery;
  final ValueChanged<Patient> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings;
    final results = ref.watch(patientSearchProvider(query)).value ?? const [];
    return Column(
      children: [
        Padding(
          padding: AppSpacing.screenPadding,
          child: SearchField(
            key: const ValueKey('labcase-patient-search'),
            hintText: s.searchPatientsHint,
            onChanged: onQuery,
            autofocus: true,
          ),
        ),
        Expanded(
          child: results.isEmpty
              ? EmptyState(icon: Icons.person_search, title: s.noResults)
              : ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (context, i) {
                    final p = results[i];
                    return ListTile(
                      key: ValueKey('labcase-patient-${p.id}'),
                      title: Text(p.displayName),
                      subtitle: Text(AppFormat.phone(p.phone)),
                      onTap: () => onPick(p),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
