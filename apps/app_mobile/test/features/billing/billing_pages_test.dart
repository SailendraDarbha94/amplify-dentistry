import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/features/billing/billing_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'billing_fixtures.dart';
import 'billing_test_env.dart';

void main() {
  late BillingTestEnv env;

  setUp(() async {
    env = await BillingTestEnv.open();
  });
  tearDown(() => env.close());

  const base = '/patients/$testPatientId/billing';

  testWidgets('new invoice preselects unbilled work and issues it', (
    tester,
  ) async {
    await seedTwoProcedures(env);
    await env.pump(tester, base);
    expect(find.text(BillingStrings.noInvoices), findsOneWidget);
    expect(find.text('₹0.00'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('billing-new-invoice')));
    await settle(tester, frames: 10);
    expect(env.location, '$base/invoice/new');
    expect(
      find.byKey(const ValueKey('inv-line-proc-rct-select')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('inv-line-proc-whitening-select')),
      findsOneWidget,
    );
    // Tooth in FDI notation and totals from the clinic GST table.
    expect(find.textContaining('Tooth 46'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('invoice-grand-total')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await settle(tester, frames: 2);
    expect(find.text('₹15,440.00'), findsOneWidget);
    expect(find.text('₹1,440.00'), findsOneWidget);
    expect(find.text('Invoice-cum-bill of supply'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('invoice-issue')));
    await settle(tester, frames: 12);

    final invoices = await env.repos.billing.invoicesForPatient(testPatientId);
    expect(invoices, hasLength(1));
    final issued = invoices.single;
    expect(issued.status, InvoiceStatus.issued);
    expect(issued.grandTotal, const Money.rupees(15440));
    expect(issued.lines, hasLength(2));
    expect(env.location, '$base/invoice/${issued.id}');
  });

  testWidgets('deselecting the cosmetic line gives a bill of supply', (
    tester,
  ) async {
    await seedTwoProcedures(env);
    await env.pump(tester, '$base/invoice/new');
    await tester.tap(
      find.byKey(const ValueKey('inv-line-proc-whitening-select')),
    );
    await settle(tester, frames: 2);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('invoice-document-type')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await settle(tester, frames: 2);
    expect(find.text('Bill of supply'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('invoice-grand-total')),
        matching: find.text('₹6,000.00'),
      ),
      findsOneWidget,
    );
  });

  group('invoice detail', () {
    late Invoice invoice;

    setUp(() async {
      invoice = await issueFixtureInvoice(env, await seedTwoProcedures(env));
    });

    testWidgets('card payment rejects a full card number, accepts last 4', (
      tester,
    ) async {
      await env.pump(tester, '$base/invoice/${invoice.id}');
      expect(find.text(invoice.number), findsWidgets);
      expect(find.text('Issued'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('invoice-pay')));
      await settle(tester, frames: 8);
      expect(find.byKey(const ValueKey('pay-amount')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('pay-method-card')));
      await settle(tester, frames: 2);
      await tester.enterText(find.byKey(const ValueKey('pay-amount')), '10000');
      await tester.enterText(
        find.byKey(const ValueKey('pay-card-last4')),
        '4111111111111111',
      );
      await tester.tap(find.byKey(const ValueKey('pay-save')));
      await settle(tester, frames: 4);
      expect(find.text(BillingStrings.neverFullCard), findsOneWidget);
      expect(await env.repos.billing.paymentsForInvoice(invoice.id), isEmpty);

      await tester.enterText(
        find.byKey(const ValueKey('pay-card-last4')),
        '1111',
      );
      await tester.tap(find.byKey(const ValueKey('pay-card-brand')));
      await settle(tester, frames: 4);
      await tester.tap(find.text('Visa').last);
      await settle(tester, frames: 4);
      await tester.tap(find.byKey(const ValueKey('pay-save')));
      await settle(tester, frames: 12);

      final payments = await env.repos.billing.paymentsForInvoice(invoice.id);
      expect(payments, hasLength(1));
      expect(payments.single.cardLast4, '1111');
      expect(payments.single.cardBrand, 'Visa');
      final stored = (await env.repos.billing.getInvoice(invoice.id))!;
      expect(stored.status, InvoiceStatus.partiallyPaid);
      expect(find.text('Partly paid'), findsOneWidget);
      expect(find.text('₹5,440.00'), findsWidgets);
    });

    testWidgets('void requires a reason', (tester) async {
      await env.pump(tester, '$base/invoice/${invoice.id}');
      await tester.tap(find.byKey(const ValueKey('invoice-void')));
      await settle(tester, frames: 8);
      await tester.tap(find.byKey(const ValueKey('void-confirm')));
      await settle(tester, frames: 4);
      expect(find.text(BillingStrings.reasonRequired), findsOneWidget);
      expect(
        (await env.repos.billing.getInvoice(invoice.id))!.status,
        InvoiceStatus.issued,
      );

      await tester.enterText(
        find.byKey(const ValueKey('void-reason')),
        'Wrong patient',
      );
      await tester.tap(find.byKey(const ValueKey('void-confirm')));
      await settle(tester, frames: 12);
      final stored = (await env.repos.billing.getInvoice(invoice.id))!;
      expect(stored.status, InvoiceStatus.voided);
      expect(stored.voidReason, 'Wrong patient');
      expect(find.text('Void'), findsOneWidget);
      expect(
        await env.repos.billing.patientBalance(testPatientId),
        const Money.zero(),
      );
    });

    testWidgets('ledger shows running balance and aging', (tester) async {
      await env.pump(tester, base);
      await tester.tap(find.text('Ledger'));
      await settle(tester, frames: 8);
      expect(find.byKey(const ValueKey('aging-0-30')), findsOneWidget);
      expect(find.text('₹15,440'), findsOneWidget);
      expect(find.textContaining('Balance ₹15,440.00'), findsOneWidget);
      expect(find.byKey(const ValueKey('ledger-family-toggle')), findsNothing);
    });
  });
}
