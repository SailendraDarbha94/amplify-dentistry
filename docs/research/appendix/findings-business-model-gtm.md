# Findings: business-model-gtm

Raw research output from the multi-agent sweep (October 2026). Each finding carries a verification tag:

- `confirmed` (7): passed independent fact-check
- `corrected` (22): fact-checker corrected the claim; text below is the corrected version

## Summary

India is a large, fragmented, software-under-penetrated dental market with a clear price ceiling. DCI lists ~405,000 registered dentists (ORF's Nov-2025 analysis uses 376,721), ~28,000 new BDS seats a year (82% private colleges), a projected surplus of 100,000+ dentists over the next decade, and more than 330,000 standalone practices with fewer than 1% of clinics belonging to chains. Incumbent clinic software is generic and cheap: Practo Ray is ₹999–1,499/clinic/month on annual billing with a 7-day trial; Clinicea is ₹1,999–3,999 per practitioner/month; Dentee (the only dental-only Indian incumbent of note) hides pricing behind a 15-day trial and is estimated at ₹2,000–5,000/clinic/month; Bestosys, Cufront, MocDoc and others cluster at ₹500–2,500/clinic/month; and Open Dental is explicitly free in India. Global dental-only cloud products price 10–50x higher (tab32 $125–225/mo, Open Dental $199→$149/location in the US, Curve ~$350–500/mo, Dentrix Ascend ~$399–800/mo, CareStack $829–1,299/mo, Dentally £125–945/mo by surgery count), which is the long-term prize but not the launch market.

The winning vertical-SaaS playbooks are consistent: own one specialty's clinical workflow (Cloud 9 was "built from the ground up for ortho" and became the category creator, later bought by Planet DDS; Dentally won UK NHS-integrated cloud dentistry and was bought by Henry Schein One), keep pricing flat and simple (Cliniko's $45–395 bands unchanged since 2011, bootstrapped; Jane's CAD 59/79/99 base plus per-license and add-ons), and layer transactional revenue on top of a low or free subscription (Fresha: free core software, monetised through payments, marketplace referral fees and messaging credits; now 130k businesses and a >$1B valuation after KKR's May-2026 round). CareStack, built in Kerala and selling to US practices at $829+/month, with 1,181 employees and ₹100–500 Cr Indian-entity revenue, is the existence proof that an India-built dental SaaS can win globally.

Recommended wedge: solo and 1–3-chair owner-dentist practices in India, led by the first-clinic cohort (interns, fresh BDS/MDS graduates and dentists 0–7 years out) that AmpDent already reaches. Ship a mobile-first (Flutter) dental-specific core: appointment book + odontogram-based treatment plan and tooth-numbered consent templates + WhatsApp reminders/recall + GST invoice with EMI/UPI payment link + lab-case tracking. Price at a free tier (1 doctor, capped patients and WhatsApp credits) → ₹1,499/clinic/month (≈₹14,999/year, undercutting Clinicea per-practitioner pricing and matching Practo Ray's Clinic Management tier) → ₹2,999/clinic/month for multi-doctor, patient app and lab marketplace, with WhatsApp credits (Meta utility cost ₹0.115/message; Fresha retails WhatsApp at ₹1.60–5.50/message in India), payments (Practo takes 1.8–2%) and later lab/supplies marketplace as the real margin. Distribute through the AmpDent student funnel, dental-college alumni and intern cohorts, the IDA's 450 local branches and CDE programme, and the two or three annual shows (IDC with 300+ exhibitors, Famdent/Messe Düsseldorf, IDA's World Dental Show); add dealer and implant-company co-marketing once there is a lab/supplies marketplace to offer them. Expand abroad in the order Indian dentists migrate: Oman/GCC (Dentee already lists Oman; DHA licensing is exam-based with no practical), then UK (53% of new GDC registrants in 2025 were international, ORE scaled to 1,500 passes/year, and IDA itself runs a UK ORE pathway), then Australia.

Caveats: the WebSearch budget ran out partway through; GCC dentist counts, Indian dental-software adoption rates, Dentalkart/Toothlens funding, patient-financing merchant fees, and a formal IP-India trademark check for "AmpDent"/"Amplify Dentistry" remain open.

## Findings

### 1. `corrected` · confidence high

As of 11 Oct 2026 the DCI "Dentists Registered" page shows an all-India IDR count of 405,777 Part-A dentists (plus 167 legacy Part-B; no fresh Part-B registrations since the Dentists (Amendment) Act 1972), compiled "as received from the State Dental Councils... as on till date" with no stated as-of date and no de-duplication across states or removal of deceased/emigrated dentists, so it is an upper bound on practising dentists. ORF's 21 Nov 2025 analysis used an older snapshot of 376,721 and a 2025 population of 1,463,865,525 to state ~1:3,846 (the arithmetic actually gives ~1:3,886). Using the live 405,777 against the same population gives roughly 1 dentist per ~3,600 people (not ~3,850); either way India is well above the 1:7,500 "WHO" ratio commonly cited in Indian dental literature (a figure attributed to WHO in secondary sources rather than a published WHO norm). Top-5 state councils by Part-A registrations are Karnataka (57,125), Maharashtra (55,672), Kerala (37,760), Tamil Nadu (36,824) and Andhra Pradesh (29,000); Uttar Pradesh (27,622) is 6th, followed by Gujarat (24,422) and Punjab (23,436).

**Why it matters:** The TAM is large and geographically concentrated in 5 southern/western states; launch GTM (IDA branches, colleges, dealer visits) should start in Karnataka, Maharashtra, Kerala, TN and the Telugu states where the founder has roots.

Sources:
- https://dciindia.gov.in/DentistRegistered.aspx
- https://www.orfonline.org/expert-speak/dentistry-in-india-oversupply-and-gender-bias-shaping-oral-health-workforce

<details><summary>Fact-check notes</summary>

Fetched both stated sources on 2026-10-11. (1) DCI live page: Total IDR count Part A = 405,777, Part B = 167; state table confirms Karnataka 57,125, Maharashtra 55,672, Kerala 37,760, Tamil Nadu 36,824 — but Andhra Pradesh is listed at 29,000, which ranks 5th, ahead of Uttar Pradesh 27,622. The claim's "top states" list therefore omits AP and wrongly implies UP is 5th. The page carries no as-of date (only "as on till date" and a 2026 copyright) and no note on duplicate multi-state registrations or deceased dentists, so "registered" ≠ "active". (2) ORF article (Damini Bisen, 21 Nov 2025) cites 376,721 DCI-registered dentists, population 1,463,865,525, ratio ~1:3,846 and a WHO 1:7,500 benchmark "for developing countries" via a PubMed link; ORF's own ratio is arithmetically off (376,721 → ~1:3,886). (3) The claim's "~1 per 3,850" is ORF's ratio for 376,721 dentists, not the ratio implied by the 405,777 figure it leads with; 1,463,865,525 / 405,777 ≈ 3,608. Mixing the two denominators overstates the ratio by ~7%. (4) India-vs-global lens: the 1:7,500 figure is a commonly repeated number in Indian dental papers attributed to WHO; I could not locate a primary WHO document establishing it, and WebSearch budget was exhausted this turn so independent cross-checks (and a second fetch of a PubMed source) could not be completed — the benchmark should be labelled "widely cited" rather than an official WHO standard. Core numbers (405,777; four of the five state figures) hold; the top-5 ordering and the ratio are wrong, so refuted=true with corrections.

</details>

### 2. `corrected` · confidence high

India has ~330 BDS-granting dental colleges and ~28,000 BDS seats a year (DCI's own site, as of Oct 2026: 331 BDS colleges, 28,114 permitted BDS seats, 405,961 registered dentists; the ORF Nov-2025 figures of 329 colleges / 27,926 seats are slightly stale). Roughly 82% of COLLEGES are private (269 of 329, incl. 32 deemed) and about 86% of SEATS are private (~24,080 of 28,038 vs 3,958 government seats). The "surplus of 100,000+ dentists over the next decade" is a misdated citation: it comes from Vundavalli (Int Dent J 2014), which projected a ~100,000 oversupply BY 2020 from a 2011 baseline of 117,825 dentists; by the same 1:7,500 WHO norm India already has roughly 2x the "required" ~195,000 dentists today (405,961 registered vs ~1.46bn people, ~1:3,600). The gender figures are weakly sourced: the "70% of registered dentists are women" statistic traces to a single sentence in Tiwari et al. 2019 (Adv Dent Res) attributing it to DCI 2018 data with no primary document, and the "75% of dental students are women" figure is stated by ORF only for "many states", not nationally. Treat as "women are a majority, likely 60-70%+ of recent dental graduates/registrants" rather than a precise national statistic.

**Why it matters:** Every year ~28k new dentists need a first clinic or an associate job; a student-to-owner funnel (AmpDent) is a real acquisition engine. Product and marketing should be designed for women owner-dentists (flexible hours, part-time practice, family-run clinics).

Sources:
- https://www.orfonline.org/expert-speak/dentistry-in-india-oversupply-and-gender-bias-shaping-oral-health-workforce
- https://www.dentalfry.com/bds-course/total-bds-seats-india/
- https://dciindia.gov.in/
- https://vishnunambiar.com/bds-admission/total-bds-seats-india/
- https://pmc.ncbi.nlm.nih.gov/articles/PMC9376410/
- https://pmc.ncbi.nlm.nih.gov/articles/PMC6960321/

<details><summary>Fact-check notes</summary>

1) ORF (Damini Bisen, 21 Nov 2025) states 27,926 BDS seats, 329 colleges, 82% of seats private, "surplus of over 100,000 dentists over the next decade", >70% of registered dentists women (citing Tiwari 2019) and 75% of students women "in many states" (unnamed EBSCO record). 2) DCI homepage (fetched 11 Oct 2026) now shows BDS colleges 331, permitted BDS seats 28,114, MDS seats 7,716, registered dentists 405,961 — so seat/college counts have moved up; DCI gives no public/private split. 3) The second stated source (dentalfry.com) 301-redirects to vishnunambiar.com (updated 3 Oct 2026): 28,038 seats, 329 colleges (315 admitting), 60 government / 269 private colleges, 3,958 government vs ~24,080 private seats — i.e. 81.8% of colleges but ~86% of seats are private, so ORF's "82% of seats" appears to be a college-share misread. 4) The surplus figure: ORF cites ijdrd.com article-165 (fetch 500 error), but the underlying study is Vundavalli S., Int Dent J 2014 (PMC9376410), which uses 2011 Census + DCI data (117,825 dentists end-2011, ~300 colleges, ~24-26k graduates/yr, 2% attrition, 1:7,500 norm) to project ~309,700 dentists and "more than one lakh dentists over supply by the year 2020". It is not a forward projection from 2025; the phrase "over the next decade" is ORF's error. Arithmetic on current DCI data (405,961 dentists / 1.46bn) gives ~1:3,600, already ~210,000 above the 1:7,500 benchmark. 5) Gender: Tiwari et al. 2019, Adv Dent Res 30(3):60-68 (PMC6960321) contains the sentence that women make up 70% of registered dentists in India per DCI 2018, with no primary citation; the paper's abstract actually says women are 30-40% of registered dentists in many Asian countries, so India is an outlier claim resting on one unsourced line. No Europe PMC search returned any peer-reviewed national figure for female share of Indian dental students; the 75% figure is state-level per ORF's own wording. Note: WebSearch budget was exhausted this turn, so verification relied on direct fetches of the stated sources, DCI, PMC and Europe PMC.

</details>

### 3. `confirmed` · confidence medium

Fewer than 1% of Indian dental clinics belong to chains; the market is 330,000+ standalone practices. Clove Dental, the largest chain, has ~715 clinics in 26 cities, ~₹450 Cr FY26 revenue, clinics breaking even at ~₹4.75 lakh/month and maturing at ~₹10 lakh/month on ~₹40 lakh capex.

**Why it matters:** Chains are a tiny, well-funded segment that builds or buys enterprise systems; the volume wedge is the solo/small practice. Clove's unit numbers also bound willingness to pay: a mature clinic earning ₹10 lakh/month can justify ₹1,500–3,000/month software (0.15–0.3% of revenue), a new one earning ₹1–2 lakh cannot justify much more than ~₹1,000.

Sources:
- https://www.healthcare-in-india.net/dental-surgery/dentistry-in-india-future-opportunities-entrepreneurship/
- https://www.forbesindia.com/article/news/deep-dive/clove-dentals-prescription-for-scale/2993977/1
- https://www.clovedental.in/
- https://dciindia.gov.in/

### 4. `confirmed` · confidence high

