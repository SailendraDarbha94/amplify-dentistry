import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_data/ampdent_data.dart';

import 'rx_model.dart';

/// Thrown when the prescriber has no council registration number
/// (DCI Code 3.4.1 requires it on every prescription).
class MissingRegistrationNumber implements Exception {
  /// Creates the error.
  const MissingRegistrationNumber();

  @override
  String toString() => 'Prescriber has no registration number';
}

/// Issues prescriptions: generates the verification code, writes the
/// immutable row and records an audit event for every allergy override.
class PrescriptionIssuer {
  /// Creates the issuer.
  const PrescriptionIssuer({
    required this.prescriptions,
    required this.audit,
    required this.ctx,
    this.codeGenerator = generateVerificationCode,
  });

  /// Prescription repository.
  final PrescriptionRepository prescriptions;

  /// Audit log.
  final AuditRepository audit;

  /// Actor.
  final ActorContext ctx;

  /// Verification code generator (pinned in tests).
  final String Function() codeGenerator;

  /// Issues [draft] for [patientId]. Throws [ArgumentError] on an empty draft
  /// and [MissingRegistrationNumber] when the prescriber has none. Pass
  /// [patient] so its demographics are frozen on the row for reprints.
  Future<Prescription> issue({
    required RxDraft draft,
    required String patientId,
    required ClinicMember prescriber,
    Patient? patient,
    String? visitId,
    DateTime? now,
  }) async {
    if (draft.lines.isEmpty) {
      throw ArgumentError('A prescription needs at least one line');
    }
    if ((prescriber.registrationNumber ?? '').trim().isEmpty) {
      throw const MissingRegistrationNumber();
    }
    final at = (now ?? DateTime.now()).toUtc();
    final rx = draft.toPrescription(
      id: newId(),
      clinicId: ctx.clinicId,
      patientId: patientId,
      prescriber: prescriber,
      verificationCode: codeGenerator(),
      now: at,
      visitId: visitId,
      patient: patient,
    );
    final saved = await prescriptions.issuePrescription(ctx, rx);
    for (final line in draft.lines) {
      final reason = line.overrideReason;
      if (reason == null || reason.isEmpty) continue;
      await audit.append(
        ctx,
        action: AuditAction.update,
        entityType: 'prescription',
        entityId: saved.id,
        after: {
          'allergyOverride': {
            'drug': line.genericUpper,
            'allergyGroup': line.allergyGroup,
            'patientId': patientId,
          },
        },
        reason: 'Allergy override: $reason',
        at: at,
      );
    }
    return saved;
  }
}
