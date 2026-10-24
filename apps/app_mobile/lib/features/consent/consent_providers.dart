import 'dart:typed_data';

import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'consent_model.dart';
import 'consent_service.dart';

/// Procedure consents of a patient, newest first (live).
final patientConsentsProvider =
    StreamProvider.family<List<ConsentRecord>, String>(
      (ref, patientId) =>
          ref.watch(consentRepositoryProvider).watchConsents(patientId),
    );

/// One consent record by id.
final consentRecordProvider = FutureProvider.family<ConsentRecord?, String>(
  (ref, id) => ref.watch(consentRepositoryProvider).getConsent(id),
);

/// Procedures a consent can be taken for: planned, accepted or in progress.
final consentableProceduresProvider =
    FutureProvider.family<List<ProcedureRecord>, String>((
      ref,
      patientId,
    ) async {
      final all = await ref
          .watch(chartRepositoryProvider)
          .proceduresForPatient(patientId);
      return all
          .where(
            (p) => p.status.isPlanned || p.status == ProcedureStatus.inProgress,
          )
          .toList();
    });

/// Stored signature PNG for a consent's `signatureImagePath`.
final signatureBytesProvider = FutureProvider.family<Uint8List?, String>(
  (ref, path) => ref.watch(signatureStoreProvider).read(path),
);

/// Whether the patient has signed the clinical photography consent.
final hasPhotoUseConsentProvider = StreamProvider.family<bool, String>(
  (ref, patientId) => ref
      .watch(consentRepositoryProvider)
      .watchConsents(patientId)
      .map((list) => list.any((c) => c.templateCode == photoUseTemplateCode)),
);

/// The consent service bound to the current actor and signature store.
final Provider<ConsentService> consentServiceProvider =
    Provider<ConsentService>(
      (ref) => ConsentService(
        consents: ref.watch(consentRepositoryProvider),
        signatures: ref.watch(signatureStoreProvider),
        ctx: ref.watch(actorContextProvider),
      ),
    );

/// The member who took a consent (may be inactive by now).
final consentDentistProvider = FutureProvider.family<ClinicMember?, String>(
  (ref, memberId) => ref.watch(clinicRepositoryProvider).getMember(memberId),
);
