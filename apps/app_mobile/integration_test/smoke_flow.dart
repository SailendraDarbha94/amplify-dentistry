/// The first-day path of a clinic, shared by the on-device smoke test and
/// its widget-test twin (`test/smoke_flow_test.dart`). [env] must already be
/// pumped; the flow starts on a fresh install.
library;

import 'dart:async';

import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_mobile/core/router.dart';
import 'package:ampdent_mobile/features/billing/invoice_pdf_page.dart';
import 'package:ampdent_mobile/features/today/today_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'smoke_support.dart';

/// Runs onboarding, a new patient, the chart (seeding, a caries finding on
/// 16 MO, a scaling planned and completed), an invoice issued from the chart
/// and paid in cash, and asserts the Today KPI tiles.
Future<void> runSmokeFlow(WidgetTester tester, SmokeEnv env) async {
  // 1. A fresh install lands on onboarding; completing it goes home.
  await waitFor(tester, find.byKey(const ValueKey('onboarding-clinic-name')));
  await _completeOnboarding(tester);
  await env.waitForLocation(tester, '/today');
  final session = env.session;
  expect(session.hasClinic, isTrue);
  final clinicId = session.clinicId!;
  expect(await env.repos.catalog.byCode(clinicId, 'SCALING-ADULT'), isNotNull);

  // 2. New patient from the Today quick action.
  await tapKey(tester, 'qa-new-patient');
  await enterKey(tester, 'patient-first-name', 'Asha');
  await enterKey(tester, 'patient-phone', '9876543210');
  await enterKey(tester, 'patient-approx-age', '36');
  await tapKey(tester, 'patient-save');
  final patient = await waitForValue(tester, () async {
    final found = await env.repos.patients.search(clinicId, 'Asha');
    return found.isEmpty ? null : found.single;
  }, reason: 'patient was not saved');
  expect(patient.patientNumber, 'P-00001');
  expect(patient.phone, '+919876543210');
  await env.waitForLocation(tester, '/patients/${patient.id}');

  // 3. Open the chart; the first open seeds age-default tooth states.
  await tapKey(tester, 'qa-chart');
  await waitFor(tester, find.byKey(const ValueKey('chart-odontogram')));
  await waitUntil(
    tester,
    () async => (await env.repos.chart.currentStates(patient.id)).length == 52,
    reason: 'age-default tooth states were not seeded',
  );
  expect(
    (await env.repos.chart.currentStates(patient.id))[ToothId.parse('16')],
    ToothState.present,
  );

  // 4. Caries on 16 MO (tooth preselected through the route, as the
  //    odontogram's touch coordinates depend on layout).
  env.router.pop();
  await settle(tester);
  unawaited(env.router.push('/patients/${patient.id}/chart?tooth=16'));
  await tapKey(tester, 'chart-action-finding');
  await tapKey(tester, 'finding-icdas-5');
  await tapKey(tester, 'chart-surface-M');
  await tapKey(tester, 'chart-surface-O');
  await tapKey(tester, 'finding-save');
  final finding = await waitForValue(tester, () async {
    final findings = await env.repos.chart.findings(patient.id);
    return findings.isEmpty ? null : findings.single;
  }, reason: 'finding was not saved');
  expect(finding.tooth, ToothId.parse('16'));
  expect(finding.surfaces.code, 'MO');
  expect(finding.icdas, IcdasCode.distinctCavity);
  expect(finding.icd10Code, 'K02.1');

  // 5. Plan a scaling from the catalogue and complete it.
  await tapKey(tester, 'chart-action-procedure');
  await enterKey(tester, 'procedure-search', 'SCALING-ADULT');
  await tapKey(tester, 'procedure-item-SCALING-ADULT');
  await tapKey(tester, 'procedure-save');
  final planned = await waitForValue(tester, () async {
    final procedures = await env.repos.chart.proceduresForPatient(patient.id);
    return procedures.isEmpty ? null : procedures.single;
  }, reason: 'procedure was not planned');
  expect(planned.code, 'SCALING-ADULT');
  expect(planned.status, ProcedureStatus.planned);
  await tapKey(tester, 'proc-done-${planned.id}');
  await waitUntil(
    tester,
    () async =>
        (await env.repos.chart.getProcedure(planned.id))?.status ==
        ProcedureStatus.completed,
    reason: 'scaling was not completed',
  );
  final completed = (await env.repos.chart.getProcedure(planned.id))!;
  final recalls = await env.repos.recalls.forPatient(patient.id);
  expect(recalls.single.type, RecallType.hygiene);
  expect(recalls.single.triggeredByProcedureId, planned.id);

  // 6. Bill the completed work and record a cash payment.
  await tapKey(tester, 'proc-bill-${planned.id}');
  await waitFor(tester, find.byKey(ValueKey('inv-line-${planned.id}-select')));
  await tapKey(tester, 'invoice-issue');
  final invoice = await waitForValue(tester, () async {
    final invoices = await env.repos.billing.invoicesForPatient(patient.id);
    return invoices.isEmpty ? null : invoices.single;
  }, reason: 'invoice was not issued');
  expect(invoice.status, InvoiceStatus.issued);
  expect(invoice.number, startsWith('DRAFT-'));
  expect(invoice.lines.single.gstClass, GstClass.exemptHealthcare);
  expect(invoice.grandTotal, completed.netFee);
  await env.waitForLocation(
    tester,
    '/patients/${patient.id}/billing/invoice/${invoice.id}',
  );
  await _closePdfPreview(tester);
  await tapKey(tester, 'invoice-pay');
  await tapKey(tester, 'pay-method-cash');
  await tapKey(tester, 'pay-save');
  await waitUntil(
    tester,
    () async =>
        (await env.repos.billing.getInvoice(invoice.id))?.status ==
        InvoiceStatus.paid,
    reason: 'payment did not settle the invoice',
  );
  final payments = await env.repos.billing.paymentsForInvoice(invoice.id);
  expect(payments.single.method, PaymentMethod.cash);
  expect(payments.single.amount, invoice.grandTotal);

  // 7. Today's KPIs reflect the day's work.
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Today'),
    ),
  );
  await env.waitForLocation(tester, '/today');
  final production = AppFormat.money(completed.netFee, showPaise: false);
  try {
    await waitFor(tester, _kpi('kpi-production', production));
  } on TestFailure {
    fail('Production KPI never showed $production. ${_kpiDiagnostics(env)}');
  }
  expect(
    _kpi(
      'kpi-collections',
      AppFormat.money(invoice.grandTotal, showPaise: false),
    ),
    findsOneWidget,
  );
  expect(
    _kpi('kpi-recall', AppFormat.money(const Money.zero(), showPaise: false)),
    findsOneWidget,
    reason: 'the hygiene recall is six months out, not overdue',
  );
  expect(_kpi('kpi-appointments', '0'), findsOneWidget);
  // The data layer audits under the entity class name.
  final audit = await env.repos.audit.forEntity(
    clinicId,
    'ProcedureRecord',
    planned.id,
  );
  expect(audit, isNotEmpty, reason: 'clinical writes are audited');
}

