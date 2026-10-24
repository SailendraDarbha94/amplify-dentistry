import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'appointment_form_model.dart';
import 'appointment_form_sections.dart';
import 'appointment_providers.dart';

/// Picks a new slot (date, time, duration, chair, dentist) for an existing
/// appointment, warns about clashes and saves the move. Resolves with the
/// updated appointment or null.
class MoveSlotSheet extends ConsumerStatefulWidget {
  /// Creates the sheet.
  const MoveSlotSheet({
    super.key,
    required this.appointment,
    required this.patient,
  });

  /// Appointment being moved.
  final Appointment appointment;

  /// Its patient (for the draft).
  final Patient? patient;

  /// Shows the sheet.
  static Future<Appointment?> show(
    BuildContext context, {
    required Appointment appointment,
    required Patient? patient,
  }) => showModalBottomSheet<Appointment>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => MoveSlotSheet(appointment: appointment, patient: patient),
  );

  @override
  ConsumerState<MoveSlotSheet> createState() => _MoveSlotSheetState();
}

class _MoveSlotSheetState extends ConsumerState<MoveSlotSheet> {
  late AppointmentDraft _draft;
  List<Appointment> _conflicts = const [];
  int _ticket = 0;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _draft = AppointmentDraft.fromAppointment(
      widget.appointment,
      patient: widget.patient,
    );
    Future<void>.microtask(_refresh);
  }

  void _update(AppointmentDraft next) {
    setState(() => _draft = next);
    _refresh();
  }

  Future<void> _refresh() async {
    final ticket = ++_ticket;
    final found = await ref
        .read(appointmentBookerProvider)
        .conflictsFor(_draft, excludeId: widget.appointment.id);
    if (!mounted || ticket != _ticket) return;
    setState(() => _conflicts = found);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final saved = await ref
          .read(appointmentBookerProvider)
          .save(
            _draft,
            existing: widget.appointment,
            now: ref.read(clockProvider)(),
          );
      if (mounted) Navigator.of(context).pop(saved);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clinicians = ref.watch(cliniciansProvider);
    final chairs = ref.watch(chairsProvider).value ?? const <Chair>[];
    final patients =
        ref
            .watch(
              patientsByIdsProvider(
                patientIdsKey(_conflicts.map((a) => a.patientId)),
              ),
            )
            .value ??
        const <String, Patient>{};
    final unchanged =
        _draft.startsAt.toUtc() == widget.appointment.startsAt.toUtc() &&
        _draft.endsAt.toUtc() == widget.appointment.endsAt.toUtc() &&
        _draft.chairId == widget.appointment.chairId &&
        _draft.providerId == widget.appointment.providerId;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: Column(
          children: [
            Padding(
              padding: AppSpacing.horizontalGutter,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Move appointment',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: AppSpacing.screenPadding,
                children: [
                  Text(
                    'Currently ${AppFormat.weekdayDate(widget.appointment.startsAt)}, '
                    '${AppFormat.time(widget.appointment.startsAt)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const FormGap(),
                  SlotSection(
                    draft: _draft,
                    chairs: chairs,
                    clinicians: clinicians,
                    onStartChanged: (v) =>
                        _update(_draft.copyWith(startsAt: v)),
                    onDurationChanged: (v) =>
                        _update(_draft.copyWith(durationMinutes: v)),
                    onChairChanged: (v) => _update(_draft.copyWith(chairId: v)),
                    onProviderChanged: (v) =>
                        _update(_draft.copyWith(providerId: v)),
                  ),
                  if (_conflicts.isNotEmpty) ...[
                    const FormGap(),
                    ConflictWarning(
                      key: const ValueKey('move-conflict'),
                      conflicts: _conflicts,
                      patients: patients,
                      chairs: chairs,
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.sm,
                AppSpacing.gutter,
                AppSpacing.gutter,
              ),
              child: BigActionButton(
                key: const ValueKey('move-save'),
                label: unchanged
                    ? context.strings.save
                    : 'Move to ${AppFormat.weekdayDate(_draft.startsAt)}, '
                          '${AppFormat.time(_draft.startsAt)}',
                icon: Icons.drive_file_move_outline,
                loading: _saving,
                onPressed: _saving || unchanged ? null : _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
