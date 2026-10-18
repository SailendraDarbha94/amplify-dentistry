import 'package:ampdent_terminology/ampdent_terminology.dart';
import 'package:test/test.dart';

const _values = {
  'name_of_patient': 'Ravi Kumar',
  'patient_age': '34',
  'patient_gender': 'male',
  'doctor_name': 'Asha Rao',
  'tooth_numbers': '36, 37',
  'clinic_name': 'Oasis Dental',
  'date': '2026-10-18',
  'registration_number': 'A-12345',
  'grievance_contact': 'privacy@example.in',
};

void main() {
  group('consentTemplates', () {
    test('has the 17 ported templates plus the 4 additions, unique codes', () {
      expect(portedConsentTemplates.length, 17);
      expect(additionalConsentTemplates.length, 4);
      final codes = consentTemplates.map((t) => t.code).toList();
      expect(codes.toSet().length, codes.length);
      for (final code in ['GENERAL-EXAM', 'ORTHO', 'WHITENING', 'PHOTO-USE']) {
        expect(consentTemplateByCode(code), isNotNull, reason: code);
      }
    });

    test('declared placeholders match the body and include the footer set', () {
      for (final t in consentTemplates) {
        expect(
          t.placeholdersInBody.toSet(),
          t.placeholders.toSet(),
          reason: t.code,
        );
        for (final p in [
          'clinic_name',
          'date',
          'registration_number',
          'doctor_name',
        ]) {
          expect(t.placeholders, contains(p), reason: '${t.code} missing $p');
        }
        expect(t.body, endsWith(consentFooter), reason: t.code);
      }
    });

    test('render replaces every placeholder and leaves none', () {
      for (final t in consentTemplates) {
        final out = t.render(_values);
        expect(out, isNot(matches(RegExp(r'\{[a-z_]+\}'))), reason: t.code);
        expect(out, contains('Ravi Kumar'));
        expect(out, contains('Registration No. A-12345'));
        expect(t.unresolvedPlaceholders(_values), isEmpty, reason: t.code);
      }
      final rct = consentTemplateByCode('RCT')!;
      expect(rct.render(_values), contains('tooth numbered 36, 37'));
      expect(
        rct.unresolvedPlaceholders({'name_of_patient': 'x'}),
        containsAll(['patient_age', 'tooth_numbers']),
      );
      expect(rct.render({'name_of_patient': 'x'}), contains('{patient_age}'));
    });

    test('ported bodies are verbatim', () {
      expect(
        consentTemplateByCode('RCT')!.body,
        startsWith(
          'I mr/ms/mrs {name_of_patient} aged {patient_age}, {patient_gender}, '
          'have been explained by the Dr. {doctor_name} about the need for Root '
          'Canal Treatment/ Therapy in relation to the tooth numbered '
          '{tooth_numbers}',
        ),
      );
      expect(
        consentTemplateByCode('JAW-FRACTURE')!.body,
        contains('the need for the surgery..'),
      );
      expect(
        consentTemplateByCode('CD')!.placeholders,
        isNot(contains('tooth_numbers')),
      );
    });

    test(
      'versionHash is a stable sha256 hex that changes with body/version',
      () {
        final rct = consentTemplateByCode('RCT')!;
        expect(rct.versionHash, matches(RegExp(r'^[0-9a-f]{64}$')));
        expect(rct.versionHash, rct.versionHash);
        expect(
          ConsentTemplate.fromJson(rct.toJson()).versionHash,
          rct.versionHash,
        );
        expect(
          rct.copyWith(version: '1.1').versionHash,
          isNot(rct.versionHash),
        );
        expect(
          rct.copyWith(body: '${rct.body} ').versionHash,
          isNot(rct.versionHash),
        );
        final hashes = consentTemplates.map((t) => t.versionHash).toSet();
        expect(hashes.length, consentTemplates.length);
      },
    );

    test('procedure mappings resolve to real catalogue codes', () {
      for (final t in consentTemplates) {
        for (final code in t.procedureCodes) {
          expect(
            procedureSeedByCode(code),
            isNotNull,
            reason: '${t.code} -> $code',
          );
        }
      }
      expect(consentTemplateFor('RCT-MOL')!.code, 'RCT');
      expect(consentTemplateFor('EXT-SIMPLE')!.code, 'EXTRACTION');
      expect(consentTemplateFor('GOODS-MOUTHWASH'), isNull);
    });
  });

  group('DataNoticeTemplate', () {
    test('DATA-PROCESSING notice renders fully and lists purposes', () {
      expect(dataNoticeTemplates.single.code, 'DATA-PROCESSING');
      final notice = dpdpDataProcessingNotice;
      expect(
        notice.purposes,
        containsAll(['treatment', 'billing', 'marketing']),
      );
      expect(notice.placeholdersInBody.toSet(), notice.placeholders.toSet());
      final out = notice.render(_values);
      expect(out, isNot(matches(RegExp(r'\{[a-z_]+\}'))));
      expect(
        out,
        contains('section 5 of the Digital Personal Data Protection Act, 2023'),
      );
      expect(out, contains('privacy@example.in'));
      expect(notice.versionHash, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(
        DataNoticeTemplate.fromJson(notice.toJson()).versionHash,
        notice.versionHash,
      );
    });
  });
}
