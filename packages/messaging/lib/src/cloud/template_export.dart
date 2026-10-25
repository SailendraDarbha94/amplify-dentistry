import 'package:ampdent_core/ampdent_core.dart';

import '../templates/message_template.dart';
import 'meta_template_payload.dart';

/// Repo-relative path of the generated file the Edge Functions read.
const String templateExportRelativePath =
    'supabase/functions/_shared/templates.json';

/// [template]'s body in Meta's numbered form (`{{1}}`, `{{2}}`, ...), the
/// text pasted into Meta's template submission; numbering follows
/// `template.variables` order, so it matches `bodyParams`.
String metaNumberedBody(MessageTemplate template) {
  final index = {
    for (var i = 0; i < template.variables.length; i++)
      template.variables[i]: i + 1,
  };
  return template.body.replaceAllMapped(templatePlaceholderPattern, (m) {
    final n = index[m.group(1)!];
    return n == null ? m.group(0)! : '{{$n}}';
  });
}

/// One template as the Edge Functions see it.
class TemplateExportEntry {
  /// Creates an entry.
  const TemplateExportEntry({
    required this.code,
    required this.metaName,
    required this.language,
    required this.category,
    required this.bodyParams,
    required this.buttons,
    required this.body,
    required this.metaBody,
  });

  /// Catalogue code (`APPT_REMINDER_24H`).
  final String code;

  /// Meta template name (`appt_reminder_24h`).
  final String metaName;

  /// BCP-47 language code (`en`).
  final String language;

  /// `UTILITY` | `AUTHENTICATION` | `MARKETING`.
  final String category;

  /// Variable names in body order; the send payload maps them positionally.
  final List<String> bodyParams;

  /// Quick-reply buttons (`{type: QUICK_REPLY, text: '1'}`).
  final List<Map<String, String>> buttons;

  /// Body with `{name}` placeholders (our form).
  final String body;

  /// Body with `{{n}}` placeholders (Meta's submission form).
  final String metaBody;

  /// Builds the entry for [template]. Throws [StateError] when the declared
  /// variables and the placeholders in the body disagree, so a mismatch can
  /// never reach Meta.
  factory TemplateExportEntry.fromTemplate(MessageTemplate template) {
    final inBody = template.placeholdersInBody;
    if (inBody.join(',') != template.variables.join(',')) {
      throw StateError(
        'Template ${template.code}: variables ${template.variables} do not '
        'match body placeholders $inBody',
      );
    }
    return TemplateExportEntry(
      code: template.code,
      metaName: metaTemplateName(template.code),
      language: template.languageCode,
      category: metaCategory(template.category),
      bodyParams: List.unmodifiable(template.variables),
      buttons: metaQuickReplyButtons(template),
      body: template.body,
      metaBody: metaNumberedBody(template),
    );
  }

  /// JSON form, key order as in the contract.
  Map<String, Object?> toJson() => {
    'code': code,
    'metaName': metaName,
    'language': language,
    'category': category,
    'bodyParams': bodyParams,
    'buttons': buttons,
    'body': body,
    'metaBody': metaBody,
  };

  /// Parses the JSON form.
  factory TemplateExportEntry.fromJson(Map<String, Object?> json) =>
      TemplateExportEntry(
        code: json['code'] as String,
        metaName: json['metaName'] as String,
        language: json['language'] as String,
        category: json['category'] as String,
        bodyParams: stringListFromJson(json['bodyParams']),
        buttons: [
          for (final b in (json['buttons'] as List?) ?? const [])
            (b as Map).map((k, v) => MapEntry(k as String, v as String)),
        ],
        body: json['body'] as String,
        metaBody: json['metaBody'] as String? ?? '',
      );
}

/// The whole `templates.json` document.
class TemplateExport {
  /// Creates an export.
  const TemplateExport({required this.generatedAt, required this.templates});

  /// When the file was generated (UTC).
  final DateTime generatedAt;

  /// Entries in catalogue order.
  final List<TemplateExportEntry> templates;

  /// Builds the export for the WhatsApp templates in [templates]; SMS
  /// templates have no Meta counterpart and are left out.
  factory TemplateExport.fromTemplates(
    Iterable<MessageTemplate> templates, {
    DateTime? generatedAt,
  }) => TemplateExport(
    generatedAt: (generatedAt ?? DateTime.now()).toUtc(),
    templates: [
      for (final t in templates)
        if (t.channel == MessageChannel.whatsapp)
          TemplateExportEntry.fromTemplate(t),
    ],
  );

  /// Entry by catalogue [code], or null.
  TemplateExportEntry? byCode(String code) {
    for (final t in templates) {
      if (t.code == code) return t;
    }
    return null;
  }

  /// JSON form.
  Map<String, Object?> toJson() => {
    'generatedAt': generatedAt.toIso8601String(),
    'templates': [for (final t in templates) t.toJson()],
  };

  /// Parses the JSON form.
  factory TemplateExport.fromJson(Map<String, Object?> json) => TemplateExport(
    generatedAt: dateFromJson(json['generatedAt']),
    templates: [
      for (final t in (json['templates'] as List?) ?? const [])
        TemplateExportEntry.fromJson((t as Map).cast<String, Object?>()),
    ],
  );
}
