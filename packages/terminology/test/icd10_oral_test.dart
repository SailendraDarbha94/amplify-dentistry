import 'package:ampdent_terminology/ampdent_terminology.dart';
import 'package:test/test.dart';

void main() {
  group('icd10OralCodes', () {
    test('codes are unique and all in K00-K14', () {
      final codes = icd10OralCodes.map((c) => c.code).toList();
      expect(codes.toSet().length, codes.length, reason: 'duplicate codes');
      for (final c in icd10OralCodes) {
        expect(
          c.code,
          matches(RegExp(r'^K(0\d|1[0-4])(\.\d)?$')),
          reason: c.code,
        );
        expect(c.description, isNotEmpty, reason: c.code);
      }
    });

    test('every category K00..K14 is present and subcodes point to it', () {
      for (var i = 0; i <= 14; i++) {
        final cat = 'K${i.toString().padLeft(2, '0')}';
        final category = icd10ByCode(cat);
        expect(category, isNotNull, reason: cat);
        expect(category!.isCategory, isTrue);
        expect(icd10Children(cat), isNotEmpty, reason: cat);
      }
      for (final c in icd10OralCodes.where((c) => !c.isCategory)) {
        expect(c.parentCode, c.code.substring(0, 3), reason: c.code);
        expect(icd10ByCode(c.parentCode!), isNotNull, reason: c.code);
      }
    });

    test('well-known codes carry WHO descriptions', () {
      expect(icd10ByCode('K02.1')!.description, 'Caries of dentine');
      expect(icd10ByCode('K04.0')!.description, 'Pulpitis');
      expect(icd10ByCode('K05.3')!.description, 'Chronic periodontitis');
      expect(icd10ByCode('K01.1')!.description, 'Impacted teeth');
      expect(icd10ByCode('K13.5')!.description, 'Oral submucous fibrosis');
      expect(icd10ByCode('k07.6')!.code, 'K07.6');
    });

    test('search ranks code prefix first then description text', () {
      final results = searchIcd10('K04');
      expect(results.first.code, 'K04');
      expect(results.where((c) => c.code.startsWith('K04')).length, 11);
      final pulp = searchIcd10('pulp');
      expect(pulp.map((c) => c.code), contains('K04.0'));
      expect(pulp.map((c) => c.code), contains('K02.5'));
      expect(searchIcd10(''), isEmpty);
    });

    test('toJson/fromJson round-trips', () {
      for (final c in icd10OralCodes) {
        expect(Icd10Code.fromJson(c.toJson()), c);
      }
    });
  });
}
