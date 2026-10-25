import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_data/ampdent_data.dart';
import 'package:ampdent_mobile/features/billing/billing_actions.dart';
import 'package:ampdent_mobile/features/billing/billing_reports.dart';
import 'package:ampdent_mobile/features/billing/invoice_draft.dart';
import 'package:ampdent_terminology/ampdent_terminology.dart';
import 'package:flutter_test/flutter_test.dart';

import 'billing_fixtures.dart';
import 'billing_test_env.dart';

void main() {
  group('draft lines', () {
    test('preselects completed work and takes GST class from catalogue', () {
      final lines = draftLinesFromProcedures(
        [
          completedProcedure(
            id: 'a',
            code: 'RCT-MOL',
            tooth: ToothId.parse('46'),
          ),
          completedProcedure(id: 'b', code: 'WHITENING-OFFICE'),
          completedProcedure(
            id: 'c',
            code: 'CRN-ZIR',
            status: ProcedureStatus.inProgress,
          ),
        ],
        catalog: fixtureCatalog(),
        notation: ToothNotation.fdi,
        preselectedIds: const {'c'},
      );
      expect(lines, hasLength(3));
      expect(lines[0].selected, isTrue);
      expect(lines[0].line.gstClass, GstClass.exemptHealthcare);
      expect(lines[0].line.sacHsnCode, '999312');
      expect(lines[0].line.tooth, ToothId.parse('46'));
      expect(lines[1].line.gstClass, GstClass.cosmeticTaxable);
      expect(lines[1].catalogGstClass, GstClass.cosmeticTaxable);
      expect(lines[1].gstClassOverridden, isFalse);
      // Unknown catalogue item falls back to exempt but is still selectable.
      expect(lines[2].selected, isTrue);
      expect(lines[2].catalogGstClass, isNull);

      final overridden = lines[0].copyWith(
        line: lines[0].line.copyWith(gstClass: GstClass.standardTaxable),
      );
      expect(overridden.gstClassOverridden, isTrue);
    });

    test('exempt + cosmetic 18% totals and Rule 46A document type', () {
      final lines = draftLinesFromProcedures(
        [
          completedProcedure(id: 'a', code: 'RCT-MOL'),
          completedProcedure(id: 'b', code: 'WHITENING-OFFICE'),
        ],
        catalog: fixtureCatalog(),
        notation: ToothNotation.fdi,
      );
      final draft = buildDraftInvoice(
        id: 'inv',
        clinicId: testClinicId,
        patientId: testPatientId,
        issuedBy: testDentistId,
        lines: lines,
        rates: GstRateTable.indiaDefaults(),
        clinicGstRegistered: true,
        now: billingNow,
      );
      expect(draft.subtotal, const Money.rupees(14000));
      expect(draft.discountTotal, const Money.zero());
      expect(draft.taxTotal, const Money.rupees(1440));
      expect(draft.grandTotal, const Money.rupees(15440));
      expect(draft.documentType, InvoiceDocumentType.invoiceCumBillOfSupply);
      expect(draft.lines[0].taxRatePercent, 0);
      expect(draft.lines[1].taxRatePercent, 18);
      expect(draft.lines[1].taxAmount, const Money.rupees(1440));

      final unregistered = buildDraftInvoice(
        id: 'inv2',
        clinicId: testClinicId,
        patientId: testPatientId,
        issuedBy: testDentistId,
        lines: lines,
        rates: GstRateTable.indiaDefaults(),
        clinicGstRegistered: false,
        now: billingNow,
      );
      expect(unregistered.documentType, InvoiceDocumentType.receipt);

      final exemptOnly = buildDraftInvoice(
        id: 'inv3',
        clinicId: testClinicId,
        patientId: testPatientId,
        issuedBy: testDentistId,
        lines: [lines[0], lines[1].copyWith(selected: false)],
        rates: GstRateTable.indiaDefaults(),
        clinicGstRegistered: true,
        now: billingNow,
      );
      expect(exemptOnly.documentType, InvoiceDocumentType.billOfSupply);
      expect(exemptOnly.grandTotal, const Money.rupees(6000));
    });

    test('discount reduces the taxable value before GST', () {
      final line = draftLinesFromProcedures(
        [
          completedProcedure(
            id: 'b',
            code: 'WHITENING-OFFICE',
            discount: const Money.rupees(1000),
          ),
        ],
        catalog: fixtureCatalog(),
        notation: ToothNotation.fdi,
      ).single;
      final draft = buildDraftInvoice(
        id: 'inv',
        clinicId: testClinicId,
        patientId: testPatientId,
        issuedBy: testDentistId,
        lines: [line],
        rates: GstRateTable.indiaDefaults(),
        clinicGstRegistered: true,
        now: billingNow,
      );
      expect(draft.taxableTotal, const Money.rupees(7000));
      expect(draft.taxTotal, const Money.rupees(1260));
      expect(draft.grandTotal, const Money.rupees(8260));
      expect(
        line
            .copyWith(
              line: line.line.copyWith(discount: const Money.rupees(9000)),
            )
            .discountTooLarge,
        isTrue,
      );
    });
  });

  group('issue through the repository', () {
    late BillingTestEnv env;

    setUp(() async => env = await BillingTestEnv.open());
    tearDown(() => env.close());

    test(
      'mints a DRAFT number, posts the charge and marks work billed',
      () async {
        final procedures = await seedTwoProcedures(env);
        final issued = await issueFixtureInvoice(env, procedures);
        expect(issued.status, InvoiceStatus.issued);
        expect(issued.number, startsWith('DRAFT-INV-'));
        expect(issued.isDraftNumber, isTrue);
        expect(issued.taxTotal, const Money.rupees(1440));
        expect(issued.grandTotal, const Money.rupees(15440));
        expect(issued.documentType, InvoiceDocumentType.invoiceCumBillOfSupply);

        expect(
          await env.repos.billing.patientBalance(testPatientId),
          const Money.rupees(15440),
        );
        final invoices = await env.repos.billing.invoicesForPatient(
          testPatientId,
        );
        expect(billedProcedureIds(invoices), {'proc-rct', 'proc-whitening'});
        final audit = await env.repos.audit.forEntity(
          testClinicId,
          'Invoice',
          issued.id,
        );
        expect(audit.map((a) => a.action), contains(AuditAction.statusChange));
      },
    );
  });

  group('multi-sitting work is billed per stage', () {
    late BillingTestEnv env;

    setUp(() async => env = await BillingTestEnv.open());
    tearDown(() => env.close());

    ProcedureRecord stagedRct() {
      final seed = procedureSeedByCode('RCT-MOL')!;
      return ProcedureRecord(
        id: 'proc-rct',
        clinicId: testClinicId,
        patientId: testPatientId,
        catalogItemId: seedId('catalog', 'RCT-MOL'),
        code: 'RCT-MOL',
        name: seed.name,
        tooth: ToothId.parse('46'),
        treatmentArea: seed.treatmentArea,
        providerId: testDentistId,
        fee: const Money.rupees(6000),
        totalStages: 3,
        stageNames: const ['Access', 'Obturation', 'Review'],
        createdAt: billingNow.toUtc(),
        updatedAt: billingNow.toUtc(),
      );
    }

    Future<Invoice> issueUnbilled(DateTime at) async {
      final procedures = await env.repos.chart.proceduresForPatient(
        testPatientId,
      );
      final invoices = await env.repos.billing.invoicesForPatient(
        testPatientId,
      );
      final stages = unbilledStages(procedures, invoices);
      expect(stages, hasLength(1), reason: 'one new stage per sitting');
      final lines = draftLinesFromStages(
        stages,
        catalog: fixtureCatalog(),
        notation: ToothNotation.fdi,
      );
      expect(lines.single.selected, isTrue);
      final rates = await env.repos.clinics.loadGstRateTable(testClinicId);
      return InvoiceIssuer(billing: env.repos.billing, ctx: testCtx).issue(
        buildDraftInvoice(
          id: newId(),
          clinicId: testClinicId,
          patientId: testPatientId,
          issuedBy: testDentistId,
          lines: lines,
          rates: rates,
          clinicGstRegistered: true,
          now: at,
        ),
        rates: rates,
        at: at,
      );
    }

    test('an RCT is billed across three invoices summing to the fee', () async {
      await env.repos.chart.createProcedure(testCtx, stagedRct());
      expect(
        unbilledStages(
          await env.repos.chart.proceduresForPatient(testPatientId),
          const [],
        ),
        isEmpty,
        reason: 'planned work is not billable',
      );

      final issued = <Invoice>[];
      for (var sitting = 0; sitting < 3; sitting++) {
        final at = billingNow.add(Duration(days: 7 * sitting));
        await env.repos.chart.advanceStage(testCtx, 'proc-rct', at: at);
        issued.add(await issueUnbilled(at));
        final line = issued.last.lines.single;
        expect(line.procedureId, 'proc-rct');
        expect(line.stageIndex, sitting);
        expect(line.unitPrice, const Money.rupees(2000));
        expect(line.description, contains('stage ${sitting + 1} of 3'));
      }
      expect(issued.map((i) => i.lines.single.description).toList(), [
        contains('Access'),
        contains('Obturation'),
        contains('Review'),
      ]);
      expect(issued.map((i) => i.grandTotal).total, const Money.rupees(6000));
      final proc = (await env.repos.chart.getProcedure('proc-rct'))!;
      expect(proc.status, ProcedureStatus.completed);
      expect(
        unbilledStages([
          proc,
        ], await env.repos.billing.invoicesForPatient(testPatientId)),
        isEmpty,
        reason: 'nothing left to bill once every stage is on an invoice',
      );
      expect(
        await env.repos.billing.patientBalance(testPatientId),
        const Money.rupees(6000),
      );
    });

    test('completed single-sitting work bills once in full', () async {
      final procedures = await seedTwoProcedures(env);
      final stages = unbilledStages(procedures, const []);
      expect(stages.map((s) => s.stageIndex), [null, null]);
      expect(stages.first.fee, procedures.first.fee);
      final lines = draftLinesFromStages(
        stages,
        catalog: fixtureCatalog(),
        notation: ToothNotation.fdi,
      );
      expect(lines.map((l) => l.keySuffix), ['proc-rct', 'proc-whitening']);
      expect(lines.first.line.description, isNot(contains('stage')));
      final invoice = await issueFixtureInvoice(env, procedures);
      expect(
        unbilledStages(procedures, [invoice]),
        isEmpty,
        reason: 'billed work is excluded forever (until voided)',
      );
    });

    test('stage instalments split the fee and discount exactly', () {
      final rct = stagedRct().copyWith(
        fee: const Money.rupees(5000),
        discount: const Money.rupees(100),
        status: ProcedureStatus.completed,
        stageIndex: 2,
      );
      final stages = reachedStages(rct);
      expect(stages.map((s) => s.stageIndex), [0, 1, 2]);
      expect(stages.map((s) => s.fee).total, const Money.rupees(5000));
      expect(stages.map((s) => s.discount).total, const Money.rupees(100));
      expect(stages.map((s) => s.key), [
        'proc-rct-s0',
        'proc-rct-s1',
        'proc-rct-s2',
      ]);
    });

    test('a refused issue strands no DRAFT invoice', () async {
      await env.repos.clinics.upsertMember(
        testCtx,
        testDentist().copyWith(registrationNumber: ''),
      );
      final procedures = await seedTwoProcedures(env);
      await expectLater(
        issueFixtureInvoice(env, procedures),
        throwsA(isA<NoRegisteredClinician>()),
      );
      expect(
        await env.repos.billing.invoicesForPatient(testPatientId),
        isEmpty,
      );
      expect(
        unbilledStages(procedures, const []),
        hasLength(2),
        reason: 'the work is still billable',
      );
    });
  });

  group('ledger helpers', () {
    test('running balance accumulates oldest first', () {
      LedgerEntry entry(String id, int paise, int minute) => LedgerEntry(
        id: id,
        clinicId: testClinicId,
        patientId: testPatientId,
        entryType: paise > 0 ? LedgerEntryType.charge : LedgerEntryType.payment,
        amount: Money.paise(paise),
        referenceId: id,
        occurredAt: DateTime.utc(2026, 10, 1, 10, minute),
        description: id,
      );
      final rows = ledgerWithRunningBalance([
        entry('a', 500000, 0),
        entry('b', -200000, 1),
        entry('c', 100000, 2),
      ]);
      expect(rows.map((r) => r.$2.paise), [500000, 300000, 400000]);
    });

    test('family members share a guardian phone or are the guardian', () {
      final mother = testPatient(id: 'mother', phone: '+919000000010');
      final child = testPatient(
        id: 'child',
        firstName: 'Kiran',
        phone: '+919000000010',
      ).copyWith(guardianName: 'Asha', guardianPhone: '+919000000010');
      final sibling = testPatient(
        id: 'sibling',
        firstName: 'Anu',
        phone: '+919000000011',
      ).copyWith(guardianName: 'Asha', guardianPhone: '+919000000010');
      final stranger = testPatient(id: 'other', phone: '+919000000099');
      final all = [stranger, sibling, mother, child];
      expect(familyMembers(child, all).map((p) => p.id), [
        'child',
        'sibling',
        'mother',
      ]);
      expect(familyMembers(mother, all).map((p) => p.id), [
        'mother',
        'sibling',
        'child',
      ]);
      expect(familyMembers(stranger, all).map((p) => p.id), ['other']);
    });
  });

  group('computeBillingReport', () {
    test('sums the month only', () {
      Payment pay(
        String id,
        int rupees,
        PaymentMethod m,
        DateTime at, {
        bool refund = false,
      }) => Payment(
        id: id,
        clinicId: testClinicId,
        patientId: testPatientId,
        amount: Money.rupees(rupees),
        method: m,
        receivedAt: at,
        receivedBy: testDentistId,
        isRefund: refund,
        createdAt: at,
      );
      final report = computeBillingReport(
        month: DateTime(2026, 10),
        payments: [
          pay('p1', 1000, PaymentMethod.cash, DateTime(2026, 10, 2)),
          pay('p2', 2500, PaymentMethod.upi, DateTime(2026, 10, 20)),
          pay(
            'p3',
            500,
            PaymentMethod.cash,
            DateTime(2026, 10, 21),
            refund: true,
          ),
          pay('p4', 9999, PaymentMethod.card, DateTime(2026, 9, 30)),
        ],
        procedures: [
          completedProcedure(
            id: 'a',
            code: 'RCT-MOL',
            completedAt: DateTime(2026, 10, 5),
          ),
          completedProcedure(
            id: 'b',
            code: 'RCT-MOL',
            completedAt: DateTime(2026, 9, 5),
          ),
        ],
      );
      expect(report.collections, const Money.rupees(3500));
      expect(report.refunds, const Money.rupees(500));
      expect(report.netCollections, const Money.rupees(3000));
      expect(
        report.collectionsByMethod[PaymentMethod.cash],
        const Money.rupees(1000),
      );
      expect(
        report.collectionsByMethod[PaymentMethod.upi],
        const Money.rupees(2500),
      );
      expect(report.collectionsByMethod[PaymentMethod.card], isNull);
      expect(report.production, const Money.rupees(6000));
      expect(report.invoicesIssued, 0);
    });
  });
}
