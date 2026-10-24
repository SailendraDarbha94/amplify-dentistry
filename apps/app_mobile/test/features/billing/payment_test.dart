import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/features/billing/billing_actions.dart';
import 'package:ampdent_mobile/features/billing/billing_strings.dart';
import 'package:ampdent_mobile/features/billing/payment_form_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'billing_fixtures.dart';
import 'billing_test_env.dart';

void main() {
  group('PaymentValidators', () {
    test('card last4 rejects a full card number and accepts four digits', () {
      expect(
        PaymentValidators.cardLast4('4111111111111111'),
        BillingStrings.neverFullCard,
      );
      expect(PaymentValidators.cardLast4('411'), isNotNull);
      expect(PaymentValidators.cardLast4('12a4'), isNotNull);
      expect(PaymentValidators.cardLast4('1234'), isNull);
    });

    test('amount must be positive and within the max', () {
      expect(PaymentValidators.amount(''), BillingStrings.amountRequired);
      expect(PaymentValidators.amount('0'), BillingStrings.amountRequired);
      expect(PaymentValidators.amount('abc'), BillingStrings.amountRequired);
      expect(
        PaymentValidators.amount('1,500.50', max: const Money.rupees(1000)),
        BillingStrings.amountExceedsBalance,
      );
      expect(
        PaymentValidators.amount('999', max: const Money.rupees(1000)),
        isNull,
      );
      expect(
        PaymentValidators.parseAmount('₹ 1,250.5'),
        const Money.paise(125050),
      );
    });

    test('reasons are mandatory', () {
      expect(PaymentValidators.reason('   '), BillingStrings.reasonRequired);
      expect(PaymentValidators.reason('Patient changed mind'), isNull);
    });
  });

  test('upiPaymentUri carries VPA, name, amount, currency and note', () {
    final uri = upiPaymentUri(
      vpa: 'smile@upi',
      payeeName: 'Smile Dental',
      amount: const Money.paise(125050),
      note: 'DRAFT-INV-202610-0001',
    );
    expect(uri.scheme, 'upi');
    expect(uri.host, 'pay');
    expect(uri.queryParameters['pa'], 'smile@upi');
    expect(uri.queryParameters['pn'], 'Smile Dental');
    expect(uri.queryParameters['am'], '1250.50');
    expect(uri.queryParameters['cu'], 'INR');
    expect(uri.queryParameters['tn'], 'DRAFT-INV-202610-0001');
  });

  group('payments against an issued invoice', () {
    late BillingTestEnv env;
    late Invoice invoice;
    late PaymentRecorder recorder;

    setUp(() async {
      env = await BillingTestEnv.open();
      invoice = await issueFixtureInvoice(env, await seedTwoProcedures(env));
      recorder = PaymentRecorder(billing: env.repos.billing, ctx: testCtx);
    });
    tearDown(() => env.close());

    test('partial payment moves to partiallyPaid, the rest to paid', () async {
      await recorder.recordPayment(
        patientId: testPatientId,
        invoiceId: invoice.id,
        amount: const Money.rupees(10000),
        method: PaymentMethod.cash,
        now: billingNow,
      );
      var stored = (await env.repos.billing.getInvoice(invoice.id))!;
      expect(stored.status, InvoiceStatus.partiallyPaid);
      expect(stored.amountPaid, const Money.rupees(10000));
      expect(stored.balance, const Money.rupees(5440));
      expect(
        await env.repos.billing.patientBalance(testPatientId),
        const Money.rupees(5440),
      );

      await recorder.recordPayment(
        patientId: testPatientId,
        invoiceId: invoice.id,
        amount: const Money.rupees(5440),
        method: PaymentMethod.upi,
        reference: 'UTR123',
        now: billingNow.add(const Duration(minutes: 5)),
      );
      stored = (await env.repos.billing.getInvoice(invoice.id))!;
      expect(stored.status, InvoiceStatus.paid);
      expect(stored.balance, const Money.zero());
      expect(
        await env.repos.billing.patientBalance(testPatientId),
        const Money.zero(),
      );
      final payments = await env.repos.billing.paymentsForInvoice(invoice.id);
      expect(payments.map((p) => p.method), [
        PaymentMethod.cash,
        PaymentMethod.upi,
      ]);
      expect(payments.last.reference, 'UTR123');
    });

    test('card payment stores last4 and brand only, never a PAN', () async {
      await expectLater(
        recorder.recordPayment(
          patientId: testPatientId,
          invoiceId: invoice.id,
          amount: const Money.rupees(1000),
          method: PaymentMethod.card,
          cardLast4: '4111111111111111',
          cardBrand: 'Visa',
          now: billingNow,
        ),
        throwsArgumentError,
      );
      expect(await env.repos.billing.paymentsForInvoice(invoice.id), isEmpty);

      final paid = await recorder.recordPayment(
        patientId: testPatientId,
        invoiceId: invoice.id,
        amount: const Money.rupees(1000),
        method: PaymentMethod.card,
        cardLast4: '1111',
        cardBrand: 'Visa',
        now: billingNow,
      );
      expect(paid.cardLast4, '1111');
      expect(paid.cardBrand, 'Visa');
      expect(paid.gatewayToken, isNull);
    });

    test('refund needs a reason and reverses the invoice status', () async {
      await recorder.recordPayment(
        patientId: testPatientId,
        invoiceId: invoice.id,
        amount: invoice.grandTotal,
        method: PaymentMethod.cash,
        now: billingNow,
      );
      await expectLater(
        recorder.recordRefund(
          patientId: testPatientId,
          invoiceId: invoice.id,
          amount: const Money.rupees(500),
          method: PaymentMethod.cash,
          reason: ' ',
          now: billingNow,
        ),
        throwsArgumentError,
      );
      final refund = await recorder.recordRefund(
        patientId: testPatientId,
        invoiceId: invoice.id,
        amount: const Money.rupees(500),
        method: PaymentMethod.cash,
        reason: 'Overcharged',
        now: billingNow.add(const Duration(minutes: 1)),
      );
      expect(refund.isRefund, isTrue);
      expect(refund.note, 'Overcharged');
      final stored = (await env.repos.billing.getInvoice(invoice.id))!;
      expect(stored.status, InvoiceStatus.partiallyPaid);
      expect(stored.amountPaid, invoice.grandTotal - const Money.rupees(500));
      expect(
        await env.repos.billing.patientBalance(testPatientId),
        const Money.rupees(500),
      );
    });

    test('void requires a reason and reverses the charge', () async {
      final issuer = InvoiceIssuer(billing: env.repos.billing, ctx: testCtx);
      await expectLater(
        issuer.voidInvoice(invoice.id, reason: '   '),
        throwsArgumentError,
      );
      expect(
        (await env.repos.billing.getInvoice(invoice.id))!.status,
        InvoiceStatus.issued,
      );

      final voided = await issuer.voidInvoice(
        invoice.id,
        reason: 'Duplicate entry',
        at: billingNow,
      );
      expect(voided.status, InvoiceStatus.voided);
      expect(voided.voidReason, 'Duplicate entry');
      expect(
        await env.repos.billing.patientBalance(testPatientId),
        const Money.zero(),
      );
    });

    test(
      'link requests carry number, amount and link but no clinical text',
      () async {
        final clinic = testClinic();
        final patient = testPatient();
        final request = invoiceLinkRequest(
          clinic: clinic,
          patient: patient,
          invoice: invoice,
          now: billingNow,
        );
        expect(request.template.code, 'INVOICE_LINK');
        expect(request.toPhone, patient.phone);
        final body = request.render();
        expect(body, contains(invoice.number));
        expect(body, contains('₹15,440.00'));
        expect(body, contains(invoiceLinkUrl(invoice)));
        expect(body, isNot(contains('Root canal')));
        expect(body, isNot(contains('Whitening')));
      },
    );
  });
}
