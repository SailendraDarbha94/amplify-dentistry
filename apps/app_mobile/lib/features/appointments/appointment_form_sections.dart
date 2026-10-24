import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';

import 'appointment_form_model.dart';

/// Shows the chosen patient or a prompt to choose one.
class PatientTile extends StatelessWidget {
  /// Creates the tile.
  const PatientTile({super.key, required this.patient, required this.onTap});

  /// Chosen patient, if any.
  final Patient? patient;

  /// Opens the picker.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final p = patient;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        key: const ValueKey('appointment-patient'),
        leading: CircleAvatar(
          child: Icon(p == null ? Icons.person_search : Icons.person),
        ),
        title: Text(p?.displayName ?? 'Choose a patient'),
        subtitle: p == null
            ? Text('Search or quick-add with ${s.name.toLowerCase()} and phone')
            : Text('${p.patientNumber} · ${AppFormat.phone(p.phone)}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

/// Date, time, duration, chair and dentist pickers.
class SlotSection extends StatelessWidget {
  /// Creates the section.
  const SlotSection({
    super.key,
    required this.draft,
    required this.chairs,
    required this.clinicians,
    required this.onStartChanged,
    required this.onDurationChanged,
    required this.onChairChanged,
    required this.onProviderChanged,
  });

  /// Current draft.
  final AppointmentDraft draft;

  /// Active chairs.
  final List<Chair> chairs;

  /// Clinicians to choose from.
  final List<ClinicMember> clinicians;

  /// New local start.
  final ValueChanged<DateTime> onStartChanged;

  /// New duration in minutes.
  final ValueChanged<int> onDurationChanged;

  /// New chair id (null for none).
  final ValueChanged<String?> onChairChanged;

  /// New provider id.
  final ValueChanged<String> onProviderChanged;

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: draft.startsAt,
      firstDate: DateTime(draft.startsAt.year - 1),
      lastDate: DateTime(draft.startsAt.year + 2),
    );
    if (picked == null) return;
    onStartChanged(
      DateTime(
        picked.year,
        picked.month,
        picked.day,
        draft.startsAt.hour,
        draft.startsAt.minute,
      ),
    );
  }

  Future<void> _pickTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(draft.startsAt),
    );
    if (picked == null) return;
    onStartChanged(
      roundToSlot(
        DateTime(
          draft.startsAt.year,
          draft.startsAt.month,
          draft.startsAt.day,
          picked.hour,
          picked.minute,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final providerValue = clinicians.any((m) => m.id == draft.providerId)
        ? draft.providerId
        : null;
    final chairValue = chairs.any((c) => c.id == draft.chairId)
        ? draft.chairId
        : null;
    return FormSection(
      title: 'Slot',
      children: [
        FormRow(
          children: [
            _PickerTile(
              key: const ValueKey('appointment-date'),
              icon: Icons.calendar_today_outlined,
              label: AppFormat.weekdayDate(draft.startsAt),
              onTap: () => _pickDate(context),
            ),
            _PickerTile(
              key: const ValueKey('appointment-time'),
              icon: Icons.access_time,
              label: AppFormat.time(draft.startsAt),
              onTap: () => _pickTime(context),
            ),
          ],
        ),
        Text('Duration', style: Theme.of(context).textTheme.labelLarge),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            for (final m in appointmentDurationChoices)
              ChoiceChip(
                key: ValueKey('appointment-duration-$m'),
                label: Text('$m min'),
                selected: draft.durationMinutes == m,
                onSelected: (_) => onDurationChanged(m),
              ),
            if (!appointmentDurationChoices.contains(draft.durationMinutes))
              ChoiceChip(
                label: Text('${draft.durationMinutes} min'),
                selected: true,
                onSelected: (_) {},
              ),
          ],
        ),
        Text(
          'Ends ${AppFormat.time(draft.endsAt)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        DropdownButtonFormField<String?>(
          key: const ValueKey('appointment-chair'),
          initialValue: chairValue,
          decoration: const InputDecoration(labelText: 'Chair'),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('No chair'),
            ),
            for (final c in chairs)
              DropdownMenuItem<String?>(value: c.id, child: Text(c.name)),
          ],
          onChanged: onChairChanged,
        ),
        DropdownButtonFormField<String>(
          key: const ValueKey('appointment-provider'),
          initialValue: providerValue,
          decoration: const InputDecoration(labelText: 'Dentist'),
          items: [
            for (final m in clinicians)
              DropdownMenuItem<String>(value: m.id, child: Text(m.displayName)),
          ],
          onChanged: (v) {
            if (v != null) onProviderChanged(v);
          },
        ),
      ],
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 18),
    label: Text(label, overflow: TextOverflow.ellipsis),
  );
}

/// Warns about appointments that clash with the chosen slot.
class ConflictWarning extends StatelessWidget {
  /// Creates the warning.
  const ConflictWarning({
    super.key,
    required this.conflicts,
    required this.patients,
    required this.chairs,
  });

  /// Clashing appointments.
  final List<Appointment> conflicts;

  /// Patients of the clashing appointments.
  final Map<String, Patient> patients;

  /// Chairs, for names.
  final List<Chair> chairs;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final s = context.strings;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.warning.withValues(alpha: 0.12),
        borderRadius: AppRadii.mdAll,
        border: Border.all(color: colors.warning),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: colors.warning),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Clashes with ${conflicts.length} '
                  '${conflicts.length == 1 ? 'appointment' : 'appointments'}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final a in conflicts)
            Text(
              '${AppFormat.time(a.startsAt)} – ${AppFormat.time(a.endsAt)} · '
              '${patients[a.patientId]?.displayName ?? s.patient}'
              '${_chairName(a.chairId)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }

  String _chairName(String? chairId) {
    if (chairId == null) return '';
    final chair = chairs.where((c) => c.id == chairId).firstOrNull;
    return chair == null ? '' : ' · ${chair.name}';
  }
}

/// Planned procedures on the slot with add / remove.
class WorkSection extends StatelessWidget {
  /// Creates the section.
  const WorkSection({
    super.key,
    required this.work,
    required this.onAdd,
    required this.onRemove,
  });

  /// Chosen work.
  final List<PlannedWork> work;

  /// Opens the procedure picker.
  final VoidCallback onAdd;

  /// Removes one item.
  final ValueChanged<PlannedWork> onRemove;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    return FormSection(
      title: s.procedures,
      trailing: TextButton.icon(
        key: const ValueKey('appointment-add-procedure'),
        onPressed: onAdd,
        icon: const Icon(Icons.add),
        label: Text(s.add),
      ),
      children: [
        if (work.isEmpty)
          Text(
            'Pick from the plan or the catalogue; the duration follows.',
            style: Theme.of(context).textTheme.bodySmall,
          )
        else
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final w in work)
                InputChip(
                  key: ValueKey('appointment-work-${w.procedureId ?? w.code}'),
                  label: Text('${w.label} · ${w.durationMinutes} min'),
                  avatar: Icon(
                    w.procedureId == null
                        ? Icons.menu_book_outlined
                        : Icons.assignment_turned_in_outlined,
                    size: 18,
                  ),
                  onDeleted: () => onRemove(w),
                ),
            ],
          ),
      ],
    );
  }
}
