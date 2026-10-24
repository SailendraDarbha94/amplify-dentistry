import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_mobile/features/onboarding/onboarding_draft.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Active labs of the current clinic (refetched after every write).
final FutureProvider<List<Lab>> labsProvider = FutureProvider<List<Lab>>((ref) {
  final clinicId = ref.watch(currentClinicIdProvider);
  if (clinicId == null) return Future.value(const []);
  return ref.watch(labRepositoryProvider).labs(clinicId);
});

/// Builds a turnaround map that applies [days] to every case type.
Map<String, int> uniformTurnaround(int days) => {
  for (final t in LabCaseType.values) t.name: days,
};

/// Dental labs the clinic sends work to, with default turnaround.
class LabsPage extends ConsumerWidget {
  /// Creates the page.
  const LabsPage({super.key});

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, {
    Lab? existing,
  }) async {
    final ctx = ref.read(actorContextProvider);
    final lab = await showModalBottomSheet<Lab>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => LabFormSheet(clinicId: ctx.clinicId, existing: existing),
    );
    if (lab == null) return;
    await ref.read(labRepositoryProvider).upsertLab(ctx, lab);
    ref.invalidate(labsProvider);
  }

  Future<void> _deactivate(BuildContext context, WidgetRef ref, Lab lab) async {
    final ok = await ConfirmSheet.show(
      context,
      title: 'Deactivate ${lab.name}?',
      message: 'Open cases keep the lab; new cases cannot pick it.',
      confirmLabel: 'Deactivate',
      destructive: true,
    );
    if (!ok) return;
    await ref
        .read(labRepositoryProvider)
        .deactivateLab(ref.read(actorContextProvider), lab.id);
    ref.invalidate(labsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings;
    final labs = ref.watch(labsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Labs')),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('labs-add'),
        onPressed: () => _edit(context, ref),
        icon: const Icon(Icons.add),
        label: Text(s.add),
      ),
      body: labs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(labsProvider),
        ),
        data: (list) => list.isEmpty
            ? EmptyState(
                icon: Icons.science_outlined,
                title: s.nothingHere,
                message: 'Add the labs you send crowns and dentures to.',
              )
            : ListView.separated(
                padding: const EdgeInsets.only(bottom: 96),
                itemCount: list.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final lab = list[i];
                  final crown = lab.turnaroundFor(LabCaseType.crownZirconia);
                  return ListTile(
                    key: ValueKey('lab-row-${lab.id}'),
                    leading: const Icon(Icons.science_outlined),
                    title: Text(lab.name),
                    subtitle: Text(
                      [
                        if (lab.phone != null) AppFormat.phone(lab.phone!),
                        if (crown != null) '$crown working days',
                      ].join('  ·  '),
                    ),
                    trailing: IconButton(
                      tooltip: 'Deactivate',
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () => _deactivate(context, ref, lab),
                    ),
                    onTap: () => _edit(context, ref, existing: lab),
                  );
                },
              ),
      ),
    );
  }
}

/// Bottom sheet to add or edit a lab; pops with the lab to save.
class LabFormSheet extends StatefulWidget {
  /// Creates the sheet.
  const LabFormSheet({super.key, required this.clinicId, this.existing});

  /// Owning clinic.
  final String clinicId;

  /// Lab being edited, or null.
  final Lab? existing;

  @override
  State<LabFormSheet> createState() => _LabFormSheetState();
}

class _LabFormSheetState extends State<LabFormSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late final TextEditingController _phone = TextEditingController(
    text: widget.existing?.phone ?? '',
  );
  late final TextEditingController _whatsapp = TextEditingController(
    text: widget.existing?.whatsappPhone ?? '',
  );
  late final TextEditingController _days = TextEditingController(
    text:
        widget.existing?.turnaroundFor(LabCaseType.crownZirconia)?.toString() ??
        '7',
  );

  @override
  void dispose() {
    for (final c in [_name, _phone, _whatsapp, _days]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final e = widget.existing;
    final days = int.parse(_days.text.trim());
    Navigator.of(context).pop(
      Lab(
        id: e?.id ?? newId(),
        clinicId: widget.clinicId,
        name: _name.text.trim(),
        phone: _phone.text.trim().isEmpty
            ? null
            : OnboardingValidators.normalisePhone(_phone.text),
        whatsappPhone: _whatsapp.text.trim().isEmpty
            ? null
            : OnboardingValidators.normalisePhone(_whatsapp.text),
        turnaroundDays: uniformTurnaround(days),
        isActive: e?.isActive ?? true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          padding: AppSpacing.screenPadding,
          children: [
            Text(
              widget.existing == null ? 'Add lab' : 'Edit lab',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              key: const ValueKey('lab-name'),
              controller: _name,
              decoration: const InputDecoration(labelText: 'Lab name'),
              textCapitalization: TextCapitalization.words,
              validator: (v) => OnboardingValidators.required(v, 'Lab name'),
            ),
            const FormGap(),
            FormRow(
              children: [
                TextFormField(
                  controller: _phone,
                  decoration: const InputDecoration(labelText: 'Phone'),
                  keyboardType: TextInputType.phone,
                  validator: (v) =>
                      OnboardingValidators.phone(v, optional: true),
                ),
                TextFormField(
                  controller: _whatsapp,
                  decoration: const InputDecoration(labelText: 'WhatsApp'),
                  keyboardType: TextInputType.phone,
                  validator: (v) =>
                      OnboardingValidators.indianMobile(v, optional: true),
                ),
              ],
            ),
            const FormGap(),
            TextFormField(
              key: const ValueKey('lab-days'),
              controller: _days,
              decoration: const InputDecoration(
                labelText: 'Turnaround (working days)',
                helperText:
                    'Applied to every case type; due dates skip Sundays',
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                final n = int.tryParse((v ?? '').trim());
                return n == null || n < 1 || n > 60 ? 'Enter 1 to 60' : null;
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            BigActionButton(
              key: const ValueKey('lab-save'),
              label: s.save,
              icon: Icons.check,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