Practo Ray (generic clinic software, India's reference price) lists CM Atom at ₹999/month and Clinic Management at ₹1,499/month on 1-year billing (₹999 on 4-year), with 3,000–8,000 free SMS, unlimited doctors on the higher tier, a 7-day free trial, and a payments product taking 1.8–2% per transaction.

**Why it matters:** This is the price anchor Indian dentists already know: ~₹1,000–1,500 per clinic per month, not per doctor. A dental-only product can charge at or slightly above this only if it is visibly more dental (odontogram, consents, lab tracking) and bundles WhatsApp instead of SMS.

Sources:
- https://www.practo.com/providers/clinics/ray/plans
- https://www.saasworthy.com/product/ray-by-practo
- https://www.practo.com/providers/clinics/ray
- https://www.saasworthy.com/product/ray-by-practo (returned HTTP 403, not verified)

### 5. `corrected` · confidence high

Clinicea (multi-specialty, "20+ specialities", dental is one of many; built by Technolarity) lists on clinicea.com/pricing, as of 2026-10-11, INR-only pricing billed per practitioner per month: Starter ₹1,999, Pro ₹2,999, Enterprise ₹3,999. Add-ons: Patient Portal ₹3,999/clinic/month (includes 100 active users), Lab ₹499/technician/month, Pharmacy ₹499/pharmacist/month, White-labelled emails ₹499/clinic/month, Remote Self-Registration ₹14,999 one-time (+₹4,999/yr hosting from year 2), EMR form digitisation ₹12,500–₹45,000 one-time. Trial: "14-day free spin", "No Credit card required", demo booked before trial (not self-serve), no minimum contract, "cancel anytime", free training/support. There is NO USD/"global" pricing page on clinicea.com: the pricing page shows INR only, has no currency/region selector, and the "$69/$89 per practitioner" figures could not be found on any Clinicea property; the only USD figures found are a third-party SoftwareSuggest listing ($18/$24/$42 for "Power/Premium/Enterprise", stale plan names) that conflicts with Clinicea's own page. Prices on third-party sites are explicitly "subject to change".

**Why it matters:** Per-practitioner pricing is the upper bound of what Indian clinics tolerate and it penalises multi-dentist clinics; a flat per-clinic price with 2–3 doctors included is a direct positioning advantage. Clinicea also shows add-on monetisation (patient portal, lab) is accepted.

Sources:
- https://clinicea.com/pricing
- https://www.findemr.com/clinicea
- https://www.clinicea.com/pricing
- https://clinicea.com/
- https://www.softwaresuggest.com/clinicea

<details><summary>Fact-check notes</summary>

Verified directly against the live sources on 2026-10-11. clinicea.com/pricing (and www.clinicea.com/pricing, and with ?currency=USD) shows only INR: Starter 1999, Pro 2999, Enterprise 3999 per practitioner/month; Patient Portal INR 3999/clinic/month incl. 100 active users; Lab INR 499/technician/month; Pharmacy INR 499/pharmacist/month; white-labelled emails INR 499/clinic/month; Remote Self-Registration INR 14,999 one-time + INR 4,999/yr hosting from year 2; EMR digitisation INR 12,500/25,000/45,000; "Take it for a 14-day free spin", "No Credit card required", FAQ: book demo first, no exit fee/minimum contract, "cancel anytime". No currency or region selector exists, so the "global page shows $69/$89" part of the claim is unsupported — refuted for lack of evidence. findemr.com/clinicea repeats the same INR figures but does NOT mention a free trial (only "Watch a Free Demo") and twice says "pricing is subject to change". softwaresuggest.com/clinicea (updated 4 Oct 2026) shows different, apparently stale plans: ₹1,299/₹1,699/₹2,999 (Power/Premium/Enterprise) and $18/$24/$42 — these conflict with both the claim's $69/$89 and with Clinicea's own page, so third-party aggregator prices should not be cited. clinicea.com homepage confirms multi-specialty positioning ("20+" specialities, "multi-speciality integrated polyclinics"), dental is not the focus; footer says "Made with ❤️ by Technolarity" but company location is not stated on fetched pages, so "India-built" rests on the INR-only pricing rather than an explicit statement. India-vs-global lens: the claim correctly labels the INR prices as India pricing, but invents a global USD tier; Clinicea publicly prices in INR only. Caveats: WebSearch budget for this run was exhausted, so only direct fetches were possible; G2, GetApp, SoftwareAdvice, Capterra and SaaSworthy returned HTTP 403.

</details>

### 6. `corrected` · confidence medium

Dentee (Mumbai P.O. Box, Maharashtra 400053; region selector offers India and Oman, footer also lists Australia) is ONE of several dental-only Indian practice-management vendors, not a demonstrably dominant incumbent: the only cited source ranking it (Codingclave, 9 June 2026) places Dentee fifth of ten and notes a "smaller deployed base", and Dentee publishes no clinic/dentist counts. Pricing is not published: the plan page lists sign-up fee "Free", a 15-day free trial with "No credit card or commitment required", and says the monthly plan "will be emailed to you after successful signup". Officially listed features (features.html) are Electronic Patient Records, Appointments and Schedulers, SMS and email notifications, Accounts & Cash Management, Reporting System, Document Management, Administrator, Inventory Management and Lab Management, plus Android/iOS apps for doctors and patients; "e-prescription" is not an advertised feature (the site only says handwritten prescriptions are "replaced by printed forms"). The ₹2,000–5,000/clinic/month figure is a single third-party (competitor-authored) estimate from Codingclave, which is internally inconsistent (its FAQ says ₹500–1,500/month for Dentee basic) and should be treated as low-confidence; published dental-only competitor pricing from the same guide includes BestoSys at ₹1,149–2,475/clinic/month and Dentsoftware at ₹15,000–60,000/year.

**Why it matters:** The dental-only slot in India is weakly held by a product with opaque pricing and no WhatsApp on its site; transparent pricing, WhatsApp-first communication and a modern mobile app are differentiators. Dentee's Oman presence also signals the GCC is the natural first export market.

Sources:
- https://www.dentee.com/dental-practice-management-software/plan.html
- https://www.dentee.com/
- https://codingclave.com/guides/best-dental-clinic-software-india-2026
- https://www.dentee.com/dental-practice-management-software/
- https://www.dentee.com/dental-practice-management-software/features.html

<details><summary>Fact-check notes</summary>

Supported: dentee.com/dental-practice-management-software/plan.html confirms no published prices, "Free" sign-up fee, 15-day trial, "No credit card or commitment required", and pricing "emailed to you after successful signup". dentee.com homepage confirms Mumbai P.O. Box (400053), region selector India/Oman (footer additionally says "Australia India Oman"), and "Dentee for Patients"/"Dentee for Doctors" Android and iOS apps. features.html confirms SMS/email notifications, Inventory Management and Lab Management. Codingclave (published 9 June 2026) does state "Roughly ₹2,000-₹5,000/month/clinic". Refuted/corrected: (1) "main dental-only Indian incumbent" has no supporting evidence — Dentee publishes no clinic counts (only "MILLIONS OF PEOPLE TRUST US" about patients), and Codingclave ranks it 5th of 10 with a "smaller deployed base means support quality varies", while listing other dental-only Indian vendors (BestoSys, Dentsoftware, Smart Dental Desk, Dentolize). (2) "e-prescription" is not a named Dentee feature; the site only mentions printed prescription forms under Reporting. (3) The ₹2,000–5,000 estimate comes from a competitor-authored guide that contradicts itself (FAQ: ₹500–1,500/month), so it is weak evidence. India-vs-global lens: the claim is correctly India-scoped; Dentee's site is +91-phone, Indian-city focused, with Oman as a secondary region. Limitation: the WebSearch budget for this turn was exhausted, so the two required fresh WebSearch queries could not be run; G2 (403) and BestoSys pricing page (404) also could not be fetched. Findings rest on direct fetches of the three stated sources plus Dentee's features pages.

</details>

### 7. `corrected` · confidence medium

Indian clinic-software list prices that are actually published by vendors (checked Oct 2026) cluster around ₹1,000–2,500 per clinic per month, but most of the specific figures in the claim are unverified third-party estimates, not vendor prices: Adrine publishes a Clinic plan at ₹999/month (Hospital: custom quote); Cufront publishes Plus at ₹1,250/month and Pro at ₹1,500/month only when billed yearly (monthly list ₹1,925 and ₹2,300, Enterprise custom, 14-day free trial) — so "₹1,250 flat" is wrong. Bestosys names Gold/Platinum/Diamond tiers but publishes no prices (pricing "depends on number of branches and doctors"; the ₹1,149/₹1,485/₹2,475 figures appear only in a June 2026 dev-agency blog, while another blog lists Bestosys at ₹500/month). MocDoc publishes no pricing; third-party estimates range from ₹800/month (Adrine blog) to ₹3,000–8,000/month (Codingclave), so "~₹800–3,000" is a splice of contradictory guesses. Dentsoftware (Avengersoft) publishes no prices (form-gated, 7-day trial); ₹15,000–60,000/year comes only from the Codingclave blog. DentaCloud ₹1,500/month appears only in Adrine's competitor table and its site could not be reached. Treat only Adrine (₹999) and Cufront (₹1,250–1,500 annual-billed) as confirmed price points; the others need vendor quotes.

**Why it matters:** Price is not a moat in India; below ~₹1,000/month there is already free or near-free supply. Differentiation must come from dental workflow depth, WhatsApp automation and the student/owner community, with transactional revenue (messaging, payments, lab) carrying margin.

Sources:
- https://codingclave.com/guides/best-dental-clinic-software-india-2026
- https://www.adrine.in/blog/best-dental-practice-management-software-india
- https://www.cufront.com/blog/practo-ray-pricing-india-worth-it-2026
- https://www.cufront.com/
- https://www.adrine.in/pricing
- https://www.bestosys.com/plans.php
- https://www.dentsoftware.com/dental-office-software-pricing
- https://mocdoc.com/

<details><summary>Fact-check notes</summary>

Checked all three stated sources plus vendor sites directly (WebSearch budget was exhausted for this turn, so verification used WebFetch of vendor pages). (1) Codingclave (published 9 Jun 2026, a custom-dev agency blog) is the sole source for Bestosys ₹1,149/₹1,485/₹2,475 and Dentsoftware ₹15,000–60,000/yr; it also gives MocDoc at ₹3,000–8,000/month and marks most other figures "roughly" — it does not support a ₹500–2,500 cluster (its own ranges for Dentee, Adrine, Smart Dental Desk, Medical365 run ₹2,000–10,000/month). (2) Adrine's blog (19 Feb 2026) is a competitor comparison table listing Bestosys at ₹500/month (contradicting Codingclave), MocDoc ₹800/month, DentaCloud ₹1.5K/month, Adrine from ₹999 — figures with no citations. (3) Cufront's blog (23 May 2026) says ₹1,250/month flat with a 14-day trial, but Cufront's own homepage pricing section now shows Plus ₹1,250/mo and Pro ₹1,500/mo "billed yearly (save 35%)", with monthly list prices of ₹1,925 and ₹2,300 struck through, plus an Enterprise custom tier and a ₹1,449/doctor/month AI-scribe add-on — so "flat" is inaccurate. (4) Bestosys plans.php lists Gold/Platinum/Diamond with no prices and says pricing depends on branches/doctors; bestosys.com/pricing returns 404. (5) Adrine.in/pricing confirms Clinic ₹999/month, Hospital custom — the one fully confirmed number. (6) mocdoc.com has no pricing page (mocdoc.in/pricing redirects to mocdoc.com/pricing which 404s). (7) dentsoftware.com pricing page is form-gated ("Get the rates"), 7-day trial, Indian +91 contact. (8) dentacloud.in refused connection; dentacloud.com redirects to Futudent (a Finnish dental camera company), so the Indian "DentaCloud" could not be verified. India-vs-global lens: no conflation found — all products are India-market; the problem is reliance on uncited blog estimates presented as list prices and the cherry-picked ₹500–2,500 band that the cited sources themselves don't agree on.

</details>

### 8. `confirmed` · confidence high

Open Dental charges $199/month/location (first 12 months) then $149 in the US, $89 in 'other countries', and is FREE with limited support in developing countries explicitly including India; eServices add-ons are $5–165/month/location and AI image analysis $149/month/location.

**Why it matters:** A full-featured, dental-only desktop PMS is already free in India, so the subscription alone cannot be the value proposition; the product must win on cloud/mobile, WhatsApp, Indian billing (GST, UPI, EMI) and support. Open Dental's add-on menu is also a useful template for unbundled pricing.

Sources:
- https://www.opendental.com/site/fees.html
- https://www.opendental.com/site/aiimageanalysis.html

### 9. `corrected` · confidence high

Published dental-only cloud PMS list prices as of Oct 2026 (US/UK list prices, not Indian pricing): tab32 (US) — Start-Up plan $125/mo in Year 1 then $225/mo from Year 2 (up to 3 providers); Established Practice $225/mo (up to 5 providers); Summit custom; free 14-day trial with card on file; $0.20/claim plus $0.50 per claim with attachments; AutoRemind reminders included in Year 1 only (500 messages/mo, $0.08 per extra message) and $69/mo after Year 1; AI services and data/imaging migration priced on request. CareStack (US list) — Essentials "starting at $829/month"; Intelligence "starting at $1,299/month" adding AI clinical notes, AI voice perio charting and AI x-ray analysis (Overjet); final price depends on locations/chairs and an implementation fee may apply. Curve Dental — no list price published on curvedental.com (quote/demo only); a third-party 2025 review (dentalstack.io) cites "starting at approximately $350/mo per practice location, unlimited providers" — the "$350–500" upper bound is not supported by any cited source. Dentrix Ascend — quote-only; the SelectHub page (updated 28 Sep 2026) shows "Custom Quote" with no figures, so the "$399–800/mo" range is unsourced and should be dropped or marked as unverified anecdote. Dentally (UK) — Starter £125 (1 surgery) to £575 (8 surgeries), Essentials £220–£720, Pro £320–£945 per month, excluding VAT, unlimited users and storage; AI clinical notes limited trial on Starter, 45/surgery/month on Essentials, 90 on Pro (not available in NI/ROI). None of these vendors publish India-specific pricing; these figures are USD/GBP list prices for US/UK markets.

**Why it matters:** Western dental SaaS earns 10–50x Indian ARPU for the same core features. A product engineered to Indian cost structures but with dental depth can later sell at $99–199/location in GCC/UK/Australia, which is where the enterprise value of the company will come from.

Sources:
- https://tab32.com/pricing/
- https://carestack.com/pricing
- https://www.dentally.com/en-gb/pricing
- https://www.dentalstack.io/reviews/curve-dental
- https://www.selecthub.com/dental-practice-management-software/open-dental-vs-dentrix-ascend/
- https://www.curvedental.com/pricing
- https://www.dentrixascend.com/

<details><summary>Fact-check notes</summary>

Verified directly against the stated sources on 2026-10-11 (WebSearch budget was exhausted for this run, so verification relied on fetching primary pages). tab32.com/pricing: "Year 1: $125/mo · Year 2+: $225/mo" (Start-Up, up to 3 providers), Established Practice "$225 /mo" (up to 5 providers), "Free 14-day trial ... with your card on file", "$0.20/claim", "$0.50/claim attachments", AutoRemind "Included Year 1", "500 messages included per month", "$0.08 per message beyond 500/mo", "$69/mo" after Year 1 — the claim omits the $69/mo post-year-1 reminder fee and the attachment fee, and blurs two tiers into "3–5 providers". carestack.com/pricing: Essentials "Starting at $829/month", Intelligence "Starting at $1299/month" with AI clinical notes, AI voice perio charting, AI x-rays by Overjet; implementation fee may apply — claim matches. dentally.com/en-gb/pricing: eight price points per tier for 1–8 surgeries, Starter £125…£575, Essentials £220…£720, Pro £320…£945, "Excluding VAT" — claim matches. dentalstack.io Curve review (titled 2025): "Starting at $350/mo", per practice, unlimited providers; no range to $500 given; curvedental.com/pricing publishes no price ("GET A PERSONALIZED QUOTE") — so "unpublished" is right, "$350–500" is only partly supported. selecthub.com Open Dental vs Dentrix Ascend (Last Updated Sep 28, 2026): Dentrix Ascend shows "Custom Quote", no dollar figures, "Free Trial is unavailable"; dentrixascend.com publishes no price — the "$399–800/mo" range is not supported by the stated source. India-vs-global: the claim correctly frames these as global USD/GBP prices and does not assert they apply in India; no Indian pricing exists on any of these pages (CareStack, though India-founded, lists only US prices).

</details>

### 10. `corrected` · confidence high

Trial norms (verified from vendor pages, Oct 2026): Practo Ray — 7-day free trial for new practices (15 days per additional practice for existing users); card requirement not stated. Clinicea — 14-day free trial, no credit card required (vendor asks prospects to book a demo first). Cufront — 14-day free trial with full feature access, no credit card required (pricing page at cufront.com/pricing is a 404; trial terms are on the homepage). Dentee — 15-day free trial, "no credit card or commitment required"; monthly pricing is emailed after signup, not published. tab32 — 14-day free trial with card on file ("you won't be charged until your trial ends"), Start-Up plan only. Cliniko — 30-day free trial, no payment details needed (some features such as Telehealth unlock only after a card is added). Open Dental — DOES offer a free, non-expiring downloadable Trial Version (limited to 30 patients, no CDT codes, no eServices/API), plus a 90-day money-back guarantee on support fees (practice must stop using the software to be refunded). Jane — no free trial; evaluation via sales demo or a shared Jane Demo Account (login distributed weekly via community/support). Fresha — core subscription is "Free" on both Independent and Team plans; revenue comes from a one-time new-client marketplace fee, optional card processing, paid SMS/WhatsApp/email beyond free quotas, and paid add-ons. Context: Practo Ray, Clinicea, Cufront and Dentee are India-market vendors priced in INR; tab32 and Open Dental are US dental vendors (USD); Cliniko (USD) and Jane (CAD) are general allied-health/clinic platforms, not dental-specific; Fresha is salon/spa software, not a dental product, so it is a weak comparator for dental trial norms.

**Why it matters:** In India a no-card 14–15 day trial is table stakes and buyers expect to see prices on the website; a permanent free tier (Fresha/Open Dental style) is the most aggressive and credible way to seed a student-to-owner funnel, with paid tiers unlocked when the clinic grows.

Sources:
- https://www.practo.com/providers/clinics/ray/plans
- https://clinicea.com/pricing
- https://www.dentee.com/dental-practice-management-software/plan.html
- https://tab32.com/pricing/
- https://www.cliniko.com/pricing/
- https://jane.app/pricing
- https://www.fresha.com/pricing
- https://www.cufront.com/

<details><summary>Fact-check notes</summary>

Most of the claim holds, but two items are wrong or materially incomplete. (1) Open Dental: the claim says "no trial" — false. opendental.com's navigation links a "Trial Version" page offering a free, never-expiring downloadable trial (30-patient cap, no CDT content, no eServices/API). The 90-day money-back guarantee is confirmed on the fees page, but with a condition (office must stop using the software), and it applies to support fees/eServices, not to a one-time purchase price. (2) Fresha: "permanently free core software" is accurate on the pricing page (both plans list subscription as "Free"), but Fresha positions itself as "#1 Software for Salons and Spas" — it is not a dental product, and the stated source URL for Fresha (fresha.com/pricing) shows INR-denominated add-on/messaging fees, so citing it as a dental trial norm conflates verticals. Minor corrections: Practo Ray's 7-day trial is confirmed, but existing users get 15 days per added practice and the page does not state card requirement; Cliniko's "no card" is partly conditional (Telehealth needs a card); Dentee's stated source URL (plan.html) does confirm 15 days/no card, but Dentee publishes no prices; Cufront's stated source /pricing returns 404 — the homepage confirms 14 days/no card and INR pricing (Plus Rs 1,250/mo, Pro Rs 1,500/mo billed yearly), Pune-based. tab32 14-day card-on-file confirmed, Start-Up plan ($125/mo year 1). Jane "no free trial, demo account instead" confirmed verbatim. Note: WebSearch budget for this run was exhausted, so verification relied on direct fetches of vendor pages only; no independent 2025-2026 third-party corroboration was obtained.

</details>

### 11. `confirmed` · confidence high

Cliniko (allied health, Melbourne) is bootstrapped from day one, prices in flat USD bands by practitioner count ($45 for 1, $95 for 2–5, $145 for 6–8, up to $395 for 26–200), has not changed prices since June 2011, includes unlimited admin/reception users, and charges only for SMS (10c each); 30-day trial.

**Why it matters:** Proof that a single-vertical practice-management SaaS can win on simplicity and trust without VC: one price per band, nothing gated, usage-based messaging. This is the template for the Indian paid tier (flat per clinic, doctors included, messaging metered).

Sources:
- https://www.cliniko.com/pricing/
- https://4dayweek.io/company/cliniko
- https://www.cliniko.com/
- https://www.cliniko.com/blog/

### 12. `confirmed` · confidence high

Jane App (Canada, physio/chiro/allied health) prices in CAD at $59 (Balance, 20 appts/month cap), $79 (Practice) and $99 (Thrive) base with one practitioner, plus per-license fees for extra practitioners; add-ons: AI Scribe $15/practitioner, Insurance Billing $20 + $5/practitioner, Payroll $40 + $6/staff, Websites $59/clinic; no free trial.

**Why it matters:** Shows how a vertical SaaS grows ARPU from ~$60 to $150+ with add-ons (AI notes, insurance, websites, payroll) rather than raising base price; the same ladder (AI notes, website builder, patient app, lab, financing) applies to dentistry.

Sources:
- https://jane.app/pricing

### 13. `confirmed` · confidence medium

Fresha (salons/spas) offers its core software permanently free, monetises via payment processing, a one-time marketplace fee for new clients it brings, and messaging credits (in India: 20 free texts/WhatsApp per month, then ₹13.50/SMS, ₹1.60–5.50 per WhatsApp message, ₹54 per marketing SMS); it reports ~130,000 businesses, 35M appointments/month and raised $80M from KKR in May 2026 at a >$1B valuation.

**Why it matters:** A free-software, transaction-monetised model has reached unicorn scale in a fragmented SMB vertical very similar in structure to Indian dentistry. Fresha's India WhatsApp retail price (₹1.60–5.50) versus Meta's cost (₹0.115 utility) shows the margin available on messaging credits.

Sources:
- https://www.fresha.com/pricing
- https://ventureburn.com/fresha-raises-80m-hits-1-billion-valuation/
- https://www.tamradar.com/funding-rounds/fresha-growth-80m

### 14. `corrected` · confidence high

Planet DDS announced its acquisition of Cloud 9 Software (cloud orthodontic/pediatric PMS) on 5 January 2023; Planet DDS's own release says the combined company serves "more than 2,900 locations" (the "2,300+" figure in the claim is not supported by the stated sources). The "built from the ground up for ortho" tagline, the "category creator" label and the rationale that fleshing out a generic ortho module "would take five more years" do NOT appear in either stated source (Planet DDS newsroom or Dental Products Report) and remain unverified; Planet DDS CEO Eric Giesecke's quoted rationale was only that Cloud 9 addresses "the unique needs of orthodontic and pediatric care practices." Dentally (UK, founded 2011 by Nick Davies and James Harker) was acquired by Software of Excellence, a wholly owned Henry Schein One subsidiary, announced 8 July 2020; Dentally today markets itself as "Fully integrated with NHS in England, Wales, Scotland and HSC in Northern Ireland." The "70,000 practitioners" figure is not present on any stated source, Dentally's homepage, or its LinkedIn page and should be dropped or re-sourced. Both are US/UK precedents and say nothing about the Indian dental market.

**Why it matters:** Specialty depth is a defensible moat and an acquisition thesis: generic vendors cannot cheaply replicate specialty workflow, so they buy. For a dental-only product, deep tooth-level charting, consents, lab and recall workflows are the moat; Henry Schein One/Planet DDS/Straumann are the eventual acquirers.

Sources:
- https://www.planetdds.com/newsroom/planet-dds-announces-its-acquisition-of-cloud-9/
- https://www.dentalproductsreport.com/view/planet-dds-acquires-cloud-9-software
- https://blog.softwareofexcellence.com/en-gb/software-of-excellence-acquires-dentally
- https://www.dentally.com/en-gb/resources/henry-schein-one
- https://www.dentally.com/en-gb
- https://www.linkedin.com/company/dentally

<details><summary>Fact-check notes</summary>

Verified: (1) Dental Products Report article is dated 5 Jan 2023, confirming the Jan 2023 acquisition date; it contains no "five more years" or "ground up for ortho" quote, only Giesecke's reference to "the unique needs of orthodontic and pediatric care practices." (2) Planet DDS newsroom release gives no explicit date (image path/campaign tag imply Jan 2023) and states "more than 2,900 locations" combined, not 2,300+; no "five more years" quote; Cloud 9 CEO Mike Ressel only says the company has been "in the cloud since the founding." (3) Software of Excellence blog confirms acquisition announced 8 July 2020, Dentally founded 2011 by Nick Davies and James Harker, SOE a wholly owned subsidiary of Henry Schein One (JV of Henry Schein and Internet Brands, founded 2018); it gives no practitioner count and does not mention NHS. (4) The stated dentally.com/resources/henry-schein-one page only says Dentally "is part of Henry Schein One" — no founding year, date or user counts. (5) Dentally homepage (fetched Oct 2026) confirms NHS/HSC integration across all four UK nations and HSO ownership, but publishes no practitioner/practice count; LinkedIn confirms founded 2011, 201-500 employee band, no 70,000 figure. Refuted elements: the 2,300+ location number (official figure 2,900+), and the unsourced "five more years", "category creator", and "70,000 practitioners" claims. Caveats: the per-turn WebSearch budget was exhausted before my searches ran, so I could not run the two required fresh searches; cloud9ortho.com did not resolve and several planetdds.com/dentally.com subpages returned 404, so the "five more years" quote may exist in an unstated podcast/interview and the 70,000 figure could be a newer Dentally/HSO marketing stat, but neither could be confirmed. India-vs-global: the claim correctly frames these as US/UK precedents; the only risk is reading UK NHS-integration as a moat relevant to India, where no equivalent public payer integration exists.

</details>

### 15. `corrected` · confidence medium

CareStack (US parent Good Methods Global Inc., Celebration/Orlando FL, incorporated Oct 2014; founded 2015, commercial launch late 2017) sells a dental-only cloud PMS whose US list pricing "starts at" $829/month (Essentials) and $1,299/month (Intelligence), with actual quotes depending on locations, chairs and providers, and no India/UK/AU pricing published. Its own site states it supports "over 1,500 dental practices in the United States" and is "utilized in over 3000+ practices" (unreconciled), and claims "over $145 million raised in the past five years" without naming investors; third-party tracking (Tracxn) records only $79.1M disclosed across 6 rounds from investors including Accel, Delta Dental, Steadview and F-Prime Capital, and Straumann Group took an undisclosed strategic minority stake in July 2022. The Indian entity is Good Methods Software Solutions Private Limited (not "Good Methods Global"), incorporated 1 Mar 2012 in Thiruvananthapuram, Kerala, with Tracxn-estimated revenue of ₹100–500 Cr for FY ending 31 Mar 2025. Headcount figures vary by source: Tracxn 1,095 (31 May 2025), CareStack site "1,300+" (Oct 2026), LinkedIn 769 listed profiles (501–1,000 band); the specific "1,181 employees (Mar 2026)" figure could not be verified. CareStack is a US-market product built with Indian engineering; it does not sell to Indian dental clinics.

**Why it matters:** The strongest evidence that an India-built dental SaaS can win premium Western customers and attract both VC and strategic (insurer, implant-maker) capital. It also shows CareStack skipped India as a market, leaving the domestic dental-only slot open.

Sources:
- https://tracxn.com/d/companies/carestack/__y_nu6zWxAt39Usy5aV1BDkEt6FeCxTcuBUe009-c55Q
- https://carestack.com/company
- https://carestack.com/pricing
- https://www.prnewswire.com/news/carestack/
- https://www.linkedin.com/company/carestack

<details><summary>Fact-check notes</summary>

Checked 2026-10-11 by fetching the stated sources plus CareStack's PR Newswire and LinkedIn pages (web search budget was exhausted, so no fresh WebSearch could be run). (1) Pricing holds: carestack.com/pricing lists Essentials "starting at $829/month" and Intelligence "starting at $1,299/month", USD/US region only, quote depends on locations/chairs/providers; India not mentioned. (2) "1,500+ US practices" holds but is understated/inconsistent: the same company page also says "3000+" practices in its stats block. (3) "$145M raised" is CareStack's self-reported figure ("over $145 million in the past five years"); Tracxn records only $79.1M across 6 rounds, so the $145M is unaudited marketing. (4) Investors: Tracxn names Accel, Delta Dental, Steadview and F-Prime Capital (8 institutional investors total); Straumann's involvement is confirmed only as a "strategic minority stake" announced 12 Jul 2022 via PR Newswire, amount undisclosed; the company page names no investors. (5) Indian entity name is wrong: Tracxn lists Good Methods Software Solutions Private Limited (incorporated 1 Mar 2012, Thiruvananthapuram), with the US entity Good Methods Global Inc. (incorporated 26 Oct 2014). The "since 2012" date and Kerala location hold. (6) "1,181 employees (Mar 2026)" not supported by any fetched source: Tracxn says 1,095 as of 31 May 2025, company site says "1,300+", LinkedIn shows 769 profiles / 501–1,000 band. (7) ₹100–500 Cr FY25 revenue range for the Indian entity holds per Tracxn (as of 31 Mar 2025), but is a band estimate, not reported revenue. India-vs-global lens: the claim correctly frames CareStack as US-facing; it has no Indian dental customer offering, so it is a benchmark for US pricing/scale, not for the Indian market.

</details>

### 16. `corrected` · confidence high

Meta's WhatsApp Business Platform moved from conversation-based to per-delivered-template-message billing on 1 July 2025, and Meta's official pricing docs confirm India's marketing rate was raised on 1 January 2026 and that INR billing for India-based businesses began the same day (INR migration mandatory by 31 Dec 2026). Current India rates quoted by Indian BSP/aggregator pages (not verified against Meta's INR rate card, which is only available as a CSV/PDF download) are ₹0.8631 per marketing message and ₹0.1150 per utility or authentication message (authentication-international ₹2.4971), excluding 18% GST and any BSP markup; BSP-inclusive prices run higher (e.g. AiSensy lists ₹1.09 marketing / ₹0.145 utility). The pre-2026 figure of ₹0.7846 and the "~10%" increase could not be confirmed from any source fetched and should be treated as unverified. Meta's own developer docs (fetched 11 Oct 2026) still state that utility templates sent inside an open 24-hour customer service window and non-template service replies are free, and list no October 2026 change to that policy; however, several BSPs (Gupshup, AiSensy, Amomic, ChatMaxima) state that from 1 October 2026 service replies are charged (₹0.1150) after 1,000 free per phone number per month, and AiSensy/Amomic add that in-window utility templates also became chargeable. This Oct-2026 change is a genuine source conflict and is not corroborated by Meta's official documentation; budget conservatively and verify against Meta's INR rate card before relying on it. The Fresha pricing page is not a source for Meta API rates: it only shows Fresha's own resale price of ₹1.60–₹5.50 per WhatsApp notification in India.

