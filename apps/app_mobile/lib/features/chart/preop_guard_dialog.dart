import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'chart_strings.dart';
import 'preop_guard.dart';

/// Asks the clinician to attach a pre-operative radiograph or type the
/// reason none was taken before endodontic, extraction, implant or crown
/// work starts. Test keys: `preop-image-<id>`, `preop-reason`,
/// `preop-confirm`, `preop-cancel`.
class PreOpGuardDialog extends ConsumerStatefulWidget {
  /// Creates the dialog.
  const PreOpGuardDialog({
    super.key,
    required this.procedureName,
    this.candidates = const [],
  });

  /// Procedure about to start.
  final String procedureName;

  /// Radiographs of the patient that may be attached.
  final List<ImageRecord> candidates;

  /// Shows the dialog; null when cancelled.
  static Future<PreOpResolution?> show(
    BuildContext context, {
    required String procedureName,
    List<ImageRecord> candidates = const [],
  }) => showDialog<PreOpResolution>(
    context: context,
    useRootNavigator: true,
    builder: (_) =>
        PreOpGuardDialog(procedureName: procedureName, candidates: candidates),
  );

  @override
  ConsumerState<PreOpGuardDialog> createState() => _PreOpGuardDialogState();
}

class _PreOpGuardDialogState extends ConsumerState<PreOpGuardDialog> {
  final Set<String> _selected = {};
  final TextEditingController _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  PreOpResolution get _resolution =>
      PreOpResolution(imageIds: _selected.toList(), reason: _reason.text);

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final notation = ref.watch(notationProvider);
    final valid = _resolution.isValid;
    return AlertDialog(
      title: Text(ChartStrings.preOpTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.procedureName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(ChartStrings.preOpBody),
            if (widget.candidates.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                ChartStrings.preOpAttach,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              for (final image in widget.candidates)
                CheckboxListTile(
                  key: ValueKey('preop-image-${image.id}'),
                  contentPadding: EdgeInsets.zero,
                  value: _selected.contains(image.id),
                  title: Text(AppFormat.enumLabel(image.kind)),
                  subtitle: Text(
                    [
                      AppFormat.date(image.capturedAt),
                      if (image.teeth.isNotEmpty)
                        notation.formatAll(image.teeth, plain: true),
                    ].join(' · '),
                  ),
                  onChanged: (v) => setState(() {
                    if (v ?? false) {
                      _selected.add(image.id);
                    } else {
                      _selected.remove(image.id);
                    }
                  }),
                ),
            ],
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const ValueKey('preop-reason'),
              controller: _reason,
              minLines: 1,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: ChartStrings.preOpReason,
                helperText: valid ? null : ChartStrings.preOpReasonRequired,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('preop-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.cancel),
        ),
        FilledButton(
          key: const ValueKey('preop-confirm'),
          onPressed: valid
              ? () => Navigator.of(context).pop(_resolution)
              : null,
          child: Text(ChartStrings.proceed),
        ),
      ],
    );
  }
}
