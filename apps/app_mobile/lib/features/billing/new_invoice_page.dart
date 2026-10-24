import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'billing_actions.dart';
import 'billing_providers.dart';
import 'billing_strings.dart';
import 'invoice_draft.dart';
import 'invoice_line_editor.dart';

/// New invoice from the patient's completed-but-unbilled procedures. Totals
/// use the clinic's GST rate table and `computeInvoiceTotals`; the document
/// type follows `suggestDocumentType`. Issue saves the draft (minting the
/// `DRAFT-` number), issues it and opens the detail page with the PDF.
class NewInvoicePage extends ConsumerStatefulWidget {
  /// Creates the page.
  const NewInvoicePage({
    super.key,
    required this.patientId,
    this.preselectedProcedureIds = const {},
  });

  /// The patient.
  final String patientId;

  /// Procedure ids from the `procedureIds` query parameter.
  final Set<String> preselectedProcedureIds;

  @override
  ConsumerState<NewInvoicePage> createState() => _NewInvoicePageState();
}

class _NewInvoicePageState extends ConsumerState<NewInvoicePage> {
  List<InvoiceDraftLine>? _lines;
  final TextEditingController _notes = TextEditingController();
  bool _issuing = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final procedures = ref.watch(billableProceduresProvider(widget.patientId));
    final catalog = ref.watch(catalogByIdProvider);
    final rates = ref.watch(gstRateTableProvider);
    final clinic = ref.watch(currentClinicProvider);
    final notation = ref.watch(notationProvider);
    final now = ref.watch(clockProvider)();

    if (procedures.hasError) {
      return Scaffold(
        appBar: AppBar(title: Text(BillingStrings.newInvoice)),
        body: ErrorView(message: procedures.error.toString()),
      );
    }
    final ready =
        procedures.hasValue &&
        catalog.hasValue &&
        rates.hasValue &&
        clinic.hasValue;
    if (!ready) return LoadingScaffold(message: s.loading);

    final lines = _lines ??= draftLinesFromProcedures(
      procedures.requireValue,
      catalog: catalog.requireValue,
      notation: notation,
      preselectedIds: widget.preselectedProcedureIds,
    );
    final rateTable = rates.requireValue;
    final gstRegistered = clinic.requireValue.isGstRegistered;
    final preview = buildDraftInvoice(
      id: 'preview',
      clinicId: clinic.requireValue.id,
      patientId: widget.patientId,
      issuedBy: '',
      lines: lines,
      rates: rateTable,
      clinicGstRegistered: gstRegistered,
      now: now,
    );
    final anySelected = lines.any((l) => l.selected);
    final anyInvalid = lines.any((l) => l.selected && l.discountTooLarge);

    return Scaffold(
      appBar: AppBar(title: Text(BillingStrings.newInvoice)),
      body: lines.isEmpty
          ? EmptyState(
              icon: Icons.receipt_long_outlined,
              title: BillingStrings.noBillableProcedures,
              message: BillingStrings.noBillableProceduresHint,
            )
          : ListView(
              padding: AppSpacing.screenPadding,
              children: [
                Text(
                  BillingStrings.linesTitle,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final (i, line) in lines.indexed)
                  InvoiceLineEditor(
                    key: ValueKey(
                      'inv-line-${line.procedure?.id ?? line.line.id}',
                    ),
                    draft: line,
                    notation: notation,
                    keyBase: 'inv-line-${line.procedure?.id ?? line.line.id}',
                    onChanged: (updated) => setState(() {
                      _lines = [...lines]..[i] = updated;
                    }),
                  ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  key: const ValueKey('invoice-notes'),
                  controller: _notes,
                  decoration: InputDecoration(labelText: s.notes),
                  maxLines: 2,
                ),
                const SizedBox(height: AppSpacing.md),
                InvoiceTotalsCard(invoice: preview),
              ],
            ),
      bottomNavigationBar: lines.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: AppSpacing.screenPadding,
                child: BigActionButton(
                  key: const ValueKey('invoice-issue'),
                  label: BillingStrings.issue,
                  icon: Icons.check_circle_outline,
                  loading: _issuing,
                  onPressed: anySelected && !anyInvalid && !_issuing
                      ? () => _issue(lines, rateTable, gstRegistered)
                      : null,
                ),
              ),
            ),
    );
  }

  Future<void> _issue(
    List<InvoiceDraftLine> lines,
    GstRateTable rates,
    bool gstRegistered,
  ) async {
    setState(() => _issuing = true);
    final ctx = ref.read(actorContextProvider);
    final now = ref.read(clockProvider)();
    final draft = buildDraftInvoice(
      id: newId(),
      clinicId: ctx.clinicId,
      patientId: widget.patientId,
      issuedBy: ctx.actorId,
      lines: lines,
      rates: rates,
      clinicGstRegistered: gstRegistered,
      now: now,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );
    try {
      final issued = await InvoiceIssuer(
        billing: ref.read(billingRepositoryProvider),
        ctx: ctx,
      ).issue(draft, rates: rates, at: now);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${BillingStrings.invoiceIssued} ${issued.number}'),
        ),
      );
      context.pushReplacement(
        '/patients/${widget.patientId}/billing/invoice/${issued.id}?pdf=1',
      );
    } catch (e, st) {
      const Logger('billing').error('Issue failed', error: e, stackTrace: st);
      if (!mounted) return;
      setState(() => _issuing = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}

/// Totals block shared by the editor and the detail page.
class InvoiceTotalsCard extends StatelessWidget {
  /// Creates the card for an invoice whose totals are computed.
  const InvoiceTotalsCard({super.key, required this.invoice});

  /// The invoice.
  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    return SectionCard(
      title: BillingStrings.totalsTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LabeledValue(
            label: BillingStrings.subtotal,
            value: AppFormat.money(invoice.subtotal),
            dense: true,
          ),
          LabeledValue(
            label: s.discount,
            value: '-${AppFormat.money(invoice.discountTotal)}',
            dense: true,
          ),
          LabeledValue(
            label: BillingStrings.taxable,
            value: AppFormat.money(invoice.taxableTotal),
            dense: true,
          ),
          LabeledValue(
            key: const ValueKey('invoice-tax-total'),
            label: s.gst,
            value: AppFormat.money(invoice.taxTotal),
            dense: true,
          ),
          const Divider(),
          LabeledValue(
            label: BillingStrings.grandTotal,
            value: '',
            valueWidget: MoneyText(
              key: const ValueKey('invoice-grand-total'),
              AppFormat.money(invoice.grandTotal),
              emphasis: MoneyEmphasis.strong,
            ),
          ),
          LabeledValue(
            key: const ValueKey('invoice-document-type'),
            label: BillingStrings.documentType,
            value: BillingStrings.documentTypeLabel(invoice.documentType),
            dense: true,
          ),
        ],
      ),
    );
  }
}
