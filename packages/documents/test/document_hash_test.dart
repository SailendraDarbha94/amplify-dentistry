import 'dart:convert';
import 'dart:typed_data';

import 'package:ampdent_documents/ampdent_documents.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

void main() {
  group('document hash', () {
    test('sha256Hex of known bytes', () {
      final bytes = Uint8List.fromList(utf8.encode('abc'));
      expect(
        sha256Hex(bytes),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
    });

    test('canonical JSON is key-order independent', () {
      expect(
        canonicalJson({
          'b': 1,
          'a': {
            'd': 2,
            'c': [3, 4],
          },
        }),
        '{"a":{"c":[3,4],"d":2},"b":1}',
      );
      expect(
        documentContentHash({'b': 1, 'a': 2}),
        documentContentHash({'a': 2, 'b': 1}),
      );
    });

    test('entity hash is stable across re-renders', () {
      final a = InvoicePdf(
        clinic: clinic,
        dentist: dentist,
        patient: patient,
        invoice: sampleInvoice(),
        theme: testTheme(),
      );
      final b = InvoicePdf(
        clinic: clinic,
        dentist: dentist,
        patient: patient,
        invoice: sampleInvoice(),
        theme: testTheme(),
      );
      expect(a.documentHash, b.documentHash);
      expect(a.documentHash, hasLength(64));
    });

    test('shortHash truncates and upper-cases', () {
      expect(shortHash('abcdef0123456789abcdef', length: 8), 'ABCDEF01');
      expect(shortHash('ab', length: 8), 'AB');
    });
  });
}
