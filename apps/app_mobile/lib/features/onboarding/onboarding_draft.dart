import 'package:ampdent_messaging/ampdent_messaging.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:flutter/foundation.dart';

/// Everything the three onboarding steps collect before the clinic, owner
/// dentist and chairs are written in one go.
@immutable
class OnboardingDraft {
  /// Creates a draft.
  const OnboardingDraft({
    this.clinicName = '',
    this.city = '',
    this.stateCode,
    this.pincode = '',
    this.phone = '',
    this.whatsappPhone = '',
    this.upiVpa = '',
    this.gstin = '',
    this.dentistName = '',
    this.qualifications = '',
    this.registrationNumber = '',
    this.registrationCouncil = '',
    this.hprId = '',
    this.dentistPhone = '',
    this.chairCount = 1,
  });

  /// Clinic display name.
  final String clinicName;

  /// City or town.
  final String city;

  /// Two-digit GST state code, null until picked.
  final String? stateCode;

  /// Six-digit PIN code (optional at onboarding).
  final String pincode;

  /// Clinic phone (landline or mobile).
  final String phone;

  /// WhatsApp Business number (optional).
  final String whatsappPhone;

  /// UPI VPA for invoice QR (optional).
  final String upiVpa;

  /// GSTIN when registered (optional).
  final String gstin;

  /// Owner dentist display name.
  final String dentistName;

  /// Comma-separated degrees.
  final String qualifications;

  /// State dental council registration number (mandatory).
  final String registrationNumber;

  /// Issuing council.
  final String registrationCouncil;

  /// ABDM HPR id (optional).
  final String hprId;

  /// Dentist mobile (falls back to the clinic phone when blank).
  final String dentistPhone;

  /// Number of chairs to create.
  final int chairCount;

  /// Degrees split from [qualifications].
  List<String> get qualificationList => qualifications
      .split(',')
      .map((q) => q.trim())
      .where((q) => q.isNotEmpty)
      .toList();

  /// Returns a copy with the given fields replaced.
  OnboardingDraft copyWith({
    String? clinicName,
    String? city,
    String? stateCode,
    String? pincode,
    String? phone,
    String? whatsappPhone,
    String? upiVpa,
    String? gstin,
    String? dentistName,
    String? qualifications,
    String? registrationNumber,
    String? registrationCouncil,
    String? hprId,
    String? dentistPhone,
    int? chairCount,
  }) => OnboardingDraft(
    clinicName: clinicName ?? this.clinicName,
    city: city ?? this.city,
    stateCode: stateCode ?? this.stateCode,
    pincode: pincode ?? this.pincode,
    phone: phone ?? this.phone,
    whatsappPhone: whatsappPhone ?? this.whatsappPhone,
    upiVpa: upiVpa ?? this.upiVpa,
    gstin: gstin ?? this.gstin,
    dentistName: dentistName ?? this.dentistName,
    qualifications: qualifications ?? this.qualifications,
    registrationNumber: registrationNumber ?? this.registrationNumber,
    registrationCouncil: registrationCouncil ?? this.registrationCouncil,
    hprId: hprId ?? this.hprId,
    dentistPhone: dentistPhone ?? this.dentistPhone,
    chairCount: chairCount ?? this.chairCount,
  );
}

/// Pure validators shared by the onboarding form and the settings pages.
/// Each returns an error message or null.
abstract final class OnboardingValidators {
  static final RegExp _pincode = RegExp(r'^[1-9][0-9]{5}$');
  static final RegExp _vpa = RegExp(r'^[A-Za-z0-9.\-_]{2,}@[A-Za-z]{2,}$');
  static final RegExp _gstin = RegExp(
    r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$',
  );

  /// Non-empty after trimming.
  static String? required(String? value, String label) =>
      (value ?? '').trim().isEmpty ? '$label is required' : null;

  /// Any phone: digits, at least 6 of them (landlines allowed).
  static String? phone(String? value, {bool optional = false}) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return optional ? null : 'Phone is required';
    final digits = PhoneNumbers.digitsOnly(v);
    return digits.length < 6 ? 'Enter a valid phone number' : null;
  }

  /// Indian mobile (10 digits starting 6-9, optional +91 / 0 prefix).
  static String? indianMobile(String? value, {bool optional = false}) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return optional ? null : 'Mobile number is required';
    return PhoneNumbers.isValidIndianMobile(v)
        ? null
        : 'Enter a valid 10-digit Indian mobile number';
  }

  /// Six-digit PIN code; blank allowed.
  static String? pincode(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return null;
    return _pincode.hasMatch(v) ? null : 'Enter a 6-digit PIN code';
  }

  /// `name@bank` style VPA; blank allowed.
  static String? upiVpa(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return null;
    return _vpa.hasMatch(v) ? null : 'Enter a valid UPI id (name@bank)';
  }

  /// 15-character GSTIN; blank allowed.
  static String? gstin(String? value) {
    final v = (value ?? '').trim().toUpperCase();
    if (v.isEmpty) return null;
    return _gstin.hasMatch(v) ? null : 'Enter a valid 15-character GSTIN';
  }

  /// Council registration number: mandatory for every clinician
  /// (DCI Code 3.4.1 requires it on prescriptions and receipts).
  static String? registrationNumber(String? value) =>
      (value ?? '').trim().isEmpty
      ? MobileStrings.registrationNumberRequired
      : null;

  /// Normalises an Indian mobile to E.164 when it is one; otherwise returns
  /// the trimmed input (landlines are stored as typed).
  static String normalisePhone(String raw) {
    final v = raw.trim();
    return PhoneNumbers.tryNormaliseIndian(v) ?? v;
  }
}
