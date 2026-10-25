import 'dart:math';

import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_data/ampdent_data.dart';
import 'package:flutter/foundation.dart';

/// Frequency chips offered on a line; free text is also accepted.
const List<String> frequencyPresets = [
  '1-0-0',
  '0-0-1',
  '1-0-1',
  '1-1-1',
  '1-1-1-1',
  'SOS',
  'HS',
  'single dose',
];

/// Forms whose quantity is counted in units (tablets, capsules); every other
/// form is dispensed as one pack.
const Set<DrugForm> countableForms = {DrugForm.tablet, DrugForm.capsule};

/// Doses per day implied by a frequency string: `1-0-1` counts the non-zero
/// slots, `OD/BD/TDS/QID/HS/SOS` map to 1/2/3/4/1/2, `single dose` and
/// `once per visit` are one dose in total (see [computeQuantity]).
int dosesPerDay(String frequency) {
  final f = frequency.trim().toLowerCase();
  if (f.isEmpty) return 1;
  final slots = RegExp(r'^(\d+(\.\d+)?|½)(\s*-\s*(\d+(\.\d+)?|½))+$');
  if (slots.hasMatch(f)) {
    return f
        .split('-')
        .map((p) => p.trim())
        .where((p) => p != '0' && p.isNotEmpty)
        .length
        .clamp(1, 6);
  }
  if (f.startsWith('qid') || f.contains('4 times')) return 4;
  if (f.startsWith('tds') || f.contains('3 times')) return 3;
  if (f.startsWith('bd') || f.contains('twice') || f.contains('2 times')) {
    return 2;
  }
  if (f.startsWith('od') || f.startsWith('hs') || f.contains('once')) return 1;
  if (f.startsWith('sos')) return 2;
  final times = RegExp(r'(\d+)\s*times').firstMatch(f);
  if (times != null) return int.parse(times.group(1)!).clamp(1, 12);
  return 1;
}

/// Whether the frequency means one dose in total rather than per day.
bool isSingleDose(String frequency) {
  final f = frequency.trim().toLowerCase();
  return f.contains('single') ||
      f.contains('once per visit') ||
      f.contains('before appointment') ||
      f.contains('before injection');
}

/// Units per dose from a dose string (`1 tablet` -> 1, `2 tablets` -> 2,
/// `½ tablet` / `1/2 tablet` -> 0.5). Non-numeric doses count as 1.
double unitsPerDose(String dose) {
  final d = dose.trim().toLowerCase();
  if (d.startsWith('½') || d.startsWith('1/2') || d.startsWith('half')) {
    return 0.5;
  }
  final m = RegExp(r'^(\d+(\.\d+)?)').firstMatch(d);
  return m == null ? 1 : double.parse(m.group(1)!);
}

/// Quantity to dispense. Tablets and capsules: units per dose x doses per
/// day x days (`1-0-1` x 5 days -> 10), rounded up; a single dose is one
/// dose in total. Syrups, gels, mouthwashes and injections: one pack.
int computeQuantity({
  required String dose,
  required String frequency,
  required int durationDays,
  required DrugForm form,
}) {
  if (!countableForms.contains(form)) return 1;
  final units = unitsPerDose(dose);
  if (isSingleDose(frequency)) return max(1, units.ceil());
  final days = max(1, durationDays);
  return max(1, (units * dosesPerDay(frequency) * days).ceil());
}

/// `1-0-1` -> `Morning and night`.
String frequencyDescription(String frequency) => switch (frequency.trim()) {
  '1-0-0' => 'Morning',
  '0-1-0' => 'Afternoon',
  '0-0-1' => 'Night',
  '1-0-1' => 'Morning and night',
  '1-1-1' => 'Three times a day',
  '1-1-1-1' => 'Four times a day',
  'SOS' => 'When needed',
  'HS' => 'At bedtime',
  'OD' => 'Once a day',
  'BD' => 'Twice a day',
  'TDS' => 'Three times a day',
  'QID' => 'Four times a day',
  'single dose' => 'Single dose',
  _ => frequency,
};

/// Human label for a drug form.
String drugFormLabel(DrugForm form) => switch (form) {
  DrugForm.tablet => 'Tab',
  DrugForm.capsule => 'Cap',
  DrugForm.syrup => 'Syrup',
  DrugForm.suspension => 'Susp',
  DrugForm.injection => 'Inj',
  DrugForm.mouthwash => 'Mouthwash',
  DrugForm.gel => 'Gel',
  DrugForm.ointment => 'Oint',
  DrugForm.paste => 'Paste',
  DrugForm.drops => 'Drops',
  DrugForm.varnish => 'Varnish',
  DrugForm.toothpaste => 'Toothpaste',
  DrugForm.other => '',
};

