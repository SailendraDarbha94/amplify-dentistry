import 'package:meta/meta.dart';

import '../dental/tooth_id.dart';
import '../money/money.dart';
import '../util/ids.dart' as ids;
import 'clinic.dart';
import 'json_support.dart';

/// Which GST document an invoice prints as.
enum InvoiceDocumentType {
  /// Unregistered clinic: a plain receipt.
  receipt,

  /// Registered, only taxable lines.
  taxInvoice,

  /// Registered, exempt and taxable lines mixed (CGST Rule 46A).
  invoiceCumBillOfSupply,

  /// Registered, only exempt lines.
  billOfSupply,
}

/// Invoice lifecycle. `void` is spelled [voided] because `void` is reserved.
enum InvoiceStatus { draft, issued, partiallyPaid, paid, voided }

/// One invoice line with its GST breakdown. Amounts other than quantity,
/// unit price, discount and rate are derived by [computeInvoiceTotals].
@immutable
class InvoiceLine {
  /// Creates an invoice line.
  const InvoiceLine({
    required this.id,
    this.procedureId,
    this.catalogItemId,
    required this.description,
    this.tooth,
    this.quantity = 1,
    required this.unitPrice,
    this.discount = const Money.zero(),
    required this.gstClass,
    required this.sacHsnCode,
    this.taxRatePercent = 0,
    this.taxableValue = const Money.zero(),
    this.taxAmount = const Money.zero(),
    this.lineTotal = const Money.zero(),
  });

  /// UUID v4.
  final String id;

  /// Procedure billed, if any.
  final String? procedureId;

  /// Catalogue item, if any.
  final String? catalogItemId;

  /// Printed description.
  final String description;

  /// Tooth, when tooth-level.
  final ToothId? tooth;

  /// Quantity.
  final int quantity;

  /// Price per unit.
  final Money unitPrice;

  /// Line discount (total).
  final Money discount;

  /// GST class.
  final GstClass gstClass;

  /// SAC / HSN code printed.
  final String sacHsnCode;

  /// Tax rate applied (resolved from the clinic's rate table at issue).
  final num taxRatePercent;

  /// quantity * unitPrice - discount.
  final Money taxableValue;

  /// taxableValue * rate.
  final Money taxAmount;

  /// taxableValue + taxAmount.
  final Money lineTotal;

  /// Gross before discount.
  Money get gross => unitPrice.times(quantity);

  /// Returns a copy with the given fields replaced.
  InvoiceLine copyWith({
    String? description,
    ToothId? tooth,
    int? quantity,
    Money? unitPrice,
    Money? discount,
    GstClass? gstClass,
    String? sacHsnCode,
    num? taxRatePercent,
    Money? taxableValue,
    Money? taxAmount,
    Money? lineTotal,
  }) => InvoiceLine(
    id: id,
    procedureId: procedureId,
    catalogItemId: catalogItemId,
    description: description ?? this.description,
    tooth: tooth ?? this.tooth,
    quantity: quantity ?? this.quantity,
    unitPrice: unitPrice ?? this.unitPrice,
    discount: discount ?? this.discount,
    gstClass: gstClass ?? this.gstClass,
    sacHsnCode: sacHsnCode ?? this.sacHsnCode,
    taxRatePercent: taxRatePercent ?? this.taxRatePercent,
    taxableValue: taxableValue ?? this.taxableValue,
    taxAmount: taxAmount ?? this.taxAmount,
    lineTotal: lineTotal ?? this.lineTotal,
  );

  /// JSON form.
  Map<String, Object?> toJson() => {
    'id': id,
    'procedureId': procedureId,
    'catalogItemId': catalogItemId,
    'description': description,
    'tooth': toothToJson(tooth),
    'quantity': quantity,
    'unitPrice': unitPrice.toJson(),
    'discount': discount.toJson(),
    'gstClass': gstClass.name,
    'sacHsnCode': sacHsnCode,
    'taxRatePercent': taxRatePercent,
    'taxableValue': taxableValue.toJson(),
    'taxAmount': taxAmount.toJson(),
    'lineTotal': lineTotal.toJson(),
  };

