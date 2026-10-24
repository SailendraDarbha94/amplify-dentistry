import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'appointment_form_model.dart';
import 'appointment_providers.dart';

/// Seven day chips (Monday to Sunday) around the selected day with week
/// arrows and a 'Today' shortcut. Dots under a chip mean booked slots.
class WeekStrip extends ConsumerWidget {
  /// Creates the strip.
  const WeekStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings;
    final selected = ref.watch(selectedDayProvider);
    final now = ref.watch(clockProvider)();
    final monday = weekStart(selected);
    final counts =
        ref.watch(weekCountsProvider(dayKey(monday))).value ?? const {};
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
              key: const ValueKey('schedule-prev-week'),
              tooltip: 'Previous week',
              onPressed: () =>
                  ref.read(selectedDayProvider.notifier).shiftWeeks(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                _monthLabel(monday, monday.add(const Duration(days: 6))),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
            ),
            TextButton(
              key: const ValueKey('schedule-today'),
              onPressed: isSameDay(selected, now)
                  ? null
                  : () => ref.read(selectedDayProvider.notifier).today(),
              child: Text(s.today),
            ),
            IconButton(
              key: const ValueKey('schedule-next-week'),
              tooltip: 'Next week',
              onPressed: () =>
                  ref.read(selectedDayProvider.notifier).shiftWeeks(1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        SizedBox(
          height: 72,
          child: Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: _DayCell(
                    day: monday.add(Duration(days: i)),
                    selected: isSameDay(
                      selected,
                      monday.add(Duration(days: i)),
                    ),
                    today: isSameDay(now, monday.add(Duration(days: i))),
                    count: counts[dayKey(monday.add(Duration(days: i)))] ?? 0,
                    onTap: () => ref
                        .read(selectedDayProvider.notifier)
                        .select(monday.add(Duration(days: i))),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static String _monthLabel(DateTime from, DateTime to) {
    final a = ShortDate.dayMonth(from);
    final b = ShortDate.dayMonth(to);
    return '$a – $b ${to.year}';
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.selected,
    required this.today,
    required this.count,
    required this.onTap,
  });

  final DateTime day;
  final bool selected;
  final bool today;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final fg = selected ? scheme.onPrimary : scheme.onSurface;
    return Semantics(
      button: true,
      selected: selected,
      label: ShortDate.weekdayDayMonth(day),
      child: InkWell(
        key: ValueKey('schedule-day-${dayKey(day)}'),
        onTap: onTap,
        borderRadius: AppRadii.mdAll,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          decoration: BoxDecoration(
            color: selected ? scheme.primary : null,
            borderRadius: AppRadii.mdAll,
            border: today && !selected
                ? Border.all(color: scheme.primary, width: 1.5)
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                ShortDate.weekday(day).substring(0, 1),
                style: text.labelSmall?.copyWith(color: fg),
              ),
              Text(
                '${day.day}',
                style: text.titleMedium?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(
                height: 6,
                child: count == 0
                    ? null
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < (count > 3 ? 3 : count); i++)
                            Container(
                              width: 4,
                              height: 4,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: selected
                                    ? scheme.onPrimary
                                    : scheme.primary,
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
