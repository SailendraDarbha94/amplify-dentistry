import 'package:ampdent_core/ampdent_core.dart';

const List<String> _ones = [
  '',
  'One',
  'Two',
  'Three',
  'Four',
  'Five',
  'Six',
  'Seven',
  'Eight',
  'Nine',
  'Ten',
  'Eleven',
  'Twelve',
  'Thirteen',
  'Fourteen',
  'Fifteen',
  'Sixteen',
  'Seventeen',
  'Eighteen',
  'Nineteen',
];

const List<String> _tens = [
  '',
  '',
  'Twenty',
  'Thirty',
  'Forty',
  'Fifty',
  'Sixty',
  'Seventy',
  'Eighty',
  'Ninety',
];

/// Spells a non-negative integer in words using the Indian numbering system
/// (hundred, thousand, lakh, crore). Zero is `Zero`; values above a crore
/// recurse, so 1,00,00,00,000 is `One Hundred Crore`.
String numberToIndianWords(int value) {
  if (value < 0) return 'Minus ${numberToIndianWords(-value)}';
  if (value == 0) return 'Zero';
  return _words(value).trim();
}

String _words(int n) {
  if (n == 0) return '';
  if (n < 20) return _ones[n];
  if (n < 100) {
    final unit = n % 10;
    return unit == 0 ? _tens[n ~/ 10] : '${_tens[n ~/ 10]}-${_ones[unit]}';
  }
  if (n < 1000) return _join('${_ones[n ~/ 100]} Hundred', _words(n % 100));
  if (n < 100000) {
    return _join('${_words(n ~/ 1000)} Thousand', _words(n % 1000));
  }
  if (n < 10000000) {
    return _join('${_words(n ~/ 100000)} Lakh', _words(n % 100000));
  }
  return _join('${_words(n ~/ 10000000)} Crore', _words(n % 10000000));
}

String _join(String head, String tail) => tail.isEmpty ? head : '$head $tail';

/// Renders a [Money] amount the way an Indian invoice spells it, e.g.
/// `Rupees One Lakh Twenty-Five Thousand and Fifty Paise Only`. Whole-rupee
/// amounts omit the paise clause; zero is `Rupees Zero Only`.
String rupeesInWords(Money amount) {
  final negative = amount.isNegative;
  final rupees = amount.paise.abs() ~/ 100;
  final paise = amount.paise.abs() % 100;
  final buffer = StringBuffer();
  if (negative) buffer.write('Minus ');
  buffer.write('Rupees ');
  if (rupees == 0 && paise == 0) {
    buffer.write('Zero');
  } else {
    if (rupees > 0) buffer.write(numberToIndianWords(rupees));
    if (paise > 0) {
      if (rupees > 0) buffer.write(' and ');
      buffer.write('${numberToIndianWords(paise)} Paise');
    }
  }
  buffer.write(' Only');
  return buffer.toString();
}
