import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_data/ampdent_data.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Live GST rate history of the current clinic.
final StreamProvider<List<GstRate>> gstRatesProvider =
    StreamProvider<List<GstRate>>((ref) {
      final clinicId = ref.watch(currentClinicIdProvider);
      if (clinicId == null) return Stream.value(const []);
      return ref
          .watch(clinicRepositoryProvider)
          .watchSetting(clinicId, SettingKeys.gstRates)
          .map(
            (json) => json == null ? const <GstRate>[] : gstRatesFromJson(json),
          );
    });

/// The rate in force for [gstClass] at [asOf] (latest effectiveFrom <= asOf).
GstRate? currentGstRate(
  Iterable<GstRate> rates,
  GstClass gstClass,
  DateTime asOf,
) {
  GstRate? best;
  for (final r in rates) {
    if (r.gstClass != gstClass || r.effectiveFrom.isAfter(asOf)) continue;
    if (best == null || r.effectiveFrom.isAfter(best.effectiveFrom)) best = r;
  }
  return best;
}

/// Returns [rates] plus [rate], sorted by class then effective date.
List<GstRate> withGstRate(Iterable<GstRate> rates, GstRate rate) {
  final out = [...rates, rate]
    ..sort((a, b) {
      final c = a.gstClass.index.compareTo(b.gstClass.index);
      return c != 0 ? c : a.effectiveFrom.compareTo(b.effectiveFrom);
    });
  return out;
}

/// Cosmetic dentistry options: 18% with input tax credit, or the 5% without
/// ITC reading effective 22 Sep 2025 (clinic's call; see
/// docs/research/04-compliance-pricing-gtm.md).
enum CosmeticGstOption {
  /// 18% with ITC.
  standard18(18, true),

  /// 5% without ITC.
  concessional5(5, false);

  const CosmeticGstOption(this.percent, this.itc);

  /// Rate percent.
  final int percent;

  /// Whether ITC is allowed.
  final bool itc;

  /// Picks the option matching a rate, null when neither.
  static CosmeticGstOption? from(GstRate? rate) {
    if (rate == null) return null;
    for (final o in values) {
      if (o.percent == rate.ratePercent &&
          o.itc == rate.inputTaxCreditAllowed) {
        return o;
      }
    }
    return null;
  }
}

/// GST rate table with history and the cosmetic 18/5 toggle.
class GstRatesPage extends ConsumerWidget {
  /// Creates the page.
  const GstRatesPage({super.key});

  Future<void> _append(WidgetRef ref, GstRate rate) async {
    final rates = ref.read(gstRatesProvider).value ?? const <GstRate>[];
    await ref
        .read(clinicRepositoryProvider)
        .saveGstRates(ref.read(actorContextProvider), withGstRate(rates, rate));
  }

  Future<void> _setCosmetic(WidgetRef ref, CosmeticGstOption option) async {
    final now = ref.read(clockProvider)().toUtc();
    final today = DateTime.utc(now.year, now.month, now.day);
    await _append(
      ref,
      GstRate(
        gstClass: GstClass.cosmeticTaxable,
        ratePercent: option.percent,
        inputTaxCreditAllowed: option.itc,
        effectiveFrom: today,
      ),
    );
  }

