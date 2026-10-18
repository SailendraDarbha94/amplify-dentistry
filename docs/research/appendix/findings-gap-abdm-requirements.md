# Findings: ABDM/NHA official requirements for a dental-clinic software vendor (sandbox exit, HPR/HFR for dentistry, DHIS Corrigendum 7, NHCX, mandate trajectory, dental data standards)

Raw research output from the multi-agent sweep (October 2026). Each finding carries a verification tag:

- `gap-fill-unverified` (15): from the gap-fill round; not fact-checked

## Summary

Method note: the per-turn web-search budget was already exhausted when this task started, and sandbox.abdm.gov.in/docs and devforum.abdm.gov.in were returning 503/connection-refused, so everything below was pulled directly from official primary sources by URL: the Strapi CMS APIs that power abdm.gov.in (https://abdm.gov.in/strapicms/api/...), the sandbox CMS (https://sandboxcms.abdm.gov.in/api/...), NHA PDFs (DHIS scheme, Operational Guidelines, Corrigenda 3/4/7, HFR SOP OM), the NMC's 28-Feb/3-Mar/17-Jul-2026 ABDM notices, the NHPR portal bundle (nhpr.abdm.gov.in), NRCeS FHIR IG 6.5.0 pages, MLDS release-package records, CERT-In's empanelment list and 25-Jul-2025 audit policy, and dciindia.gov.in. State dental council sites could not be reached and no search was possible, so state-level HPR mandates remain unverified.

Sandbox-to-production is now firmly a v3, four-milestone, five-gate process. NHA's own text (relayed verbatim in NMC's 3-Mar-2026 Annexure-I and in the sandbox CMS "Sandbox Entry & Exit" page) defines M1 ABHA creation/verification, M2 HIP linking via HIE-CM, M3 consent-based HIU, and M4 native HPR/HFR flows, and the gates as third-party Functional Testing (nine named NHA-empanelled agencies, chargeable, max 7 working days), CERT-In/STQC WASA "Safe-to-Host" certificate (separately for web, Android and iOS; re-done on major changes; CERT-In policy requires at-least-annual audits), internal NHA demo, Health Tech Committee demo, then production client-id/secret. There is no official "any two milestones" shortcut: the exit form is filed per milestone, but NHA's "Become ABDM Enabled" matrix requires M1+M2+M3+HFR for an HMIS/clinic app, and DHIS eligibility for a clinic requires integration "till M3". M1 implementations on v1/v2 APIs are no longer accepted, callback servers must be India-based with NHA NAT IPs whitelisted, and all 8 HI types (including InvoiceRecord) are mandatory for the HMIS category.

Dentistry is a first-class citizen in the registries: HPR lists "Dentistry" as a system of medicine with eleven dental specialities and states that a dentist's application is verified by the State Dental Council; HFR offers "Dental Clinic/Dental College/Dental Hospital" facility types with a "Number of Dental chairs" field and makes the Clinical Establishments Act ID optional. The National Dental Register itself now lives at ndr.abdm.gov.in (NDC quick link), mirroring the NMC's NMR, which is the strongest signal that NDC-side mandates will follow NMC's. DHIS Corrigendum 7 (9 Apr 2026, valid Apr–Sep 2026) explicitly covers private clinics and DSCs, pays Rs 5/record (clinic) and Rs 2.5/record (DSC) for OPConsult/Prescription/Invoice above 100 KYC-linked records per month, requires a valid WASA and full v3 compliance from July 2026, and caps at Rs 5 crore. For a solo dental clinic the money is trivial (roughly Rs 500–1,500/month); the real value of M1/M2 is the mandate trajectory (NMC already names non-compliant private colleges; NHA's 2026 Model District programme targets "all health facilities, public and private") and the AB PM-JAY/NHCX pathway, which is mostly irrelevant to general dentistry.

Recommendation: GO for building M1 (v3) and M2 (HIP, 8 HI types, FHIR R4 per NRCeS 6.5.0) plus native HFR/HPR (M4) in the sandbox during the first 90 days, but plan the exit (FT + WASA + HTC) to land in days 90–150 and defer M3 to months 4–6, because M3 is what unlocks the "ABDM-enabled HMIS" listing and DHIS. Encode tooth-level findings today as SNOMED CT Condition/Procedure/Observation entries with bodySite = SNOMED tooth-structure concepts inside OPConsultRecord; adopt the SNOMED International Odontogram and General Dentistry Diagnostic refsets (July-2026 editions on MLDS, free under the India affiliate licence) rather than waiting for an NRCeS dental artefact, which does not exist.

