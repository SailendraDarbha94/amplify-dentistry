import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_terminology/ampdent_terminology.dart';
import 'package:test/test.dart';

void main() {
  group('dentalDrugMaster', () {
    test('has at least 40 entries with unique codes and valid schedules', () {
      expect(dentalDrugMaster.length, greaterThanOrEqualTo(40));
      final codes = dentalDrugMaster.map((d) => d.code).toList();
      expect(codes.toSet().length, codes.length, reason: 'duplicate codes');
      for (final d in dentalDrugMaster) {
        expect(DrugSchedule.values, contains(d.schedule), reason: d.code);
        expect(
          d.code,
          matches(RegExp(r'^[A-Z0-9]+(-[A-Z0-9]+)*$')),
          reason: d.code,
        );
        expect(d.brandNames, isNotEmpty, reason: d.code);
        expect(d.defaultDurationDays, greaterThanOrEqualTo(0), reason: d.code);
        if (d.scheduleEffectiveFromIso != null) {
          expect(d.scheduleEffectiveFrom, isNotNull, reason: d.code);
          expect(d.previousSchedule, isNotNull, reason: d.code);
        }
      }
    });

    test('required schedule tags are correct', () {
      DrugSchedule s(String code) => drugSeedByCode(code)!.schedule;
      expect(s('AMOX-500'), DrugSchedule.h);
      expect(s('AMOX-CLAV-625'), DrugSchedule.h);
      expect(s('METRO-400'), DrugSchedule.h);
      expect(s('CEFIX-200'), DrugSchedule.h1);
      expect(s('CEFUROX-500'), DrugSchedule.h1);
      expect(s('CEFTRIAX-1G-INJ'), DrugSchedule.h1);
      expect(s('LEVO-500'), DrugSchedule.h1);
      expect(s('TRAMADOL-50'), DrugSchedule.h1);
      expect(s('TRAMADOL-PARA'), DrugSchedule.h1);
      expect(s('ALPRAZ-025'), DrugSchedule.h1);
      expect(s('DIAZ-5'), DrugSchedule.h1);
      expect(s('PARA-650'), DrugSchedule.otc);
      expect(s('CHX-02-MW'), DrugSchedule.otc);
      expect(s('LIGNO-2-ADR'), DrugSchedule.h);
      expect(s('LIGNO-GEL'), DrugSchedule.otc);
      expect(s('NAF-5-VARNISH'), DrugSchedule.otc);
    });

    test('scheduleAt applies the pregabalin H -> H1 change on 2026-11-16', () {
      final pregabalin = drugSeedByCode('PREGAB-75')!;
      expect(pregabalin.scheduleEffectiveFrom, DateTime(2026, 11, 16));
      expect(scheduleAt(pregabalin, DateTime(2026, 10, 1)), DrugSchedule.h);
      expect(scheduleAt(pregabalin, DateTime(2026, 11, 15)), DrugSchedule.h);
      expect(scheduleAt(pregabalin, DateTime(2026, 11, 16)), DrugSchedule.h1);
      expect(scheduleAt(pregabalin, DateTime(2026, 12, 1)), DrugSchedule.h1);
      // Drugs without an effective date are unchanged over time.
      final amox = drugSeedByCode('AMOX-500')!;
      expect(scheduleAt(amox, DateTime(2000)), DrugSchedule.h);
      expect(scheduleAt(amox, DateTime(2100)), DrugSchedule.h);
    });

    test('allergy groups are assigned', () {
      String? g(String code) => drugSeedByCode(code)!.allergyGroup;
      expect(g('AMOX-500'), AllergyGroups.penicillin);
      expect(g('AMOX-CLAV-625'), AllergyGroups.penicillin);
      expect(g('CEFIX-200'), AllergyGroups.cephalosporin);
      expect(g('CEFUROX-500'), AllergyGroups.cephalosporin);
      expect(g('CEFTRIAX-1G-INJ'), AllergyGroups.cephalosporin);
      for (final code in [
        'IBU-400',
        'DICLO-50',
        'ACECLO-100',
        'KETO-10',
        'ETORI-90',
      ]) {
        expect(g(code), AllergyGroups.nsaid, reason: code);
      }
      expect(g('LIGNO-2-ADR'), AllergyGroups.localAnaesthetic);
      expect(g('ARTIC-4-ADR'), AllergyGroups.localAnaesthetic);
      expect(drugsInAllergyGroup(AllergyGroups.penicillin).length, 2);
    });

    test('toJson/fromJson round-trips', () {
      for (final d in dentalDrugMaster) {
        expect(
          DrugSeed.fromJson(d.toJson()).toJson(),
          d.toJson(),
          reason: d.code,
        );
      }
    });

    test('search matches brand names', () {
      expect(searchDrugs('dolo').single.code, 'PARA-650');
      expect(searchDrugs('augmentin').single.code, 'AMOX-CLAV-625');
    });
  });
}
