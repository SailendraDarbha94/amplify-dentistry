import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_data/ampdent_data.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;

export 'fixtures_billing.dart';
export 'fixtures_clinical.dart';

/// Fixed instants (UTC, millisecond precision so they round-trip exactly).
final DateTime t0 = DateTime.utc(2026, 10, 18, 9, 0);
final DateTime t1 = DateTime.utc(2026, 10, 18, 9, 30);
final DateTime t2 = DateTime.utc(2026, 10, 18, 10, 0);

const String clinicId = 'clinic-1';
const String dentistId = 'member-1';
const String deviceId = 'device-1';
const String patientId = 'patient-1';

const ActorContext ctx = ActorContext(
  clinicId: clinicId,
  actorId: dentistId,
  deviceId: deviceId,
);

/// An open in-memory database with its repositories and a seeded clinic,
/// dentist and patient.
class TestEnv {
  TestEnv(this.db) : repos = DriftRepositories(db);

  final AppDatabase db;
  final DriftRepositories repos;

  static Future<TestEnv> open({bool withPatient = true}) async {
    // Every test opens its own in-memory database on purpose.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final env = TestEnv(AppDatabase.inMemory());
    await env.repos.clinics.createClinic(ctx, clinic());
    await env.repos.clinics.upsertMember(ctx, dentist());
    if (withPatient) await env.repos.patients.upsert(ctx, patient());
    return env;
  }

  Future<void> close() => db.close();
}

Clinic clinic({String? gstin = '36ABCDE1234F1Z5'}) => Clinic(
  id: clinicId,
  name: 'Smile Dental',
  legalName: 'Smile Dental Care LLP',
  addressLines: const ['12 MG Road', 'Banjara Hills'],
  city: 'Hyderabad',
  stateCode: '36',
  pincode: '500034',
  phone: '04012345678',
  whatsappPhone: '9000000000',
  email: 'hello@smile.example',
  gstin: gstin,
  upiVpa: 'smile@upi',
  logoPath: '/logos/smile.png',
  createdAt: t0,
  updatedAt: t0,
);

ClinicMember dentist({String id = dentistId}) => ClinicMember(
  id: id,
  clinicId: clinicId,
  displayName: 'Dr. A. Rao',
  role: ClinicRole.ownerDentist,
  registrationNumber: 'A-12345',
  registrationCouncil: 'Telangana State Dental Council',
  qualifications: const ['BDS', 'MDS (Endodontics)'],
  hprId: 'HPR-1',
  phone: '9000000001',
  email: 'rao@smile.example',
  feeSharePercent: 40,
  createdAt: t0,
  updatedAt: t0,
);

Patient patient({
  String id = patientId,
  String number = 'P-00001',
  String firstName = 'Anil',
  String? lastName = 'Kumar',
  String phone = '9000000002',
  String altPhone = '9000000003',
}) => Patient(
  id: id,
  clinicId: clinicId,
  patientNumber: number,
  firstName: firstName,
  lastName: lastName,
  phone: phone,
  altPhone: altPhone,
  email: 'anil@example.com',
  dateOfBirth: DateTime.utc(1990, 5, 20),
  approxAgeYears: 36,
  ageRecordedAt: t0,
  sex: Sex.male,
  addressLines: const ['4 Park Lane'],
  city: 'Hyderabad',
  pincode: '500001',
  abhaNumber: '12345678901234',
  abhaAddress: 'anil@abdm',
  guardianName: 'Ravi',
  guardianRelation: 'father',
  guardianPhone: '9000000004',
  preferredLanguage: 'te',
  tags: const ['vip'],
  notes: 'Prefers mornings',
  createdAt: t0,
  updatedAt: t0,
);

Appointment appointment({
  String id = 'appt-1',
  String? chairId = 'chair-1',
  String providerId = dentistId,
  DateTime? startsAt,
  DateTime? endsAt,
  AppointmentStatus status = AppointmentStatus.scheduled,
}) => Appointment(
  id: id,
  clinicId: clinicId,
  patientId: patientId,
  providerId: providerId,
  chairId: chairId,
  startsAt: startsAt ?? t0,
  endsAt: endsAt ?? t1,
  status: status,
  reason: 'Pain in lower left',
  plannedProcedureIds: const ['proc-1'],
  source: AppointmentSource.whatsapp,
  notes: 'Walk-in friendly',
  confirmedAt: t0,
  reminder24hSentAt: t0,
  reminderMorningSentAt: t0,
  arrivedAt: null,
  cancelledReason: null,
  createdAt: t0,
  updatedAt: t0,
);

Visit visit({String id = 'visit-1'}) => Visit(
  id: id,
  clinicId: clinicId,
  patientId: patientId,
  providerId: dentistId,
  appointmentId: 'appt-1',
  startedAt: t0,
  chiefComplaint: 'Pain',
  createdAt: t0,
  updatedAt: t0,
);
