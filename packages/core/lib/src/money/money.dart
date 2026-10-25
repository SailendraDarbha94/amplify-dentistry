import 'package:meta/meta.dart';

/// Indian GST classification of an invoice line. The rate for each class is
/// resolved through [GstRateTable] (clinic configuration with history), never
/// hard-coded at the call site.
enum GstClass {
  /// Health-care services by a registered dentist: exempt (SAC 999312,
  /// Notification 12/2017 entry 74). RCT, extraction, fillings, crowns and
  /// bridges fitted as part of treatment.
  exemptHealthcare('999312', 'Exempt health-care service'),

  /// Purely cosmetic dentistry (bleaching, smile-design veneers; SAC 999722).
  /// Taxable at 18% with ITC or, since 22 Sep 2025, arguably 5% without ITC;
  /// the rate is a clinic setting.
  cosmeticTaxable('999722', 'Cosmetic service (taxable)'),

  /// Goods sold over the counter (HSN 9021 artificial teeth / dental
  /// fittings, 3306 oral hygiene products): 5%.
  goods('9021', 'Goods (HSN)'),

  /// Any other taxable service at the standard rate (18%).
  standardTaxable('9993', 'Taxable service (standard rate)');

  const GstClass(this.defaultCode, this.description);

  /// Default SAC/HSN code; overridable per catalogue item.
  final String defaultCode;
  final String description;
}

/// One GST rate configuration row. Clinics keep a history of these so old
/// invoices recompute identically.
@immutable
class GstRate {
  const GstRate({
    required this.gstClass,
    required this.ratePercent,
    required this.inputTaxCreditAllowed,
    required this.effectiveFrom,
  });

  final GstClass gstClass;

  /// Total GST percentage (CGST + SGST), e.g. 0, 5, 18.
  final num ratePercent;
  final bool inputTaxCreditAllowed;
  final DateTime effectiveFrom;
}

/// Resolves the GST rate for a class at a point in time.
class GstRateTable {
  GstRateTable(Iterable<GstRate> rates)
    : _rates = rates.toList()
        ..sort((a, b) => a.effectiveFrom.compareTo(b.effectiveFrom));

  /// Defaults as of October 2026: exempt 0%, cosmetic 18% with ITC (the
  /// contested 5%-without-ITC reading is opt-in), goods 5%, standard 18%.
  factory GstRateTable.indiaDefaults() {
    final epoch = DateTime.utc(2017, 7, 1);
    return GstRateTable([
      GstRate(
        gstClass: GstClass.exemptHealthcare,
        ratePercent: 0,
        inputTaxCreditAllowed: false,
        effectiveFrom: epoch,
      ),
      GstRate(
        gstClass: GstClass.cosmeticTaxable,
        ratePercent: 18,
        inputTaxCreditAllowed: true,
        effectiveFrom: epoch,
      ),
      GstRate(
        gstClass: GstClass.goods,
        ratePercent: 5,
        inputTaxCreditAllowed: true,
        effectiveFrom: DateTime.utc(2025, 9, 22),
      ),
      GstRate(
        gstClass: GstClass.standardTaxable,
        ratePercent: 18,
        inputTaxCreditAllowed: true,
        effectiveFrom: epoch,
      ),
    ]);
  }

  final List<GstRate> _rates;

  GstRate rateFor(GstClass gstClass, {DateTime? at}) {
    final when = at ?? DateTime.now();
    GstRate? best;
    for (final r in _rates) {
      if (r.gstClass == gstClass && !r.effectiveFrom.isAfter(when)) best = r;
    }
    if (best == null) {
      throw StateError('No GST rate configured for $gstClass at $when');
    }
    return best;
  }
}

/// Money in integer paise (1/100 INR). Never use doubles for currency.
@immutable
class Money implements Comparable<Money> {
  const Money.paise(this.paise);

  const Money.zero() : paise = 0;

  /// Builds from whole rupees (and optional paise) without floating point.
  const Money.rupees(int rupees, [int extraPaise = 0])
    : paise = rupees * 100 + extraPaise;

  /// Parses `1,250`, `1250.50`, `₹ 1,250.5`. Returns null if unparseable.
  static Money? tryParse(String input) {
    final cleaned = input.replaceAll(RegExp(r'₹|Rs\.?|INR|[,\s]'), '');
    final match = RegExp(r'^(-?)(\d+)(?:\.(\d{1,2}))?$').firstMatch(cleaned);
    if (match == null) return null;
    final sign = match.group(1) == '-' ? -1 : 1;
    final rupees = int.parse(match.group(2)!);
    final fraction = (match.group(3) ?? '0').padRight(2, '0');
    return Money.paise(sign * (rupees * 100 + int.parse(fraction)));
  }

  final int paise;

  int get wholeRupees => paise ~/ 100;
  int get fractionPaise => paise.abs() % 100;
  bool get isZero => paise == 0;
  bool get isNegative => paise < 0;

  Money operator +(Money other) => Money.paise(paise + other.paise);
  Money operator -(Money other) => Money.paise(paise - other.paise);
  Money operator -() => Money.paise(-paise);
  bool operator <(Money other) => paise < other.paise;
  bool operator >(Money other) => paise > other.paise;
  bool operator <=(Money other) => paise <= other.paise;
  bool operator >=(Money other) => paise >= other.paise;

  /// Multiplies by a quantity.
  Money times(int quantity) => Money.paise(paise * quantity);

  /// Applies a percentage with banker's-neutral rounding to the nearest paisa
  /// (half away from zero), e.g. 18% GST on ₹1,000 = ₹180.00.
  Money percent(num percentage) {
    final raw = paise * percentage / 100;
    return Money.paise(raw.round());
  }

  /// Splits this amount into [parts] near-equal instalments whose sum is exact.
  List<Money> split(int parts) {
    assert(parts > 0);
    final base = paise ~/ parts;
    var remainder = paise - base * parts;
    return List.generate(parts, (_) {
      final extra = remainder > 0 ? 1 : 0;
      remainder -= extra;
      return Money.paise(base + extra);
    });
  }

  /// Indian-style grouping: `₹1,25,000.50`. Set [symbol] to false for
  /// contexts that add their own currency marker.
  String format({bool symbol = true, bool showPaise = true}) {
    final negative = paise < 0;
    final absRupees = paise.abs() ~/ 100;
    final grouped = _groupIndian(absRupees.toString());
    final paiseText = showPaise
        ? '.${(paise.abs() % 100).toString().padLeft(2, '0')}'
        : '';
    final body = '$grouped$paiseText';
    return '${negative ? '-' : ''}${symbol ? '₹' : ''}$body';
  }

  static String _groupIndian(String digits) {
    if (digits.length <= 3) return digits;
    final last3 = digits.substring(digits.length - 3);
    var rest = digits.substring(0, digits.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    return '${parts.join(',')},$last3';
  }

  Map<String, Object?> toJson() => {'paise': paise};

  factory Money.fromJson(Object? json) {
    if (json is int) return Money.paise(json);
    if (json is Map && json['paise'] is int) {
      return Money.paise(json['paise'] as int);
    }
    throw FormatException('Not a Money value', json);
  }

  @override
  int compareTo(Money other) => paise.compareTo(other.paise);

  @override
  bool operator ==(Object other) => other is Money && other.paise == paise;

  @override
  int get hashCode => paise.hashCode;

  @override
  String toString() => format();
}

/// Sum helper.
extension MoneyIterable on Iterable<Money> {
  Money get total => fold(const Money.zero(), (a, b) => a + b);
}