**Why it matters:** Appointment reminders, recall and lab-ready messages cost ~₹0.12–0.14 each at Meta rates, so a bundle of 500 utility messages costs the vendor <₹70 but is retailed by competitors at ₹1.60–5.50 per message. WhatsApp credits are the highest-margin add-on and should be bundled into paid tiers and sold as top-ups.

Sources:
- https://amomic.in/blog/whatsapp-business-api-pricing-india
- https://chatmaxima.com/whatsapp-api-pricing/india/
- https://www.fresha.com/pricing
- https://developers.facebook.com/docs/whatsapp/pricing/
- https://developers.facebook.com/docs/whatsapp/pricing/updates-to-pricing
- https://developers.facebook.com/documentation/business-messaging/whatsapp/pricing
- https://developers.facebook.com/docs/whatsapp/business-platform/changelog
- https://aisensy.com/pricing

<details><summary>Fact-check notes</summary>

(1) Meta developer docs (developers.facebook.com/docs/whatsapp/pricing and /updates-to-pricing, fetched 2026-10-11): per-message pricing effective 1 July 2025; "India: higher marketing rate" effective 1 Jan 2026 with no figures given; INR billing localisation from 1 Jan 2026, migration deadline 31 Dec 2026; "Utility templates delivered within an open customer service window are free"; "Service conversations are now free for all businesses" (since 1 Nov 2024); the only 1 Oct 2026 updates listed are rate changes in Bangladesh, Iraq, Nepal, Sri Lanka, Kazakhstan, Kuwait, Morocco, Oman, Ukraine. No mention of "1,000", "free tier", service-message charging or in-window utility charging. Rate card CSV/PDF links were not extractable, so exact INR figures could not be verified at source. (2) amomic.in (dated 29 Sep 2026, "rates checked 10 Oct 2026"): marketing ₹0.8631, utility/auth ₹0.1150, auth-intl ₹2.4971, 18% GST; claims from 1 Oct 2026 service replies charged after 1,000 free/month and in-window utility templates chargeable, citing Meta's updates page — which does not contain that. It gives no pre-2026 rate (₹0.7846 not present). (3) chatmaxima.com: same ₹0.8631/₹0.1150 figures "effective 1 Oct 2026"; says in-window utility templates "remain free" but service replies charged after 1,000 free/month; no pre-2026 rate. (4) aisensy.com/pricing: ₹1.09 marketing, ₹0.145 utility/auth/service, "effective 1 October 2026", in-window utility chargeable from 1 Oct 2026, 1,000 free service messages/month. (5) gupshup.ai/pricing: "Starting October 1, 2026, Meta will charge for Service messages"; "first 1,000 Service messages are free". (6) twilio.com/en-us/whatsapp/pricing ("current as of September 2026"): in-window utility messages carry no charge, no Oct 2026 change mentioned. (7) fresha.com/pricing: only Fresha's own WhatsApp notification price ₹1.60–₹5.50, irrelevant to Meta API rates. India-vs-global: the claim is correctly India-scoped (INR, GST), but the ₹0.7846 prior rate was not found anywhere and the Oct-2026 change is BSP-asserted, not Meta-confirmed. WebSearch budget was exhausted for this turn, so fresh searches could not be run; verification relied on WebFetch of ~25 primary and BSP pages.

