import 'package:ampdent_core/ampdent_core.dart';
import 'package:test/test.dart';

void main() {
  group('ToothId FDI parsing', () {
    test('parses permanent and primary codes', () {
      expect(ToothId.parse('11').fdi, '11');
      expect(ToothId.parse('48').fdi, '48');
      expect(ToothId.parse('55').isPrimary, isTrue);
      expect(ToothId.parse('85').position, 5);
    });

    test('rejects invalid codes', () {
      expect(ToothId.tryParse('19'), isNull);
      expect(ToothId.tryParse('56'), isNull);
      expect(ToothId.tryParse('00'), isNull);
      expect(ToothId.tryParse('9'), isNull);
      expect(ToothId.tryParse('abc'), isNull);
    });

    test('round-trips supernumerary storage keys', () {
      final t = ToothId.parse('11+1');
      expect(t.isSupernumerary, isTrue);
      expect(t.storageKey, '11+1');
      expect(ToothId.parse(t.storageKey), t);
    });
  });

  group('Universal conversion', () {
    test('matches the ADA table for all 32 permanent teeth', () {
      const expected = {
        '18': 1, '17': 2, '16': 3, '15': 4, '14': 5, '13': 6, '12': 7, '11': 8,
        '21': 9, '22': 10, '23': 11, '24': 12, '25': 13, '26': 14, '27': 15, '28': 16,
        '38': 17, '37': 18, '36': 19, '35': 20, '34': 21, '33': 22, '32': 23, '31': 24,
        '41': 25, '42': 26, '43': 27, '44': 28, '45': 29, '46': 30, '47': 31, '48': 32,
      };
      for (final e in expected.entries) {
        expect(ToothId.parse(e.key).universalNumber, e.value, reason: e.key);
        expect(ToothId.tryParseUniversal('${e.value}')!.fdi, e.key);
      }
    });

    test('matches the ADA letters for all 20 primary teeth', () {
      const expected = {
        '55': 'A', '54': 'B', '53': 'C', '52': 'D', '51': 'E',
        '61': 'F', '62': 'G', '63': 'H', '64': 'I', '65': 'J',
        '75': 'K', '74': 'L', '73': 'M', '72': 'N', '71': 'O',
        '81': 'P', '82': 'Q', '83': 'R', '84': 'S', '85': 'T',
      };
      for (final e in expected.entries) {
        expect(ToothId.parse(e.key).universalLetter, e.value, reason: e.key);
        expect(ToothId.tryParseUniversal(e.value)!.fdi, e.key);
      }
    });

    test('supernumerary teeth map to 51-82 and AS-TS', () {
      expect(ToothId.parse('11+1').universal, '58');
      expect(ToothId.parse('55+1').universal, 'AS');
      expect(ToothId.tryParseUniversal('58')!.storageKey, '11+1');
      expect(ToothId.tryParseUniversal('AS')!.storageKey, '55+1');
    });
  });

  group('Palmer', () {
    test('renders quadrant glyphs and plain text', () {
      expect(ToothId.parse('11').palmer, '1┘');
      expect(ToothId.parse('21').palmer, '└1');
      expect(ToothId.parse('31').palmer, '┌1');
      expect(ToothId.parse('41').palmer, '1┐');
      expect(ToothId.parse('65').palmerText, 'ULE');
      expect(ToothNotation.palmer.tryParse('UR6')!.fdi, '16');
      expect(ToothNotation.palmer.tryParse('LL E')!.fdi, '75');
    });
  });

  group('Morphology', () {
    test('types, roots and anterior flag', () {
      expect(ToothId.parse('13').type, ToothType.canine);
      expect(ToothId.parse('14').type, ToothType.premolar);
      expect(ToothId.parse('54').type, ToothType.molar);
      expect(ToothId.parse('14').typicalRootCount, 2);
      expect(ToothId.parse('16').typicalRootCount, 3);
      expect(ToothId.parse('46').typicalRootCount, 2);
      expect(ToothId.parse('32').isAnterior, isTrue);
      expect(ToothId.parse('36').isPosterior, isTrue);
    });

    test('predecessor and successor', () {
      expect(ToothId.parse('14').primaryPredecessor!.fdi, '54');
      expect(ToothId.parse('16').primaryPredecessor, isNull);
      expect(ToothId.parse('75').permanentSuccessor!.fdi, '35');
    });

    test('arch rows read patient-right to patient-left', () {
      final row = ToothId.archRow(Arch.upper, Dentition.permanent);
      expect(row.first.fdi, '18');
      expect(row[7].fdi, '11');
      expect(row[8].fdi, '21');
      expect(row.last.fdi, '28');
      expect(ToothId.permanentTeeth().length, 32);
      expect(ToothId.primaryTeeth().length, 20);
    });
  });

  group('Notation helpers', () {
    test('parseToothList accepts mixed free text', () {
      final teeth = parseToothList('16, 17 ; 26');
      expect(teeth.map((t) => t.fdi), ['16', '17', '26']);
      expect(parseToothList('UR6 UL6').map((t) => t.fdi), ['16', '26']);
      expect(
        parseToothList('3, 14', preferred: ToothNotation.universal)
            .map((t) => t.fdi),
        ['16', '26'],
      );
    });

    test('formatAll sorts and joins', () {
      final teeth = [ToothId.parse('26'), ToothId.parse('16')];
      expect(ToothNotation.fdi.formatAll(teeth), '16, 26');
      expect(ToothNotation.universal.formatAll(teeth), '3, 14');
    });
  });
}
