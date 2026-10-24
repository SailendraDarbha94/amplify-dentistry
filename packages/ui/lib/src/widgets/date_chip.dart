import 'package:flutter/material.dart';

import '../strings/app_strings.dart';

/// Short English date formatting without `intl`: `Sat 18 Oct`, `18 Oct 2026`.
abstract final class ShortDate {
  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  static const List<String> _weekdays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  /// `18 Oct`.
  static String dayMonth(DateTime d) => '${d.day} ${_months[d.month - 1]}';

  /// `Sat 18 Oct`.
  static String weekdayDayMonth(DateTime d) =>
      '${_weekdays[d.weekday - 1]} ${dayMonth(d)}';

  /// `18 Oct 2026`.
  static String dayMonthYear(DateTime d) => '${dayMonth(d)} ${d.year}';

  /// `Sat` .. `Sun`.
  static String weekday(DateTime d) => _weekdays[d.weekday - 1];

  /// True when both dates fall on the same calendar day.
  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Selectable chip showing a date (`Sat 18 Oct`); "Today" when the date is
/// today. Used in schedule day pickers and recall due-date rows.
class DateChip extends StatelessWidget {
  /// Creates a date chip.
  const DateChip({
    super.key,
    required this.date,
    this.selected = false,
    this.onTap,
    this.label,
    this.showYear = false,
    this.now,
  });

  /// The date to show.
  final DateTime date;

  /// Highlighted state.
  final bool selected;

  /// Tap handler; null makes the chip static.
  final VoidCallback? onTap;

  /// Overrides the formatted text.
  final String? label;

  /// Appends the year.
  final bool showYear;

  /// Reference "now" for the Today check; defaults to the wall clock.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final today = now ?? DateTime.now();
    final text =
        label ??
        (ShortDate.sameDay(date, today)
            ? strings.today
            : showYear
            ? ShortDate.dayMonthYear(date)
            : ShortDate.weekdayDayMonth(date));
    return ChoiceChip(
      label: Text(text),
      avatar: onTap == null
          ? null
          : const Icon(Icons.calendar_today_outlined, size: 16),
      selected: selected,
      onSelected: onTap == null ? null : (_) => onTap!(),
    );
  }
}
