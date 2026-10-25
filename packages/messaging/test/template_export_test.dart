import 'dart:convert';
import 'dart:io';

import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_messaging/ampdent_messaging.dart';
import 'package:test/test.dart';

void main() {
  final export = TemplateExport.fromTemplates(
    defaultTemplates,
    generatedAt: DateTime.utc(2026, 10, 25, 12),
  );

  group('TemplateExport', () {
    test('exports every WhatsApp template and no SMS template', () {
      final whatsapp = templatesForChannel(MessageChannel.whatsapp);
      expect(export.templates, hasLength(whatsapp.length));
      expect(export.templates.map((t) => t.code), whatsapp.map((t) => t.code));
      expect(export.byCode('OTP_AUTH_SMS'), isNull);
      expect(export.byCode('OTP_AUTH'), isNotNull);
    });

    test('bodyParams equal the variables in body order, metaName is snake', () {
      for (final entry in export.templates) {
        final t = templateByCode(entry.code)!;
        expect(entry.bodyParams, t.variables, reason: entry.code);
        expect(entry.bodyParams, t.placeholdersInBody, reason: entry.code);
        expect(entry.metaName, t.code.toLowerCase());
        expect(entry.metaName, matches(RegExp(r'^[a-z0-9_]+$')));
        expect(entry.language, 'en');
        expect(
          entry.category,
          isIn(['UTILITY', 'AUTHENTICATION', 'MARKETING']),
        );
        expect(entry.body, t.body);
      }
    });

    test('contract sample: APPT_REMINDER_24H', () {
      final entry = export.byCode('APPT_REMINDER_24H')!;
      expect(entry.metaName, 'appt_reminder_24h');
      expect(entry.category, 'UTILITY');
      expect(entry.buttons, [
        {'type': 'QUICK_REPLY', 'text': '1'},
      ]);
      expect(entry.bodyParams, [
        'patient_name',
        'clinic_name',
        'appointment_date',
        'appointment_time',
        'doctor_name',
        'clinic_phone',
      ]);
      expect(
        entry.metaBody,
        'Reminder: {{1}} has an appointment at {{2}} tomorrow, {{3}} at {{4}} '
        'with Dr. {{5}}. Reply 1 to confirm, or call {{6}} to reschedule.',
      );
    });

    test('metaBody numbers every placeholder, repeats share a number', () {
      const t = MessageTemplate(
        code: 'X',
        channel: MessageChannel.whatsapp,
        category: MessageCategory.utility,
        body: '{a} and {b}, again {a}',
        variables: ['a', 'b'],
        description: '',
      );
      expect(metaNumberedBody(t), '{{1}} and {{2}}, again {{1}}');
    });

    test('rejects a template whose variables disagree with its body', () {
      const bad = MessageTemplate(
        code: 'BAD',
        channel: MessageChannel.whatsapp,
        category: MessageCategory.utility,
        body: '{a} {b}',
        variables: ['b', 'a'],
        description: '',
      );
      expect(() => TemplateExportEntry.fromTemplate(bad), throwsStateError);
    });

    test('round-trips through JSON with the contract keys', () {
      final json = jsonDecode(jsonEncode(export.toJson())) as Map;
      expect(json.keys, ['generatedAt', 'templates']);
      expect(json['generatedAt'], '2026-10-25T12:00:00.000Z');
      final first = (json['templates'] as List).first as Map;
      expect(
        first.keys,
        containsAll([
          'code',
          'metaName',
          'language',
          'category',
          'bodyParams',
          'buttons',
          'body',
        ]),
      );
      final parsed = TemplateExport.fromJson(json.cast<String, Object?>());
      expect(parsed.generatedAt, export.generatedAt);
      expect(
        parsed.templates.map((t) => t.toJson()),
        export.templates.map((t) => t.toJson()),
      );
    });

    test(
      'the committed supabase/functions/_shared/templates.json is current',
      () {
        final file = File('../../$templateExportRelativePath');
        expect(
          file.existsSync(),
          isTrue,
          reason: 'run: dart run tool/export_templates.dart',
        );
        final committed = TemplateExport.fromJson(
          (jsonDecode(file.readAsStringSync()) as Map).cast<String, Object?>(),
        );
        expect(
          committed.templates.map((t) => t.toJson()).toList(),
          export.templates.map((t) => t.toJson()).toList(),
          reason: 'templates.json is stale; run tool/export_templates.dart',
        );
      },
    );
  });
}
