import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_data/ampdent_data.dart';

import 'billing_strings.dart';

/// Methods offered in the payment sheet, in display order.
const List<PaymentMethod> selectablePaymentMethods = [
  PaymentMethod.cash,
  PaymentMethod.upi,
  PaymentMethod.card,
  PaymentMethod.netBanking,
  PaymentMethod.emi,
  PaymentMethod.cheque,
];

/// Card networks offered for the brand field.
const List<String> cardBrands = [
  'Visa',
  'Mastercard',
  'RuPay',
  'Amex',
  'Other',
];

/// Validators for the payment and refund sheets. Card data is last four digits
/// and network only; a full PAN is rejected outright.
abstract final class PaymentValidators {
  /// Parses an amount that must be positive and, when [max] is given, no
  /// larger than it. Returns null when valid.
  static String? amount(String? value, {Money? max, String? maxMessage}) {
    final parsed = parseAmount(value);
    if (parsed == null || parsed <= const Money.zero()) {
      return BillingStrings.amountRequired;
    }
    if (max != null && parsed > max) {
      return maxMessage ?? BillingStrings.amountExceedsBalance;
    }
    return null;
  }

  /// Exactly four digits; anything longer is treated as a card number and
  /// refused so a PAN can never be stored.
  static String? cardLast4(String? value) {
    final v = (value ?? '').trim();
    if (!RegExp(r'^\d{4}$').hasMatch(v)) return BillingStrings.neverFullCard;
    return null;
  }

  /// A card network must be chosen.
  static String? cardBrand(String? value) =>
      (value ?? '').trim().isEmpty ? BillingStrings.cardBrand : null;

  /// Reasons (refund, void) are mandatory.
  static String? reason(String? value) =>
      (value ?? '').trim().isEmpty ? BillingStrings.reasonRequired : null;

  /// Parses rupees text into [Money]; null when empty or malformed.
  static Money? parseAmount(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return null;
    return Money.tryParse(v);
  }
}

/// `upi://pay?...` link for the clinic's static VPA, opened by any UPI app.
Uri upiPaymentUri({
  required String vpa,
  required String payeeName,
  required Money amount,
  String? note,
}) => Uri(
  scheme: 'upi',
  host: 'pay',
  queryParameters: {
    'pa': vpa,
    'pn': payeeName,
    'am':
        '${amount.wholeRupees}.${amount.fractionPaise.toString().padLeft(2, '0')}',
    'cu': 'INR',
    if (note != null && note.isNotEmpty) 'tn': note,
  },
);

/// Writes payments and refunds through the [BillingRepository] under one
/// actor. Every write is append-only; the repository posts the ledger entry
/// and updates the linked invoice in the same transaction.
class PaymentRecorder {
  /// Creates the recorder.
  const PaymentRecorder({required this.billing, required this.ctx});

  /// Repository.
  final BillingRepository billing;

  /// Actor for the writes.
  final ActorContext ctx;

  /// Records a payment. Card payments store only [cardLast4] and [cardBrand].
  Future<Payment> recordPayment({
    required String patientId,
    String? invoiceId,
    required Money amount,
    required PaymentMethod method,
    String? reference,
    String? cardLast4,
    String? cardBrand,
    String? note,
    DateTime? now,
  }) async {
    if (method == PaymentMethod.card) {
      final error = PaymentValidators.cardLast4(cardLast4);
      if (error != null) {
        throw ArgumentError.value(cardLast4, 'cardLast4', error);
      }
    }
    final at = (now ?? DateTime.now()).toUtc();
    return billing.recordPayment(
      ctx,
      Payment(
        id: newId(),
        clinicId: ctx.clinicId,
        patientId: patientId,
        invoiceId: invoiceId,
        amount: amount,
        method: method,
        reference: _clean(reference),
        cardLast4: method == PaymentMethod.card ? cardLast4 : null,
        cardBrand: method == PaymentMethod.card ? _clean(cardBrand) : null,
        receivedAt: at,
        receivedBy: ctx.actorId,
        note: _clean(note),
        createdAt: at,
      ),
    );
  }

  /// Records a refund as a reverse payment (`isRefund`) carrying the mandatory
  /// [reason]. One ledger posting results; the linked invoice's `amountPaid`
  /// and status move back accordingly.
  Future<Payment> recordRefund({
    required String patientId,
    String? invoiceId,
    required Money amount,
    required PaymentMethod method,
    required String reason,
    String? reference,
    DateTime? now,
  }) async {
    final error = PaymentValidators.reason(reason);
    if (error != null) throw ArgumentError.value(reason, 'reason', error);
    final at = (now ?? DateTime.now()).toUtc();
    return billing.recordPayment(
      ctx,
      Payment(
        id: newId(),
        clinicId: ctx.clinicId,
        patientId: patientId,
        invoiceId: invoiceId,
        amount: amount,
        method: method,
        reference: _clean(reference),
        receivedAt: at,
        receivedBy: ctx.actorId,
        isRefund: true,
        note: reason.trim(),
        createdAt: at,
      ),
    );
  }

  static String? _clean(String? value) {
    final v = value?.trim();
    return v == null || v.isEmpty ? null : v;
  }
}
