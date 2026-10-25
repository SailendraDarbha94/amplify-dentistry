// Writes supabase/functions/_shared/templates.json from defaultTemplates.
//
//   cd packages/messaging && dart run tool/export_templates.dart [out.json]
//
// Re-run after any change to the template catalogue; template_export_test
// fails when the committed file is stale.
import 'dart:convert';
import 'dart:io';

import 'package:ampdent_messaging/ampdent_messaging.dart';

void main(List<String> args) {
  final out = args.isNotEmpty ? File(args.first) : _defaultOutput();
  final export = TemplateExport.fromTemplates(defaultTemplates);
  final json = const JsonEncoder.withIndent('  ').convert(export.toJson());
  out.parent.createSync(recursive: true);
  out.writeAsStringSync('$json\n');
  stdout.writeln('Wrote ${export.templates.length} templates to ${out.path}');
}

/// `<repo>/supabase/functions/_shared/templates.json`, resolved from this
/// script's location (`<repo>/packages/messaging/tool/`).
File _defaultOutput() {
  final script = File.fromUri(Platform.script);
  final repoRoot = script.parent.parent.parent.parent;
  return File('${repoRoot.path}/$templateExportRelativePath');
}
