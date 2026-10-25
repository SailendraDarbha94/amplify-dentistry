import 'dart:io';
import 'dart:typed_data';

import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_data/ampdent_data.dart';
import 'package:ampdent_mobile/core/stored_file_path.dart';
import 'package:ampdent_terminology/ampdent_terminology.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'consent_model.dart';

/// Where captured signature PNGs live. The consent row stores the path; the
/// bytes never enter the database. Paths are relative to the store root
/// (`clinics/<clinicId>/patients/<patientId>/signatures/<consentId>.png`)
/// so the signature evidence survives an app-container move.
abstract class SignatureStore {
  /// Persists [png] for [consentId] of a patient and returns the stored
  /// (store-relative) path.
  Future<String> save(
    String consentId,
    Uint8List png, {
    required String clinicId,
    required String patientId,
  });

  /// Reads a stored signature, null when missing.
  Future<Uint8List?> read(String path);

  /// Store-relative path for a consent's signature.
  static String relativePath(
    String clinicId,
    String patientId,
    String consentId,
  ) => 'clinics/$clinicId/patients/$patientId/signatures/$consentId.png';
}

/// Keeps signatures in memory (tests, previews).
class InMemorySignatureStore implements SignatureStore {
  final Map<String, Uint8List> _files = {};

  @override
  Future<String> save(
    String consentId,
    Uint8List png, {
    required String clinicId,
    required String patientId,
  }) async {
    final path = SignatureStore.relativePath(clinicId, patientId, consentId);
    _files[path] = png;
    return path;
  }

  @override
  Future<Uint8List?> read(String path) async => _files[path];
}

/// Writes signatures under the app documents directory and hands out
/// store-relative paths. Absolute paths written by earlier builds
/// (`<documents>/signatures/<consentId>.png`) are still readable: they are
/// re-rooted at the current documents directory when the old container is
/// gone (see [resolveStoredFile]).
class FileSignatureStore implements SignatureStore {
  /// Creates the store; [directory] overrides the platform documents dir.
  FileSignatureStore({this.directory});

  /// Base directory; the platform documents directory when null.
  final Directory? directory;

  Future<Directory> _root() async =>
      directory ?? await getApplicationDocumentsDirectory();

  /// Absolute file for a stored path (relative or legacy absolute).
  Future<File> resolve(String path) =>
      resolveStoredFile(path, root: _root, folder: 'signatures');

  @override
  Future<String> save(
    String consentId,
    Uint8List png, {
    required String clinicId,
    required String patientId,
  }) async {
    final rel = SignatureStore.relativePath(clinicId, patientId, consentId);
    final file = await resolve(rel);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(png, flush: true);
    return rel;
  }

  @override
  Future<Uint8List?> read(String path) async {
    final file = await resolve(path);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }
}

/// Signature store for the app; overridden in tests.
final Provider<SignatureStore> signatureStoreProvider =
    Provider<SignatureStore>((ref) => FileSignatureStore());

/// Everything the dentist captured on the consent screen.
class ConsentSigning {
  /// Creates the signing input.
  const ConsentSigning({
    required this.template,
    required this.languageCode,
    required this.renderedText,
    this.procedureIds = const [],
    this.planId,
    this.teeth = const [],
    required this.signerName,
    required this.signerRelation,
    this.signerPhone,
    this.witnessName,
    required this.discussionNote,
    this.readAloud = false,
    this.signaturePng,
  });

  /// Template that was rendered.
  final ConsentTemplate template;

  /// Language the text was shown in.
  final String languageCode;

  /// Exact text shown to the signer.
  final String renderedText;

  /// Procedures covered.
  final List<String> procedureIds;

  /// Plan covered, if plan-level.
  final String? planId;

  /// Teeth named in the text.
  final List<ToothId> teeth;

  /// Signer's name.
  final String signerName;

  /// Signer's capacity.
  final SignerRelation signerRelation;

  /// Signer's phone.
  final String? signerPhone;

  /// Witness, if any.
  final String? witnessName;

  /// What the dentist explained.
  final String discussionNote;

  /// Whether the dentist read the form aloud.
  final bool readAloud;

  /// Drawn signature as PNG.
  final Uint8List? signaturePng;
}

/// Records signed procedure consents through the repository.
class ConsentService {
  /// Creates the service.
  const ConsentService({
    required this.consents,
    required this.signatures,
    required this.ctx,
  });

  /// Consent repository.
  final ConsentRepository consents;

  /// Signature image store.
  final SignatureStore signatures;

  /// Actor for writes.
  final ActorContext ctx;

  /// Validates and stores the consent. Throws [StateError] with a
  /// user-facing message when signing is not allowed (for example a minor
  /// signing for themselves).
  Future<ConsentRecord> sign(
    ConsentSigning input, {
    required Patient patient,
    required ClinicMember dentist,
    DateTime? now,
  }) async {
    final signedAt = (now ?? DateTime.now()).toUtc();
    final problem = validateConsentSigning(
      patient: patient,
      now: signedAt,
      relation: input.signerRelation,
      signerName: input.signerName,
      discussionNote: input.discussionNote,
      hasSignature: input.signaturePng != null,
    );
    if (problem != null) throw StateError(problem);
    final registration = (dentist.registrationNumber ?? '').trim();
    if (!dentist.isClinician || registration.isEmpty) {
      throw StateError(ConsentStrings.dentistRequired);
    }
    final id = newId();
    final png = input.signaturePng;
    final signaturePath = png == null
        ? null
        : await signatures.save(
            id,
            png,
            clinicId: ctx.clinicId,
            patientId: patient.id,
          );
    final note = input.readAloud
        ? '${input.discussionNote.trim()} ${ConsentStrings.readAloudMarker}'
        : input.discussionNote.trim();
    final record = ConsentRecord(
      id: id,
      clinicId: ctx.clinicId,
      patientId: patient.id,
      templateCode: input.template.code,
      templateVersionHash: input.template.versionHash,
      languageCode: input.languageCode,
      procedureIds: input.procedureIds,
      planId: input.planId,
      teeth: input.teeth,
      renderedText: input.renderedText,
      signerName: input.signerName.trim(),
      signerRelation: input.signerRelation,
      signerPhone: _blankToNull(input.signerPhone),
      signatureImagePath: signaturePath,
      signedAt: signedAt,
      dentistId: dentist.id,
      dentistRegistrationNumber: registration,
      discussionNote: note,
      witnessName: _blankToNull(input.witnessName),
      deviceId: ctx.deviceId,
      documentHash: consentDocumentHash(
        renderedText: input.renderedText,
        teeth: input.teeth,
        signerName: input.signerName.trim(),
        signerRelation: input.signerRelation,
        signedAt: signedAt,
        signaturePng: png,
      ),
      createdAt: signedAt,
    );
    return consents.recordConsent(ctx, record);
  }

  static String? _blankToNull(String? value) {
    final v = (value ?? '').trim();
    return v.isEmpty ? null : v;
  }
}