</details>

### 17. `corrected` · confidence medium

The ABDM Digital Health Incentive Scheme (DHIS) is live, not lapsed: NHA has extended and rewritten it repeatedly (Corrigendum 4 of 11 Jun 2024 extended it to 30 Jun 2025; Corrigendum 5 of 19 Feb 2025; Corrigendum 6 of 20 Nov 2025 covered Nov 2025–Mar 2026; Corrigendum 7 of 9 Apr 2026 is in force for April–September 2026). The original Dec-2022 policy's "10+ beds" rule, under which a single-doctor clinic earned nothing and only the digital solution company (DSC) was paid ₹5/record above 200/month with a ₹4 Cr cap, is obsolete. Under the current rules all HFR-registered health facilities including clinics are directly eligible; incentives are paid only on KYC-verified ABHA-linked records above a baseline of 100 transactions/month, at ₹10 (facility) / ₹5 (DSC) per Diagnostic Report or Discharge Summary and ₹5 (facility) / ₹2.5 (DSC) per other record type (prescription, OP consultation, invoice etc.), ₹10 to the HIU plus ₹5 to the HIP per successful consent-based share, and a lifetime cap of ₹5 Cr per facility or DSC (₹1 Cr for NHCX claim incentives); payments to facilities are conditional on filing utilisation certificates. The DPDP Rules, 2025 (G.S.R. 846(E)) were notified on 13 Nov 2025; Rules 1, 2 and 17–21 took effect that day, Rule 4 (consent managers) commences 13 Nov 2026, and Rules 3, 5–16, 22 and 23 (notice, security safeguards, breach intimation etc.) commence 13 May 2027. Rule 7(2) requires an immediate "without delay" description of a breach to the Data Protection Board followed by detailed information within 72 hours of becoming aware (extendable on written request).

**Why it matters:** ABDM/ABHA integration is both a potential incentive revenue line (paid to the software vendor, not the clinic) and a credibility marker; DPDP compliance by May 2027 (consent, breach reporting, data-principal rights) must be designed into the data model from day one.

Sources:
- https://abdm.gov.in/strapicms/uploads/Financial_Incentive_Policy_DHIS_e96a62fd28.pdf
- https://www.pib.gov.in/Pressreleaseshare.aspx?PRID=1885610
- https://ehealth.eletsonline.com/2025/11/the-healthcare-centric-guide-to-dpdp-rules-2025-what-indias-healthcare-providers-companies-must-know/
- https://amlegalsdpdpa.com/dpdpa-compliance-deadline-2027
- https://abdm.gov.in/DHIS
- https://abdm.gov.in/strapicms/uploads/DHIS_corrigendum_7_c1d7e09cc2.pdf
- https://abdm.gov.in/strapicms/uploads/20_Nov_2025_vf_DHIS_Corrigendum_6_dba5b58a53.pdf
- https://abdm.gov.in/strapicms/uploads/Corrigendum_5_to_DHIS_36d146fed0.pdf

<details><summary>Fact-check notes</summary>

DHIS half of the claim is REFUTED on facts and dates. (1) The stated source (Financial_Incentive_Policy_DHIS PDF, Dec 2022) does say clinics with <10 beds get nothing and DSCs get ₹5/transaction above 200/month with a ₹4 Cr cap — but that is the original 2022 policy and has been superseded. (2) The live abdm.gov.in/DHIS page (last updated 31/07/2026, read 11 Oct 2026 via browser) states eligibility is "All Health facilities like Clinics, Nursing Homes & Hospitals", baseline is 100 transactions/month, rates are ₹10/₹5 (facility) and ₹5/₹2.5 (DSC) for KYC-verified records, ₹10 HIU + ₹5 HIP per consent share, and that "all health facilities registered with HFR and DSCs can earn an Incentive of up to ₹5 Crore". (3) Corrigendum 4 (11 Jun 2024) text: "extend the DHIS scheme till 30th June 2025 or till funds for DHIS are available" — so the 30 June 2025 date was itself an extension, not the "original term" (the original policy ran Q4 FY22-23 to Q1 FY23-24, i.e. to ~June 2023; Corrigendum 3 extended to 30 June 2024). (4) Corrigendum 6 (20 Nov 2025): "effective from the month of November 2025 till the month of March 2026", cap "Rs 5 crores"; Corrigendum 7 (9 Apr 2026): "effective from the month of April 2026 till September 2026", clause viii cap "Rs 5 crores" and "Rs. 1 crore" for NHCX claims, incentives only for KYC-linked records. So the extension is verified, not "unverified", and the rates/cap/eligibility in the claim are stale. DPDP half is CONFIRMED against the official Gazette text (MeitY PDF, G.S.R. 846(E), "New Delhi, the 13th November, 2025"): Rule 1(2) Rules 1, 2, 17–21 in force on publication; 1(3) Rule 4 one year after; 1(4) Rules 3, 5–16, 22, 23 eighteen months after; Rule 7(2)(b) "within seventy-two hours of becoming aware of the breach, or within such longer period as the Board may allow". SCC Online independently gives 13-11-2025 / 13-11-2026 / 13-5-2027. Minor nuance: Wikipedia and some press date the notification 14 Nov 2025 (public release) but the Gazette is dated 13 Nov 2025, matching the claim. India-vs-global lens: no conflation; all facts are India-specific. Note: the PIB link (PRID 1885610) returned HTTP 403 and could not be checked; WebSearch budget was exhausted for this turn so no fresh searches were run — verification relied on the official NHA and MeitY documents fetched directly.

</details>

### 18. `corrected` · confidence medium

Standard Indian retail health policies generally exclude routine dental treatment; dental costs are typically paid only when caused by accidental injury or when hospitalisation/medically necessary surgery (e.g., jaw surgery) is involved. Dental OPD cover is available as an add-on/OPD feature on several plans, including Care Plus (Care Health), Niva Bupa Health Premia, Aditya Birla Activ Health Platinum Enhanced, Star Comprehensive (OPD dental Rs 5,000-10,000), ManipalCigna ProHealth and HDFC ERGO OPD riders, usually with sub-limits (~Rs 15,000-50,000/yr caps) and 1-3 year waiting periods. On 13 March 2025, dental-tech startup Toothlens, together with Star Health and Allied Insurance and Vizza Broking Services, announced what its own press release called "India's first cashless Dental OPD insurance program" (a company claim, not independently verified; covers consults, X-rays, fillings, extractions, scaling, RCT, crowns). Toothlens now sells cashless dental OPD plans at Rs 165 / 475 / 855 per month and lists Care Health, ManipalCigna and Aditya Birla among partners, so the current status of the Star Health tie-up specifically is unclear. India's out-of-pocket share of current health expenditure per the current WHO Global Health Expenditure Database (via World Bank, updated Dec 2025) is 49.5% (2020) and 43.9% (2023), not ~62.7%; the 62.7% figure reflects an older, since-revised WHO data vintage. India's National Health Accounts (latest: NHA 2022-23, released 2026) is the authoritative domestic series.

