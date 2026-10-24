import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'appointment_details_section.dart';
import 'appointment_form_model.dart';
import 'appointment_form_sections.dart';
import 'appointment_providers.dart';
import 'patient_picker_sheet.dart';
import 'procedure_picker_sheet.dart';

/// Books a new appointment. Query parameters prefill the draft:
/// `patientId`, `at` (ISO local), `chairId`, `procedureId`.
class AppointmentFormPage extends ConsumerStatefulWidget {
  /// Creates the page.
  const AppointmentFormPage({
    super.key,
    this.patientId,
    this.at,
    this.chairId,
    this.procedureId,
  });

  /// Preselected patient.
  final String? patientId;

  /// Preselected start, ISO-8601 local.
  final String? at;

  /// Preselected chair.
  final String? chairId;

  /// Planned procedure to add to the slot.
  final String? procedureId;

  @override
  ConsumerState<AppointmentFormPage> createState() =>
      _AppointmentFormPageState();
}

class _AppointmentFormPageState extends ConsumerState<AppointmentFormPage> {
  AppointmentDraft? _draft;
  List<Appointment> _conflicts = const [];
  int _conflictTicket = 0;
  bool _durationTouched = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_init);
  }

  Future<void> _init() async {
    final now = ref.read(clockProvider)();
    final parsedAt = widget.at == null ? null : DateTime.tryParse(widget.at!);
    final startsAt = roundToSlot(
      parsedAt ?? now.add(const Duration(minutes: 10)),
    );
    Patient? patient;
    if (widget.patientId != null) {
      patient = await ref
          .read(patientRepositoryProvider)
          .getById(widget.patientId!);
    }
    final work = <PlannedWork>[];
    if (widget.procedureId != null) {
      final proc = await ref
          .read(chartRepositoryProvider)
          .getProcedure(widget.procedureId!);
      if (proc != null) {
        final catalogue = await ref.read(catalogByIdProvider.future);
        work.add(
          PlannedWork.fromProcedure(
            proc,
            notation: ref.read(notationProvider),
            catalogItem: catalogue[proc.catalogItemId],
          ),
        );
      }
    }
    final member = ref.read(appSessionProvider).memberId;
    final clinicians = ref.read(cliniciansProvider);
    final providerId = clinicians.any((m) => m.id == member)
        ? member
        : clinicians.isNotEmpty
        ? clinicians.first.id
        : member;
    final chairs = ref.read(chairsProvider).value ?? const <Chair>[];
    final chairId =
        widget.chairId ?? (chairs.isNotEmpty ? chairs.first.id : null);
    if (!mounted) return;
    setState(() {
      _draft = AppointmentDraft(
        patient: patient,
        providerId: providerId,
        chairId: chairId,
        startsAt: startsAt,
        durationMinutes: defaultDurationFor(work),
        work: work,
      );
    });
    await _refreshConflicts();
  }

  void _update(AppointmentDraft Function(AppointmentDraft) change) {
    final current = _draft;
    if (current == null) return;
    final next = change(current);
    setState(() {
      _draft = next;
      _error = null;
    });
    final slotChanged =
        next.startsAt != current.startsAt ||
        next.durationMinutes != current.durationMinutes ||
        next.chairId != current.chairId ||
        next.providerId != current.providerId;
    if (slotChanged) _refreshConflicts();
  }

  Future<void> _refreshConflicts() async {
    final draft = _draft;
    if (draft == null) return;
    final ticket = ++_conflictTicket;
    final found = await ref.read(appointmentBookerProvider).conflictsFor(draft);
    if (!mounted || ticket != _conflictTicket) return;
    setState(() => _conflicts = found);
  }

  Future<void> _pickPatient() async {
    final picked = await PatientPickerSheet.show(context);
    if (picked != null) _update((d) => d.copyWith(patient: picked));
  }

  Future<void> _addWork() async {
    final draft = _draft;
    if (draft == null) return;
    final picked = await ProcedurePickerSheet.show(
      context,
      patientId: draft.patient?.id,
      alreadyChosen: {for (final w in draft.work) w.procedureId ?? w.code},
    );
    if (picked == null) return;
    _update((d) {
      final work = [...d.work, picked];
      return d.copyWith(
        work: work,
        durationMinutes: _durationTouched
            ? d.durationMinutes
            : defaultDurationFor(work),
      );
    });
  }

  void _removeWork(PlannedWork w) => _update((d) {
    final work = d.work.where((x) => x != w).toList();
    return d.copyWith(
      work: work,
      durationMinutes: _durationTouched
          ? d.durationMinutes
          : defaultDurationFor(work),
    );
  });

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null) return;
    final problem = draft.validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await ref
          .read(appointmentBookerProvider)
          .save(draft, now: ref.read(clockProvider)());
      ref.read(selectedDayProvider.notifier).select(saved.startsAt.toLocal());
      if (!mounted) return;
      context.go('/schedule/${saved.id}');
    } on Object catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final draft = _draft;
    if (draft == null) {
      return LoadingScaffold(appBar: AppBar(title: Text(s.appointment)));
    }
    final clinicians = ref.watch(cliniciansProvider);
    final chairs = ref.watch(chairsProvider).value ?? const <Chair>[];
    final patientIds = _conflicts.map((a) => a.patientId);
    final conflictPatients =
        ref.watch(patientsByIdsProvider(patientIdsKey(patientIds))).value ??
        const <String, Patient>{};
    return Scaffold(
      appBar: AppBar(title: Text('New ${s.appointment.toLowerCase()}')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: AppSpacing.screenPadding,
                children: [
                  PatientTile(patient: draft.patient, onTap: _pickPatient),
                  const FormGap(height: AppSpacing.lg),
                  SlotSection(
                    draft: draft,
                    chairs: chairs,
                    clinicians: clinicians,
                    onStartChanged: (v) =>
                        _update((d) => d.copyWith(startsAt: v)),
                    onDurationChanged: (v) {
                      _durationTouched = true;
                      _update((d) => d.copyWith(durationMinutes: v));
                    },
                    onChairChanged: (v) =>
                        _update((d) => d.copyWith(chairId: v)),
                    onProviderChanged: (v) =>
                        _update((d) => d.copyWith(providerId: v)),
                  ),
                  if (_conflicts.isNotEmpty) ...[
                    const FormGap(),
                    ConflictWarning(
                      key: const ValueKey('appointment-conflict'),
                      conflicts: _conflicts,
                      patients: conflictPatients,
                      chairs: chairs,
                    ),
                  ],
                  const FormGap(height: AppSpacing.lg),
                  WorkSection(
                    work: draft.work,
                    onAdd: _addWork,
                    onRemove: _removeWork,
                  ),
                  const FormGap(height: AppSpacing.lg),
                  DetailsSection(
                    reason: draft.reason,
                    notes: draft.notes,
                    source: draft.source,
                    onReasonChanged: (v) =>
                        _update((d) => d.copyWith(reason: v)),
                    onNotesChanged: (v) => _update((d) => d.copyWith(notes: v)),
                    onSourceChanged: (v) =>
                        _update((d) => d.copyWith(source: v)),
                  ),
                  if (_error != null) ...[
                    const FormGap(),
                    Text(
                      _error!,
                      key: const ValueKey('appointment-error'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
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
                key: const ValueKey('appointment-save'),
                label: _conflicts.isEmpty
                    ? 'Book ${AppFormat.time(draft.startsAt)}'
                    : 'Book anyway',
                icon: Icons.event_available,
                loading: _saving,
                onPressed: _saving ? null : _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
