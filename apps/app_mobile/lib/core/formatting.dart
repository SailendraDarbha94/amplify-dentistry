import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:intl/intl.dart';

/// Display formatting shared by every feature. All helpers are static so the
/// names never clash with the PDF formatters in `ampdent_documents`.
abstract final class AppFormat {
  static final DateFormat _date = DateFormat('d MMM yyyy', 'en_IN');
  static final DateFormat _shortDate = DateFormat('d MMM', 'en_IN');
  static final DateFormat _time = DateFormat('h:mm a', 'en_IN');
  static final DateFormat _weekday = DateFormat('EEE', 'en_IN');

  /// `18 Oct 2026`.
  static String date(DateTime value) => _date.format(value.toLocal());

  /// `18 Oct`.
  static String shortDate(DateTime value) => _shortDate.format(value.toLocal());

  /// `Sun 18 Oct`.
  static String weekdayDate(DateTime value) {
    final local = value.toLocal();
    return '${_weekday.format(local)} ${_shortDate.format(local)}';
  }

  /// `2:05 PM`.
  static String time(DateTime value) => _time.format(value.toLocal());

  /// `18 Oct 2026, 2:05 PM`.
  static String dateTime(DateTime value) => '${date(value)}, ${time(value)}';

  /// Date or a dash when missing.
  static String dateOrDash(DateTime? value) =>
      value == null ? '-' : date(value);

  /// `₹1,25,000.00` using [Money.format].
  static String money(Money value, {bool showPaise = true}) =>
      value.format(showPaise: showPaise);

  /// `+91 98765 43210` or the raw value when it is not an Indian mobile.
  static String phone(String raw) => IndianPhoneFormat.format(raw);

  /// `34 y`, `6 y 3 m`, or `-` when the age is unknown.
  static String age(Patient patient, DateTime asOf) {
    final years = patient.ageYears(asOf);
    if (years == null) return '-';
    if (years >= 10) return '${years.floor()} y';
    final whole = years.floor();
    final months = ((years - whole) * 12).floor();
    return months == 0 ? '$whole y' : '$whole y $months m';
  }

  /// `Male`, `Female`, `Other`, or `-`.
  static String sex(Sex value) => switch (value) {
    Sex.male => 'Male',
    Sex.female => 'Female',
    Sex.other => 'Other',
    Sex.unspecified => '-',
  };

  /// `34 y / Male`; omits the sex when unspecified.
  static String ageSex(Patient patient, DateTime asOf) {
    final a = age(patient, asOf);
    return patient.sex == Sex.unspecified ? a : '$a / ${sex(patient.sex)}';
  }

  /// `crownZirconia` -> `Crown zirconia`.
  static String enumLabel(Enum value) {
    final name = value.name;
    final spaced = name.replaceAllMapped(
      RegExp('([a-z0-9])([A-Z])'),
      (m) => '${m[1]} ${m[2]!.toLowerCase()}',
    );
    return spaced[0].toUpperCase() + spaced.substring(1);
  }

  /// `18%` or `5.5%`.
  static String percent(num rate) =>
      rate == rate.roundToDouble() ? '${rate.toInt()}%' : '$rate%';
}
