import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'appointment_form_model.dart';

/// Patients matching the picker's search text (recent ones when blank).
final _pickerSearchProvider = StreamProvider.family<List<Patient>, String>((
  ref,
  query,
) {
  final clinicId = ref.watch(currentClinicIdProvider);
  if (clinicId == null) return Stream.value(const []);
  final q = query.trim();
  return ref
      .watch(patientRepositoryProvider)
      .watchAll(clinicId, query: q.isEmpty ? null : q)
      .map((list) => list.take(30).toList());
});

/// Bottom sheet that finds an existing patient or quick-adds one by name and
/// phone. Resolves with the chosen [Patient] or null.
class PatientPickerSheet extends ConsumerStatefulWidget {
  /// Creates the sheet.
  const PatientPickerSheet({super.key});

  /// Shows the sheet.
  static Future<Patient?> show(BuildContext context) =>
      showModalBottomSheet<Patient>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        useSafeArea: true,
        builder: (_) => const PatientPickerSheet(),
      );

  @override
  ConsumerState<PatientPickerSheet> createState() => _PatientPickerSheetState();
}

class _PatientPickerSheetState extends ConsumerState<PatientPickerSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  String _query = '';
  bool _quickAdd = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final ctx = ref.read(actorContextProvider);
      final patient = await ref
          .read(patientRepositoryProvider)
          .upsert(
            ctx,
            quickAddPatient(
              clinicId: ctx.clinicId,
              name: _name.text,
              phone: _phone.text,
              now: ref.read(clockProvider)(),
            ),
          );
      if (mounted) Navigator.of(context).pop(patient);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final results = ref.watch(_pickerSearchProvider(_query));
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: AppSpacing.horizontalGutter,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _quickAdd ? s.newPatient : s.patient,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  TextButton.icon(
                    key: const ValueKey('picker-toggle-quick-add'),
                    onPressed: () => setState(() => _quickAdd = !_quickAdd),
                    icon: Icon(_quickAdd ? Icons.search : Icons.person_add_alt),
                    label: Text(_quickAdd ? s.search : s.add),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: _quickAdd ? _buildQuickAdd(s) : _buildSearch(s, results),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearch(AppStrings s, AsyncValue<List<Patient>> results) {
    return Column(
      children: [
        Padding(
          padding: AppSpacing.horizontalGutter,
          child: SearchField(
            key: const ValueKey('picker-search'),
            hintText: s.searchPatientsHint,
            autofocus: true,
            onChanged: (q) => setState(() => _query = q),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: results.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorView(message: e.toString()),
            data: (list) => list.isEmpty
                ? EmptyState(
                    icon: Icons.person_search_outlined,
                    title: s.noResults,
                    action: FilledButton.tonalIcon(
                      onPressed: () => setState(() {
                        _quickAdd = true;
                        _name.text = _query.trim();
                      }),
                      icon: const Icon(Icons.person_add_alt),
                      label: Text(s.newPatient),
                    ),
                  )
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final p = list[i];
                      return ListTile(
                        key: ValueKey('picker-patient-${p.id}'),
                        leading: CircleAvatar(
                          child: Text(p.firstName.substring(0, 1)),
                        ),
                        title: Text(p.displayName),
                        subtitle: Text(
                          '${p.patientNumber} · ${AppFormat.phone(p.phone)}',
                        ),
                        onTap: () => Navigator.of(context).pop(p),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAdd(AppStrings s) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: AppSpacing.screenPadding,
        children: [
          TextFormField(
            key: const ValueKey('picker-quick-name'),
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: s.name),
            validator: QuickAddValidators.name,
          ),
          const FormGap(),
          TextFormField(
            key: const ValueKey('picker-quick-phone'),
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(labelText: s.phone, prefixText: '+91 '),
            validator: QuickAddValidators.phone,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Date of birth, address and consents can be completed later on '
            'the patient record. Minors need a guardian before messaging.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.lg),
          BigActionButton(
            key: const ValueKey('picker-quick-save'),
            label: s.save,
            icon: Icons.person_add_alt_1,
            loading: _saving,
            onPressed: _saving ? null : _create,
          ),
        ],
      ),
    );
  }
}
