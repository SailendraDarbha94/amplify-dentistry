import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_terminology/ampdent_terminology.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';

/// Chooses what a consent covers when the flow was opened without
/// procedure ids: tick planned procedures, or pick a stand-alone template
/// (examination, photography, orthodontics, whitening).
class ConsentPicker extends StatefulWidget {
  /// Creates the picker.
  const ConsentPicker({
    super.key,
    required this.procedures,
    required this.notation,
    required this.onContinue,
  });

  /// Procedures consent can be taken for.
  final List<ProcedureRecord> procedures;

  /// Clinic display notation.
  final ToothNotation notation;

  /// Called with the selected procedure ids, or a template code when a
  /// stand-alone template was chosen.
  final void Function(List<String> procedureIds, String? templateCode)
  onContinue;

  @override
  State<ConsentPicker> createState() => _ConsentPickerState();
}

class _ConsentPickerState extends State<ConsentPicker> {
  final Set<String> _selected = {};
  String? _template;

  bool get _canContinue => _selected.isNotEmpty || _template != null;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: AppSpacing.screenPadding,
            children: [
              Text('Planned procedures', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              if (widget.procedures.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Text(
                    'No planned procedures. Add them on the chart or pick a '
                    'template below.',
                    style: theme.textTheme.bodyMedium,
                  ),
                )
              else
                for (final p in widget.procedures)
                  CheckboxListTile(
                    key: ValueKey('consent-pick-${p.id}'),
                    value: _selected.contains(p.id),
                    onChanged: (v) => setState(() {
                      _template = null;
                      if (v ?? false) {
                        _selected.add(p.id);
                      } else {
                        _selected.remove(p.id);
                      }
                    }),
                    title: Text(p.name),
                    subtitle: Text(
                      [
                        p.code,
                        if (p.tooth != null)
                          '${s.tooth} ${widget.notation.format(p.tooth!)}',
                        if (p.teeth.isNotEmpty)
                          widget.notation.formatAll(p.teeth),
                        consentTemplateFor(p.code)?.title ?? 'General consent',
                      ].join('  |  '),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
              const SizedBox(height: AppSpacing.lg),
              Text('Other consent forms', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              RadioGroup<String>(
                groupValue: _template,
                onChanged: (v) => setState(() {
                  _template = v;
                  _selected.clear();
                }),
                child: Column(
                  children: [
                    for (final t in consentTemplates)
                      RadioListTile<String>(
                        key: ValueKey('consent-template-${t.code}'),
                        value: t.code,
                        title: Text(t.title),
                        subtitle: Text(t.code),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: AppSpacing.screenPadding,
            child: BigActionButton(
              key: const ValueKey('consent-continue'),
              label: s.next,
              icon: Icons.arrow_forward,
              onPressed: _canContinue
                  ? () => widget.onContinue(_selected.toList(), _template)
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}
