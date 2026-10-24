import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_data/ampdent_data.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Why a patient is on the ASAP list.
enum WaitlistReason {
  /// A recall that is due or overdue.
  recallDue,

  /// An accepted plan line with no upcoming appointment.
  acceptedUnscheduled,
}

/// One row of the ASAP / waitlist.
class WaitlistEntry {
  /// Creates an entry.
  const WaitlistEntry({
    required this.patient,
    required this.reason,
    required this.title,
    required this.since,
    this.value = const Money.zero(),
    this.procedureId,
  });

  /// Patient to call.
  final Patient patient;

  /// Why they are listed.
  final WaitlistReason reason;

  /// `Hygiene recall` or the procedure name.
  final String title;

  /// Due date (recall) or acceptance date (plan line); drives the sort.
  final DateTime since;

  /// Expected production.
  final Money value;

  /// Planned procedure to preselect when booking.
  final String? procedureId;
}

/// Builds the waitlist: recalls due now plus accepted procedures that no
/// chair-occupying future appointment references. Patients are fetched one
/// by one through the repository (solo clinics; a clinic-wide query lands
/// with the reporting work).
Future<List<WaitlistEntry>> loadWaitlist({
  required String clinicId,
  required DateTime now,
  required PatientRepository patients,
  required RecallRepository recalls,
  required ChartRepository chart,
  required AppointmentRepository appointments,
  int maxPatients = 400,
}) async {
  final entries = <WaitlistEntry>[];
  final cache = <String, Patient?>{};
  Future<Patient?> patientOf(String id) async {
    if (cache.containsKey(id)) return cache[id];
    return cache[id] = await patients.getById(id);
  }

  final due = await recalls.due(clinicId, until: now.toUtc(), limit: 200);
  for (final r in due) {
    final p = await patientOf(r.patientId);
    if (p == null || !p.isActive) continue;
    entries.add(
      WaitlistEntry(
        patient: p,
        reason: WaitlistReason.recallDue,
        title: '${AppFormat.enumLabel(r.type)} recall',
        since: r.dueAt,
        value: r.estimatedValue,
      ),
    );
  }

  final upcoming = await appointments.range(
    clinicId,
    now.toUtc(),
    now.toUtc().add(const Duration(days: 366)),
  );
  final scheduledProcedureIds = <String>{
    for (final a in upcoming)
      if (a.status.occupiesChair) ...a.plannedProcedureIds,
  };
  final all = await patients.search(clinicId, '', limit: maxPatients);
  for (final p in all) {
    cache[p.id] = p;
    final accepted = await chart.proceduresForPatient(
      p.id,
      statuses: const [ProcedureStatus.accepted],
    );
    for (final proc in accepted) {
      if (scheduledProcedureIds.contains(proc.id)) continue;
      entries.add(
        WaitlistEntry(
          patient: p,
          reason: WaitlistReason.acceptedUnscheduled,
          title: proc.name,
          since: proc.acceptedAt ?? proc.plannedAt ?? proc.createdAt,
          value: proc.netFee,
          procedureId: proc.id,
        ),
      );
    }
  }
  entries.sort((a, b) => a.since.compareTo(b.since));
  return entries;
}

/// The ASAP list, re-read each time the sheet opens.
final FutureProvider<List<WaitlistEntry>> waitlistProvider =
    FutureProvider<List<WaitlistEntry>>((ref) {
      final clinicId = ref.watch(currentClinicIdProvider);
      if (clinicId == null) return Future.value(const []);
      return loadWaitlist(
        clinicId: clinicId,
        now: ref.watch(clockProvider)(),
        patients: ref.watch(patientRepositoryProvider),
        recalls: ref.watch(recallRepositoryProvider),
        chart: ref.watch(chartRepositoryProvider),
        appointments: ref.watch(appointmentRepositoryProvider),
      );
    });

/// Read-only ASAP list. [slotAt] and [chairId] prefill the booking form when
/// the sheet was opened from a cancelled slot.
class WaitlistSheet extends ConsumerWidget {
  /// Creates the sheet.
  const WaitlistSheet({super.key, this.slotAt, this.chairId});

  /// Slot to fill, local.
  final DateTime? slotAt;

  /// Chair of the slot to fill.
  final String? chairId;

  /// Shows the sheet.
  static Future<void> show(
    BuildContext context, {
    DateTime? slotAt,
    String? chairId,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => WaitlistSheet(slotAt: slotAt, chairId: chairId),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings;
    final list = ref.watch(waitlistProvider);
    final now = ref.watch(clockProvider)();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      builder: (context, controller) => Column(
        children: [
          Padding(
            padding: AppSpacing.horizontalGutter,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'ASAP list',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: s.retry,
                  onPressed: () => ref.invalidate(waitlistProvider),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          if (slotAt != null)
            Padding(
              padding: AppSpacing.horizontalGutter,
              child: Text(
                'Fill ${AppFormat.weekdayDate(slotAt!)}, '
                '${AppFormat.time(slotAt!)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: list.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorView(
                message: e.toString(),
                onRetry: () => ref.invalidate(waitlistProvider),
              ),
              data: (entries) => entries.isEmpty
                  ? EmptyState(
                      icon: Icons.hourglass_empty,
                      title: s.nothingHere,
                      message:
                          'Recalls that fall due and accepted treatment '
                          'without a slot show up here.',
                    )
                  : ListView.separated(
                      controller: controller,
                      itemCount: entries.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) => _WaitlistTile(
                        entry: entries[i],
                        now: now,
                        slotAt: slotAt,
                        chairId: chairId,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WaitlistTile extends StatelessWidget {
  const _WaitlistTile({
    required this.entry,
    required this.now,
    this.slotAt,
    this.chairId,
  });

  final WaitlistEntry entry;
  final DateTime now;
  final DateTime? slotAt;
  final String? chairId;

  @override
  Widget build(BuildContext context) {
    final overdue = entry.since.isBefore(now);
    final tone = switch (entry.reason) {
      WaitlistReason.recallDue => overdue ? BadgeTone.danger : BadgeTone.info,
      WaitlistReason.acceptedUnscheduled => BadgeTone.planned,
    };
    final badge = switch (entry.reason) {
      WaitlistReason.recallDue => overdue ? context.strings.overdue : 'Due',
      WaitlistReason.acceptedUnscheduled => context.strings.accepted,
    };
    final query = <String, String>{
      'patientId': entry.patient.id,
      'at': ?slotAt?.toIso8601String(),
      'chairId': ?chairId,
      'procedureId': ?entry.procedureId,
    };
    return ListTile(
      key: ValueKey('waitlist-${entry.patient.id}-${entry.title}'),
      title: Text(entry.patient.displayName),
      subtitle: Text(
        '${entry.title} · ${AppFormat.date(entry.since)}'
        '${entry.value.paise > 0 ? ' · ${AppFormat.money(entry.value, showPaise: false)}' : ''}',
      ),
      trailing: StatusBadge(label: badge, tone: tone, dense: true),
      onTap: () {
        Navigator.of(context).pop();
        context.push(
          Uri(path: '/schedule/new', queryParameters: query).toString(),
        );
      },
    );
  }
}
