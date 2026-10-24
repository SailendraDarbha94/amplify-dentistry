import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';

/// Bottom sheet that collects a mandatory free-text reason, with quick-pick
/// chips. Pops with the trimmed reason, or null when cancelled; the confirm
/// button stays disabled while the reason is blank.
class ReasonSheet extends StatefulWidget {
  /// Creates the sheet.
  const ReasonSheet({
    super.key,
    required this.title,
    this.message,
    this.suggestions = const [],
    this.confirmLabel,
    this.destructive = false,
  });

  /// Heading.
  final String title;

  /// Optional explanation under the heading.
  final String? message;

  /// Quick-pick reasons shown as chips.
  final List<String> suggestions;

  /// Confirm button label; defaults to `Confirm`.
  final String? confirmLabel;

  /// Styles the confirm button as destructive.
  final bool destructive;

  /// Shows the sheet; resolves to the reason or null.
  static Future<String?> show(
    BuildContext context, {
    required String title,
    String? message,
    List<String> suggestions = const [],
    String? confirmLabel,
    bool destructive = false,
  }) => showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ReasonSheet(
      title: title,
      message: message,
      suggestions: suggestions,
      confirmLabel: confirmLabel,
      destructive: destructive,
    ),
  );

  @override
  State<ReasonSheet> createState() => _ReasonSheetState();
}

class _ReasonSheetState extends State<ReasonSheet> {
  final TextEditingController _reason = TextEditingController();

  @override
  void initState() {
    super.initState();
    _reason.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final theme = Theme.of(context);
    final text = _reason.text.trim();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ListView(
        shrinkWrap: true,
        padding: AppSpacing.screenPadding,
        children: [
          Text(widget.title, style: theme.textTheme.titleLarge),
          if (widget.message != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(widget.message!, style: theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: AppSpacing.md),
          if (widget.suggestions.isNotEmpty) ...[
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final r in widget.suggestions)
                  ChoiceChip(
                    key: ValueKey('reason-chip-$r'),
                    label: Text(r),
                    selected: text == r,
                    onSelected: (_) => _reason.text = r,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          TextField(
            key: const ValueKey('reason-text'),
            controller: _reason,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Reason (${s.required.toLowerCase()})',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(s.cancel),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton(
                  key: const ValueKey('reason-confirm'),
                  style: widget.destructive
                      ? FilledButton.styleFrom(
                          backgroundColor: AppColors.of(context).danger,
                        )
                      : null,
                  onPressed: text.isEmpty
                      ? null
                      : () => Navigator.of(context).pop(text),
                  child: Text(widget.confirmLabel ?? s.confirm),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
