import 'package:flutter/material.dart';

/// Formats Indian phone numbers for display: `+91 98765 43210`.
abstract final class IndianPhoneFormat {
  /// Normalises `9876543210`, `09876543210`, `919876543210`, `+91-98765 43210`
  /// to `+91 98765 43210`. Anything that is not a 10-digit Indian mobile or
  /// landline after stripping the country code is returned trimmed as-is.
  static String format(String raw) {
    final trimmed = raw.trim();
    var digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 12 && digits.startsWith('91')) {
      digits = digits.substring(2);
    } else if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    if (digits.length != 10) return trimmed;
    return '+91 ${digits.substring(0, 5)} ${digits.substring(5)}';
  }

  /// Returns the bare 10-digit national number, or null when [raw] is not an
  /// Indian number. Use before storing or dialling.
  static String? nationalDigits(String raw) {
    final formatted = format(raw);
    if (!formatted.startsWith('+91 ')) return null;
    return formatted.replaceAll(RegExp(r'\D'), '').substring(2);
  }

  /// True when [raw] is a plausible Indian mobile number (10 digits, 6-9 lead).
  static bool isValidMobile(String raw) {
    final national = nationalDigits(raw);
    return national != null && RegExp(r'^[6-9]\d{9}$').hasMatch(national);
  }
}

/// Text widget that renders a phone number in Indian display format with
/// tabular figures.
class PhoneText extends StatelessWidget {
  /// Creates a phone label.
  const PhoneText(this.number, {super.key, this.style, this.icon = false});

  /// Raw number in any common form.
  final String number;

  /// Optional text style; defaults to bodyLarge.
  final TextStyle? style;

  /// Shows a small phone icon before the number.
  final bool icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = Text(
      IndianPhoneFormat.format(number),
      style: (style ?? theme.textTheme.bodyLarge)?.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    if (!icon) return text;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.phone_outlined,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        text,
      ],
    );
  }
}
