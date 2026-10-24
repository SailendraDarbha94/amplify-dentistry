import 'package:ampdent_core/ampdent_core.dart';

/// Month-to-date billing figures for the clinic.
class BillingReport {
  /// Creates a report.
  const BillingReport({
    required this.month,
    this.collections = const Money.zero(),
    this.collectionsByMethod = const {},
    this.refunds = const Money.zero(),
    this.production = const Money.zero(),
    this.outstanding = const Money.zero(),
    this.invoicesIssued = 0,
  });

  /// First day of the month reported (local).
  final DateTime month;

  /// Payments received in the month, net of nothing (refunds separate).
  final Money collections;

  /// Collections split by payment method.
  final Map<PaymentMethod, Money> collectionsByMethod;

  /// Refunds given in the month.
  final Money refunds;

  /// Net fees of procedures completed in the month.
  final Money production;

  /// Balance outstanding on issued and partly paid invoices (all time).
  final Money outstanding;

  /// Invoices issued in the month (any status except draft).
  final int invoicesIssued;

  /// Collections minus refunds.
  Money get netCollections => collections - refunds;
}

/// Whether [value] falls in the calendar month of [month] (local time).
bool inSameMonth(DateTime value, DateTime month) {
  final local = value.toLocal();
  return local.year == month.year && local.month == month.month;
}

/// First day of the month containing [date].
DateTime monthOf(DateTime date) {
  final local = date.toLocal();
  return DateTime(local.year, local.month);
}

/// Builds the [BillingReport] for [month] from raw rows.
BillingReport computeBillingReport({
  required DateTime month,
  Iterable<Payment> payments = const [],
  Iterable<ProcedureRecord> procedures = const [],
  Iterable<Invoice> invoices = const [],
}) {
  var collections = const Money.zero();
  var refunds = const Money.zero();
  final byMethod = <PaymentMethod, Money>{};
  for (final p in payments) {
    if (!inSameMonth(p.receivedAt, month)) continue;
    if (p.isRefund) {
      refunds += p.amount;
      continue;
    }
    collections += p.amount;
    byMethod[p.method] = (byMethod[p.method] ?? const Money.zero()) + p.amount;
  }
  var production = const Money.zero();
  for (final p in procedures) {
    final at = p.completedAt;
    if (p.status != ProcedureStatus.completed || at == null) continue;
    if (inSameMonth(at, month)) production += p.netFee;
  }
  var outstanding = const Money.zero();
  var issued = 0;
  for (final inv in invoices) {
    if (inv.status == InvoiceStatus.draft) continue;
    if (inSameMonth(inv.issuedAt, month)) issued++;
    if (inv.status == InvoiceStatus.issued ||
        inv.status == InvoiceStatus.partiallyPaid) {
      outstanding += inv.balance;
    }
  }
  return BillingReport(
    month: month,
    collections: collections,
    collectionsByMethod: byMethod,
    refunds: refunds,
    production: production,
    outstanding: outstanding,
    invoicesIssued: issued,
  );
}
