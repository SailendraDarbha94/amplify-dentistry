import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_data/ampdent_data.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  late TestEnv env;

  setUp(() async => env = await TestEnv.open());
  tearDown(() => env.close());

  group('treatment plans', () {
    test('save, accept with stable snapshot hash, revise', () async {
      final plans = env.repos.treatmentPlans;
      final p = plan();
      final lines = [
        planLine(),
        planLine(id: 'line-2', code: 'CRN-ZIR', tooth: '36', sequence: 1),
        planLine(
          id: 'line-3',
          code: 'CRN-PFM',
          tooth: '36',
          sequence: 2,
          isAlternative: true,
        ),
      ];
      await plans.savePlan(ctx, p, lines.reversed.toList());
      expect((await plans.getPlan(p.id))!.toJson(), equals(p.toJson()));
      final stored = await plans.linesForPlan(p.id);
      expect(stored.map((l) => l.id), ['line-1', 'line-2', 'line-3']);
      expect(stored.first.toJson(), equals(planLine().toJson()));
      expect(
        planSubtotal(stored),
        const Money.rupees(6000 - 500) + const Money.rupees(6000 - 500),
      );

      // Dropping a line marks it removed (no delete) and audits it.
      await plans.savePlan(ctx, p, lines.take(2).toList());
      expect(await plans.linesForPlan(p.id), hasLength(2));
      final removedEvents = await env.repos.audit.forEntity(
        clinicId,
        'TreatmentPlanLine',
        'line-3',
      );
      expect(removedEvents.last.action, AuditAction.softDelete);
      expect(removedEvents.last.after!['removedAt'], isNotNull);

      final expectedHash = computePlanSnapshotHash(
        p,
        lines.take(2).toList().reversed,
      );
      final accepted = await plans.acceptPlan(
        ctx,
        p.id,
        signerName: 'Anil Kumar',
        signatureHash: 'sig',
        at: t1,
      );
      expect(accepted.snapshotHash, expectedHash);
      expect(accepted.status, TreatmentPlanStatus.accepted);
      expect(accepted.isAccepted, isTrue);
      expect(
        () => plans.savePlan(ctx, accepted, lines.take(2).toList()),
        throwsStateError,
      );

      final revised = await plans.revisePlan(ctx, p.id, title: 'v2');
      expect(revised.version, 2);
      expect(revised.supersedesPlanId, p.id);
      expect(
        (await plans.getPlan(p.id))!.status,
        TreatmentPlanStatus.superseded,
      );
      final revisedLines = await plans.linesForPlan(revised.id);
      expect(revisedLines, hasLength(2));
      expect(revisedLines.map((l) => l.code), ['RCT-MOL', 'CRN-ZIR']);
      expect((await plans.activePlan(patientId))!.id, revised.id);
    });

    test('activatePlan deactivates other active plans', () async {
      final plans = env.repos.treatmentPlans;
      await plans.savePlan(ctx, plan(), [planLine()]);
      await plans.savePlan(ctx, plan(id: 'plan-2'), [
        planLine(id: 'line-9', planId: 'plan-2'),
      ]);
      await plans.activatePlan(ctx, 'plan-2');
      expect(
        (await plans.getPlan('plan-1'))!.status,
        TreatmentPlanStatus.inactive,
      );
      expect((await plans.activePlan(patientId))!.id, 'plan-2');
    });
  });

  group('estimates', () {
    test('v1 from plan, v2 requires justification', () async {
      final plans = env.repos.treatmentPlans;
      await plans.savePlan(ctx, plan(), [
        planLine(),
        planLine(
          id: 'line-2',
          code: 'WHITENING-OFFICE',
          unitFee: const Money.rupees(10000),
          gstClass: GstClass.cosmeticTaxable,
          sequence: 1,
        ),
        planLine(id: 'line-3', code: 'ALT', sequence: 2, isAlternative: true),
      ]);
      final v1 = await plans.estimateFromPlan(ctx, 'plan-1', at: t0);
      expect(v1.version, 1);
      expect(v1.number, startsWith('DRAFT-EST-'));
      expect(v1.lines, hasLength(2));
      expect(v1.subtotal, const Money.rupees(16000));
      expect(v1.discountTotal, const Money.rupees(1000));
      // 18% on the cosmetic line's net 9,500 = 1,710.
      expect(v1.taxTotal, const Money.rupees(1710));
      expect(v1.grandTotal, const Money.rupees(15000 + 1710));
      expect(v1.status, EstimateStatus.issued);
      expect((await plans.getEstimate(v1.id))!.toJson(), equals(v1.toJson()));

      expect(() => plans.estimateFromPlan(ctx, 'plan-1'), throwsArgumentError);
      expect(
        () => plans.issueEstimate(
          ctx,
          Estimate(
            id: 'est-x',
            clinicId: clinicId,
            patientId: patientId,
            planId: 'plan-1',
            version: 2,
            number: '',
            subtotal: const Money.zero(),
            discountTotal: const Money.zero(),
            taxTotal: const Money.zero(),
            grandTotal: const Money.zero(),
            issuedAt: t0,
            issuedBy: dentistId,
            justification: '   ',
            createdAt: t0,
          ),
        ),
        throwsArgumentError,
      );

      final v2 = await plans.estimateFromPlan(
        ctx,
        'plan-1',
        justification: 'Patient chose zirconia',
        at: t1,
      );
      expect(v2.version, 2);
      final all = await plans.estimatesForPlan('plan-1');
      expect(all.map((e) => e.version), [1, 2]);
      expect(all.first.status, EstimateStatus.superseded);
      expect(all.last.status, EstimateStatus.issued);
    });
  });

  group('billing', () {
    test('issue computes totals, mints DRAFT number, posts a charge', () async {
      final billing = env.repos.billing;
      final draft = await billing.saveDraft(ctx, draftInvoice());
      expect(draft.status, InvoiceStatus.draft);
      expect(draft.number, startsWith('DRAFT-INV-'));
      expect(draft.isDraftNumber, isTrue);
      expect(draft.subtotal, const Money.rupees(15000));
      expect(await billing.ledger(patientId), isEmpty);

      final issued = await billing.issueInvoice(ctx, draft.id, at: t0);
      expect(issued.status, InvoiceStatus.issued);
      expect(issued.number, draft.number);
      expect(issued.documentType, InvoiceDocumentType.invoiceCumBillOfSupply);
      expect(issued.lines.first.taxRatePercent, 0);
      expect(issued.lines.last.taxRatePercent, 18);
      expect(issued.taxableTotal, const Money.rupees(15000));
      expect(issued.taxTotal, const Money.rupees(1800));
      expect(issued.grandTotal, const Money.rupees(16800));
      expect(issued.balance, const Money.rupees(16800));
      expect(() => billing.issueInvoice(ctx, draft.id), throwsStateError);
      expect(() => billing.saveDraft(ctx, draftInvoice()), throwsStateError);

      final ledger = await billing.ledger(patientId);
      expect(ledger.single.entryType, LedgerEntryType.charge);
      expect(ledger.single.amount, const Money.rupees(16800));
      expect(ledger.single.referenceId, issued.id);
      expect(
        await billing.patientBalance(patientId),
        const Money.rupees(16800),
      );
    });

    test('payments reduce the balance and move the status', () async {
      final billing = env.repos.billing;
      final draft = await billing.saveDraft(ctx, draftInvoice());
      await billing.issueInvoice(ctx, draft.id, at: t0);

      await billing.recordPayment(ctx, payment());
      var inv = await billing.getInvoice('inv-1');
      expect(inv!.status, InvoiceStatus.partiallyPaid);
      expect(inv.amountPaid, const Money.rupees(6800));
      expect(inv.balance, const Money.rupees(10000));
      expect(
        await billing.patientBalance(patientId),
        const Money.rupees(10000),
      );

      await billing.recordPayment(
        ctx,
        payment(id: 'pay-2', amount: const Money.rupees(10000), receivedAt: t2),
      );
      inv = await billing.getInvoice('inv-1');
      expect(inv!.status, InvoiceStatus.paid);
      expect(inv.balance, const Money.zero());
      expect(await billing.patientBalance(patientId), const Money.zero());
      expect(
        await billing.watchPatientBalance(patientId).first,
        const Money.zero(),
      );
      expect(await billing.paymentsForInvoice('inv-1'), hasLength(2));
      expect(
        (await billing.paymentsForPatient(patientId)).first.toJson(),
        equals(
          payment(
            id: 'pay-2',
            amount: const Money.rupees(10000),
            receivedAt: t2,
          ).toJson(),
        ),
      );
      expect(() => billing.recordPayment(ctx, payment()), throwsStateError);
      expect(
        () => billing.recordPayment(
          ctx,
          payment(id: 'pay-3', amount: const Money.zero()),
        ),
        throwsArgumentError,
      );
      // Ledger has charge + two payments, atomically written.
      final ledger = await billing.ledger(patientId);
      expect(ledger.map((e) => e.entryType), [
        LedgerEntryType.charge,
        LedgerEntryType.payment,
        LedgerEntryType.payment,
      ]);
      expect(
        (await env.repos.audit.forEntity(
          clinicId,
          'Payment',
          'pay-1',
        )).single.action,
        AuditAction.create,
      );
    });

    test('void requires a reason and reverses the charge', () async {
      final billing = env.repos.billing;
      final draft = await billing.saveDraft(ctx, draftInvoice());
      await billing.issueInvoice(ctx, draft.id, at: t0);
      expect(
        () => billing.voidInvoice(ctx, draft.id, reason: ' '),
        throwsArgumentError,
      );
      final voided = await billing.voidInvoice(
        ctx,
        draft.id,
        reason: 'Wrong patient',
        at: t1,
      );
      expect(voided.status, InvoiceStatus.voided);
      expect(voided.voidReason, 'Wrong patient');
      expect(await billing.patientBalance(patientId), const Money.zero());
      expect(await billing.outstandingInvoices(clinicId), isEmpty);
      final events = await env.repos.audit.forEntity(
        clinicId,
        'Invoice',
        draft.id,
      );
      expect(events.last.reason, 'Wrong patient');
      expect(
        () => billing.voidInvoice(ctx, draft.id, reason: 'again'),
        throwsStateError,
      );
    });

    test('adjustments post to the ledger by type', () async {
      final billing = env.repos.billing;
      final draft = await billing.saveDraft(ctx, draftInvoice());
      await billing.issueInvoice(ctx, draft.id, at: t0);
      await billing.recordAdjustment(ctx, adjustment());
      expect(
        await billing.patientBalance(patientId),
        const Money.rupees(16800 - 500),
      );
      expect(
        () => billing.recordAdjustment(
          ctx,
          Adjustment(
            id: 'adj-2',
            clinicId: clinicId,
            patientId: patientId,
            type: AdjustmentType.writeOff,
            amount: const Money.rupees(1),
            reason: '',
            approvedBy: dentistId,
            createdAt: t0,
          ),
        ),
        throwsArgumentError,
      );
      expect(
        (await billing.adjustmentsForPatient(patientId)).single.toJson(),
        equals(adjustment().toJson()),
      );
    });

    test('aging buckets outstanding balances', () async {
      final billing = env.repos.billing;
      Future<void> issue(String id, DateTime issuedAt) async {
        await billing.saveDraft(
          ctx,
          draftInvoice(
            id: id,
            issuedAt: issuedAt,
            lines: [invoiceLine(id: 'l-$id')],
          ),
        );
        await billing.issueInvoice(ctx, id, at: issuedAt);
      }

      final asOf = DateTime.utc(2026, 10, 18);
      await issue('inv-a', asOf.subtract(const Duration(days: 5)));
      await issue('inv-b', asOf.subtract(const Duration(days: 45)));
      await issue('inv-c', asOf.subtract(const Duration(days: 75)));
      await issue('inv-d', asOf.subtract(const Duration(days: 120)));
      await billing.recordPayment(
        ctx,
        payment(
          id: 'p-d',
          invoiceId: 'inv-d',
          amount: const Money.rupees(5000),
        ),
      );
      final aging = await billing.aging(clinicId, asOf: asOf);
      expect(aging.keys, agingBucketKeys);
      expect(aging['0-30'], const Money.rupees(5000));
      expect(aging['31-60'], const Money.rupees(5000));
      expect(aging['61-90'], const Money.rupees(5000));
      expect(aging['90+'], const Money.zero());
      expect(await billing.outstandingInvoices(clinicId), hasLength(3));
      expect(
        await billing.patientBalance(patientId),
        const Money.rupees(15000),
      );
    });

    test('unregistered clinic issues receipts', () async {
      final db = AppDatabase.inMemory();
      final repos = DriftRepositories(db);
      await repos.clinics.createClinic(ctx, clinic(gstin: null));
      await repos.patients.upsert(ctx, patient());
      await repos.billing.saveDraft(ctx, draftInvoice());
      final issued = await repos.billing.issueInvoice(ctx, 'inv-1');
      expect(issued.documentType, InvoiceDocumentType.receipt);
      await db.close();
    });
  });
}
