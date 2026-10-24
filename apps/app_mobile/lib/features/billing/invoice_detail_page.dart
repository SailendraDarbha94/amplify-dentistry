import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_messaging/ampdent_messaging.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'billing_actions.dart';
import 'billing_providers.dart';
import 'billing_strings.dart';
import 'invoice_pdf_page.dart';
import 'invoices_tab.dart';
import 'new_invoice_page.dart';
import 'payment_sheet.dart';
import 'refund_sheet.dart';

/// One invoice: header, lines, totals, payments and the actions (record
/// payment, refund, PDF preview with print/share, WhatsApp link, void with
/// reason). With [openPdf] the PDF preview opens on top right away.
class InvoiceDetailPage extends ConsumerStatefulWidget {
  /// Creates the page.
  const InvoiceDetailPage({
    super.key,
    required this.patientId,
    required this.invoiceId,
    this.openPdf = false,
  });

  /// The patient.
  final String patientId;

  /// The invoice.
  final String invoiceId;

  /// Push the PDF preview as soon as the invoice has loaded.
  final bool openPdf;

  @override
  ConsumerState<InvoiceDetailPage> createState() => _InvoiceDetailPageState();
}

class _InvoiceDetailPageState extends ConsumerState<InvoiceDetailPage> {
  bool _pdfOpened = false;

