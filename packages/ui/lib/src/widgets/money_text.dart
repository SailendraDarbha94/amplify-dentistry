import 'package:flutter/material.dart';

/// Visual weight of a [MoneyText].
enum MoneyEmphasis {
  /// Inline body text.
  normal,

  /// Bold title-sized, for line totals.
  strong,

  /// Large display figure, for the amount due on a bill screen.
  hero,
}

/// Renders a pre-formatted currency string (for example from
/// `Money.format()` in `ampdent_core`) with tabular figures. Takes a [String]
/// so this package stays free of domain dependencies.
class MoneyText extends StatelessWidget {
  /// Creates a money label.
  const MoneyText(
    this.amount, {
    super.key,
    this.emphasis = MoneyEmphasis.normal,
    this.color,
    this.textAlign,
  });

  /// Formatted amount, e.g. `₹1,25,000.50` or `-₹500.00`.
  final String amount;

  /// Size and weight.
  final MoneyEmphasis emphasis;

  /// Overrides the text colour; negatives default to the error colour.
  final Color? color;

  /// Horizontal alignment.
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = switch (emphasis) {
      MoneyEmphasis.normal => theme.textTheme.bodyLarge,
      MoneyEmphasis.strong => theme.textTheme.titleMedium,
      MoneyEmphasis.hero => theme.textTheme.displaySmall,
    };
    final negative = amount.trimLeft().startsWith('-');
    final style = base?.copyWith(
      color: color ?? (negative ? theme.colorScheme.error : null),
      fontWeight: emphasis == MoneyEmphasis.normal
          ? FontWeight.w500
          : FontWeight.w700,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Text(
      amount,
      style: style,
      textAlign: textAlign,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
