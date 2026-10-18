# Architecture and data model

The Flutter decision, reference architecture, offline-first sync, canonical tooth and clinical model, standards alignment, integrations, costs at scale, and repo layout.

> Part of the [dental practice-management research](README.md) (October 2026). Verification tags: `[confirmed]` passed two independent fact-checks, `[corrected]` text already incorporates the checker's correction, `[disputed]` two checkers disagreed, `[unverified]`/`[gap-fill-unverified]` nobody checked. Numbers carry inline source URLs. The editor's cross-section fixes have been applied; strategic decisions are listed in the [executive summary](00-executive-summary.md).

## Stack decision

### What actually decides it

The founder's muscle memory is Expo, Next.js, NestJS and Supabase, so React Native deserves a fair hearing. The deciding factor is not the CRUD screens but four canvas-heavy, touch-dense surfaces that must work on a cheap Android phone and a 10-inch tablet: a 32-tooth odontogram with per-surface hit-testing and mixed dentition, a six-site perio grid with auto-advance, a radiograph viewer with annotation, and signature capture. Clove Dental's CIO evaluated 10+ EMRs, found none "truly dental", and built an in-house EMR with large touch buttons and minimal typing (https://www.ciol.com/cxo-of-the-week-vikas-sood-cio-clove-dental/); that is the bar.

### Flutter vs Expo/React Native, honestly

| Dimension | Flutter 3.47 (12 Aug 2026) | Expo SDK 57 / React Native 0.86 | Edge |
|---|---|---|---|
| Rendering | Impeller is the only renderer on iOS, default on Android API 29+ and, from 3.47, on macOS, Windows and Linux (https://docs.flutter.dev/perf/impeller) | Skia v3 (Graphite) was first tagged 2 Oct 2026 on a fork; the official package was still 2.14.x in early Oct 2026 with open Android Vulkan crashes (https://github.com/Shopify/react-native-skia); SDK 57 shipped 30 Jun 2026 (https://expo.dev/changelog/sdk-57) | Flutter |
| Canvas ergonomics | CustomPainter with built-in hit-testing and Semantics | One production write-up reports Mali GPU stalls and canvas content invisible to screen readers (https://dev.to/techamit95ch/the-hidden-performance-ceiling-of-react-native-skia-in-production-2nfk); a single un-benchmarked account, tagged [disputed] | Flutter, weakly |
| Web | CanvasKit; `--wasm` only on Chromium 119+, never on iOS browsers (https://docs.flutter.dev/platform-integration/web/wasm) | React DOM plus Next.js, already known | React Native |
| PDF, print, signature | `pdf` 3.13.1 (3.04k likes, 1.73M downloads), `printing` 5.15.1 (1.81k likes), `signature` 6.4.0 (663 likes), all free (https://pub.dev/packages/pdf, https://pub.dev/packages/printing, https://pub.dev/packages/signature) | Thinner equivalents | Flutter |
| Dental widgets | None usable: `teeth_selector` 0.2.2 (7 likes, ~21 months stale) and `dental_teeth_selector` 0.1.1 (10 likes) pick whole teeth only (https://pub.dev/packages/dental_teeth_selector) | `react-advanced-odontogram` (MIT: FDI/Universal/Palmer, six-site perio, ICDAS, FHIR export) exists (https://github.com/ZoliQua/React-Advanced-Odontogram) | React, on paper |
| Hiring and founder velocity | Mid-2025 US LinkedIn: ~1,068 Flutter vs ~6,413 React Native postings, no verified Indian split (https://devnewsletter.com/p/state-of-flutter-2026/) [disputed, US-only]; founder must learn Dart | Larger pool; productive on day one | React Native |
| Project health | Flutter 3.44 had 972 commits from 178 contributors and 1.5M+ monthly developers, +50% YoY (https://devnewsletter.com/p/state-of-flutter-2026/) | Meta-backed, Expo well funded | Tie |

Verdict: Flutter. The surfaces that make this product "dental" rather than "clinic" are exactly where Flutter's single rendering pipeline, free document stack and desktop builds remove risk, and Expo would mean betting the core screens on a Skia release that is weeks old. The honest price is a slower first month, a weaker web renderer and a smaller Indian hiring pool; spend the Expo, NestJS and Supabase knowledge on the service layer and the public website.

### The best path under Flutter

- Pin Flutter 3.47 / Dart 3.13 and start on `package:material_ui` (1.0 shipped with 3.47; in-framework Material was frozen in 3.44), running `dart fix --apply --code=migrate_design_widgets` from the first commit (https://docs.flutter.dev/release/breaking-changes).
- Build the odontogram, perio grid and image annotation as one pure-Dart engine on `dart:ui` Canvas with precomputed `Path` objects and bounding-box hit tests, no Material dependency, so it survives framework churn (https://pub.dev/packages?q=odontogram returns nothing today). Decision (recommended): open-source only the tooth geometry and FDI/Universal/Palmer notation layer as a small `tooth_geometry` package; keep surfaces, conditions, perio, history and sync in the proprietary `chart_engine`, because the surface-level odontogram is the one thing competitors cannot pull from a package.
- Design adaptive from day one: Android 16 (targetSdk 36) ignores orientation and resizability restrictions on sw>=600dp displays (https://developer.android.com/about/versions/16/behavior-changes-16); use NavigationRail and a two-pane chart/notes layout on tablets (https://docs.flutter.dev/ui/adaptive-responsive/large-screens).
- The front-desk surface (`app_desk`, Flutter web on CanvasKit plus a Windows build) is a v2 decision gated on a two-week spike of the schedule and ledger on a real clinic PC; until then keep only the Windows capture-bridge agent in services/, and let Next.js host the public site and patient link pages.

## Reference architecture

### Surfaces and services

One Flutter target on day one, `app_mobile` (the dentist's phone: chart, note, prescribe, bill, next visit); a second, `app_desk` (Flutter web plus Windows for reception and billing), is v2 and gated on the CanvasKit spike, sharing the same chart and document engine. Around them: Supabase Postgres in Mumbai as the system of record, PowerSync for offline replication, Supabase Storage for images, a small NestJS service for WhatsApp webhooks, payment callbacks and ABDM, a Windows capture-bridge agent for TWAIN sensors, and a Next.js site; any voice-notes worker runs on the Claude API under its BAA (https://privacy.claude.com/en/articles/8114513-business-associate-agreements-baa-for-commercial-customers).

### Backend choice and alternatives

Supabase has a Mumbai region (ap-south-1), AES-256 at rest, SOC 2 Type 2 and a HIPAA BAA on Team and Enterprise; Pro is $25/month with 100k MAU, 8 GB database, 100 GB storage and 250 GB egress, compute add-ons run from Small $15 to 2XL $410, and PITR costs $100 per 7 days (https://supabase.com/pricing, https://supabase.com/docs/guides/platform/regions). PowerSync reads Postgres through logical replication, defines per-tenant Sync Streams keyed on `clinic_id`, queues writes locally and replays them through the Supabase client so RLS gates every write; Free covers 50 peak clients, Pro from $49 covers 1,000 peak clients and 30 GB synced, Team from $599 adds HIPAA and SOC 2 (https://docs.powersync.com/integration-guides/supabase-+-powersync, https://powersync.com/pricing). Mumbai hosting is also what the approved ABDM Health Data Management Policy requires ("No personal data shall be stored beyond the geographical boundaries of India"; the 2022 revision reported at https://www.medianama.com/2022/06/223-new-health-data-management-policy/ was a draft), and in practice NHA requires India-hosted callback servers (unverified).

| Alternative | Why it loses here |
|---|---|
| NestJS + Prisma on your own Postgres | Rebuilds Auth, Storage, RLS tooling and PowerSync's Supabase shortcuts; keep NestJS for the service layer only |
| Firebase | Firebase Authentication, FCM and Crashlytics are absent from Google's HIPAA covered-products list, which names Firestore, Cloud Storage and Identity Platform (https://docs.cloud.google.com/docs/security/compliance/hipaa); phone OTP to India is $0.07 per SMS, about ₹6 (https://firebase.google.com/pricing); security rules are not filters and cap embedded reads at 10 per single-document request (https://firebase.google.com/docs/firestore/pricing) |
| Serverpod 4.0.4 | SSPL-1.0 licence, quote-only cloud, no managed RLS, Storage or Auth (https://pub.dev/packages/serverpod) [unverified] |
| Isar, Realm, ElectricSQL | Isar last pushed 14 Jun 2025; Atlas Device Sync hit end-of-life 30 Sep 2025; ElectricSQL has no official Dart client (https://github.com/isar/isar) |

### Multi-tenancy: shared schema, clinic_id, RLS

One schema, `clinic_id` on every tenant row, RLS for isolation; schema-per-tenant does not scale to thousands of clinics and breaks PowerSync publications. Follow Supabase's rules exactly: index every column a policy filters on, wrap auth calls as `(select auth.uid())`, scope policies `to authenticated`, and move membership lookups into `security definer` functions; an unindexed RLS filter runs at 171 ms against 0.046 ms indexed (https://supabase.com/docs/guides/database/postgres/row-level-security-performance). Put clinic and role into `app_metadata` through a custom access-token hook; the research's sources disagree on whether claims or a membership table should be authoritative, so use a `clinic_members(user_id, clinic_id, role)` table checked in RLS with the claim as a cache (https://supabase.com/docs/guides/database/postgres/row-level-security). Roles: owner-dentist, associate dentist, visiting specialist (procedure-scoped, with a fee-share percentage), receptionist, accountant (ledger only), lab (case-scoped). Every clinic carries a `region` attribute for later UK, EU and GCC pinning; Supabase has no Middle East region today (https://supabase.com/docs/guides/platform/regions).

### Auth and phone OTP in India

Supabase Auth with the Send-SMS hook routed to MSG91: ₹0.25 per OTP at 5,000, ₹0.22 at 15,000, ₹0.20 at 27,000, ₹0.19 at ~54k-400k and ₹0.18 at ~855k, plus 18% GST (https://msg91.com/in/pricing/otp). Twilio costs $0.0832 per segment to India plus $0.05 per Verify success, about ₹11 per OTP (https://www.twilio.com/en-us/verify/pricing); Firebase is $0.07, about ₹6 (https://firebase.google.com/pricing). A WhatsApp authentication template is ₹0.115 (https://developers.facebook.com/docs/whatsapp/pricing), so default staff login to WhatsApp OTP with SMS fallback. OTP SMS needs DLT registration at ₹5,900 all-in (https://www.messagecentral.com/blog/a-complete-guide-on-dlt-registration), so start that paperwork before the first build.

### Audit log and immutability

Clinical rows are append-only: procedures change status and never disappear (Open Dental: a procedure "can NEVER be deleted", https://www.opendental.com/OpenDentalDocumentation26-1.xml), and notes are versioned. A Postgres trigger writes every insert, update and delete into `audit_event` with actor, clinic, table, row id, before/after JSON, device and server timestamp, which is what India's EHR Standards 2016 describe (ISO 27789 entries with date, time, record ID and user ID; "As-Is" immutability with versioning, https://www.nrces.in/download/files/pdf/nrces_ehr_stand_india.pdf); the standards are [disputed] because they are recommended rather than mandatory, but WASA auditors read from them, and NABH's dental standard wants every entry signed, dated and timed within one hour (https://nabh-portal-live.s3.ap-south-1.amazonaws.com/wp-content/uploads/2025/07/13105241/Final-Dental-Standard-3rd-Edition.pdf) [gap-fill, unverified]. CERT-In requires 180 days of logs in Indian jurisdiction and 6-hour incident reporting (https://www.cert-in.org.in/PDF/CERT-In_Directions_70B_28.04.2022.pdf); DPDP Rule 8(3) requires one year and Rule 7 a breach report within 72 hours, in force from 13 May 2027 (https://www.dpdpa.com/DPDP_Rules_2025_English_only.pdf).

### Files, images, encryption

Originals live in Supabase Storage under `clinic_id/patient_id/` behind signed URLs, with previews from `flutter_image_compress` 2.5.1 (https://pub.dev/packages/flutter_image_compress). The phone camera is the primary imaging device for a 1-3 chair clinic; RVG sensors are captured through vendor TWAIN drivers on Windows (https://www.carestreamdental.com/en-in/discover/intraoral/intraoral-sensors/rvg-142/), so a thin Windows agent watches the export folder and uploads DICOM or JPEG. `dicom_viewer` 0.6.0 (pure Dart) decodes Explicit VR LE, RLE and JPEG Baseline but throws on JPEG 2000 and JPEG-LS (https://pub.dev/packages/dicom_viewer), so keep a server-side transcode. DICOM has no standard way to record which teeth an intraoral image shows (https://wiki.ihe.net/index.php/Display_Mapping_and_Viewing_Solution_for_Intraoral_Radiography), so store your own `image_tooth_tags` (FDI list, view type, FMX slot). Encryption: AES-256 at rest and TLS on Supabase (https://supabase.com/security), field-level encryption for Aadhaar-derived and ABHA identifiers, and an on-device SQLCipher spike (compatibility with PowerSync's SQLite extension is unverified).

### PDF, printing, signature

Invoices, prescriptions, estimates, lab slips and consent forms are generated on-device with `pdf` 3.13.1 and printed or shared with `printing` 5.15.1 (https://pub.dev/packages/printing), with Noto fonts following the language table: English, Hindi and Telugu at launch; Kannada, Malayalam and Tamil at months 7-9; Assamese only when an Assam or Arunachal clinic asks. A prescription must carry the dentist's usual signature and date, patient name and address, total quantity and dose (Rule 65(10)) and a repeat flag defaulting to "not to be repeated" (Rule 65(11)) (https://cdsco.gov.in/opencms/export/sites/CDSCO_WEB/Pdf-documents/acts_rules/2016DrugsandCosmeticsAct1940Rules1945.pdf), plus the State Dental Council registration number and degrees on the letterhead (Code 3.4.1, 5.7.2) and generic names (Code 3.5) (https://dciindia.gov.in/Rule_Regulation/Gazette_Notification_reg_DCI_Revised_Dentists_Code_of_Ethics_Regulations_2014_27.06.2014.pdf). `signature` 6.4.0 exports PNG bytes and raw points (https://pub.dev/packages/signature); store the strokes, a SHA-256 of the rendered PDF, template version, timestamp, device id and OTP-verified phone. A drawn signature is enforceable under IT Act s.10A but is not a Second-Schedule electronic signature; offer Aadhaar eSign (s.3A) for implants and surgical cases (https://www.leegality.com/blog/what-is-esign) [disputed on detail; get a legal opinion before marketing "legally valid e-signatures"].

### Push

FCM is no-cost on both Firebase plans and reaches iOS through APNs; use the HTTP v1 API, since the legacy APIs were shut down in 2024 (https://firebase.google.com/pricing). Payloads carry an opaque record id only, never names or clinical text.

### Offline-first sync and conflict policy

Drift is the on-device store, PowerSync replicates per-clinic slices, and Hive CE 2.20.2 holds only settings (https://pub.dev/packages/hive_ce). Every row has a client-generated UUID, `clinic_id`, a server-assigned `updated_at` and a `device_id`. Conflict policy is per entity:

| Entity | Policy | Why |
|---|---|---|
| Patient demographics, appointment notes | Last-writer-wins per column by server `updated_at` | Low stakes |
| Appointment slots | Server-side exclusion constraint on (chair, time range); the loser is notified and dropped to the waitlist | Double-booking needs one authority |
| Procedures, findings, tooth state | Append-only with status transitions; duplicates from two devices are merged in the UI | History must never vanish silently |
| Perio measurements | Keyed by (exam, tooth, site, type); later server timestamp wins per cell | Cell granularity makes overwrite harmless |
| Saved or signed treatment plan | Immutable snapshot with hash-bound signature | The signed estimate is the legal record |
| Invoices, receipts, ledger | Offline drafts with client UUIDs; invoice number and ledger posting minted server-side on first sync; payments are append-only events | GST-compliant sequential numbering cannot be minted offline |

Sync Streams must mirror the RLS predicate exactly; each device syncs only its clinic's active patients and the current fortnight's schedule, and images sync as metadata with lazy download.

## Canonical data model

### Entity map

Clinic, Branch, ClinicMember (role, fee-share), Patient (ABHA number and address, guardian link, nominee, preferred language), Visit, ToothSlot with ToothState history, Finding, Procedure, ProcedureCatalog, FeeSchedule, TreatmentPlan and TreatmentPlanLine (frozen on save), Estimate, ConsentRecord, DataConsent, AbdmConsentArtefact, PerioExam and PerioMeasurement, MedicalHistory (structured risk fields), Prescription and PrescriptionLine, DrugMaster (schedule history), Image and ImageToothTag, LabCase, ImplantRecord, Invoice, InvoiceLine, Payment, LedgerEntry, Adjustment, Recall, Message (WhatsApp/SMS log with delivery status), SterilisationCycle, BmwRegister, Licence, AuditEvent.

### Teeth, surfaces, dentition

Store teeth as ISO 3950 / FDI two-digit codes (11-48 permanent; 51-55, 61-65, 71-75, 81-85 primary), the notation Indian schools and WHO use, and render Universal (1-32, A-T) and Palmer through pure conversion functions as a per-clinic and per-user preference (https://en.wikipedia.org/wiki/Dental_notation). FDI defines no supernumerary code, so adopt a documented convention (base FDI plus index) and map on output to Universal 51-82 and AS-TS as Open Dental stores them, and to SNODENT supernumerary concepts (https://www.opendental.com/OpenDentalDocumentation26-1.xml, https://hl7.org/fhir/us/dental-data-exchange/ValueSet-tooth-identification-valueset.html). Model each arch position as a slot that can hold a primary and a permanent tooth at once, each with an eruption state (unerupted, erupting, erupted, exfoliated, missing, retained, impacted, implant, supernumerary), defaulted from date of birth as Carestream Sensei Cloud does (primary 0-6, mixed from about 6.5-11, permanent 11+, third molars 12-19) with override (https://help.carestreamdental.com/rh/web/server/Sensei_Cloud/projects_responsive/CM300_SCWorkbook/Charting_Mixed_Dentition.htm). Surfaces are a fixed enum: M, D, O or I, B or F, L or P, plus V for class V lesions (collapsed into B/F on claim export, as Open Dental does), ROOT and WHOLE; the treatment-area enum mirrors Open Dental's (Surf, Tooth, Mouth, Quad, Sextant, Arch, ToothRange) (https://opendental.com/Manual/entertreatment.html).

### Findings, procedures and the catalogue

A Finding is per tooth or surface, coded SNOMED CT with ICD-10 K00-K14 alongside (https://icd.who.int/browse10/2019/en#/K00-K14) and ICDAS 0-6 severity for caries (https://www.iccms-web.com/content/icdas). A Procedure row carries clinic, patient, provider, catalogue code, tooth, surfaces, treatment area, phase, fee, discount, status and dates, with Open Dental's lifecycle: TP=1, Complete=2, ExistingCurProv=3, ExistingOtherProv=4, Referred=5, Deleted=6, Condition=7, TPinactive=8, Deleted being a status and never a row deletion (https://www.opendental.com/OpenDentalDocumentation26-1.xml). The ProcedureCatalog is clinic-owned, pre-seeded by city tier with editable ranges (metro RCT ₹3,500-7,000, smaller towns ₹2,000-4,500, https://clovedental.in/blog/filling-root-canal/cost-of-root-canal-treatment-india); each code carries treatment area, paint type, a layman term for estimates, default diagnoses, a `gst_class`, a recall trigger, multi-sitting stages (RCT 1/2/3) and an `external_codes` map in which CDT appears only for licensed US tenants. Recall is procedure-triggered as in Open Dental's recalltype/recalltrigger model, with NICE CG19's 3-24 month menu as the interval picker (https://www.nice.org.uk/guidance/CG19/chapter/recommendations).

### Periodontal measurements

PerioExam plus PerioMeasurement rows keyed by (exam, tooth, site, type): six sites (MB, B, DB, ML, L, DL), types probing depth, gingival margin, bleeding, suppuration, plaque, calculus, furcation (stored 0-3, displayed per clinic as Glickman I-IV) and MGJ, and one mobility value per tooth. Store gingival margin as a signed integer rather than Open Dental's encoding in which 105 means -5 mm and -1 means not measured (https://www.opendental.com/OpenDentalDocumentation24-1.xml); CAL and bleeding percentages are derived, never stored. A screening layer records BSP BPE codes 0-4 and * per sextant, unlocks six-point charting for code 3 and 4 sextants and blocks BPE on implants (https://www.bsperio.org.uk/assets/downloads/BSP_BPE_Guidelines_2019.pdf). The 2017 AAP/EFP stage and grade are clinician-entered with a suggested value, since they also need radiographic bone loss, tooth loss, smoking and HbA1c (https://www.perio.org/wp-content/uploads/2019/08/Staging-and-Grading-Periodontitis.pdf).

### Treatment plans, estimates, consent

One Active plan per patient, any number of Inactive alternatives (RCT plus crown versus extraction plus implant), and Saved plans that freeze every line's description, tooth, fee and patient amount, with a signature hash-bound to the concatenation of plan note, date and each line's description and amount (https://www.opendental.com/manual/treatmentplan.html). Phases use clinic-defined priorities with subtotals; the India model replaces insurance columns with patient portion, discount, instalment schedule and an optional third-party payer. Because the DCI Code requires a written estimate before treatment and a justification for any increase (Reg 5.7.1, https://dciindia.gov.in/Rule_Regulation/Gazette_Notification_reg_DCI_Revised_Dentists_Code_of_Ethics_Regulations_2014_27.06.2014.pdf), Estimate is a first-class versioned object. Three consent tables, never one: ConsentRecord for procedures (template version hash, merged tooth numbers, risks and alternatives as shown, signer identity and relationship, guardian for under-18s, dentist registration number, discussion note, signature artefact); DataConsent per DPDP purpose (notice version, language, channel, withdrawal timestamp); AbdmConsentArtefact (purpose, HI types, date range, expiry, status). Consumer fora have punished missing written consent and missing pre-operative radiographs, from the NCDRC's ₹5 lakh award in Sravani Dental to a Maharashtra SCDRC award of ₹4,32,208 plus ₹2 lakh against Sabka Dentist on 7 Aug 2026 (https://indiankanoon.org/doc/29669611/, https://indiankanoon.org/doc/82459637/) [gap-fill, unverified], so block "start RCT" without an attached IOPA/OPG or a documented reason.

### Invoices, payments, ledger

A double-entry patient and family ledger. Invoice type follows GST registration, printing "Invoice-cum-Bill of Supply" under Rule 46A when exempt and taxable lines mix; InvoiceLine carries SAC/HSN and a `gst_class` of EXEMPT (health care, SAC 999312), COSMETIC_5_NO_ITC or COSMETIC_18 (whitening and smile-design veneers; the rate after the 22 Sep 2025 move of group 99972 to 5% without ITC is unsettled, so it is a per-clinic setting with a rate-history table) or GOODS_5 (HSN 9021 devices sold over the counter) (https://gstcouncil.gov.in/sites/default/files/2025-09/faq.pdf, https://www.taxmann.com/post/blog/no-gst-on-providing-dental-health-care-services-by-dental-clinic-aar/). Payment is an append-only event with method, gateway token, last four digits and brand only, never a PAN, since the card-on-file ban has applied since 1 Oct 2022 (RBI's card-on-file tokenisation framework (circular RBI/2021-22/96 of 7 Sep 2021, deadline extended to 1 Oct 2022 by RBI/2022-23/77; https://www.rbi.org.in/Scripts/BS_CircularIndexDisplay.aspx)); Adjustment is typed (discount, write-off, refund, visiting-specialist share); LedgerEntry posts per responsible party with aging buckets. Receipts print the registration number (Code 3.4.1); invoice numbers are a server-side sequence per clinic per financial year.

### Audit, retention, erasure

Each record type carries a retention class and a legal-hold flag. The DCI floor is three years from commencement of treatment with copies within 72 hours (Reg 3.3.1-3.3.2, https://dciindia.gov.in/Rule_Regulation/Gazette_Notification_reg_DCI_Revised_Dentists_Code_of_Ethics_Regulations_2014_27.06.2014.pdf); given the 7-8 year gaps between treatment and judgment in the cases above, default to 10 years from last visit for adults, age 28 for minors and device lifetime for implants, with an "inactive" state rather than deletion. DPDP erasure requests under s.8(7) are honoured for marketing data and refused for clinical records while a legal-retention basis applies, with the basis logged (https://prsindia.org/files/bills_acts/acts_parliament/2023/Digital_Personal_Data_Protection_Act,_2023.pdf).

### Standards alignment

| Standard | How the model maps | Licence |
|---|---|---|
| FHIR R4 4.0.1, ABDM (NRCeS IG v6.5.0) | Visit to OPConsultRecord (type SNOMED 371530004; sections Chief complaints 422843007, Physical examination 425044008, Allergies 722446000, Medical history 371529009, Investigation advice 721963009, Medications 721912009, Follow up 390906007, Procedure 371525003); Rx to PrescriptionRecord; bill to InvoiceRecord; no dental profile exists, so a tooth is a SNOMED bodySite on Condition and Procedure (https://nrces.in/ndhm/fhir/r4/StructureDefinition-OPConsultRecord.html) | Free |
| HL7 US Dental Data Exchange IG STU1 v1.0.0 (2021-11-02; a 2.0.0-ballot CI build adds a Dental Procedure profile) | Finding to Dental Finding (Observation, LOINC code, SNODENT/SNOMED value, single bodySite); the Tooth Identification value set holds 207 concepts, 104 SNODENT plus 103 SNOMED (https://hl7.org/fhir/us/dental-data-exchange/) | Free, US-only |
| SNOMED CT | Findings, procedures, teeth, surfaces; adopt the Odontogram refset (MLDS 173263) and General Dentistry Diagnostic refset (133814), July-2026 editions (https://mlds.ihtsdotools.org/api/releasePackages/173263) | Free in India under an NRCeS affiliate licence (access in 4-5 business days, per-deployment sub-licences, annual usage report); International Affiliate Licence once any non-India user exists (https://www.nrces.in/faqs) [gap-fill, unverified] |
| SNODENT | Secondary code for US tenants; 7,000+ terms (https://www.ada.org/resources/practice/dental-standards/snodent) | No-cost ADA licence |
| CDT | `external_codes.cdt` for US tenants only; CDT 2027 carries 67 changes | ADA commercial licence, royalties unpublished, 2-4 weeks to process (https://www.ada.org/publications/ada-store-products/licensing-for-commercial-users) |
| ICD-10 K00-K14 and ICD-10-CM | Diagnosis picker; WHO edition for India and ABDM, CM for US (https://icd.who.int/browse10/2019/en#/K00-K14) | Free |
| DICOM | Modality IO and PX; Digital Intra-Oral X-Ray Image Storage 1.2.840.10008.5.1.4.1.1.1.3, CT Image Storage 1.2.840.10008.5.1.4.1.1.2 for CBCT, VL Photographic 1.2.840.10008.5.1.4.1.1.77.1.4 for photos, Encapsulated STL 1.2.840.10008.5.1.4.1.1.104.3 for scans; exposed through FHIR ImagingStudy (https://dicom.nema.org/medical/dicom/current/output/chtml/part04/sect_B.5.html) | Free |

### What to borrow from Open Dental, and what the licences allow

Open Dental moved from GPL to a proprietary licence at version 24.4 (20 Mar 2025), but its GPL-2.0 source for 21.1 through 24.3 stays published (latest commit "version 24.3.63.0", 1 Apr 2025) and its schema documentation stays public: 24.1 has 402 tables and 4,161 columns, 26.2 has 430 tables (https://www.opendental.com/site/license.html, https://www.opendental.com/site/sourcecode.html, https://www.opendental.com/OpenDentalDocumentation26-1.xml). GPL is viral, so no code may be copied into a proprietary SaaS; schema documentation describes facts, so modelling after it is low-risk.

| Borrow as design | Leave behind |
|---|---|
| The procedure status lifecycle and never-delete rule; `toothinitial`'s separation of tooth state from procedures; `procedurecode` fields PaintType, TreatArea, LaymanTerm and DiagnosticCodes; Saved/Active/Inactive plans with frozen copies and hash-bound signatures; `recalltype`/`recalltrigger`; lab-case due dates computed from each lab's turnaround skipping weekends and holidays (https://www.opendental.com/manual/labcaseedit.html) | Universal storage of ToothNum with FDI as display-only; the overloaded `Surf` string holding surfaces, quadrants and arches; `periomeasure`'s 100-plus negative encoding; the US insurance tables; CDT descriptors, since "It is a violation of the copyright to share CDT codes with another office" (https://www.opendental.com/manual/procedurecodes.html) |

Elsewhere: `react-advanced-odontogram` (MIT, 78 stars, procedurally generated tooth SVGs) is safe to port into Dart with the MIT notice kept (https://github.com/ZoliQua/React-Advanced-Odontogram); DentalPin's BSL 1.1 forbids a competing clinic SaaS built on it, but its 59-module catalogue is a free India feature checklist (https://github.com/dentalpin/dentalpin); Clear.Dental is GPLv3 and off-limits for code (https://clear.dental/).

## Integrations

### WhatsApp

Build on Meta's Cloud API directly (one WABA number per clinic) or through Gupshup, which adds only $0.001 per message with no monthly fee (https://www.gupshup.ai/pricing); never resell a BSP seat plan. Meta's India rates are ₹0.1150 per utility or authentication template, ₹0.8631 per marketing template (raised 1 Jan 2026) and ₹2.4971 for authentication-international, billed per delivered message since 1 Jul 2025, plus 18% GST; INR billing began 1 Jan 2026 and non-INR Indian WABAs stop delivering from 1 Jan 2027 (https://developers.facebook.com/docs/whatsapp/pricing). The research is split on the 1 Oct 2026 change: BSPs report in-window service replies now cost ₹0.115 beyond 1,000 free per number per month, while Meta's page still shows them free [disputed]; budget as if the BSPs are right. Confirmations, reminders, post-op instructions, invoices and recall are utility templates; promotions are marketing.

| Provider | Monthly fee | Marketing | Utility | Source |
|---|---|---|---|---|
| Meta Cloud API direct | ₹0 | ₹0.8631 | ₹0.1150 | https://developers.facebook.com/docs/whatsapp/pricing |
| Gupshup | ₹0 | Meta + $0.001 | Meta + $0.001 | https://www.gupshup.ai/pricing |
| Interakt | ₹2,799 / ₹3,799 | ₹0.958 / ₹0.949 | ₹0.150 / ₹0.140 | https://www.interakt.shop/pricing/ |
| AiSensy | from ~₹1,500 | ₹1.09 | ₹0.145 | https://aisensy.com/pricing |
| WATI | per seat, $24-69 per extra user | not published | not published | https://www.wati.io/pricing/ |

Policy shapes the design: the Business Messaging Policy (updated 23 Sep 2026) bars health information where regulations require heightened protection, allows business-initiated messages only through approved templates and requires a human escalation path for any bot (https://whatsappbusiness.com/policy/), so WhatsApp is the notification and deep-link layer and plans, records and X-rays sit behind an authenticated portal link. WhatsApp Flows carry intake and slot selection as structured screens (https://developers.facebook.com/documentation/business-messaging/whatsapp/flows/llms.txt); Meta's AI-provider pricing (from 16 Feb 2026) applies only to general-purpose AI assistants, and only in the markets where Meta must allow them (EU/EEA, Italy, Brazil); a clinic-specific booking bot is ordinary business messaging (https://developers.facebook.com/documentation/business-messaging/whatsapp/pricing/ai-providers.md).

### SMS and DLT

SMS is the fallback and OTP channel. The sending entity needs a one-time DLT registration at ₹5,900 all-in, headers from nil to about ₹590, and templates with at least 30% fixed text and whitelisted URLs (https://www.messagecentral.com/blog/a-complete-guide-on-dlt-registration). Since the TCCCPR Second Amendment of 12 Feb 2025, headers carry -P/-S/-T/-G suffixes: a reminder is a Service (-S) message delivered regardless of DND, promotional (-P) traffic is blocked for DND subscribers and limited to a 10:00-21:00 default window, and a Unicode Telugu or Hindi reminder bills as 70-character segments (https://www.trai.gov.in/sites/default/files/2025-02/Regulation_12022025.pdf). Store DLT entity, header and template ids per clinic; budget ₹0.10-0.22 per SMS plus GST (https://www.techtonetworks.com/post/bulk-sms-cost-india).

### Payments

Never touch patient money. RBI's Master Direction on Payment Aggregators (15 Sep 2025) requires ₹15 crore net worth at application and ₹25 crore by the third financial year, escrow with a scheduled bank, and merchant funds credited "in the merchant's bank account only" (https://rbi.org.in/Scripts/BS_ViewMasDirections.aspx?id=12896). The compliant design is sub-merchant onboarding under a licensed PA: Razorpay Route (0.1% transfer fee; the platform must show turnover above ₹40 lakh via GST-3B or self-declare if unregistered, https://razorpay.com/docs/payments/route/) or Cashfree Easy Split (0.2% per split, up to 5 vendors, vendor KYC with PAN plus bank or UPI, https://www.cashfree.com/docs/help/easy-split/faqs/faqs.md). Rack rates are a 2% platform fee on UPI and cards at Razorpay (0.99% on UPI QR) and 1.95% at Cashfree, plus 18% GST on the fee (https://razorpay.com/pricing/, https://www.cashfree.com/payment-gateway-charges/). The realistic payments margin is small, and it must be one published payments rule: ₹0 on cash and static-QR UPI collected in clinic; a single printed 0.25% platform split, over the payment aggregator's negotiated rate, only on gateway-routed remote payments and EMI; UPI MDR passed through as its own line.

Three 2026 changes the app must respect. UPI Collect was deprecated on 28 Feb 2026, so use UPI Intent on Android and dynamic QR on desktop web, and acquire clinic VPAs under MCC 8021 for the ₹5 lakh healthcare per-transaction limit (https://razorpay.com/docs/announcements/upi-collect-migration/standard-integration, https://razorpay.com/docs/payments/payment-methods/transaction-limits/upi). UPI P2M above ₹2,000 attracts 0.4% MDR capped at ₹300 from 15 Oct 2026 unless deferred (a Supreme Court PIL is pending), with AutoPay debits and merchants under ₹1 lakh a month exempt, so tag each UPI payment with MDR applicability and pass it through as a separate line (https://www.medianama.com/2026/09/223-upi-mdr-above-rs-2000-october-15/). The RBI E-mandate Framework 2026 allows AFA-free recurring debits up to ₹15,000 with 24-hour pre-debit notice, making UPI AutoPay the rail for memberships and the SaaS subscription (https://rbi.org.in/Scripts/BS_ViewMasDirections.aspx?id=13374). In-clinic, a static UPI QR or `upi://pay` deep link costs nothing. EMI rides the PA's stack, with Bajaj Finance platform charges of 6% (3 months) to 13.5% (12 months) borne by the clinic (https://razorpay.com/docs/payments/payment-methods/emi/). Use `razorpay_flutter` 1.4.7 (https://pub.dev/packages/razorpay_flutter). This plumbing is from the gap-fill round without a second check; get a CA opinion on whether split settlement makes the SaaS an e-commerce operator under Income-tax s.194-O (https://cleartax.in/s/section-194o).

### ABDM M1-M3

Build on v3 APIs only; M1 on v1/v2 is no longer accepted (https://sandboxcms.abdm.gov.in/uploads/FAQ_20_11_2025_808a25df64.pdf). Milestones: M1 ABHA creation and verification, M2 HIP linking through HIE-CM, M3 consent-based HIU, M4 native HPR/HFR. Gates: functional testing by one of nine NHA-empanelled agencies within 7 working days, a CERT-In-empanelled WASA "Safe-to-Host" certificate issued separately for web, Android and iOS and renewed at least annually, an internal NHA demo, a Health Tech Committee demo, then production credentials (https://sandboxcms.abdm.gov.in/api/newmenus?populate=deep, https://sandbox.abdm.gov.in/sandbox/v3/new-documentation?doc=testing_agencies_contact, https://www.cert-in.org.in/PDF/Comprehensive_Cyber_Security_Audit_Policy_Guidelines.pdf). The research conflicts on scope: a vendor guide quotes NHA support as accepting "any two milestones" to leave the sandbox (https://nirmitee.io/blog/abdm-integration-milestones-m1-m2-m3-m4-multi-software-guide/), while NHA's "Become ABDM Enabled" matrix requires M1+M2+M3+HFR for an HMIS listing; confirm with integration.support@nha.gov.in. Backend constraints: all 8 HI types including InvoiceRecord are mandatory for the HMIS category, callback servers must be India-hosted domains with NHA NAT IPs whitelisted, on-notify must be answered within 60 seconds, and HIP link tokens last 6 months (https://sandboxcms.abdm.gov.in/uploads/FAQ_20_11_2025_808a25df64.pdf). HPR lists Dentistry with eleven specialities verified by the State Dental Council, and HFR offers "Dental Clinic" with a dental-chairs field (https://nhpr.abdm.gov.in/nhpr/v4/assets/index-7a48ab1a.js). Incentives are trivial: DHIS Corrigendum 7 (9 Apr 2026, valid to Sep 2026) pays ₹5 per record to the clinic and ₹2.5 to the vendor above 100 KYC-linked records a month, only with M3 and a valid WASA (https://abdm.gov.in/strapicms/uploads/DHIS_corrigendum_7_c1d7e09cc2.pdf). Plan M1, M2 and M4 in the first 90 days, the exit gates in days 90-150 and M3 in months 4-6, and reserve roughly ₹3-10 lakh for FT and WASA fees, which NHA does not publish; every ABDM figure here is gap-fill research read from NHA's CMS APIs without a second check.

## Costs at 100 / 1,000 / 10,000 clinics

An own estimate from October 2026 rate cards. The table uses a mature-clinic case of 3 users, 600 visits, 1,800 WhatsApp utility messages (about ₹245 incl. GST) and 200 MB of new images per clinic per month; the year-one ICP (12-18 patients a day, about 400 visits and 1,200 messages, about ₹165 incl. GST) is roughly a third cheaper on messaging; USD prices exclude India's 18% GST on imported SaaS; ₹88-90 per USD. The research tags the underlying model [disputed, low confidence]; one correction is applied: PowerSync Pro from launch, because 300 users on the same IST hours exceed the Free plan's 50 peak clients.

| Line | 100 clinics | 1,000 clinics | 10,000 clinics | Source |
|---|---|---|---|---|
| Supabase (plan, compute, PITR, storage, egress) | Pro $25 on Micro compute; 20 GB/month of images stays inside the 100 GB allowance for ~5 months, then $0.0213/GB: $25-40 | Pro $25 + Large $110 + PITR $100 + ~2.3 TB over allowance (~$49) + egress $35-100: $300-450 | Team $599 + 2XL $410 + PITR $100 + ~24 TB (~$510) + egress $300-900: $2,000-2,500 (one 2XL for ~30k users is an assumption) | https://supabase.com/pricing |
| PowerSync | Pro $49 | Pro $49 + peak clients over 1,000 at $30 per 1,000 + synced over 30 GB and hosted over 10 GB at $1/GB: $150-300 | Team $599 + ~10k peak clients (~$270) + ~500 GB synced (~$470) + ~500 GB hosted (~$490): ~$1,800 | https://powersync.com/pricing |
| CI/CD | Codemagic free tier (500 M2 minutes) | $0.095/min or $3,990/yr: $0-333 | $3,990/yr unlimited: ~$333 | https://codemagic.io/pricing/ |
| WhatsApp, Meta pass-through, utility | 180,000 msgs × ₹0.115 = ₹20,700 + GST ≈ ₹24,400 (~$275) | 1.8M msgs ≈ ₹2.44 lakh (~$2,750) | 18M msgs ≈ ₹24.4 lakh (~$27,700), still below the 25M-a-month tier where the rate falls ~6% | https://developers.facebook.com/docs/whatsapp/pricing |
| ABDM compliance (FT plus three WASA certificates, annualised) | ₹3-10 lakh/yr ≈ ₹25,000-85,000/month (quotes needed) | same | same, plus re-audits on major releases | https://sandboxcms.abdm.gov.in/api/faqs?populate=* |
| Platform subtotal (ex messaging and compliance) | ~$75-100: $0.75-1.00 (₹66-90) per clinic | ~$500-1,100: $0.50-1.10 (₹44-97) per clinic | ~$4,100-4,700: $0.41-0.47 (₹36-42) per clinic | derived |
| All-in COGS per clinic per month | ₹560-1,185 (compliance amortisation dominates) | ₹315-430 | ₹285-300 | derived |

WhatsApp at roughly ₹245 per clinic per month is the dominant variable cost at every scale, so bundle a utility quota and meter marketing templates; fixed compliance cost makes the first 100 clinics barely profitable at ₹999-1,499, and infrastructure margin only crosses 70-80% past a few hundred clinics.

## Repo layout and tooling

### Monorepo

Melos 8.9.0 on pub workspaces: Melos needs Dart 3.9 or later, workspaces arrived in Dart 3.6, glob members need Dart 3.11, and all packages share one pubspec.lock (https://pub.dev/packages/melos, https://dart.dev/tools/pub/workspaces).

```
amplify-dentistry/
  apps/
    app_mobile/        # Flutter: Android + iOS, dentist chairside
    app_desk/          # v2: Flutter web (CanvasKit) + Windows, gated on a two-week spike
  packages/
    core/              # domain model, FDI/Universal/Palmer converters, GST classes
    chart_engine/      # pure dart:ui odontogram, perio grid, image annotation (no Material)
    terminology/       # SNOMED refsets, ICD-10 K00-K14, LOINC panel, SNODENT map
    fhir_abdm/         # NRCeS R4 bundle builders: OPConsult, Prescription, Invoice
    data/              # Drift schema, migrations, PowerSync sync streams, conflict handlers
    documents/         # pdf templates: invoice, Rx, estimate, consent, lab slip; Noto fonts
    ui/                # material_ui theme, adaptive scaffolds, shared widgets
    messaging/         # WhatsApp/SMS template catalogue, opt-in ledger client
  services/
    api/               # NestJS: WhatsApp and payment webhooks, ABDM HIP/HIU callbacks
    capture_bridge/    # Windows agent: TWAIN/export-folder watcher -> DICOM/JPEG upload
  supabase/            # migrations, RLS policies, audit triggers, seed catalogues, policy tests
  web/                 # Next.js public site, patient booking and portal pages
  melos.yaml  pubspec.yaml (workspace)  codemagic.yaml  .github/workflows/
```

### CI/CD

| Need | Choice | Cost | Source |
|---|---|---|---|
| iOS and macOS builds | Codemagic | 500 free Mac mini M2 minutes a month, then $0.095/min M2 or $0.114/min M4; $3,990/yr unlimited M2 | https://codemagic.io/pricing/ |
| Linux jobs (analyze, tests, web build) | GitHub Actions | 2,000-3,000 free minutes; then $0.006/min Linux versus $0.062/min macOS | https://docs.github.com/en/billing/managing-billing-for-your-products/about-billing-for-github-actions |

A $3,990 Codemagic year beats GitHub's macOS minutes once builds pass about 5,400 Mac minutes a month. Pipeline gates: `melos run analyze`, golden tests for `chart_engine` at phone, tablet and desktop sizes, Drift migration tests, RLS policy tests against a disposable Supabase branch, and FHIR bundle validation with validator_cli against the NRCeS IG.

### Stores and release discipline

Google Play: file the Health apps declaration (mandatory since 31 Aug 2024) as "Healthcare Services and Management", publish a non-PDF privacy policy URL, add the "not a medical device" disclaimer, keep patient payments out of Play Billing (the dentist's subscription may use India's alternative billing at a 4-percentage-point lower fee), and register as an Organization account with a D-U-N-S number (https://support.google.com/googleplay/android-developer/answer/16679511?hl=en) [disputed on dates]. Apple: guideline 1.4.1 scrutiny for medical apps, 5.1.1(v) in-app account deletion, 5.1.3 no PHI in iCloud (https://developer.apple.com/app-store/review/guidelines/). Release discipline: store-delivered updates with no in-clinic install window, feature flags for the 15 Oct 2026 UPI MDR date and the 13 May 2027 DPDP obligations, a pinned Flutter SDK per release branch, and a WASA re-audit trigger for any change touching auth, storage or ABDM.

## Key numbers

The decision-relevant figures this section rests on, each with its source.

- Flutter 3.47 (12 Aug 2026) — current stable; Impeller sole renderer on iOS, default on Android API 29+ and on macOS/Windows/Linux — https://docs.flutter.dev/perf/impeller
- ~1,068 Flutter vs ~6,413 React Native US job postings (mid-2025, disputed, US-only) — hiring-pool gap — https://devnewsletter.com/p/state-of-flutter-2026/
- $25/month — Supabase Pro (100k MAU, 8 GB DB, 100 GB storage, 250 GB egress); Team $599 with HIPAA BAA; PITR $100 per 7 days; 2XL compute $410 — https://supabase.com/pricing
- $49/month — PowerSync Pro (1,000 peak clients, 30 GB synced); Free capped at 50 peak clients; Team $599 — https://powersync.com/pricing
- 171 ms vs 0.046 ms — unindexed vs indexed RLS filter in Supabase's own diagnostic — https://supabase.com/docs/guides/database/postgres/row-level-security-performance
- ₹0.25 to ₹0.18 per OTP + 18% GST — MSG91 volume ladder (5,000 to ~855k OTPs) vs ~₹6 Firebase and ~₹11 Twilio Verify — https://msg91.com/in/pricing/otp
- ₹5,900 all-in — one-time TRAI DLT principal-entity registration for Indian SMS — https://www.messagecentral.com/blog/a-complete-guide-on-dlt-registration
- 6 hours / 180 days — CERT-In incident-reporting deadline and ICT log retention in India — https://www.cert-in.org.in/PDF/CERT-In_Directions_70B_28.04.2022.pdf
- 72 hours / 13 May 2027 — DPDP Rule 7 detailed breach report deadline and commencement date of substantive DPDP obligations — https://www.dpdpa.com/DPDP_Rules_2025_English_only.pdf
- 3 years / 72 hours — DCI Code minimum record retention from commencement of treatment and deadline to furnish copies — https://dciindia.gov.in/Rule_Regulation/Gazette_Notification_reg_DCI_Revised_Dentists_Code_of_Ethics_Regulations_2014_27.06.2014.pdf
- ProcStatus 1-8 (TP, Complete, EC, EO, Referred, Deleted, Condition, TPi) — Open Dental procedure lifecycle to copy; procedures are never physically deleted — https://www.opendental.com/OpenDentalDocumentation26-1.xml
- 402 tables / 4,161 columns (v24.1) and 430 tables (v26.2) — Open Dental public schema documentation; GPL source published only through v24.3, proprietary from 24.4 (20 Mar 2025) — https://www.opendental.com/site/license.html
- 207 concepts (104 SNODENT + 103 SNOMED) — HL7 US Dental Data Exchange IG Tooth Identification value set — https://hl7.org/fhir/us/dental-data-exchange/ValueSet-tooth-identification-valueset.html
- SNOMED 371530004 and section codes 422843007/425044008/722446000/371529009/721963009/721912009/390906007/371525003 — ABDM OPConsultRecord composition type and sliced sections — https://nrces.in/ndhm/fhir/r4/StructureDefinition-OPConsultRecord.html
- ₹0.1150 utility / ₹0.8631 marketing per delivered WhatsApp template in India (+18% GST); INR migration mandatory by 31 Dec 2026 — https://developers.facebook.com/docs/whatsapp/pricing
- $0.001 per message, no monthly fee — Gupshup markup over Meta rates vs Interakt ₹2,799-3,799/month and AiSensy ₹1.09 marketing / ₹0.145 utility — https://www.gupshup.ai/pricing
- ₹15 crore at application / ₹25 crore by FY3 — RBI net-worth requirement for a non-bank Payment Aggregator; merchant funds must go to the merchant's account only — https://rbi.org.in/Scripts/BS_ViewMasDirections.aspx?id=12896
- 2% Razorpay platform fee on UPI/cards (0.99% UPI QR), 1.95% Cashfree, Route transfer 0.1%, Easy Split 0.2% — sub-merchant payment economics — https://razorpay.com/pricing/
- 0.4% MDR capped at ₹300 on UPI P2M above ₹2,000 from 15 Oct 2026 (AutoPay and sub-₹1 lakh/month merchants exempt; deferral possible) — https://www.medianama.com/2026/09/223-upi-mdr-above-rs-2000-october-15/
- ₹5 per record (clinic) / ₹2.5 per record (vendor) above 100 KYC-linked records a month, M3 + valid WASA required — ABDM DHIS Corrigendum 7 (9 Apr 2026) — https://abdm.gov.in/strapicms/uploads/DHIS_corrigendum_7_c1d7e09cc2.pdf
- ≈₹24,400 / ₹2.44 lakh / ₹24.4 lakh per month — Meta WhatsApp utility pass-through at 100 / 1,000 / 10,000 clinics (1,800 messages per clinic, incl. GST); dominant variable cost — https://developers.facebook.com/docs/whatsapp/pricing
- 500 free Mac mini M2 minutes/month, then $0.095/min; $3,990/yr unlimited — Codemagic CI pricing; break-even vs GitHub macOS ($0.062/min) near 5,400 Mac minutes/month — https://codemagic.io/pricing/
