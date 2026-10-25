import 'package:meta/meta.dart';

import '../dental/tooth_id.dart';
import '../money/money.dart';
import 'json_support.dart';

/// Estimate lifecycle.
enum EstimateStatus { draft, issued, accepted, superseded }

/// One line of an estimate (frozen copy of a plan line with tax).
@immutable
class EstimateLine {
  /// Creates an estimate line.
  const EstimateLine({
    required this.description,
    this.tooth,
    this.quantity = 1,
    required this.unitFee,
    this.discount = const Money.zero(),
    required this.gstClass,
    this.taxRatePercent = 0,
    required this.lineTotal,
  });

  /// Patient-facing description.
  final String description;

  /// Tooth, when tooth-level.
  final ToothId? tooth;

  /// Quantity.
  final int quantity;

  /// Fee per unit.
  final Money unitFee;

  /// Line discount.
  final Money discount;

  /// GST class.
  final GstClass gstClass;

  /// Tax rate applied.
  final num taxRatePercent;

  /// Total including tax.
  final Money lineTotal;

  /// Returns a copy with the given fields replaced.
  EstimateLine copyWith({
    String? description,
    ToothId? tooth,
    int? quantity,
    Money? unitFee,
    Money? discount,
    GstClass? gstClass,
    num? taxRatePercent,
    Money? lineTotal,
  }) => EstimateLine(
    description: description ?? this.description,
    tooth: tooth ?? this.tooth,
    quantity: quantity ?? this.quantity,
    unitFee: unitFee ?? this.unitFee,
    discount: discount ?? this.discount,
    gstClass: gstClass ?? this.gstClass,
    taxRatePercent: taxRatePercent ?? this.taxRatePercent,
    lineTotal: lineTotal ?? this.lineTotal,
  );

  /// JSON form.
  Map<String, Object?> toJson() => {
    'description': description,
    'tooth': toothToJson(tooth),
    'quantity': quantity,
    'unitFee': unitFee.toJson(),
    'discount': discount.toJson(),
    'gstClass': gstClass.name,
    'taxRatePercent': taxRatePercent,
    'lineTotal': lineTotal.toJson(),
  };

  /// Parses the JSON form.
  factory EstimateLine.fromJson(Map<String, Object?> json) => EstimateLine(
    description: json['description'] as String,
    tooth: toothFromJsonOrNull(json['tooth']),
    quantity: json['quantity'] as int? ?? 1,
    unitFee: moneyFromJson(json['unitFee']),
    discount: moneyFromJsonOrNull(json['discount']) ?? const Money.zero(),
    gstClass: enumFromJson(GstClass.values, json['gstClass']),
    taxRatePercent: json['taxRatePercent'] as num? ?? 0,
    lineTotal: moneyFromJson(json['lineTotal']),
  );
}

/// A versioned cost estimate given to the patient before treatment. A new
/// version requires a [justification].
@immutable
class Estimate {
  /// Creates an estimate.
  const Estimate({
    required this.id,
    required this.clinicId,
    required this.patientId,
    this.planId,
    this.version = 1,
    required this.number,
    this.lines = const [],
    required this.subtotal,
    required this.discountTotal,
    required this.taxTotal,
    required this.grandTotal,
    required this.issuedAt,
    required this.issuedBy,
    this.justification,
    this.validUntil,
    this.status = EstimateStatus.draft,
    this.planVersion,
    this.planSnapshotHash,
    required this.createdAt,
  }) : assert(
         version == 1 || justification != null,
         'A revised estimate needs a justification',
       );

  /// UUID v4.
  final String id;

  /// Owning clinic.
  final String clinicId;

  /// Patient.
  final String patientId;

  /// Plan this estimate prices.
  final String? planId;

  /// Version, 1-based.
  final int version;

  /// Document number (draft or server-minted).
  final String number;

  /// Lines.
  final List<EstimateLine> lines;

  /// Sum of gross line amounts.
  final Money subtotal;

