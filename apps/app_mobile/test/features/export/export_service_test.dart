import 'dart:convert';
import 'dart:io';

import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_documents/ampdent_documents.dart';
import 'package:ampdent_mobile/features/export/export_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'feature_harness.dart';

void main() {
  late FeatureTestEnv env;
  late Directory out;
  final shared = <(List<ExportFile>, String, String)>[];

  Future<void> fakeShare(
    List<ExportFile> files, {
    required String subject,
    required String text,
  }) async => shared.add((files, subject, text));

  ExportService service() => ExportService(
    export: env.repos.export,
    clinics: env.repos.clinics,
    loadFonts: () async => DocumentFonts.fromFiles(
      Directory('../../packages/documents/assets/fonts'),
    ),
    outputDirectory: () async => out,
    share: fakeShare,
    clock: () => DateTime(2026, 10, 25, 10, 30),
  );

  setUp(() async {
    shared.clear();
    env = await FeatureTestEnv.open(withPatient: true);
    out = await Directory.systemTemp.createTemp('ampdent-export-test');
  });
  tearDown(() async {
    await env.close();
    if (out.existsSync()) await out.delete(recursive: true);
  });

  test('patient export writes PDF + JSON, shares images and audits', () async {
    final image = File('${out.path}/iopa.png');
    await image.writeAsBytes(List<int>.generate(64, (i) => i));
    final t = DateTime.utc(2026, 10, 20);
    await env.repos.clinical.addImage(
      testCtx,
      ImageRecord(
        id: 'img-1',
        clinicId: testClinicId,
        patientId: testPatientId,
        kind: ImageKind.periapical,
        filePath: image.path,
        capturedAt: t,
        createdAt: t,
      ),
    );
    await env.repos.clinical.addImage(
      testCtx,
      ImageRecord(
        id: 'img-missing',
        clinicId: testClinicId,
        patientId: testPatientId,
        kind: ImageKind.photoIntraoral,
        filePath: '${out.path}/missing.jpg',
        capturedAt: t,
        createdAt: t,
      ),
    );

    final outcome = await service().exportPatient(testCtx, testPatientId);

    expect(outcome.files.length, 3);
    expect(outcome.files[0].mimeType, 'application/pdf');
    expect(outcome.files[1].mimeType, 'application/json');
    expect(outcome.files[2].mimeType, 'image/png');
    expect(outcome.summary, 'Record PDF, JSON and 1 image');
    final pdf = File(outcome.files[0].path);
    expect(pdf.existsSync(), isTrue);
    expect(pdf.lengthSync(), greaterThan(1000));
    expect(utf8.decode((await pdf.readAsBytes()).take(5).toList()), '%PDF-');
    final json = jsonDecode(
      await File(outcome.files[1].path).readAsString(),
    ) as Map<String, Object?>;
    expect((json['patient'] as Map)['id'], testPatientId);
    expect((json['images'] as List).length, 2);

    expect(shared.length, 1);
    expect(shared.single.$2, contains('Patient record'));
    expect(shared.single.$1.length, 3);

    final events = await env.repos.audit.forEntity(
      testClinicId,
      'Patient',
      testPatientId,
    );
    expect(events.any((e) => e.action == AuditAction.export), isTrue);
    final exportEvent = events.lastWhere((e) => e.action == AuditAction.export);
    expect(exportEvent.actorId, testDentistId);
    expect(exportEvent.deviceId, testDeviceId);
  });

  test('clinic export writes one JSON file and audits the clinic', () async {
    final outcome = await service().exportClinic(testCtx);
    expect(outcome.files.length, 1);
    expect(outcome.files.single.name, endsWith('.json'));
    final json = jsonDecode(
      await File(outcome.files.single.path).readAsString(),
    ) as Map<String, Object?>;
    expect((json['clinic'] as Map)['id'], testClinicId);
    expect((json['patients'] as List).length, 1);
    expect(outcome.summary, startsWith('1 patients'));
    final events = await env.repos.audit.forEntity(
      testClinicId,
      'Clinic',
      testClinicId,
    );
    expect(events.any((e) => e.action == AuditAction.export), isTrue);
  });

  test('mimeTypeForPath and encodeBundleJson helpers', () {
    expect(mimeTypeForPath('/a/b.JPG'), 'image/jpeg');
    expect(mimeTypeForPath('/a/b.webp'), 'image/webp');
    expect(mimeTypeForPath('/a/b'), 'application/octet-stream');
    final text = encodeBundleJson({
      'money': Money.rupees(5),
      'when': DateTime.utc(2026, 1, 1),
      'kind': ImageKind.opg,
    });
    final decoded = jsonDecode(text) as Map<String, Object?>;
    expect(decoded['money'], Money.rupees(5).toJson());
    expect(decoded['when'], '2026-01-01T00:00:00.000Z');
    expect(decoded['kind'], 'opg');
  });
}
