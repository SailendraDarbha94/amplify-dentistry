import 'package:ampdent_core/ampdent_core.dart';

// Meta WhatsApp Business Platform, India rate card, per delivered template
// message, in INR, exclusive of GST. Read on 2026-10-18 from
// https://developers.facebook.com/docs/whatsapp/pricing (INR figures as
// reported by Indian BSPs; INR billing becomes mandatory by 31 Dec 2026).
//
// Meta revises these rates on quarter boundaries (the marketing rate last
// moved on 1 Jan 2026), so treat them as a snapshot and re-read the rate
// card at the start of each quarter. Rates are stored in micro-rupees
// (1 rupee = 1,000,000 micro-rupees) because they carry sub-paisa precision.

/// ISO date the rate card below was read from Meta's pricing page.
const String metaIndiaRateCardReadOn = '2026-10-18';

/// Utility template: ₹0.1150 per delivered message, ex GST.
const int utilityRateMicroRupees = 115000;

/// Authentication template: ₹0.1150 per delivered message, ex GST.
const int authenticationRateMicroRupees = 115000;

/// Marketing template: ₹0.8631 per delivered message, ex GST.
const int marketingRateMicroRupees = 863100;

/// Service (customer-initiated window) message. The first 1,000 service
/// conversations per number per month are free; the overage rate after
/// 1 Oct 2026 is disputed between BSPs and Meta's own docs, so this snapshot
/// records zero and callers budgeting for overage should use the utility
/// rate.
const int serviceRateMicroRupees = 0;

/// Authentication-international template: ₹2.4971, ex GST. Not used for
/// Indian numbers; recorded for completeness.
const int authenticationInternationalRateMicroRupees = 2497100;

/// GST charged on Meta's India invoices (IGST on imported services).
const int messagingGstPercent = 18;

/// Micro-rupees per paisa.
const int _microRupeesPerPaisa = 10000;

/// Per-message rate in micro-rupees, ex GST, for [category].
int rateMicroRupees(MessageCategory category) => switch (category) {
  MessageCategory.utility => utilityRateMicroRupees,
  MessageCategory.authentication => authenticationRateMicroRupees,
  MessageCategory.marketing => marketingRateMicroRupees,
  MessageCategory.service => serviceRateMicroRupees,
};

/// Estimated cost in paise of [count] delivered messages of [category],
/// rounded to the nearest paisa after applying GST when [includeGst].
///
/// 1,500 utility messages: 1,500 × ₹0.115 = ₹172.50, plus 18% GST = ₹203.55,
/// returned as 20355.
int estimateCostPaise(
  MessageCategory category, {
  int count = 1,
  bool includeGst = true,
}) {
  if (count < 0) throw ArgumentError.value(count, 'count', 'must be >= 0');
  final exGst = rateMicroRupees(category) * count;
  final scaled = includeGst ? exGst * (100 + messagingGstPercent) : exGst * 100;
  // scaled is in micro-rupees × 100; round to the nearest paisa.
  final denominator = _microRupeesPerPaisa * 100;
  return (scaled + denominator ~/ 2) ~/ denominator;
}

/// Same as [estimateCostPaise], as [Money].
Money estimateCost(
  MessageCategory category, {
  int count = 1,
  bool includeGst = true,
}) => Money.paise(
  estimateCostPaise(category, count: count, includeGst: includeGst),
);
