import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';

/// One-field text prompt (rename a plan or phase, enter teeth). Owns its
/// controller so it outlives the closing animation. Returns the trimmed
/// text, or null when cancelled.
class TextPromptDialog extends StatefulWidget {
  /// Creates the dialog.
  const TextPromptDialog({
    super.key,
    required this.title,
    this.initial = '',
    this.labelText,
    this.hintText,
    this.keyboardType,
    this.okLabel,
    this.fieldKey,
    this.okKey = const ValueKey('plan-prompt-ok'),
  });

  /// Dialog title.
  final String title;

  /// Initial field value.
  final String initial;

  /// Field label.
  final String? labelText;

  /// Field hint.
  final String? hintText;

  /// Keyboard type.
  final TextInputType? keyboardType;

  /// Confirm button label (`Done` by default).
  final String? okLabel;

  /// Key of the text field (tests).
  final Key? fieldKey;

  /// Key of the confirm button (tests).
  final Key okKey;

  /// Shows the dialog.
  static Future<String?> show(
    BuildContext context, {
    required String title,
    String initial = '',
    String? labelText,
    String? hintText,
    TextInputType? keyboardType,
    String? okLabel,
    Key? fieldKey,
    Key okKey = const ValueKey('plan-prompt-ok'),
  }) => showDialog<String>(
    context: context,
    builder: (_) => TextPromptDialog(
      title: title,
      initial: initial,
      labelText: labelText,
      hintText: hintText,
      keyboardType: keyboardType,
      okLabel: okLabel,
      fieldKey: fieldKey,
      okKey: okKey,
    ),
  );

  @override
  State<TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<TextPromptDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: widget.fieldKey,
        controller: _controller,
        autofocus: true,
        keyboardType: widget.keyboardType,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: widget.labelText,
          hintText: widget.hintText,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.cancel),
        ),
        FilledButton(
          key: widget.okKey,
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: Text(widget.okLabel ?? s.done),
        ),
      ],
    );
  }
}

/// Bottom sheet asking for the justification an estimate revision needs
/// (DCI 5.7.1). Owns its controller. Returns the text, or null.
class EstimateJustificationSheet extends StatefulWidget {
  /// Creates the sheet.
  const EstimateJustificationSheet({super.key, required this.version});

  /// Version being issued.
  final int version;

  /// Shows the sheet.
  static Future<String?> show(BuildContext context, {required int version}) =>
      showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => EstimateJustificationSheet(version: version),
      );

  @override
  State<EstimateJustificationSheet> createState() =>
      _EstimateJustificationSheetState();
}

class _EstimateJustificationSheetState
    extends State<EstimateJustificationSheet> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ListView(
        shrinkWrap: true,
        padding: AppSpacing.screenPadding,
        children: [
          Text(
            'Estimate version ${widget.version}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'A revised estimate must say why it differs from the previous '
            'version. The patient sees this line.',
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const ValueKey('estimate-justification'),
            controller: _controller,
            autofocus: true,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Reason for revision (required)',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          BigActionButton(
            key: const ValueKey('estimate-issue'),
            label: 'Issue estimate',
            icon: Icons.request_quote_outlined,
            onPressed: () => Navigator.of(context).pop(_controller.text),
          ),
        ],
      ),
    );
  }
}
