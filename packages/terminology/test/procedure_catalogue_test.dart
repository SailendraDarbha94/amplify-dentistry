import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_terminology/ampdent_terminology.dart';
import 'package:test/test.dart';

void main() {
  group('indianProcedureCatalogue', () {
    test('has at least 120 entries with unique uppercase-hyphen codes', () {
      expect(indianProcedureCatalogue.length, greaterThanOrEqualTo(120));
      final codes = indianProcedureCatalogue.map((s) => s.code).toList();
      expect(codes.toSet().length, codes.length, reason: 'duplicate codes');
      for (final code in codes) {
        expect(
          code,
          matches(RegExp(r'^[A-Z0-9]+(-[A-Z0-9]+)*$')),
          reason: code,
        );
      }
    });

    test('covers every category', () {
      for (final category in ProcedureSeedCategory.values) {
        expect(
          proceduresInCategory(category),
          isNotEmpty,
          reason: category.name,
        );
      }
    });

    test('fee ranges are ordered and durations positive', () {
      for (final s in indianProcedureCatalogue) {
        expect(
          s.feeMinPaise,
          lessThanOrEqualTo(s.defaultFeePaise),
          reason: s.code,
        );
        expect(
          s.defaultFeePaise,
          lessThanOrEqualTo(s.feeMaxPaise),
          reason: s.code,
        );
        expect(s.feeMinPaise, greaterThanOrEqualTo(0), reason: s.code);
        expect(s.durationMinutes, greaterThan(0), reason: s.code);
        expect(s.name, isNotEmpty);
        expect(s.laymanName, isNotEmpty);
      }
    });

    test('every referenced consent template exists and maps back', () {
      for (final s in indianProcedureCatalogue) {
        final code = s.consentTemplateCode;
        if (code == null) continue;
        final template = consentTemplateByCode(code);
        expect(template, isNotNull, reason: '${s.code} -> $code');
        expect(consentTemplateFor(s.code)?.code, code, reason: s.code);
      }
    });

    test(
      'endodontic, extraction, implant and crown procedures need a radiograph',
      () {
        final mustHave = indianProcedureCatalogue.where(
          (s) =>
              s.category == ProcedureSeedCategory.endodontic ||
              s.category == ProcedureSeedCategory.implant ||
              s.code.startsWith('EXT-') ||
              s.code.startsWith('CRN-') && s.code != 'CRN-RECEMENT',
        );
        for (final s in mustHave) {
          expect(s.requiresPreOpRadiograph, isTrue, reason: s.code);
        }
      },
    );

    test('key research fees are encoded in paise', () {
      final rct = procedureSeedByCode('RCT-MOL')!;
      expect(rct.feeMaxPaise, 12000 * 100);
      expect(rct.stages, ['Access and BMP', 'Obturation', 'Post-op review']);
      expect(procedureSeedByCode('RCT-PRE')!.defaultFeePaise, 4500 * 100);
      final zir = procedureSeedByCode('CRN-ZIR')!;
      expect(zir.feeMinPaise, 6000 * 100);
      expect(zir.feeMaxPaise, 25000 * 100);
      expect(zir.stages, [
        'Preparation and impression',
        'Try-in',
        'Cementation',
      ]);
      expect(zir.recallInterval, RecallInterval.twelveMonths);
      expect(procedureSeedByCode('IMP-PLACE')!.feeMaxPaise, 120000 * 100);
      expect(procedureSeedByCode('ALIGNER-CASE')!.feeMaxPaise, 400000 * 100);
      expect(
        procedureSeedByCode('SCALING-ADULT')!.recallInterval,
        RecallInterval.sixMonths,
      );
      expect(
        procedureSeedByCode('PERIO-MAINT')!.recallInterval,
        RecallInterval.threeMonths,
      );
    });

    test('GST classes and SAC/HSN codes are consistent', () {
      for (final s in indianProcedureCatalogue) {
        switch (s.gstClass) {
          case GstClass.exemptHealthcare:
            expect(s.sacHsnCode, '999312', reason: s.code);
          case GstClass.cosmeticTaxable:
            expect(s.sacHsnCode, '999722', reason: s.code);
            expect(s.category, ProcedureSeedCategory.cosmetic, reason: s.code);
          case GstClass.goods:
            expect(s.code, startsWith('GOODS-'), reason: s.code);
          case GstClass.standardTaxable:
            fail('no catalogue seed should be standard-rated: ${s.code}');
        }
      }
      expect(
        procedureSeedByCode('WHITENING-OFFICE')!.gstClass,
        GstClass.cosmeticTaxable,
      );
      expect(
        procedureSeedByCode('SMILE-VNR')!.gstClass,
        GstClass.cosmeticTaxable,
      );
      expect(
        procedureSeedByCode('GOODS-DENTURE-ADHESIVE')!.gstClass,
        GstClass.goods,
      );
    });

    test('toJson/fromJson round-trips', () {
      for (final s in indianProcedureCatalogue) {
        final back = ProcedureSeed.fromJson(s.toJson());
        expect(back.toJson(), s.toJson(), reason: s.code);
      }
    });

    test('search finds by code, name and layman name', () {
      expect(searchProcedures('rct-mol').single.code, 'RCT-MOL');
      expect(
        searchProcedures('wisdom').map((s) => s.code),
        contains('EXT-3M-IMPACTED'),
      );
      expect(searchProcedures(''), isEmpty);
    });

    test('category is the core ProcedureCategory enum', () {
      for (final s in indianProcedureCatalogue) {
        expect(s.category, isA<ProcedureCategory>(), reason: s.code);
      }
      expect(ProcedureSeedCategory.values, ProcedureCategory.values);
    });

    test('every crown-coded procedure requires a pre-op radiograph', () {
      for (final s in indianProcedureCatalogue) {
        if (s.code.startsWith('CRN-')) {
          expect(s.requiresPreOpRadiograph, isTrue, reason: s.code);
        }
      }
    });
  });
}