/// Provider states and tile texts behind the KPI tiles, for failures.
String _kpiDiagnostics(SmokeEnv env) {
  final c = env.container;
  final kpis = c.read(todayKpisProvider);
  String tileTexts(String key) => find
      .descendant(
        of: find.byKey(ValueKey(key), skipOffstage: false),
        matching: find.byType(Text, skipOffstage: false),
        skipOffstage: false,
      )
      .evaluate()
      .map((e) => (e.widget as Text).data)
      .join(' | ');
  final tiles = [
    for (final key in const [
      'kpi-production',
      'kpi-collections',
      'kpi-recall',
      'kpi-unscheduled',
      'kpi-noshow',
      'kpi-appointments',
    ])
      '$key: ${tileTexts(key)}',
  ];
  final summary = kpis == null
      ? 'null'
      : '(production ${kpis.productionToday}, '
            'collections ${kpis.collectionsThisMonth}, '
            'recall ${kpis.overdueRecallValue}, '
            'unscheduled ${kpis.acceptedUnscheduledValue})';
  return 'kpis=$summary '
      'procedures=${c.read(clinicProceduresProvider)} '
      'payments=${c.read(monthPaymentsProvider)} '
      'recalls=${c.read(dueRecallsProvider)} '
      'plans=${c.read(acceptedPlansProvider)} '
      'lines=${c.read(acceptedPlanLinesProvider)} '
      'appointments=${c.read(horizonAppointmentsProvider)} '
      'location=${env.location} tiles=$tiles';
}

/// Text [value] rendered inside the KPI tile keyed [key].
Finder _kpi(String key, String value) =>
    find.descendant(of: find.byKey(ValueKey(key)), matching: find.text(value));

/// Fills the three onboarding steps with a Telangana clinic.
Future<void> _completeOnboarding(WidgetTester tester) async {
  await enterKey(tester, 'onboarding-clinic-name', 'Smile Dental');
  await enterKey(tester, 'onboarding-city', 'Hyderabad');
  await enterKey(tester, 'onboarding-phone', '9000000001');
  await tapKey(tester, 'onboarding-state');
  await tester.scrollUntilVisible(
    find.text('Telangana (36)'),
    120,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.tap(find.text('Telangana (36)').last);
  await settle(tester);
  await tapKey(tester, 'onboarding-next');
  await enterKey(tester, 'onboarding-dentist-name', 'Dr. A. Rao');
  await enterKey(tester, 'onboarding-registration', 'A-12345');
  await tapKey(tester, 'onboarding-next');
  await tapKey(tester, 'onboarding-chairs-plus');
  await tapKey(tester, 'onboarding-next', frames: 12);
}

/// The invoice detail page opens the PDF preview on top after issuing; wait
/// for it and close it so the detail actions are reachable again.
Future<void> _closePdfPreview(WidgetTester tester) async {
  final preview = find.byType(InvoicePdfPage);
  await waitFor(tester, preview, timeout: const Duration(seconds: 15));
  rootNavigatorKey.currentState!.pop();
  await waitUntil(
    tester,
    () async => preview.evaluate().isEmpty,
    reason: 'PDF preview did not close',
  );
}
