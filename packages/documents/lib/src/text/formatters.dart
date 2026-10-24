import 'package:ampdent_core/ampdent_core.dart';
import 'package:intl/intl.dart';

final DateFormat _dateFormat = DateFormat('dd MMM yyyy');
final DateFormat _dateTimeFormat = DateFormat('dd MMM yyyy, HH:mm');

/// Formats a date as `18 Oct 2026`.
String formatDate(DateTime value) => _dateFormat.format(value);

/// Formats a timestamp as `18 Oct 2026, 14:05`.
String formatDateTime(DateTime value) => _dateTimeFormat.format(value);

/// Formats an optional date, returning [fallback] for null.
String formatDateOrDash(DateTime? value, {String fallback = '-'}) =>
    value == null ? fallback : formatDate(value);

/// Formats money with the rupee sign and Indian grouping, e.g. `₹1,25,000.00`.
String formatMoney(Money value) => value.format();

/// Formats a tooth in the clinic's display notation as plain text (no Palmer
/// glyphs, which PDF fonts may lack).
String formatTooth(ToothId tooth, ToothNotation notation) =>
    notation.formatPlain(tooth);

/// Formats a list of teeth in the clinic's display notation; [fallback] when
/// empty.
String formatTeeth(
  Iterable<ToothId> teeth,
  ToothNotation notation, {
  String fallback = '-',
}) {
  if (teeth.isEmpty) return fallback;
  return notation.formatAll(teeth, plain: true);
}

/// Formats a tooth plus its surfaces, e.g. `16 (MOD)`.
String formatToothSurfaces(
  ToothId? tooth,
  SurfaceSet surfaces,
  ToothNotation notation,
) {
  if (tooth == null) return surfaces.isEmpty ? '-' : surfaces.code;
  final base = formatTooth(tooth, notation);
  return surfaces.isEmpty ? base : '$base (${surfaces.labelFor(tooth)})';
}

/// Patient age as `34 y`, `6 y 3 m` for under-twelves, or `-` when unknown.
String formatAge(Patient patient, DateTime asOf) {
  final years = patient.ageYears(asOf);
  if (years == null) return '-';
  final whole = years.floor();
  if (whole < 12) {
    final months = ((years - whole) * 12).floor();
    return months == 0 ? '$whole y' : '$whole y $months m';
  }
  return '$whole y';
}

/// Sex as a single word for document headers.
String formatSex(Sex sex) => switch (sex) {
  Sex.male => 'Male',
  Sex.female => 'Female',
  Sex.other => 'Other',
  Sex.unspecified => '-',
};

/// `34 y / Male` style demographics line.
String formatAgeSex(Patient patient, DateTime asOf) =>
    '${formatAge(patient, asOf)} / ${formatSex(patient.sex)}';

/// Patient postal address on one line, or empty when none is recorded.
String formatPatientAddress(Patient patient) {
  final parts = <String>[
    ...patient.addressLines.where((l) => l.trim().isNotEmpty),
    if (patient.city != null && patient.city!.isNotEmpty) patient.city!,
    if (patient.pincode != null && patient.pincode!.isNotEmpty)
      patient.pincode!,
  ];
  return parts.join(', ');
}

/// Clinic postal address on one line.
String formatClinicAddress(Clinic clinic) {
  final parts = <String>[
    ...clinic.addressLines.where((l) => l.trim().isNotEmpty),
    clinic.city,
    clinic.pincode,
  ];
  return parts.join(', ');
}

/// Converts a camelCase enum name to words, e.g. `crownZirconia` to
/// `Crown zirconia`, `inProgress` to `In progress`.
String humanizeEnumName(String name) {
  final spaced = name.replaceAllMapped(
    RegExp('([a-z0-9])([A-Z])'),
    (m) => '${m.group(1)} ${m.group(2)!.toLowerCase()}',
  );
  if (spaced.isEmpty) return spaced;
  return spaced[0].toUpperCase() + spaced.substring(1);
}

/// Formats a GST rate as `18%` or `5%`, dropping a trailing `.0`.
String formatPercent(num rate) {
  if (rate == rate.roundToDouble()) return '${rate.toInt()}%';
  return '$rate%';
}

/// Payment method label as printed on receipts (`UPI`, `Net banking`, `EMI`).
String formatPaymentMethod(PaymentMethod method) => switch (method) {
  PaymentMethod.cash => 'Cash',
  PaymentMethod.upi => 'UPI',
  PaymentMethod.card => 'Card',
  PaymentMethod.netBanking => 'Net banking',
  PaymentMethod.emi => 'EMI',
  PaymentMethod.cheque => 'Cheque',
  PaymentMethod.wallet => 'Wallet',
  PaymentMethod.other => 'Other',
};
