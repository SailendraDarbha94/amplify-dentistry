import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'billing_providers.dart';
import 'billing_strings.dart';

/// Badge tone for an invoice status.
BadgeTone invoiceStatusTone(InvoiceStatus status) => switch (status) {
  InvoiceStatus.draft => BadgeTone.neutral,
  InvoiceStatus.issued => BadgeTone.warning,
  InvoiceStatus.partiallyPaid => BadgeTone.info,
  InvoiceStatus.paid => BadgeTone.success,
  InvoiceStatus.voided => BadgeTone.danger,
};

/// List of a patient's invoices, newest first.
class InvoicesTab extends ConsumerWidget {
  /// Creates the tab.
  const InvoicesTab({super.key, required this.patientId});

  /// The patient.
  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings;
    final invoices = ref.watch(billingInvoicesProvider(patientId));
    return invoices.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(billingInvoicesProvider(patientId)),
      ),
      data: (list) => list.isEmpty
          ? EmptyState(
              icon: Icons.receipt_long_outlined,
              title: BillingStrings.noInvoices,
              message: BillingStrings.noBillableProceduresHint,
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              itemCount: list.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final inv = list[i];
                return ListTile(
                  key: ValueKey('invoice-row-${inv.id}'),
                  minTileHeight: AppSpacing.minTapTarget,
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: Text(inv.number),
                  subtitle: Text(
                    '${AppFormat.date(inv.issuedAt)} - '
                    '${BillingStrings.documentTypeLabel(inv.documentType)}',
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      MoneyText(
                        AppFormat.money(inv.grandTotal),
                        emphasis: MoneyEmphasis.strong,
                      ),
                      StatusBadge(
                        label: inv.status == InvoiceStatus.partiallyPaid
                            ? '${s.due} ${AppFormat.money(inv.balance)}'
                            : BillingStrings.invoiceStatusLabel(inv.status),
                        tone: invoiceStatusTone(inv.status),
                        dense: true,
                      ),
                    ],
                  ),
                  onTap: () => context.push(
                    '/patients/$patientId/billing/invoice/${inv.id}',
                  ),
                );
              },
            ),
    );
  }
}