**Why it matters:** Unlike the US (where claims, eligibility and attachments drive tab32/Open Dental pricing), insurance-claims features are a low priority for India v1; instead, cash collection, UPI/payment links, EMI financing and treatment-plan-to-invoice conversion matter most. Keep a claims module for the UK/GCC/US roadmap.

Sources:
- https://www.policyx.com/health-insurance/articles/dental-insurance-covers-and-benefits-in-india/
- https://www.starhealth.in/dental-insurance/
- https://www.fincover.com/insurance/health/is-dental-treatment-covered-in-health-insurance/
- https://theprint.in/ani-press-releases/toothlens-launches-indias-first-cashless-dental-opd-insurance-with-star-health/2546524/
- https://apacnewsnetwork.com/2025/03/toothlens-partners-with-star-health-vizza-broking-services-to-launch-cashless-dental-opd-insurance/
- https://toothlens.com/resources/media
- https://toothlens.com/dental-insurance
- https://api.worldbank.org/v2/country/IN/indicator/SH.XPD.OOPC.CH.ZS?format=json&date=2018:2023

<details><summary>Fact-check notes</summary>

1) Dental exclusion + riders: SUPPORTED. PolicyX (published 7 May 2025, updated 27 Jul 2026) says dental is not standard coverage and is an add-on/OPD feature; its table lists Care Plus (OPD dental), Niva Bupa Health Premia (OPD dental + diagnostics), Aditya Birla Activ Health Platinum Enhanced (dental consultation/investigations), Star Comprehensive (OPD dental Rs 5k-10k), ManipalCigna ProHealth, ICICI Lombard (accident dental only); caps Rs 15k-50k/yr, 1-3 yr waiting. Fincover says base policies exclude routine dental but may pay for accident/hospitalisation-related dental; names Care, Max/Niva Bupa, Aditya Birla, HDFC ERGO for OPD riders. Claim is incomplete (omits Star, ManipalCigna, HDFC ERGO) but directionally right. Official insurer pages (Care, Niva Bupa, Aditya Birla) returned 403/404/cert errors, so rider details rest on aggregator sources. 2) Toothlens/Star Health: DATE CONFIRMED but FRAMING NEEDS CORRECTION. ThePrint (ANI press release) and APAC News Network, both dated 13 March 2025, report Toothlens launched "India's first cashless Dental OPD insurance program" in collaboration with Star Health and Allied Insurance and Vizza Broking Services. This is a syndicated company press release, so "India's first" is Toothlens's own claim; Vizza Broking was a co-partner omitted by the claim. Toothlens's current site (toothlens.com/dental-insurance) advertises "India's First Comprehensive Cashless Dental Plans" at Rs 165/475/855 per month but names no insurer; its media page FAQ lists Care Health, ManipalCigna, Aditya Birla as program partners and does not name Star Health; Star Health's own site (starhealth.in/dental-insurance, press-release pages) returned 403 so I could not verify the Star Health side. The stated source starhealth.in/dental-insurance could not be opened. 3) OOP 62.7% (WHO 2020): REFUTED. World Bank indicator SH.XPD.OOPC.CH.ZS (source: WHO Global Health Expenditure Database, last updated 12 Dec 2025) gives India OOP as % of current health expenditure: 2018 53.2%, 2019 52.0%, 2020 49.5%, 2021 45.1%, 2022 44.5%, 2023 43.9%. 62.7% matches an older WHO GHED vintage (c. 2018 estimate) that has since been revised downward; attributing it to 2020 is wrong. NHSRC lists NHA 2022-23 as the latest national report (PDF too large to parse; figure not extracted). India-vs-global lens: no conflation found; all facts are India-specific. Note: the per-turn WebSearch budget was exhausted before this check started, so verification used direct WebFetch of stated sources plus primary/press URLs rather than fresh web searches.

</details>

### 19. `corrected` · confidence medium

Bajaj Finance's "Dental Care on EMI" page (still live, Oct 2026) states the EMI Network covers "over 800 medical procedures", "up to Rs. 4 lakh", repayable "over a tenure that ranges up to 38 months", at "5,500+ medical partners in over 1,000 Indian cities" on "No Cost EMIs", naming Apollo Dental, Clove Dental and Sabka Dentist as dental partners. However, the Health EMI Network Card product page itself now 301-redirects to a "page is under maintenance" placeholder, and Bajaj is steering new customers to the general Insta EMI Card (limit up to Rs 6 lakh, 3-60 months, Rs 530 joining fee, 1.5 lakh+ stores) — so the "Health EMI Network Card" branding is stale/legacy. "0%/No Cost EMI" is not literally free to the patient: Bajaj's fees page lists for the Health EMI Network Card a processing fee up to Rs 1,017, convenience fee up to Rs 270, Rs 600 bounce charge and 36% p.a. penal charge (and consumer-finance interest up to 28.25% on non-no-cost schemes). On financing partners: Bajaj EMI and SaveIN are genuinely advertised by Indian dental clinics (SaveIN is a healthcare-focused pay-later platform offering credit up to Rs 10 lakh in 3/6/9/12 EMIs and markets "lower commission" to clinics); "Capital Float" is an outdated name — it rebranded to axio (CapFloat Financial Services, NBFC) and axio's site shows no dental/clinic product; and Snapmint positions itself as "EMI on UPI" for D2C e-commerce (3/6/9 months) with no dental or clinic offering on its site, and neither of the two stated clinic sources mentions Snapmint or Capital Float. Clinic-side commissions/MDR/subvention rates are indeed not published by Bajaj, SaveIN or Snapmint (SaveIN's site has no pricing page; Bajaj says processing fees "vary from products, schemes, and dealers").

**Why it matters:** Embedded patient financing is a proven Indian dental add-on that competitors do not integrate into the PMS; a 'Finance this treatment plan' button with a referral/MDR share is a plausible revenue line, but the economics need direct negotiation with Bajaj/SaveIn.

Sources:
- https://www.bajajfinserv.in/emi-network-dental-care-on-emi
- https://www.vanillasmiles.dental/blog/finding-the-best-dental-clinic-near-you-made-easy-with-g-money-savein-bajaj-finance/
- https://www.smilesroyale.com/0-emi-plan/
- https://www.bajajfinserv.in/health-emi-network-card
- https://www.bajajfinserv.in/health-emi-maintanance.html
- https://www.bajajfinserv.in/insta-emi-card
- https://www.bajajfinserv.in/all-fees-and-charges
- https://savein.money/

<details><summary>Fact-check notes</summary>

Checked 2026-10-11 by fetching the stated sources and provider sites directly (WebSearch budget for this run was exhausted, so no fresh search queries could be run; findings rest on first-party pages). (1) https://www.bajajfinserv.in/emi-network-dental-care-on-emi (title "Dental Care on EMI - Bajaj Finance Health EMI Network Card") verbatim: "you can get over 800 medical procedures on EMI via the Bajaj Finance EMI Network. You get up to Rs. 4 lakh ... repay ... over a tenure that ranges up to 38 months"; "5,500+ medical partners in over 1,000 Indian cities ... on No Cost EMIs"; FAQ partners "Apollo Dental, Clove Dental, Sabka Dentist"; foreclosure allowed after 6 months. So the numbers in the claim are accurate as of today. (2) https://www.bajajfinserv.in/health-emi-network-card returns HTTP 301 -> https://www.bajajfinserv.in/health-emi-maintanance.html: "Thank you for your interest in our Health EMI Card. Currently, the page is under maintenance" — the standalone card is no longer being actively sold via its product page. https://www.bajajfinserv.in/insta-emi-card: "card loan offer of up to Rs. 6 lakh", "repayment period from 3 to 60 months", "one-time joining fee of Rs. 530", "1.5 lakh partner stores across 4,000 cities". (3) https://www.bajajfinserv.in/all-fees-and-charges, section "Fees and charges of Health EMI Network Card": "Processing fee Up to Rs. 1,017/- ... collected upfront. Bounce charges Rs. 600/- per bounce ... Penal Charge at the rate of 36% per annum ... Convenience fee ... Up to Rs.270/-"; consumer finance "Rate of Interest Upto 28.25%"; "Processing fee varies from products, schemes, and dealers" (no merchant rates). (4) Stated source vanillasmiles.dental (dated 31 Mar 2023) names only G Money, SaveIN and Bajaj Finance; stated source smilesroyale.com/0-emi-plan names only Bajaj Finserv EMI Network, "No Cost EMIs", "3 to 24 months". Neither mentions Capital Float or Snapmint, so "widely advertise ... via Capital Float/SaveIn and Snapmint" is unsupported for those two. (5) https://capitalfloat.com and https://www.axio.co.in resolve to axio: "axio (formerly known as Capital Float, Walnut & Walnut 369) is the brand name of CapFloat Financial Services Private Limited, an NBFC"; "3000+ Merchants Enabled"; no dental/healthcare mention. (6) https://savein.money/: "Pay in No-cost EMIs", "Healthcare" vertical, "Credit limit up to ₹10 lakhs ... Pay in 3 / 6 / 9 / 12 EMIs", "Trusted by 2000+ Leading Brands", stat tile "Lower Commission" (value JS-rendered, not readable), testimonial re "Dr. Batra's clinic" (Mar 2026); /pricing, /business return 404 — no published clinic pricing. (7) https://www.snapmint.com and https://www.snapmintbusiness.com: "EMI on UPI Solution for Ecommerce", "EMI options are available in 3/6/9 months for both No Cost EMI and Low Cost EMI", "Trusted by 2000 D2C brands"; no dental/clinic mention; /pricing 404. Net: Bajaj figures hold; product branding stale; Capital Float name obsolete (axio) and not a dental lender; Snapmint-for-dental unsupported; "0%" overstated given listed fees; absence of published merchant fees confirmed.

</details>

### 20. `confirmed` · confidence high

The Indian Dental Association claims 75,000+ members across 29 state (its About page says 33), 7 UT, 1 Defence and 450+ local branches; it runs CDE (CODE), the Indian Dental Conference (IDC), World Dental Show (WDS) and Delhi Dental Show, publishes JIDA, IDA Times and Student Digest, and operates a 'Private partner' programme, an IDA Seal and lists DentalCart as 'supported by IDA'.

**Why it matters:** IDA covers roughly 1 in 5 registered dentists and has an existing commercial partnership/endorsement machinery (Seal, private-partner, sponsored supply portal). Local branches (450) are the realistic unit for demos and CDE-sponsored workshops; an IDA Seal or student-digest partnership is a credible, cheap trust channel.

Sources:
- https://ida.org.in/
- https://www.ida.org.in/AboutUs/Details/AboutIDA
- https://membership.ida.org.in/
- https://idaseal.ida.org.in/
- https://www.ida.org.in/Privatepartner (HTTP 404)

### 21. `corrected` · confidence medium

Key Indian dental trade events (as verified 11 Oct 2026): 76th Indian Dental Conference (IDC 2026), Father Muller Convention Centre, Mangalore, 6–8 Feb 2026 (already past; the stated source gives no exhibitor count, so "300+ exhibitors" is unsupported). IDA Hyderabad Dental Convention 2026, HITEX Exhibition Centre, 25–26 Jul 2026 (already past; organisers projected 6,000+ footfall and 250+ exhibitors). IDA World Dental Show 2026 (programme branded "World Dental Conclave"), Jio World Convention Centre, Mumbai, 17–18 Oct 2026 (upcoming; per the official WDS 2026 schedule PDF). FAMDENT Show Mumbai 2026 (20th edition, Messe Düsseldorf India / Medicare Asia), Bombay Exhibition Center, Goregaon, 12–14 Jun 2026 (already past); the organiser's 2025 post-show report for the 19th edition records 154 exhibitors, 12,141 visitors from 23 states, 8,000 sqm gross space and 1,320 conference delegates, not "500+ exhibitors and 20–50k visitors". A FAMDENT Hyderabad edition also ran 7–8 Feb 2026 at HITEX. FDI World Dental Congress 2026 was Prague, 4–7 Sep 2026 (past). Note that four of the five events have already taken place as of October 2026, so GTM planning should target the WDS (Oct 2026) and the 2027 editions.

**Why it matters:** Three to four domestic shows a year reach tens of thousands of practising dentists; a small booth plus a free-tier signup incentive at IDC/Famdent/WDS is the lowest-CAC offline channel. FDI is for the international phase, not launch.

Sources:
- https://www.dentaller.in/76th-indian-dental-conference-2026/
- https://smestreet.in/sectors/indian-dental-association-to-host-its-prestigious-hyderabad-dental-convention-2026-12180103
- https://www.ida.org.in/Events/Details/EventsnMeetings
- https://10times.com/famdent-show-mumbai
- https://www.fdiworlddental.org/fdi-world-dental-congress-2026
- https://wds.org.in/
- https://wds.org.in/pdf/WDS/WDC-Schedule-2026.pdf
- https://www.famdent.com/mumbai

