/// Seed vocabularies for the AmpDent dental platform: Indian procedure
/// catalogue, ICD-10 K00-K14, dental drug master with schedules, consent
/// templates, recall rules, BDS case-sheet structure and GST state defaults.
///
/// Everything here is const-friendly seed data; the data layer maps it into
/// tables on first launch. Nothing in this package is a core entity.
library;

export 'src/allergy_substances.dart';
export 'src/case_sheet.dart';
export 'src/consent_templates.dart';
export 'src/drug_master.dart';
export 'src/gst_defaults.dart';
export 'src/icd10_oral.dart';
export 'src/procedure_catalogue.dart';
export 'src/recall_rules.dart';
