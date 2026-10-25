import 'package:ampdent_core/ampdent_core.dart';
import 'package:test/test.dart';

/// Tri-state age: a patient with neither a date of birth nor an approximate
/// age is `unknown`, never silently an adult.
void main() {
  final asOf = DateTime.utc(2026, 10, 25);
  final t0 = DateTime.utc(2026, 10, 1);

  Patient patient({
    DateTime? dob,
    num? approxAge,
    String? guardianName,
    String? guardianPhone,
  }) => Patient(
    id: 'p',
    clinicId: 'c',
    patientNumber: 'P-1',
    firstName: 'Kiran',
    phone: '9000000001',
    dateOfBirth: dob,
    approxAgeYears: approxAge,
    ageRecordedAt: approxAge == null ? null : asOf,
    guardianName: guardianName,
    guardianPhone: guardianPhone,
    createdAt: t0,
    updatedAt: t0,
  );

  test('ageStatus is unknown without DOB or approximate age', () {
    final unknown = patient();
    expect(unknown.hasKnownAge, isFalse);
    expect(unknown.ageStatus(asOf), AgeStatus.unknown);
    expect(unknown.isMinorOrNull(asOf), isNull);
    expect(unknown.isMinor(asOf), isFalse, reason: 'bool view stays false');
    expect(
      unknown.requiresGuardian(asOf),
      isTrue,
      reason: 'unknown must be resolved before treatment or messaging',
    );
  });

  test('a minor and an adult resolve from DOB or approximate age', () {
    final minor = patient(dob: DateTime.utc(2016, 1, 1));
    expect(minor.ageStatus(asOf), AgeStatus.minor);
    expect(minor.isMinorOrNull(asOf), isTrue);
    expect(minor.requiresGuardian(asOf), isTrue);
    expect(
      patient(
        dob: DateTime.utc(2016, 1, 1),
        guardianName: 'Lakshmi',
        guardianPhone: '9123456789',
      ).requiresGuardian(asOf),
      isFalse,
    );
    final adult = patient(approxAge: 42);
    expect(adult.hasKnownAge, isTrue);
    expect(adult.ageStatus(asOf), AgeStatus.adult);
    expect(adult.isMinorOrNull(asOf), isFalse);
    expect(adult.requiresGuardian(asOf), isFalse);
    expect(patient(approxAge: 10).ageStatus(asOf), AgeStatus.minor);
  });
}