<details><summary>Fact-check notes</summary>

Checked the stated sources with WebFetch (WebSearch budget was exhausted for this turn, so I fetched official event sites directly instead of running fresh searches). (1) IDC: dentaller.in confirms 6–8 Feb 2026, Father Muller Convention Centre, Mangalore, but contains no exhibitor, stall or trade-exhibition figure at all; the "300+ exhibitors" claim is unsourced. (2) Hyderabad Dental Convention: smestreet.in confirms 25–26 Jul 2026 at HITEX, expected footfall 6,000+ and 250+ exhibitors. (3) WDS: the ida.org.in events page lists no dates; wds.org.in confirms the venue (Jio World Convention Centre, Mumbai) and its official schedule PDF (wds.org.in/pdf/WDS/WDC-Schedule-2026.pdf, titled "World Dental Conclave 2026") lists Day 1 Saturday 17 October and Day 2 Sunday 18 October, so 17–18 Oct 2026 holds. (4) Famdent: 10times.com returned HTTP 403; famdent.com and dentaller.in confirm 12–14 Jun 2026, Bombay Exhibition Center, 20th edition, organised by Messe Düsseldorf India (Medicare Asia initiative). The organiser's own Post Show Report 2025 (famdent.com/post-show-report-mumbai, 19th edition, 20–22 Jun 2025) states 154 exhibitors, 12,141 visitors from 23 Indian states, 8,000 sqm gross space, 27 speakers, 26 scientific sessions, 6 hands-on workshops, 1,320 delegates. This directly refutes "500+ exhibitors and 20–50k visitors estimated from past editions" (exhibitors overstated ~3x, visitors overstated ~2–4x). (5) FDI: fdiworlddental.org confirms Prague, 4–7 Sep 2026. India-vs-global lens: no conflation issue, FDI is correctly flagged as the global event; however the claim presents past events (Feb, Jun, Jul, Sep 2026) in a way that reads as upcoming, which matters for a GTM calendar dated Oct 2026.

</details>

### 22. `corrected` · confidence high

In 2025, 53.1% (1,305 of 2,457) of dentists newly added to the UK GDC register were non-UK qualified, overtaking UK qualifiers (1,152; 46.9%) for the first time; by route, new joiners were EEA-qualified 27.6% (679), ORE 20.4% (501), LDS 4.4% (108), rest-of-world 0.7% (17). The figures "ORE 10.1%, EEA 18.7%" describe the WHOLE dentist register (47,916 registrants: 4,819 ORE, 8,974 EEA, 65.9% UK-qualified), not 2025 new joiners. The GDC announced ORE changes in March 2026 (new UCL Consultants contract) that it says could produce a "five-fold increase" in ORE-route registrants; Dentistry.co.uk reports the GDC expects up to 1,500 successful ORE candidates a year once fully scaled (not independently re-verified here). The Indian Dental Association's "Global Dentist Programme – UK ORE Pathway" (gdp.ida.org.in) is run with Smile Dental Academy (UK) and markets placement via Smile DSO, which the page self-describes as a 1,200+ clinic network; training fees are ₹95,000 (ORE Part 1) and ₹3,87,000 (Part 2), ₹4,82,000 total, incl. 18% GST, with an all-in pathway estimate of ₹15,17,108 (~₹15.2 lakh) including GDC/exam fees, visa, flights and living costs. The page's most recent listed batch is 19 Aug 2025 (Mumbai), so fees may be stale as of Oct 2026.

**Why it matters:** Indian dentists are a major export pipeline to the UK (and GCC/Australia), and the IDA is actively monetising it. A product that follows the dentist from Indian clinic to UK associate role (same patient-record model, NHS/private billing module later) has a built-in international expansion path and a partnership angle with IDA GDP/Smile DSO.

Sources:
- https://dentistry.co.uk/2026/05/07/international-dentists-joining-gdc-register-outnumber-uk-qualifiers-for-the-first-time/
- https://gdp.ida.org.in/
- https://www.gdc-uk.org/docs/default-source/reports-and-publications/gdc-registration-statistics-report-2025-accessible.pdf?sfvrsn=b3c4ea93_3

<details><summary>Fact-check notes</summary>

