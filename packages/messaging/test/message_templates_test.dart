import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_messaging/ampdent_messaging.dart';
import 'package:test/test.dart';

/// A value for every variable any default template declares.
const Map<String, String> _allValues = {
  'patient_name': 'Ravi Kumar',
  'clinic_name': 'Oasis Dental',
  'appointment_date': 'Mon 20 Oct',
  'appointment_time': '10:30 AM',
  'doctor_name': 'Asha Rao',
  'clinic_phone': '+91 98765 43210',
  'procedure_name': 'root canal treatment',
  'link': 'https://l.ampdent.in/x/abc123',
  'document_number': 'INV-2026-0001',
  'amount': 'Rs 2,500.00',
  'payment_date': '18 Oct 2026',
  'recall_type': 'scaling',
  'due_date': '15 Apr 2027',
  'started_date': '2 Sep 2026',
  'next_step': 'crown',
  'lab_item': 'zirconia crown',
  'visit_date': '18 Oct 2026',
  'otp': '482913',
  'expiry_minutes': '10',
  'patient_number': 'P-00042',
};

/// Phrases the clinical-content guard rejects in every body.
const List<String> _forbiddenPhrases = [
  'diagnosis',
  'caries',
  'X-ray',
  'root canal findings',
];

/// Words naming a clinical finding; no body may contain them.
const List<String> _findingWords = [
  'cavity',
  'decay',
  'abscess',
  'infection',
  'fracture',
  'lesion',
  'radiograph',
  'findings',
  'gum disease',
  'periodontitis',
  'pulpitis',
  'tumour',
  'ulcer',
  'AI detects',
];

const List<String> _requiredCodes = [
  'APPT_CONFIRM',
  'APPT_REMINDER_24H',
  'APPT_REMINDER_MORNING',
  'APPT_RESCHEDULED',
  'APPT_CANCELLED',
  'POST_OP_INSTRUCTIONS',
  'POST_OP_EXTRACTION',
  'POST_OP_RCT',
  'POST_OP_SCALING',
  'POST_OP_IMPLANT',
  'POST_OP_WHITENING',
  'INVOICE_LINK',
  'RECEIPT_LINK',
  'PRESCRIPTION_LINK',
  'ESTIMATE_LINK',
  'CONSENT_LINK',
  'RECALL_DUE',
  'RECALL_OVERDUE',
  'TREATMENT_INCOMPLETE',
  'LAB_READY_SEAT_APPT',
  'REVIEW_REQUEST',
  'OTP_AUTH',
  'WELCOME_NEW_PATIENT',
];

void main() {
  group('MessageTemplate.render', () {
    final template = templateByCode('APPT_REMINDER_24H')!;

    test('fills every variable and leaves no braces behind', () {
      final text = template.render(_allValues);
      expect(text, contains('Ravi Kumar'));
      expect(text, contains('Oasis Dental'));
      expect(text, contains('10:30 AM'));
      expect(text, contains('Dr. Asha Rao'));
      expect(text, isNot(contains('{')));
      expect(text, isNot(contains('}')));
    });

    test('throws ArgumentError listing every missing key', () {
      final partial = Map<String, String>.from(_allValues)
        ..remove('doctor_name')
        ..remove('clinic_phone');
      expect(
        () => template.render(partial),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.toString(),
            'message',
            allOf(contains('doctor_name'), contains('clinic_phone')),
          ),
        ),
      );
      expect(template.missingVariables(partial), [
        'doctor_name',
        'clinic_phone',
      ]);
    });

    test('ignores extra keys', () {
      final extra = {..._allValues, 'unused': 'x'};
      expect(() => template.render(extra), returnsNormally);
    });

    test('round-trips through JSON and copyWith', () {
      final copy = MessageTemplate.fromJson(template.toJson());
      expect(copy.code, template.code);
      expect(copy.body, template.body);
      expect(copy.variables, template.variables);
      expect(copy.channel, template.channel);
      expect(copy.category, template.category);
      final hi = template.copyWith(languageCode: 'hi');
      expect(hi.languageCode, 'hi');
      expect(hi.code, template.code);
    });
  });

  group('defaultTemplates', () {
    test('contains every required code, each unique', () {
      final codes = defaultTemplates.map((t) => t.code).toList();
      expect(codes.toSet().length, codes.length);
      for (final code in _requiredCodes) {
        expect(codes, contains(code), reason: code);
      }
      for (final code in postOpTemplateCodes) {
        expect(codes, contains(code), reason: code);
      }
    });

    test('declared variables match the placeholders in each body', () {
      for (final t in defaultTemplates) {
        expect(t.placeholdersInBody, t.variables, reason: t.code);
        for (final v in t.variables) {
          expect(t.body, contains('{$v}'), reason: '${t.code}: $v');
        }
      }
    });

    test('every template renders with the shared value set', () {
      for (final t in defaultTemplates) {
        final text = t.render(_allValues);
        expect(
          text,
          isNot(contains(RegExp(r'\{[a-z0-9_]+\}'))),
          reason: t.code,
        );
      }
    });

    test('morning reminder carries the "Reply 1 to confirm" wording', () {
      expect(
        templateByCode('APPT_REMINDER_MORNING')!.body,
        contains('Reply 1 to confirm'),
      );
      expect(
        templateByCode('APPT_REMINDER_24H')!.body,
        contains('Reply 1 to confirm'),
      );
    });

    test('clinical content guard: no forbidden phrase in any body', () {
      for (final t in defaultTemplates) {
        final lower = t.body.toLowerCase();
        for (final phrase in _forbiddenPhrases) {
          expect(
            lower,
            isNot(contains(phrase.toLowerCase())),
            reason: '${t.code} contains "$phrase"',
          );
        }
      }
    });

    test('clinical content guard: no template names a clinical finding', () {
      for (final t in defaultTemplates) {
        final lower = t.body.toLowerCase();
        for (final word in _findingWords) {
          expect(
            lower,
            isNot(contains(word.toLowerCase())),
            reason: '${t.code} names a finding: "$word"',
          );
        }
      }
    });

    test('anything clinical points at a link variable', () {
      for (final code in [
        ...postOpTemplateCodes,
        'PRESCRIPTION_LINK',
        'ESTIMATE_LINK',
        'CONSENT_LINK',
        'INVOICE_LINK',
        'RECEIPT_LINK',
      ]) {
        expect(templateByCode(code)!.hasLink, isTrue, reason: code);
      }
      // Prescription never names a drug; the only clinical word allowed is
      // the procedure name, so the Rx body has none at all.
      expect(
        templateByCode('PRESCRIPTION_LINK')!.variables,
        isNot(contains('procedure_name')),
      );
    });

    test('categories and channels', () {
      expect(
        templateByCode('OTP_AUTH')!.category,
        MessageCategory.authentication,
      );
      expect(templateByCode('OTP_AUTH_SMS')!.channel, MessageChannel.sms);
      expect(templatesInCategory(MessageCategory.marketing), isEmpty);
      expect(templatesForChannel(MessageChannel.sms).map((t) => t.code), [
        'OTP_AUTH_SMS',
      ]);
      expect(
        templatesInCategory(MessageCategory.utility).length,
        defaultTemplates.length - 2,
      );
    });

    test('lookup by code and language', () {
      expect(templateByCode('APPT_CONFIRM'), isNotNull);
      expect(templateByCode('APPT_CONFIRM', languageCode: 'hi'), isNull);
      expect(templateByCode('NOPE'), isNull);
    });
  });
}
