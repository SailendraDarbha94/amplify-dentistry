import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_messaging/ampdent_messaging.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_mobile/features/onboarding/onboarding_draft.dart';
import 'package:ampdent_mobile/features/recall/patient_messenger.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'lab_model.dart';
import 'lab_providers.dart';

/// Labs the clinic works with: name, WhatsApp and per-case-type turnaround.
class LabDirectoryList extends ConsumerWidget {
  /// Creates the list.
  const LabDirectoryList({super.key});

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
      builder: (_) => LabEditSheet(clinicId: ctx.clinicId, existing: existing),
    );
    if (lab == null) return;
    await ref.read(labRepositoryProvider).upsertLab(ctx, lab);
    ref.invalidate(labDirectoryProvider);
    ref.invalidate(labProvider(lab.id));
  }

  Future<void> _whatsapp(WidgetRef ref, Lab lab) async {
    final phone = PhoneNumbers.tryNormaliseIndian(
      lab.whatsappPhone ?? lab.phone ?? '',
    );
    if (phone == null) return;
    await ref.read(linkLauncherProvider)(whatsappDeepLink(phone, ''));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings;
    final labs = ref.watch(labDirectoryProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('labs-dir-add'),
        onPressed: () => _edit(context, ref),
        icon: const Icon(Icons.add),
        label: Text('${s.add} ${s.lab.toLowerCase()}'),
      ),
      body: labs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(labDirectoryProvider),
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
                  final days = lab.turnaroundDays.values.toSet().toList()
                    ..sort();
                  final turnaround = days.isEmpty
                      ? 'Turnaround not set'
                      : days.length == 1
                      ? '${days.single} working days'
                      : '${days.first}-${days.last} working days';
                  return ListTile(
                    key: ValueKey('labs-dir-row-${lab.id}'),
                    leading: const Icon(Icons.science_outlined),
                    title: Text(lab.name),
                    subtitle: Text(
                      [
                        if (lab.whatsappPhone != null)
                          'WA ${AppFormat.phone(lab.whatsappPhone!)}'
                        else if (lab.phone != null)
                          AppFormat.phone(lab.phone!),
                        turnaround,
                      ].join('  ·  '),
                    ),
                    trailing: IconButton(
                      tooltip: 'WhatsApp lab',
                      icon: const Icon(Icons.chat_outlined),
                      onPressed: lab.whatsappPhone == null && lab.phone == null
                          ? null
                          : () => _whatsapp(ref, lab),
                    ),
                    onTap: () => _edit(context, ref, existing: lab),
                  );
                },
              ),
      ),
    );
  }
}

/// Bottom sheet to add or edit a lab with per-case-type turnaround days.
/// Pops with the lab to save.
class LabEditSheet extends StatefulWidget {
  /// Creates the sheet.
  const LabEditSheet({super.key, required this.clinicId, this.existing});

  /// Owning clinic.
  final String clinicId;

  /// Lab being edited, or null to add one.
  final Lab? existing;

  /// Turnaround applied to a type the lab has none for.
  static const int defaultDays = 7;

  @override
  State<LabEditSheet> createState() => _LabEditSheetState();
}

class _LabEditSheetState extends State<LabEditSheet> {
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
  late final Map<LabCaseType, TextEditingController> _days = {
    for (final t in LabCaseType.values)
      t: TextEditingController(
        text: (widget.existing?.turnaroundFor(t) ?? LabEditSheet.defaultDays)
            .toString(),
      ),
  };

  @override
  void dispose() {
    for (final c in [_name, _phone, _whatsapp, ..._days.values]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _validateDays(String? v) {
    final n = int.tryParse((v ?? '').trim());
    return n == null || n < 1 || n > 90 ? '1-90' : null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final e = widget.existing;
    String? phoneOrNull(TextEditingController c) => c.text.trim().isEmpty
        ? null
        : OnboardingValidators.normalisePhone(c.text);
    Navigator.of(context).pop(
      Lab(
        id: e?.id ?? newId(),
        clinicId: widget.clinicId,
        name: _name.text.trim(),
        phone: phoneOrNull(_phone),
        whatsappPhone: phoneOrNull(_whatsapp),
        turnaroundDays: {
          for (final entry in _days.entries)
            entry.key.name: int.parse(entry.value.text.trim()),
        },
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
              key: const ValueKey('lab-edit-name'),
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
                  decoration: InputDecoration(labelText: s.phone),
                  keyboardType: TextInputType.phone,
                  validator: (v) =>
                      OnboardingValidators.phone(v, optional: true),
                ),
                TextFormField(
                  key: const ValueKey('lab-edit-whatsapp'),
                  controller: _whatsapp,
                  decoration: const InputDecoration(labelText: 'WhatsApp'),
                  keyboardType: TextInputType.phone,
                  validator: (v) =>
                      OnboardingValidators.indianMobile(v, optional: true),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            FormSection(
              title: 'Turnaround (working days)',
              description: 'Due dates skip Sundays and clinic holidays.',
              gap: AppSpacing.sm,
              children: [
                for (final t in LabCaseType.values)
                  Row(
                    children: [
                      Expanded(child: Text(labCaseTypeLabel(t))),
                      SizedBox(
                        width: 88,
                        child: TextFormField(
                          key: ValueKey('lab-edit-days-${t.name}'),
                          controller: _days[t],
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(isDense: true),
                          validator: _validateDays,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            BigActionButton(
              key: const ValueKey('lab-edit-save'),
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