## Findings

### 1. `gap-fill-unverified` · confidence high

NHA's current sandbox-exit process (CMS page 'Sandbox Entry & Exit' behind sandbox.abdm.gov.in/sandbox/v3, mirrored in NMC's 3-Mar-2026 Annexure-I) is: M1 ABHA creation & verification; M2 health-record linking & exchange through HIE-CM (HIP); M3 consent-based sharing (HIU); M4 creation & verification of healthcare professionals and facilities (native HPR/HFR). Production certification = FT (third-party functional testing) -> WASA (CERT-In empanelled Web Application Security Assessment) -> Internal demo to NHA Integration Support -> HTC (Health Tech Committee) demo -> go-live approval, then client-id/secret for production emailed. Exit form must attach FT certificate & reports, WASA certificate, Undertaking (hard copy by post) and GSTIN certificate. No 'any two milestones' rule exists in any official text; the exit form is filed 'for the milestone for which you have received go ahead for HTC', and NHA's 'Become ABDM Enabled' matrix requires M1+M2+M3+HFR for 'HMIS Applications – used by hospitals' (M1+M2+HFR for LMIS). M1 built on v1/v2 APIs is no longer accepted: 'Implementation with only V3 APIs is acceptable for milestone-1'.

**Why it matters:** Decides scope: a dental PMS that wants to be listed as an ABDM-enabled HMIS and to claim DHIS must eventually do all of M1, M2, M3 and native HFR/HPR; M1+M2 alone yields production keys for those milestones but not the HMIS listing. Build everything on v3 from day one.

Sources:
- https://sandboxcms.abdm.gov.in/api/newmenus?populate=deep
- https://nmc.org.in/whats-new/download/950
- https://sandbox.abdm.gov.in/sandbox/v3/new-documentation?doc=SandboxExit
- https://sandbox.abdm.gov.in/sandbox/v3/new-documentation?doc=ABDMCompliant

### 2. `gap-fill-unverified` · confidence high

NHA-empanelled functional-testing agencies (nine, chargeable): AKS Information Technology Services (info.cert@aksitservices.co.in, 7290058951); Avasure Technologies (jaiveen.mehta@avasuretechnologies.com, 9820058628); AQM Technologies (sanjay.parikh@aqmtechnologies.com, 8291858027); Code Decode Labs (abdm-cert@codedecodelabs.com, 9011459161); ESF Labs (sivarama@esflabs.com, 9963971531); FIME India (salesindia@fime.com, 080-43358036); Oxygen Consulting Services (sanjiv.agarwala@o2csv.com, 9890302009); Nangia & Co LLP (pushpendra.bharambe@nangia.com, 9892950303); Suma Soft (abdm@sumasoft.com, 8828222799). NHA rule: 'total duration for the functional testing/evaluation should not exceed beyond 7 working days from the date of onboarding'; the FT report must be in NHA's standard template or it is rejected; after NHA approves the FT report an internal demo is scheduled. Sandbox-entry SLA: the Sandbox Committee 'meets only once a week... expect minimum of 7 days turnaround' (older guide: 3-4 days; abdm.gov.in FAQ: max 5 working days). Fees are not published by NHA.

**Why it matters:** Gives the exact vendor shortlist and a hard 7-working-day FT clock to plan around; budget must be obtained by quotation (NHA publishes no tariff). Treat market estimates of roughly INR 1–3 lakh per milestone bundle as unverified.

Sources:
- https://sandboxcms.abdm.gov.in/api/menus?populate=deep
- https://sandbox.abdm.gov.in/sandbox/v3/new-documentation?doc=testing_agencies_contact
- https://sandbox.abdm.gov.in/sandbox/v3/new-documentation?doc=ABDMSandboxSignup
- https://abdm.gov.in/strapicms/api/faqs

### 3. `gap-fill-unverified` · confidence high