Verified against the primary GDC Registration Statistical Report 2025 (PDF text extracted with pdftotext). Headline holds: p.14 table "New additions to the dentist register in 2025, by route" shows UK 1,152 (46.9%), EEA 679 (27.6%), ORE 501 (20.4%), LDS 108 (4.4%), RoW 17 (0.7%), total 2,457; text: "overseas and international routes accounted for 1,305 (53.1%)". Foreword confirms "more than half (53%)". However the claim's "ORE route 10.1%, EEA 18.7%" sub-figures are WRONG for new joiners: they come from the stock table "Dentists, by route to registration 2025" (whole register: EEA 8,974 = 18.7%, ORE 4,819 = 10.1%, LDS 1,017 = 2.1%, RoW 1,543 = 3.2%, UK 31,563 = 65.9%, total 47,916). The Dentistry.co.uk article (7 May 2026) itself mixed these numbers (its sub-routes sum to 34.1%, not 53%), which is where the error originated. The 1,500/yr ORE figure appears only in the Dentistry.co.uk article ("expects up to 1,500 successful candidates a year once the new UCL Consultants contract is fully scaled"); the GDC report says only that March 2026 ORE changes "could result in a five-fold increase" via the ORE route. I could not run fresh WebSearch queries to independently confirm the 1,500 number because this turn's shared web-search budget was exhausted; treat it as single-source. IDA GDP page (gdp.ida.org.in) confirms partners Smile Dental Academy and Smile DSO ("network of 1,200+ clinics" is the programme's own marketing claim, not independently verified), fees ₹95,000 Part 1 and ₹3,87,000 Part 2 (₹4,82,000 total, incl. 18% GST), and all-in estimate ₹15,17,108 (whose line items do not sum exactly to the stated subtotals). The page's "next batch" is dated 19 Aug 2025, brochure labelled 2026, so pricing currency as of Oct 2026 is uncertain. India-vs-global check: the claim correctly frames this as a UK regulatory fact with an Indian training-pathway angle; no conflation beyond the stock/flow error.

</details>

### 23. `corrected` · confidence medium

UAE/DHA general-dentist licensing for Indian BDS holders is exam-based: a Prometric computer-based test of 150 MCQs (~170 min), pass mark 60% (with per-domain thresholds), no practical exam, though some candidates face a short DHA oral assessment before final registration. Experience requirement per secondary sources: 1-year internship plus 2 years' post-internship clinical experience for general dentists; specialists need 3 years post-master's, and the "Indian/Pakistani MDS holders cannot get a specialist licence until 3 years post-MDS" rule comes from a single Feb-2024 blog quoting figures "as of January 2023" and was NOT verified against the official UAE Unified PQR. Up-front costs are roughly AED 2,000 (DataFlow ~AED 992 + exam ~AED 1,080); the quoted DHA licence fee of AED 3,020 (full-time) / 4,020 (part-time) is a 2023-dated renewal figure from a coaching blog, not a current official DHA schedule, so "~AED 3,000–5,000" should be labelled approximate and unverified. For Australia: the ADC Annual Report 2023/24 confirms 2,925 written exams and 1,721 (not 1,703) practical exams were delivered in FY2023/24 (July 2023–June 2024, not "FY2024" as a calendar year); the pass figures (written 41% = 1,209/2,925; practical 15% = 253/1,703) appear only on a commercial coaching site (gdaydentist.com.au) citing the ADC report pp. 27–28 and could not be confirmed against the ADC's own published web report, which lists no pass rates. ADC written exam fee is AUD 2,122 (2026).

**Why it matters:** GCC is the easiest first export market for an Indian dental SaaS (low licensing friction, large Indian-dentist diaspora, English/Arabic, Dentee already sells in Oman), the UK second, Australia third. Sequence international localisation accordingly (AED/OMR billing, Arabic patient comms, then NHS/UK private, then Medicare/CDBS).

Sources:
- https://academically.com/blogs/how-indian-dentists-can-work-in-dubai/
- https://gulfdentistmcqs.com/demystifying-uae-licensing-for-dentists-a-comprehensive-guide-to-dha-moh-doh-and-emree/
- https://gdaydentist.com.au/
- https://adc.org.au/annual-report-2023-24
- https://adc.org.au/dentists/written-examination

<details><summary>Fact-check notes</summary>

Stated sources checked: (1) academically.com (updated 27 Aug 2026) confirms 150 MCQs, 170 min, 60% pass, no practical, ~2 years' experience, but lists only exam + DataFlow fees (AED 1,080 + 992 = ~2,020) and gives NO licence fee and NO specialist/3-years-post-MDS rule; it also notes a possible DHA Oral Assessment (5 scenario questions) that the claim omits. (2) gulfdentistmcqs.com is dated 9 Feb 2024 and explicitly flags its figures as "as of January 2023"; it is the sole source for the AED 3,020/4,020 licence (renewal) fees, the 1-yr internship + 2-yr experience rule, and the 3-years-post-master's restriction for Indian/Pakistani specialists; it is also internally inconsistent (DOH pass mark 65% vs 70%, 150 vs 100 MCQs). No official DHA/PQR document could be fetched (dha.gov.ae licensing and PQR URLs returned 404/empty). (3) gdaydentist.com.au gives written 41% (1,209/2,925) and practical 15% (253/1,703) for FY2024 citing ADC Annual Report 2023/24 pp. 27–28. The ADC's own 2023/24 annual report web page (adc.org.au/annual-report-2023-24) confirms 2,925 written exams delivered but states 1,721 practical exams delivered (vs 1,703 in the claim) and contains no pass numbers or rates; the full PDF was not reachable. ADC written exam page confirms AUD 2,122 fee and 2026–27 sitting dates. Verdict: the claim is a faithful summary of its secondary sources but (a) one ADC figure conflicts with the ADC report, (b) "FY2024" is imprecise (ADC FY = Jul 2023–Jun 2024), (c) the UAE fee and specialist-restriction figures are 2023-vintage blog data presented as current, with no primary-source confirmation. Web search budget was exhausted this turn, so fresh WebSearch queries could not be run; only direct fetches were possible. India-vs-global lens: no conflation; the claim correctly scopes to Indian BDS holders in Dubai (DHA), though note DOH (Abu Dhabi) and MOHAP have different pass marks/fees.

</details>

### 24. `corrected` · confidence medium

Per Tracxn's India HealthTech SaaS sector page (last updated 30 Sep 2026), funding into Indian HealthTech SaaS was $142M (2022), $120M (2023), $410M (2024), $199M (2025) and ~$27M year-to-date in 2026; the "244 funded companies" figure is Tracxn's cumulative sector count (51 at Series A+, 32 Series B+, 25 Series C+), not the number funded in 2025. HealthPlix has raised $43M total and is Series C-stage, but its most recent transaction was conventional debt (15 Mar 2023), not a fresh equity round; Eka Care's funding figures are paywalled on Tracxn and the "$19.5M, Series A" number could not be verified from an open source in this check. CareStack (Good Methods Global Inc.) has raised $79.1M across 6 rounds, last a Series B on 13 Jul 2022, with Accel, Delta Dental, Steadview and F-Prime Capital named (Straumann Group named in 2022 coverage of that round); note CareStack is headquartered in Celebration, Florida and sells primarily to US dental practices (registered office in Thiruvananthapuram), so it is a US-market comparable built by an Indian team, not an Indian clinic-software comparable. Clove Dental's QIA $50M (Nov 2023) and ">$215M total" figures could not be verified in this check (stated source returned HTTP 403; Clove's own site mentions no investors, only 730+ clinics in 31+ cities) and should be treated as unverified until a primary source is cited.

**Why it matters:** Capital is available but selective; generic EMRs (HealthPlix, Eka) already absorbed the 'clinic software' thesis, so a dental-only pitch must show a transactional/marketplace layer and an international ARPU story. Strategic investors (implant makers, insurers, dental distributors) have precedent in dental SaaS.

Sources:
- https://tracxn.com/d/explore/healthtech-saas-startups-in-india/__xC1CafNfPgol_bN4jyQ8Cb9qzHbUy1dzqMZxBwxUVR8
- https://www.bwdisrupt.com/article/dental-clinic-chain-clove-dental-to-invest-25-30m-over-the-next-5-years-109129
- https://tracxn.com/d/companies/carestack/__y_nu6zWxAt39Usy5aV1BDkEt6FeCxTcuBUe009-c55Q
- https://www.clovedental.in/
- https://www.clovedental.in/about-us
- https://healthplix.com/about
- https://www.eka.care/
- https://carestack.com/

<details><summary>Fact-check notes</summary>

Verified: Tracxn sector page (fetched, last updated 2026-09-30) shows exactly $142M/2022, $120M/2023, $410M/2024, $199M/2025, plus $27.4M 2026 YTD; it lists 244 funded companies as a cumulative sector total, not a 2025 count, so the claim's phrasing "in 2025 ... across 244 funded companies" is wrong. Tracxn also lists HealthPlix at $43M total, Series C stage, with latest round = conventional debt on 15 Mar 2023; Eka Care's amounts are locked/masked on the page, so "$19.5M Series A" is unverified (HealthPlix's own site names only Avataar, LSPD-like logo and JSW Ventures; Eka Care's site names no investors). Tracxn CareStack page: $79.1M across 6 rounds, latest Series B 13 Jul 2022, investors named Accel, Delta Dental, Steadview, F-Prime Capital; Straumann appears only via a 2022 news item; HQ Celebration, US, registered address Thiruvananthapuram - the claim omits F-Prime and treats a US-market company as a comparable for India. Clove Dental: the stated bwdisrupt source returned HTTP 403; Business Standard/ET/QIA/Wikipedia fetches failed (403/404/blocked); Clove's own site states 730+ clinics across 31+ cities and names no investors. Fresh WebSearch could not be run because this turn's shared web-search budget (200 calls) was exhausted before this subagent ran, so the Clove QIA $50M / >$215M figures remain unverified rather than disproven. India-vs-global lens: the Tracxn sector figures are India-specific and correctly scoped, but CareStack is a US-market product and should not be presented as an Indian clinic-software comparable.

</details>

### 25. `corrected` · confidence low

India has ~2,400 directory-listed dental labs: Rentech Digital's scraped business directory (data dated 1 Apr 2026) lists 2,403 labs, 96.5% single-owner operations (2,319), with Maharashtra 385, Tamil Nadu 268 and Uttar Pradesh 197 — a scraped-directory count, not a census, so the true number is likely higher. Market-size estimates diverge by ~22x on definition: MarketsandMarkets (report MD 5560 IND, Aug 2026) values the India dental lab market at $31.1M in 2025, reaching $38.3M by 2030 (11.1% CAGR), while Grand View Research's Horizon outlook (published Nov 2025) puts India dental laboratories at $699.7M in 2023 and $1,131.8M by 2030 (7.1% CAGR). Illusion Dental Lab (Andheri West, Mumbai) claims 1,800+ employees, 130+ cities served, 50+ countries and a "decade of legacy"; it is a division of Laxmi Dental Limited, a publicly listed Indian dental company, and its iScanPro intraoral scanner is free only to dentists who take Illusion Zirconia or Illusion Aligners packages (terms and conditions apply; otherwise sold on EMI). The dental-supply channel is fragmented across online marketplaces and regional depots; the largest online player, Dentalkart (VASA Denticity Ltd, New Delhi, founded 2016), claims ~20,000–20,480 SKUs, 450–500+ brands, 2–2.5 lakh customer clinics, 19,212 pincodes and 7 owned warehouses — not "35,000 products, 125 brands".

**Why it matters:** Lab-case tracking is a dental-only workflow no generic EMR offers, and labs are a two-sided network: once clinics send cases through the app, labs and later supply depots become paying marketplace participants and co-marketing partners (as Illusion already does with hardware bundles). This is the most defensible moat available in India.

Sources:
- https://rentechdigital.com/smartscraper/business-report-details/list-of-dental-laboratories-in-india
- https://www.marketsandmarkets.com/Market-Reports/geography/dental-lab-market/india
- https://www.grandviewresearch.com/horizon/outlook/dental-laboratories-market/india
- https://www.illusiondentallab.com/iscanpro/
- https://ensun.io/search/dental-supply/india
- https://www.illusiondentallab.com/
- https://www.illusiondentallab.com/about-us/
- https://www.linkedin.com/company/illusion-dental-laboratory

<details><summary>Fact-check notes</summary>

VERIFIED: (1) Rentech Digital page fetched 2026-10-11: 2,403 dental labs, 96.50% (2,319) single-owner, Maharashtra 385 / Tamil Nadu 268 / Uttar Pradesh 197, data as of April 1, 2026. Note the page says "single-owner", not single-location, and it is a scraped directory (SmartScraper), so it undercounts informal labs. (2) MarketsandMarkets India dental lab page: "$31.1 Million in 2025", $38.3M by 2030, CAGR 11.1%, report code MD 5560 IND dated August 2026 (a snapshot box also shows an unlabeled "USD 26.32 MN"). (3) Grand View Research Horizon India dental laboratories: $699.7M (2023) to $1,131.8M (2030), 7.1% CAGR 2024-2030, published 17 Nov 2025. The ~22x gap is a definitional difference between vendors, not a change over time. (4) Illusion Dental Lab homepage: "over 1,800 employees", "over 50 countries", FAQ "serves more than 130 cities", head office Mumbai (402 Akruti Arcade, Andheri W). The iScanPro page confirms the scanner is free with Illusion Zirconia or Illusion Aligners packages, "Terms and conditions apply", otherwise purchasable with EMI; the page gives no scale numbers itself. LinkedIn: Illusion is "a division of Laxmi Dental Limited... India's first publicly listed dental company", 1,001-5,000 employee band (538 visible on LinkedIn) — important missing context: the free-scanner play is backed by a listed company, not an independent lab. REFUTED: (5) The "Dentalkart 35,000 products, 125 brands" figures are not supported. The cited ensun.io page returned HTTP 429 and is a third-party directory. Dentalkart's own about-us page states 20,480 SKUs, 500+ brands, 2 lakh+ active clinics, 19,212 pincodes, 7 warehouse cities, founded 29 Aug 2016, HQ New Delhi; its homepage shows "20,000+ Products" and "450+ Trusted Brands" (body text inconsistently says 2,000 brands); LinkedIn (VASA Denticity Ltd) says 500+ brands, 2.5 lakh+ customers, 201-500 employees. So the product count is overstated ~1.7x and the brand count understated ~4x. India-vs-global check: all figures are India-specific; Illusion's "50+ countries" is an export claim, not India reach. Limitation: WebSearch budget was exhausted for this turn, so no independent search corroboration (e.g., Laxmi Dental annual report employee count, Dentalkart press) was possible; findings rest on fetching the stated sources plus the companies' own websites and LinkedIn pages.

</details>

### 26. `corrected` · confidence medium

Dental AI radiograph reads are sold as premium, separately-priced add-ons in the US/West, but the specific numbers in the claim are partly wrong or unverified. Verified as of Oct 2026: Open Dental lists "AI Image Analysis" at $149/month/location billed via BetterDiagnostics (vs its own US support fee of $199/month/location, i.e. the AI add-on costs ~75% of the PMS itself); CareStack's $1,299/month "Intelligence" tier bundles "AI-powered X-Ray Analysis by Overjet", which its $829/month "Essentials" tier excludes (a ~$470/month uplift). Pearl Second Opinion: Pearl publishes no price; Overjet's own comparison blog (18 Mar 2026) cites a $349/month no-contract list price via a third-party partner, while DentistDecoded (updated Mar 2026) estimates $500–1,500/month per practice; the "$299–549/month" range could not be verified (the cited Molar Report page is unreachable, expired TLS certificate). Overjet: quote-only, priced by location count and modules; the $1,500–3,500+/month figure is a single third-party estimate (DentistDecoded), not a published price. Diagnocat: publishes no pricing; the €30–70/dentist/month figure is again only DentistDecoded's estimate, and the "AUD 215/month" figure could not be sourced at all (no diagnocat.com.au domain resolves). India context: none of these vendors publish Indian pricing; Diagnocat's site does not list India among its served regions; Pearl cites only FDA clearance (no CDSCO mention); Open Dental waives its support fee in India but does not state that the $149 AI add-on is waived. So the Western add-on pricing pattern is real but cannot be assumed to transfer to India, where the comparable premium for AI x-ray reads is effectively undefined.

**Why it matters:** AI reads are a later-stage, higher-ARPU add-on; in India they should be a pay-per-image or ₹499–999/month upsell rather than core, and a reseller/API partnership (Diagnocat-style low per-dentist pricing) is more realistic than building first.

Sources:
- https://www.themolarreport.com/learn/pearl-pricing
- https://www.overjet.com/blog/overjet-vs-pearl-dental-ai-software
- https://dentistdecoded.com/articles/diagnocat-vs-pearl-ai-vs-overjet/
- https://www.opendental.com/site/fees.html
- https://carestack.com/pricing
- https://www.hellopearl.com/products/second-opinion
- https://diagnocat.com/
- https://www.betterdiagnostics.ai/pricing

<details><summary>Fact-check notes</summary>

Fetched sources: (1) opendental.com/site/fees.html confirms "AI Image Analysis $149/month/location, billed through BetterDiagnostics", US support $199/mo/location (first 12 months, raised from $179 on 2 Feb 2026), $149 thereafter, "Developing countries (e.g., India...) Free with limited support" — AI add-on not listed as free. (2) carestack.com/pricing confirms Essentials $829/mo and Intelligence $1,299/mo; comparison table marks "AI-powered X-Ray Analysis by Overjet" as No for Essentials, included in Intelligence; prices vary with locations/chairs/providers. (3) overjet.com/blog/overjet-vs-pearl-dental-ai-software (dated 18 Mar 2026): Pearl Second Opinion "$349/month by a third-party partner with no contract required"; Overjet pricing "customized based on practice size, location count, and selected modules" — no dollar figure. (4) dentistdecoded.com (published 7 Dec 2025, updated Mar 2026): Diagnocat ~€30–70/month per dentist (estimate), Pearl $500–1,500/month per practice, Overjet $1,500–3,500+/month; the article is internally inconsistent on Pearl's per-dentist vs per-practice model. (5) themolarreport.com/learn/pearl-pricing — fetch failed (certificate expired), so the $299–549 range has no verifiable source. (6) hellopearl.com/products/second-opinion — no pricing, FDA clearances only, no country list; hellopearl.com/pricing returns 404. (7) diagnocat.com — no pricing page (404); homepage region selector lists DACH, Spain, Italy, EU, UK, USA, Canada, South Africa, Oceania, "Other countries"; India not named; "Regulatory clearance or approval varies by country". diagnocat.com.au does not resolve, so AUD 215/month is unsourced. (8) betterdiagnostics.ai/pricing — no prices published. Fresh WebSearch could not be run: the shared per-turn web-search budget was exhausted, so verification relied on direct fetches of vendor and stated pages only. Net: 2 of 5 price points confirmed (Open Dental, CareStack), 1 roughly in range but mis-stated (Pearl $349 vs claimed $299–549; other estimate $500–1,500), 2 are unverified third-party estimates (Overjet, Diagnocat EUR) and 1 unsourced (Diagnocat AUD). The claim also presents US list prices as if globally applicable; no Indian pricing exists for any of them.

</details>

### 27. `corrected` · confidence medium

Naming conflicts for "AmpDent" (checked 2026-10-11): (1) ampdent.com is confirmed owned by AMP'D Entertainment Inc., an event lighting/audio/video/staging/rigging production company in Yorba Linda, California (info@ampdent.com) — not a dental business. (2) "AMP – Accelerate My Practice" (acceleratemypractice.com) is confirmed as a US dental practice coaching company founded in 2011 — a coaching/training brand rather than a software product. (3) "Amp Orthodontics & Kids Dental, Clemmons, NC" could NOT be verified: the Yelp page returns HTTP 403 to automated fetch and no alternate source was reachable; treat as unconfirmed. (4) The statement that amplifydentistry.com "currently presents AmpDent as a dental-student study platform in public beta" is NOT true as of 2026-10-11: both amplifydentistry.com and www.amplifydentistry.com fail DNS resolution (ENOTFOUND), and the founder's own repo deleted the entire Next.js web app (web/app/page.tsx, which carried the "Platform for Dental Students" copy and ampdent-logo assets) in commit 866eb91 "cleaning up repo" on 2026-08-16. The AmpDent study-app branding is therefore a historical artifact, not a live public-beta site. (5) A Trademarkia search for "ampdent" returns 0 US trademark results (consistent with "no AmpDent trademark found"), but this is a single third-party database; USPTO TESS/TSDR and IP-India class 9/42/44 searches remain incomplete, so trademark availability in India (the primary market) is unverified. Note the lens issue: all confirmed conflicts are US entities; no Indian "AmpDent"/"Amp Dent" conflict was checked or found, so the claim does not establish an India-specific conflict.

**Why it matters:** 'AmpDent' is usable in India today but carries US collision risk (AMP dental consulting, Amp Orthodontics) and the .com is taken; file Indian TM applications in classes 9, 42 and 44 early, hold amplifydentistry.com/.in as the umbrella, and consider a distinct product name for the clinic app (keeping AmpDent for the student/education funnel).

Sources:
- https://amplifydentistry.com/
- https://ampdent.com/company/
- https://www.yelp.com/biz/amp-orthodontics-and-kids-dental-clemmons
- https://acceleratemypractice.com/amp/
- https://amplifydentistry.com/ (DNS ENOTFOUND on 2026-10-11)
- https://www.yelp.com/biz/amp-orthodontics-and-kids-dental-clemmons (HTTP 403, unverified)
- https://www.trademarkia.com/search/trademarks?query=ampdent
- /Users/batman/Projects/amplify-dentistry git commit 866eb91 (2026-08-16) and 866eb91^:web/app/page.tsx

<details><summary>Fact-check notes</summary>

Direct fetch of https://ampdent.com/company/ confirms AMP'D Entertainment Inc., Yorba Linda CA, lighting/audio/video/staging/rigging, 20+ years, contact info@ampdent.com. Direct fetch of https://acceleratemypractice.com/amp/ confirms Accelerate My Practice (AMP), dental practice coaching founded 2011 (in-office coaching, treatment-plan tool, case acceptance calculator). Fetch of https://amplifydentistry.com/ and https://www.amplifydentistry.com/ both failed with getaddrinfo ENOTFOUND (domain does not resolve) — so the site cannot "currently present" anything; the claim's wording is stale. Local repo /Users/batman/Projects/amplify-dentistry: `git log --stat` shows commit 866eb91 (2026-08-16, "cleaning up repo") deleted the whole web/ Next.js app; `git show 866eb91^:web/app/page.tsx` contains "Platform for Dental Students" and ampdent-logo images but no "public beta" wording was found in the deleted code. Yelp (https://www.yelp.com/biz/amp-orthodontics-and-kids-dental-clemmons and m.yelp.com) returned HTTP 403; Healthgrades also 403; so the Clemmons NC practice is unverified. Trademarkia (https://www.trademarkia.com/search/trademarks?query=ampdent) shows "0 Trademark Results found for 'ampdent'". WebSearch could not be run: the per-turn web search budget (200 calls shared across agents) was already exhausted, so only direct WebFetch and local git evidence were used; the user can send a follow-up to continue searching.

</details>

### 28. `corrected` · confidence medium

Practo Prime (the marketplace booking product) charges the clinic/hospital, not the doctor, a one-time "technology fee" the first time a patient connects via Practo; Practo's provider FAQ says the fee is valid for 6 months with unlimited uncharged repeat appointments in that window (though the same page elsewhere describes validity as a "unique connection period, on a rolling basis"), and Practo publishes no rupee amount for the fee. Competitor Cufront (blog posts dated May–Aug 2026) estimates these per-appointment marketplace fees at roughly ₹1,500–3,000/month for a clinic seeing 30–50 patients/day, on top of a Ray subscription it puts at "~₹2,000+/month" (Practo's own Ray plans page lists CM Atom at ₹999/month and Clinic Management at ₹1,499/month on 1-year terms, ₹999/month on 4-year). The "10–20% of consult fee" figure does not appear in any of the stated sources and should be dropped or re-sourced. Practo's Ray Payment Solution (RPS) charges 2% per transaction on the CM Atom plan and 1.8% on the Clinic Management plan; Practo's separate "Cashless Appointments" feature states no usage charge and a flat ₹50 cancellation/no-show payout to the provider.

**Why it matters:** Dentists resent per-lead fees from a marketplace they do not control; a clinic-owned booking page (own domain/Google Business link) with zero per-booking fee is a sellable feature, while payments at ~1.5–2% is an accepted take rate to replicate.

Sources:
- https://help.practo.com/practo-prime/faqs-for-practo-prime-providers/
- https://www.cufront.com/blog/practo-ray-pricing-india-worth-it-2026
- https://www.practo.com/providers/clinics/ray/plans
- https://www.cufront.com/blog/practo-ray-alternatives-india-2026
- https://www.cufront.com/blog/cufront-vs-practo-new-clinic-2026
- https://help.practo.com/practo-prime/faqs-for-cashless-appointments-providers/
- https://help.practo.com/practo-ray/new-improvements-to-the-ray-payment-solution/
- https://help.practo.com/practo-ray/ray-connect-pricing-faqs/

<details><summary>Fact-check notes</summary>

Verified by opening all three stated sources plus five additional Practo help-center and Cufront pages (WebSearch was unavailable: the shared per-turn search budget was already exhausted, so no fresh searches could be run). (1) Practo Prime provider FAQ (help.practo.com) confirms: fee is charged to the clinic/hospital ("we do not charge doctors"; individual doctors/RMPs cannot subscribe), is a "one time technology fee the first time a patient uses our technology", "valid for a period of 6 months", with "unlimited repeat appointments... not charged for". Caveat: Q5/Q6 on the same page describe validity as "the unique connection period, on a rolling basis" with no length, so the 6-month figure is internally inconsistent. No rupee amount is published. (2) Cufront "Practo Ray Pricing in India 2026" (23 May 2026) and "7 Best Practo Ray Alternatives" (3 Aug 2026) give the ₹1,500–3,000/month per-appointment-fee estimate for 30–50 patients/day; Cufront is a competitor and frames it as a Practo Ray add-on, not explicitly as the Prime technology fee. (3) The "10–20% of consult fee" figure appears in NONE of the stated sources nor in any other Cufront or Practo page checked (cufront blog index, cufront-vs-practo-new-clinic-2026, Practo Prime FAQ, Cashless Appointments FAQ) — this part of the claim is unsupported and is the reason for refuted=true. (4) Practo Ray plans page lists RPS at "2%" (CM Atom, ₹999/mo on 1-yr) and "1.8%" (Clinic Management, ₹1,499/mo 1-yr, ₹999/mo 4-yr) — so "1.8–2%" is correct but plan-dependent, and it belongs to the Ray Payment Solution, not a product called "Practo Pay". Cufront's "~₹2,000+/month" Ray base-price estimate is higher than Practo's own listed prices. (5) Practo's "New improvements to the Ray Payment Solution" page says "lower transaction charges (coming soon)" and 3-day settlement, with no percentages. India-vs-global: all figures are India-specific (INR, Indian help center); the claim did not conflate global facts.

</details>

### 29. `corrected` · confidence medium

Recommended wedge (synthesis, partially corrected): target first-clinic and 1–3-chair owner-dentists in Karnataka/Maharashtra/Kerala/TN/Telugu states; v1 = mobile-first appointment book + odontogram treatment plan + tooth-numbered consent templates + WhatsApp reminders/recall + compliant Indian invoice (NOT a "GST invoice" by default: health-care services by clinical establishments are GST-exempt under Notification 12/2017-CT(Rate) Entry 74; GST applies only to taxable items such as purely cosmetic procedures or OTC product sales, so the invoice must support exempt + optional taxable line items) with UPI/EMI payment link + lab-case tracking. Pricing benchmarks (verified Oct 2026): Practo Ray lists ₹999/month (CM Atom, up to 50 doctors, 3,000 SMS, 2% payments fee) and ₹1,499/month on 1-year (Clinic Management, unlimited doctors, 8,000 SMS, 1.8% payments fee), with no WhatsApp-credit or patient-cap tiers; Clinicea is ₹1,999/₹2,999/₹3,999 per practitioner/month with no free plan; Fresha is free subscription with 20 free texts/month then ₹1.60–₹5.50 per WhatsApp message in India; Cliniko is USD 45 (1 practitioner) to USD 395/month with no INR pricing; Open Dental is USD 199→149/month per US location (USD 89 "other countries", free in developing countries). So a proposed Free → ₹1,499/clinic/month (₹14,999/yr, up to 3 doctors) → ₹2,999/clinic/month ladder sits at or above Practo Ray's unlimited-doctor tier and must justify itself on dental-specific features, not price. WhatsApp costs: since 1 July 2025 Meta bills per delivered template message (utility templates inside an open 24-hour service window are free), India marketing rates rose 1 Jan 2026, and India customers must migrate to INR billing by 31 Dec 2026 — so "WhatsApp credits" should be priced as pass-through per-message with margin, not conversation bundles. Payments margin: UPI and RuPay debit are zero-MDR in India; the 1.5–2% is only a gateway/platform fee (e.g., Razorpay charges a 2% platform fee +18% GST even on zero-MDR UPI, 0.99% for UPI QR), so a "1.5–2% take" on UPI is a cost the clinic pays the gateway, not a margin the app can retain; realistic margin is a share of card/EMI fees or a fixed platform fee. Channels: IDA (claims 75,000+ members, 29 state branches, 450+ local branches; CDE programs) is a real route; event booths: FAMDENT Hyderabad 7–8 Feb 2026 and FAMDENT Mumbai 12–14 Jun 2026 (Messe Düsseldorf India/Medicare Asia), WDS at Jio World Convention Centre Mumbai (2026 dates not confirmed on site), IDC 2026 dates/venue unverified. AmpDent student funnel, alumni, dealer/implant-company partnerships and GCC → UK → Australia expansion order remain unverified strategic hypotheses, not sourced facts.

**Why it matters:** This positions the product one notch above Practo Ray on dental depth at the same per-clinic price, undercuts Clinicea's per-practitioner model for multi-doctor clinics, neutralises free Open Dental with cloud/mobile/WhatsApp, and builds the only moat (labs, students, community) that generic EMRs and Western incumbents cannot easily copy.

Sources:
- https://www.practo.com/providers/clinics/ray/plans
- https://clinicea.com/pricing
- https://www.opendental.com/site/fees.html
- https://www.fresha.com/pricing
- https://www.cliniko.com/pricing/
- https://ida.org.in/
- https://developers.facebook.com/docs/whatsapp/pricing
- https://developers.facebook.com/docs/whatsapp/pricing/updates-to-pricing

<details><summary>Fact-check notes</summary>

Facts-and-dates lens: (1) The claim's pricing ladder is presented as if benchmarked, but the stated Practo Ray page shows CM Atom at 999/month (1-yr) with up to 50 doctors and 3,000 SMS, and Clinic Management at 1,499/month (1-yr; 999/month on 4-yr) with unlimited doctors and 8,000 SMS plus 1.8–2% payments fee; there are no WhatsApp-credit tiers or patient caps, so a ₹1,499 "up to 3 doctors" tier is priced equal to Practo's unlimited-doctor tier. (2) Clinicea charges per practitioner (₹1,999/₹2,999/₹3,999) and has no permanent free plan, so a per-clinic ₹2,999 "unlimited doctors" tier undercuts Clinicea but the comparison in the claim is apples-to-oranges. (3) Fresha is subscription-free with ₹1.60–₹5.50 per WhatsApp message in India after 20 free texts/month, which is the closest real analogue to the proposed "50 WhatsApp/month free" model. (4) Cliniko (USD 45–395, no INR) and Open Dental (USD 199→149 per US location; USD 89 other countries; free in developing countries; US rate raised from $179 on 2 Feb 2026) are global/US-priced and not Indian benchmarks — conflating them with Indian pricing is the india-vs-global error. (5) "GST invoice": health care services by a clinical establishment are exempt under Notification 12/2017-CT(Rate) Entry 74; only cosmetic procedures, pharmacy/product sales etc. are taxable, so a dental invoice is usually a GST-exempt invoice, not a GST invoice. (6) "1.5–2% payments as margin": UPI/RuPay debit have zero MDR; Razorpay's 2% is a platform fee (+18% GST) on top of zero MDR, 0.99% for UPI QR — the app cannot both offer UPI and keep 1.5–2% as its own margin without passing a gateway fee to dentists, which Practo also charges (1.8–2%). (7) WhatsApp: Meta moved to per-message pricing on 1 July 2025, utility templates in an open 24h window are free, India marketing rate increased 1 Jan 2026, INR billing mandatory for India WABAs by 31 Dec 2026 — "credits" bundles should reflect this. (8) IDA site confirms 75,000+ members, 29 state branches, 450+ local branches and CDE programs (IDC, WDS, DDS events) — supports the IDA channel. (9) FAMDENT 2026: Hyderabad 7–8 Feb 2026, Mumbai 12–14 Jun 2026 (Messe Düsseldorf India) — confirmed. WDS 2026 dates not readable on wds.org.in; IDC 2026 site not found. (10) AmpDent funnel, alumni, dealer/implant partnerships, and GCC→UK→Australia ordering could not be verified against any source. Note: WebSearch budget for this run was exhausted, so verification relied on direct WebFetch of stated and known primary pages; GST and WhatsApp INR rate-card numbers were not directly fetched (cleartax/Meta CSV returned 404), so GST exemption is cited via Notification 12/2017 as summarized by taxguru.in.

</details>

## Open questions

- What share of Indian dental clinics currently use any practice-management software vs paper/Excel/WhatsApp-only? No survey was found; a 200-dentist primary survey via AmpDent/IDA branches would settle it (search budget ran out before this could be checked further).
- What merchant discount rate / referral commission do Bajaj Finserv Health, SaveIn and Snapmint pay or charge dental clinics for 0% EMI, and can a PMS vendor earn a referral share? Needs direct conversation with their merchant teams.
- Exact current status and rate card of the ABDM Digital Health Incentive Scheme after 30 June 2025 (extension, per-record rates, whether a small-clinic PMS vendor can realistically claim it). Check abdm.gov.in corrigenda directly.
- Dentee's actual price list, customer count and churn; Dentee's Oman business size (as a proxy for GCC demand from an Indian dental-only product).
- GCC market sizing: number of dentists and clinics in UAE, Saudi, Oman, Qatar and the share who are Indian-trained; which PMS products dominate there (e.g., Dentally/Software of Excellence, local vendors) and at what AED pricing.
- Dentalkart, Toothlens and other Indian dental-tech funding rounds 2024–2026 (fetch of Inc42/Tracxn pages failed), to confirm investor appetite for dental-specific plays and potential supply-marketplace partners or competitors.
- Formal trademark clearance for 'AmpDent' and 'Amplify Dentistry' in India (IP India classes 9, 42, 44) and USPTO/UKIPO, given the AMP dental-consulting and Amp Orthodontics collisions found.
- What fraction of BDS/MDS graduates open their own clinic, and how many years after graduation on average? This determines the lag and conversion rate of the AmpDent student funnel; DCI/college placement data or an alumni survey is needed.
- Dental-college licensing: would colleges adopt a free 'teaching clinic' edition (Open Dental is free to schools) and what procurement/approval path do DCI-recognised colleges follow?
- Dentally's current onboarding fee and transactional module prices (the 2024 G-Cloud PDF could not be parsed) as a benchmark for UK pricing when expanding.
- Southeast Asia (Indonesia, Philippines, Vietnam, Malaysia) dental PMS competitive landscape and pricing, to decide whether SEA should precede or follow the UK in the expansion sequence.
