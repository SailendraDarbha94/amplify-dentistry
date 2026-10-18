import 'package:meta/meta.dart';

import '../dental/tooth_id.dart';
import 'json_support.dart';

/// Kind of image or attached document.
enum ImageKind {
  photoIntraoral,
  photoExtraoral,
  periapical,
  bitewing,
  occlusal,
  opg,
  cbct,
  scan,
  document,
  other;

  /// Whether this is a radiograph (counts as a pre-op radiograph).
  bool get isRadiograph =>
      this == periapical ||
      this == bitewing ||
      this == occlusal ||
      this == opg ||
      this == cbct;
}

/// A clinical image, radiograph, scan or scanned document with its tooth
/// tags (DICOM has no standard field for which teeth an intraoral image
/// shows, so we keep our own).
@immutable
class ImageRecord {
  /// Creates an image record.
  const ImageRecord({
    required this.id,
    required this.clinicId,
    required this.patientId,
    this.visitId,
    required this.kind,
    required this.filePath,
    this.thumbnailPath,
    required this.capturedAt,
    this.teeth = const [],
    this.fmxSlot,
    this.isPreOperative = false,
    this.procedureId,
    this.note,
    this.sha256,
    this.sharingConsentId,
    required this.createdAt,
  });

  /// UUID v4.
  final String id;

  /// Owning clinic.
  final String clinicId;

  /// Patient.
  final String patientId;

  /// Visit during which it was captured.
  final String? visitId;

  /// Image kind.
  final ImageKind kind;

  /// Local path of the original file.
  final String filePath;

  /// Local path of the preview.
  final String? thumbnailPath;

  /// Capture time.
  final DateTime capturedAt;

  /// Teeth shown.
  final List<ToothId> teeth;

  /// Full-mouth-series slot label (`UR-PA-molar`), when part of an FMX.
  final String? fmxSlot;

  /// Whether this is a pre-operative image for [procedureId].
  final bool isPreOperative;

  /// Related procedure.
  final String? procedureId;

  /// Caption / note.
  final String? note;

  /// SHA-256 of the file for integrity.
  final String? sha256;

  /// `DataConsent` id covering photo use / sharing, when applicable.
  final String? sharingConsentId;

  /// Row creation time.
  final DateTime createdAt;

  /// Returns a copy with the given fields replaced.
  ImageRecord copyWith({
    String? visitId,
    ImageKind? kind,
    String? filePath,
    String? thumbnailPath,
    List<ToothId>? teeth,
    String? fmxSlot,
    bool? isPreOperative,
    String? procedureId,
    String? note,
    String? sha256,
    String? sharingConsentId,
  }) => ImageRecord(
    id: id,
    clinicId: clinicId,
    patientId: patientId,
    visitId: visitId ?? this.visitId,
    kind: kind ?? this.kind,
    filePath: filePath ?? this.filePath,
    thumbnailPath: thumbnailPath ?? this.thumbnailPath,
    capturedAt: capturedAt,
    teeth: teeth ?? this.teeth,
    fmxSlot: fmxSlot ?? this.fmxSlot,
    isPreOperative: isPreOperative ?? this.isPreOperative,
    procedureId: procedureId ?? this.procedureId,
    note: note ?? this.note,
    sha256: sha256 ?? this.sha256,
    sharingConsentId: sharingConsentId ?? this.sharingConsentId,
    createdAt: createdAt,
  );

  /// JSON form.
  Map<String, Object?> toJson() => {
    'id': id,
    'clinicId': clinicId,
    'patientId': patientId,
    'visitId': visitId,
    'kind': kind.name,
    'filePath': filePath,
    'thumbnailPath': thumbnailPath,
    'capturedAt': dateToJson(capturedAt),
    'teeth': teethToJson(teeth),
    'fmxSlot': fmxSlot,
    'isPreOperative': isPreOperative,
    'procedureId': procedureId,
    'note': note,
    'sha256': sha256,
    'sharingConsentId': sharingConsentId,
    'createdAt': dateToJson(createdAt),
  };

  /// Parses the JSON form.
  factory ImageRecord.fromJson(Map<String, Object?> json) => ImageRecord(
    id: json['id'] as String,
    clinicId: json['clinicId'] as String,
    patientId: json['patientId'] as String,
    visitId: json['visitId'] as String?,
    kind: enumFromJson(ImageKind.values, json['kind']),
    filePath: json['filePath'] as String,
    thumbnailPath: json['thumbnailPath'] as String?,
    capturedAt: dateFromJson(json['capturedAt']),
    teeth: teethFromJson(json['teeth']),
    fmxSlot: json['fmxSlot'] as String?,
    isPreOperative: json['isPreOperative'] as bool? ?? false,
    procedureId: json['procedureId'] as String?,
    note: json['note'] as String?,
    sha256: json['sha256'] as String?,
    sharingConsentId: json['sharingConsentId'] as String?,
    createdAt: dateFromJson(json['createdAt']),
  );
}