WASA requirements per NHA sandbox FAQs: security testing 'from any STQC or CERT-IN empaneled agency' producing a 'Safe-to-Host' certificate; WASA is required separately 'for IOS app, WASA for android app and for website'; it is conducted on the staging URL and licensed to the same production application; it must be redone for 'critical or major' code changes or add-on modules (minor changes exempt); if one module is built after another, WASA covers only the new module. CERT-In's Comprehensive Cyber Security Audit Policy Guidelines v1.0 (25-Jul-2025) require audits 'at least once in a year' and the report must certify the web application and backend are free of exploitable vulnerabilities; DHIS Corrigendum 7 treats WASA as expiring and renewable (illustrations of a WASA 'expired as on April 1, 2026'). CERT-In's empanelled-auditor PDF currently lists ~221 organisations numbered to 236 (e.g., AAA Technologies Mumbai, AKS IT Noida, AQM Technologies Mumbai, Allied Boston Noida). CERT-In itself publishes no 'Safe to Host' term or fee; typical market cost for a small SaaS surface is roughly INR 0.5–3 lakh per application and is NOT from an official source.

**Why it matters:** A Flutter product means three WASA certificates (web, Android, iOS), an annual renewal cycle, and a freeze on 'major' backend changes between certification and HTC demo; this is the largest recurring compliance cost line.

Sources:
- https://sandboxcms.abdm.gov.in/api/faqs?populate=*
- https://www.cert-in.org.in/PDF/Comprehensive_Cyber_Security_Audit_Policy_Guidelines.pdf
- https://www.cert-in.org.in/PDF/Empanel_org.pdf
- https://www.cert-in.org.in/s2cMainServlet?pageid=CERTEMPANEL
- https://abdm.gov.in/strapicms/uploads/DHIS_corrigendum_7_c1d7e09cc2.pdf

### 4. `gap-fill-unverified` · confidence high

2025–2026 technical changes captured in NHA's 'Integrator Guide – ABDM ABHA V3 APIs' FAQ v1.4 (20-Nov-2025): all 8 HI types (Prescription, DiagnosticReport, OPConsultation, DischargeSummary, ImmunizationRecord, HealthDocumentRecord, WellnessRecord, Invoice) are mandatory for the HMIS category; sandbox base URLs https://dev.abdm.gov.in/api (session, M2/M3), https://abhasbx.abdm.gov.in/abha/api (M1), production https://apis.abdm.gov.in/api and https://abha.abdm.gov.in/api/abha; X-CM-ID 'sbx' vs 'abdm'; REQUEST-ID must be a UUID; Aadhaar/mobile encrypted with RSA/ECB/OAEPWithSHA-1AndMGF1Padding using the public-cert API; sandbox limit of 100 ABHA creations per client ID (error ABDM-1227); max 6 ABHA addresses per ABHA number; HIP link token valid 6 months and >3 generate-token calls/day for the same ABHA blocks for 24h; care contexts cannot be unlinked; callback URL must be a domain (no IP/port), the server must be India-based and NHA NAT IPs 13.203.243.253, 13.203.245.166, 65.0.113.207, 14.143.232.140 whitelisted; on-notify must be answered within 60s; FHIR bundles validated with validator_cli 6.2.1 against -ig https://nrces.in/ndhm/fhir/r4; a facility (HFR ID) may hold multiple Bridge IDs, each yielding its own HIP ID (e.g., IN0710000001, IN0710000001_1). Facilities register/link software in sandbox at https://hspsbx.abdm.gov.in/home and in production at https://nhpr.abdm.gov.in/home via 'Software Linkage'.

**Why it matters:** Directly shapes the data model and infra: India-resident hosting is non-negotiable for M2, HIP IDs must be stored per facility-bridge pair, link tokens cached with 6-month TTL, and the PMS must emit InvoiceRecord as well as OPConsult/Prescription to pass FT.

Sources:
- https://sandboxcms.abdm.gov.in/uploads/FAQ_20_11_2025_808a25df64.pdf
- https://nrces.in/ndhm/fhir/r4/index.html

### 5. `gap-fill-unverified` · confidence high

HPR explicitly supports dentists: the NHPR portal states 'Doctors from all the system of medicines (Modern medicine, Dentist, Ayurveda, Unani, Siddha, Sowa-Rigpa, Homeopathy), Nurses and Pharmacists can be part of the HPR', offers 'Dentistry' as a System of Medicine with specialities Oral Medicine & Radiology, Oral & Maxillofacial Surgery, Periodontology, Conservative Dentistry, Endodontics, Prosthodontics, Pedodontics, Orthodontics, Oral Pathology, Implantology, Community Dentistry, and says 'a dentist's application will be verified by the State Dental Council' (Council Verifier) plus a State/Work verifier for government employment. Required inputs visible in the portal: Aadhaar e-KYC, degree certificate (latest), registration certificate (latest) with council name/number/dates, name-change proof if names differ; query/decline reasons include 'Incorrect Registration number', 'Registration Expired', 'Name mismatch on Aadhaar and Registration Certificate'. Registration is free. NHA's admin dashboard tracks a 'Pending More Than 15 Days' report, but no public SLA is stated. The National Dental Register is hosted at https://ndr.abdm.gov.in (linked from dciindia.gov.in), i.e., NDC's register runs on ABDM/HPR infrastructure, as NMC's NMR does at nmr-nmc.abdm.gov.in.

