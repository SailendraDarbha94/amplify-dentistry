import 'dart:typed_data';

import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/features/consent/consent_model.dart';
import 'package:ampdent_mobile/features/consent/consent_service.dart';
import 'package:ampdent_terminology/ampdent_terminology.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../feature_test_env.dart';

ProcedureRecord _procedure(String id, String code, String tooth) {
  final t = DateTime.utc(2026, 10, 20);
  return ProcedureRecord(
    id: id,
    clinicId: testClinicId,
    patientId: testPatientId,
    catalogItemId: 'cat-$code',
    code: code,
    name: code,
    tooth: ToothId.parse(tooth),
    treatmentArea: TreatmentArea.tooth,
    providerId: testDentistId,
    fee: const Money.rupees(1000),
    createdAt: t,
    updatedAt: t,
  );
}

void main() {
  setUpAll(() => initializeDateFormatting('en_IN'));
  final now = DateTime.utc(2026, 10, 25, 9);
  final patient = testPatient();

  group('consentVariables', () {
    test('tooth numbers follow the clinic notation', () {
      final teeth = [ToothId.parse('36'), ToothId.parse('16')];
      final fdi = consentVariables(
        patient: patient,
        dentist: testDentist(),
        clinic: testClinic(),
        teeth: teeth,
        notation: ToothNotation.fdi,
        now: now,
      );
      expect(fdi['tooth_numbers'], '16, 36');
      final universal = consentVariables(
        patient: patient,
        dentist: testDentist(),
        clinic: testClinic(),
        teeth: teeth,
        notation: ToothNotation.universal,
        now: now,
      );
      expect(universal['tooth_numbers'], '3, 19');
      final palmer = consentVariables(
        patient: patient,
        dentist: testDentist(),
        clinic: testClinic(),
        teeth: teeth,
        notation: ToothNotation.palmer,
        now: now,
      );
      expect(palmer['tooth_numbers'], 'UR6, LL6');
      expect(fdi['doctor_name'], 'A. Rao');
      expect(fdi['registration_number'], 'A-12345');
      expect(fdi['patient_age'], '36 years');
      expect(fdi['patient_gender'], 'Female');
      expect(fdi['clinic_name'], 'Smile Dental');
    });

    test(
      'rendered RCT consent contains the tooth numbers and no placeholders',
      () {
        final template = consentTemplateFor('RCT-MOL')!;
        final values = consentVariables(
          patient: patient,
          dentist: testDentist(),
          clinic: testClinic(),
          teeth: [ToothId.parse('36')],
          notation: ToothNotation.universal,
          now: now,
        );
        final text = renderConsentText(template, values);
        expect(text, contains('tooth numbered 19'));
        expect(text, contains('Dr. A. Rao'));
        expect(text, contains('Registration No. A-12345'));
        expect(template.unresolvedPlaceholders(values), isEmpty);
        expect(text, isNot(contains('{')));
      },
    );
  });

  group('groupProceduresByTemplate', () {
    test('groups by template and falls back to the general form', () {
      final groups = groupProceduresByTemplate([
        _procedure('a', 'RCT-MOL', '36'),
        _procedure('b', 'CRN-ZIR', '36'),
        _procedure('c', 'RCT-ANT', '11'),
        _procedure('d', 'SCALING-ADULT', '11'),
      ]);
      expect(groups.map((g) => g.template.code), [
        'RCT',
        'CROWN',
        fallbackConsentTemplateCode,
      ]);
      expect(groups.first.procedureIds, ['a', 'c']);
      expect(groups.first.teeth.map((t) => t.fdi), ['11', '36']);
    });
  });

  group('validateConsentSigning', () {
    final minor = patient.copyWith(
      dateOfBirth: DateTime.utc(2016, 1, 1),
      guardianName: 'Lakshmi',
      guardianRelation: 'Mother',
      guardianPhone: '+919123456789',
    );

    test('a minor cannot self-sign', () {
      expect(
        validateConsentSigning(
          patient: minor,
          now: now,
          relation: SignerRelation.self,
          signerName: 'Kiran',
          discussionNote: 'Explained',
          hasSignature: true,
        ),
        ConsentStrings.minorCannotSelfSign,
      );
      expect(
        validateConsentSigning(
          patient: minor,
          now: now,
          relation: SignerRelation.parent,
          signerName: 'Lakshmi',
          discussionNote: 'Explained',
          hasSignature: true,
        ),
        isNull,
      );
      expect(signerRelationFromGuardian('Mother'), SignerRelation.parent);
      expect(signerRelationFromGuardian('Uncle'), SignerRelation.guardian);
    });

    test('discussion note and signature are mandatory', () {
      expect(
        validateConsentSigning(
          patient: patient,
          now: now,
          relation: SignerRelation.self,
          signerName: 'Asha',
          discussionNote: '  ',
          hasSignature: true,
        ),
        ConsentStrings.discussionNoteRequired,
      );
      expect(
        validateConsentSigning(
          patient: patient,
          now: now,
          relation: SignerRelation.self,
          signerName: 'Asha',
          discussionNote: 'Risks explained',
          hasSignature: false,
        ),
        ConsentStrings.signatureRequired,
      );
    });
  });

  test('document hash is deterministic and signature-sensitive', () {
    final a = consentDocumentHash(
      renderedText: 'text',
      teeth: [ToothId.parse('36')],
      signerName: 'Asha',
      signerRelation: SignerRelation.self,
      signedAt: now,
      signaturePng: Uint8List.fromList([1, 2, 3]),
    );
    final b = consentDocumentHash(
      renderedText: 'text',
      teeth: [ToothId.parse('36')],
      signerName: 'Asha',
      signerRelation: SignerRelation.self,
      signedAt: now,
      signaturePng: Uint8List.fromList([1, 2, 3]),
    );
    final c = consentDocumentHash(
      renderedText: 'text',
      teeth: [ToothId.parse('36')],
      signerName: 'Asha',
      signerRelation: SignerRelation.self,
      signedAt: now,
      signaturePng: Uint8List.fromList([1, 2, 4]),
    );
    expect(a, b);
    expect(a, isNot(c));
    expect(a, hasLength(64));
  });

  group('ConsentService', () {
    late FeatureTestEnv env;

    setUp(() async => env = await FeatureTestEnv.open(withPatient: true));
    tearDown(() => env.close());

    test(
      'signs and stores the record; minors need a guardian signer',
      () async {
        final store = InMemorySignatureStore();
        final service = ConsentService(
          consents: env.repos.consents,
          signatures: store,
          ctx: testCtx,
        );
        final template = consentTemplateByCode('RCT')!;
        final minor = patient.copyWith(
          dateOfBirth: DateTime.utc(2016, 1, 1),
          guardianName: 'Lakshmi',
          guardianPhone: '+919123456789',
        );
        ConsentSigning input(SignerRelation relation, String name) =>
            ConsentSigning(
              template: template,
              languageCode: 'en',
              renderedText: 'rendered',
              procedureIds: const ['proc-1'],
              teeth: [ToothId.parse('36')],
              signerName: name,
              signerRelation: relation,
              discussionNote: 'Explained risks and extraction alternative',
              readAloud: true,
              signaturePng: Uint8List.fromList([9, 9, 9]),
            );
        await expectLater(
          service.sign(
            input(SignerRelation.self, 'Kiran'),
            patient: minor,
            dentist: testDentist(),
            now: now,
          ),
          throwsStateError,
        );
        final record = await service.sign(
          input(SignerRelation.parent, 'Lakshmi'),
          patient: minor,
          dentist: testDentist(),
          now: now,
        );
        expect(record.templateVersionHash, template.versionHash);
        expect(record.dentistRegistrationNumber, 'A-12345');
        expect(record.deviceId, testDeviceId);
        expect(record.discussionNote, endsWith(ConsentStrings.readAloudMarker));
        expect(record.signatureImagePath, isNotNull);
        expect(await store.read(record.signatureImagePath!), isNotNull);
        expect(record.documentHash, hasLength(64));
        final stored = await env.repos.consents.consentsForPatient(
          testPatientId,
        );
        expect(stored.single.id, record.id);
        expect(
          await env.repos.consents.consentsForProcedure('proc-1'),
          hasLength(1),
        );
      },
    );
  });
}
