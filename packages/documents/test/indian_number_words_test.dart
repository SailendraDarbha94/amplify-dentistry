import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_documents/ampdent_documents.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('rupeesInWords', () {
    test('zero', () {
      expect(rupeesInWords(const Money.zero()), 'Rupees Zero Only');
    });

    test('one', () {
      expect(rupeesInWords(const Money.rupees(1)), 'Rupees One Only');
    });

    test('twenty-one', () {
      expect(rupeesInWords(const Money.rupees(21)), 'Rupees Twenty-One Only');
    });

    test('one hundred five', () {
      expect(
        rupeesInWords(const Money.rupees(105)),
        'Rupees One Hundred Five Only',
      );
    });

    test('one thousand', () {
      expect(
        rupeesInWords(const Money.rupees(1000)),
        'Rupees One Thousand Only',
      );
    });

    test('one lakh', () {
      expect(rupeesInWords(const Money.rupees(100000)), 'Rupees One Lakh Only');
    });

    test('12,34,567.50', () {
      expect(
        rupeesInWords(const Money.rupees(1234567, 50)),
        'Rupees Twelve Lakh Thirty-Four Thousand Five Hundred Sixty-Seven '
        'and Fifty Paise Only',
      );
    });

    test('one crore', () {
      expect(
        rupeesInWords(const Money.rupees(10000000)),
        'Rupees One Crore Only',
      );
    });

    test('one lakh twenty-five thousand and fifty paise', () {
      expect(
        rupeesInWords(const Money.rupees(125000, 50)),
        'Rupees One Lakh Twenty-Five Thousand and Fifty Paise Only',
      );
    });

    test('paise only', () {
      expect(rupeesInWords(const Money.paise(5)), 'Rupees Five Paise Only');
    });

    test('negative', () {
      expect(
        rupeesInWords(const Money.rupees(-250)),
        'Minus Rupees Two Hundred Fifty Only',
      );
    });

    test('above a crore recurses', () {
      expect(numberToIndianWords(1000000000), 'One Hundred Crore');
      expect(
        numberToIndianWords(123456789),
        'Twelve Crore Thirty-Four Lakh Fifty-Six Thousand Seven Hundred '
        'Eighty-Nine',
      );
    });
  });
}
