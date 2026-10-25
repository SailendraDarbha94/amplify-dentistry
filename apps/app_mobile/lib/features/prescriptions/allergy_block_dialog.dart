import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';

/// Minimum length of an override reason.
const int minOverrideReasonLength = 5;

/// Red blocking dialog shown when a drug matches one of the patient's
/// recorded allergies (by group or by substance name). Returns the override reason, or null when
/// the dentist backs out. The confirm button stays disabled until a reason
/// of at least [minOverrideReasonLength] characters is typed.
class AllergyBlockDialog extends StatefulWidget {
  /// Creates the dialog.
  const AllergyBlockDialog({
    super.key,
    required this.drug,
    required this.matches,
  });

  /// Drug being added.
  final Drug drug;

  /// Allergy entries that match the drug.
  final List<AllergyEntry> matches;

  /// Shows the dialog; resolves to the reason or null.
  static Future<String?> show(
    BuildContext context, {
    required Drug drug,
    required List<AllergyEntry> matches,
  }) => showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AllergyBlockDialog(drug: drug, matches: matches),
  );

  @override
  State<AllergyBlockDialog> createState() => _AllergyBlockDialogState();
}

class _AllergyBlockDialogState extends State<AllergyBlockDialog> {
  final TextEditingController _reason = TextEditingController();

  bool get _canOverride =>
      _reason.text.trim().length >= minOverrideReasonLength;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final danger = AppColors.of(context).danger;
    final theme = Theme.of(context);
    return AlertDialog(
      key: const ValueKey('allergy-block-dialog'),
      icon: Icon(Icons.dangerous_outlined, color: danger, size: 40),
      iconColor: danger,
      title: Text(
        'Allergy recorded',
        style: theme.textTheme.titleLarge?.copyWith(color: danger),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.drug.allergyGroup == null ||
                      widget.drug.allergyGroup!.isEmpty
                  ? '${widget.drug.genericName.toUpperCase()} matches an '
                        'allergy this patient has recorded:'
                  : '${widget.drug.genericName.toUpperCase()} belongs to the '
                        '${widget.drug.allergyGroup} group. This patient has '
                        'recorded:',
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final a in widget.matches)
              Text(
                '• ${a.substance}'
                '${a.reaction == null ? '' : ' - ${a.reaction}'}'
                '${a.severity == AllergySeverity.unknown ? '' : ' (${a.severity.name})'}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Prescribe anyway only with a documented reason. The reason is '
              'written to the audit log.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const ValueKey('allergy-override-reason'),
              controller: _reason,
              autofocus: true,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Override reason',
                hintText:
                    'e.g. Tolerated same drug in 2024; allergy was '
                    'to a different agent',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('allergy-override-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.cancel),
        ),
        FilledButton(
          key: const ValueKey('allergy-override-confirm'),
          style: FilledButton.styleFrom(backgroundColor: danger),
          onPressed: _canOverride
              ? () => Navigator.of(context).pop(_reason.text.trim())
              : null,
          child: const Text('Prescribe anyway'),
        ),
      ],
    );
  }
}