  Future<void> _addRate(
    BuildContext context,
    WidgetRef ref,
    GstClass gstClass,
  ) async {
    final rate = await showDialog<GstRate>(
      context: context,
      builder: (_) =>
          _AddRateDialog(gstClass: gstClass, now: ref.read(clockProvider)()),
    );
    if (rate != null) await _append(ref, rate);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings;
    final rates = ref.watch(gstRatesProvider);
    final clinic = ref.watch(currentClinicProvider).value;
    final now = ref.watch(clockProvider)();
    return Scaffold(
      appBar: AppBar(title: Text('${s.gst} rates')),
      body: rates.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(message: e.toString()),
        data: (list) => ListView(
          padding: AppSpacing.screenPadding,
          children: [
            if (clinic != null && !clinic.isGstRegistered)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Not GST registered'),
                  subtitle: const Text(
                    'Invoices print as receipts without tax. Add a GSTIN in '
                    'Clinic profile once registered; rates below apply then.',
                  ),
                ),
              ),
            for (final cls in GstClass.values) ...[
              const SizedBox(height: AppSpacing.md),
              _RateCard(
                gstClass: cls,
                rates: list.where((r) => r.gstClass == cls).toList(),
                current: currentGstRate(list, cls, now),
                onAdd: () => _addRate(context, ref, cls),
                onCosmetic: cls == GstClass.cosmeticTaxable
                    ? (o) => _setCosmetic(ref, o)
                    : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RateCard extends StatelessWidget {
  const _RateCard({
    required this.gstClass,
    required this.rates,
    required this.current,
    required this.onAdd,
    this.onCosmetic,
  });

  final GstClass gstClass;
  final List<GstRate> rates;
  final GstRate? current;
  final VoidCallback onAdd;
  final ValueChanged<CosmeticGstOption>? onCosmetic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sorted = rates.toList()
      ..sort((a, b) => b.effectiveFrom.compareTo(a.effectiveFrom));
    return SectionCard(
      title: gstClass.description,
      subtitle: 'SAC/HSN ${gstClass.defaultCode}',
      trailing: StatusBadge(
        key: ValueKey('gst-current-${gstClass.name}'),
        label: current == null ? '-' : AppFormat.percent(current!.ratePercent),
        tone: current == null || current!.ratePercent == 0
            ? BadgeTone.neutral
            : BadgeTone.info,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (onCosmetic != null) ...[
            SegmentedButton<CosmeticGstOption>(
              key: const ValueKey('gst-cosmetic-toggle'),
              segments: const [
                ButtonSegment(
                  value: CosmeticGstOption.standard18,
                  label: Text('18% with ITC'),
                ),
                ButtonSegment(
                  value: CosmeticGstOption.concessional5,
                  label: Text('5% no ITC'),
                ),
              ],
              selected: {
                if (CosmeticGstOption.from(current) != null)
                  CosmeticGstOption.from(current)!,
              },
              emptySelectionAllowed: true,
              onSelectionChanged: (set) {
                if (set.isNotEmpty) onCosmetic!(set.first);
              },
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          Text('History', style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          if (sorted.isEmpty)
            Text('No rate recorded', style: theme.textTheme.bodySmall),
          for (final r in sorted)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'From ${AppFormat.date(r.effectiveFrom)}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    '${AppFormat.percent(r.ratePercent)}'
                    '${r.inputTaxCreditAllowed ? '  ·  ITC' : '  ·  no ITC'}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            key: ValueKey('gst-add-${gstClass.name}'),
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add rate from a date'),
          ),
        ],
      ),
    );
  }
}

class _AddRateDialog extends StatefulWidget {
  const _AddRateDialog({required this.gstClass, required this.now});

  final GstClass gstClass;
  final DateTime now;

  @override
  State<_AddRateDialog> createState() => _AddRateDialogState();
}

class _AddRateDialogState extends State<_AddRateDialog> {
  final TextEditingController _percent = TextEditingController();
  bool _itc = true;
  late DateTime _from = DateTime(
    widget.now.year,
    widget.now.month,
    widget.now.day,
  );
  String? _error;

  @override
  void dispose() {
    _percent.dispose();
    super.dispose();
  }

  void _submit() {
    final n = num.tryParse(_percent.text.trim());
    if (n == null || n < 0 || n > 28) {
      setState(() => _error = 'Enter a rate between 0 and 28');
      return;
    }
    Navigator.of(context).pop(
      GstRate(
        gstClass: widget.gstClass,
        ratePercent: n,
        inputTaxCreditAllowed: _itc,
        effectiveFrom: DateTime.utc(_from.year, _from.month, _from.day),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    return AlertDialog(
      title: Text(widget.gstClass.description),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const ValueKey('gst-rate-percent'),
            controller: _percent,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Rate (%)',
              errorText: _error,
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Input tax credit allowed'),
            value: _itc,
            onChanged: (v) => setState(() => _itc = v),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Effective from'),
            subtitle: Text(AppFormat.date(_from)),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _from,
                firstDate: DateTime(2017, 7, 1),
                lastDate: DateTime(widget.now.year + 1),
              );
              if (picked != null) setState(() => _from = picked);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.cancel),
        ),
        FilledButton(
          key: const ValueKey('gst-rate-save'),
          onPressed: _submit,
          child: Text(s.save),
        ),
      ],
    );
  }
}
