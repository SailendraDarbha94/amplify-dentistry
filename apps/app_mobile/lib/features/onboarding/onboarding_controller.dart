import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_data/ampdent_data.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_terminology/ampdent_terminology.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'onboarding_draft.dart';

/// Result of a completed onboarding.
class OnboardingResult {
  /// Creates a result.
  const OnboardingResult({required this.clinicId, required this.memberId});

  /// New clinic id.
  final String clinicId;

  /// Owner dentist member id (the device's actor from now on).
  final String memberId;
}

/// Writes the clinic, owner dentist and chairs from an [OnboardingDraft].
/// Pure data-layer work, so it is testable without widgets.
class OnboardingService {
  /// Creates the service over [repositories].
  const OnboardingService(this.repositories, {required this.deviceId});

  /// Repositories to write through.
  final DriftRepositories repositories;

  /// Device id stamped on the audit events.
  final String deviceId;

  /// Creates everything and returns the new ids. [now] defaults to UTC now.
  Future<OnboardingResult> submit(
    OnboardingDraft draft, {
    DateTime? now,
  }) async {
    final at = (now ?? DateTime.now()).toUtc();
    final clinicId = newId();
    final memberId = newId();
    final ctx = ActorContext(
      clinicId: clinicId,
      actorId: memberId,
      deviceId: deviceId,
    );
    final whatsapp = draft.whatsappPhone.trim();
    final upi = draft.upiVpa.trim();
    final gstin = draft.gstin.trim().toUpperCase();
    final clinic = Clinic(
      id: clinicId,
      name: draft.clinicName.trim(),
      city: draft.city.trim(),
      stateCode: draft.stateCode ?? '',
      pincode: draft.pincode.trim(),
      phone: OnboardingValidators.normalisePhone(draft.phone),
      whatsappPhone: whatsapp.isEmpty
          ? null
          : OnboardingValidators.normalisePhone(whatsapp),
      upiVpa: upi.isEmpty ? null : upi,
      gstin: gstin.isEmpty ? null : gstin,
      createdAt: at,
      updatedAt: at,
    );
    // createClinic also seeds GST rates, notation and counters.
    await repositories.clinics.createClinic(ctx, clinic);

    final dentistPhone = draft.dentistPhone.trim().isEmpty
        ? clinic.phone
        : OnboardingValidators.normalisePhone(draft.dentistPhone);
    final council = draft.registrationCouncil.trim();
    final owner = ClinicMember(
      id: memberId,
      clinicId: clinicId,
      displayName: draft.dentistName.trim(),
      role: ClinicRole.ownerDentist,
      registrationNumber: draft.registrationNumber.trim(),
      registrationCouncil: council.isEmpty
          ? defaultCouncilName(draft.stateCode)
          : council,
      qualifications: draft.qualificationList,
      hprId: draft.hprId.trim().isEmpty ? null : draft.hprId.trim(),
      phone: dentistPhone,
      createdAt: at,
      updatedAt: at,
    );
    await repositories.clinics.upsertMember(ctx, owner);

    for (var i = 0; i < draft.chairCount; i++) {
      await repositories.clinics.upsertChair(
        ctx,
        Chair(
          id: newId(),
          clinicId: clinicId,
          name: 'Chair ${i + 1}',
          sortOrder: i,
        ),
      );
    }
    return OnboardingResult(clinicId: clinicId, memberId: memberId);
  }

  /// `Telangana State Dental Council` from a GST state code; null when the
  /// code is unknown.
  static String? defaultCouncilName(String? stateCode) {
    if (stateCode == null) return null;
    final state = gstStateByCode(stateCode);
    return state == null ? null : '${state.name} State Dental Council';
  }
}

/// Holds the draft across the three steps.
class OnboardingController extends Notifier<OnboardingDraft> {
  @override
  OnboardingDraft build() => const OnboardingDraft();

  /// Replaces the draft (called by each step's `onSaved`).
  void update(OnboardingDraft Function(OnboardingDraft draft) change) =>
      state = change(state);

  /// Writes everything and activates the session. Returns the new ids.
  Future<OnboardingResult> submit() async {
    final session = ref.read(appSessionProvider);
    final repositories = ref.read(repositoriesProvider);
    final service = OnboardingService(repositories, deviceId: session.deviceId);
    final result = await service.submit(state);
    await ref
        .read(appSessionProvider.notifier)
        .activate(
          clinics: repositories.clinics,
          clinicId: result.clinicId,
          memberId: result.memberId,
        );
    return result;
  }
}

/// The onboarding draft.
final NotifierProvider<OnboardingController, OnboardingDraft>
onboardingControllerProvider =
    NotifierProvider<OnboardingController, OnboardingDraft>(
      OnboardingController.new,
    );
