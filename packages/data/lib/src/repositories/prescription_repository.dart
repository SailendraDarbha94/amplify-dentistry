import 'package:ampdent_core/ampdent_core.dart';

import 'actor_context.dart';

/// Drugs whose allergy group matches an allergy recorded in [history].
List<Drug> conflictingDrugs(MedicalHistory history, Iterable<Drug> drugs) =>
    drugs.where((d) {
      final group = d.allergyGroup;
      return group != null &&
          group.isNotEmpty &&
          history.hasAllergyGroup(group);
    }).toList();

/// Drugs flagged for caution given the patient's history: pregnancy caution
/// when pregnant; the caller adds paediatric caution from the patient's age.
List<Drug> cautionDrugs(MedicalHistory history, Iterable<Drug> drugs) =>
    drugs.where((d) => history.pregnant && d.pregnancyCaution).toList();

/// Drug master and prescriptions.
abstract class PrescriptionRepository {
  /// Seeds the drug master from `dentalDrugMaster` when empty; returns the
  /// number of rows inserted.
  Future<int> seedDrugMasterIfEmpty();

  /// Drugs ordered by generic name.
  Future<List<Drug>> drugs({bool includeInactive = false});

  /// Drug by id.
  Future<Drug?> getDrug(String id);

  /// Case-insensitive search over generic and brand names.
  Future<List<Drug>> searchDrugs(String query, {int limit = 50});

  /// Creates or updates a drug (clinic-added or edited master row).
  Future<Drug> upsertDrug(ActorContext ctx, Drug drug);

  /// Stores a prescription (immutable thereafter). An empty
  /// `verificationCode` is replaced with a generated one.
  Future<Prescription> issuePrescription(
    ActorContext ctx,
    Prescription prescription,
  );

  /// Prescription by id.
  Future<Prescription?> getPrescription(String id);

  /// Prescription by pharmacist verification code.
  Future<Prescription?> byVerificationCode(String code);

  /// A patient's prescriptions, newest first.
  Future<List<Prescription>> prescriptionsForPatient(String patientId);

  /// Stream of a patient's prescriptions, newest first.
  Stream<List<Prescription>> watchPrescriptions(String patientId);
}
