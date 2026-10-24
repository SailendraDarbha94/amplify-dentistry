# ampdent_terminology

Seed vocabularies for the AmpDent dental platform (pure Dart, depends only on
`ampdent_core`):

- `indianProcedureCatalogue`: 153 Indian dental procedures with fee ranges in
  paise, GST class, SAC/HSN, stages, recall interval and consent template.
- `icd10OralCodes`: WHO ICD-10 (2019) block K00-K14 with 4-character subcodes.
- `dentalDrugMaster`: dental drug master with Drugs and Cosmetics Rules
  schedule tags and schedule history (`scheduleAt`).
- `consentTemplates`, `dataNoticeTemplates`: procedure consent and DPDP notice
  templates with `{placeholder}` rendering and a stable `versionHash`.
- `defaultRecallRules`: procedure-triggered recall defaults.
- `caseSheetSections`, `medicalHistoryQuestions`: BDS case-sheet structure.
- `gstStateCodes`, `gstRegistrationThresholdRupees`: GST state table.

The data layer maps these seeds into tables on first launch; the seeds are
never mutated at runtime.