  InvoiceRef get _ref =>
      (patientId: widget.patientId, invoiceId: widget.invoiceId);

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final invoice = ref.watch(invoiceProvider(_ref));
    final patient = ref.watch(billingPatientProvider(widget.patientId));
    if (invoice.hasError) {
      return Scaffold(
        appBar: AppBar(),
        body: ErrorView(message: invoice.error.toString()),
      );
    }
    if (!invoice.hasValue || !patient.hasValue) {
      return LoadingScaffold(message: s.loading);
    }
    final inv = invoice.requireValue;
    final p = patient.requireValue;
    if (inv == null || p == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const ErrorView(message: 'Invoice not found'),
      );
    }
    if (widget.openPdf && !_pdfOpened) {
      _pdfOpened = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openPdf(p, inv);
      });
    }
    final payments = ref.watch(invoicePaymentsProvider(_ref)).value ?? const [];
    final notation = ref.watch(notationProvider);
    final open =
        inv.status == InvoiceStatus.issued ||
        inv.status == InvoiceStatus.partiallyPaid;
    final canRefund =
        inv.status != InvoiceStatus.voided &&
        inv.amountPaid > const Money.zero();
    return Scaffold(
      appBar: AppBar(
        title: Text(inv.number),
        actions: [
          IconButton(
            key: const ValueKey('invoice-pdf'),
            tooltip: BillingStrings.previewPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () => _openPdf(p, inv),
          ),
          if (inv.status != InvoiceStatus.voided)
            IconButton(
              key: const ValueKey('invoice-void'),
              tooltip: BillingStrings.voidInvoice,
              icon: const Icon(Icons.block_outlined),
              onPressed: () => _void(inv),
            ),
        ],
      ),
      body: ListView(
        padding: AppSpacing.screenPadding,
        children: [
          _Header(invoice: inv, patient: p),
          const SizedBox(height: AppSpacing.md),
          SectionCard(
            title: BillingStrings.linesTitle,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Column(
              children: [
                for (final l in inv.lines)
                  ListTile(
                    dense: true,
                    title: Text(l.description),
                    subtitle: Text(
                      [
                        if (l.tooth != null)
                          '${s.tooth} ${notation.format(l.tooth!)}',
                        '${BillingStrings.sacHsn} ${l.sacHsnCode}',
                        '${s.gst} ${BillingStrings.gstClassLabel(l.gstClass)} '
                            '${AppFormat.percent(l.taxRatePercent)}',
                        if (!l.discount.isZero)
                          '${s.discount} ${AppFormat.money(l.discount)}',
                      ].join(' - '),
                    ),
                    trailing: MoneyText(
                      AppFormat.money(l.lineTotal),
                      emphasis: MoneyEmphasis.strong,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          InvoiceTotalsCard(invoice: inv),
          const SizedBox(height: AppSpacing.md),
          SectionCard(
            title: s.payment,
            trailing: MoneyText(
              AppFormat.money(inv.amountPaid),
              emphasis: MoneyEmphasis.strong,
            ),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: payments.isEmpty
                ? Padding(
                    padding: AppSpacing.horizontalGutter,
                    child: Text(s.nothingHere),
                  )
                : Column(
                    children: [
                      for (final pay in payments)
                        ListTile(
                          key: ValueKey('invoice-payment-${pay.id}'),
                          dense: true,
                          leading: Icon(
                            pay.isRefund
                                ? Icons.undo_outlined
                                : Icons.payments_outlined,
                          ),
                          title: Text(
                            '${pay.isRefund ? BillingStrings.refund : s.payment}'
                            ' - ${BillingStrings.paymentMethodLabel(pay.method)}'
                            '${pay.cardLast4 == null ? '' : ' **** ${pay.cardLast4}'}',
                          ),
                          subtitle: Text(
                            [
                              AppFormat.dateTime(pay.receivedAt),
                              if (pay.reference != null) pay.reference!,
                              if (pay.note != null) pay.note!,
                            ].join(' - '),
                          ),
                          trailing: MoneyText(
                            AppFormat.money(
                              pay.isRefund ? -pay.amount : pay.amount,
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          if (inv.notes != null) ...[
            const SizedBox(height: AppSpacing.md),
            SectionCard(title: s.notes, child: Text(inv.notes!)),
          ],
          if (inv.voidReason != null) ...[
            const SizedBox(height: AppSpacing.md),
            SectionCard(
              title: BillingStrings.voidReason,
              child: Text(inv.voidReason!),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('invoice-send'),
                onPressed: () => _sendLink(p, inv, payments),
                icon: const Icon(Icons.chat_outlined),
                label: Text(BillingStrings.sendLink),
              ),
              if (canRefund)
                OutlinedButton.icon(
                  key: const ValueKey('invoice-refund'),
                  onPressed: () => RefundSheet.show(
                    context,
                    patient: p,
                    invoice: inv,
                    maxAmount: inv.amountPaid,
                  ),
                  icon: const Icon(Icons.undo_outlined),
                  label: Text(BillingStrings.refund),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
      bottomNavigationBar: open
          ? SafeArea(
              child: Padding(
                padding: AppSpacing.screenPadding,
                child: BigActionButton(
                  key: const ValueKey('invoice-pay'),
                  label:
                      '${BillingStrings.recordPayment} '
                      '(${AppFormat.money(inv.balance)})',
                  icon: Icons.payments_outlined,
                  onPressed: () async {
                    final paid = await RecordPaymentSheet.show(
                      context,
                      patient: p,
                      invoice: inv,
                      defaultAmount: inv.balance,
                    );
                    if (paid != null && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(BillingStrings.paymentRecorded)),
                      );
                    }
                  },
                ),
              ),
            )
          : null,
    );
  }

  void _openPdf(Patient patient, Invoice invoice) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => InvoicePdfPage(patient: patient, invoice: invoice),
      ),
    );
  }

  Future<void> _void(Invoice invoice) async {
    final reason = await VoidReasonSheet.show(
      context,
      invoiceNumber: invoice.number,
    );
    if (reason == null || !mounted) return;
    try {
      await InvoiceIssuer(
        billing: ref.read(billingRepositoryProvider),
        ctx: ref.read(actorContextProvider),
      ).voidInvoice(invoice.id, reason: reason, at: ref.read(clockProvider)());
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(BillingStrings.invoiceVoided)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  /// Queues the INVOICE_LINK / RECEIPT_LINK message in the log and opens the
  /// WhatsApp deep link. The body carries only the number, amount and link.
  Future<void> _sendLink(
    Patient patient,
    Invoice invoice,
    List<Payment> payments,
  ) async {
    final clinic = ref.read(currentClinicProvider).value;
    if (clinic == null) return;
    final now = ref.read(clockProvider)();
    final request = documentLinkRequest(
      clinic: clinic,
      patient: patient,
      invoice: invoice,
      lastPayment: payments.where((p) => !p.isRefund).lastOrNull,
      now: now,
    );
    try {
      final text = request.render();
      final uri = whatsappDeepLink(request.e164Phone, text);
      await ref.read(messagingProvider).send(request);
      final ok = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      ).catchError((_) => false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok ? BillingStrings.linkQueued : BillingStrings.couldNotOpenApp,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.invoice, required this.patient});

  final Invoice invoice;
  final Patient patient;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    return SectionCard(
      title: BillingStrings.documentTypeLabel(invoice.documentType),
      subtitle: patient.displayName,
      trailing: StatusBadge(
        key: const ValueKey('invoice-status'),
        label: BillingStrings.invoiceStatusLabel(invoice.status),
        tone: invoiceStatusTone(invoice.status),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LabeledValue(
            label: 'Issued on',
            value: AppFormat.dateTime(invoice.issuedAt),
            dense: true,
          ),
          LabeledValue(
            label: s.balance,
            value: '',
            valueWidget: MoneyText(
              key: const ValueKey('invoice-balance'),
              AppFormat.money(invoice.balance),
              emphasis: MoneyEmphasis.hero,
              color: invoice.balance > const Money.zero()
                  ? AppColors.of(context).danger
                  : AppColors.of(context).success,
            ),
          ),
          if (invoice.isDraftNumber)
            Text(
              'Draft number: the final number is assigned on first sync.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}