  /// Parses the JSON form.
  factory InvoiceLine.fromJson(Map<String, Object?> json) => InvoiceLine(
    id: json['id'] as String,
    procedureId: json['procedureId'] as String?,
    catalogItemId: json['catalogItemId'] as String?,
    description: json['description'] as String,
    tooth: toothFromJsonOrNull(json['tooth']),
    quantity: json['quantity'] as int? ?? 1,
    unitPrice: moneyFromJson(json['unitPrice']),
    discount: moneyFromJsonOrNull(json['discount']) ?? const Money.zero(),
    gstClass: enumFromJson(GstClass.values, json['gstClass']),
    sacHsnCode: json['sacHsnCode'] as String,
    taxRatePercent: json['taxRatePercent'] as num? ?? 0,
    taxableValue:
        moneyFromJsonOrNull(json['taxableValue']) ?? const Money.zero(),
    taxAmount: moneyFromJsonOrNull(json['taxAmount']) ?? const Money.zero(),
    lineTotal: moneyFromJsonOrNull(json['lineTotal']) ?? const Money.zero(),
  );
}

/// An invoice / receipt. Numbers are `DRAFT-` locally until the server mints
/// the sequential number on first sync.
///
/// The treating dentist is frozen on the row at issue time (`dentistId`,
/// `dentistName`, `dentistQualifications`, `dentistRegistrationNumber`,
/// `dentistRegistrationCouncil`) so the printed registration number (DCI
/// Code 3.4.1) never depends on who is operating the device when the
/// receipt is reprinted; `issuedBy` is the member who raised the bill.
@immutable
class Invoice {
  /// Creates an invoice.
  const Invoice({
    required this.id,
    required this.clinicId,
    required this.patientId,
    required this.number,
    required this.documentType,
    this.status = InvoiceStatus.draft,
    required this.issuedAt,
    this.lines = const [],
    this.subtotal = const Money.zero(),
    this.discountTotal = const Money.zero(),
    this.taxableTotal = const Money.zero(),
    this.taxTotal = const Money.zero(),
    this.grandTotal = const Money.zero(),
    this.amountPaid = const Money.zero(),
    this.notes,
    required this.issuedBy,
    this.dentistId,
    this.dentistName,
    this.dentistQualifications = const [],
    this.dentistRegistrationNumber,
    this.dentistRegistrationCouncil,
    this.voidReason,
    required this.createdAt,
    required this.updatedAt,
  });

  /// UUID v4.
  final String id;

  /// Owning clinic.
  final String clinicId;

  /// Patient billed.
  final String patientId;

  /// Document number.
  final String number;

  /// GST document type.
  final InvoiceDocumentType documentType;

  /// Lifecycle status.
  final InvoiceStatus status;

  /// Issue time.
  final DateTime issuedAt;

  /// Lines.
  final List<InvoiceLine> lines;

  /// Sum of gross line amounts.
  final Money subtotal;

  /// Sum of discounts.
  final Money discountTotal;

  /// Sum of taxable values.
  final Money taxableTotal;

  /// Sum of tax.
  final Money taxTotal;

  /// Payable total.
  final Money grandTotal;

  /// Payments applied so far.
  final Money amountPaid;

  /// Printed notes.
  final String? notes;

  /// Issuing member (whoever raised the bill; may be front desk).
  final String issuedBy;

  /// Treating dentist named on the document; frozen at issue.
  final String? dentistId;

  /// Dentist's name as printed.
  final String? dentistName;

  /// Dentist's qualifications as printed.
  final List<String> dentistQualifications;

  /// Dentist's council registration number (DCI Code 3.4.1).
  final String? dentistRegistrationNumber;

