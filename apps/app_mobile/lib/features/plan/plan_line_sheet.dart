import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';

import 'plan_model.dart';

/// Edits a line's fee, discount, quantity, phase, alternative status and
/// note. Fees outside the catalogue range are allowed with a warning.
/// Returns the updated line, or null when dismissed.
class PlanLineSheet extends StatefulWidget {
  /// Creates the sheet.
  const PlanLineSheet({
    super.key,
    required this.line,
    required this.phases,
    required this.alternativeGroups,
    this.catalogItem,
  });

  /// Line being edited.
  final TreatmentPlanLine line;

  /// Phases to choose from.
  final List<PlanPhase> phases;

  /// Existing alternative group names (suggestions).
  final List<String> alternativeGroups;

  /// Catalogue item for the range check.
  final CatalogItem? catalogItem;

  /// Shows the sheet.
  static Future<TreatmentPlanLine?> show(
    BuildContext context, {
    required TreatmentPlanLine line,
    required List<PlanPhase> phases,
    required List<String> alternativeGroups,
    CatalogItem? catalogItem,
  }) => showModalBottomSheet<TreatmentPlanLine>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => PlanLineSheet(
      line: line,
      phases: phases,
      alternativeGroups: alternativeGroups,
      catalogItem: catalogItem,
    ),
  );

  @override
  State<PlanLineSheet> createState() => _PlanLineSheetState();
}

class _PlanLineSheetState extends State<PlanLineSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _fee;
  late final TextEditingController _discount;
  late final TextEditingController _quantity;
  late final TextEditingController _group;
  late final TextEditingController _note;
  late int _phase;
  late bool _alternative;

  @override
  void initState() {
    super.initState();
    final l = widget.line;
    _fee = TextEditingController(text: '${l.unitFee.wholeRupees}');
    _discount = TextEditingController(text: '${l.discount.wholeRupees}');
    _quantity = TextEditingController(text: '${l.quantity}');
    _group = TextEditingController(text: l.alternativeGroup ?? 'Plan B');
    _note = TextEditingController(text: l.note ?? '');
    _phase = l.phaseIndex;
    _alternative = l.isAlternative;
  }

  @override
  void dispose() {
    for (final c in [_fee, _discount, _quantity, _group, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Money? get _feeValue => Money.tryParse(_fee.text.trim());

  String? _validateMoney(String? v, {bool allowZero = true}) {
    final m = Money.tryParse((v ?? '').trim());
    if (m == null || m.isNegative || (!allowZero && m.isZero)) {
      return context.strings.invalidValue;
    }
    return null;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final fee = _feeValue!;
    final qty = int.parse(_quantity.text.trim());
    final discount = Money.tryParse(_discount.text.trim())!;
    Navigator.of(context).pop(
      lineWith(
        widget.line,
        phaseIndex: _phase,
        quantity: qty,
        unitFee: fee,
        discount: discount,
        isAlternative: _alternative,
        alternativeGroup: _group.text,
        note: _note.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final item = widget.catalogItem;
    final fee = _feeValue;
    final warning = fee == null ? null : feeRangeWarning(fee, item);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          padding: AppSpacing.screenPadding,
          children: [
            Text(widget.line.laymanName, style: theme.textTheme.titleLarge),
            Text(
              '${widget.line.name}  |  ${widget.line.code}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            FormRow(
              flex: const [3, 1],
              children: [
                TextFormField(
                  key: const ValueKey('line-fee'),
                  controller: _fee,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Fee per unit (₹)',
                    helperText: item == null
                        ? null
                        : 'Catalogue ${AppFormat.money(item.feeMin, showPaise: false)}'
                              ' - ${AppFormat.money(item.feeMax, showPaise: false)}',
                  ),
                  validator: (v) => _validateMoney(v, allowZero: false),
                  onChanged: (_) => setState(() {}),
                ),
                TextFormField(
                  key: const ValueKey('line-quantity'),
                  controller: _quantity,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Qty'),
                  validator: (v) {
                    final n = int.tryParse((v ?? '').trim());
                    return n == null || n < 1 ? s.invalidValue : null;
                  },
                ),
              ],
            ),
            if (warning != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Row(
                  key: const ValueKey('line-fee-warning'),
                  children: [
                    Icon(Icons.warning_amber, color: colors.warning, size: 18),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        warning,
                        style: TextStyle(color: colors.warning),
                      ),
                    ),
                  ],
                ),
              ),
            const FormGap(),
            TextFormField(
              key: const ValueKey('line-discount'),
              controller: _discount,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '${s.discount} (₹, total)',
              ),
              validator: _validateMoney,
            ),
            const FormGap(),
            DropdownButtonFormField<int>(
              key: const ValueKey('line-phase'),
              initialValue: _phase,
              decoration: const InputDecoration(labelText: 'Phase'),
              items: [
                for (final p in widget.phases)
                  DropdownMenuItem(value: p.index, child: Text(p.name)),
              ],
              onChanged: (v) => setState(() => _phase = v ?? _phase),
            ),
            SwitchListTile(
              key: const ValueKey('line-alternative'),
              value: _alternative,
              onChanged: (v) => setState(() => _alternative = v),
              title: const Text('Alternative option'),
              subtitle: const Text('Shown as Plan B; excluded from the total'),
              contentPadding: EdgeInsets.zero,
            ),
            if (_alternative)
              TextFormField(
                key: const ValueKey('line-group'),
                controller: _group,
                decoration: InputDecoration(
                  labelText: 'Alternative group',
                  helperText: widget.alternativeGroups.isEmpty
                      ? null
                      : 'Existing: ${widget.alternativeGroups.join(', ')}',
                ),
              ),
            const FormGap(),
            TextFormField(
              key: const ValueKey('line-note'),
              controller: _note,
              decoration: InputDecoration(labelText: s.notes),
              maxLines: 2,
            ),
            const SizedBox(height: AppSpacing.lg),
            BigActionButton(
              key: const ValueKey('line-save'),
              label: s.done,
              icon: Icons.check,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
