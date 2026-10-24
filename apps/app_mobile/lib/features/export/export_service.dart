/// Builds and shares record exports: the DCI-mandated patient record copy
/// (PDF) plus a complete JSON bundle and the patient's image files, or the
/// whole clinic as JSON. The repository call is what writes the `export`
/// audit event; this service only renders and hands files to the share
/// sheet.
library;

import 'dart:convert';
import 'dart:io';

import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_data/ampdent_data.dart';
import 'package:ampdent_documents/ampdent_documents.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

/// One file handed to the share sheet.
@immutable
class ExportFile {
  /// Creates a file reference.
  const ExportFile({
    required this.path,
    required this.name,
    required this.mimeType,
  });

  /// Absolute path on disk.
  final String path;

  /// File name shown to the receiver.
  final String name;

  /// MIME type.
  final String mimeType;
}

/// Hands files to a share target (the system share sheet in production).
typedef ExportSharer = Future<void> Function(
  List<ExportFile> files, {
  required String subject,
  required String text,
});

/// What an export produced.
@immutable
class ExportOutcome {
  /// Creates an outcome.
  const ExportOutcome({
    required this.files,
    required this.directory,
    required this.summary,
  });

  /// Files shared, in order (PDF, JSON, then images).
  final List<ExportFile> files;

  /// Folder the generated files were written to.
  final String directory;

  /// One-line human summary, e.g. `Record PDF, JSON and 3 images`.
  final String summary;
}

/// Shares through `share_plus`.
Future<void> shareWithSharePlus(
  List<ExportFile> files, {
  required String subject,
  required String text,
}) async {
  await SharePlus.instance.share(
    ShareParams(
      files: [
        for (final f in files)
          XFile(f.path, mimeType: f.mimeType, name: f.name),
      ],
      fileNameOverrides: [for (final f in files) f.name],
      subject: subject,
      text: text,
    ),
  );
}

/// MIME type from a file extension (images only; everything else is binary).
String mimeTypeForPath(String path) {
  final ext = path.contains('.')
      ? path.substring(path.lastIndexOf('.') + 1).toLowerCase()
      : '';
  return switch (ext) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'heic' => 'image/heic',
    'pdf' => 'application/pdf',
    'json' => 'application/json',
    'txt' => 'text/plain',
    _ => 'application/octet-stream',
  };
}

/// Encodes an export bundle; anything the entities do not already turn into
/// JSON falls back to `toString`.
String encodeBundleJson(Map<String, Object?> json) =>
    const JsonEncoder.withIndent('  ', _toEncodable).convert(json);

Object? _toEncodable(Object? value) {
  if (value is Money) return value.toJson();
  if (value is DateTime) return value.toUtc().toIso8601String();
  if (value is Enum) return value.name;
  return value.toString();
}

/// Orchestrates patient and clinic exports.
class ExportService {
  /// Creates the service. [loadFonts], [outputDirectory] and [share] are
  /// injectable so tests run without a device.
  const ExportService({
    required this.export,
    required this.clinics,
    required this.loadFonts,
    required this.outputDirectory,
    required this.share,
    this.clock = DateTime.now,
  });

  /// Audited bundle source.
  final ExportRepository export;

  /// Clinic and member lookup for the letterhead.
  final ClinicRepository clinics;

  /// Loads the embedded PDF fonts.
  final Future<DocumentFonts> Function() loadFonts;

  /// Where generated files go (a temp directory in production).
  final Future<Directory> Function() outputDirectory;

  /// Share target.
  final ExportSharer share;

  /// Clock; override in tests.
  final DateTime Function() clock;

  static const Logger _log = Logger('export');