**Why it matters:** The product can capture and verify HPR IDs for dentists today (store HPR ID + State Dental Council registration number + validity date), and should expect NDC to mandate HPR/NDR enrolment of all BDS/MDS practitioners the way NMC did via NMR.

Sources:
- https://nhpr.abdm.gov.in/nhpr/v4/assets/index-7a48ab1a.js
- https://abdm.gov.in/strapicms/api/faqs
- https://dciindia.gov.in/
- https://ndr.abdm.gov.in/

### 6. `gap-fill-unverified` · confidence high

HFR explicitly supports dental facilities: facility types include 'Dental Clinic', 'Dental College', 'Dental Hospital' (alongside 'Clinic/Dispensary'), System of Medicine 'Dentistry', and an infrastructure field 'Number of Dental chairs'. Registration is self-declared on submission, free, and verified later by state-appointed District Verifiers and NHA National Verifiers per the 19-Jun-2024 HFR Verification SOP; the HFR API treats the Clinical Establishments Act ID (ceaId), NIN and AB-PMJAY ID as optional fields, so CEA registration is not a precondition. As of Jun 2024, 23,954 facilities were pending DV verification (Maharashtra 5,351; UP 5,212; AP 1,868; Kerala 833; Karnataka 919; Arunachal Pradesh 83). NHA FAQs say HFR/HPR enrolment is voluntary, but once a private facility joins ABDM 'healthcare professionals in that facility will also be required to get registered on the HPR'.

**Why it matters:** Onboarding flow for a clinic can create/verify its HFR ID (type 'Dental Clinic', ownership 'Private', chairs count) in minutes with no CEA licence, but verification latency is state-dependent, so the app must work in 'self-declared' status and poll for 'Approved'.

Sources:
- https://abdm.gov.in/strapicms/api/dhis-faqs
- https://nhpr.abdm.gov.in/nhpr/v4/assets/index-7a48ab1a.js
- https://abdm.gov.in/strapicms/uploads/OM_SMD_HFR_0b51a50adf.pdf
- https://sandboxcms.abdm.gov.in/api/menus?populate=deep
- https://abdm.gov.in/strapicms/api/faqs

### 7. `gap-fill-unverified` · confidence high

DHIS Corrigendum 7 (NHA F.No. S-12021/070/2022-ABDM(Coord), 9 Apr 2026, signed Vikram Pagaria) is effective April–September 2026 and follows corrigenda of 16-Mar-2023, 29-Jul-2023, 13-Dec-2023, 11-Jun-2024, 19-Feb-2025 (Corr. 5, utilisation certificates) and 20-Nov-2025 (Corr. 6). Eligibility: 'all public and private sector entities (Health Facilities, Digital Solution Companies (DSCs) etc.)'; FAQ lists 'hospitals, clinics, labs, diagnostic centers and pharmacies'. Threshold stays at 100 transactions/month; only records linked to KYC-verified ABHA addresses count; Scan & Share and health-locker uploads earn nothing. Rates above 100: Category 1 (DiagnosticReport/DischargeSummary) Rs 10 to facility, Rs 5 to DSC; Category 2 (Prescription, OPConsultation, Immunization, HealthDocument, Wellness, Invoice) Rs 5 to facility, Rs 2.5 to DSC; the 100-record deduction removes the lowest-value records first. Consent-based sharing: Rs 10 to HIU, Rs 5 to each HIP/private locker (auto-consent excluded; HIP=HIU excluded). Scan & Pay Rs 5 facility / Re 1 DSC. UHI Rs 5 each to EUA and HSPA. AB PM-JAY claims via NHCX: Rs 200 or 10% of claim (lower) to facility, Rs 10 to DSC, capped Rs 1 crore. Limits: 1 transaction/ABHA/day and 5/month per category; Rs 5 crore cap per entity; back-dated claims only 3 months; Rs 2,500 minimum-disbursal rule removed. For a 'Health Facility/Clinic' transactions count only on a system integrated 'till M3 stage'; labs/pharmacies need M2 only. DSC must have a valid WASA (transactions before WASA ineligible; payouts from the month after certification) and must be v3-compliant on M1, M2 and M3 by June 2026 (Category-2 rates Apr–Jun; no incentives at all from July 2026 until compliant). DSC eligibility also requires 10 facilities linking records in a month.

