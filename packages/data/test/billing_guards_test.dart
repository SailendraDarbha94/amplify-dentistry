import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_data/ampdent_data.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Guards on the billing and plan repositories: one-transaction invoice
/// issue, per-stage billing of multi-sitting work, payment validation and
/// the declined-estimate record on acceptance.
void main() {
  late TestEnv env;

  setUp(() async => env = await TestEnv.open());
  tearDown(() => env.close());

  InvoiceLine stageLine(String id, int? stage) => InvoiceLine(
    id: id,
    procedureId: 'proc-1',
    stageIndex: stage,
    description: 'Root canal (stage)',
    unitPrice: const Money.rupees(2000),
    gstClass: GstClass.exemptHealthcare,
    sacHsnCode: '999312',
  );

  group('issueDraft is atomic', () {
    test('a failure after the issue leaves nothing written', () async {
      final billing = env.repos.billing;
      final before = await env.repos.outbox.pendingCount(clinicId);
      await expectLater(
        env.db.transaction(() async {
          final issued = await billing.issueDraft(ctx, draftInvoice(), at: t0);
          expect(issued.status, InvoiceStatus.issued);
          throw StateError('forced failure after issue');
        }),
        throwsStateError,
      );
      expect(await billing.getInvoice('inv-1'), isNull);
      expect(await billing.invoicesForPatient(patientId), isEmpty);
      expect(await billing.ledger(patientId), isEmpty);
      expect(
        await env.repos.audit.forEntity(clinicId, 'Invoice', 'inv-1'),
        isEmpty,
      );
      expect(await env.repos.outbox.pendingCount(clinicId), before);
    });

    test('a refused issue strands no DRAFT row', () async {
      await env.repos.clinics.upsertMember(
        ctx,
        dentist().copyWith(registrationNumber: ''),
      );
      final billing = env.repos.billing;
      await expectLater(
        billing.issueDraft(ctx, draftInvoice(), at: t0),
        throwsA(isA<NoRegisteredClinician>()),
      );
      expect(await billing.invoicesForPatient(patientId), isEmpty);
      expect(await billing.ledger(patientId), isEmpty);
    });

    test('a successful issue writes the invoice, ledger and audit', () async {
      final issued = await env.repos.billing.issueDraft(
        ctx,
        draftInvoice(),
        at: t0,
      );
      expect(issued.status, InvoiceStatus.issued);
      expect(issued.number, startsWith('DRAFT-INV-'));
      expect(await env.repos.billing.ledger(patientId), hasLength(1));
      expect(
        (await env.repos.audit.forEntity(
          clinicId,
          'Invoice',
          issued.id,
        )).map((e) => e.action),
        containsAll([AuditAction.create, AuditAction.statusChange]),
      );
    });
  });

  group('per-stage billing guard', () {
    setUp(() async {
      await env.repos.chart.createProcedure(ctx, procedure());
      await env.repos.chart.advanceStage(ctx, 'proc-1', at: t0);
    });

    test(
      'each stage is billable once; a whole-procedure line collides',
      () async {
        final billing = env.repos.billing;
        final first = await billing.issueDraft(
          ctx,
          draftInvoice(id: 'inv-s1', lines: [stageLine('l1', 0)]),
          at: t0,
        );
        expect(first.lines.single.stageIndex, 0);

        await expectLater(
          billing.issueDraft(
            ctx,
            draftInvoice(id: 'inv-dup', lines: [stageLine('l2', 0)]),
            at: t1,
          ),
          throwsStateError,
          reason: 'stage 1 is already billed',
        );
        expect(await billing.getInvoice('inv-dup'), isNull);

        await expectLater(
          billing.issueDraft(
            ctx,
            draftInvoice(id: 'inv-whole', lines: [stageLine('l3', null)]),
            at: t1,
          ),
          throwsStateError,
          reason: 'the whole procedure overlaps a billed stage',
        );

        final second = await billing.issueDraft(
          ctx,
          draftInvoice(id: 'inv-s2', lines: [stageLine('l4', 1)]),
          at: t1,
        );
        expect(second.lines.single.stageIndex, 1);
        expect(await billing.invoicesForPatient(patientId), hasLength(2));
      },
    );

    test('voiding an invoice frees its stages', () async {
      final billing = env.repos.billing;
      await billing.issueDraft(
        ctx,
        draftInvoice(id: 'inv-s1', lines: [stageLine('l1', 0)]),
        at: t0,
      );
      await billing.voidInvoice(ctx, 'inv-s1', reason: 'Wrong fee', at: t1);
      final again = await billing.issueDraft(
        ctx,
        draftInvoice(id: 'inv-s1b', lines: [stageLine('l2', 0)]),
        at: t2,
      );
      expect(again.status, InvoiceStatus.issued);
    });
  });

  group('recordPayment validation', () {
    late Invoice invoice;

    setUp(() async {
      invoice = await env.repos.billing.issueDraft(ctx, draftInvoice(), at: t0);
      expect(invoice.grandTotal, const Money.rupees(16800));
    });

    Payment pay({
      String id = 'p-1',
      String? invoiceId = 'inv-1',
      String forPatient = patientId,
      Money amount = const Money.rupees(1000),
      bool isRefund = false,
    }) => Payment(
      id: id,
      clinicId: clinicId,
      patientId: forPatient,
      invoiceId: invoiceId,
      amount: amount,
      method: PaymentMethod.cash,
      receivedAt: t1,
      receivedBy: dentistId,
      isRefund: isRefund,
      createdAt: t1,
    );

    test('rejects a payment from another patient', () async {
      await env.repos.patients.upsert(
        ctx,
        patient(id: 'patient-2', number: 'P-00002', phone: '9000000099'),
      );
      await expectLater(
        env.repos.billing.recordPayment(ctx, pay(forPatient: 'patient-2')),
        throwsArgumentError,
      );
      expect(await env.repos.billing.paymentsForInvoice('inv-1'), isEmpty);
      expect(await env.repos.billing.ledger('patient-2'), isEmpty);
    });

    test('rejects zero and negative amounts', () async {
      expect(
        () => env.repos.billing.recordPayment(
          ctx,
          pay(amount: const Money.zero()),
        ),
        throwsArgumentError,
      );
      expect(
        () => env.repos.billing.recordPayment(
          ctx,
          pay(amount: const Money.rupees(-500)),
        ),
        throwsArgumentError,
      );
      expect(await env.repos.billing.paymentsForInvoice('inv-1'), isEmpty);
    });

    test('rejects an overpayment unless flagged as an advance', () async {
      final billing = env.repos.billing;
      await expectLater(
        billing.recordPayment(ctx, pay(amount: const Money.rupees(20000))),
        throwsArgumentError,
      );
      expect(await billing.paymentsForInvoice('inv-1'), isEmpty);

      await billing.recordPayment(
        ctx,
        pay(amount: const Money.rupees(20000)),
        allowAdvance: true,
      );
      final stored = (await billing.getInvoice('inv-1'))!;
      expect(stored.status, InvoiceStatus.paid);
      expect(stored.amountPaid, const Money.rupees(20000));
      expect(
        await billing.patientBalance(patientId),
        const Money.rupees(-3200),
        reason: 'the excess stays as credit on the ledger',
      );
    });

    test('an unlinked payment is an advance without a flag', () async {
      await env.repos.billing.recordPayment(
        ctx,
        pay(invoiceId: null, amount: const Money.rupees(500)),
      );
      expect(
        await env.repos.billing.patientBalance(patientId),
        const Money.rupees(16800 - 500),
      );
    });

    test('refunds only up to the amount paid', () async {
      final billing = env.repos.billing;
      await billing.recordPayment(ctx, pay(amount: const Money.rupees(6800)));
      await expectLater(
        billing.recordPayment(
          ctx,
          pay(id: 'r-1', amount: const Money.rupees(7000), isRefund: true),
        ),
        throwsArgumentError,
      );
      await billing.recordPayment(
        ctx,
        pay(id: 'r-2', amount: const Money.rupees(6800), isRefund: true),
      );
      final stored = (await billing.getInvoice('inv-1'))!;
      expect(stored.amountPaid, const Money.zero());
      expect(stored.status, InvoiceStatus.issued);
      // Unlinked refund: only up to the credit on account (none here).
      await expectLater(
        billing.recordPayment(
          ctx,
          pay(
            id: 'r-3',
            invoiceId: null,
            amount: const Money.rupees(1),
            isRefund: true,
          ),
        ),
        throwsArgumentError,
      );
    });
  });

  group('acceptPlan', () {
    test('records why the patient declined a written estimate', () async {
      final plans = env.repos.treatmentPlans;
      await plans.savePlan(ctx, plan(), [planLine()]);
      final accepted = await plans.acceptPlan(
        ctx,
        'plan-1',
        signerName: 'Anil Kumar',
        signatureHash: 'sig',
        estimateDeclinedReason: '  Patient refused a written estimate ',
        at: t1,
      );
      expect(accepted.isAccepted, isTrue);
      expect(
        accepted.estimateDeclinedReason,
        'Patient refused a written estimate',
      );
      expect(
        (await plans.getPlan('plan-1'))!.estimateDeclinedReason,
        'Patient refused a written estimate',
        reason: 'the reason is a column, not only on the returned object',
      );
      final events = await env.repos.audit.forEntity(
        clinicId,
        'TreatmentPlan',
        'plan-1',
      );
      expect(
        events.last.reason,
        'Patient declined a written estimate: Patient refused a written '
        'estimate',
      );
    });

    test('a blank reason is stored as none', () async {
      final plans = env.repos.treatmentPlans;
      await plans.savePlan(ctx, plan(), [planLine()]);
      final accepted = await plans.acceptPlan(
        ctx,
        'plan-1',
        signerName: 'Anil Kumar',
        estimateDeclinedReason: '   ',
        at: t1,
      );
      expect(accepted.estimateDeclinedReason, isNull);
    });
  });
}
