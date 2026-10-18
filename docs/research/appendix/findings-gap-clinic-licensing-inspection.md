# Findings: Indian dental clinic licensing and inspection compliance stack: AERB/eLORA radiation registration, state Clinical Establishment laws, Bio-Medical Waste authorisation, NABH DHSP Section B and NABH CMS digital standards

Raw research output from the multi-agent sweep (October 2026). Each finding carries a verification tag:

- `gap-fill-unverified` (15): from the gap-fill round; not fact-checked

## Summary

Method note: the web-search budget for this run was already exhausted, so everything below was pulled directly from primary-source PDFs and portals by URL (AERB, CPCB, clinicalestablishments.mohfw.gov.in, KPME Karnataka, AP APMCE portal, NABH S3 documents, CDSCO). Kerala, Tamil Nadu and Maharashtra state portals were unreachable (403/timeouts), so those three state regimes remain gaps (see open questions).

Radiation (AERB). Every dental X-ray unit (intra-oral, handheld, OPG, CBCT) must be registered/licensed through eLORA under Rule 3 of the Atomic Energy (Radiation Protection) Rules 2004; AERB runs a simplified dental module (institute registration, then equipment registration for Indian-made units or procurement+registration for imports) and charges no fee. RSO approval is mandatory only for CT/interventional radiology; a dental registrant can designate themself as RSO, and TLD personnel monitoring is "recommendatory" for dental users in the eLORA dental guideline (SC-3 still says all radiation workers get personnel monitoring, so OPG/CBCT clinics should budget for it). Periodic QA by an AERB-authorised agency is required at least once every two years and after any safety-relevant repair, in the prescribed dental test-report format (kVp +/-5 kV, timer <=10% error, filtration, mA linearity CoL<0.1, output CoV<0.05, tube leakage <0.25 mGy/h intra-oral and <1 mGy/h OPG/CBCT, plus CBCT contrast and CTDIw tests). eLORA has forms for QA Test Summary, periodic Radiation Survey Report, Safety Status Report (requires an operational-status update every 6 months), licence renewal before expiry, and Intimation + Confirmation of Decommissioning. AERB's 2024 annual report counts 30,557 licensed dental units out of 82,049 diagnostic-radiology institutions and 33,973 DR licences/registrations issued in 2024; it also found ~90% of ~1,000 >10 mSv dose reports (mostly diagnostic radiology) were "non-genuine" due to TLD badge misuse, which is a direct product hook for a badge-custody log.

Clinic registration. Arunachal Pradesh is a Clinical Establishments Act 2010 state (in force 1 Mar 2012): a single-dentist clinic registers with the District Registering Authority via the national portal, provisional registration is by self-declaration, permanent registration awaits category-wise minimum standards, and the Arunachal fee is Rs 1,000 for clinics (Rs 3,000 imaging centre) paid to the "Arunachal Pradesh State Council for CEA" account. Critically, no "Minimum Standards for Dental Clinic" has been notified under the CEA; the portal's dental page carries only Mobile Dental Van and Dental Lab drafts, and the only gazetted minimum standards are for diagnostic labs (2018/2020). Karnataka's KPME portal registers "Dental Lab or Clinic (DEN)" for Rs 6,300 with Aadhaar e-sign, an uploaded Schedule of Charges and an Internal Grievance Redressal field, and a Taluk Health Officer inspection with an online checklist; Telangana replaced its APMCE rules with the Telangana Clinical Establishments Rules 2022 (DRA, provisional/permanent, Rs 100/day late-renewal penalty, mandatory medical records and quarterly returns); Andhra Pradesh still runs the APMCE Act 2002 portal with a dedicated "Dental Clinics/Hospitals" category and "Clinics (Solo Practitioners)" tier.

