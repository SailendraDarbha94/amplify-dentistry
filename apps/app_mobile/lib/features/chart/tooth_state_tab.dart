import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'chart_providers.dart';
import 'chart_strings.dart';
import 'tooth_sheet.dart';

/// Picks the lifecycle state of a tooth (present, missing, unerupted,
/// implant, extracted...) and appends it to the history.
/// Test keys: `tooth-state-<state.name>`, `tooth-state-note`,
/// `tooth-state-save`.
class ToothStateTab extends ConsumerStatefulWidget {
  /// Creates the tab.
  const ToothStateTab({
    super.key,
    required this.patientId,
    required this.tooth,
  });

  /// Patient.
  final String patientId;

  /// Tooth.
  final ToothId tooth;

  @override
  ConsumerState<ToothStateTab> createState() => _ToothStateTabState();
}

class _ToothStateTabState extends ConsumerState<ToothStateTab> {
  ToothState? _selected;
  final TextEditingController _note = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save(ToothState state) async {
    setState(() => _saving = true);
    try {
      await ref
          .read(chartServiceProvider)
          .setToothState(
            patientId: widget.patientId,
            tooth: widget.tooth,
            state: state,
            note: _note.text,
          );
      if (!mounted) return;
      Navigator.of(context)
          .pop(ToothSheetResult('${AppFormat.enumLabel(state)} recorded'));
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final states = ref.watch(toothStatesProvider(widget.patientId)).value;
    final current = states?[widget.tooth];
    final selected = _selected ?? current;
    return ListView(
      padding: AppSpacing.screenPadding,
      children: [
        if (current != null)
          LabeledValue(
            label: ChartStrings.currentState,
            value: AppFormat.enumLabel(current),
          ),
        const SizedBox(height: AppSpacing.sm),
        for (final state in ToothState.values)
          ListTile(
            key: ValueKey('tooth-state-${state.name}'),
            leading: Icon(
              state == selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: state == selected
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            title: Text(AppFormat.enumLabel(state)),
            trailing: state == current
                ? StatusBadge(label: 'Current', tone: BadgeTone.info)
                : null,
            onTap: () => setState(() => _selected = state),
          ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          key: const ValueKey('tooth-state-note'),
          controller: _note,
          decoration: InputDecoration(labelText: ChartStrings.noteOptional),
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: AppSpacing.lg),
        BigActionButton(
          key: const ValueKey('tooth-state-save'),
          label: s.save,
          loading: _saving,
          onPressed: selected == null || _saving ? null : () => _save(selected),
        ),
      ],
    );
  }
}
