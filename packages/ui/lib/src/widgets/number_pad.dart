import 'package:flutter/material.dart';

import '../strings/app_strings.dart';
import '../theme/app_spacing.dart';

/// Large on-screen keypad for amounts, tooth numbers and probing depths.
/// Digits and [extraKeys] (for example `'.'` or `'00'`) are delivered through
/// [onDigit]; the bottom row has backspace and a full-width Done button.
class NumberPad extends StatelessWidget {
  /// Creates a keypad.
  const NumberPad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.onDone,
    this.extraKeys = const [],
    this.doneLabel,
    this.keyHeight = AppSpacing.bigButtonHeight,
    this.showDone = true,
  });

  /// Called with the pressed key text (`'0'`-`'9'` or an extra key).
  final ValueChanged<String> onDigit;

  /// Called when backspace is pressed.
  final VoidCallback onBackspace;

  /// Called when Done is pressed; null disables the button.
  final VoidCallback? onDone;

  /// Extra keys. The first takes the slot left of `0`; the rest form an
  /// additional row above Done.
  final List<String> extraKeys;

  /// Done button label; defaults to [AppStrings.done].
  final String? doneLabel;

  /// Height of each key (minimum 48).
  final double keyHeight;

  /// Hides the Done row when false.
  final bool showDone;

  /// Semantics label used for the backspace key in tests and screen readers.
  static const String backspaceSemanticsLabel = 'Backspace';

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final firstExtra = extraKeys.isNotEmpty ? extraKeys.first : null;
    final remainingExtras = extraKeys.length > 1
        ? extraKeys.sublist(1)
        : const <String>[];
    final rows = <List<Widget>>[
      [_key('1'), _key('2'), _key('3')],
      [_key('4'), _key('5'), _key('6')],
      [_key('7'), _key('8'), _key('9')],
      [
        if (firstExtra != null)
          _key(firstExtra, secondary: true)
        else
          const SizedBox.shrink(),
        _key('0'),
        _NumberPadKey(
          height: keyHeight,
          onPressed: onBackspace,
          secondary: true,
          semanticsLabel: backspaceSemanticsLabel,
          child: const Icon(Icons.backspace_outlined, size: 26),
        ),
      ],
      if (remainingExtras.isNotEmpty)
        [for (final k in remainingExtras) _key(k, secondary: true)],
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                for (var i = 0; i < row.length; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.sm),
                  Expanded(child: row[i]),
                ],
              ],
            ),
          ),
        if (showDone)
          SizedBox(
            height: keyHeight,
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onDone,
              icon: const Icon(Icons.check),
              label: Text(doneLabel ?? strings.done),
            ),
          ),
      ],
    );
  }

  Widget _key(String text, {bool secondary = false}) => _NumberPadKey(
    height: keyHeight,
    onPressed: () => onDigit(text),
    secondary: secondary,
    semanticsLabel: text,
    child: Text(text),
  );
}

class _NumberPadKey extends StatelessWidget {
  const _NumberPadKey({
    required this.height,
    required this.onPressed,
    required this.child,
    required this.semanticsLabel,
    this.secondary = false,
  });

  final double height;
  final VoidCallback onPressed;
  final Widget child;
  final String semanticsLabel;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: SizedBox(
        height: height.clamp(AppSpacing.minTapTarget, double.infinity),
        child: Material(
          color: secondary
              ? scheme.surfaceContainerHigh
              : scheme.surfaceContainerHighest,
          shape: RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Center(
              child: DefaultTextStyle(
                style: theme.textTheme.headlineSmall!.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                child: IconTheme(
                  data: IconThemeData(color: scheme.onSurface),
                  child: ExcludeSemantics(child: child),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
