import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_mobile/features/notes/icd10_picker_sheet.dart';
import 'package:ampdent_mobile/features/notes/note_editor_model.dart'
    show icd10Label;
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'allergy_block_dialog.dart';
import 'drug_search_sheet.dart';
import 'prescription_issuer.dart';
import 'prescription_providers.dart';
import 'rx_line_sheet.dart';
import 'rx_line_tile.dart';
import 'rx_model.dart';

/// Composes a prescription: diagnosis with optional ICD-10 codes, drug lines
/// from the master with auto quantities, allergy soft-block with override
/// reason, Schedule H1 and caution tags, then issues it with a verification
/// code. With [repeatOfId] the lines of an earlier prescription are copied
/// into the draft.
class PrescriptionEditorPage extends ConsumerStatefulWidget {
  /// Creates the editor.
  const PrescriptionEditorPage({
    super.key,
    required this.patientId,
    this.repeatOfId,
  });

  /// Patient.
  final String patientId;

  /// Prescription to repeat, or null.
  final String? repeatOfId;

  @override
  ConsumerState<PrescriptionEditorPage> createState() =>
      _PrescriptionEditorPageState();
}

class _PrescriptionEditorPageState
    extends ConsumerState<PrescriptionEditorPage> {
  RxDraft _draft = const RxDraft();
  final TextEditingController _diagnosis = TextEditingController();
  bool _loadedRepeat = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.repeatOfId != null) _loadRepeat();
  }

  Future<void> _loadRepeat() async {
    final rx = await ref
        .read(prescriptionRepositoryProvider)
        .getPrescription(widget.repeatOfId!);
    final drugs = await ref.read(drugsProvider.future);
    if (!mounted || rx == null) return;
    setState(() {
      _draft = RxDraft.repeatOf(rx, drugs: {for (final d in drugs) d.id: d});
      _diagnosis.text = _draft.diagnosis;
      _loadedRepeat = true;
    });
  }

  @override
  void dispose() {
    _diagnosis.dispose();
    super.dispose();
  }

  bool get _isMinor {
    final patient = ref.read(rxPatientProvider(widget.patientId)).value;
    return patient?.isMinor(ref.read(clockProvider)()) ?? false;
  }

  Future<void> _addDrug() async {
    final drugs = await ref.read(drugsProvider.future);
    if (!mounted) return;
    final history = ref.read(rxMedicalHistoryProvider(widget.patientId)).value;
    final drug = await DrugSearchSheet.show(
      context,
      drugs: drugs,
      history: history,
      isMinor: _isMinor,
    );
    if (drug == null || !mounted) return;
    String? override;
    if (allergyConflicts(history, drug)) {
      override = await AllergyBlockDialog.show(
        context,
        drug: drug,
        matches: matchingAllergies(history, drug),
      );
      if (override == null || !mounted) return;
    }
    final line = await RxLineSheet.show(
      context,
      initial: RxLineDraft.fromDrug(drug).copyWith(overrideReason: override),
    );
    if (line == null || !mounted) return;
    setState(() => _draft = _draft.copyWith(lines: [..._draft.lines, line]));
  }

  Future<void> _editLine(int i) async {
    final edited = await RxLineSheet.show(context, initial: _draft.lines[i]);
    if (edited == null || !mounted) return;
    final lines = [..._draft.lines];
    lines[i] = edited;
    setState(() => _draft = _draft.copyWith(lines: lines));
  }

  void _removeLine(int i) => setState(
    () => _draft = _draft.copyWith(lines: [..._draft.lines]..removeAt(i)),
  );

  Future<void> _pickIcd10() async {
    final code = await Icd10PickerSheet.show(context);
    if (code == null) return;
    final current = _diagnosis.text.trim();
    _diagnosis.text = current.isEmpty
        ? icd10Label(code)
        : '$current; ${icd10Label(code)}';
  }

  Future<void> _save() async {
    if (_saving) return;
    final member = ref.read(currentMemberProvider).value;
    if (member == null) return;
    setState(() => _saving = true);
    try {
      final visit = await ref
          .read(appointmentRepositoryProvider)
          .openVisit(widget.patientId);
      final issuer = PrescriptionIssuer(
        prescriptions: ref.read(prescriptionRepositoryProvider),
        audit: ref.read(auditRepositoryProvider),
        ctx: ref.read(actorContextProvider),
      );
      final rx = await issuer.issue(
        draft: _draft.copyWith(diagnosis: _diagnosis.text),
        patientId: widget.patientId,
        prescriber: member,
        visitId: visit?.id,
        now: ref.read(clockProvider)(),
      );
      if (!mounted) return;
      context.pushReplacement(
        '/patients/${widget.patientId}/prescriptions/${rx.id}',
      );
    } on MissingRegistrationNumber {
      if (mounted) _toast(MobileStrings.registrationNumberRequired);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final history = ref.watch(rxMedicalHistoryProvider(widget.patientId)).value;
    final patient = ref.watch(rxPatientProvider(widget.patientId)).value;
    final minor = patient?.isMinor(ref.watch(clockProvider)()) ?? false;
    if (widget.repeatOfId != null && !_loadedRepeat) {
      return LoadingScaffold(appBar: AppBar(title: Text(s.prescription)));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.repeatOfId == null
              ? 'New prescription'
              : 'Repeat prescription',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: [
          if (patient != null)
            Padding(
              padding: AppSpacing.horizontalGutter,
              child: Wrap(
                spacing: AppSpacing.sm,
                children: [
                  if (minor)
                    const StatusBadge(
                      label: 'Minor: check paediatric doses',
                      tone: BadgeTone.info,
                    ),
                  if (history?.pregnant ?? false)
                    const StatusBadge(
                      label: 'Pregnant: check every drug',
                      tone: BadgeTone.danger,
                    ),
                  if (history != null && history.allergies.isNotEmpty)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: StatusBadge(
                        label:
                            'Allergies: ${history.allergies.map((a) => a.substance).join(', ')}',
                        tone: BadgeTone.danger,
                      ),
                    ),
                ],
              ),
            ),
          Padding(
            padding: AppSpacing.screenPadding,
            child: TextField(
              key: const ValueKey('rx-diagnosis'),
              controller: _diagnosis,
              minLines: 1,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Diagnosis (${s.optional})',
                suffixIcon: IconButton(
                  key: const ValueKey('rx-icd10'),
                  tooltip: 'ICD-10',
                  icon: const Icon(Icons.manage_search),
                  onPressed: _pickIcd10,
                ),
              ),
            ),
          ),
          if (_draft.hasScheduleH1)
            Container(
              key: const ValueKey('rx-h1-summary'),
              margin: AppSpacing.horizontalGutter,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: colors.warning.withValues(alpha: 0.15),
                borderRadius: AppRadii.mdAll,
                border: Border.all(color: colors.warning),
              ),
              child: Row(
                children: [
                  Icon(Icons.verified_user_outlined, color: colors.warning),
                  const SizedBox(width: AppSpacing.sm),
                  const Expanded(
                    child: Text(
                      'Contains Schedule H1 drugs: the pharmacist must keep '
                      'a register entry with this prescription.',
                    ),
                  ),
                ],
              ),
            ),
          if (_draft.lines.isEmpty)
            const Padding(
              padding: AppSpacing.screenPadding,
              child: EmptyState(
                icon: Icons.medication_outlined,
                title: 'No drugs yet',
                message:
                    'Add from the drug master; quantities are computed '
                    'from dose, frequency and days.',
              ),
            )
          else
            for (var i = 0; i < _draft.lines.length; i++)
              RxLineTile(
                index: i + 1,
                line: _draft.lines[i],
                cautions: [
                  if (_draft.lines[i].pregnancyCaution &&
                      (history?.pregnant ?? false))
                    'Pregnancy caution',
                  if (_draft.lines[i].pediatricCaution && minor)
                    'Paediatric caution',
                ],
                onTap: () => _editLine(i),
                onRemove: () => _removeLine(i),
              ),
          Padding(
            padding: AppSpacing.screenPadding,
            child: OutlinedButton.icon(
              key: const ValueKey('rx-add-drug'),
              icon: const Icon(Icons.add),
              label: const Text('Add drug'),
              onPressed: _addDrug,
            ),
          ),
          SwitchListTile(
            key: const ValueKey('rx-repeatable'),
            title: const Text('Repeatable'),
            subtitle: const Text('Patient may refill without a new visit'),
            value: _draft.isRepeatable,
            onChanged: (v) =>
                setState(() => _draft = _draft.copyWith(isRepeatable: v)),
          ),
          SwitchListTile(
            key: const ValueKey('rx-dispensed'),
            title: const Text('Dispensed by clinic'),
            value: _draft.dispensedByClinic,
            onChanged: (v) =>
                setState(() => _draft = _draft.copyWith(dispensedByClinic: v)),
          ),
          Padding(
            padding: AppSpacing.horizontalGutter,
            child: Text(
              'Issued with your name, qualifications and registration '
              'number, plus a 6-character verification code.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: AppSpacing.screenPadding,
        child: BigActionButton(
          key: const ValueKey('rx-save'),
          label: 'Issue prescription',
          icon: Icons.check,
          loading: _saving,
          onPressed: _draft.lines.isEmpty || _saving ? null : _save,
        ),
      ),
    );
  }
}
