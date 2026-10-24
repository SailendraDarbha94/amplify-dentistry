import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'billing_strings.dart';
import 'payment_form_model.dart';

/// Bottom sheet that refunds part or all of what was paid on an invoice (or
/// on account). A reason is mandatory; the refund is written as a reverse
/// payment so the invoice status and ledger move back together.
class RefundSheet extends ConsumerStatefulWidget {
  /// Creates the sheet.
  const RefundSheet({
    super.key,
    required this.patient,
    this.invoice,
    required this.maxAmount,
  });

  /// Patient refunded.
  final Patient patient;

  /// Invoice the refund applies to, null for on-account credit.
  final Invoice? invoice;

  /// Most that can be refunded (amount paid).
  final Money maxAmount;

  /// Shows the sheet; resolves to the saved refund or null when dismissed.
  static Future<Payment?> show(
    BuildContext context, {
    required Patient patient,
    Invoice? invoice,
    required Money maxAmount,
  }) => showModalBottomSheet<Payment>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) =>
        RefundSheet(patient: patient, invoice: invoice, maxAmount: maxAmount),
  );

  @override
  ConsumerState<RefundSheet> createState() => _RefundSheetState();
}

class _RefundSheetState extends ConsumerState<RefundSheet> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _amount = TextEditingController(
    text: widget.maxAmount.format(symbol: false),
  );
  final _reason = TextEditingController();
  final _reference = TextEditingController();
  PaymentMethod _method = PaymentMethod.cash;
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    _reference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final viewInsets = MediaQuery.viewInsetsOf(context);
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                BillingStrings.refund,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text('${s.paid} ${AppFormat.money(widget.maxAmount)}'),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                key: const ValueKey('refund-amount'),
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: s.amount,
                  prefixText: '₹ ',
                ),
                validator: (v) => PaymentValidators.amount(
                  v,
                  max: widget.maxAmount,
                  maxMessage: BillingStrings.amountExceedsPaid,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final m in selectablePaymentMethods)
                    ChoiceChip(
                      key: ValueKey('refund-method-${m.name}'),
                      label: Text(BillingStrings.paymentMethodLabel(m)),
                      selected: _method == m,
                      onSelected: (_) => setState(() => _method = m),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                key: const ValueKey('refund-reason'),
                controller: _reason,
                decoration: InputDecoration(
                  labelText: BillingStrings.refundReason,
                ),
                validator: PaymentValidators.reason,
                maxLines: 2,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                key: const ValueKey('refund-reference'),
                controller: _reference,
                decoration: InputDecoration(
                  labelText: BillingStrings.reference,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              BigActionButton(
                key: const ValueKey('refund-save'),
                label: BillingStrings.refund,
                icon: Icons.undo_outlined,
                loading: _saving,
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final refund =
          await PaymentRecorder(
            billing: ref.read(billingRepositoryProvider),
            ctx: ref.read(actorContextProvider),
          ).recordRefund(
            patientId: widget.patient.id,
            invoiceId: widget.invoice?.id,
            amount: PaymentValidators.parseAmount(_amount.text)!,
            method: _method,
            reason: _reason.text,
            reference: _reference.text,
            now: ref.read(clockProvider)(),
          );
      if (!mounted) return;
      Navigator.of(context).pop(refund);
    } catch (e, st) {
      const Logger('billing').error('Refund failed', error: e, stackTrace: st);
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}

/// Bottom sheet asking for the mandatory void reason. Resolves to the
/// trimmed reason, or null when cancelled.
class VoidReasonSheet extends StatefulWidget {
  /// Creates the sheet.
  const VoidReasonSheet({super.key, required this.invoiceNumber});

  /// Invoice being voided.
  final String invoiceNumber;

  /// Shows the sheet.
  static Future<String?> show(
    BuildContext context, {
    required String invoiceNumber,
  }) => showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => VoidReasonSheet(invoiceNumber: invoiceNumber),
  );

  @override
  State<VoidReasonSheet> createState() => _VoidReasonSheetState();
}

class _VoidReasonSheetState extends State<VoidReasonSheet> {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${BillingStrings.voidInvoice} ${widget.invoiceNumber}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(BillingStrings.voidWarning),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                key: const ValueKey('void-reason'),
                controller: _reason,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: BillingStrings.voidReason,
                ),
                validator: PaymentValidators.reason,
                maxLines: 2,
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                key: const ValueKey('void-confirm'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.of(context).danger,
                ),
                onPressed: () {
                  if (_form.currentState?.validate() ?? false) {
                    Navigator.of(context).pop(_reason.text.trim());
                  }
                },
                icon: const Icon(Icons.block_outlined),
                label: Text(BillingStrings.voidInvoice),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
