import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_data/ampdent_data.dart';
import 'package:ampdent_mobile/features/billing/billing_actions.dart';
import 'package:ampdent_mobile/features/billing/invoice_draft.dart';
import 'package:ampdent_terminology/ampdent_terminology.dart';

import 'billing_test_env.dart';

/// A completed procedure from the seed catalogue (ids match `seedId`).
ProcedureRecord completedProcedure({
  required String id,
  required String code,
  ToothId? tooth,
  Money? fee,
  Money discount = const Money.zero(),
  ProcedureStatus status = ProcedureStatus.completed,
  DateTime? completedAt,
}) {
  final seed = procedureSeedByCode(code)!;
  final at = (completedAt ?? billingNow).toUtc();
  return ProcedureRecord(
    id: id,
    clinicId: testClinicId,
    patientId: testPatientId,
    catalogItemId: seedId('catalog', code),
    code: code,
    name: seed.name,
    tooth: tooth,
    treatmentArea: seed.treatmentArea,
    status: status,
    providerId: testDentistId,
    fee: fee ?? seed.defaultFee,
    discount: discount,
    completedAt: status == ProcedureStatus.completed ? at : null,
    createdAt: at,
    updatedAt: at,
  );
}

/// Catalogue map for the two fixture codes without touching the database.
Map<String, CatalogItem> fixtureCatalog() => {
  for (final code in ['RCT-MOL', 'WHITENING-OFFICE'])
    seedId('catalog', code): catalogItemFromSeed(procedureSeedByCode(code)!, 0),
};

/// Inserts an exempt RCT (₹6,000, tooth 46) and a cosmetic whitening
/// (₹8,000) as completed procedures and returns them.
Future<List<ProcedureRecord>> seedTwoProcedures(BillingTestEnv env) async {
  final rct = completedProcedure(
    id: 'proc-rct',
    code: 'RCT-MOL',
    tooth: ToothId.parse('46'),
  );
  final whitening = completedProcedure(
    id: 'proc-whitening',
    code: 'WHITENING-OFFICE',
  );
  await env.repos.chart.createProcedure(testCtx, rct);
  await env.repos.chart.createProcedure(testCtx, whitening);
  return [rct, whitening];
}

/// Builds and issues an invoice for [procedures] through the real repository.
Future<Invoice> issueFixtureInvoice(
  BillingTestEnv env,
  List<ProcedureRecord> procedures,
) async {
  final lines = draftLinesFromProcedures(
    procedures,
    catalog: fixtureCatalog(),
    notation: ToothNotation.fdi,
  );
  final rates = await env.repos.clinics.loadGstRateTable(testClinicId);
  final draft = buildDraftInvoice(
    id: newId(),
    clinicId: testClinicId,
    patientId: testPatientId,
    issuedBy: testDentistId,
    lines: lines,
    rates: rates,
    clinicGstRegistered: true,
    now: billingNow,
  );
  return InvoiceIssuer(
    billing: env.repos.billing,
    ctx: testCtx,
  ).issue(draft, rates: rates, at: billingNow);
}