Bio-medical waste and NABH. Under BMW Rules 2016 (amended 2018/2019; no later amendment is cited by CPCB's 2024 report) a non-bedded dental clinic needs a one-time Form II authorisation from the SPCB (deemed granted after 90 days), a CBWTF agreement if within 75 km, bar-coded colour-coded bags (mandatory since 27 Mar 2019), a daily category-wise BMW register (clinics under 30 beds may rely on CBWTF receipts), Form IV annual report by 30 June published on its own website, 24-hour accident reports, annual training and staff health-check/immunisation records, all retained 5 years. CPCB's 2024 report shows 3,18,022 non-bedded HCFs, 14,783 show-cause notices/directions in 2024 (up from 8,082), and lists of never-authorised "small clinics, dispensaries" being forwarded to health departments in Karnataka, Kerala, Maharashtra, TN, Telangana, AP and Arunachal; the NGT-mandated compensation scale starts at Rs 1,200/day with closure after 60 days of non-compliance, and "no CBWTF arrangement" carries the highest risk weight. NABH DHSP 3rd edition (April 2023) Section B (1-15 chairs: 80 standards, 416 OEs, 77 core) specifies exactly the logs an inspection-ready module must emit: unique-ID dental records with signed/dated/timed entries within one hour (IMS.3), defined retention and documented destruction (IMS.6), periodic record audits (IMS.7), a consent-required procedure list with named dentist and risks/benefits/alternatives (PRE.4, COP.8), displayed tariff and written estimates (PRE.6), daily physical/chemical and weekly biological sterilisation tests with per-load numbering (IPC.6), colour-coded BMW handling (IPC.4), an AERB-aligned radiation-safety programme with TLDs and QA records (AAC.12), monthly documented facility rounds (FMS.1), 2-yearly electrical audits (FMS.3), equipment inventory and logs (FMS.4), and an Annexure-3 licence list (fire NOC, BMW authorisation, drug licence, AERB approvals for OPG unit and room layout, TLD badges). NABH's Digital Health Standards for Clinic Management Systems (effective 17 Sep 2025; 32 standards/112 OEs; Basic = 100% core/60% commitment/30% achievement, Advanced = 100/80/60/60%) require prior NHA-ABDM approval and are scoped to allopathic clinics, so a dental CMS can target them but is not explicitly in scope.

Obligation table (solo-clinic applicability | record the app must produce | periodicity | retention | state variation):
1. AERB registration/licence of each dental X-ray unit (AE(RP)R 2004 r.3; eLORA dental guideline) | Y | equipment register with eLORA registration certificate, type-approval model, supplier/QA agency, protective accessories, leakage values | once per unit; renew before expiry | life of unit + decommissioning record | none (central).
2. AERB periodic QA + radiation survey (SC-3 Rev 2; dental QA format) | Y | QA test report in AERB format, QA Test Summary submission, survey report, signed/stamped layout (OPG/CBCT) | every 2 years and after repair; QA report valid 6 months for licence filing | until next QA at minimum (AERB does not state years) | none.
3. RSO designation, TLD/PMS, Safety Status Report, operational status | Y (self-RSO allowed; TLD recommendatory for IOPA, expected for OPG/CBCT) | RSO nomination, TLD badge issue/return log, dose records (transfer on exit), SSR | operational status every 6 months; SSR as per licence conditions | dose records: career-long per SC-3 6.2.3/6.2.9 | none.
4. Clinical Establishment registration | Y (single doctor covered) | certificate, renewal diary, staff/qualification list, schedule of charges, grievance mechanism, medical records + returns | provisional then permanent; renewals per state (Telangana Rs 100/day late penalty) | records "as per state authority" (NABH IMS.6) | Arunachal CEA 2010 Rs 1,000 clinic fee; Karnataka KPME Rs 6,300; Telangana Rules 2022; AP APMCE 2002; Kerala/TN/Maharashtra not verified.
5. BMW authorisation Form II + CBWTF agreement | Y (one-time for non-bedded) | authorisation copy, CBWTF agreement, pickup receipts | one-time; amend on change | 5 years | SPCB-specific portals (unverified).
6. Daily BMW register, bar-code labels, Form IV annual report, Form I accident report, training, health check/immunisation, BMW committee minutes | Y | daily category-wise kg log, bar-code bag IDs, Form IV by 30 June (publish on website), accident log, training attendance, health-check/immunisation record | daily; annual; 24 h on accident | 5 years | none (central rules); enforcement intensity varies.
7. NABH DHSP Section B (voluntary) | Y (1-15 chairs) | all logs above plus consent register, sterilisation validation log, monthly facility-round checklist, electrical audit, equipment inventory, record audit | daily/weekly/monthly/2-yearly as listed | per clinic policy consistent with state rules | none.
8. Drugs dispensing (D&C Rules Sch. K item 5) | Y if dispensing to own patients | drug purchase register (name, qty, batch, manufacturer) open to inspection | per purchase | not specified in Schedule K | none.
9. Fire NOC, Shops & Establishment/trade registration, lifts | depends on building/state | licence copies with expiry | per licence | per licence | state/municipal.
10. PC-PNDT | N (no ultrasound/prenatal diagnostics in dental) | none | - | - | -.

## Findings

### 1. `gap-fill-unverified` · confidence high

All dental X-ray equipment (intra-oral stand/wall-mounted, handheld, OPG/cephalometric and dental CBCT) requires a licence/registration from AERB through eLORA before patient use, under Rule 3 of the Atomic Energy (Radiation Protection) Rules 2004; AERB runs a dedicated eLORA dental module (Step 1 institute registration; Step 2 registration of indigenous equipment, or procurement application for imported equipment; Step 3 registration of imported equipment) that emails a registration certificate downloadable from 'My Casefile', and AERB charges no licence or processing fee. AERB's 2024 annual report counts 30,557 licensed dental units (intra-oral, OPG, CBCT) across 82,049 diagnostic-radiology institutions, with 33,973 DR licences/registrations issued in 2024.

**Why it matters:** The equipment module should model each unit with eLORA registration number, type-approved model, serial/year, authorised supplier/QA agency and certificate PDF, and should warn that zero fees are payable (AERB explicitly flags agents demanding 'AERB fees' as fraud). ~30k registered dental units is the addressable base for a radiation-compliance feature.

Sources:
- https://www.aerb.gov.in/images/PDF/dentalguidelines05082019.pdf
- https://www.aerb.gov.in/images/PDF/DiagnosticRadiology/e-LORA-Diagnostic-Radiology-Guidelines.pdf
- https://www.aerb.gov.in/english/regulatory-facilities/radiation-facilities/application-in-medicine/diagnostic-radiology
- https://www.aerb.gov.in/images/PDF/Annual_report/ar2024/English/Annual_report-2024-eng.pdf

### 2. `gap-fill-unverified` · confidence high

RSO approval from AERB is mandatory only for CT and interventional radiology; for all other X-ray equipment (including dental) the registrant 'may designate himself as RSO', and the eLORA dental guideline says 'one person from your institute should be designated as RSO' and that the PMS (TLD) number is 'recommendatory for dental users'. Safety Code AERB/RF-MED/SC-3 (Rev. 2, March 2016) nonetheless requires personnel monitoring for all radiation workers, dose records to be maintained and transferred between employers (6.2.3, 6.2.9, 6.3.3), and periodic verification of protective devices. AERB's 06.07.2026 handheld X-ray guideline states TLD badges are not mandatory for low-dose handheld use but a Licence (Registration) and 2-yearly QA still are.

**Why it matters:** The app needs an RSO field per clinic (default = owner dentist), an optional TLD/PMS badge register (issue, quarterly return, dose result) that becomes strongly recommended when an OPG/CBCT is registered, and a career dose-record export on staff exit.

Sources:
- https://www.aerb.gov.in/images/PDF/DiagnosticRadiology/e-LORA-Diagnostic-Radiology-Guidelines.pdf
- https://www.aerb.gov.in/images/PDF/dentalguidelines05082019.pdf
- https://www.aerb.gov.in/images/PDF/DiagnosticRadiology/Safety-Code-for-Diagnostic-Radiology.pdf
- https://www.aerb.gov.in/images/PDF/Handheld-advisory.pdf

### 3. `gap-fill-unverified` · confidence high

AERB requires periodic Quality Assurance of dental X-ray equipment 'at least once in two years and also after any repairs having radiation safety implications', performed only by AERB-authorised agencies in the prescribed 'Performance Test Report for Dental X-ray Equipment' format: operating potential +/-5 kV, irradiation-time error <=10%, minimum total filtration (1.5/2.0/2.5 mm Al by kVp), timer linearity and mA/mAs linearity CoL <0.1, output consistency CoV <0.05, tube-housing leakage <0.25 mGy/h (intra-oral) or <1 mGy/h (extra-oral) at 1 m, plus for dental CBCT low-contrast (3 mm hole), high-contrast (1.5 lp/mm) and CTDIw within +/-20%, and a radiation protection survey with a calibrated survey meter. A QA report older than 6 months cannot support a licence application; periodic QA results are filed through the eLORA 'QA Test Summary' form and layout changes via 'Change in Layout' plus a radiation survey report.

**Why it matters:** This is the concrete spec for the 'radiation log': a per-unit QA due-date engine (24 months, reset on repair), a structured QA result record mirroring the AERB form fields and tolerances, agency name/seal capture, and reminders to file the QA Test Summary on eLORA.

Sources:
- https://www.aerb.gov.in/images/PDF/DiagnosticRadiology/4-PERFORMANCE-TEST-REPORT-FOR-DENTAL-X-RAY-EQUIPMENT.pdf
- https://www.aerb.gov.in/images/PDF/DiagnosticRadiology/3.4.1-Regulatory-requirements-for-diagnostic-radiology-facilities.pdf
- https://www.aerb.gov.in/images/PDF/DiagnosticRadiology/e-LORA-Diagnostic-Radiology-Guidelines.pdf

### 4. `gap-fill-unverified` · confidence high

Ongoing AERB obligations beyond QA are: keep a duly signed and stamped X-ray room layout with shielding details on site ('will be verified during AERB inspection'; layout not required for intra-oral or handheld units, required for OPG/CBCT with shielding per AERB layout guideline, e.g. 22 cm brick at 0.5 m for CBCT/OPG), display the AERB licence conspicuously, update the operational status of every unit on eLORA at least once in 6 months (otherwise the Safety Status Report cannot be submitted), submit the periodic Safety Status Report, renew the licence before expiry (eLORA 2021 guideline has separate renewal forms for new/pre-owned and 'existing declared' equipment), and on disposal file 'Intimation of Decommissioning' followed by the supplier's 'Confirmation of Decommissioning' which flips the unit status to Decommissioned. AERB's 2024 report notes it conducted 424 regulatory inspections of diagnostic radiology facilities in 2024 and warns unlicensed facilities 'shall be sealed without further notice', though its public advisory states it does not routinely inspect low-hazard X-ray facilities.

**Why it matters:** The compliance calendar must carry four AERB timers per clinic (6-month operational-status update, SSR, licence expiry, 2-year QA) and a decommissioning workflow; storing the stamped layout drawing and licence PDF makes the clinic inspection-ready without paper hunting.

Sources:
- https://www.aerb.gov.in/images/PDF/DiagnosticRadiology/e-LORA-Diagnostic-Radiology-Guidelines.pdf
- https://www.aerb.gov.in/images/PDF/DiagnosticRadiology/drg2021.pdf
- https://www.aerb.gov.in/images/PDF/11-Guidelines-SSR.pdf
- https://www.aerb.gov.in/images/PDF/layout_guidelines.pdf
- https://www.aerb.gov.in/images/PDF/Annual_report/ar2024/English/Annual_report-2024-eng.pdf
- https://www.aerb.gov.in/storage/uploads/News/news1pS4c.pdf

### 5. `gap-fill-unverified` · confidence high

AERB's 2024 annual report found that of ~1,000 cases in 2023 where TLD badges recorded >10 mSv, about 90% (1,071 of 1,080 in diagnostic radiology) were 'non-genuine', caused by 'improper use and storage of TLD badges', and AERB launched awareness campaigns and tighter follow-up requiring institutions to submit corrective action plans.

**Why it matters:** A simple TLD badge custody log (who wears which badge, where stored when not worn, return date each quarter) would directly prevent the most common AERB follow-up event for small radiology users; it is cheap to build and highly inspectable.

Sources:
- https://www.aerb.gov.in/images/PDF/Annual_report/ar2024/English/Annual_report-2024-eng.pdf

### 6. `gap-fill-unverified` · confidence high

Arunachal Pradesh is a Clinical Establishments (Registration and Regulation) Act 2010 state (Act in force there from 1 March 2012, together with Sikkim, Mizoram, Himachal Pradesh and the UTs; UP, Bihar, Rajasthan, Jharkhand and Uttarakhand adopted later). The Act covers 'a single doctor' clinic in any recognised system; registration is with the District Registering Authority through the national portal, in two steps: provisional registration by self-declaration without inspection, then permanent registration after category-wise minimum standards are notified. The MoHFW fee table lists Arunachal fees of Rs 1,000 for clinics, Rs 2,000-3,000 for hospitals (by bed band), Rs 2,000 for labs, Rs 3,000 for imaging centres and Rs 1,000 'other', payable to the 'Arunachal Pradesh State Council for CEA' Bank of Baroda account at Naharlagun. The state rules PDF on the portal is a scanned image (not machine-readable).

**Why it matters:** For the founder's own clinic the app should hold the CEA provisional/permanent certificate, the DRA contact, renewal dates, and the fee receipt; the national portal (clinicalestablishments.mohfw.gov.in/portal) is the filing channel, so a 'documents pack' export matching its upload list is the useful feature.

Sources:
- https://clinicalestablishments.mohfw.gov.in/en/faq
- https://clinicalestablishments.mohfw.gov.in/sites/default/files/2023-06/46311.pdf
- https://clinicalestablishments.mohfw.gov.in/sites/default/files/2022-06/416_0.pdf
- https://clinicalestablishments.mohfw.gov.in/sites/default/files/2021-12/969.pdf

### 7. `gap-fill-unverified` · confidence high

No 'Minimum Standards for Dental Clinic' has been notified under the Clinical Establishments Act: the portal's Minimum Standards page lists only the 2018 gazette (minimum standards for medical diagnostic laboratories) and a 2020 HR amendment; the 'Dental Clinic Establishment' page carries only 'Mobile Dental Van' and 'Dental Lab' documents (June 2022 uploads). The national categorisation document defines 'Dental clinics - places where dentists provide dental care with no inpatient facilities' and 'Dental hospitals' (specialties per the Dentists Act), with sub-categories for single-dentist and poly clinics (dental).

**Why it matters:** There is no central equipment/staff/record checklist an inspector can cite for a dental clinic under CEA today, so the app's checklist should be built from NABH DHSP Section B plus AERB and BMW rules, and flagged as 'ahead of regulation' rather than 'mandated by CEA'; watch the portal for a future dental minimum-standards gazette.

Sources:
- https://clinicalestablishments.mohfw.gov.in/en/node/1299
- https://clinicalestablishments.mohfw.gov.in/dental-clinic-establishment
- https://clinicalestablishments.mohfw.gov.in/sites/default/files/2021-09/650_1.pdf

### 8. `gap-fill-unverified` · confidence high

Karnataka registers dental practices under the KPME Act through kpme.karnataka.gov.in as category 'Dental Lab or Clinic (DEN)' (defined as 'places where dentists provide dental care with no inpatient facilities') for Rs 6,300 (vs Rs 3,100 consultation-only clinic, Rs 12,500 imaging centre, Rs 25,000-2,50,000 hospitals). The online application captures Specialities, Ownership, Admin/Manager, Human Resource details, uploaded Certificates/Documents, an 'Internal Grievance Redressal' section and a 'Schedule of Charges', is Aadhaar-OTP e-signed, paid online via Khajane, then inspected by the Taluk Health Officer using an online checklist (plus an uploaded signed manual checklist) before approval; a separate 'Auto Renewal' manual exists. Telangana adopted the central Act and issued the Telangana Clinical Establishments (Registration and Regulation) Rules 2022 (G.O. Ms. 64, 14 June 2022) superseding its APMCE Rules 2007: District Registering Authority, provisional and permanent registration, fees in Annexure-4, Rs 100/day penalty for late renewal, public display of registration details, and Rule 28 requiring clinics to 'maintain medical records of patients treated' and furnish three-monthly reports. Andhra Pradesh still operates the Allopathic Private Medical Care Establishments Act 2002 portal (clinicalesttact.ap.gov.in) with explicit tiers 'Clinics/consultation rooms (Solo Practitioners)' and 'Dental Clinics/Hospitals' and Forms I-XI.

**Why it matters:** State registration is a per-state data model (category code, fee, inspecting officer, renewal cycle, mandatory displayed schedule of charges and grievance mechanism). Karnataka's required 'Schedule of Charges' and grievance fields map directly to a tariff-display feature and a complaints register the app can print for inspection.

Sources:
- https://kpme.karnataka.gov.in/Catg_Fees.aspx
- https://kpme.karnataka.gov.in/Documents/KPME%20categories%20.pdf
- https://kpme.karnataka.gov.in/Documents/KPME%20User%20Manual%20-%20Fresh%20Applications.pdf
- https://clinicalestablishments.mohfw.gov.in/sites/default/files/2022-09/2381.pdf
- http://clinicalesttact.ap.gov.in/
- https://clinicalesttact.ap.gov.in/forms/Andhra_Pradesh_Allopathic_Private_Medical_Care_Establishments_act.pdf

### 9. `gap-fill-unverified` · confidence high

Under the Bio-Medical Waste Management Rules 2016 every clinic 'irrespective of quantity' must obtain authorisation from the SPCB/PCC on Form II; for non-bedded facilities (clinic, dispensary) this is a one-time authorisation, deemed granted if the SPCB does not object within 90 days, and must be re-applied only on change of activities (bedded facilities' validity is tied to Air/Water consents). A clinic within 75 km of a Common Bio-medical Waste Treatment Facility must have a valid CBWTF agreement (specifying pickup, bag and bar-code supply, payment), and anatomical/soiled waste must be treated within 48 hours. CPCB's 2024 report lists the rule amendments as 16.03.2018, 19.02.2019 and 10.05.2019 (no later amendment).

**Why it matters:** Onboarding should capture SPCB authorisation number/date and CBWTF agreement (with expiry), and the app should not nag solo clinics about 'annual BMW renewal' (a common vendor myth) since non-bedded authorisation is one-time.

Sources:
- https://cpcb.gov.in/uploads/Projects/Bio-Medical-Waste/Guidelines_healthcare_June_2018.pdf
- https://cpcb.gov.in/uploads/Projects/Bio-Medical-Waste/AR_BMWM_2024.pdf
- https://cpcb.gov.in/bio-medical-waste-rules/

### 10. `gap-fill-unverified` · confidence high

CPCB's 2018 HCF guidelines spell out the BMW records an inspector expects: a daily category-wise bio-medical waste register/logbook (yellow, red, white/sharps, blue) with weights (HCFs under 30 beds may keep CBWTF-printed receipts instead of their own weighing), bar-coded labels on every bag (mandatory for all HCFs from 27.03.2019; label carries colour mark, SPCB-issued unique HCF number, bag ID), the Form IV annual report submitted to the SPCB by 30 June for the preceding calendar year and also published on the clinic's own website, an accident report to the SPCB within 24 hours of a major accident (and a 'NIL' record otherwise), induction plus annual BMW training records, annual employee health-check and Hepatitis B/tetanus immunisation records, BMW committee minutes, and all BMW records retained for five years. CPCB is now building a national Centralised Barcode System for Tracking BMW (CBST-BMW) portal following Supreme Court directions.

**Why it matters:** This is the exact BMW log spec: daily weight entry per colour, bag-barcode capture (scan the CBWTF label), auto-compiled Form IV (kg/year by category, trainings, accidents, immunisation status), a 30-June reminder, and a public 'BMW annual report' page the clinic can link from its website.

Sources:
- https://cpcb.gov.in/uploads/Projects/Bio-Medical-Waste/Guidelines_healthcare_June_2018.pdf
- https://cpcb.gov.in/uploads/Projects/Bio-Medical-Waste/Guidelines_for_Bar_Code_System_for_HCFs_and_CBWTFs.pdf
- https://cpcb.gov.in/uploads/Projects/Bio-Medical-Waste/AR_BMWM_2024.pdf

### 11. `gap-fill-unverified` · confidence high

BMW enforcement against small clinics is real and rising, though the vendor claim that missing BMW contracts were 'the single most common reason for clinic shutdown notices in 2024-25' could not be verified: CPCB's Annual Report 2024 records 4,56,538 HCFs (3,18,022 non-bedded), 14,783 show-cause notices/directions issued to defaulters in 2024 versus 8,082 in 2023, and states that SPCBs in Andhra Pradesh, Arunachal Pradesh, Karnataka, Kerala, Maharashtra, Tamil Nadu, Telangana and others reported HCFs operating without authorisation, with 'non-bedded HCFs like small clinics, dispensaries etc. never applied for authorization and list of such HCFs are forwarded to State Health Departments'. Under CPCB's NGT-mandated Environmental Compensation scale, 'no arrangement for disposal of BMW with CBWTF' carries the highest health-risk score (30 of 100), 'not applied for authorisation' 10 and 'improper segregation' 20; for a non-bedded clinic the factors are T=0.5 and S=0.15 with a floor of Rs 1,200 per day of violation, doubling after 15 days, quadrupling after 30 days, and 'Closure of HCF' beyond 60 days or on a 4th failed inspection. Arunachal Pradesh reports no CBWTF in the state at all.

**Why it matters:** A compliance dashboard that shows 'authorised + CBWTF agreement + daily log' status is defensible as a shutdown-risk reducer; the app should also handle the Arunachal/remote case (no CBWTF within 75 km, SPCB-approved deep-burial authorisation and pit records) rather than assuming a CBWTF exists.

Sources:
- https://cpcb.gov.in/uploads/Projects/Bio-Medical-Waste/AR_BMWM_2024.pdf
- https://cpcb.gov.in/uploads/Projects/Bio-Medical-Waste/BMW_Guidelines_21.06.2019.pdf
- https://cpcb.gov.in/uploads/Projects/Bio-Medical-Waste/Guidelines_healthcare_June_2018.pdf

### 12. `gap-fill-unverified` · confidence high

NABH Accreditation Standards for Dental Healthcare Service Providers 3rd edition (April 2023; brochure June 2023) splits Section A (dental hospitals/institutes) from Section B 'DHSPs with 1-15 chairs' (80 standards, 416 objective elements, 77 core); implementation for 3 months precedes application, standards cost Rs 2,000, fees run from Rs 5,000 application + Rs 15,000 annual at the smallest tier to Rs 40,000 + Rs 1,50,000 (plus 18% GST), with surveillance in year 2 and re-application in year 4. Section B Information Management OEs: IMS.3 requires a unique identifier per dental record, written authorisation of who may make entries, every entry 'signed, dated and timed' and documented 'no later than one hour of completion' (electronic systems should auto-stamp), an identifiable author with 'authorized e-signature provision as per statutory requirements', and defined record contents; IMS.5 (core) requires confidentiality, integrity (no tampering, controlled corrections) and security of records with role-based access; IMS.6 (core) requires a document-control process, a defined retention period per record category 'in consonance with rules laid down by respective state authority', secure retention and documented destruction; IMS.7 (core) requires periodic clinical-record audits on a statistical sample for timeliness, legibility and completeness with documented corrective actions.

**Why it matters:** These are testable software requirements: immutable audit trail with user/date/time, one-hour entry SLA flags, configurable retention/destruction policy per record type, role-based access, and a built-in record-audit sampler; they also prove a dental-only CMS can be designed around NABH Section B rather than generic EHR norms.

Sources:
- https://nabh-portal-live.s3.ap-south-1.amazonaws.com/wp-content/uploads/2025/07/13105241/Final-Dental-Standard-3rd-Edition.pdf
- https://nabh-portal-live.s3.ap-south-1.amazonaws.com/wp-content/uploads/2025/07/25075419/General-Information-Brochure_DHSP.pdf
- https://nabh.co/dental-healthcare-service-providers/

### 13. `gap-fill-unverified` · confidence high

NABH DHSP Section B clinical-safety OEs that define specific logs: PRE.4 (core) requires a list of procedures needing informed consent and consent that names the performing dentist and covers risks, benefits and alternatives in a language the patient understands; COP.8 requires a documented pre-operative assessment/diagnosis/instructions and consent by the treating dental surgeon before dental surgical procedures; PRE.6 (core) requires a uniform pricing policy, a displayed tariff list and written cost estimates before treatment; IPC.6.d requires documented sterilisation validation with 'physical/chemical tests daily, and biological tests at least weekly', Bowie-Dick and leak-rate tests, a unique number and content description per load and temperature/pressure/time charts; IPC.4.d (core) requires colour-coded BMW segregation per statute with handover to the authorised vendor; AAC.12 requires a quality-assurance and radiation-safety programme per AERB guidelines with TLD badges, periodically tested and documented protective devices, signage and QA/calibration records; FMS.1.c (core) requires documented facility safety rounds at least monthly, FMS.3.b electrical safety audits at least once in two years, and FMS.4.b an inventoried equipment list with logs and retained conformance certificates. Annexure 3 lists the licences a DHSP should hold: fire NOC, BMW authorisation, retail/bulk drug licence if applicable, building permit, AERB approval for the OPG machine and the OPG room layout, TLD badges, lift licences.

**Why it matters:** Together with the AERB and CPCB items, this is the full specification for an 'inspection-ready logs' module: consent templates with mandatory named-operator and alternatives fields, a sterilisation cycle log (daily indicator, weekly spore test, per-load ID), a monthly facility-round checklist, an equipment/AMC register, and a licence wallet with expiries.

Sources:
- https://nabh-portal-live.s3.ap-south-1.amazonaws.com/wp-content/uploads/2025/07/13105241/Final-Dental-Standard-3rd-Edition.pdf

### 14. `gap-fill-unverified` · confidence high

NABH Digital Health Standards for Clinic Management Systems, 1st edition, are effective 17 September 2025: 8 chapters (AAC, COP, MOM, DAC, DOM, FPM, HRM, IMS), 32 standards and 112 objective elements (41 core, 20 commitment, 27 achievement, 24 excellence). Basic Level certification needs 100% core, 60% commitment and 30% achievement OEs; Advanced Level needs 100% core, 80% commitment, 60% achievement and 60% excellence. A CMS must first be evaluated and approved by the National Health Authority for ABDM and security (WASA) before applying; the mandatory module is Clinics/Polyclinics/Dispensaries with optional Daycare, Laboratory, Radiology, Procurement and HRM modules; annexures include registration, case-history, consent-form, MLC and KPI templates. The standard defines 'clinic' as a facility run by doctors registered with the NMC/State Medical Council practising allopathy, and the text never mentions dental, so dental CMS vendors are not explicitly in scope. NABH published CMS test cases in November 2025.

**Why it matters:** A dental CMS can still pursue NABH CMS Basic/Advanced certification as a credibility signal (the OEs are generic), but the sequence is ABDM M1-M3 first, then NABH; the gap in dental scope is also an opportunity to lobby NABH for a dental annexure (as it did for Diabetes and Oncology).

Sources:
- https://nabh-portal-live.s3.ap-south-1.amazonaws.com/wp-content/uploads/2025/09/17165618/NABH-Digital-Health-Standards-for-Clinic-Management-Systems-CMS-1st-Edition-1.pdf
- https://nabh-portal-live.s3.ap-south-1.amazonaws.com/wp-content/uploads/2025/11/03105333/Test-Case-for-NABH-Digital-Health-Standards-for-CMS1st-Edition.pdf
- https://nabh.co/digital-health-standards/

### 15. `gap-fill-unverified` · confidence medium

Other recurring licence items: (a) Drugs dispensed by a dentist to their own patients fall under Schedule K item 5 of the Drugs and Cosmetics Rules 1945 (the Rules' definition of 'registered medical practitioner' includes persons registered under the Dentists Act 1948), exempting the clinic from a retail sale licence provided the practitioner is not keeping an open shop and keeps purchase records showing names, quantities, batch numbers and manufacturers, open to Drugs Inspector inspection; (b) NABH's digital-health FAQ and DHSP Annexure 3 treat a valid 'registration or shop act certificate', fire NOC and lift licences as statutory prerequisites whose currency assessors check; (c) PC-PNDT registration is handled by separate state portals (e.g. pcpndt.ap.gov.in) and is tied to ultrasound/genetic facilities, so it does not apply to a dental clinic without such equipment.

**Why it matters:** The licence wallet should include a drug-purchase register for dispensing clinics (a real inspection item), optional fire NOC/Shops & Establishments/lift entries with expiry reminders, and should explicitly exclude PNDT to avoid false alarms.

Sources:
- https://cdsco.gov.in/opencms/export/sites/CDSCO_WEB/Pdf-documents/acts_rules/2016DrugsandCosmeticsAct1940Rules1945.pdf
- https://nabh-portal-live.s3.ap-south-1.amazonaws.com/wp-content/uploads/2025/07/01104750/Top-10-FAQs_DHS_V1.0.docx.pdf
- https://nabh-portal-live.s3.ap-south-1.amazonaws.com/wp-content/uploads/2025/07/13105241/Final-Dental-Standard-3rd-Edition.pdf
- https://hmfw.ap.gov.in/

## Open questions

- AERB licence/registration validity period for dental units: the eLORA guidelines and SC-3 only say 'renew before expiry'; the number of years printed on dental registration certificates (commonly reported as 5) was not found in any primary document and should be confirmed from an actual eLORA certificate.
- AERB retention period for QA reports, radiation survey reports and TLD dose records at the clinic: SC-3 requires dose records to be maintained and transferred but states no retention duration; need the licence terms-and-conditions text issued on eLORA.
- Whether any 2024-2026 AERB circular specifically targets dental clinics (e.g. on handheld intra-oral units or CBCT RSO requirements): only the 06.07.2026 handheld guideline and the public advisory mentioning dental were found; AERB's notifications page lists no dental-specific notification.
- Karnataka KPME Act 2007/2017 and Rules primary text (patient charter display, fee display, record-keeping and penalty clauses) was not retrieved because the search budget was exhausted and karunadu.karnataka.gov.in was unreachable; the Rs 6,300 fee and application fields come from the portal only.
- Kerala Clinical Establishments Act 2018 and its registration portal (clinicalestablishments.kerala.gov.in returned 403), Tamil Nadu Private Clinical Establishments Act 1997 / 2018 Rules (DMS pages unreachable) and Maharashtra's Bombay Nursing Homes Registration Act (municipal registration) were not read; their single-dentist coverage, fees and mandated registers remain unverified.
- Whether the Arunachal Pradesh state rules (scanned PDF on the CEA portal) add state-specific registers or fees beyond the Central Rules 2012 and the Rs 1,000 clinic fee in the MoHFW table; OCR was not available in this environment.
- Which SPCBs run online BMW authorisation portals for non-bedded clinics (e.g. Karnataka KSPCB, Telangana TSPCB, Arunachal APSPCB) and whether Form IV is filed online: CPCB's report confirms the CBST-BMW national portal is under development but SPCB-level portal status was not verified.
- Primary text of BMW Rules 2016 and the 2018/2019 amendments could not be downloaded from CPCB (PDF links redirect to 404); the Form I/Form II/Form IV contents and 5-year retention are taken from CPCB's 2018 HCF guidelines, which paraphrase the rules.
- Exact mapping of NABH DHSP fee sets to chair tiers (1-3, 4-10, 11-15 chairs) is not stated on the NABH page; confirm with NABH before quoting accreditation cost to clinics.
- Whether NABH will issue a dental annexure to the CMS digital-health standard, and whether a dental-only CMS is accepted for CMS certification given the allopathic 'clinic' definition.
