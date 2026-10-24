import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'billing_strings.dart';
import 'payment_form_model.dart';

/// Bottom sheet that records a payment: amount (defaults to the balance),
/// method, reference, last-4 and network for cards (never a PAN), and for UPI
/// the clinic's VPA with an `upi://pay` button. Partial payments are allowed;
/// overpaying an invoice is not.
class RecordPaymentSheet extends ConsumerStatefulWidget {
  /// Creates the sheet.
  const RecordPaymentSheet({
    super.key,
    required this.patient,
    this.invoice,
    required this.defaultAmount,
  });

  /// Paying patient.
  final Patient patient;

  /// Invoice settled, null for an on-account payment.
  final Invoice? invoice;

  /// Pre-filled amount.
  final Money defaultAmount;

  /// Shows the sheet; resolves to the saved payment or null when dismissed.
  static Future<Payment?> show(
    BuildContext context, {
    required Patient patient,
    Invoice? invoice,
    required Money defaultAmount,
  }) => showModalBottomSheet<Payment>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => RecordPaymentSheet(
      patient: patient,
      invoice: invoice,
      defaultAmount: defaultAmount,
    ),
  );

  @override
  ConsumerState<RecordPaymentSheet> createState() => _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends ConsumerState<RecordPaymentSheet> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _amount = TextEditingController(
    text: widget.defaultAmount.isZero
        ? ''
        : widget.defaultAmount.format(symbol: false),
  );
  final _reference = TextEditingController();
  final _last4 = TextEditingController();
  PaymentMethod _method = PaymentMethod.cash;
  String? _brand;
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _last4.dispose();
    super.dispose();
  }

  Money? get _max => widget.invoice?.balance;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final clinic = ref.watch(currentClinicProvider).value;
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
                BillingStrings.recordPayment,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (widget.invoice != null)
                Text(
                  '${widget.invoice!.number} - ${s.due} '
                  '${AppFormat.money(widget.invoice!.balance)}',
                ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                key: const ValueKey('pay-amount'),
                controller: _amount,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: s.amount,
                  prefixText: '₹ ',
                ),
                validator: (v) => PaymentValidators.amount(v, max: _max),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(BillingStrings.method),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final m in selectablePaymentMethods)
                    ChoiceChip(
                      key: ValueKey('pay-method-${m.name}'),
                      label: Text(BillingStrings.paymentMethodLabel(m)),
                      selected: _method == m,
                      onSelected: (_) => setState(() => _method = m),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (_method == PaymentMethod.upi)
                _UpiBlock(
                  clinic: clinic,
                  amount: PaymentValidators.parseAmount(_amount.text),
                  note: widget.invoice?.number,
                ),
              if (_method == PaymentMethod.card) ...[
                TextFormField(
                  key: const ValueKey('pay-card-last4'),
                  controller: _last4,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: BillingStrings.cardLast4,
                    helperText: BillingStrings.cardLast4Hint,
                  ),
                  validator: PaymentValidators.cardLast4,
                ),
                DropdownButtonFormField<String>(
                  key: const ValueKey('pay-card-brand'),
                  initialValue: _brand,
                  decoration: InputDecoration(
                    labelText: BillingStrings.cardBrand,
                  ),
                  items: [
                    for (final b in cardBrands)
                      DropdownMenuItem(value: b, child: Text(b)),
                  ],
                  onChanged: (v) => setState(() => _brand = v),
                  validator: PaymentValidators.cardBrand,
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              if (_method != PaymentMethod.cash)
                TextFormField(
                  key: const ValueKey('pay-reference'),
                  controller: _reference,
                  decoration: InputDecoration(
                    labelText: BillingStrings.reference,
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              BigActionButton(
                key: const ValueKey('pay-save'),
                label: s.save,
                icon: Icons.check,
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
      final payment =
          await PaymentRecorder(
            billing: ref.read(billingRepositoryProvider),
            ctx: ref.read(actorContextProvider),
          ).recordPayment(
            patientId: widget.patient.id,
            invoiceId: widget.invoice?.id,
            amount: PaymentValidators.parseAmount(_amount.text)!,
            method: _method,
            reference: _reference.text,
            cardLast4: _last4.text,
            cardBrand: _brand,
            now: ref.read(clockProvider)(),
          );
      if (!mounted) return;
      Navigator.of(context).pop(payment);
    } catch (e, st) {
      const Logger('billing').error('Payment failed', error: e, stackTrace: st);
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}

class _UpiBlock extends StatelessWidget {
  const _UpiBlock({required this.clinic, required this.amount, this.note});

  final Clinic? clinic;
  final Money? amount;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final vpa = clinic?.upiVpa;
    if (vpa == null || vpa.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Text(
          BillingStrings.upiNotConfigured,
          style: TextStyle(color: AppColors.of(context).warning),
        ),
      );
    }
    final uri = amount == null || amount! <= const Money.zero()
        ? null
        : upiPaymentUri(
            vpa: vpa,
            payeeName: clinic!.name,
            amount: amount!,
            note: note,
          );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LabeledValue(
            key: const ValueKey('pay-upi-vpa'),
            label: BillingStrings.payTo,
            value: vpa,
            trailing: IconButton(
              tooltip: context.strings.ok,
              icon: const Icon(Icons.copy_outlined),
              onPressed: () => Clipboard.setData(ClipboardData(text: vpa)),
            ),
          ),
          OutlinedButton.icon(
            key: const ValueKey('pay-upi-open'),
            onPressed: uri == null
                ? null
                : () async {
                    final ok = await launchUrl(
                      uri,
                      mode: LaunchMode.externalApplication,
                    ).catchError((_) => false);
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(BillingStrings.couldNotOpenApp)),
                      );
                    }
                  },
            icon: const Icon(Icons.qr_code_2_outlined),
            label: Text(BillingStrings.openUpiApp),
          ),
        ],
      ),
    );
  }
}
