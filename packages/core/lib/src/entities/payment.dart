import 'package:meta/meta.dart';

import '../money/money.dart';
import 'billing.dart';
import 'json_support.dart';

/// How a payment was received.
enum PaymentMethod { cash, upi, card, netBanking, emi, cheque, wallet, other }

/// Typed ledger adjustment.
enum AdjustmentType { discount, writeOff, refund, specialistShare, correction }

/// Kind of ledger posting.
enum LedgerEntryType { charge, payment, adjustment, refund }

/// An append-only payment event. Card data is a gateway token, last four
/// digits and brand only; never a PAN.
@immutable
class Payment {
  /// Creates a payment.
  const Payment({
    required this.id,
    required this.clinicId,
    required this.patientId,
    this.invoiceId,
    required this.amount,
    required this.method,
    this.reference,
    this.gatewayToken,
    this.cardLast4,
    this.cardBrand,
    required this.receivedAt,
    required this.receivedBy,
    this.isRefund = false,
    this.note,
    required this.createdAt,
  });

  /// UUID v4.
  final String id;

  /// Owning clinic.
  final String clinicId;

  /// Paying patient (or responsible party).
  final String patientId;

  /// Invoice settled, null for an advance / on-account payment.
  final String? invoiceId;

  /// Amount (positive; [isRefund] marks direction).
  final Money amount;

  /// Method.
  final PaymentMethod method;

  /// UTR / cheque number / receipt reference.
  final String? reference;

  /// Gateway token for card payments.
  final String? gatewayToken;

  /// Last four digits of the card.
  final String? cardLast4;

  /// Card network (`Visa`, `RuPay`).
  final String? cardBrand;

  /// When received.
  final DateTime receivedAt;

  /// Member who received it.
  final String receivedBy;

  /// Whether this is money going back to the patient.
  final bool isRefund;

  /// Note.
  final String? note;

  /// Row creation time.
  final DateTime createdAt;

  /// Returns a copy with the given fields replaced.
  Payment copyWith({String? reference, String? note}) => Payment(
    id: id,
    clinicId: clinicId,
    patientId: patientId,
    invoiceId: invoiceId,
    amount: amount,
    method: method,
    reference: reference ?? this.reference,
    gatewayToken: gatewayToken,
    cardLast4: cardLast4,
    cardBrand: cardBrand,
    receivedAt: receivedAt,
    receivedBy: receivedBy,
    isRefund: isRefund,
    note: note ?? this.note,
    createdAt: createdAt,
  );

  /// JSON form.
  Map<String, Object?> toJson() => {
    'id': id,
    'clinicId': clinicId,
    'patientId': patientId,
    'invoiceId': invoiceId,
    'amount': amount.toJson(),
    'method': method.name,
    'reference': reference,
    'gatewayToken': gatewayToken,
    'cardLast4': cardLast4,
    'cardBrand': cardBrand,
    'receivedAt': dateToJson(receivedAt),
    'receivedBy': receivedBy,
    'isRefund': isRefund,
    'note': note,
    'createdAt': dateToJson(createdAt),
  };

  /// Parses the JSON form.
  factory Payment.fromJson(Map<String, Object?> json) => Payment(
    id: json['id'] as String,
    clinicId: json['clinicId'] as String,
    patientId: json['patientId'] as String,
    invoiceId: json['invoiceId'] as String?,
    amount: moneyFromJson(json['amount']),
    method: enumFromJson(PaymentMethod.values, json['method']),
    reference: json['reference'] as String?,
    gatewayToken: json['gatewayToken'] as String?,
    cardLast4: json['cardLast4'] as String?,
    cardBrand: json['cardBrand'] as String?,
    receivedAt: dateFromJson(json['receivedAt']),
    receivedBy: json['receivedBy'] as String,
    isRefund: json['isRefund'] as bool? ?? false,
    note: json['note'] as String?,
    createdAt: dateFromJson(json['createdAt']),
  );
}

/// A typed, approved adjustment to a patient's account.
@immutable
class Adjustment {
  /// Creates an adjustment.
  const Adjustment({
    required this.id,
    required this.clinicId,
    required this.patientId,
    this.invoiceId,
    required this.type,
    required this.amount,
    required this.reason,
    required this.approvedBy,
    required this.createdAt,
  });

  /// UUID v4.
  final String id;

  /// Owning clinic.
  final String clinicId;

  /// Patient.
  final String patientId;

  /// Invoice adjusted, if any.
  final String? invoiceId;

  /// Kind.
  final AdjustmentType type;

  /// Amount (positive).
  final Money amount;

