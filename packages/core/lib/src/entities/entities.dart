/// Domain entities (patients, appointments, procedures, plans, billing,
/// consent, perio exams, prescriptions, lab cases, audit).
///
/// Every entity is an immutable class with a const constructor, `copyWith`,
/// `toJson`/`fromJson` (ISO-8601 dates, enum `.name`, `Money` via its JSON,
/// `ToothId` via `storageKey`, `SurfaceSet` via `code`) and identity by `id`.
library;

export 'appointment.dart';
export 'audit.dart';
export 'billing.dart';
export 'catalog_item.dart';
export 'clinic.dart';
export 'clinical.dart';
export 'clinical_note.dart';
export 'compliance.dart';
export 'consent.dart';
export 'drug.dart';
export 'estimate.dart';
export 'imaging.dart';
export 'implant.dart';
export 'json_support.dart';
export 'lab.dart';
export 'medical_history.dart';
export 'messaging.dart';
export 'patient.dart';
export 'payment.dart';
export 'perio_exam.dart';
export 'prescription.dart';
export 'procedure.dart';
export 'recall.dart';
export 'treatment_plan.dart';
export 'treatment_plan_line.dart';