/// `Schedule H1` tag text.
String scheduleLabel(DrugSchedule schedule) => switch (schedule) {
  DrugSchedule.otc => 'OTC',
  DrugSchedule.h => 'Sch H',
  DrugSchedule.h1 => 'Schedule H1',
  DrugSchedule.x => 'Schedule X',
  DrugSchedule.g => 'Sch G',
};

/// Letters and digits without look-alikes (no 0/O, 1/I/L).
const String verificationAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

/// Six-character verification code printed on the prescription.
String generateVerificationCode([Random? random]) {
  final r = random ?? Random.secure();
  return List.generate(
    6,
    (_) => verificationAlphabet[r.nextInt(verificationAlphabet.length)],
  ).join();
}

/// Whether [drug] matches an allergy recorded in [history]: by group, by
/// the group inferred from the substance text, or by substance name (see
/// `allergyMatches` in `ampdent_data`).
bool allergyConflicts(MedicalHistory? history, Drug drug) =>
    history != null && matchingAllergies(history, drug).isNotEmpty;

/// Allergy entries that block [drug].
List<AllergyEntry> matchingAllergies(MedicalHistory? history, Drug drug) =>
    history == null ? const [] : allergyMatches(history, drug);

/// Caution chip labels for a drug given the patient's history and age.
List<String> cautionLabels({
  required Drug drug,
  MedicalHistory? history,
  required bool isMinor,
}) => [
  if (drug.pregnancyCaution && (history?.pregnant ?? false))
    'Pregnancy caution',
  if (drug.pregnancyCaution && !(history?.pregnant ?? false))
    'Caution in pregnancy',
  if (drug.pediatricCaution && isMinor) 'Paediatric caution',
];

/// One editable prescription line.
@immutable
class RxLineDraft {
  /// Creates a line.
  const RxLineDraft({
    this.drugId,
    required this.genericName,
    this.brandName,
    required this.strength,
    required this.form,
    required this.dose,
    required this.frequency,
    required this.durationDays,
    this.quantity,
    required this.route,
    this.instructions = '',
    this.schedule = DrugSchedule.h,
    this.allergyGroup,
    this.pregnancyCaution = false,
    this.pediatricCaution = false,
    this.overrideReason,
  });

  /// Starts a line from a drug master entry with its defaults.
  factory RxLineDraft.fromDrug(Drug d) => RxLineDraft(
    drugId: d.id,
    genericName: d.genericName,
    brandName: d.brandNames.isEmpty ? null : d.brandNames.first,
    strength: d.strength,
    form: d.form,
    dose: d.defaultDose,
    frequency: d.defaultFrequency,
    durationDays: d.defaultDurationDays,
    route: d.route,
    schedule: d.schedule,
    allergyGroup: d.allergyGroup,
    pregnancyCaution: d.pregnancyCaution,
    pediatricCaution: d.pediatricCaution,
  );

  /// Copies a stored line (for repeats).
  factory RxLineDraft.fromLine(PrescriptionLine l, {Drug? drug}) => RxLineDraft(
    drugId: l.drugId,
    genericName: l.genericName,
    brandName: l.brandName,
    strength: l.strength,
    form: l.form,
    dose: l.dose,
    frequency: l.frequency,
    durationDays: l.durationDays,
    quantity: l.quantity,
    route: l.route,
    instructions: l.instructions ?? '',
    schedule: l.schedule,
    allergyGroup: drug?.allergyGroup,
    pregnancyCaution: drug?.pregnancyCaution ?? false,
    pediatricCaution: drug?.pediatricCaution ?? false,
  );

  /// Drug master id.
  final String? drugId;

  /// Generic name (printed in capitals).
  final String genericName;

  /// Brand name, optional.
  final String? brandName;

  /// `500 mg`.
  final String strength;

  /// Form.
  final DrugForm form;

  /// `1 tablet`.
  final String dose;

  /// `1-0-1`, `TDS`...
  final String frequency;

  /// Days.
  final int durationDays;

  /// Manually set quantity; null means auto-compute.
  final int? quantity;

  /// Route.
  final String route;

  /// Instructions (`after food`).
  final String instructions;

  /// Schedule tag.
  final DrugSchedule schedule;

  /// Allergy group of the drug.
  final String? allergyGroup;

  /// Drug flagged for pregnancy caution.
  final bool pregnancyCaution;

  /// Drug flagged for paediatric caution.
  final bool pediatricCaution;