  /// Reason given.
  final String reason;

  /// Approving member.
  final String approvedBy;

  /// Row creation time.
  final DateTime createdAt;

  /// Returns a copy with the given fields replaced.
  Adjustment copyWith({String? reason}) => Adjustment(
    id: id,
    clinicId: clinicId,
    patientId: patientId,
    invoiceId: invoiceId,
    type: type,
    amount: amount,
    reason: reason ?? this.reason,
    approvedBy: approvedBy,
    createdAt: createdAt,
  );

  /// JSON form.
  Map<String, Object?> toJson() => {
    'id': id,
    'clinicId': clinicId,
    'patientId': patientId,
    'invoiceId': invoiceId,
    'type': type.name,
    'amount': amount.toJson(),
    'reason': reason,
    'approvedBy': approvedBy,
    'createdAt': dateToJson(createdAt),
  };

  /// Parses the JSON form.
  factory Adjustment.fromJson(Map<String, Object?> json) => Adjustment(
    id: json['id'] as String,
    clinicId: json['clinicId'] as String,
    patientId: json['patientId'] as String,
    invoiceId: json['invoiceId'] as String?,
    type: enumFromJson(AdjustmentType.values, json['type']),
    amount: moneyFromJson(json['amount']),
    reason: json['reason'] as String,
    approvedBy: json['approvedBy'] as String,
    createdAt: dateFromJson(json['createdAt']),
  );
}

/// One posting on the patient ledger. Charges are positive, payments and
/// credits negative, so the balance is a plain sum.
@immutable
class LedgerEntry {
  /// Creates a ledger entry.
  const LedgerEntry({
    required this.id,
    required this.clinicId,
    required this.patientId,
    required this.entryType,
    required this.amount,
    required this.referenceId,
    required this.occurredAt,
    required this.description,
  });

  /// UUID v4.
  final String id;

  /// Owning clinic.
  final String clinicId;

  /// Patient (responsible party).
  final String patientId;

  /// Kind of posting.
  final LedgerEntryType entryType;

  /// Signed amount.
  final Money amount;

  /// Invoice / payment / adjustment id this posting mirrors.
  final String referenceId;

  /// Posting time.
  final DateTime occurredAt;

  /// Printed description.
  final String description;

  /// Returns a copy with the given fields replaced.
  LedgerEntry copyWith({String? description}) => LedgerEntry(
    id: id,
    clinicId: clinicId,
    patientId: patientId,
    entryType: entryType,
    amount: amount,
    referenceId: referenceId,
    occurredAt: occurredAt,
    description: description ?? this.description,
  );

  /// JSON form.
  Map<String, Object?> toJson() => {
    'id': id,
    'clinicId': clinicId,
    'patientId': patientId,
    'entryType': entryType.name,
    'amount': amount.toJson(),
    'referenceId': referenceId,
    'occurredAt': dateToJson(occurredAt),
    'description': description,
  };

  /// Parses the JSON form.
  factory LedgerEntry.fromJson(Map<String, Object?> json) => LedgerEntry(
    id: json['id'] as String,
    clinicId: json['clinicId'] as String,
    patientId: json['patientId'] as String,
    entryType: enumFromJson(LedgerEntryType.values, json['entryType']),
    amount: moneyFromJson(json['amount']),
    referenceId: json['referenceId'] as String,
    occurredAt: dateFromJson(json['occurredAt']),
    description: json['description'] as String,
  );
}

/// Sum of signed ledger amounts: positive means the patient owes money.
Money ledgerBalance(Iterable<LedgerEntry> entries) =>
    entries.map((e) => e.amount).total;

/// Bucket keys returned by [agingBuckets], in order.
const List<String> agingBucketKeys = ['0-30', '31-60', '61-90', '90+'];

/// Outstanding invoice balances grouped by days since issue as of [asOf].
/// Draft and voided invoices, and invoices with no balance, are skipped.
Map<String, Money> agingBuckets(Iterable<Invoice> invoices, DateTime asOf) {
  final out = <String, Money>{
    for (final k in agingBucketKeys) k: const Money.zero(),
  };
  for (final inv in invoices) {
    if (inv.status == InvoiceStatus.draft ||
        inv.status == InvoiceStatus.voided) {
      continue;
    }
    final balance = inv.balance;
    if (balance <= const Money.zero()) continue;
    final days = asOf.difference(inv.issuedAt).inDays;
    final key = days <= 30
        ? '0-30'
        : days <= 60
        ? '31-60'
        : days <= 90
        ? '61-90'
        : '90+';
    out[key] = out[key]! + balance;
  }
  return out;
}