**Why it matters:** A private single-dentist clinic is eligible, but a realistic 300 KYC-linked OPConsult/Invoice records a month yields about Rs 1,000 to the clinic and Rs 500 to the vendor, so DHIS is a marketing talking point, not a revenue line; worse, it is only claimable with M3 and v3 WASA-certified software, which argues against rushing M1/M2 solely for incentives.

Sources:
- https://abdm.gov.in/strapicms/uploads/DHIS_corrigendum_7_c1d7e09cc2.pdf
- https://abdm.gov.in/strapicms/api/dhis-faqs
- https://abdm.gov.in/strapicms/uploads/Digital_Health_Incentive_Scheme_550e710e09.pdf
- https://abdm.gov.in/strapicms/uploads/Operational_Guidelines_DHIS_0500f58100.pdf
- https://abdm.gov.in/strapicms/uploads/Corrigendum4_11062024_vf_4d37d5408c_01ee0141a6.pdf

### 8. `gap-fill-unverified` · confidence high

DHIS mechanics and payment record: facilities register via the HFR portal (bank details, PAN, cancelled cheque, Mandate Form, Annexure-4 undertaking, eSign), DSCs via the Sandbox portal; claims are filed monthly in HFR/Sandbox and NHA's FAQ says payment is 'generally processed within approximately 45 days, subject to the availability of funds'; the original scheme allows proportionate pay-outs if the budget is exhausted in a cycle; utilisation certificates apply only to public facilities (exempt up to Rs 1 lakh; 25% utilisation proof for Rs 1–50 lakh; 75% above; claims nullified if no UC within 9 months). A record created in a non-ABDM FHIR-capable tool, or a prescription merely sent over WhatsApp, does not qualify: 'Only FHIR compliant format is not eligible'; the record must be generated by ABDM-enabled software and linked to a KYC-verified ABHA address as a care context via the HIP APIs. An OPConsultRecord or PrescriptionRecord bundle linked by a dental PMS qualifies as a Category-2 transaction.

**Why it matters:** If DHIS is offered to clinics, the PMS must implement care-context linking of every OPConsult/Prescription/Invoice automatically at visit close, keep the ABHA KYC flag, and expose a monthly claim helper; WhatsApp delivery of the PDF is irrelevant to eligibility.

Sources:
- https://abdm.gov.in/strapicms/api/dhis-faqs
- https://abdm.gov.in/strapicms/uploads/Operational_Guidelines_DHIS_0500f58100.pdf
- https://abdm.gov.in/strapicms/uploads/DHIS_corrigendum_7_c1d7e09cc2.pdf

### 9. `gap-fill-unverified` · confidence medium

