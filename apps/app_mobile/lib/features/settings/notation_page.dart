import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tooth notation shown across the app. FDI is always what is stored; this
/// only changes how numbers are displayed.
class NotationPage extends ConsumerWidget {
  /// Creates the page.
  const NotationPage({super.key});

  /// Example teeth rendered under each option.
  static final List<ToothId> _examples = [
    ToothId.parse('11'),
    ToothId.parse('36'),
    ToothId.parse('75'),
  ];

  Future<void> _select(WidgetRef ref, ToothNotation notation) async {
    final ctx = ref.read(actorContextProvider);
    final repo = ref.read(clinicRepositoryProvider);
    await repo.saveNotation(ctx, notation);
    final clinic = await repo.getClinic(ctx.clinicId);
    if (clinic != null && clinic.defaultNotation != notation) {
      await repo.updateClinic(
        ctx,
        clinic.copyWith(
          defaultNotation: notation,
          updatedAt: DateTime.now().toUtc(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(notationProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Tooth notation')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        children: [
          const Padding(
            padding: AppSpacing.horizontalGutter,
            child: Text(
              'Teeth are always stored as FDI (ISO 3950). Pick how they are '
              'shown on the chart, plans and documents.',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          RadioGroup<ToothNotation>(
            groupValue: current,
            onChanged: (v) {
              if (v != null) _select(ref, v);
            },
            child: Column(
              children: [
                for (final n in ToothNotation.values)
                  RadioListTile<ToothNotation>(
                    key: ValueKey('notation-${n.name}'),
                    value: n,
                    title: Text(n.label),
                    subtitle: Text(_examples.map(n.formatPlain).join('   ')),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
