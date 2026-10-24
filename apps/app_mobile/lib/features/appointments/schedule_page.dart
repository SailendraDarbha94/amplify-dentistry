import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'appointment_form_model.dart';
import 'appointment_providers.dart';
import 'day_view.dart';
import 'waitlist.dart';
import 'week_strip.dart';

/// The appointment book: week strip, one column per chair, FAB to book.
class SchedulePage extends ConsumerWidget {
  /// Creates the page.
  const SchedulePage({super.key});

  String _newLocation(DateTime at, {String? chairId}) => Uri(
    path: '/schedule/new',
    queryParameters: {'at': at.toIso8601String(), 'chairId': ?chairId},
  ).toString();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings;
    final day = ref.watch(selectedDayProvider);
    final now = ref.watch(clockProvider)();
    final appointments = ref.watch(dayAppointmentsProvider(dayKey(day)));
    final chairs = ref.watch(chairsProvider).value ?? const <Chair>[];
    final members = ref.watch(clinicMembersProvider).value ?? const [];
    final ids = appointments.value?.map((a) => a.patientId) ?? const [];
    final patients =
        ref.watch(patientsByIdsProvider(patientIdsKey(ids))).value ??
        const <String, Patient>{};
    final booked = appointments.value
        ?.where((a) => a.status.occupiesChair)
        .length;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          booked == null
              ? AppFormat.weekdayDate(day)
              : '${AppFormat.weekdayDate(day)} · $booked',
        ),
        actions: [
          IconButton(
            key: const ValueKey('schedule-waitlist'),
            tooltip: 'ASAP list',
            onPressed: () => WaitlistSheet.show(context),
            icon: const Icon(Icons.hourglass_bottom_outlined),
          ),
          IconButton(
            tooltip: 'Pick a date',
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: day,
                firstDate: DateTime(now.year - 1),
                lastDate: DateTime(now.year + 2),
              );
              if (picked != null) {
                ref.read(selectedDayProvider.notifier).select(picked);
              }
            },
            icon: const Icon(Icons.calendar_month_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('schedule-new'),
        onPressed: () => context.push(
          _newLocation(
            isSameDay(day, now)
                ? roundToSlot(now.add(const Duration(minutes: 10)))
                : DateTime(day.year, day.month, day.day, 10),
          ),
        ),
        icon: const Icon(Icons.add),
        label: Text(s.appointment),
      ),
      body: Column(
        children: [
          const WeekStrip(),
          const Divider(height: 1),
          Expanded(
            child: appointments.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorView(
                message: e.toString(),
                onRetry: () =>
                    ref.invalidate(dayAppointmentsProvider(dayKey(day))),
              ),
              data: (list) => DayView(
                key: ValueKey('schedule-day-view-${dayKey(day)}'),
                day: day,
                now: now,
                appointments: list,
                chairs: chairs,
                members: members,
                patients: patients,
                onTapAppointment: (a) => context.push('/schedule/${a.id}'),
                onTapSlot: (at, chairId) =>
                    context.push(_newLocation(at, chairId: chairId)),
                onFillCancelled: (a) => WaitlistSheet.show(
                  context,
                  slotAt: a.startsAt.toLocal(),
                  chairId: a.chairId,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