Mandate trajectory (medical side, official): NMC public notices of 28-Feb-2026 (submit HFR IDs and HMIS details within 7 days), 03-Mar-2026 (integrate attached hospitals' HMIS with the ABDM-HMIS portal within 15 days; ABHA generation/linking for OPD/IPD patients is a Minimum Standard Requirement) and the 17-Jul-2026 Office Memorandum that names non-compliant UG/PG colleges, including private ones, for failing 'M2 milestone (ABHA integration), HFR/HPR mapping, M3 milestone (advanced data sharing), and incomplete data in HRL and/or Scan & Share', with action threatened by MARB; NHA contact Mr Narendra Singh, pm.adoption@nha.gov.in. NHA's Aug-2026 DO to medical colleges and the Mar-2026 'Model District' letter ('implement ABDM across all health facilities (both public and private) in the district') extend pressure to private facilities. Dental side: dciindia.gov.in notices through 8-Oct-2026 contain no ABDM/ABHA/HPR directive; no NDC, MoHFW or state notification mandating ABDM at private dental clinics was found; the NDC's national register already runs on ABDM (ndr.abdm.gov.in). State dental council sites (AP, Kerala, Karnataka, Tamil Nadu, Telangana, Maharashtra) were unreachable, so the reported AP HPR mandate and Kerala/Haryana pushes remain unverified. NABH: no ABDM-integration requirement found in the sources reached.

**Why it matters:** There is no legal obligation on private dental clinics as of Oct 2026, but the NMC pattern (register -> HFR IDs -> ABDM-HMIS -> name-and-shame) is the template NDC is positioned to copy; a dental-college module (M2/M3/HRL/Scan & Share compliant) could be an early institutional wedge.

Sources:
- https://nmc.org.in/whats-new/download/1808
- https://nmc.org.in/whats-new/download/950
- https://nmc.org.in/whats-new/download/951
- https://nmc.org.in/whats-new/download/947
- https://abdm.gov.in/strapicms/api/state-communications
- https://dciindia.gov.in/

### 10. `gap-fill-unverified` · confidence medium

NHCX relevance for dentistry is low today: NHA's NHCX portal (nhcx.abdm.gov.in) is wired to the PM-JAY provider/UMP stack (apisprod.nha.gov.in/pmjay/hcx, ump.pmjay.gov.in) and DHIS Corrigendum 7 incentivises only 'AB PM-JAY insurance claim transactions ... filed by Health Facilities using FHIR format through NHCX' (Rs 200/claim or 10%, Rs 10 to the DSC). The NRCeS IG carries the NHCX claim profiles (hcx-profile.html) and 'Benefit Category/ProductOrService' value sets, so the data model can accommodate claims later. No official source ties PM-JAY, CGHS or ESIC empanelment of dental clinics to ABDM/NHCX; sandbox docs note HFR accepts an optional AB-PMJAY hospital ID. The 2023 scheme's HCX clause said 'The HCX platform is currently under development'.

**Why it matters:** Defer NHCX; keep an Invoice/ChargeItem model aligned to the NRCeS InvoiceRecord profile so a future cashless-dental or corporate-insurance claim path can be added without re-modelling billing.

Sources:
- https://nhcx.abdm.gov.in/main.js
- https://abdm.gov.in/strapicms/uploads/DHIS_corrigendum_7_c1d7e09cc2.pdf
- https://abdm.gov.in/strapicms/api/dhis-faqs
- https://nrces.in/ndhm/fhir/r4/profiles.html
- https://sandboxcms.abdm.gov.in/api/menus?populate=deep

### 11. `gap-fill-unverified` · confidence high

NRCeS FHIR Implementation Guide for ABDM v6.5.0 (generated 2025-05-08) defines 7 clinical Composition profiles (OPConsultRecord, PrescriptionRecord, DiagnosticReportRecord, DischargeSummaryRecord, ImmunizationRecord, HealthDocumentRecord, WellnessRecord) plus InvoiceRecord, 35 resource profiles and 48 value sets; none is dental-specific and no tooth-numbering or odontogram value set exists. OPConsultRecord (type fixed to SNOMED 371530004) has optional sections Chief Complaints (Condition), Physical Examination (Observation), Allergies, Medical History (Condition/Procedure), Family History, Investigation Advice (ServiceRequest), Medications (MedicationRequest/Statement), Follow-up (Appointment), Procedure, Referral (ServiceRequest), Other Observations (Observation), DocumentReference (PDF/images). The ABDM Condition and Procedure profiles both expose bodySite (0..*) with coding.system fixed to http://snomed.info/sct and an example binding to the SNOMED body-site value set; Condition.code is sliced for ICD-10 and SNOMED CT systems.

**Why it matters:** Tooth-level charting should be encoded today as Condition (e.g., SNOMED dental caries/pulpitis) or Procedure (e.g., root canal, extraction) entries whose bodySite carries the SNOMED tooth-structure concept (SNOMED has per-tooth 'structure of permanent maxillary right first molar tooth'-style concepts mappable to FDI notation), with the odontogram image/PDF attached via DocumentReference; store FDI numbers internally and map to SNOMED at bundle time.

Sources:
- https://nrces.in/ndhm/fhir/r4/index.html
- https://www.nrces.in/ndhm/fhir/r4/StructureDefinition-OPConsultRecord.html
- https://www.nrces.in/ndhm/fhir/r4/StructureDefinition-Condition.html
- https://www.nrces.in/ndhm/fhir/r4/StructureDefinition-Procedure.html
- https://www.nrces.in/ndhm/fhir/r4/terminology.html

### 12. `gap-fill-unverified` · confidence high

Dental terminology exists at SNOMED International level and is distributed through NRCeS/MLDS: the 'SNOMED CT General Dentistry Diagnostic refset package' (MLDS 133814, URI http://snomed.info/sct/718292005) and the 'SNOMED CT Odontogram refset package' (MLDS 173263; procedures, body structures, findings, disorders for odontogram implementations) both have July-2026 v1.0 releases published 2026-09-25 (RF2, ~48 KB and ~42 KB) and are listed on NRCeS's resources page under National Refsets. India-specific extensions available are the India Drug Extension (31-Aug-2026), India Patient Instructions Language Extension (31-Aug-2026), India AYUSH Extension (29-Jun-2026) and India Reference Sets (2021); none is dental. NRCeS's HCIT Standard Registry lets vendors self-declare standards compliance.

**Why it matters:** Adopt the Odontogram and General Dentistry refsets as the product's clinical pick-lists (diagnoses, procedures, tooth structures) so bundles are SNOMED-coded from day one and are globally portable (same refsets are used by UK/US/AU dental systems).

Sources:
- https://mlds.ihtsdotools.org/api/releasePackages/173263
- https://mlds.ihtsdotools.org/api/releasePackages/133814
- https://www.nrces.in/resources
- https://www.nrces.in/registries/hcit-standard-registry

### 13. `gap-fill-unverified` · confidence high

SNOMED CT licensing for a commercial Indian vendor: an Affiliate Licence is mandatory ('Yes you still need to procure license for SNOMED CT' even though MoHFW 'has made SNOMED CT freely available for all use within India'); process = register on MLDS India landing (https://mlds.ihtsdotools.org/#/landing/IN), choose Usage Type 'Commercial – Developer, Vendor or Terminology provider', agreement type 'Affiliate – Normal', accept the 2023 Affiliate License Agreement; download access in 4–5 business days; no fee for use in India or any Member country; each customer deployment needs a sub-licence and the affiliate must file an annual usage report; apps used outside India need an International Affiliate Licence (fees apply only in non-Member countries). C-DAC's CSNOtk v8.0 (May 2024) is the free integration toolkit.

**Why it matters:** Zero licence cost in India and in most target markets (US, UK, EU Members, Middle East Members), but the vendor must track per-clinic sub-licences and report usage yearly; obtain the international affiliate licence before any non-India deployment.

Sources:
- https://www.nrces.in/faqs
- https://www.nrces.in/standards/snomed-ct
- https://nrces.in/download/files/pdf/nrces_sct_licensing.pdf
- https://sandboxcms.abdm.gov.in/api/faqs?populate=*
- https://sandboxcms.abdm.gov.in/api/toolkit

### 14. `gap-fill-unverified` · confidence medium

Go/No-Go for the first 90 days: GO on building M1 (v3 ABHA create/verify incl. ABHA-address verification and Scan & Share token flow) and M2 (HIP: HIP-initiated and user-initiated linking, 8 HI-type FHIR bundles, ECDH data push) plus native HFR/HPR (M4) in the sandbox, with the exit (FT + WASA + HTC) realistically closing in days 90–150 and M3 scheduled for months 4–6. Itemised estimate: sandbox application ~1 week (committee weekly); engineering M1 ~3–4 weeks, M2 ~6–10 weeks, M4 ~2 weeks (NHPR FT is done by the NHPR team, write abdm.texp1@nha.gov.in / facility.abdm@nha.gov.in); FT ≤7 working days plus quotation (unpublished; budget roughly INR 1–3 lakh, low confidence); WASA 2–4 weeks per surface x3 (web, Android, iOS; budget roughly INR 1.5–6 lakh total, low confidence, renewed annually); HTC demo scheduling unpublished (plan 2–4 weeks); India-resident hosting with whitelisted NHA IPs and a domain-based callback. Verify production via NHA's test facility 'Integrator Testing Lab' (HFR ID IN0110005723). Total compliance cash reserve for year one: roughly INR 3–10 lakh (vendor quotes required), excluding engineering.

**Why it matters:** Sets the roadmap and budget line: ABDM M1/M2 belongs in the first release cycle because it costs mostly engineering time, but the certification gates should not block the commercial launch of the core dental workflow.

Sources:
- https://sandboxcms.abdm.gov.in/api/newmenus?populate=deep
- https://sandboxcms.abdm.gov.in/uploads/FAQ_20_11_2025_808a25df64.pdf
- https://sandboxcms.abdm.gov.in/api/faqs?populate=*
- https://abdm.gov.in/strapicms/api/faqs

### 15. `gap-fill-unverified` · confidence high

Official NHA contact routes relevant to a dental PMS vendor: integration.support@nha.gov.in (sandbox integration, FT grievances, HIU reference-app access); devforum.abdm.gov.in (technical queries, quote client-id); abdm.incentive@nha.gov.in / abdm.incentives@nha.gov.in (DHIS); dir.coord@nha.gov.in (Vikram Pagaria, Director ABDM, signs DHIS corrigenda); pm.adoption@nha.gov.in (Narendra Singh, adoption/HMIS integration named in NMC notices); facility.abdm@nha.gov.in and abdm.texp1@nha.gov.in (NHPR/M4 functional demo); pml.coord@nha.gov.in and facility@nha.gov.in (HFR verification); grievance.abdm.gov.in. NHA's 2026 ecosystem moves that compete with or complement a clinic PMS: NHA–C-DAC MoU (Aug 2025) for a 'light HMIS' for small/medium providers and NHA's Feb-2026 letter promoting 'eSushrut Clinic' adoption; NMC also points colleges to NIC NextGen eHospital and C-DAC eSushrut.

**Why it matters:** Provides the escalation map for the unresolved items and flags that a free government clinic HMIS (eSushrut Clinic) is being pushed to states, so differentiation must come from dental-specific depth rather than ABDM compliance alone.

Sources:
- https://abdm.gov.in/strapicms/api/faqs
- https://abdm.gov.in/strapicms/uploads/Operational_Guidelines_DHIS_0500f58100.pdf
- https://nmc.org.in/whats-new/download/1808
- https://sandboxcms.abdm.gov.in/api/newmenus?populate=deep
- https://abdm.gov.in/strapicms/api/state-communications
- https://abdm.gov.in/strapicms/api/whats-news

## Open questions

- Functional-testing and WASA fees: NHA publishes no tariff; obtain written quotes from at least three of the nine FT agencies and two CERT-In auditors for a Flutter (web+Android+iOS) + NestJS backend scope before budgeting (route: the agency contacts above; grievances to integration.support@nha.gov.in).
- HTC scheduling SLA: no published turnaround from Exit-form submission to HTC demo and production keys; ask integration.support@nha.gov.in or post on devforum.abdm.gov.in (site was unreachable during this research).
- Whether NHA still accepts an exit for M1+M2 only for a 'Clinic – No IPD' MVP 4.0 category application and lists it as ABDM-enabled without M3; the 'Become ABDM Enabled' matrix says HMIS needs M1+M2+M3+HFR (confirm with integration.support@nha.gov.in).
- State-level HPR/HFR mandates for dentists (Andhra Pradesh, Kerala, Haryana, Rajasthan, Karnataka, Maharashtra, Tamil Nadu, Telangana): state dental council and state NHM/ABDM SMD sites were unreachable and search was unavailable; verify via each State Dental Council notice board and the state ABDM SMD office (NHA letter 12-Aug-2024 'Engagement of Councils ... across all systems of medicine' is image-only and could not be text-extracted).
- NDC intent: dciindia.gov.in shows no ABDM/HPR circular through 8-Oct-2026 and the NDR runs on ndr.abdm.gov.in; confirm with NDC (ndc@dciindia.gov.in / RTI) whether NDR enrolment or ABHA capture will be made mandatory for registered dentists or dental colleges, mirroring NMC's 2026 notices.
- What comes after DHIS Corrigendum 7 (valid only to Sep 2026): no Corrigendum 8 was found on abdm.gov.in CMS as of 11-Oct-2026; monitor https://abdm.gov.in/DHIS and the dhis-faqs CMS feed, and ask abdm.incentive@nha.gov.in.
- DHIS payment-delay reporting: NHA's FAQ states ~45 days post-approval 'subject to availability of funds'; press reports of delays could not be checked without search.
- HPR verification turnaround for dentists by state dental councils: NHA tracks 'pending >15 days' internally but publishes no SLA; sample by registering 2–3 dentists (e.g., Arunachal Pradesh and Andhra Pradesh councils) and timing approval.
- NRCeS position on a dental HI type or India dental refset: no artefact exists in IG 6.5.0 or the national refsets; ask NRCeS (contact form on nrces.in) whether an Indian dental/odontogram refset or FHIR guidance is planned and whether tooth bodySite coding via SNOMED is their recommended approach.
- PM-JAY/CGHS/ESIC dental empanelment and NHCX: no official link between ABDM/NHCX and dental empanelment was found; confirm with the state SHA (AB PM-JAY) and CGHS whether HFR ID or NHCX participation is required for dental packages.
- Sandbox 'cut off date' after which only empanelled FT agencies may test: the CMS text references a cut-off without a date; confirm it has passed (likely) with integration.support@nha.gov.in.
