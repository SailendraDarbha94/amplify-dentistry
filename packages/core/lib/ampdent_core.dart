/// Pure-Dart domain model for the AmpDent dental platform.
///
/// FDI (ISO 3950) tooth identity is canonical; surfaces are canonical faces;
/// money is integer paise; clinical rows are append-only. No Flutter imports.
library;

export 'src/dental/clinical_enums.dart';
export 'src/dental/dentition.dart';
export 'src/dental/notation.dart';
export 'src/dental/perio.dart';
export 'src/dental/surfaces.dart';
export 'src/dental/tooth_id.dart';
export 'src/entities/entities.dart';
export 'src/money/money.dart';
export 'src/util/ids.dart';
export 'src/util/logger.dart';
