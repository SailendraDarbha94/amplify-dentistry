import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';

import 'rx_model.dart';

/// Bottom sheet editing one line: dose, frequency, duration, auto quantity,
/// route and instructions. Returns the edited line or null.
class RxLineSheet extends StatefulWidget {
  /// Creates the sheet.
  const RxLineSheet({super.key, required this.initial});

  /// Line to edit.
  final RxLineDraft initial;

  /// Shows the sheet.
  static Future<RxLineDraft?> show(
    BuildContext context, {
    required RxLineDraft initial,
  }) => showModalBottomSheet<RxLineDraft>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => RxLineSheet(initial: initial),
  );

  @override
  State<RxLineSheet> createState() => _RxLineSheetState();
}

class _RxLineSheetState extends State<RxLineSheet> {
  late RxLineDraft _line = widget.initial;
  late final TextEditingController _dose = TextEditingController(
    text: _line.dose,
  );
  late final TextEditingController _frequency = TextEditingController(
    text: _line.frequency,
  );
  late final TextEditingController _quantity = TextEditingController(
    text: '${_line.effectiveQuantity}',
  );
  late final TextEditingController _instructions = TextEditingController(
    text: _line.instructions,
  );
  late final TextEditingController _brand = TextEditingController(
    text: _line.brandName ?? '',
  );
  late final TextEditingController _route = TextEditingController(
    text: _line.route,
  );

  @override
  void dispose() {
    _dose.dispose();
    _frequency.dispose();
    _quantity.dispose();
    _instructions.dispose();
    _brand.dispose();
    _route.dispose();
    super.dispose();
  }

  void _set(RxLineDraft next) {
    setState(() => _line = next);
    if (next.quantity == null) {
      _quantity.text = '${next.effectiveQuantity}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final theme = Theme.of(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.lg,
        AppSpacing.gutter,
        AppSpacing.lg + bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${_line.genericUpper} ${_line.strength}',
              style: theme.textTheme.titleLarge,
            ),
            Text(
              '${drugFormLabel(_line.form)} · ${scheduleLabel(_line.schedule)}',
              style: theme.textTheme.bodySmall,
            ),
            const FormGap(),
            TextField(
              key: const ValueKey('rx-brand'),
              controller: _brand,
              decoration: InputDecoration(labelText: 'Brand (${s.optional})'),
              onChanged: (v) => _set(_line.copyWith(brandName: v)),
            ),
            const FormGap(),
            TextField(
              key: const ValueKey('rx-dose'),
              controller: _dose,
              decoration: const InputDecoration(labelText: 'Dose'),
              onChanged: (v) => _set(_line.copyWith(dose: v)),
            ),
            const FormGap(),
            Text('Frequency', style: theme.textTheme.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                for (final f in frequencyPresets)
                  ChoiceChip(
                    key: ValueKey('rx-freq-$f'),
                    label: Text(f),
                    selected: _line.frequency == f,
                    onSelected: (_) {
                      _frequency.text = f;
                      _set(_line.copyWith(frequency: f));
                    },
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const ValueKey('rx-frequency'),
              controller: _frequency,
              decoration: InputDecoration(
                labelText: 'Frequency',
                helperText: frequencyDescription(_line.frequency),
              ),
              onChanged: (v) => _set(_line.copyWith(frequency: v)),
            ),
            const FormGap(),
            Row(
              children: [
                Expanded(
                  child: Text('Duration', style: theme.textTheme.labelLarge),
                ),
                IconButton.filledTonal(
                  key: const ValueKey('rx-duration-minus'),
                  icon: const Icon(Icons.remove),
                  onPressed: _line.durationDays > 1
                      ? () => _set(
                          _line.copyWith(durationDays: _line.durationDays - 1),
                        )
                      : null,
                ),
                SizedBox(
                  width: 72,
                  child: Text(
                    '${_line.durationDays} d',
                    key: const ValueKey('rx-duration'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton.filledTonal(
                  key: const ValueKey('rx-duration-plus'),
                  icon: const Icon(Icons.add),
                  onPressed: () => _set(
                    _line.copyWith(durationDays: _line.durationDays + 1),
                  ),
                ),
              ],
            ),
            const FormGap(),
            TextField(
              key: const ValueKey('rx-quantity'),
              controller: _quantity,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Quantity',
                helperText: _line.quantity == null
                    ? 'Auto: dose x frequency x days'
                    : 'Set by hand',
                suffixIcon: _line.quantity == null
                    ? null
                    : IconButton(
                        tooltip: 'Recompute',
                        icon: const Icon(Icons.refresh),
                        onPressed: () =>
                            _set(_line.copyWith(clearQuantity: true)),
                      ),
              ),
              onChanged: (v) {
                final n = int.tryParse(v.trim());
                if (n != null && n > 0) {
                  setState(() => _line = _line.copyWith(quantity: n));
                }
              },
            ),
            const FormGap(),
            TextField(
              key: const ValueKey('rx-route'),
              controller: _route,
              decoration: const InputDecoration(labelText: 'Route'),
              onChanged: (v) => _set(_line.copyWith(route: v)),
            ),
            const FormGap(),
            TextField(
              key: const ValueKey('rx-instructions'),
              controller: _instructions,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Instructions (${s.optional})',
                hintText: 'After food, avoid alcohol...',
              ),
              onChanged: (v) => _set(_line.copyWith(instructions: v)),
            ),
            const SizedBox(height: AppSpacing.lg),
            BigActionButton(
              key: const ValueKey('rx-line-save'),
              label: s.done,
              onPressed:
                  _line.dose.trim().isEmpty || _line.frequency.trim().isEmpty
                  ? null
                  : () => Navigator.of(context).pop(_line),
            ),
          ],
        ),
      ),
    );
  }
}
