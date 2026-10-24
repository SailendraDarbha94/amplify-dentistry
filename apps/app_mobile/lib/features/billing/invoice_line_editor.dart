import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';

import 'billing_strings.dart';
import 'invoice_draft.dart';

/// One line of a new invoice: include toggle, description, tooth in clinic
/// notation, fee, editable discount, GST class chip (with a warning when it
/// differs from the catalogue) and SAC/HSN.
class InvoiceLineEditor extends StatelessWidget {
  /// Creates the editor.
  const InvoiceLineEditor({
    super.key,
    required this.draft,
    required this.notation,
    required this.onChanged,
    required this.keyBase,
  });

  /// The line being edited.
  final InvoiceDraftLine draft;

  /// Tooth notation for display.
  final ToothNotation notation;

  /// Called with the replaced line.
  final ValueChanged<InvoiceDraftLine> onChanged;

  /// Prefix for the test keys (`<keyBase>-select`, `-discount`, `-gst`).
  final String keyBase;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final theme = Theme.of(context);
    final line = draft.line;
    final colors = AppColors.of(context);
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CheckboxListTile(
            key: ValueKey('$keyBase-select'),
            value: draft.selected,
            onChanged: (v) => onChanged(draft.copyWith(selected: v ?? false)),
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(line.description),
            subtitle: Text(
              [
                if (line.tooth != null)
                  '${s.tooth} ${notation.format(line.tooth!)}',
                '${BillingStrings.sacHsn} ${line.sacHsnCode}',
              ].join(' - '),
            ),
            secondary: MoneyText(
              AppFormat.money(line.unitPrice, showPaise: false),
              emphasis: MoneyEmphasis.strong,
            ),
          ),
          if (draft.selected)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          key: ValueKey('$keyBase-discount'),
                          initialValue: line.discount.isZero
                              ? ''
                              : line.discount.format(symbol: false),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: s.discount,
                            prefixText: '₹ ',
                            isDense: true,
                            errorText: draft.discountTooLarge
                                ? BillingStrings.discountTooLarge
                                : null,
                          ),
                          onChanged: (v) {
                            final parsed = v.trim().isEmpty
                                ? const Money.zero()
                                : Money.tryParse(v);
                            if (parsed == null || parsed.isNegative) return;
                            onChanged(
                              draft.copyWith(
                                line: line.copyWith(discount: parsed),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      _GstClassChip(
                        key: ValueKey('$keyBase-gst'),
                        value: line.gstClass,
                        overridden: draft.gstClassOverridden,
                        onChanged: (c) => onChanged(
                          draft.copyWith(
                            line: line.copyWith(
                              gstClass: c,
                              sacHsnCode: c == draft.catalogGstClass
                                  ? (draft.procedure == null
                                        ? c.defaultCode
                                        : line.sacHsnCode)
                                  : c.defaultCode,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (draft.gstClassOverridden)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_outlined,
                            size: 16,
                            color: colors.warning,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              key: ValueKey('$keyBase-gst-warning'),
                              '${BillingStrings.gstClassOverridden} '
                              '(${BillingStrings.gstClassLabel(draft.catalogGstClass!)})',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.warning,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _GstClassChip extends StatelessWidget {
  const _GstClassChip({
    super.key,
    required this.value,
    required this.overridden,
    required this.onChanged,
  });

  final GstClass value;
  final bool overridden;
  final ValueChanged<GstClass> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SizedBox(
      height: AppSpacing.minTapTarget,
      child: ActionChip(
        avatar: Icon(
          overridden ? Icons.warning_amber_outlined : Icons.percent,
          size: 18,
          color: overridden ? colors.warning : null,
        ),
        label: Text(
          '${context.strings.gst}: ${BillingStrings.gstClassLabel(value)}',
        ),
        onPressed: () async {
          final picked = await showModalBottomSheet<GstClass>(
            context: context,
            showDragHandle: true,
            builder: (context) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final c in GstClass.values)
                    ListTile(
                      key: ValueKey('gst-option-${c.name}'),
                      minTileHeight: AppSpacing.minTapTarget,
                      leading: Icon(
                        c == value
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                      ),
                      selected: c == value,
                      title: Text(BillingStrings.gstClassLabel(c)),
                      subtitle: Text('${c.description} - ${c.defaultCode}'),
                      onTap: () => Navigator.of(context).pop(c),
                    ),
                ],
              ),
            ),
          );
          if (picked != null) onChanged(picked);
        },
      ),
    );
  }
}
