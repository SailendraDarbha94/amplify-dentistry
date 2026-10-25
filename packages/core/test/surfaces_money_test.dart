import 'package:ampdent_core/ampdent_core.dart';
import 'package:test/test.dart';

void main() {
  group('SurfaceSet', () {
    test('canonical order and labels', () {
      final set = SurfaceSet.parse('DOM');
      expect(set.code, 'MOD');
      expect(set.labelFor(ToothId.parse('16')), 'MOD');
      expect(set.labelFor(ToothId.parse('11')), 'MID');
      expect(SurfaceSet.parse('BL').labelFor(ToothId.parse('16')), 'BP');
      expect(SurfaceSet.parse('BL').labelFor(ToothId.parse('46')), 'BL');
      expect(SurfaceSet.parse('FL').labelFor(ToothId.parse('41')), 'FL');
    });

    test('accepts clinical synonyms and rejects junk', () {
      expect(SurfaceSet.parse('MIFL').code, 'MOFL');
      expect(SurfaceSet.tryParse('MOX'), isNull);
      expect(SurfaceSet.tryParse('b')!.code, 'F');
    });

    test('class V folds into facial on export', () {
      final set = SurfaceSet.parse('MV');
      expect(set.code, 'MV');
      expect(set.exportCode, 'MF');
      expect(set.restorativeSurfaceCount, 1);
    });

    test('toggle', () {
      final set = SurfaceSet.parse('MO').toggled(ToothSurface.distal);
      expect(set.code, 'MOD');
      expect(set.toggled(ToothSurface.mesial).code, 'OD');
    });
  });

  group('Sextant', () {
    test('assigns teeth to the six sextants', () {
      expect(Sextant.of(ToothId.parse('17')), Sextant.upperRightPosterior);
      expect(Sextant.of(ToothId.parse('12')), Sextant.upperAnterior);
      expect(Sextant.of(ToothId.parse('23')), Sextant.upperAnterior);
      expect(Sextant.of(ToothId.parse('24')), Sextant.upperLeftPosterior);
      expect(Sextant.of(ToothId.parse('36')), Sextant.lowerLeftPosterior);
      expect(Sextant.of(ToothId.parse('41')), Sextant.lowerAnterior);
      expect(Sextant.of(ToothId.parse('45')), Sextant.lowerRightPosterior);
    });
  });

  group('Dentition defaults', () {
    test('adult chart has 28 present teeth and unerupted third molars', () {
      final states = defaultToothStates(ageYears: 30);
      final present = states.entries.where(
        (e) => e.key.isPermanent && e.value == ToothState.present,
      );
      expect(present.length, 32, reason: 'third molars present at 30');
      final states20 = defaultToothStates(ageYears: 20);
      expect(states20[ToothId.parse('18')], ToothState.unerupted);
      expect(states20[ToothId.parse('11')], ToothState.present);
      expect(states20[ToothId.parse('51')], ToothState.exfoliated);
    });

    test('toddler chart is primary only', () {
      final states = defaultToothStates(ageYears: 3);
      expect(states[ToothId.parse('55')], ToothState.present);
      expect(states[ToothId.parse('16')], ToothState.unerupted);
      expect(DentitionStage.forAgeYears(3), DentitionStage.primaryOnly);
    });

    test('eight-year-old is mixed', () {
      final states = defaultToothStates(ageYears: 8);
      expect(states[ToothId.parse('16')], ToothState.present);
      expect(states[ToothId.parse('11')], ToothState.present);
      expect(states[ToothId.parse('51')], ToothState.exfoliated);
      expect(states[ToothId.parse('55')], ToothState.present);
      expect(states[ToothId.parse('13')], ToothState.unerupted);
      expect(DentitionStage.forAgeYears(8), DentitionStage.mixed);
      final visible = visibleTeeth(states);
      expect(visible, contains(ToothId.parse('55')));
      expect(visible, isNot(contains(ToothId.parse('13'))));
    });
  });

  group('Money', () {
    test('indian grouping and paise', () {
      expect(const Money.rupees(125000, 50).format(), '₹1,25,000.50');
      expect(const Money.rupees(999).format(showPaise: false), '₹999');
      expect(const Money.rupees(1000).format(), '₹1,000.00');
      expect(const Money.rupees(-1500).format(), '-₹1,500.00');
      expect(
        const Money.rupees(10000000).format(symbol: false),
        '1,00,00,000.00',
      );
    });

    test('percent and split are exact', () {
      expect(const Money.rupees(1000).percent(18), const Money.rupees(180));
      expect(const Money.rupees(999).percent(5), const Money.paise(4995));
      final parts = const Money.rupees(10000).split(3);
      expect(parts.total, const Money.rupees(10000));
      expect(parts.map((p) => p.paise), [333334, 333333, 333333]);
    });

    test('parsing', () {
      expect(Money.tryParse('₹ 1,250.5'), const Money.paise(125050));
      expect(Money.tryParse('1250'), const Money.rupees(1250));
      expect(Money.tryParse('abc'), isNull);
    });
  });

  group('GST rate table', () {
    test('defaults and history', () {
      final table = GstRateTable.indiaDefaults();
      expect(table.rateFor(GstClass.exemptHealthcare).ratePercent, 0);
      expect(table.rateFor(GstClass.cosmeticTaxable).ratePercent, 18);
      expect(table.rateFor(GstClass.goods).ratePercent, 5);
      final custom = GstRateTable([
        GstRate(
          gstClass: GstClass.cosmeticTaxable,
          ratePercent: 18,
          inputTaxCreditAllowed: true,
          effectiveFrom: DateTime.utc(2017, 7, 1),
        ),
        GstRate(
          gstClass: GstClass.cosmeticTaxable,
          ratePercent: 5,
          inputTaxCreditAllowed: false,
          effectiveFrom: DateTime.utc(2025, 9, 22),
        ),
      ]);
      expect(
        custom
            .rateFor(GstClass.cosmeticTaxable, at: DateTime.utc(2025, 1, 1))
            .ratePercent,
        18,
      );
      expect(
        custom
            .rateFor(GstClass.cosmeticTaxable, at: DateTime.utc(2026, 1, 1))
            .ratePercent,
        5,
      );
    });
  });

  group('Perio', () {
    test('CAL and BPE derivation', () {
      final t = ToothId.parse('16');
      const r = PerioSiteReading(
        tooth: ToothId(
          dentition: Dentition.permanent,
          quadrant: Quadrant.upperRight,
          position: 6,
        ),
        site: PerioSite.mesioBuccal,
        probingDepth: 5,
        gingivalMargin: -2,
        bleeding: true,
      );
      expect(r.tooth, t);
      expect(r.clinicalAttachmentLoss, 7);
      expect(r.recession, 2);
      expect(bpeCodeFor([r]), BpeCode.code3);
      expect(bpeCodeFor([r.copyWith(probingDepth: 6)]), BpeCode.code4);
      expect(bpeCodeFor([r.copyWith(probingDepth: 2)]), BpeCode.code1);
      final summary = PerioSummary.from([r, r.copyWith(bleeding: false)]);
      expect(summary.bleedingPercent, 50);
      expect(summary.suggestedStage, PeriodontitisStage.stage3);
    });
  });
}
