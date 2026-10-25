import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';

import 'chart_strings.dart';
import 'consent_guard.dart';

/// Blocks a procedure that needs a signed consent when none is on record:
/// one tap opens the consent form, or the clinician types the reason for
/// going ahead without it. Test keys: `consent-reason`, `consent-get`,
/// `consent-confirm`, `consent-cancel`.
class ConsentGuardDialog extends StatefulWidget {
  /// Creates the dialog.
  const ConsentGuardDialog({super.key, required this.procedureName});

  /// Procedure about to start.
  final String procedureName;

  /// Shows the dialog; null when cancelled.
  static Future<ConsentResolution?> show(
    BuildContext context, {
    required String procedureName,
  }) => showDialog<ConsentResolution>(
    context: context,
    useRootNavigator: true,
    builder: (_) => ConsentGuardDialog(procedureName: procedureName),
  );

  @override
  State<ConsentGuardDialog> createState() => _ConsentGuardDialogState();
}

class _ConsentGuardDialogState extends State<ConsentGuardDialog> {
  final TextEditingController _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final valid = ConsentResolution.reasonIsValid(_reason.text);
    return AlertDialog(
      title: Text(ChartStrings.consentTitle),
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
            Text(ChartStrings.consentBody),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              key: const ValueKey('consent-get'),
              onPressed: () =>
                  Navigator.of(context)
                      .pop(const ConsentResolution.getConsent()),
              icon: const Icon(Icons.draw_outlined),
              label: Text(ChartStrings.consentGet),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const ValueKey('consent-reason'),
              controller: _reason,
              minLines: 1,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: ChartStrings.consentReason,
                helperText: valid ? null : ChartStrings.consentReasonRequired,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('consent-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.cancel),
        ),
        TextButton(
          key: const ValueKey('consent-confirm'),
          onPressed: valid
              ? () =>
                    Navigator.of(context)
                        .pop(ConsentResolution.withReason(_reason.text))
              : null,
          child: Text(ChartStrings.consentProceed),
        ),
      ],
    );
  }
}
