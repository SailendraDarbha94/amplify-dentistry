import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'billing_providers.dart';
import 'billing_strings.dart';
import 'invoices_tab.dart';
import 'ledger_tab.dart';
import 'payment_sheet.dart';
import 'reports_tab.dart';

/// Patient billing: outstanding balance, invoices, ledger with running
/// balance and family view, aging and the month's clinic report.
class PatientBillingPage extends ConsumerWidget {
  /// Creates the page for [patientId].
  const PatientBillingPage({super.key, required this.patientId});

  /// The patient.
  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings;
    final patient = ref.watch(billingPatientProvider(patientId));
    return patient.when(
      loading: () => LoadingScaffold(message: s.loading),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(billingPatientProvider(patientId)),
        ),
      ),
      data: (p) => p == null
          ? Scaffold(
              appBar: AppBar(),
              body: const ErrorView(message: 'Patient not found'),
            )
          : _BillingBody(patient: p),
    );
  }
}

class _BillingBody extends ConsumerWidget {
  const _BillingBody({required this.patient});

  final Patient patient;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings;
    final balance =
        ref.watch(billingBalanceProvider(patient.id)).value ??
        const Money.zero();
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(BillingStrings.billing),
          bottom: TabBar(
            tabs: [
              Tab(text: BillingStrings.invoices),
              Tab(text: s.ledger),
              Tab(text: BillingStrings.reports),
            ],
          ),
        ),
        body: Column(
          children: [
            _BalanceHeader(patient: patient, balance: balance),
            Expanded(
              child: TabBarView(
                children: [
                  InvoicesTab(patientId: patient.id),
                  LedgerTab(patientId: patient.id),
                  ReportsTab(patientId: patient.id),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: AppSpacing.screenPadding,
            child: BigActionButton(
              key: const ValueKey('billing-new-invoice'),
              label: BillingStrings.newInvoice,
              icon: Icons.receipt_long_outlined,
              onPressed: () =>
                  context.push('/patients/${patient.id}/billing/invoice/new'),
            ),
          ),
        ),
      ),
    );
  }
}

class _BalanceHeader extends StatelessWidget {
  const _BalanceHeader({required this.patient, required this.balance});

  final Patient patient;
  final Money balance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final credit = balance.isNegative;
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: AppSpacing.screenPadding,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(patient.displayName, style: theme.textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    credit
                        ? BillingStrings.creditOnAccount
                        : BillingStrings.outstandingBalance,
                    style: theme.textTheme.labelMedium,
                  ),
                  MoneyText(
                    key: const ValueKey('billing-balance'),
                    AppFormat.money(credit ? -balance : balance),
                    emphasis: MoneyEmphasis.hero,
                    color: credit
                        ? AppColors.of(context).success
                        : (balance.isZero
                              ? null
                              : AppColors.of(context).danger),
                  ),
                ],
              ),
            ),
            FilledButton.tonalIcon(
              key: const ValueKey('billing-record-payment'),
              onPressed: () => RecordPaymentSheet.show(
                context,
                patient: patient,
                defaultAmount: balance > const Money.zero()
                    ? balance
                    : const Money.zero(),
              ),
              icon: const Icon(Icons.payments_outlined),
              label: Text(context.strings.payment),
            ),
          ],
        ),
      ),
    );
  }
}