  /// Reason recorded when an allergy block was overridden.
  final String? overrideReason;

  /// Effective quantity: manual when set, else computed.
  int get effectiveQuantity =>
      quantity ??
      computeQuantity(
        dose: dose,
        frequency: frequency,
        durationDays: durationDays,
        form: form,
      );

  /// Schedule H1 line.
  bool get isScheduleH1 => schedule == DrugSchedule.h1;

  /// Generic name in capitals.
  String get genericUpper => genericName.toUpperCase();

  /// Stored line.
  PrescriptionLine toLine() => PrescriptionLine(
    drugId: drugId,
    genericName: genericUpper,
    brandName: brandName,
    strength: strength,
    form: form,
    dose: dose.trim(),
    frequency: frequency.trim(),
    durationDays: durationDays,
    quantity: effectiveQuantity,
    route: route,
    instructions: instructions.trim().isEmpty ? null : instructions.trim(),
    schedule: schedule,
  );

  /// Returns a copy with the given fields replaced; [clearQuantity] returns
  /// to auto-compute.
  RxLineDraft copyWith({
    String? brandName,
    String? dose,
    String? frequency,
    int? durationDays,
    int? quantity,
    bool clearQuantity = false,
    String? route,
    String? instructions,
    String? overrideReason,
  }) => RxLineDraft(
    drugId: drugId,
    genericName: genericName,
    brandName: brandName ?? this.brandName,
    strength: strength,
    form: form,
    dose: dose ?? this.dose,
    frequency: frequency ?? this.frequency,
    durationDays: durationDays ?? this.durationDays,
    quantity: clearQuantity ? null : quantity ?? this.quantity,
    route: route ?? this.route,
    instructions: instructions ?? this.instructions,
    schedule: schedule,
    allergyGroup: allergyGroup,
    pregnancyCaution: pregnancyCaution,
    pediatricCaution: pediatricCaution,
    overrideReason: overrideReason ?? this.overrideReason,
  );
}

/// Whole prescription being composed.
@immutable
class RxDraft {
  /// Creates a draft.
  const RxDraft({
    this.diagnosis = '',
    this.lines = const [],
    this.isRepeatable = false,
    this.dispensedByClinic = false,
  });

  /// Copies a stored prescription into a fresh draft (repeat).
  factory RxDraft.repeatOf(
    Prescription rx, {
    Map<String, Drug> drugs = const {},
  }) => RxDraft(
    diagnosis: rx.diagnosis ?? '',
    lines: [
      for (final l in rx.lines)
        RxLineDraft.fromLine(
          l,
          drug: l.drugId == null ? null : drugs[l.drugId!],
        ),
    ],
    isRepeatable: rx.isRepeatable,
    dispensedByClinic: rx.dispensedByClinic,
  );

  /// Diagnosis text, optionally with ICD-10 codes appended.
  final String diagnosis;

  /// Lines.
  final List<RxLineDraft> lines;

  /// Patient may repeat without a visit.
  final bool isRepeatable;

  /// Dispensed in-house.
  final bool dispensedByClinic;

  /// Any Schedule H1 line.
  bool get hasScheduleH1 => lines.any((l) => l.isScheduleH1);

  /// Returns a copy with the given fields replaced.
  RxDraft copyWith({
    String? diagnosis,
    List<RxLineDraft>? lines,
    bool? isRepeatable,
    bool? dispensedByClinic,
  }) => RxDraft(
    diagnosis: diagnosis ?? this.diagnosis,
    lines: lines ?? this.lines,
    isRepeatable: isRepeatable ?? this.isRepeatable,
    dispensedByClinic: dispensedByClinic ?? this.dispensedByClinic,
  );

  /// Builds the immutable prescription.
  Prescription toPrescription({
    required String id,
    required String clinicId,
    required String patientId,
    required ClinicMember prescriber,
    required String verificationCode,
    required DateTime now,
    String? visitId,
  }) => Prescription(
    id: id,
    clinicId: clinicId,
    patientId: patientId,
    visitId: visitId,
    prescriberId: prescriber.id,
    prescriberName: prescriber.displayName,
    prescriberRegistrationNumber: prescriber.registrationNumber ?? '',
    prescriberQualifications: prescriber.qualifications,
    issuedAt: now,
    diagnosis: diagnosis.trim().isEmpty ? null : diagnosis.trim(),
    lines: [for (final l in lines) l.toLine()],
    isRepeatable: isRepeatable,
    dispensedByClinic: dispensedByClinic,
    verificationCode: verificationCode,
    createdAt: now,
  );
}