  /// Issuing council of the registration, when recorded.
  final String? dentistRegistrationCouncil;

  /// Reason when voided.
  final String? voidReason;

  /// Row creation time.
  final DateTime createdAt;

  /// Last modification time.
  final DateTime updatedAt;

  /// Outstanding amount.
  Money get balance => grandTotal - amountPaid;

  /// Whether the number is still a local draft number.
  bool get isDraftNumber => ids.isDraftNumber(number);

  /// Whether a registered dentist is frozen on the row (required for every
  /// non-draft invoice).
  bool get hasRegisteredDentist =>
      dentistId != null && (dentistRegistrationNumber ?? '').trim().isNotEmpty;

  /// Returns a copy with the given fields replaced.
  Invoice copyWith({
    String? number,
    InvoiceDocumentType? documentType,
    InvoiceStatus? status,
    DateTime? issuedAt,
    List<InvoiceLine>? lines,
    Money? subtotal,
    Money? discountTotal,
    Money? taxableTotal,
    Money? taxTotal,
    Money? grandTotal,
    Money? amountPaid,
    String? notes,
    String? dentistId,
    String? dentistName,
    List<String>? dentistQualifications,
    String? dentistRegistrationNumber,
    String? dentistRegistrationCouncil,
    String? voidReason,
    DateTime? updatedAt,
  }) => Invoice(
    id: id,
    clinicId: clinicId,
    patientId: patientId,
    number: number ?? this.number,
    documentType: documentType ?? this.documentType,
    status: status ?? this.status,
    issuedAt: issuedAt ?? this.issuedAt,
    lines: lines ?? this.lines,
    subtotal: subtotal ?? this.subtotal,
    discountTotal: discountTotal ?? this.discountTotal,
    taxableTotal: taxableTotal ?? this.taxableTotal,
    taxTotal: taxTotal ?? this.taxTotal,
    grandTotal: grandTotal ?? this.grandTotal,
    amountPaid: amountPaid ?? this.amountPaid,
    notes: notes ?? this.notes,
    issuedBy: issuedBy,
    dentistId: dentistId ?? this.dentistId,
    dentistName: dentistName ?? this.dentistName,
    dentistQualifications: dentistQualifications ?? this.dentistQualifications,
    dentistRegistrationNumber:
        dentistRegistrationNumber ?? this.dentistRegistrationNumber,
    dentistRegistrationCouncil:
        dentistRegistrationCouncil ?? this.dentistRegistrationCouncil,
    voidReason: voidReason ?? this.voidReason,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// Returns a copy naming [dentist] as the treating clinician.
  Invoice withDentist(ClinicMember dentist) => copyWith(
    dentistId: dentist.id,
    dentistName: dentist.displayName,
    dentistQualifications: dentist.qualifications,
    dentistRegistrationNumber: dentist.registrationNumber,
    dentistRegistrationCouncil: dentist.registrationCouncil,
  );

  /// JSON form.
  Map<String, Object?> toJson() => {
    'id': id,
    'clinicId': clinicId,
    'patientId': patientId,
    'number': number,
    'documentType': documentType.name,
    'status': status.name,
    'issuedAt': dateToJson(issuedAt),
    'lines': lines.map((l) => l.toJson()).toList(),
    'subtotal': subtotal.toJson(),
    'discountTotal': discountTotal.toJson(),
    'taxableTotal': taxableTotal.toJson(),
    'taxTotal': taxTotal.toJson(),
    'grandTotal': grandTotal.toJson(),
    'amountPaid': amountPaid.toJson(),
    'notes': notes,
    'issuedBy': issuedBy,
    'dentistId': dentistId,
    'dentistName': dentistName,
    'dentistQualifications': dentistQualifications,
    'dentistRegistrationNumber': dentistRegistrationNumber,
    'dentistRegistrationCouncil': dentistRegistrationCouncil,
    'voidReason': voidReason,
    'createdAt': dateToJson(createdAt),
    'updatedAt': dateToJson(updatedAt),
  };

  /// Parses the JSON form.
  factory Invoice.fromJson(Map<String, Object?> json) => Invoice(
    id: json['id'] as String,
    clinicId: json['clinicId'] as String,
    patientId: json['patientId'] as String,
    number: json['number'] as String,
    documentType: enumFromJson(
      InvoiceDocumentType.values,
      json['documentType'],
    ),
    status: enumFromJson(InvoiceStatus.values, json['status']),
    issuedAt: dateFromJson(json['issuedAt']),
    lines:
        (json['lines'] as List?)
            ?.map(
              (e) => InvoiceLine.fromJson((e as Map).cast<String, Object?>()),
            )
            .toList() ??
        const [],
    subtotal: moneyFromJson(json['subtotal']),
    discountTotal: moneyFromJson(json['discountTotal']),
    taxableTotal: moneyFromJson(json['taxableTotal']),
    taxTotal: moneyFromJson(json['taxTotal']),
    grandTotal: moneyFromJson(json['grandTotal']),
    amountPaid: moneyFromJson(json['amountPaid']),
    notes: json['notes'] as String?,
    issuedBy: json['issuedBy'] as String,
    dentistId: json['dentistId'] as String?,
    dentistName: json['dentistName'] as String?,
    dentistQualifications: stringListFromJson(json['dentistQualifications']),
    dentistRegistrationNumber: json['dentistRegistrationNumber'] as String?,
    dentistRegistrationCouncil: json['dentistRegistrationCouncil'] as String?,
    voidReason: json['voidReason'] as String?,
    createdAt: dateFromJson(json['createdAt']),
    updatedAt: dateFromJson(json['updatedAt']),
  );
}

/// Recomputes every line's taxable value, tax and total from quantity, unit
/// price, discount and rate, then the header totals. Tax is
/// `taxableValue.percent(rate)` per line, so rounding happens per line as GST
/// invoices require.
Invoice computeInvoiceTotals(Invoice invoice) {
  final lines = <InvoiceLine>[];
  var subtotal = const Money.zero();
  var discountTotal = const Money.zero();
  var taxableTotal = const Money.zero();
  var taxTotal = const Money.zero();
  for (final l in invoice.lines) {
    final gross = l.unitPrice.times(l.quantity);
    final taxable = gross - l.discount;
    final tax = taxable.percent(l.taxRatePercent);
    lines.add(
      l.copyWith(
        taxableValue: taxable,
        taxAmount: tax,
        lineTotal: taxable + tax,
      ),
    );
    subtotal += gross;
    discountTotal += l.discount;
    taxableTotal += taxable;
    taxTotal += tax;
  }
  return invoice.copyWith(
    lines: lines,
    subtotal: subtotal,
    discountTotal: discountTotal,
    taxableTotal: taxableTotal,
    taxTotal: taxTotal,
    grandTotal: taxableTotal + taxTotal,
  );
}

/// Picks the GST document type: unregistered clinics issue receipts; a
/// registered clinic issues a bill of supply for exempt-only lines, a tax
/// invoice for taxable-only lines, and an invoice-cum-bill of supply when
/// both kinds are present (CGST Rule 46A).
InvoiceDocumentType suggestDocumentType({
  required bool clinicGstRegistered,
  required Iterable<GstClass> lineClasses,
}) {
  if (!clinicGstRegistered) return InvoiceDocumentType.receipt;
  var anyExempt = false;
  var anyTaxable = false;
  for (final c in lineClasses) {
    if (c == GstClass.exemptHealthcare) {
      anyExempt = true;
    } else {
      anyTaxable = true;
    }
  }
  if (anyExempt && anyTaxable) {
    return InvoiceDocumentType.invoiceCumBillOfSupply;
  }
  if (anyTaxable) return InvoiceDocumentType.taxInvoice;
  return InvoiceDocumentType.billOfSupply;
}
