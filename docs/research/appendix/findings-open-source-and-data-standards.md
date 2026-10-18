# Findings: open-source-and-data-standards

Raw research output from the multi-agent sweep (October 2026). Each finding carries a verification tag:

- `confirmed` (13): passed independent fact-check
- `corrected` (13): fact-checker corrected the claim; text below is the corrected version
- `unverified-low-risk` (3): not fact-checked (judged low-risk)

## Summary

Method note: the shared WebSearch budget for this run was already exhausted when this agent started, so all research was done by fetching primary sources directly (Open Dental's published schema XML and manual, HL7/FHIR IG pages, NRCeS/ABDM IG, DICOM Part 3/4, ISO/Wikipedia, WHO/DCI documents, GitHub/pub.dev repos). About 35 distinct primary pages were read; ADA (CDT/SNODENT licensing), LOINC.org, icd10data, iris.who.int and the SNOMED browser blocked automated fetches, so those specific facts are marked medium/low confidence.

The biggest strategic finding is that Open Dental, the long-standing reference open-source dental PMS, stopped being open source: version 24.4 (released 20 Mar 2025) moved from GPL to a proprietary closed-source license. Its 392-table MySQL schema documentation and REST API spec remain public, which makes it an excellent design reference (procedurelog, perioexam/periomeasure, toothinitial, treatplan/proctp, recall) but not a code base we can fork. No public GitHub mirror of the pre-24.4 GPL source was found. The remaining open-source dental PMS field is thin and mostly recent: DentalPin (BSL 1.1, Python/Nuxt, already shipping india_gst, razorpay and WhatsApp modules), OpenDentist (MIT, 13 commits), OpenMolar (GPL-3, UK, hobby-maintained). Generic EHRs (OpenEMR, GNU Health docs, Bahmni) have no real dental charting, which validates the niche thesis. For UI assets, the two MIT React odontograms (react-odontogram with a React Native/SVG variant; React-Advanced-Odontogram with FDI/Universal/Palmer, six-site perio, ICDAS and FHIR export and procedurally generated tooth SVGs) are the most reusable sources of tooth path geometry and perio math; Flutter's own ecosystem has only two tiny MIT teeth-selector packages with no surfaces, conditions or perio, so the odontogram widget must be built in-house.

On standards: FDI two-digit (ISO 3950:2016) is what Indian dentists learn and what WHO uses, while the US uses Universal and the UK Palmer; the DCI BDS curriculum explicitly teaches all three plus WHO indices (DMFT, OHI-S, Silness-Loe, Loe-Silness, CPI, Dean's). Clinical terminology should be SNOMED CT (free in India via NRCeS; India is a SNOMED International member) for teeth, surfaces and findings, ICD-10 K00-K14 for diagnoses, LOINC for perio observations (74029-0 set), and a self-owned procedure catalog instead of CDT, because CDT is ADA copyright that cannot be redistributed without a paid license (Open Dental's manual: sharing CDT codes with another office violates copyright); SNODENT, by contrast, is a no-cost license and is the code system the HL7 US Dental Data Exchange IG uses for its 207-concept Tooth Identification value set. For interoperability, target FHIR R4 twice over: India's ABDM profiles (NRCeS IG v6.5.0, OPConsultRecord/Prescription/Invoice/etc., SNOMED-coded sections, no dental-specific profile) and the HL7 US Dental Data Exchange IG (STU1 2021; 2.0 ballot 2025 adds a Dental Procedure profile bound to CDT). Imaging should be DICOM-native: modalities IO and PX, intra-oral SOP classes, CT for CBCT, Encapsulated STL/OBJ for intraoral scans, exposed through FHIR ImagingStudy.

Recommended canonical model (detailed in the findings): a Tooth entity keyed by (dentition, quadrant, position) with FDI as the stored code and pure converters to Universal/Palmer; a fixed Surface enum (M, O/I, D, B/F, L/P, plus root/whole-tooth); per-tooth ToothState history (present/missing/unerupted/implant/primary-retained/supernumerary); surface-level Condition records coded SNOMED/ICD-10 with ICDAS severity; Procedure records with status lifecycle copied from Open Dental (planned/completed/existing/referred/condition/deleted, never hard-deleted) pointing at a clinic-owned procedure catalog with optional CDT/SNOMED/local mappings; PerioExam with six-site PerioMeasurement rows per tooth per type (PD, GM, BOP, suppuration, mobility, furcation) from which CAL and 2017 AAP staging/grading are derived; immutable TreatmentPlan snapshots with bound signatures; and FHIR R4 export mappings to Condition, Observation, Procedure, Appointment, ImagingStudy and the ABDM OPConsultRecord Composition.

## Findings

### 1. `confirmed` · confidence high

Open Dental is no longer open source: its license page states the software changed in version 24.4 from the GPL to a proprietary closed-source license (motivated partly by keeping AI bots from consuming the code), and the versions page dates 24.4 to 03/20/2025 (24.3 on 12/19/2024 was the last GPL release). The company says pricing, support and database access for customers did not change.

**Why it matters:** We cannot fork or copy current Open Dental code. Only versions up to 24.3 are GPL, and GPL is viral anyway (unsuitable for a proprietary Flutter/SaaS product). Treat Open Dental strictly as a design reference, not a code source.

Sources:
- https://www.opendental.com/site/license.html
- https://www.opendental.com/site/versions.html
- https://www.opendental.com/site/sourcecode.html

### 2. `corrected` · confidence high

Open Dental's full MySQL schema documentation and REST API specification remain publicly downloadable as of October 2026, but the claim's version and table figures are stale and its GitHub conclusion is wrong. OpenDentalDocumentation24-1.xml (database version="24.1.0.0") is still served and contains 402 top-level <table> elements with 4,161 <column> elements, each carrying a <summary> description (many are empty or a bare period) — not 392 tables. It is also no longer the current schema: Open Dental publishes newer files at the same URL pattern, OpenDentalDocumentation24-2.xml (24.2.0.0, 406 tables), 25-1 (25.1.0.0, 410), 25-2 (25.2.0.0, 412), 26-1 (26.1.0.0, 427) and 26-2 (26.2.0.0, 430 tables). The API specification page lists ~115 resources that map roughly 1:1 to tables (Patients, Appointments, ProcedureLogs, PerioExams, PerioMeasures, TreatPlans, ProcTPs, etc.); access requires a developer key and a BAA, with developer-paid per-location pricing tiers of Free (read-only, throttled 1 req/5 s), $15, $30 and $35 per month, unchanged since September 2020. The 'zero GitHub mirrors' statement is misleading: a GitHub repository-name search for 'OpenDentBusiness' returns 0 repos because OpenDentBusiness is a project folder, not a repo name, but a GitHub code search for 'OpenDentBusiness in:path' returns ~14,400 hits, a repo search for 'Open Dental' returns 39 repos (e.g. ChemBrain/OpenDental, WaltWatt/OpenDental), and, more importantly, Open Dental itself publishes its GPL-2.0-licensed source officially at github.com/OpenDental/opendental, with one branch per Major/Minor version from 21_1 through 24_3 (latest commit 'version 24.3.63.0', 2025-04-01; the OpenDentBusiness folder is present). The main branch holds only LICENSE and README; Open Dental states it no longer posts the head branch for stability reasons, accepts no outside contributions, and makes newer source available to certain large customers only under NDA, so versions 25.x and 26.x source are not public even though their schema documentation is. All of this is US-centric (CDT codes, BAA/HIPAA, US insurance tables) and has no India-specific equivalent.

**Why it matters:** The schema is a free, battle-tested blueprint for a dental data model (25 years of edge cases). Documentation of facts is not copyrightable the way code is, so modelling after it is low-risk; copying column names verbatim is still best avoided for brand reasons.

Sources:
- https://www.opendental.com/OpenDentalDocumentation24-1.xml
- https://www.opendental.com/site/apispecification.html
- https://github.com/search?q=OpenDentBusiness&type=repositories
- https://www.opendental.com/OpenDentalDocumentation24-2.xml
- https://www.opendental.com/OpenDentalDocumentation25-1.xml
- https://www.opendental.com/OpenDentalDocumentation25-2.xml
- https://www.opendental.com/OpenDentalDocumentation26-1.xml
- https://www.opendental.com/OpenDentalDocumentation26-2.xml

<details><summary>Fact-check notes</summary>

Fetched and parsed https://www.opendental.com/OpenDentalDocumentation24-1.xml with xmllint: /database/@version = 24.1.0.0, count(/database/table) = 402, count(//column) = 4161 — claim's '392 tables' is incorrect. Probed sibling URLs: 24-2 (24.2.0.0, 406 tables, 1.34 MB), 25-1 (25.1.0.0, 410), 25-2 (25.2.0.0, 412), 26-1 (26.1.0.0, 427), 26-2 (26.2.0.0, 430) all return HTTP 200 with valid XML, so 24.1 is several versions out of date in Oct 2026. The API spec page lists Patients, Appointments, ProcedureLogs, PerioExams, PerioMeasures, TreatPlans, ProcTPs among ~115 resources, requires a BAA, and points to the API Permissions page, which lists developer-paid per-location tiers Free/$15/$30/$35 per month, last changed September 2020, with InsuranceSimple added in 25.1. GitHub (authenticated gh api): search/repositories q=OpenDentBusiness total_count=0 (matches the claim literally), but search/code q='OpenDentBusiness in:path' total_count=14,400 and search/repositories q='Open Dental opendental' total_count=39. Official repo OpenDental/opendental: license GPL-2.0 (LICENSE file on branch 24_3 is GNU GPL v2), created 2022-01-07, 15 branches 21_1..24_3 plus main, branch 24_3 contains OpenDentBusiness, OpenDental, OpenDentalCloud etc.; last push 2025-04-01 ('version 24.3.63.0'); main contains only LICENSE and README. README says the solution does not build out of the box, no outside contributions are accepted, and older (pre-2022) source is on a guest-accessible SVN. opendental.com/site/sourcecode.html links to github.com/OpenDental and says source is 'sometimes made available to certain large customers under a signed Non Disclosure Agreement' and that the head is no longer posted. Note: the per-turn WebSearch budget was exhausted before this subagent ran, so the two required WebSearch queries could not be executed; verification relied on direct fetches of the stated sources, sibling URLs, and the GitHub API instead. /site/databasedocumentation.html and /manual/dbdocumentation.html return 404.

</details>

### 3. `corrected` · confidence high

Open Dental's procedurelog table (verified against the official schema XML for versions 24.1, 25.1, 25.2, 26.1 and 26.2) stores ToothNum as varchar(2) in US Universal notation: 1-32 or A-T, supernumerary permanent 51-82 (add 50), supernumerary primary AS-TS. The FDI note is Canada-specific, not a general "FDI users" rule: in 24.1-25.2 the doc says "For Canadian users, using FDI nomenclature, we use 51 as a placeholder for supernumerary teeth (CDHA tooth 99)"; from 26.1 this became placeholders 51-55 mapping to FDI 99, 19, 29, 39, 49. FDI display is a conversion in the "tooth logic class", not a storage format - relevant for India, which uses FDI. Surf is varchar(10) holding surfaces, quadrants ("UL"), sextants ("2"; Canada uses 03-08) or arches ("U"/"L"). ProcStatus (tinyint) enum ProcStat is TP=1, C=2, EC=3, EO=4, R=5, D=6, Cn=7 PLUS TPi=8 (Treatment Plan inactive) in every version checked, and 26.x also documents None=0 "Not used" - the claim's seven-value list is incomplete. The table summary states a procedure "can NEVER be deleted", only set to status Deleted (also via IsLocked invalidation). Dates: DateTP, ProcDate (+ProcTime/ProcTimeEnd), DateComplete, plus DateEntryC, SecDateEntry and DateTStamp - more than "three dates". Diagnosis: DiagnosticCode and DiagnosticCode2-4 (varchar(255), documented as ICD-9 text sent on medical claims) with IcdVersion (9 or 10, default 9, copied from DxIcdVersion pref), IsPrincDiag, SnomedBodySite varchar(255), Prosthesis char(1) blank/I/R with DateOriginalProsth and IsDateProsthEst, and Discount (double; dollar amount used only to create an adjustment when a TP procedure is set complete, "should not be used as an accurate monetary discount value for completed procedures").

**Why it matters:** Copy the status lifecycle and never-delete rule (medico-legal audit trail), but do NOT copy the US-centric Universal storage or the overloaded Surf string: store FDI plus a structured surface set and a separate 'treatment area' type (tooth/surface/quadrant/sextant/arch/mouth) like procedurecode.TreatArea.

Sources:
- https://www.opendental.com/OpenDentalDocumentation24-1.xml
- https://www.opendental.com/OpenDentalDocumentation25-1.xml
- https://www.opendental.com/OpenDentalDocumentation25-2.xml
- https://www.opendental.com/OpenDentalDocumentation26-1.xml
- https://www.opendental.com/OpenDentalDocumentation26-2.xml

<details><summary>Fact-check notes</summary>

Direct inspection of the stated source (OpenDentalDocumentation24-1.xml, downloaded 2026-10-11) and the newer 25-1, 25-2, 26-1 and 26-2 XMLs confirms most of the claim verbatim: ToothNum 1-32/A-T, 51-82, AS-TS; Surf for quadrants/sextants/arches; ProcStatus 1-7 values; "A procedure can NEVER be deleted. Status can just be changed to 'deleted'"; DateTP/ProcDate/DateComplete; DiagnosticCode(2-4) + IcdVersion; SnomedBodySite; Prosthesis I/R + DateOriginalProsth; Discount. However it is refuted on precision in three ways: (1) the ProcStat enum has an 8th member TPi=8 "Treatment Plan inactive" in all versions, and None=0 in 26.x, so listing TP..Condition as the enum is incomplete; (2) the FDI/51 placeholder is explicitly "For Canadian users, using FDI nomenclature" (CDHA tooth 99), not a general FDI-user behaviour, and in 26.1+ it changed to placeholders 51-55 mapping to FDI 99/19/29/39/49 - so the claim is both US/Canada-specific and stale relative to current versions; (3) "keeps three dates" undercounts: DateEntryC, SecDateEntry, DateTStamp, ProcTime and ProcTimeEnd also exist. Also the Discount column doc warns it is not an accurate discount value for completed procedures. India-vs-global lens: Open Dental stores Universal numbering natively and treats FDI (the system used in India) as a display conversion with lossy supernumerary handling; the claim is not India-specific and should not be read as an India-ready model. Note: WebSearch budget for this turn was exhausted so no fresh searches could be run; verification relied on fetching the primary schema documents directly.

</details>

### 4. `unverified-low-risk` · confidence high

Open Dental's periodontal model is two tables: perioexam (one row per patient per exam date, with provider and note) and periomeasure (one row per tooth per SequenceType such as probing, gingival margin, mobility, recession; IntTooth 1-32; six site columns MBvalue, Bvalue, DBvalue, MLvalue, Lvalue, DLvalue; -1 = not measured; values 100+ encode negative gingival-margin values, e.g. 105 = -5 mm; ToothValue for whole-tooth measures like mobility/skip).

**Why it matters:** Six sites x tooth x measurement-type is the industry-standard shape; store gingival margin and probing depth separately so clinical attachment level (CAL = PD + GM) and 2017 AAP staging can be derived, and avoid Open Dental's '100+ = negative' hack by using signed integers.

Sources:
- https://www.opendental.com/OpenDentalDocumentation24-1.xml

### 5. `confirmed` · confidence high

Open Dental separates tooth state from procedures: toothinitial records missing teeth, primary (retained) teeth, movements (mm shift or degrees rotation/tipping) and free-hand chart drawings per tooth; procedurecode carries PaintType (how to paint the tooth graphic), TreatArea, IsProsth, IsHygiene, LaymanTerm (patient-friendly description for treatment plans), and default ICD-10 DiagnosticCodes. treatplan stores Saved/Active/Inactive plans; saved plans use proctp rows that are frozen copies of procedures (fee, insurance estimate, patient amount, tooth/surface already converted to the display notation) and a signature cryptographically bound to the concatenation of note, date and each line's description and amount.

**Why it matters:** Gives three concrete patterns: (1) tooth-state table separate from procedures so the odontogram renders state + history; (2) catalog-level rendering hints and layman terms; (3) immutable, signed treatment-plan snapshots, which is exactly what consent and estimate disputes in Indian clinics need.

Sources:
- https://www.opendental.com/OpenDentalDocumentation24-1.xml
- https://www.opendental.com/OpenDentalDocumentation25-3.xml
- https://www.opendental.com/OpenDentalDocumentation26-1.xml

### 6. `unverified-low-risk` · confidence high

Open Dental's recall model is procedure-driven: recalltype defines a DefaultInterval and the ProcCodes to place on the recall appointment; recall rows (one per patient per type) are auto-created/updated whenever qualifying procedures are completed, with RecallInterval, RecallStatus and Priority. Its insurance model (insplan, inssub, patplan, claim, claimproc, benefit) is deeply US/Canada-specific (PPO/capitation plan types, X12 835 adjustment reason codes, fee schedules).

**Why it matters:** Adopt the procedure-triggered recall pattern (e.g. scaling -> 6-month recall, RCT -> crown follow-up). Keep insurance as an optional module with a simple payer/claim abstraction for Indian cashless/TPA cases rather than cloning the US model.

Sources:
- https://www.opendental.com/OpenDentalDocumentation24-1.xml

### 7. `corrected` · confidence medium

CDT (Code on Dental Procedures and Nomenclature) is ADA-copyrighted content and the ADA says any commercial use (including embedding the codes in software) "requires a valid commercial user license from the ADA"; the ADA's commercial-licensing page is publicly reachable (https://www.ada.org/publications/ada-store-products/licensing-for-commercial-users) and lists "software" as a license category, but it publishes no royalty amounts — it only says the ADA issues "a template license agreement that reflects the appropriate terms, conditions and royalty fees" after a CDT License Application is processed (typically 2–4 weeks, up to two months; contact CDT-SNODENT@ada.org). So the exact vendor royalty is unpublished, not merely blocked by a 403/404 (only the ADA store catalog URLs and some guessed sub-pages returned 404/403). Open Dental's Procedure Codes manual page states verbatim "It is a violation of the copyright to share CDT codes with another office" and that "non-CDT codes and other types of codes (e.g., for Foreign Countries) can be exported then imported to other databases," with only not-yet-existing codes imported. The HL7 Dental Data Exchange IG continuous build, version 2.0.0-ballot (explicitly "not an authorized publication"; value set "Draft as of 2025-04-07"), binds Procedure.code in the Dental Procedure profile with EXTENSIBLE strength to the "Dental Procedure Codes Value Set" (http://hl7.org/fhir/us/dental-data-exchange/ValueSet/dental-procedure-codes-vs), defined as "Include all codes defined in" the code system http://www.ada.org/cdt. The ADA's Code Maintenance Committee held its annual meeting on March 13, 2026 and its decisions form CDT 2027, effective January 1 – December 31, 2027, with 67 changes (28 additions, 33 revisions, 0 deletions, 6 editorial); the next CMC meeting is March 4–5, 2027. India/global caveat: CDT is a US (HIPAA-era) claims code set; nothing on the ADA or HL7 pages makes it applicable to India, which has no mandated dental procedure code set and is a SNOMED International member country (SNOMED CT is therefore usable there under the national member licence), so an India-first product does not need a CDT licence unless it ships CDT codes to US customers.

**Why it matters:** Do not ship CDT codes or descriptions in an India-first product; build a clinic-owned procedure catalog with an optional external-code mapping field (CDT for licensed US tenants, SNOMED procedure codes, local codes). Budget for an ADA content license only when entering the US.

Sources:
- https://www.opendental.com/manual/procedurecodes.html
- https://build.fhir.org/ig/HL7/dental-data-exchange/ValueSet-dental-procedure-codes-vs.html
- https://www.ada.org/publications/cdt
- https://build.fhir.org/ig/HL7/dental-data-exchange/StructureDefinition-dental-procedure.html
- https://build.fhir.org/ig/HL7/dental-data-exchange/index.html
- https://www.ada.org/publications/cdt/code-maintenance-committee
- https://www.ada.org/publications/cdt/ada-dental-claim-form
- https://www.ada.org/publications/ada-store-products/licensing-for-commercial-users

<details><summary>Fact-check notes</summary>

Verified by direct fetch on 2026-10-11: (1) Open Dental manual page contains the exact copyright-sharing sentence and the "Foreign Countries" export/import sentence — claim accurate. (2) HL7 IG: ValueSet page says "Include all codes defined in http://www.ada.org/cdt", version "2.0.0-ballot", "not an authorized publication; it is the continuous build", "Draft as of 2025-04-07"; the StructureDefinition-dental-procedure page shows Procedure.code bound with strength "extensible" to that value set — claim accurate but omits the extensible strength and the unauthorized/continuous-build status. (3) ADA CDT page: "The Code Maintenance Committee (CMC) convened its Annual Meeting on March 13, 2026" and changes "to be incorporated into CDT 2027"; the CMC page adds effective dates Jan 1–Dec 31, 2027 and 67 changes (28/33/0/6) — claim accurate. (4) The claim's assertion that ADA licensing pages were unreachable is incorrect: https://www.ada.org/publications/ada-store-products/licensing-for-commercial-users loaded fine and states commercial use "requires a valid commercial user license from the ADA", lists software as a license type, and says the ADA supplies "a template license agreement that reflects the appropriate terms, conditions and royalty fees" — no dollar figures are published anywhere publicly. Guessed sub-URLs (/publications/cdt/licensing etc.) 404'd and engage.ada.org store 404'd/403'd, and the HHS code-set and CMS HCPCS pages returned 403, so the HIPAA-mandate statement rests on general knowledge rather than a fresh fetch. (5) snomed.org/members lists India under Asia Pacific. Note: WebSearch budget for this turn was exhausted, so no fresh web searches could be run; all verification was by WebFetch of primary sources.

</details>

### 8. `confirmed` · confidence high

SNODENT (ADA/ANSI standard) contains 7,000+ dental terms, is harmonized with SNOMED CT, aligned with ICD-10-CM for billing, updated every fall, and the ADA offers a no-cost usage license. Its FHIR system URI is http://www.ada.org/snodent (v2.0.0 used by HL7); codes end in 'D', e.g. 161227D = permanent maxillary right third molar (Universal 1, ISO 18), 162091D = deciduous maxillary right second molar (Universal A, ISO 55).

**Why it matters:** SNODENT is the free, dentistry-specific terminology for US credibility and is already cross-referenced to Universal and ISO numbers per tooth, making it a ready mapping table. Apply for the license early; it is zero-cost.

Sources:
- https://www.ada.org/resources/practice/dental-standards/snodent
- https://hl7.org/fhir/us/dental-data-exchange/ValueSet-tooth-identification-valueset.html
- https://www.ada.org/resources/practice/dental-standards/snodent/snodent-license-application

### 9. `corrected` · confidence high

HL7 FHIR US Dental Data Exchange IG STU1 v1.0.0 (generated/published 2021-11-02, FHIR R4 4.0.1, package hl7.fhir.us.dental-data-exchange#1.0.0) is still the only official published release as of October 2026; its publication history lists just 0.1.0 (2020-08-10, STU1 ballot) and 1.0.0 (2021-11-02, STU1). STU1 defines 7 profiles (Dental Bundle, Dental Referral Note, Dental Service Request, Dental Consult Note, Dental Condition, Dental Finding, Dental Communication) for 4 document-based use cases: medical->dental referral note, dental->medical consult note, general dentist->endodontist referral note, endodontist->general dentist consult note. Sponsor is the HL7 Payer/Provider Information Exchange (PIE) WG with Lantana Consulting Group as primary editors; acknowledged contributors include HL7 SDWG, ADA, Defense Health Agency, VA, FEHRM and CareQuest Institute; it is based on ANSI/ADA Standard No. 1084 Reference Core Data Set (2019 edition) and depends on US Core, C-CDA on FHIR, Da Vinci HRex Coverage and ODH. The 2.0.0-ballot content exists ONLY as an unpublished CI build (labelled "Draft as of 2025-04-07", "not an authorized publication"); it is not in the official package-list and has no hl7.org ballot URL. In that CI build the artifact list does not merely add a profile: it drops the three document profiles (Dental Bundle, Referral Note, Consult Note return 404) and lists 5 profiles -- Dental Service Request, Dental Condition, Dental Finding, Dental Communication and a new Dental Procedure profile (dated 2024-08-15, derived from US Core Procedure STU6.1) -- plus two new CapabilityStatements (Dental Data Exchange Client/Server) and a Dental Procedure Codes value set, i.e. a shift toward a RESTful/US Core-aligned approach; the CI home-page narrative still says "7 profiles" and is internally inconsistent. This is a US-only standard (US Core, ADA 1084, CDT/US payer context); it has no adoption or regulatory standing in India, where ABDM/NHCX FHIR profiles apply instead.

**Why it matters:** This is the only dental-specific FHIR IG in existence; aligning our export (Condition/Observation/Procedure with dental category and tooth bodySite) with it is cheap and gives instant US interoperability credibility.

Sources:
- https://hl7.org/fhir/us/dental-data-exchange/
- https://build.fhir.org/ig/HL7/dental-data-exchange/
- https://build.fhir.org/ig/HL7/dental-data-exchange/StructureDefinition-dental-procedure.html
- https://hl7.org/fhir/us/dental-data-exchange/STU1/
- https://hl7.org/fhir/us/dental-data-exchange/package-list.json
- https://hl7.org/fhir/us/dental-data-exchange/artifacts.html
- https://build.fhir.org/ig/HL7/dental-data-exchange/artifacts.html
- https://github.com/HL7/dental-data-exchange/tree/master/input/fsh

<details><summary>Fact-check notes</summary>

Verified by WebFetch on 2026-10-11 (web searches could not be run: the turn's WebSearch budget was exhausted, so no fresh search queries were executed). (1) hl7.org/fhir/us/dental-data-exchange/ and /STU1/: v1.0.0 STU1, generated 2021-11-02, FHIR 4.0.1, package hl7.fhir.us.dental-data-exchange#1.0.0, "This guide defines 7 FHIR profiles" (Bundle, Referral Note, Service Request, Consult Note, Condition, Finding, Communication), 4 use cases, PIE WG sponsor, ADA/DHA/VA/FEHRM/Lantana/CareQuest acknowledged, ANSI/ADA 1084 (2019) dependency -- these parts of the claim hold. (2) package-list.json lists only 0.1.0 (2020-08-10 ballot) and 1.0.0 (2021-11-02) plus the CI build; no 2.0.0 or STU2 entry; hl7.org/.../2025May returns 404 -- so "2.0.0-ballot (2025-04-07)" is a CI-build label, not a published ballot. (3) build.fhir.org CI index: 2.0.0-ballot, "Draft as of 2025-04-07", explicitly "not an authorized publication"; narrative still says 7 profiles and does not mention Dental Procedure. (4) build.fhir.org artifacts.html lists 5 StructureDefinitions only: Dental Service Request, Dental Condition, Dental Finding, Dental Communication, Dental Procedure; Dental Bundle/Referral Note/Consult Note absent and their pages return 404; two CapabilityStatements and a Dental Procedure Codes value set added. (5) StructureDefinition-dental-procedure.html: version 2.0.0-ballot, Draft as of 2024-08-15, "Dental specialization of the US Core Procedure profile" based on US Core STU6.1. (6) github.com/HL7/dental-data-exchange input/fsh contains Profile_DentalProcedure.fsh and SEP2024 Connectathon examples, confirming the Procedure profile originated around the Sept 2024 connectathon. Corrections to the claim: the 2.0.0-ballot is not an official/published ballot; it does not simply "add" a profile but restructures the IG (document profiles removed, 5 profiles total in artifacts); US Core base version is STU6.1; sponsor list should note Lantana as editor and HL7 SDWG; HL7 PIE is the work group, not a "sponsor/contributor" alongside ADA. India-vs-global: the standard is US-specific and irrelevant to Indian regulatory interoperability (ABDM).

</details>

### 10. `corrected` · confidence high

In the published HL7 Dental Data Exchange IG (US Realm, STU1 v1.0.0, 2021-11-02, FHIR R4; still the only official publication as of Oct 2026, with a 0.1.0 ballot in Sept 2020 before it), the Tooth Identification ValueSet expansion contains 207 concepts: 104 SNODENT v2.0.0 codes and 103 SNOMED CT (US edition, 01-Sep-2021) codes, covering permanent teeth Universal 1-32, deciduous A-T, and supernumerary teeth (SNODENT: 32 permanent, Universal 52-82; 20 deciduous, letter+'S' such as MS/TS; SNOMED lacks one deciduous supernumerary). Universal and ISO numbers are NOT in the display strings; they appear only in the SNODENT definition text (e.g. 161533D definition "Universal designation 19; ISO designation 36"), and supernumerary definitions carry at most a Universal number with no ISO number, several having no definition at all. The Dental Anatomy ValueSet has 215 concepts = Tooth Identification (207) + Oral Cavity Area (8 concepts, not 4: the same 4 regions - anterior/posterior segment of maxilla, anterior/posterior part of lower alveolar ridge - coded once in SNODENT and once in SNOMED CT). The Dental Finding profile is an Observation with code 1..1 bound required to LOINCCodes, bodySite 0..1 (Must Support) bound preferred to Dental Anatomy, and states that because only a single bodySite is allowed, multiple tooth surfaces/numbers/areas require SNOMED CT post-coordination (Composition Grammar). There is no tooth-surface value set in the IG (artifacts list: Dental Reason For Referral, Dental Observation Codes, Dental Anatomy, Oral Cavity Area, Tooth Identification, Dental Procedure Codes). The published pages do contain display errors, e.g. 161533D displays as "second molar" while its definition (Universal 19/ISO 36) is the first molar; 162234D "masillary" typo; SNOMED deciduous codes mislabelled "permanent" in the logical-definition table. A 2.0.0-ballot CI build (build.fhir.org, generated 2025-04-07, not an authorized publication) moves to SNODENT v2.1.0 and SNOMED CT US 01-Mar-2025, reports "at least 199 concepts" in Tooth Identification, keeps the same bindings and post-coordination note, still has no tooth-surface value set, and still shows the 161533D display error. Context for India: this is a US-Realm IG built around ADA Universal numbering and SNODENT (ADA-licensed); Indian clinical practice uses FDI/ISO 3950 notation, which appears here only as secondary text in SNODENT definitions, so the value set is not directly an Indian or global standard.

**Why it matters:** We must define our own surface code system (or use SNOMED surface body-structure concepts) and one Observation per tooth-site; do not rely on the IG's displays verbatim. Store SNODENT and SNOMED IDs per tooth in a static lookup table (about 52 + supernumerary rows).

Sources:
- https://hl7.org/fhir/us/dental-data-exchange/ValueSet-tooth-identification-valueset.html
- https://hl7.org/fhir/us/dental-data-exchange/ValueSet-dental-anatomy.html
- https://hl7.org/fhir/us/dental-data-exchange/ValueSet-oral-cavity-area.html
- https://hl7.org/fhir/us/dental-data-exchange/StructureDefinition-dental-findings.html
- https://hl7.org/fhir/us/dental-data-exchange/package-list.json
- https://build.fhir.org/ig/HL7/dental-data-exchange/ValueSet-tooth-identification-valueset.html
- https://build.fhir.org/ig/HL7/dental-data-exchange/artifacts.html
- https://build.fhir.org/ig/HL7/dental-data-exchange/StructureDefinition-dental-findings.html

<details><summary>Fact-check notes</summary>

Direct fetch of the stated pages confirms: Tooth Identification expansion "This value set contains 207 concepts" (104 SNODENT v2.0.0 + 103 SNOMED CT US 01-Sep-2021), permanent 1-32, deciduous A-T, supernumerary 52-82 and letter+S; 161533D display "Entire permanent mandibular left second molar tooth" vs definition "Permanent mandibular left first molar tooth; Universal designation 19; ISO designation 36" (display error confirmed). Dental Anatomy = 215 concepts, composed of Oral Cavity Area + Tooth Identification. Oral Cavity Area page shows 8 concepts (4 SNODENT + 4 SNOMED), refuting the claim's "only 4". Universal/ISO numbers appear in the definition column only, not in displays, and supernumerary codes (e.g. 177649D "Universal designation 52") have no ISO number, while 177450D etc. have no definition — refuting "each display carries both Universal and ISO numbers". Dental Findings profile: Observation, code required LOINCCodes, bodySite 0..1 preferred Dental Anatomy, single-bodySite/post-coordination note confirmed; no surface value set referenced. package-list.json: versions 0.1.0 (2020-08-10 ballot), 1.0.0 (2021-11-02 trial-use, current), plus ci-build. CI build (2.0.0-ballot, 2025-04-07): SNODENT v2.1.0, SNOMED US 01-Mar-2025, "at least 199 concepts", same bindings, no tooth-surface VS, 161533D error persists; the 2025May path returned 404, so the 2.0.0 ballot is not an authorized publication. WebSearch could not be run (per-turn search budget exhausted); all findings come from fetching the primary HL7 pages.

</details>

### 11. `unverified-low-risk` · confidence high

FHIR body-site mechanics: Procedure.bodySite is 0..* CodeableConcept with an example binding to SNOMED body structures (R4 Procedure maturity 3); BodyStructure (R4 maturity 1) is for patient-specific sites and FHIR guidance says to prefer a pre-coordinated CodeableConcept when one exists; the Dental Procedure profile adds an extension slice (http://hl7.org/fhir/StructureDefinition/bodySite) to reference BodyStructure for complex locations. In R5, ImagingStudy.bodySite becomes CodeableReference(BodyStructure) and ImagingStudy (maturity 4) carries DICOM Study/Series/SOP Instance UIDs, modality (DICOM CID 33) and endpoint for retrieval; instances themselves are not stored in FHIR.

**Why it matters:** Model export as Procedure.bodySite = SNOMED/SNODENT tooth CodeableConcept plus a local surface coding (one Procedure per tooth), reserving BodyStructure for implants/lesions with images. Keep ImagingStudy as metadata pointing at a DICOMweb store.

Sources:
- https://hl7.org/fhir/R4/procedure.html
- https://hl7.org/fhir/R4/bodystructure.html
- https://hl7.org/fhir/R5/imagingstudy.html
- https://build.fhir.org/ig/HL7/dental-data-exchange/StructureDefinition-dental-procedure.html

### 12. `confirmed` · confidence high

India's ABDM FHIR Implementation Guide (NRCeS, v6.5.0, draft 2025-05-08, FHIR R4 4.0.1) defines document bundles OPConsultRecord, PrescriptionRecord, DiagnosticReportRecord, DischargeSummaryRecord, ImmunizationRecord, HealthDocumentRecord, WellnessRecord and a billing InvoiceRecord, plus resource profiles for Patient, Practitioner, Organization, Appointment, Condition, Procedure, Observation*, ImagingStudy, Media, DocumentReference, ServiceRequest, Invoice, ChargeItem. It contains no dental or oral-health-specific profile. Terminology bindings use SNOMED CT (International), LOINC, ICD-10 for diagnoses, and Indian Common Drug Codes (CDCI).

**Why it matters:** A dental visit must be shipped to ABDM as a generic OPConsultRecord; our internal model should map cleanly to it (chief complaint -> Condition, odontogram/perio findings -> Observation, treatments -> Procedure, follow-up -> Appointment, bill -> Invoice/ChargeItem). Being the first dental PMS with clean ABDM output is a differentiator.

Sources:
- https://nrces.in/ndhm/fhir/r4/index.html
- https://nrces.in/ndhm/fhir/r4/terminology.html
- https://nrces.in/ndhm/fhir/r4/profiles.html
- https://nrces.in/ndhm/fhir/r4/hcx-profile.html
- https://nrces.in/ndhm/fhir/r4/StructureDefinition-Condition.html

### 13. `confirmed` · confidence high

ABDM OPConsultRecord is a Composition whose type is fixed to SNOMED CT 371530004 'Clinical consultation report'; sections are sliced by fixed SNOMED codes: Chief complaints 422843007 (Condition), Physical examination 425044008 (Observation), Allergies 722446000 (AllergyIntolerance), Medical history 371529009 (Condition/Procedure), Family history 422432008, Investigation advice 721963009 (ServiceRequest), Medications 721912009 (MedicationStatement/Request), Follow up 390906007 (Appointment), Procedure 371525003 (Procedure); all sections optional (0..1).

**Why it matters:** This gives the exact skeleton for the 'export visit to ABHA' feature: the BDS case-sheet sections (chief complaint, history, examination, investigations, treatment, follow-up) map one-to-one onto these SNOMED-coded sections.

Sources:
- https://nrces.in/ndhm/fhir/r4/StructureDefinition-OPConsultRecord.html
- https://nrces.in/ndhm/fhir/r4/history.html

### 14. `confirmed` · confidence medium

India is listed as a SNOMED International Member country; NRCeS (hosted at C-DAC Pune, under MoHFW) publishes the ABDM FHIR profiles, SNOMED CT national refsets and Indian extensions (AYUSH Extension, Common Drug Codes for India, Common Lab Codes, Patient Instructions). Membership means SNOMED CT use within India is covered by a free national affiliate license obtained through NRCeS (the free-of-charge detail is from NRCeS's known policy; the fetched pages confirm membership and the extensions but not the fee wording). SNOMED CT has body-structure concepts for every tooth (e.g. 245575001 'Entire maxillary right central incisor tooth', 245566003) and 38199008 'Tooth structure'.

**Why it matters:** SNOMED CT is the right zero-cost clinical vocabulary for India (and free in the US via NLM); use SNOMED tooth and surface body-structure concepts as the interoperable tooth identifier alongside FDI, and SNOMED disorder concepts for findings.

Sources:
- https://www.snomed.org/members
- https://www.nrces.in/
- https://hl7.org/fhir/us/dental-data-exchange/ValueSet-dental-anatomy.html
- https://raw.githubusercontent.com/openEHR/CKM-mirror/master/local/archetypes/cluster/openEHR-EHR-CLUSTER.exam-tooth.v0.adl
- https://www.snomed.org/get-snomed
- https://www.nrces.in/standards/snomed-ct
- https://www.nrces.in/ndhm/fhir/r4/index.html
- https://tx.fhir.org/r4/CodeSystem/$lookup?system=http://snomed.info/sct&code=245575001

### 15. `confirmed` · confidence high

ICD-10 (WHO 2019) oral chapter K00-K14: K00 disorders of tooth development and eruption; K01 embedded and impacted teeth; K02 dental caries; K03 other diseases of hard tissues of teeth; K04 diseases of pulp and periapical tissues; K05 gingivitis and periodontal diseases; K06 other disorders of gingiva and edentulous alveolar ridge; K07 dentofacial anomalies incl. malocclusion; K08 other disorders of teeth and supporting structures; K09 cysts of oral region; K10 other diseases of jaws; K11 salivary glands; K12 stomatitis; K13 lip and oral mucosa; K14 tongue. ABDM's Diagnostic Code value set is ICD-10, while Open Dental stores up to four ICD-10-CM codes per procedure for US medical claims.

**Why it matters:** Ship a built-in dental ICD-10 pick-list (K00-K14 plus S02.5 tooth fracture, Z01.2 dental exam) with WHO ICD-10 for India/ABDM and the ICD-10-CM variant (extra characters) for US tenants; store code + code-system + version.

Sources:
- https://icd.who.int/browse10/2019/en/JsonGetChildrenConcepts?ConceptId=K00-K14&useHtml=false
- https://nrces.in/ndhm/fhir/r4/terminology.html
- https://www.opendental.com/OpenDentalDocumentation24-1.xml
- https://icd.who.int/browse10/2019/en#/K00-K14
- https://nrces.in/ndhm/fhir/r4/ValueSet-ndhm-diagnostic-code.html
- https://www.opendental.com/manual/procedurecodeedit.html

### 16. `confirmed` · confidence high

Tooth notation: FDI two-digit (ISO 3950:2016) uses quadrant digit 1-4 for permanent and 5-8 for primary teeth plus position 1-8 from the midline (pronounced 'one-one'); it is the WHO/FDI international standard. Universal (ADA) numbers 1-32 from upper-right third molar clockwise and A-T for primary, and is 'commonly used only in the United States' (ADA adopted it in 1968, accepted ISO as an alternative in 1996). Palmer/Zsigmondy (1861) uses quadrant brackets with 1-8 / A-E and remains the norm in UK practice. The DCI's BDS curriculum lists 'Tooth numbering systems A.D.A., Zsigmondy Palmer and F.D.I.' as required content.

**Why it matters:** Store FDI as the canonical tooth code (India-first, WHO-aligned) with pure conversion functions to Universal and Palmer for display; make notation a per-clinic/per-user preference, as Open Dental does with its 'international' option.

Sources:
- https://en.wikipedia.org/wiki/Dental_notation
- https://dciindia.gov.in/Rule_Regulation/Revised_BDS_Course_Regulation_2007.pdf
- https://en.wikipedia.org/wiki/FDI_World_Dental_Federation_notation
- https://en.wikipedia.org/wiki/Palmer_notation
- https://en.wikipedia.org/wiki/Universal_Numbering_System
- https://knowledge.bsigroup.com/products/dentistry-designation-system-for-teeth-and-areas-of-the-oral-cavity
- https://knowledge.bsigroup.com/products/dentistry-designation-system-for-teeth-and-areas-of-the-oral-cavity-1
- https://www.ada.org/publications/cdt/ada-dental-claim-form

### 17. `confirmed` · confidence medium

LOINC has limited but real periodontal content: 74029-0 'Periodontal attachment - recommended CDA set', 86603-8 'Periodontal attachment - recommended CDA R1 set', 74030-8 'Periodontal service attachment', 34013-3/34014-1 PSR (Periodontal Screening and Recording) gingiva scale, and PhenX tooth-site codes 64040-9/64041-7. The HL7 Dental Finding profile requires LOINC for Observation.code, and React-Advanced-Odontogram exports perio charts as LOINC 74029-0 panels.

**Why it matters:** Use LOINC for Observation.code on perio exports (per-site probing depth, gingival margin, BOP as components with SNOMED tooth/site bodySite) to be conformant with both the US Dental IG and ABDM Observation profiles.

Sources:
- https://clinicaltables.nlm.nih.gov/api/loinc_items/v3/search?terms=periodontal&maxList=30&df=LOINC_NUM,LONG_COMMON_NAME
- https://hl7.org/fhir/us/dental-data-exchange/StructureDefinition-dental-findings.html
- https://github.com/ZoliQua/React-Advanced-Odontogram/blob/main/README.md
- https://hl7.org/fhir/us/dental-data-exchange/index.html
- https://hl7.org/fhir/us/dental-data-exchange/history.html
- https://api.github.com/repos/ZoliQua/React-Advanced-Odontogram

### 18. `confirmed` · confidence high

DICOM dental imaging: Modality (0008,0060) defined terms include IO 'Intra-Oral Radiography' and PX 'Panoramic X-Ray' (plus DX digital radiography, CR, CT for CBCT). Relevant SOP classes: Digital Intra-Oral X-Ray Image Storage For Presentation 1.2.840.10008.5.1.4.1.1.1.3 and For Processing ...1.3.1 (implementers supporting For Processing must also support For Presentation), Digital X-Ray ...1.1 / ...1.1.1, CT Image Storage 1.2.840.10008.5.1.4.1.1.2 and Enhanced CT ...2.1, VL Photographic Image Storage ...77.1.4 (intraoral photos), Encapsulated STL ...104.3 / OBJ ...104.4 / MTL ...104.5 (intraoral scans), Encapsulated PDF ...104.1. DICOM WG-22 (Dentistry) covers orthodontic/forensic view sets, CAD/CAM, implant guidance and 3D surface scanning.

**Why it matters:** Design the imaging module DICOM-native (store IO/PX/CBCT via a DICOMweb server, with JPEG/PNG intraoral photos wrapped as VL Photographic) and expose via FHIR ImagingStudy so sensors, OPG machines and CBCT units integrate without proprietary bridges; dental sensor vendors in India export DICOM or TWAIN images.

Sources:
- https://dicom.nema.org/medical/dicom/current/output/chtml/part03/sect_C.7.3.html
- https://dicom.nema.org/medical/dicom/current/output/chtml/part04/sect_B.5.html
- https://www.dicomstandard.org/activity/wgs/wg-22

### 19. `confirmed` · confidence high

WHO 'Oral Health Surveys: Basic Methods' 5th edition (published 12 Nov 2013, free 6.6 MB PDF) is the global standard for DMFT/dmft, CPI and other indices and uses FDI numbering on its forms. India's DCI BDS curriculum requires students to run 'oral health assessment ... using WHO basic oral health survey methods' and to record: Oral Hygiene Index-Simplified (Greene & Vermillion), Silness & Loe plaque index, Loe & Silness gingival index, CPI/CPITN, DMFT/DMFS and dft/dfs, and Dean's fluorosis index.

**Why it matters:** Auto-computing DMFT/dmft, OHI-S, plaque/gingival indices and CPI from the odontogram and perio chart is a dentist-only feature no generic EHR offers, and it directly serves dental colleges and community programmes (natural fit with the founder's AmpDent student audience).

Sources:
- https://www.who.int/publications/i/item/9789241548649
- https://dciindia.gov.in/Rule_Regulation/Revised_BDS_Course_Regulation_2007.pdf
- https://iris.who.int/server/api/core/bitstreams/b00e659f-ab38-4e61-b786-0152d91b5f1b/content

### 20. `corrected` · confidence medium

The DCI "BDS Course Regulations 2007" (approved by MoHFW letter No. V.12012/3/2006-DE dated 25.07.2007; the PDF on dciindia.gov.in incorporates amendments up to the 8th Amendment, Gazette 12.7.2017) do mandate case-history recording across departments: Conservative Dentistry lists "preparation of the case sheet" (theory topic 4 and clinical item 25); Oral Medicine & Radiology requires "Recording of detailed case histories of interesting cases – 10"; Pedodontics requires "Case History Recording & Treatment Planning – 10"; Periodontics says students "should be able to record a detailed periodontal case history" with a quota of "Diagnosis, treatment planning ... – 25 cases"; Orthodontics lists "Case History taking" as final-year clinical exercise 01; and the 30-hour Forensic Odontology syllabus, under "Maintaining dental records", lists dental charts, dental radiographs, study casts, denture marking and photographs. However, the "10 cases minimum" figure applies specifically to two departments (Oral Medicine and Pedodontics), not "several"; Periodontics is 25. The regulation does NOT prescribe any case-sheet template: the words "chief complaint", "history of present illness", "personal history", "hard tissue chart", "provisional/final diagnosis" do not appear in it (only a generic competency to arrive at "provisional, differential and final diagnosis" and "order appropriate investigations"). That case-sheet structure is textbook/college practice (e.g., Oral Medicine texts and university case-record proformas), not a DCI-mandated format, and formats vary by college. Finally, "still the base curriculum" as of October 2026 could not be verified here (web-search budget exhausted): the Dentists Act 1948 under which DCI framed these regulations has been superseded by the National Dental Commission Act, 2023, and a competency-based BDS curriculum has been under development, so the regulatory status should be re-checked against the NDC/DCI website before relying on it.

**Why it matters:** The clinical-notes template should literally be the BDS case sheet, with department variants (perio, pedo, ortho, prostho), so Indian dentists feel at home from day one; this is the India-specific 'form' the task asked about.

Sources:
- https://dciindia.gov.in/Rule_Regulation/Revised_BDS_Course_Regulation_2007.pdf

<details><summary>Fact-check notes</summary>

Verified directly from the stated source PDF (downloaded, 1.8 MB, text extracted with pdftotext). Confirmed verbatim: "treatment planning, preparation of the case sheet" (Conservative Dentistry theory item 4; clinical item 25 "Vitality Tests, Diagnosis And Treatment Planning And Preparation Of Case Sheet"); "(a) Recording of detailed case histories of interesting cases ………. 10" (Oral Medicine & Radiology record of work); "23. CASE HISTORY RECORDING" and "5. Case History Recording & Treatment Planning – 10" (Pedodontics); "Students should be able to record a detailed periodontal case history" plus "Diagnosis, treatment planning and discussion and total periodontal treatment – 25 cases" (Periodontics); "01. Case History taking" (Orthodontics final-year clinical training); Forensic Odontology (30 hrs) item 4 "Maintaining dental records ... Different types of dental records: Dental charts, Dental radiographs, Study casts, Denture marking, Photographs". Also Oral Medicine item (f): "maintaining dental records and their use in dental practice and post-mortem identification". Refuting points: (1) grep for "chief complaint", "history of present", "personal history", "hard tissue", "dental history", "medical history", "family history" returns zero hits in the regulation; the only related text is competency language "Arriving at provisional, differential and final diagnosis" and "Able to order appropriate investigations" (lines ~1114-1118). So the claimed standard case-sheet structure is not in the DCI document. (2) "10 cases minimum in several departments" is imprecise: 10 in Oral Medicine and Pedodontics; Periodontics 25; Conservative/Orthodontics give no number for case history. (3) The document itself carries amendments only to 2017 (8th Amendment notification 12.7.2017); claim that it is "still the base curriculum" in Oct 2026 is unverified: WebSearch calls for the DCI/NDC competency-based BDS curriculum could not be run because the shared per-turn web-search budget was exhausted. Note the Dentists Act 1948 has been replaced by the National Dental Commission Act 2023, which affects who issues BDS regulations now. India-vs-global: the claim is India-specific and correctly scoped; no conflation found.

</details>

### 21. `confirmed` · confidence high

Two clinical scales worth encoding natively: ICDAS caries codes 0-6 (0 none; 1 early; 2 distinct visual enamel change; 3 localized enamel breakdown; 4 underlying dentine shadow; 5 distinct cavity with visible dentine; 6 extensive cavity), merged in ICCMS as A initial / B moderate / C extensive. 2017 AAP/EFP periodontitis classification (proceedings June 2018): Stage I-IV by interdental CAL (1-2 mm, 3-4 mm, >=5 mm), radiographic bone loss, teeth lost to periodontitis and complexity (max PD <=4, <=5, >=6 mm, vertical bone loss, masticatory dysfunction); Grade A/B/C by % bone loss/age (<0.25, 0.25-1.0, >1.0), smoking (non, <10, >=10/day), HbA1c (normal, <7.0%, >=7.0%); extent localized (<30% teeth), generalized, molar/incisor pattern. React-Advanced-Odontogram already implements ICDAS severity and 2017 staging/grading (MIT).

**Why it matters:** Store caries severity per surface as ICDAS and derive perio stage/grade automatically from the six-site chart plus two risk fields; both are vendor-neutral, free scales that make the product clinically credible worldwide.

Sources:
- https://www.iccms-web.com/content/icdas
- https://www.perio.org/wp-content/uploads/2019/08/Staging-and-Grading-Periodontitis.pdf
- https://www.perio.org/for-members/2017-classification-of-periodontal-and-peri-implant-diseases-and-conditions/
- https://github.com/ZoliQua/React-Advanced-Odontogram
- https://www.iccms-web.com/uploads/asset/592845add7ac8756944059.pdf
- https://doi.org/10.1002/JPER.18-0006
- https://github.com/ZoliQua/React-Advanced-Odontogram/blob/main/src/perioClassification.ts
- https://api.github.com/repos/ZoliQua/React-Advanced-Odontogram

### 22. `corrected` · confidence high

Best reusable open-source odontogram components (as of 2026-10-10; licensing is NOT uniformly MIT): (1) ZoliQua/React-Advanced-Odontogram — MIT (LICENSE detected by GitHub), 78 stars, 26 forks, 312 commits, created 2026-02-07, last push 2026-10-05, npm `react-advanced-odontogram`, with an official Angular port (`angular-advanced-odontogram`); FDI/Universal/Palmer; multi-surface caries/restorations with ICDAS/CARS; six-site perio (PD, gingival margin, BOP + suppuration) with derived CAL, recession and whole-mouth %BOP, 2017 staging/grading; HL7 FHIR R4 import/export incl. LOINC 74029-0 perio panel and a FHIR NPM terminology package; WHO ICD-10 always on (+ BNO-10 / ICD-10-CM packs) and opt-in SNOMED CT; PNG/JPG/SVG export plus jsPDF PDF report; 12 UI languages (HU/EN/DE/ES/IT/SK/PL/RU/PT-BR/AR/ZH/FR, Arabic RTL). Tooth SVGs are reproducible output of the Python `tools/toothgen` pipeline (build.py, spec.py, roots.py, etc.) from six repository-owned canonical donor SVGs measured against the repository's Odontographie plate grid and Wheeler / Ash & Nelson mean dimensions; its README states "No external illustration is copied." (2) biomathcode/react-odontogram — 78 stars, 26 forks, created 2025-09-26, last push 2026-09-08; MIT is declared in package.json and on npm (`react-odontogram` 0.6.0, `react-native-odontogram` 0.1.0, both MIT), but the repo ships NO LICENSE file (GitHub reports license: none), so verify before relying on it; FDI/Universal/Palmer via a `notation` prop; teeth are data objects with `outlinePath`/`shadowPath`/`lineHighlightPath` SVG strings; the separate `react-native-odontogram` package renders via react-native-svg. (3) jacobwalkr/dental-chart — 30 stars, 10 forks, 15 commits, plain JS+SVG, NO license file at all (default all-rights-reserved) and last pushed 2017-05-04, so it is effectively abandoned and not legally reusable without contacting the author. Caveats for this project: both actively maintained libraries are pre-1.0 React/TypeScript packages less than 13 months old, none offers a Flutter widget; for a Flutter app only the MIT-licensed SVG assets/data model (and the FHIR R4 payload format) are directly reusable, not the components.

**Why it matters:** The MIT SVG path data and perio/ICDAS logic can be ported into a Flutter CustomPainter or flutter_svg widget legally (keep the MIT notice); the toothgen approach also shows how to own your tooth artwork outright rather than tracing a copyrighted atlas.

Sources:
- https://github.com/ZoliQua/React-Advanced-Odontogram
- https://github.com/ZoliQua/React-Advanced-Odontogram/tree/main/tools/toothgen
- https://github.com/biomathcode/react-odontogram
- https://github.com/jacobwalkr/dental-chart
- https://api.github.com/repos/ZoliQua/React-Advanced-Odontogram
- https://raw.githubusercontent.com/ZoliQua/React-Advanced-Odontogram/main/README.md
- https://raw.githubusercontent.com/ZoliQua/React-Advanced-Odontogram/main/tools/toothgen/README.md
- https://github.com/ZoliQua/Angular-Advanced-Odontogram

<details><summary>Fact-check notes</summary>

GitHub API (fetched 2026-10-11): ZoliQua/React-Advanced-Odontogram stargazers 78, forks 26, license MIT, created 2026-02-07, pushed 2026-10-05; biomathcode/react-odontogram stargazers 78, forks 26, license null (no LICENSE file in root listing; package.json says "license": "MIT"; npm registry lists react-odontogram 0.6.0 and react-native-odontogram 0.1.0 as MIT); jacobwalkr/dental-chart stargazers 30, forks 10, license null, root contains only .gitignore/css/index.html/js/scss/svg, pushed 2017-05-04. Repo page confirms 312 commits for ZoliQua. ZoliQua README lines confirm six-site perio with "derived CAL, recession and whole-mouth %BOP", ICDAS/CARS, FHIR R4 with LOINC 74029-0, ICD-10 + BNO-10/ICD-10-CM packs + opt-in SNOMED CT, PNG/JPG/SVG export + jsPDF report, 12 languages, and an official Angular port. tools/toothgen README confirms six canonical donor SVGs, "Odontographie plate grid and Wheeler/Ash & Nelson" means, and "No external illustration is copied." biomathcode README confirms notation prop (FDI/Universal/Palmer), outlinePath/shadowPath/lineHighlightPath tooth objects, and the react-native-odontogram package on react-native-svg. The claim's "all MIT" is refuted: dental-chart has no license, and react-odontogram's MIT exists only in package.json/npm metadata, not as a repo LICENSE file. Facts/figures otherwise hold. Note: the two WebSearch queries required by the lens could not be run because this turn's shared web-search budget was exhausted; verification relied on direct fetches of the stated sources, the GitHub REST API and the npm registry. India-vs-global: the claim makes no India-specific assertion; the libraries are global (Hungarian-origin and generic), and ICD-10/FHIR R4 support is relevant to ABDM/FHIR-based Indian interoperability but nothing India-specific is claimed or needed.

</details>

### 23. `corrected` · confidence high

As of 2026-10-11, pub.dev has at least four dental-chart-adjacent Flutter packages, not two, though none is a clinical odontogram: (1) dental_teeth_selector 0.1.1 (Emad Beltaje, unverified uploader, MIT; Universal/ADA and FDI numbering with converter helpers; fallen/missing-teeth toggle; SVG tooth outlines; 10 likes, 160 pub points, 401 downloads; published ~16 days before 2026-10-11, i.e. late Sept 2026); (2) teeth_selector 0.2.2 (apexo.app verified publisher, MIT; primary + permanent teeth, ISO notation by default with a custom `notation` callback, per-tooth colorize; 7 likes, 130 points, 244 downloads, last published ~21 months ago, i.e. ~Jan 2025); (3) flutter_tooth_chart 0.1.0 (unverified uploader, repo jiusanzhou/flutter_tooth_chart, MIT; FDI numbering, 32 permanent + 20 primary teeth, occlusal top-down view with "3D-lit" CustomPainter shading, no SVG; 0 likes, 160 points, 49 downloads, published ~2 months ago, i.e. ~Aug 2026); (4) teeth_anatomy 0.0.3 (unverified, MIT, "dental anatomy display", 6 likes, 115 points, 12 downloads, ~2 years old). A fifth, ultralytics_yolo_dental 1.0.1 (AGPL-3.0, 15 months old), is a YOLO image-analysis plugin, not a chart. None of these documents tooth-surface marking, condition/restoration coding, periodontal charting, or supernumerary teeth. pub.dev searches for "odontogram" and "periodontal" return no dental packages, and the GitHub repository search "odontogram flutter" sorted by stars returns only TheJulianAlva/project-mmh (1 star), kencana16/flutter_odontogram (0 stars, last updated June 2024) and BlxrryFxce17/DentiScan (0 stars). So a Flutter odontogram with surfaces/conditions/perio would have to be built in-house.

**Why it matters:** The odontogram widget is greenfield in Flutter; building it in-house (and possibly open-sourcing the widget as a marketing asset) is both necessary and an opportunity, since there is no competition on pub.dev.

Sources:
- https://pub.dev/packages/dental_teeth_selector
- https://pub.dev/packages/teeth_selector
- https://pub.dev/packages?q=dental
- https://pub.dev/packages?q=odontogram
- https://github.com/search?q=odontogram+flutter&type=repositories&s=stars&o=desc
- https://pub.dev/packages/flutter_tooth_chart
- https://pub.dev/packages/teeth_anatomy
- https://pub.dev/packages/ultralytics_yolo_dental

<details><summary>Fact-check notes</summary>

Verified directly on pub.dev on 2026-10-11. The two packages named in the claim check out on nearly every number: dental_teeth_selector 0.1.1 shows MIT, unverified uploader, author Emad Beltaje, 10 likes, 160 points, 401 downloads, published 16 days ago (~25 Sept 2026), Universal 1-32 + FDI 11-48 with converters, fallen-teeth support, SVG-drawn teeth. teeth_selector 0.2.2 shows apexo.app verified, MIT, 7 likes, 130 points, 244 downloads, 21 months ago, primary/permanent, ISO default with `notation` callback, deps path_drawing + xml. Neither page mentions surfaces, conditions, restorations, perio or supernumerary teeth. The "odontogram" search returns 4 non-dental packages (pictograms, photogrammetry, mini_program_contracts, opencv_histogram_equality) and the GitHub star-sorted search shows repos with 1, 0 and 0 stars, so those parts hold. HOWEVER, the headline "only two relevant packages" is wrong: the pub.dev "teeth" search (157 results) lists flutter_tooth_chart 0.1.0 (MIT, FDI numbering, 32 permanent + 20 primary teeth, occlusal view, CustomPainter, 0 likes/160 points/49 downloads, published ~2 months ago) and teeth_anatomy 0.0.3 (MIT, SVG-based dental anatomy display, 6 likes/115 points/12 downloads, ~2 years old); the "dental" search (547 results) also surfaces ultralytics_yolo_dental 1.0.1 (AGPL-3.0, YOLO dental image analysis, not a chart) and toothpik (an app, not a library). flutter_tooth_chart is also a tooth-level chart (not a selector) and the only one with an occlusal-view rendering, which the claim misses. India-vs-global lens: the claim is purely about a global package registry and makes no India-specific assertion, so no conflation issue; none of the packages implement India-specific notation (FDI/ISO 3950 is what Indian dental schools and the DCI use, and three of the four support it). Note: WebSearch budget for this run was exhausted, so the two required fresh WebSearch queries could not be run; all findings come from direct WebFetch of pub.dev and GitHub pages.

</details>

### 24. `corrected` · confidence high

Open-source dental PMS landscape (checked 2026-10-11): DentalPin (github.com/dentalpin/dentalpin): 86 stars, 79 forks, 1,731 commits on main; Business Source License 1.1 with Licensor Wikiparty Labs S.L., Change Date "four years from the date the Licensed Work is published" (relative, not a fixed calendar date), Change License Apache 2.0; Additional Use Grant allows production use "provided that you do not use it to provide a commercial Software-as-a-Service (SaaS) offering for dental clinic management where the primary value is substantially derived from the Licensed Work". Stack: FastAPI (Python 3.11+) + SQLAlchemy + PostgreSQL 15 + Nuxt 4/Nuxt UI, JWT auth. The modules catalog lists 59 modules (not 64), tagged official or community, including odontogram v0.3.0 (emits odontogram.tooth.updated and odontogram.surface.updated events), periodontogram, orthodontics, treatment_plan, recalls, recall_reminders, budget (handles acceptance/rejection/signature -- there is no separate "budget approvals" module), billing (emits invoice events -- there is no separate "invoices" module), india_gst (v0.1.0, official), razorpay (v0.1.0, official), whatsapp_kapso and whatsapp_webhook (v0.1.0, community), gdpr (v0.1.0, official), plus EU-specific modules (verifactu, sdi_it, sistema_ts). It ships an agentic LLM copilot module with PHI tokenization (names, phones, emails, IDs redacted before the LLM provider; on by default) and is "Backed by Dentaltix". No GitHub release is published. OpenDentist (github.com/clawnify/OpenDentist): MIT, 21 stars, 6 forks, 13 commits on master; React 19 + Vite + TypeScript + Tailwind v4/shadcn, Hono on Cloudflare Workers with D1; FDI odontogram via biomathcode/react-odontogram; README positions it as "an alternative to CareStack and Archy for solo practices, group practices, and DSOs" (repo topic: dentrix-alternative) -- it is an early-stage, US-oriented project. OpenMolar (openmolar.com; github.com/rowinggolfer/openmolar1, 55 stars, 1,444 commits): GPL-3+ ("version 3 of the License, or any later version"); OpenMolar1 is Python 3 / Qt5 / MySQL-MariaDB and "is no longer utilised in practice, although development continues as a hobby project"; OpenMolar2 (PostgreSQL, plugin architecture) is "effectively a dead project" (never ported to Python 3/Qt5). Origin: started by UK dentist Neil Wallace of Academy Dental Practice, Inverness, Scotland, out of dissatisfaction with an established UK supplier; the stated sources do not mention the NHS, so "UK NHS origin" should read "UK (Scottish) private-practice origin". Star/commit counts are point-in-time GitHub figures and will drift. India relevance: DentalPin is the only one of the three with India-specific modules (india_gst, razorpay, WhatsApp) and an "India GST demo clinic" seed, but its BSL explicitly forbids using it as the basis of a commercial dental-clinic SaaS, so it cannot be forked into a competing Indian SaaS product before the Change Date; OpenDentist (MIT) can be, but has no India-specific features.

**Why it matters:** DentalPin's BSL blocks us from reusing its code as SaaS, but its module list (GST, Razorpay, WhatsApp, recalls, budgets) is a ready-made India feature checklist and a signal a funded competitor is eyeing India. OpenDentist's MIT code is small but its D1 schema.sql is freely reusable. Nothing in this space is mobile-first or Flutter.

Sources:
- https://github.com/dentalpin/dentalpin
- https://raw.githubusercontent.com/dentalpin/dentalpin/main/docs/modules-catalog.md
- https://github.com/clawnify/OpenDentist
- https://openmolar.com/
- https://raw.githubusercontent.com/rowinggolfer/openmolar1/master/LICENSE
- https://raw.githubusercontent.com/dentalpin/dentalpin/main/LICENSE
- https://openmolar.com/about
- https://github.com/rowinggolfer/openmolar1

<details><summary>Fact-check notes</summary>

Verified by fetching every stated source plus the DentalPin LICENSE and the openmolar1 GitHub repo (WebSearch budget for this turn was exhausted, so no fresh searches could be run; findings rest on direct fetches of primary sources). CORRECT: DentalPin 86 stars / 1,731 commits, BSL 1.1 -> Apache 2.0 after 4 years, FastAPI + SQLAlchemy + PostgreSQL 15 + Nuxt 4, Dentaltix backing, copilot with PHI redaction, odontogram v0.3.0, presence of india_gst, razorpay, whatsapp_kapso, whatsapp_webhook, gdpr, periodontogram, orthodontics, treatment_plan, recalls; OpenDentist MIT / 21 stars / 13 commits / React 19 + Hono + Cloudflare Workers + D1 / react-odontogram FDI / "alternative to CareStack and Archy"; OpenMolar GPL-3+, Python 3/Qt5/MySQL, OpenMolar1 "no longer utilised in practice", OpenMolar2 "effectively a dead project". WRONG or imprecise: (1) module count -- docs/modules-catalog.md has exactly 59 module entries (summary table rows = ### sections = 59) and states no total; "64" is unsupported. (2) "budget approvals" and "invoices" are not modules; the modules are `budget` (acceptance/rejection/signature) and `billing` (invoice events). (3) The BSL exclusion is narrower than "commercial dental SaaS": it bars a commercial SaaS for dental clinic management "where the primary value is substantially derived from the Licensed Work"; licensor is Wikiparty Labs S.L.; Change Date is relative to publication date. (4) "UK NHS origin" -- openmolar.com attributes the project to Neil Wallace, Academy Dental Practice, Inverness, Scotland, motivated by dissatisfaction with an established UK supplier; neither openmolar.com nor the GitHub repo mentions the NHS. (5) "per-tooth and per-surface events" is a paraphrase of event names odontogram.tooth.updated / odontogram.surface.updated -- acceptable but not verbatim. India-vs-global: the claim does not conflate, but omits the key India-relevant consequence that DentalPin's BSL blocks its reuse as a commercial Indian dental SaaS, while the only MIT option (OpenDentist) is US-positioned with no India features.

</details>

### 25. `confirmed` · confidence medium

Generic open-source EHRs have no usable dental charting: OpenEMR's interface/forms directory (35 form types) contains no dental, tooth or odontogram form, and community threads from 2010 to 2026 show users hand-building dental charts and struggling with table design ('Dental (database) problem', 'How to use open emr for dental practice'); GNU Health's documented module list (Laboratory ... Surgery, Imaging, ICU, NTD) shows no dentistry module; Bahmni's wiki has no reachable dental module page. openEHR's only dental archetype, CLUSTER.exam-tooth.v0 (Heather Leslie, 2019, CC BY-SA 4.0), is still 'in_development': tooth label is free text (examples ISO '13', Palmer '3', Universal '6'), findings have a Surface enumeration (Mesial, Distal, Buccal, Lingual, Incisal, Occlusal), pocket depth 0-10 mm, and no mobility element.

**Why it matters:** Confirms the niche thesis empirically: 'all-doctor' platforms never got dental charting right. The openEHR surface enumeration and SNOMED 38199008 'Tooth' reference are reusable vocabulary, but no open data model exists to adopt wholesale, so we define the canonical one.

Sources:
- https://api.github.com/repos/openemr/openemr/contents/interface/forms
- https://community.open-emr.org/search.json?q=dental%20chart
- https://docs.gnuhealth.org/his/userguide/modules/index.html
- https://raw.githubusercontent.com/openEHR/CKM-mirror/master/local/archetypes/cluster/openEHR-EHR-CLUSTER.exam-tooth.v0.adl
- https://api.github.com/repos/openemr/openemr/contents/interface/modules/custom_modules
- https://community.open-emr.org/search.json?q=dental%20order%3Alatest
- https://community.open-emr.org/t/25122.json
- https://community.open-emr.org/t/24963.json

### 26. `corrected` · confidence high

Freely licensed tooth-chart artwork on Wikimedia Commons (all verified 11 Oct 2026): Ptnadult.svg (adult full dentition, Palmer notation; public domain, released by Joey-das-WBF; originally uploaded to en.wikipedia 14 Jun 2008; vector version of a Mark Preston image). Ptnchild.svg (child dentition, Palmer notation; NOT public domain: GFDL 1.2+ / CC BY-SA 3.0; same 2008 origin and Preston lineage). 'Deciduous permanent teeth.svg' (CC BY-SA 4.0; uploaded 22 Aug 2025 by Mrmw, author Maksim; bilingual EN/DE via SVG switch elements, German default). The FDI tooth-surface naming diagram is 'Diş-diş.svg' (Turkish/Azerbaijani spelling, not 'Dis-dis.svg', which returns 404): CC BY-SA 4.0, uploaded 9 Jan 2017, author Mürsəl Haqverdiyev, labels in Azerbaijani. Also useful and omitted by the original claim: 'FDI-Zahnschema.svg' (FDI two-digit full-arch chart, CC BY-SA 3.0, 2014, revised 5 Jan 2025), 'Universal Numbering System.svg' (CC BY-SA 3.0, 2013), and 'Comparison of dental notations.svg' (Palmer/ISO 3950-FDI/Universal/alphanumeric/paleoanthropology, CC BY-SA 4.0, 25 May 2020). Searches of Commons (file namespace, 'odontogram', 'odontograma', filetype:drawing) return no SVG titled 'odontogram'; the FDI-numbered arch SVGs above are the closest base artwork for an odontogram UI. Note for an India-first product: FDI two-digit notation (ISO 3950) is what Indian dental schools and the DCI curriculum use, so FDI-Zahnschema.svg / the Palmer-only Ptn* files would need relabelling; copyleft (CC BY-SA/GFDL) assets embedded in a proprietary Flutter app require attribution and share-alike on the derivative artwork itself, so the PD Ptnadult.svg is the only attribution-free option.

**Why it matters:** Public-domain Palmer charts can seed marketing/education material; CC BY-SA assets would impose attribution and share-alike on the app's artwork, so for in-app tooth icons either use MIT path data or generate original geometry (toothgen approach).

Sources:
- https://commons.wikimedia.org/wiki/File:Ptnadult.svg
- https://commons.wikimedia.org/wiki/File:Deciduous_permanent_teeth.svg
- https://commons.wikimedia.org/w/index.php?search=%22dental+chart%22+OR+%22tooth+chart%22+OR+%22dentition%22+svg&ns6=1
- https://commons.wikimedia.org/wiki/File:Ptnchild.svg
- https://commons.wikimedia.org/wiki/File:Di%C5%9F-di%C5%9F.svg
- https://commons.wikimedia.org/wiki/File:Dis-dis.svg
- https://commons.wikimedia.org/wiki/File:FDI-Zahnschema.svg
- https://commons.wikimedia.org/wiki/File:Universal_Numbering_System.svg

<details><summary>Fact-check notes</summary>

Fetched the actual Commons file pages. (1) Ptnadult.svg: public domain, author Joey-das-WBF, en.wikipedia upload 14 Jun 2008, "Vector version of ... originally by Mark Preston", Palmer notation — claim correct. (2) Ptnchild.svg: license is GFDL 1.2+ and CC BY-SA 3.0, NOT public domain — claim wrong on license. (3) Deciduous permanent teeth.svg: CC BY-SA 4.0, uploaded 22 Aug 2025 by Mrmw (author Maksim), "translated using SVG switch elements" EN/DE — claim correct. (4) 'Dis-dis.svg' does not exist (HTTP 404; Commons search for intitle:dis-dis finds no tooth file). The real file is 'Diş-diş.svg' (CC BY-SA 4.0, 9 Jan 2017, Mürsəl Haqverdiyev, caption "FDİ standartlarına görə diş səthlərinin adları" = tooth surface names per FDI standards, in Azerbaijani) — claim misnamed the file and omitted that labels are not in English. (5) Commons API searches for 'odontogram*' (filetype:drawing, 0 hits) and 'odontograma' (only an .ogg and a .pdf) confirm no odontogram SVG; but the claim omitted directly relevant FDI/Universal full-arch SVGs in Category:Diagrams of sets of teeth (FDI-Zahnschema.svg, Universal Numbering System.svg) and Comparison of dental notations.svg in Category:Dental diagrams. WebSearch budget for this run was exhausted, so no fresh WebSearch queries could be run; all verification used direct fetches of commons.wikimedia.org pages and its API.

</details>

### 27. `corrected` · confidence high

RECOMMENDED CANONICAL TOOTH MODEL (corrected): Tooth = {dentition: permanent|primary, quadrant: 1-4, position: 1-8 (primary 1-5), supernumeraryIndex?: int}, with the ISO 3950 / FDI two-digit code (11-48 permanent; 51-55, 61-65, 71-75, 81-85 primary) as the stored natural key. FDI is the right default for India and for most countries outside the US, which uses Universal 1-32 / A-T; UK dentists still commonly use Palmer (ISO 3950 is in its 2016 edition). Supernumerary teeth: ISO 3950/FDI defines NO standard code, so "base FDI + index" is a product-specific convention that must be documented as such; map it on output to Universal 51-82 (permanent, base + 50) and AS-TS (primary) exactly as Open Dental stores them, to the Canadian CDHA placeholder 99, and to SNODENT supernumerary concept codes (e.g. 177510D "Supernumerary permanent mandibular left central incisor", Universal 74) — note the HL7 Dental Data Exchange tooth-identification ValueSet gives supernumerary SNODENT entries a Universal designation only, with no ISO designation. Static lookup per tooth: fdi, universal, palmer (quadrant glyph + 1-8 / A-E), snomedId, snodentId (SNODENT is an ADA-owned, licensed vocabulary; SNOMED CT is free in India because India is a SNOMED International member), toothType, rootCount, defaultEruptionAge (rootCount and eruption age are the product's own attributes; the openEHR exam-tooth archetype has no eruption element and is only a v0 / 0.0.1-alpha 'in_development' draft whose tooth label is free text, so cite it as inspiration, not a standard). Surface enum: M, D, O (posterior) / I (anterior), B (posterior) / F or La (anterior), L (mandibular) / P (maxillary), plus V (class V / cervical, used by Open Dental and ADA claim surface codes), ROOT and WHOLE; area types mirror Open Dental's TreatmentArea enum exactly: None, Surf, Tooth, Mouth (claims as 00), Quad, Sextant, Arch, ToothRange, plus the 'AreaAlsoToothRange' flag for Quad/Arch procedures that also need tooth numbers. Note Open Dental itself stores ToothNum in Universal (varchar(2): 1-32, A-T, 51-82, AS-TS) and converts to FDI only for display; storing FDI as the key is therefore a deliberate divergence from Open Dental, justified for an India-first product. Notation is a display concern only; the HL7 Dental Data Exchange IG is at STU1 1.0.0 (2021-11) with a 2.0.0 ballot CI build dated 2025-04-07.

**Why it matters:** This single table + pure conversion functions gives FDI+Universal+Palmer display for free, handles mixed dentition and supernumeraries (the cases where naive systems break), and emits SNOMED/SNODENT codes for FHIR without per-record mapping.

Sources:
- https://en.wikipedia.org/wiki/Dental_notation
- https://hl7.org/fhir/us/dental-data-exchange/ValueSet-tooth-identification-valueset.html
- https://www.opendental.com/OpenDentalDocumentation24-1.xml
- https://raw.githubusercontent.com/openEHR/CKM-mirror/master/local/archetypes/cluster/openEHR-EHR-CLUSTER.exam-tooth.v0.adl
- https://en.wikipedia.org/wiki/FDI_World_Dental_Federation_notation
- https://en.wikipedia.org/wiki/Universal_Numbering_System
- https://build.fhir.org/ig/HL7/dental-data-exchange/ValueSet-tooth-identification-valueset.html
- https://www.opendental.com/manual/procedurecodeedit.html

<details><summary>Fact-check notes</summary>

Core model holds (FDI two-digit key, quadrant/position encoding, Palmer glyph + 1-8/A-E, Universal 1-32/A-T, supernumerary Universal 51-82/AS-TS, SNODENT/SNOMED ids, Open Dental area types), but several specifics are wrong, unsupported by the stated sources, or need qualification:

1. FDI supernumerary scheme is unsupported. Neither en.wikipedia.org/wiki/Dental_notation nor en.wikipedia.org/wiki/FDI_World_Dental_Federation_notation mentions any supernumerary coding in FDI/ISO 3950 (2016 edition cited). The claim's "base FDI + index" is a product invention, not a standard. Real-world practice from the downloaded Open Dental schema (OpenDentalDocumentation24-1.xml, procedurelog.ToothNum): "For supernumerary, add 50 to use 51-82. For supernumerary primary, use AS-TS. For Canadian users, using FDI nomenclature, we use 51 as a placeholder for supernumerary teeth, which is tooth number 99 according to CDHA standards (2/17/2014)." The HL7 ValueSet (build.fhir.org 2.0.0-ballot, 2025-04-07) gives SNODENT supernumerary entries (e.g. 177552D Universal MS, 177510D Universal 74, 177654D Universal 64) a Universal designation but no ISO designation, so no standard FDI->SNODENT supernumerary mapping exists.

2. Open Dental stores Universal, not FDI. Schema: procedurelog.ToothNum is varchar(2) "1-32 or A-T"; toothinitial.ToothNum "1-32 or A-Z. Supernumeraries not supported here yet"; ortho ToothRange "always stored in Universal (1-32) notation... displayed to the user as Palmer". The claim's FDI-key choice is defensible but is not what Open Dental does.

3. TreatArea mirror is incomplete. Actual Open Dental enum TreatmentArea: None=0 (blank on claims), Surf=1, Tooth=2, Mouth=3 ("goes on claims as 00"), Quad=4, Sextant=5, Arch=6, ToothRange=7; plus procedurecode.AreaAlsoToothRange ("If Quad or Arch, then this allows users to also specify a tooth or tooth range. Required by some insurance"). The claim omits ToothRange and the Quad/Arch+tooth-range adjunct. Surf field for areas stores "UL" etc for quadrant, "2" for sextant, "U","L" for arches; US sextants 1-6, Canada 03-08.

4. Surface enum omits V (class V). Open Dental manual procedurecodeedit.html: Veneer graphics show only on "buccal (B) and class five (V) surfaces". The surface set should include V.

5. openEHR archetype is not a usable standard. openEHR-EHR-CLUSTER.exam-tooth.v0: lifecycle in_development, revision 0.0.1-alpha; tooth label is free text with ISO/Palmer/Universal as comment examples only; surface value set is only Mesial, Distal, Buccal, Lingual, Incisal, Occlusal (no Palatal/Facial/Labial); no eruption element. So rootCount/defaultEruptionAge are the product's own fields, not derived from any cited standard.

6. Source currency. Stated HL7 URL is STU1 1.0.0 (Draft as of 2021-11-02, 207 concepts, SNODENT v2.0.0, SNOMED US edition 2021-09, with a warning that the expansion may be missing/invalid codes and a display inconsistency for 161533D). A 2.0.0-ballot CI build dated 2025-04-07 now exists. Wikipedia Dental_notation does not cover supernumerary teeth or surfaces, so it does not support those parts of the claim.

7. India-vs-global: Wikipedia states FDI "is used in most countries except the United States" and the Universal system is "commonly used in the United States"; UK still favours Palmer. No fetched source specifically confirms India (DCI/BDS) usage of FDI — plausible but unverified here. India IS listed as a SNOMED International member (snomed.org/members), so SNOMED CT tooth concepts are usable royalty-free in India; SNODENT (ADA) page returned 403 and its current version/licence terms could not be verified. ISO 3950 page returned 403; 2016 edition taken from Wikipedia.

Limitations: WebSearch budget for this turn was exhausted (0 of the required 2 searches ran); all checks are from WebFetch and a curl download of the Open Dental XML. Open Dental manual pages for tooth nomenclature/surfaces returned 404 at the URLs tried.

</details>

### 28. `corrected` · confidence high

RECOMMENDED CLINICAL RECORD MODEL (design proposal; provenance corrected). The seven-entity shape (ToothState history, Condition/Finding, Procedure, ProcedureCatalog, PerioExam/PerioMeasurement, TreatmentPlan, Recall) is a reasonable product design, but several items are mis-attributed and three are factually wrong as stated:

(1) ToothState history: a time-travelable state enum {present|missing|unerupted|partially_erupted|impacted|implant|retained_primary|extracted|supernumerary} is NOT what Open Dental does. Open Dental's `toothinitial.InitialType` enum (schema 24.1, 2024-06-25) is Missing(1), Hidden, Rotate, TipM, TipB, ShiftM, ShiftO, ShiftB, Drawing, Primary(2), Text(10) — i.e. drawing/placement flags, not clinical eruption status; implants, impaction and extraction are procedures/conditions, and supernumerary teeth are tooth numbers 51-82 / AS-TS. Treat the time-travel ToothState as your own design, not "learned from Open Dental".

(2) Condition/Finding: HL7 Dental Data Exchange IG is v1.0.0 STU1 (FHIR R4 4.0.1, generated 2021-11-02), still the only published version as of Oct 2026, scoped to medical<->dental REFERRAL/consult notes (PIE WG). Dental Condition derives from US Core Condition (code bound to US Core Condition Code, extensible); Dental Finding derives from base FHIR Observation with code=LOINC (required), value=SNOMED/SNODENT "Dental Observation Codes" (extensible), bodySite=Dental Anatomy (preferred, single bodySite only, multi-tooth via SNOMED post-coordination). The IG contains NO ICDAS, mobility, furcation or perio charting; ICDAS 0-6 comes from React-Advanced-Odontogram (v2.6.0, MIT, 78 stars), mobility 0-3 and furcation grades are clinical conventions (Glickman has grades I-IV; I-III is Hamp). Use SNOMED CT (free in India via NRCeS affiliate licence; SNOMED-India NRC) + ICD-10 for coding; ICD-10-CM and SNODENT/CDT are US artefacts.

(3) Procedure: Open Dental `procedurelog.ProcStatus` is TP=1, C=2, EC(ExistingCurProv)=3, EO(ExistingOtherProv)=4, R(Referred)=5, D(Deleted)=6, Cn(Condition)=7, TPi(TP inactive)=8; "A procedure can NEVER be deleted. Status can just be changed to deleted" — this supports the never-hard-delete rule. "accepted" and "in_progress" are NOT Open Dental statuses (acceptance lives on the signed treatment plan). Prosthesis field = blank/I/R + DateOriginalProsth; lab fee is a separate procedurelog row linked via ProcNumLab (Canada); procedure notes are append-only rows in `procnote` with a hash-bound signature — matches the "note never edited" idea.

(4) ProcedureCatalog: Open Dental `procedurecode` has ProcCode, Descript, AbbrDesc, LaymanTerm, TreatArea (0-7), IsHygiene, IsProsth, IsRadiology, PaintType (0-17), PaintText, GraphicColor, MedicalCode, DiagnosticCodes (up to 4 comma-separated ICD-10, e.g. "M26.31,K08.401,K02.51"). Fees are NOT on the code: they live in a separate `fee` table per fee schedule, and recall interval is NOT on the code — it is on `recalltype.DefaultInterval` with `recalltrigger` rows listing which codes trigger a recall. Per-clinic defaultFee and recallIntervalDays on the catalog are your simplification, fine for India (no insurance fee schedules), not Open Dental's model. CDT codes are ADA-owned and US-centric (CDT 2026 current; CDT 2027 in preparation); keep them optional in externalCodes.

(5) Perio: Open Dental `periomeasure` stores one row per tooth per PerioSequenceType {Probing=0, Mobility=1, GingMargin=2 (recession), MGJ=3, Furcation=4, SkipTooth=5, Bleeding=6 (bitflags bleeding 1 | suppuration 2 | plaque 4 | calculus 8), CAL=7 computed never stored}, columns MB,B,DB,ML,L,DL, valid 0-19, -1 = not measured, GM negatives encoded as 100+ (105 => -5). Mobility uses ToothValue (no site). CAL and %BOP are derivable; 2017 AAP/EFP STAGE/GRADE are NOT derivable from probing data alone (need radiographic bone loss, tooth loss due to perio, smoking/diabetes, progression rate) — store them as clinician-entered fields.

(6) TreatmentPlan: Open Dental `treatplan.TPStatus` is Saved=0, Active=1, Inactive=2 (not draft|presented|accepted|superseded); Saved TPs use frozen `proctp` copies, Active/Inactive link live procedures via `treatplanattach`; signature is "bound to the concatenation of the tp Note, DateTP, and to each proctp Descript and PatAmt", with DocNum pointing at the signed PDF, plus DateTSigned, DateTPracticeSigned, SignatureText, SignaturePractice. The frozen-copy + hash-bound signature + PDF design is correctly derived.

(7) Recall: Open Dental `recall` = {PatNum, RecallTypeNum, DateDueCalc, DateDue, DatePrevious, RecallInterval, RecallStatus, IsDisabled, DisableUntilDate, DisableUntilBalance, Priority}; one recall per type per patient; synchronised from trigger procedures with status C/EC/EO. DentalPin (BSL-1.1, Spanish/Dentaltix-backed, FastAPI+Nuxt, 86 stars) models recalls as created/completed/snoozed/cancelled with auto-link to booked appointments, and perio as SEPA-style snapshots — useful event names, but DentalPin is a Spain-first project, not India.

Sources named should be cited as: Open Dental 24.1 schema (note Open Dental is now at 26.1, released 2026-08-06, so re-check against the 26.x XML), HL7 Dental Data Exchange STU1 (2021), DentalPin modules-catalog, React-Advanced-Odontogram v2.6.0.

**Why it matters:** This is the core schema the Flutter app and backend should implement; it is dentist-specific (surfaces, perio sites, prosthesis replacement, treatment-plan snapshots) in exactly the places where generic EHRs fail, and every entity has a known FHIR export target.

Sources:
- https://www.opendental.com/OpenDentalDocumentation24-1.xml
- https://hl7.org/fhir/us/dental-data-exchange/
- https://raw.githubusercontent.com/dentalpin/dentalpin/main/docs/modules-catalog.md
- https://github.com/ZoliQua/React-Advanced-Odontogram
- https://www.opendental.com/site/versions.html
- https://hl7.org/fhir/us/dental-data-exchange/index.html
- https://hl7.org/fhir/us/dental-data-exchange/artifacts.html
- https://hl7.org/fhir/us/dental-data-exchange/StructureDefinition-dental-findings.html

<details><summary>Fact-check notes</summary>

Checked all four stated sources plus Open Dental version page, HL7 IG index/artifacts/profile pages, NRCeS SNOMED page, ADA CDT page, and the React-Advanced-Odontogram README. (WebSearch budget for this run was exhausted, so no fresh search queries could be run; verification relied on primary-source fetches.)

KEY REFUTATIONS:
- Open Dental toothinitial InitialType (downloaded OpenDentalDocumentation24-1.xml, 1.29 MB, and grepped): "Used to track missing teeth, primary teeth, movements, and drawings" with types 0..10 = Missing, Hidden, Rotate, TipM, TipB, ShiftM, ShiftO, ShiftB, Drawing, Primary, Text. No unerupted/impacted/extracted/implant/supernumerary state — supernumeraries are tooth numbers 51-82 / AS-TS in procedurelog. So the ToothState enum is not "learned from Open Dental".
- Open Dental ProcStatus: "Enum:ProcStat TP=1,Complete=2,Existing Cur Prov=3,Existing Other Prov=4,Referred=5,Deleted=6,Condition=7 ... 8- Treatment Plan inactive." No 'accepted' or 'in_progress'. "A procedure can NEVER be deleted. Status can just be changed to 'deleted'" (supports never-hard-delete).
- Open Dental procedurecode has no fee and no recall interval: fees are in the fee table per fee schedule; recall interval is on recalltype ("The interval between recalls") with trigger codes in recalltrigger; recall doc says sync depends on "procedurecode.SetRecall" and procs with status "C, EC, or EO". DiagnosticCodes field holds up to 4 ICD-10 codes, example "M26.31,K08.401,K02.51".
- Open Dental periomeasure: types 0-7 (Probing, Mobility, GingMargin, MGJ, Furcation, SkipTooth, Bleeding bitflags 1/2/4/8, CAL computed "never saved to the db"); "Valid values for all surfaces are 0 through 19, or -1 to represent no measurement taken... Values of 100+ represent negative values (only used for Gingival Margins)". Sites MB,B,DB,ML,L,DL confirmed. Stage/grade not present anywhere; 2017 AAP/EFP staging needs radiographic bone loss/tooth loss, grading needs progression/smoking/diabetes, so "derived stage/grade" is wrong.
- Open Dental treatplan: "Enum:TreatPlanStatus 0 - Saved, 1 - Active, 2 - Inactive"; "Saved treatment plans use proctps, which are copies of the procedure, and will not change after being saved"; signature "bound to the concatenation of the tp Note, DateTP, and to each proctp Descript and PatAmt"; DocNum = "pdf document of the TP at time of signing". Claim's draft|presented|accepted|superseded is its own vocabulary.
- Open Dental current version: 26.1 released 08/06/2026 (25.1 05/29/2025, 25.2 09/09/2025, 25.3 12/23/2025); the cited 24.1 schema dates from 06/25/2024 — stale by 2+ years.
- HL7 Dental Data Exchange IG: "1.0.0 - STU 1", "based on FHIR 4.0.1", "Generated 2021-11-02", sponsored by PIE WG, scope = "bi-directional information exchange between a medical and a dental provider or between dental providers" (referral/consult notes). Profiles: Dental Bundle, Referral Note, Service Request, Consult Note, Condition, Finding, Communication — no Dental Procedure profile. Dental Finding "is derived from Observation" with code bound to LOINC (required), value to SNOMED/SNODENT Dental Observation Codes, bodySite to Dental Anatomy, "only a single Observation.bodySite is allowed". Dental Condition "is derived from USCoreCondition" with US Core Condition Code binding. ICDAS, mobility, furcation, perio: not mentioned anywhere in the IG. Tooth Identification value set is described as "commonly used in the United States" (US Universal numbering) — India uses FDI.
- React-Advanced-Odontogram: exists, MIT, v2.6.0, 78 stars, 312 commits; states "Permanent / primary / implant / missing teeth", "ICDAS / CARS severity", "FDI / Universal / Palmer numbering", perio via LOINC panel 74029-0 at six sites, FHIR R4 export, "WHO ICD-10 always on" with opt-in SNOMED overlay. This, not the HL7 IG, is the origin of ICDAS 0-6 in the claim.
- DentalPin modules-catalog.md: exists; every module BSL-1.1; Odontogram module emits odontogram.tooth.updated / surface.updated / condition.changed / treatment.*; Periodontogram "SEPA periodontal charting — snapshots, probing sites, BoP/PI/CAL indices"; Treatment plan emits created/confirmed/treatment_added/treatment_completed; Recalls emit created/completed/snoozed/cancelled. Repo: 86 stars, 1,731 commits, FastAPI + Nuxt 4 + PostgreSQL 15, topics "spain", "verifactu", "Backed by Dentaltix" — Spain-first, not India.
- India context: NRCeS SNOMED CT page (last updated 2026-03-30) shows SNOMED CT access in India goes through an affiliate licence via MLDS, no mention of dental terminology/SNODENT. ADA CDT page shows CDT is maintained by the ADA Code Maintenance Committee with CDT 2027 in preparation (so CDT 2026 is current); it is a US code set and not an Indian standard.
- Furcation: claim says I-III; the widely used Glickman classification has grades I-IV (Hamp is I-III) — specify which.

</details>

### 29. `corrected` · confidence high

RECOMMENDED INTEROP TARGET LIST (corrected): (a) FHIR R4 4.0.1: confirmed — the ABDM/NRCeS IG v6.5.0 (generated 2025-05-08, labelled "Draft as of 2025-05-08"/"active") and the HL7 US Dental Data Exchange IG are both R4 4.0.1; but note the US Dental IG is STU1 v1.0.0 published 2021-11-02 and has not had a newer release, so treat it as a stale trial-use spec, not an actively maintained target. (b) ABDM profiles OPConsultRecord (Composition.type SNOMED 371530004; sections SNOMED-coded, e.g. ChiefComplaints 422843007, Procedure 371525003), PrescriptionRecord, InvoiceRecord, DiagnosticReportRecord and HealthDocumentRecord (Composition.type SNOMED 419891008 "Record artifact", sections referencing DocumentReference for scanned/unstructured PDFs) — these are Composition-based profiles wrapped in the single ABDM "DocumentBundle" profile, not separate "document bundles". ABDM terminology uses SNOMED CT, LOINC (vitals/body measurements), ICD-10 (not ICD-10-CM) for diagnoses, and the Indian Common Drug Codes national extension. (c) HL7 Dental IG defines exactly seven profiles: Dental Bundle, Dental Referral Note, Dental Service Request, Dental Consult Note, Dental Condition, Dental Finding and Dental Communication. There is NO "Dental Procedure" profile, and Dental Finding is an Observation whose code ValueSet "Dental Observation Codes" draws on SNOMED CT + SNODENT clinical findings (not LOINC); tooth/surface sites use the IG's Tooth Identification / Dental Anatomy / Oral Cavity Area ValueSets. Dental procedures would have to be modelled with a plain FHIR Procedure resource (CDT/SNOMED coded) outside this IG. (d) Terminologies: SNOMED CT (findings, teeth, surfaces); ICD-10 K00-K14 for India (ICD-10-CM only for US); LOINC where applicable; SNODENT under the ADA's no-cost usage licence (harmonised with SNOMED CT, aligned with ICD-10-CM, >7,000 terms, updated every fall); CDT remains an ADA-licensed proprietary code set for US use (licensing terms could not be verified in this check; the stated ADA CDT-licensing URL returned 404). (e) DICOM: intra-oral radiographs have dedicated SOP Classes (Digital Intra-Oral X-Ray Image Storage For Presentation 1.2.840.10008.5.1.4.1.1.1.3 / For Processing ...1.3.1); panoramic (PX) is a Modality code, not a SOP Class — panoramic images use Digital X-Ray Image Storage with Modality=PX; CT/CBCT use CT Image Storage; dental photos use VL Photographic Image Storage (1.2.840.10008.5.1.4.1.1.77.1.4); 3D scans use Encapsulated STL (…104.3), OBJ (…104.4) and MTL (…104.5) Storage; exchange via DICOMweb and FHIR ImagingStudy. (f) WHO "Oral health surveys: basic methods", 5th edition (2013) remains the current WHO survey manual and is the appropriate basis for DMFT/CPI(modified) exports; ICDAS and the 2017 AAP/EFP periodontal classification are reasonable computed-score exports but are not FHIR/ABDM requirements. (g) CSV/PDF-A export of case sheets for medico-legal retention is a sensible design choice, but no DCI rule mandating a specific export format was verified here.

**Why it matters:** Committing to these at design time keeps the India MVP cheap (ABDM-only) while guaranteeing the same data can later satisfy US (Dental IG, SNODENT/CDT) and UK/EU (SNOMED, DICOM) buyers without a remodel, which is the 'globally credible' requirement.

Sources:
- https://nrces.in/ndhm/fhir/r4/index.html
- https://hl7.org/fhir/us/dental-data-exchange/
- https://dicom.nema.org/medical/dicom/current/output/chtml/part04/sect_B.5.html
- https://www.ada.org/resources/practice/dental-standards/snodent
- https://www.who.int/publications/i/item/9789241548649
- https://nrces.in/ndhm/fhir/r4/terminology.html
- https://nrces.in/ndhm/fhir/r4/StructureDefinition-OPConsultRecord.html
- https://nrces.in/ndhm/fhir/r4/StructureDefinition-HealthDocumentRecord.html

<details><summary>Fact-check notes</summary>

Fetched the stated sources directly (web-search budget for this turn was exhausted, so no fresh WebSearch queries could be run). Findings: (1) nrces.in/ndhm/fhir/r4/index.html shows ABDM IG v6.5.0, FHIR 4.0.1, generated/"Draft as of" 2025-05-08; OPConsultRecord, PrescriptionRecord, InvoiceRecord, DiagnosticReportRecord, HealthDocumentRecord are Composition profiles with one DocumentBundle profile — claim (a)/(b) largely holds. OPConsultRecord page confirms SNOMED-coded type (371530004) and sections. HealthDocumentRecord type is fixed to SNOMED 419891008 with DocumentReference entries. NRCeS terminology page lists SNOMED CT, LOINC, ICD-10 (plain, not ICD-10-CM) and Indian drug codes. (2) hl7.org/fhir/us/dental-data-exchange: v1.0.0 STU1, FHIR 4.0.1, generated 2021-11-02; artifacts page lists exactly 7 profiles (Bundle, Referral Note, Service Request, Consult Note, Condition, Finding, Communication). A "Dental Procedure" profile does NOT exist, so claim (c) is partly fabricated. Dental Finding's related ValueSet "Dental Observation Codes" is SNOMED+SNODENT clinical findings; LOINC is not the binding stated for it. ICD-10-CM is not mentioned in the IG. (3) DICOM PS3.4 B.5 lists Digital Intra-Oral X-Ray SOP Classes, VL Photographic, Encapsulated STL/OBJ/MTL, but there is no panoramic (PX) SOP Class; PS3.3 C.7.3 confirms PX and IO are Modality defined terms ("Panoramic X-Ray", "Intra-Oral Radiography"). So "DICOM IO/PX" conflates modality codes with storage SOP classes. (4) ADA SNODENT page confirms a "no-cost usage license", harmonisation with SNOMED CT, alignment with ICD-10-CM, >7,000 terms, updates each fall — claim (d) "SNODENT free" holds. CDT licensing page (ada.org/publications/cdt/cdt-licensing) returned 404; CDT licensing cost not verified. (5) WHO 9789241548649 is "Oral health surveys: basic methods, 5th edition", 2013; no newer edition indicated — (f) holds. India-vs-global: the claim correctly separates CDT/SNODENT/ICD-10-CM as US, but ABDM uses ICD-10 not ICD-10-CM; the US Dental IG is a 2021 trial-use spec with no Indian uptake, so it should be a secondary modelling reference rather than a primary "target". (g) DCI/PDF-A retention mandate unverified.

</details>

## Open questions

- Exact ADA CDT licensing fee for a software vendor (the ADA licensing pages at ada.org returned 403/404 to automated fetch); need a human to request the Content License price list before any US launch.
- Is a copy of the last GPL Open Dental source (<=24.3, Dec 2024) still legally obtainable from a third party, and is there any value in it given GPL incompatibility with a proprietary SaaS? (No GitHub mirrors found.)
- Confirm the current NRCeS SNOMED CT affiliate-license process and that it is free of charge for Indian commercial vendors (membership confirmed; fee wording not fetched).
- Does ABDM/NHA plan any dental-specific HI type or value sets (none in NRCeS IG v6.5.0)? Also whether DiagnosticReportRecord is the right container for OPG/CBCT reports.
- GNU Health is believed to have added a 'dentistry' package with an odontogram around v4.0 (2022), but its public docs module list does not show it; verify on Codeberg. Bahmni dental forms also unverified (wiki page not found).
- WHO Oral Health Surveys 5th-edition PDF was blocked (403); the exact crown/root status codes and periodontal codes should be transcribed from the PDF before implementing DMFT/CPI calculators.
- Whether a standard Indian dental procedure/fee code list exists (IDA, CGHS dental rate list, insurer TPA tariffs) that should seed the procedure catalog instead of CDT.
- Content of ANSI/ADA Standard 1084 Reference Core Data Set (2019), which the HL7 Dental IG depends on; obtaining it would let us claim conformance to the ADA core dental data set.
- SNOMED CT concept IDs for tooth surfaces (the Snowstorm browser API returned 403); need the authoritative list of surface body-structure concepts or a decision to use a local surface code system in FHIR exports.
- Clarify the data model of DentalPin's odontogram/periodontogram modules (its docs point to backend/app/modules/odontogram/CLAUDE.md) purely as competitive reference, given BSL 1.1 forbids code reuse for SaaS.
