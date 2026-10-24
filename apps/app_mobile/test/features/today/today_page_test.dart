import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/features/today/today_appointments.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../export/feature_harness.dart';

void main() {
  late FeatureTestEnv env;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final t = DateTime.utc(2026, 10, 1);

  Appointment appointment(
    String id,
    DateTime startsAt,
    AppointmentStatus status,
  ) => Appointment(
    id: id,
    clinicId: testClinicId,
    patientId: testPatientId,
    providerId: testDentistId,
    chairId: 'chair-1',
    startsAt: startsAt.toUtc(),
    endsAt: startsAt.add(const Duration(minutes: 30)).toUtc(),
    status: status,
    reason: 'Check-up',
    createdAt: t,
    updatedAt: t,
  );

  setUp(() async {
    env = await FeatureTestEnv.open(withPatient: true);
    final r = env.repos;
    await r.chart.createProcedure(
      testCtx,
      ProcedureRecord(
        id: 'proc-done',
        clinicId: testClinicId,
        patientId: testPatientId,
        catalogItemId: 'cat',
        code: 'RCT-MOL',
        name: 'Root canal (molar)',
        treatmentArea: TreatmentArea.tooth,
        status: ProcedureStatus.completed,
        providerId: testDentistId,
        fee: Money.rupees(5000),
        completedAt: now.toUtc(),
        createdAt: t,
        updatedAt: t,
      ),
    );
    await r.billing.recordPayment(
      testCtx,
      Payment(
        id: 'pay-1',
        clinicId: testClinicId,
        patientId: testPatientId,
        amount: Money.rupees(3000),
        method: PaymentMethod.cash,
        receivedAt: now.toUtc(),
        receivedBy: testDentistId,
        createdAt: t,
      ),
    );
    await r.recalls.upsert(
      testCtx,
      Recall(
        id: 'recall-1',
        clinicId: testClinicId,
        patientId: testPatientId,
        type: RecallType.hygiene,
        dueAt: now.subtract(const Duration(days: 10)).toUtc(),
        estimatedValue: Money.rupees(1500),
        createdAt: t,
        updatedAt: t,
      ),
    );
    await r.treatmentPlans.savePlan(
      testCtx,
      TreatmentPlan(
        id: 'plan-1',
        clinicId: testClinicId,
        patientId: testPatientId,
        title: 'Crown',
        createdBy: testDentistId,
        createdAt: t,
        updatedAt: t,
      ),
      [
        TreatmentPlanLine(
          id: 'line-1',
          planId: 'plan-1',
          clinicId: testClinicId,
          patientId: testPatientId,
          catalogItemId: 'cat',
          code: 'CRN-ZIR',
          name: 'Zirconia crown',
          laymanName: 'Cap',
          treatmentArea: TreatmentArea.tooth,
          unitFee: Money.rupees(8000),
        ),
      ],
    );
    await r.treatmentPlans.acceptPlan(testCtx, 'plan-1', signerName: 'Asha');
    await r.appointments.upsert(
      testCtx,
      appointment(
        'appt-done',
        today.add(const Duration(hours: 9)),
        AppointmentStatus.completed,
      ),
    );
    await r.appointments.upsert(
      testCtx,
      appointment(
        'appt-noshow',
        today.add(const Duration(hours: 10)),
        AppointmentStatus.noShow,
      ),
    );
    await r.appointments.upsert(
      testCtx,
      appointment(
        'appt-next',
        today.add(const Duration(hours: 11)),
        AppointmentStatus.scheduled,
      ),
    );
  });
  tearDown(() => env.close());

  testWidgets('KPI tiles show production, collections, recall, unscheduled '
      'and no-show rate from seeded data', (tester) async {
    await env.pumpApp(tester);
    await settle(tester, frames: 12);
    expect(env.location, '/today');
    expect(find.byKey(const ValueKey('kpi-production')), findsOneWidget);
    expect(
      find.text(Money.rupees(5000).format(showPaise: false)),
      findsOneWidget,
    );
    expect(
      find.text(Money.rupees(3000).format(showPaise: false)),
      findsOneWidget,
    );
    expect(
      find.text(Money.rupees(1500).format(showPaise: false)),
      findsOneWidget,
    );
    expect(
      find.text(Money.rupees(8000).format(showPaise: false)),
      findsOneWidget,
    );
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('today list offers Start visit and opens the patient', (
    tester,
  ) async {
    await env.pumpApp(tester);
    await settle(tester, frames: 12);
    final button = find.byKey(const ValueKey('start-visit-appt-next'));
    await tester.scrollUntilVisible(
      button,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await settle(tester);
    expect(button, findsOneWidget);
    expect(find.byKey(const ValueKey('start-visit-appt-done')), findsNothing);
    await tester.tap(button);
    await settle(tester, frames: 12);
    final updated = await env.repos.appointments.getById('appt-next');
    expect(updated!.status, AppointmentStatus.inChair);
    final visit = await env.repos.appointments.openVisit(testPatientId);
    expect(visit, isNotNull);
    expect(visit!.appointmentId, 'appt-next');
    expect(env.location, '/patients/$testPatientId');
  });

  test('VisitStarter reuses an open visit', () async {
    final starter = VisitStarter(
      appointments: env.repos.appointments,
      ctx: testCtx,
    );
    final appt = (await env.repos.appointments.getById('appt-next'))!;
    final first = await starter.start(appt);
    final second = await starter.start(appt);
    expect(second.id, first.id);
    expect(canStartVisit(AppointmentStatus.inChair), isFalse);
    expect(canStartVisit(AppointmentStatus.confirmed), isTrue);
  });
}
