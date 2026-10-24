/// E.164 handling for Indian mobile numbers: normalisation of the forms
/// patients write ('98765 43210', '09876543210', '+91 98765-43210'), strict
/// validation, and masking for logs so a phone never appears in full.
abstract final class PhoneNumbers {
  /// India's country calling code, without the plus sign.
  static const String indiaCountryCode = '91';

  /// Indian mobile numbers are 10 digits and start with 6, 7, 8 or 9.
  static final RegExp _indianSubscriber = RegExp(r'^[6-9][0-9]{9}$');

  /// Any E.164 number: plus, a non-zero leading digit, 7 to 15 digits total.
  static final RegExp _e164 = RegExp(r'^\+[1-9][0-9]{6,14}$');

  /// Everything that is not a digit or a leading plus.
  static final RegExp _separators = RegExp(r'[\s\-().]');

  /// Normalises [input] to `+91XXXXXXXXXX`, or returns null when it is not a
  /// valid Indian mobile number.
  ///
  /// Accepted shapes: a bare 10-digit subscriber number, a trunk-prefixed
  /// `0` + 10 digits, `91` + 10 digits, `+91` + 10 digits, `0091` + 10 digits,
  /// each with any mix of spaces, dashes, dots and parentheses.
  static String? tryNormaliseIndian(String input) {
    var s = input.trim().replaceAll(_separators, '');
    if (s.isEmpty) return null;
    if (s.startsWith('+')) s = s.substring(1);
    if (!RegExp(r'^[0-9]+$').hasMatch(s)) return null;

    String? subscriber;
    if (s.length == 10) {
      subscriber = s;
    } else if (s.length == 11 && s.startsWith('0')) {
      subscriber = s.substring(1);
    } else if (s.length == 12 && s.startsWith(indiaCountryCode)) {
      subscriber = s.substring(2);
    } else if (s.length == 14 && s.startsWith('00$indiaCountryCode')) {
      subscriber = s.substring(4);
    }
    if (subscriber == null || !_indianSubscriber.hasMatch(subscriber)) {
      return null;
    }
    return '+$indiaCountryCode$subscriber';
  }

  /// Normalises [input] to `+91XXXXXXXXXX`; throws [FormatException] when it
  /// is not a valid Indian mobile number.
  static String normaliseIndian(String input) {
    final result = tryNormaliseIndian(input);
    if (result == null) {
      throw FormatException('Not a valid Indian mobile number', input);
    }
    return result;
  }

  /// Whether [input], in any accepted written form, is an Indian mobile.
  static bool isValidIndianMobile(String input) =>
      tryNormaliseIndian(input) != null;

  /// Whether [value] is already a strict E.164 string (`+` and 7-15 digits).
  static bool isE164(String value) => _e164.hasMatch(value);

  /// Digits only, no plus: the form `wa.me/<digits>` expects.
  static String digitsOnly(String e164) => e164.replaceAll(RegExp(r'\D'), '');

  /// Masks an E.164 number for logs: country code and last four kept,
  /// everything between replaced by stars (`+91******3210`).
  ///
  /// Inputs that are not E.164 are masked wholesale to `****`.
  static String mask(String phone) {
    if (!isE164(phone)) return '****';
    const keepPrefix = 3; // '+' plus a two-digit country code
    const keepSuffix = 4;
    if (phone.length <= keepPrefix + keepSuffix) {
      return '${phone.substring(0, 1)}${'*' * (phone.length - 1)}';
    }
    final stars = '*' * (phone.length - keepPrefix - keepSuffix);
    return '${phone.substring(0, keepPrefix)}$stars'
        '${phone.substring(phone.length - keepSuffix)}';
  }
}
