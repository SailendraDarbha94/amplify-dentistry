import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';

import '../dental/surfaces.dart';
import '../dental/tooth_id.dart';
import '../money/money.dart';
import 'json_support.dart';
import 'treatment_plan.dart';

/// One line of a treatment plan: a catalogue item applied to teeth with a
/// fee. Alternatives share an [alternativeGroup] and are excluded from the
/// default subtotal.
@immutable
class TreatmentPlanLine {
  /// Creates a plan line.
  const TreatmentPlanLine({
    required this.id,
    required this.planId,
    required this.clinicId,
    required this.patientId,
    required this.catalogItemId,
    required this.code,
    required this.name,
    required this.laymanName,
    this.tooth,
    this.teeth = const [],
    this.surfaces = const SurfaceSet.empty(),
    required this.treatmentArea,
    this.phaseIndex = 0,
    this.sequence = 0,
    this.quantity = 1,
    required this.unitFee,
    this.discount = const Money.zero(),
    this.gstClass = GstClass.exemptHealthcare,
    this.isAlternative = false,
    this.alternativeGroup,
    this.procedureId,
    this.note,
  });

  /// UUID v4.
  final String id;

  /// Owning plan.
  final String planId;

  /// Owning clinic.
  final String clinicId;

  /// Patient.
  final String patientId;

  /// Catalogue item.
  final String catalogItemId;

  /// Code frozen at planning time.
  final String code;

  /// Clinical name frozen at planning time.
  final String name;

  /// Patient-facing name frozen at planning time.
  final String laymanName;

  /// Single tooth.
  final ToothId? tooth;

  /// Teeth for ranges / arches.
  final List<ToothId> teeth;

  /// Surfaces.
  final SurfaceSet surfaces;

  /// Anatomical extent.
  final TreatmentArea treatmentArea;

  /// Phase this line belongs to.
  final int phaseIndex;

  /// Order within the phase.
  final int sequence;

  /// Quantity (number of units / teeth).
  final int quantity;

  /// Fee per unit.
  final Money unitFee;

  /// Line discount (total, not per unit).
  final Money discount;

  /// GST class.
  final GstClass gstClass;

  /// Whether this is an alternative option rather than the default.
  final bool isAlternative;

  /// Group key tying alternatives together.
  final String? alternativeGroup;

  /// Procedure created from this line once scheduled.
  final String? procedureId;

  /// Note.
  final String? note;

  /// Gross amount before discount.
  Money get gross => unitFee.times(quantity);

  /// Net amount after discount.
  Money get net => gross - discount;

  /// Returns a copy with the given fields replaced.
  TreatmentPlanLine copyWith({
    ToothId? tooth,
    List<ToothId>? teeth,
    SurfaceSet? surfaces,
    TreatmentArea? treatmentArea,
    int? phaseIndex,
    int? sequence,
    int? quantity,
    Money? unitFee,
    Money? discount,
    GstClass? gstClass,
    bool? isAlternative,
    String? alternativeGroup,
    String? procedureId,
    String? note,
  }) => TreatmentPlanLine(
    id: id,
    planId: planId,
    clinicId: clinicId,
    patientId: patientId,
    catalogItemId: catalogItemId,
    code: code,
    name: name,
    laymanName: laymanName,
    tooth: tooth ?? this.tooth,
    teeth: teeth ?? this.teeth,
    surfaces: surfaces ?? this.surfaces,
    treatmentArea: treatmentArea ?? this.treatmentArea,
    phaseIndex: phaseIndex ?? this.phaseIndex,
    sequence: sequence ?? this.sequence,
    quantity: quantity ?? this.quantity,
    unitFee: unitFee ?? this.unitFee,
    discount: discount ?? this.discount,
    gstClass: gstClass ?? this.gstClass,
    isAlternative: isAlternative ?? this.isAlternative,
    alternativeGroup: alternativeGroup ?? this.alternativeGroup,
    procedureId: procedureId ?? this.procedureId,
    note: note ?? this.note,
  );

  /// JSON form.
  Map<String, Object?> toJson() => {
    'id': id,
    'planId': planId,
    'clinicId': clinicId,
    'patientId': patientId,
    'catalogItemId': catalogItemId,
    'code': code,
    'name': name,
    'laymanName': laymanName,
    'tooth': toothToJson(tooth),
    'teeth': teethToJson(teeth),
    'surfaces': surfaces.code,
    'treatmentArea': treatmentArea.name,
    'phaseIndex': phaseIndex,
    'sequence': sequence,
    'quantity': quantity,
    'unitFee': unitFee.toJson(),
    'discount': discount.toJson(),
    'gstClass': gstClass.name,
    'isAlternative': isAlternative,
    'alternativeGroup': alternativeGroup,
    'procedureId': procedureId,
    'note': note,
  };

  /// Parses the JSON form.
  factory TreatmentPlanLine.fromJson(Map<String, Object?> json) =>
      TreatmentPlanLine(
        id: json['id'] as String,
        planId: json['planId'] as String,
        clinicId: json['clinicId'] as String,
        patientId: json['patientId'] as String,
        catalogItemId: json['catalogItemId'] as String,
        code: json['code'] as String,
        name: json['name'] as String,
        laymanName: json['laymanName'] as String,
        tooth: toothFromJsonOrNull(json['tooth']),
        teeth: teethFromJson(json['teeth']),
        surfaces: surfacesFromJson(json['surfaces']),
        treatmentArea: enumFromJson(
          TreatmentArea.values,
          json['treatmentArea'],
        ),
        phaseIndex: json['phaseIndex'] as int? ?? 0,
        sequence: json['sequence'] as int? ?? 0,
        quantity: json['quantity'] as int? ?? 1,
        unitFee: moneyFromJson(json['unitFee']),
        discount: moneyFromJsonOrNull(json['discount']) ?? const Money.zero(),
        gstClass: enumFromJson(GstClass.values, json['gstClass']),
        isAlternative: json['isAlternative'] as bool? ?? false,
        alternativeGroup: json['alternativeGroup'] as String?,
        procedureId: json['procedureId'] as String?,
        note: json['note'] as String?,
      );
}

/// Net subtotal of plan lines, excluding alternatives unless asked.
Money planSubtotal(
  Iterable<TreatmentPlanLine> lines, {
  bool includeAlternatives = false,
}) => lines
    .where((l) => includeAlternatives || !l.isAlternative)
    .map((l) => l.net)
    .total;

/// SHA-256 hex over the plan id, version and every line's clinical and
/// financial fields, with lines sorted by id so order does not matter. Stored
/// on acceptance so later tampering is detectable.
String computePlanSnapshotHash(
  TreatmentPlan plan,
  Iterable<TreatmentPlanLine> lines,
) {
  final sorted = lines.toList()..sort((a, b) => a.id.compareTo(b.id));
  final payload = <String, Object?>{
    'planId': plan.id,
    'version': plan.version,
    'lines': [
      for (final l in sorted)
        <String, Object?>{
          'id': l.id,
          'code': l.code,
          'tooth': toothToJson(l.tooth),
          'teeth': teethToJson(l.teeth.toList()..sort()),
          'surfaces': l.surfaces.code,
          'phaseIndex': l.phaseIndex,
          'quantity': l.quantity,
          'unitFee': l.unitFee.paise,
          'discount': l.discount.paise,
          'gstClass': l.gstClass.name,
          'isAlternative': l.isAlternative,
          'alternativeGroup': l.alternativeGroup,
        },
    ],
  };
  return sha256.convert(utf8.encode(jsonEncode(payload))).toString();
}
