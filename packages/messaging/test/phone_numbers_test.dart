import 'package:ampdent_messaging/ampdent_messaging.dart';
import 'package:test/test.dart';

void main() {
  group('PhoneNumbers.normaliseIndian', () {
    const expected = '+919876543210';
    const accepted = [
      '9876543210',
      '98765 43210',
      '98765-43210',
      '09876543210',
      '0 98765 43210',
      '919876543210',
      '+919876543210',
      '+91 98765-43210',
      '+91 (98765) 43210',
      '+91.98765.43210',
      '00919876543210',
      '  +91 98765 43210  ',
    ];

    for (final input in accepted) {
      test('accepts "$input"', () {
        expect(PhoneNumbers.normaliseIndian(input), expected);
        expect(PhoneNumbers.isValidIndianMobile(input), isTrue);
      });
    }

    const rejected = [
      '',
      '   ',
      '12345',
      '5876543210', // subscriber must start 6-9
      '0876543210', // 10 digits starting with 0
      '98765432101', // 11 digits, no trunk zero
      '+1 415 555 2671', // not India
      '+91 1234567890', // +91 with invalid subscriber
      '91987654321', // 11 digits starting 91 but not trunk zero
      '98765 4321O', // letter O
      'abc',
    ];

    for (final input in rejected) {
      test('rejects "$input"', () {
        expect(PhoneNumbers.tryNormaliseIndian(input), isNull);
        expect(PhoneNumbers.isValidIndianMobile(input), isFalse);
        expect(
          () => PhoneNumbers.normaliseIndian(input),
          throwsA(isA<FormatException>()),
        );
      });
    }
  });

  group('PhoneNumbers.isE164', () {
    test('accepts well-formed numbers and rejects the rest', () {
      expect(PhoneNumbers.isE164('+919876543210'), isTrue);
      expect(PhoneNumbers.isE164('+14155552671'), isTrue);
      expect(PhoneNumbers.isE164('919876543210'), isFalse);
      expect(PhoneNumbers.isE164('+0919876543210'), isFalse);
      expect(PhoneNumbers.isE164('+91 98765 43210'), isFalse);
      expect(PhoneNumbers.isE164('+1234567890123456'), isFalse);
    });
  });

  group('PhoneNumbers.digitsOnly', () {
    test('strips the plus for wa.me', () {
      expect(PhoneNumbers.digitsOnly('+919876543210'), '919876543210');
    });
  });

  group('PhoneNumbers.mask', () {
    test('keeps country code and last four', () {
      expect(PhoneNumbers.mask('+919876543210'), '+91******3210');
      expect(PhoneNumbers.mask('+14155552671'), '+14*****2671');
    });

    test('masks non-E.164 input wholesale', () {
      expect(PhoneNumbers.mask('98765 43210'), '****');
      expect(PhoneNumbers.mask(''), '****');
    });
  });
}