  /// Sum of discounts.
  final Money discountTotal;

  /// Sum of tax.
  final Money taxTotal;

  /// Payable total.
  final Money grandTotal;

  /// Issue time.
  final DateTime issuedAt;

  /// Issuing member.
  final String issuedBy;

  /// Why this version differs from the last (required when version > 1).
  final String? justification;

  /// Validity end.
  final DateTime? validUntil;

  /// Lifecycle status.
  final EstimateStatus status;

  /// Version of the plan this estimate was produced from.
  final int? planVersion;

  /// `computePlanSnapshotHash` of the plan lines at issue, so acceptance can
  /// detect that the plan changed after the patient saw the estimate.
  final String? planSnapshotHash;

  /// Row creation time.
  final DateTime createdAt;

  /// Returns a copy with the given fields replaced.
  Estimate copyWith({
    String? number,
    List<EstimateLine>? lines,
    Money? subtotal,
    Money? discountTotal,
    Money? taxTotal,
    Money? grandTotal,
    String? justification,
    DateTime? validUntil,
    EstimateStatus? status,
    int? planVersion,
    String? planSnapshotHash,
  }) => Estimate(
    id: id,
    clinicId: clinicId,
    patientId: patientId,
    planId: planId,
    version: version,
    number: number ?? this.number,
    lines: lines ?? this.lines,
    subtotal: subtotal ?? this.subtotal,
    discountTotal: discountTotal ?? this.discountTotal,
    taxTotal: taxTotal ?? this.taxTotal,
    grandTotal: grandTotal ?? this.grandTotal,
    issuedAt: issuedAt,
    issuedBy: issuedBy,
    justification: justification ?? this.justification,
    validUntil: validUntil ?? this.validUntil,
    status: status ?? this.status,
    planVersion: planVersion ?? this.planVersion,
    planSnapshotHash: planSnapshotHash ?? this.planSnapshotHash,
    createdAt: createdAt,
  );

  /// JSON form.
  Map<String, Object?> toJson() => {
    'id': id,
    'clinicId': clinicId,
    'patientId': patientId,
    'planId': planId,
    'version': version,
    'number': number,
    'lines': lines.map((l) => l.toJson()).toList(),
    'subtotal': subtotal.toJson(),
    'discountTotal': discountTotal.toJson(),
    'taxTotal': taxTotal.toJson(),
    'grandTotal': grandTotal.toJson(),
    'issuedAt': dateToJson(issuedAt),
    'issuedBy': issuedBy,
    'justification': justification,
    'validUntil': dateToJson(validUntil),
    'status': status.name,
    'planVersion': planVersion,
    'planSnapshotHash': planSnapshotHash,
    'createdAt': dateToJson(createdAt),
  };

  /// Parses the JSON form.
  factory Estimate.fromJson(Map<String, Object?> json) => Estimate(
    id: json['id'] as String,
    clinicId: json['clinicId'] as String,
    patientId: json['patientId'] as String,
    planId: json['planId'] as String?,
    version: json['version'] as int? ?? 1,
    number: json['number'] as String,
    lines:
        (json['lines'] as List?)
            ?.map(
              (e) => EstimateLine.fromJson((e as Map).cast<String, Object?>()),
            )
            .toList() ??
        const [],
    subtotal: moneyFromJson(json['subtotal']),
    discountTotal: moneyFromJson(json['discountTotal']),
    taxTotal: moneyFromJson(json['taxTotal']),
    grandTotal: moneyFromJson(json['grandTotal']),
    issuedAt: dateFromJson(json['issuedAt']),
    issuedBy: json['issuedBy'] as String,
    justification: json['justification'] as String?,
    validUntil: dateFromJsonOrNull(json['validUntil']),
    status: enumFromJson(EstimateStatus.values, json['status']),
    planVersion: json['planVersion'] as int?,
    planSnapshotHash: json['planSnapshotHash'] as String?,
    createdAt: dateFromJson(json['createdAt']),
  );
}