  /// Exports one patient: PDF record copy, JSON bundle and image files. The
  /// repository writes the `export` audit event for the patient.
  Future<ExportOutcome> exportPatient(
    ActorContext ctx,
    String patientId,
  ) async {
    final now = clock();
    final bundle = await export.exportPatient(ctx, patientId);
    final clinic = await clinics.getClinic(ctx.clinicId);
    if (clinic == null) throw StateError('Clinic ${ctx.clinicId} not found');
    final dentist = await clinics.getMember(ctx.actorId);
    final fonts = await loadFonts();
    final theme = DocumentTheme(fonts: fonts, generatedAt: now);
    final histories = bundle.medicalHistories.toList()
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    final pdf = PatientRecordPdf(
      clinic: clinic,
      patient: bundle.patient,
      dentist: dentist,
      toothStates: bundle.toothStates,
      findings: bundle.findings,
      procedures: bundle.procedures,
      plans: bundle.treatmentPlans,
      invoices: bundle.invoices,
      payments: bundle.payments,
      prescriptions: bundle.prescriptions,
      consents: bundle.consents,
      notes: bundle.clinicalNotes,
      perioExams: bundle.perioExams,
      medicalHistory: histories.isEmpty ? null : histories.first,
      asOf: now,
      theme: theme,
    );
    final folder = await _folder(
      'export-${_safe(bundle.patient.patientNumber)}-${_stamp(now)}',
    );
    final pdfPath = '${folder.path}${Platform.pathSeparator}record.pdf';
    await File(pdfPath).writeAsBytes(await pdf.build(), flush: true);
    final jsonPath = '${folder.path}${Platform.pathSeparator}record.json';
    await File(jsonPath)
        .writeAsString(encodeBundleJson(bundle.toJson()), flush: true);
    final files = <ExportFile>[
      ExportFile(
        path: pdfPath,
        name: pdf.suggestedFileName,
        mimeType: 'application/pdf',
      ),
      ExportFile(
        path: jsonPath,
        name: 'record-${_safe(bundle.patient.patientNumber)}.json',
        mimeType: 'application/json',
      ),
    ];
    var imageCount = 0;
    for (final image in bundle.images) {
      final file = File(image.filePath);
      if (!file.existsSync()) {
        _log.warning('image missing on disk: ${image.filePath}');
        continue;
      }
      imageCount++;
      files.add(
        ExportFile(
          path: file.path,
          name: file.uri.pathSegments.last,
          mimeType: mimeTypeForPath(file.path),
        ),
      );
    }
    final summary = imageCount == 0
        ? 'Record PDF and JSON'
        : 'Record PDF, JSON and $imageCount image${imageCount == 1 ? '' : 's'}';
    await share(
      files,
      subject: 'Patient record ${bundle.patient.patientNumber}',
      text:
          'Record copy of ${bundle.patient.displayName} '
          '(${bundle.patient.patientNumber}) from ${clinic.name}. $summary.',
    );
    return ExportOutcome(
      files: files,
      directory: folder.path,
      summary: summary,
    );
  }

  /// Exports everything the clinic holds as one JSON file.
  Future<ExportOutcome> exportClinic(ActorContext ctx) async {
    final now = clock();
    final bundle = await export.exportClinic(ctx);
    final folder = await _folder('clinic-export-${_stamp(now)}');
    final name = 'clinic-${_safe(bundle.clinic.name)}-${_stamp(now)}.json';
    final path = '${folder.path}${Platform.pathSeparator}$name';
    await File(path)
        .writeAsString(encodeBundleJson(bundle.toJson()), flush: true);
    final files = [
      ExportFile(path: path, name: name, mimeType: 'application/json'),
    ];
    final summary =
        '${bundle.patients.length} patients, ${bundle.auditEvents.length} '
        'audit events';
    await share(
      files,
      subject: 'Clinic export ${bundle.clinic.name}',
      text: 'Complete data export of ${bundle.clinic.name}: $summary.',
    );
    return ExportOutcome(
      files: files,
      directory: folder.path,
      summary: summary,
    );
  }

  Future<Directory> _folder(String name) async {
    final base = await outputDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}$name');
    await dir.create(recursive: true);
    return dir;
  }

  static String _stamp(DateTime now) {
    final l = now.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${l.year}${two(l.month)}${two(l.day)}-${two(l.hour)}${two(l.minute)}';
  }

  static String _safe(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '-');
    return cleaned.isEmpty ? 'export' : cleaned;
  }
}
