import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/features/today/today_kpis.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 25, 11);
  final t = DateTime.utc(2026, 10, 1);

  ProcedureRecord procedure({
    required String id,
    required ProcedureStatus status,
    DateTime? completedAt,
    int feeRupees = 1000,
    int discountRupees = 0,
  }) => ProcedureRecord(
    id: id,
    clinicId: 'c',
    patientId: 'p',
    catalogItemId: 'cat',
    code: 'X',
    name: 'X',
    treatmentArea: TreatmentArea.tooth,
    status: status,
    providerId: 'd',
    fee: Money.rupees(feeRupees),
    discount: Money.rupees(discountRupees),
    completedAt: completedAt,
    createdAt: t,
    updatedAt: t,
  );

  Payment payment({
    required String id,
    required DateTime receivedAt,
    int rupees = 500,
    bool isRefund = false,
  }) => Payment(
    id: id,
    clinicId: 'c',
    patientId: 'p',
    amount: Money.rupees(rupees),
    method: PaymentMethod.upi,
    receivedAt: receivedAt,
    receivedBy: 'd',
    isRefund: isRefund,
    createdAt: t,
  );

  Appointment appointment({
    required String id,
    required DateTime startsAt,
    required AppointmentStatus status,
    List<String> planned = const [],
  }) => Appointment(
    id: id,
    clinicId: 'c',
    patientId: 'p',
    providerId: 'd',
    startsAt: startsAt,
    endsAt: startsAt.add(const Duration(minutes: 30)),
    status: status,
    plannedProcedureIds: planned,
    createdAt: t,
    updatedAt: t,
  );

  group('productionOn', () {
    test('sums net fees of procedures completed on that local day', () {
      final value = productionOn([
        procedure(
          id: '1',
          status: ProcedureStatus.completed,
          completedAt: DateTime(2026, 10, 25, 9),
          feeRupees: 5000,
          discountRupees: 500,
        ),
        procedure(
          id: '2',
          status: ProcedureStatus.completed,
          completedAt: DateTime(2026, 10, 25, 18, 30),
          feeRupees: 1200,
        ),
        procedure(
          id: '3',
          status: ProcedureStatus.completed,
          completedAt: DateTime(2026, 10, 24, 23, 59),
        ),
        procedure(
          id: '4',
          status: ProcedureStatus.inProgress,
          completedAt: DateTime(2026, 10, 25, 10),
        ),
        procedure(id: '5', status: ProcedureStatus.planned),
      ], now);
      expect(value, Money.rupees(5700));
    });

    test('is zero with no completed work', () {
      expect(productionOn(const [], now), const Money.zero());
    });
  });

  group('collectionsInMonth', () {
    test('adds payments and subtracts refunds within the month', () {
      final value = collectionsInMonth([
        payment(id: '1', receivedAt: DateTime(2026, 10, 2), rupees: 3000),
        payment(id: '2', receivedAt: DateTime(2026, 10, 31, 23), rupees: 700),
        payment(
          id: '3',
          receivedAt: DateTime(2026, 10, 15),
          rupees: 200,
          isRefund: true,
        ),
        payment(id: '4', receivedAt: DateTime(2026, 9, 30), rupees: 9999),
        payment(id: '5', receivedAt: DateTime(2026, 11, 1), rupees: 9999),
      ], now);
      expect(value, Money.rupees(3500));
    });
  });

  group('attendanceInMonth', () {
    test('rate is noShow / (completed + noShow)', () {
      final tally = attendanceInMonth([
        appointment(
          id: '1',
          startsAt: DateTime(2026, 10, 3, 10),
          status: AppointmentStatus.completed,
        ),
        appointment(
          id: '2',
          startsAt: DateTime(2026, 10, 4, 10),
          status: AppointmentStatus.completed,
        ),
        appointment(
          id: '3',
          startsAt: DateTime(2026, 10, 5, 10),
          status: AppointmentStatus.completed,
        ),
        appointment(
          id: '4',
          startsAt: DateTime(2026, 10, 6, 10),
          status: AppointmentStatus.noShow,
        ),
        appointment(
          id: '5',
          startsAt: DateTime(2026, 10, 7, 10),
          status: AppointmentStatus.cancelled,
        ),
        appointment(
          id: '6',
          startsAt: DateTime(2026, 10, 28, 10),
          status: AppointmentStatus.scheduled,
        ),
        appointment(
          id: '7',
          startsAt: DateTime(2026, 9, 7, 10),
          status: AppointmentStatus.noShow,
        ),
      ], now);
      expect(tally.completed, 3);
      expect(tally.noShow, 1);
      expect(tally.noShowRate, 0.25);
      expect(formatRate(tally.noShowRate), '25%');
    });

    test('rate is null when nothing happened yet', () {
      final tally = attendanceInMonth(const [], now);
      expect(tally.noShowRate, isNull);
      expect(formatRate(tally.noShowRate), '-');
    });
  });

  group('unscheduledAcceptedValue', () {
    TreatmentPlan plan(String id, TreatmentPlanStatus status) => TreatmentPlan(
      id: id,
      clinicId: 'c',
      patientId: 'p',
      title: 'Plan',
      status: status,
      createdBy: 'd',
      createdAt: t,
      updatedAt: t,
    );
    TreatmentPlanLine line({
      required String id,
      required String planId,
      int rupees = 1000,
      int quantity = 1,
      bool alternative = false,
      String? procedureId,
    }) => TreatmentPlanLine(
      id: id,
      planId: planId,
      clinicId: 'c',
      patientId: 'p',
      catalogItemId: 'cat',
      code: 'X',
      name: 'X',
      laymanName: 'X',
      treatmentArea: TreatmentArea.tooth,
      quantity: quantity,
      unitFee: Money.rupees(rupees),
      isAlternative: alternative,
      procedureId: procedureId,
    );

    test('counts accepted, non-alternative, open lines only', () {
      final value = unscheduledAcceptedValue(
        plans: [
          plan('accepted', TreatmentPlanStatus.accepted),
          plan('active', TreatmentPlanStatus.active),
        ],
        lines: [
          line(id: 'a', planId: 'accepted', rupees: 8000),
          line(id: 'b', planId: 'accepted', rupees: 2000, quantity: 2),
          line(id: 'c', planId: 'accepted', rupees: 999, alternative: true),
          line(id: 'd', planId: 'active', rupees: 5000),
          line(id: 'e', planId: 'accepted', rupees: 3000, procedureId: 'done'),
          line(
            id: 'f',
            planId: 'accepted',
            rupees: 4000,
            procedureId: 'booked',
          ),
          line(
            id: 'g',
            planId: 'accepted',
            rupees: 1500,
            procedureId: 'cancelled-booking',
          ),
        ],
        procedures: [
          procedure(id: 'done', status: ProcedureStatus.completed),
          procedure(id: 'booked', status: ProcedureStatus.accepted),
          procedure(id: 'cancelled-booking', status: ProcedureStatus.accepted),
        ],
        appointments: [
          appointment(
            id: '1',
            startsAt: DateTime(2026, 11, 2, 10),
            status: AppointmentStatus.scheduled,
            planned: const ['booked'],
          ),
          appointment(
            id: '2',
            startsAt: DateTime(2026, 11, 3, 10),
            status: AppointmentStatus.cancelled,
            planned: const ['cancelled-booking'],
          ),
        ],
      );
      // a (8000) + b (2 x 2000) + g (1500, its booking was cancelled)
      expect(value, Money.rupees(13500));
    });

    test('is zero without accepted plans', () {
      expect(
        unscheduledAcceptedValue(
          plans: [plan('p', TreatmentPlanStatus.active)],
          lines: [line(id: 'a', planId: 'p')],
          procedures: const [],
          appointments: const [],
        ),
        const Money.zero(),
      );
    });
  });

  test('TodayKpis.compute wires every number', () {
    final kpis = TodayKpis.compute(
      now: now,
      procedures: [
        procedure(
          id: '1',
          status: ProcedureStatus.completed,
          completedAt: now,
          feeRupees: 2500,
        ),
      ],
      payments: [payment(id: '1', receivedAt: now, rupees: 1000)],
      dueRecalls: [
        Recall(
          id: 'r',
          clinicId: 'c',
          patientId: 'p',
          type: RecallType.hygiene,
          dueAt: now.subtract(const Duration(days: 3)),
          estimatedValue: Money.rupees(800),
          createdAt: t,
          updatedAt: t,
        ),
      ],
      plans: const [],
      lines: const [],
      appointments: [
        appointment(id: 'a', startsAt: now, status: AppointmentStatus.noShow),
      ],
    );
    expect(kpis.productionToday, Money.rupees(2500));
    expect(kpis.collectionsThisMonth, Money.rupees(1000));
    expect(kpis.overdueRecallValue, Money.rupees(800));
    expect(kpis.acceptedUnscheduledValue, const Money.zero());
    expect(kpis.noShowRate, 1.0);
  });
}
