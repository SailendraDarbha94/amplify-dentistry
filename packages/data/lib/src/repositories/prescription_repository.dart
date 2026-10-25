import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_terminology/ampdent_terminology.dart';

import 'actor_context.dart';

/// Shortest substance text that may match a drug name by containment; below
/// this an entry such as `Pan` would hit unrelated names.
const int minAllergySubstanceLength = 4;

/// Allergy entries in [history] that [drug] must not be prescribed against.
///
/// An entry matches when
/// * its recorded group, or the group inferred from its substance text
///   ([inferAllergyGroup]), equals the drug's allergy group; or
/// * its substance text (case-insensitive, trimmed) is contained in the
///   drug's generic name, one of its combination components or a brand
///   name, or contains one of those names.
///
/// So `Amoxicillin` typed with no group chip still blocks `AMOX-500` and
/// `Augmentin` blocks every penicillin.
List<AllergyEntry> allergyMatches(MedicalHistory history, Drug drug) {
  final group = drug.allergyGroup?.trim().toLowerCase();
  final names = [
    ...drug.genericName.split('+'),
    drug.genericName,
    ...drug.brandNames,
  ].map(normaliseAllergySubstance).where((n) => n.isNotEmpty).toList();
  return history.allergies.where((a) {
    final recorded = a.allergyGroup?.trim().toLowerCase();
    final inferred = inferAllergyGroup(a.substance)?.toLowerCase();
    if (group != null &&
        group.isNotEmpty &&
        (recorded == group || inferred == group)) {
      return true;
    }
    final substance = normaliseAllergySubstance(a.substance);
    if (substance.length < minAllergySubstanceLength) return false;
    return names.any(
      (n) =>
          n.contains(substance) ||
          (n.length >= minAllergySubstanceLength && substance.contains(n)),
    );
  }).toList();
}

/// Drugs that match an allergy recorded in [history] (see [allergyMatches]).
List<Drug> conflictingDrugs(MedicalHistory history, Iterable<Drug> drugs) =>
    drugs.where((d) => allergyMatches(history, d).isNotEmpty).toList();

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
