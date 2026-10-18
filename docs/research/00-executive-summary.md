# Executive summary: a dental-only clinic OS, India first

Research completed 11 October 2026 for the amplify-dentistry repo. Question asked: should Sailendra build a niche, dental-only clinic management product (Flutter apps for Android and iOS, plus a web surface) and, if so, how must it differ from the generic clinic software already on the market?

Method: ten research dimensions were run in parallel (global and Indian competitors, clinical workflows, front office and billing, regulation, tech architecture, dentist pain points, business model, patient side and AI, open-source and data standards). Of the 272 findings, 263 were fact-checked by two independent skeptics; a completeness critic then commissioned four gap topics (clinic licensing, e-prescription and teledentistry law, payments and tax plumbing, ABDM requirements), and two further agents covered chairside imaging reality and verbatim voice of Indian dentists. Four section writers and an editor produced the documents in this folder; the editor's 23 cross-section fixes have been applied.

## Verdict

**Build it, but build the product the evidence describes, not the one in the brief.** "Apps to manage clinics, patients, billing, CRM and records" is exactly where Practo Ray (₹999 to ₹1,499 a month plus 1.8 to 2% on payments; https://www.practo.com/providers/clinics/ray/plans), Clinicea, Dontin, Dento365 and DentsKart already sit. The defensible product is a clinical record organised around the tooth, on the dentist's phone, working offline, using WhatsApp as the channel, and billing in cash, UPI and GST with no insurance plumbing in the core.

Three facts carry the thesis.

- **Nobody charts on a phone.** Open Dental's tablet app says its chart is "not available when using a mobile phone device" and is US-only (https://www.opendental.com/manual/odtouchchart.html); Curve Mobile and Dentrix Ascend's app do not chart; a seven-year Practo Ray user reports it can mark a tooth but not a surface (https://yourdentalreview.com/practo-patient-management-software-ray/). Flutter's pub.dev has only whole-tooth pickers (https://pub.dev/packages/dental_teeth_selector).
- **Generic fails even for the best-funded operator.** Clove Dental's CIO evaluated more than ten EMRs, found none "truly dental", and built a tap-first EMR in-house (https://www.ciol.com/cxo-of-the-week-vikas-sood-cio-clove-dental/).
- **The real competitor is paper plus a personal WhatsApp number.** A 344-respondent Indian survey found paper-only ahead of hybrid for every record type, with 47.5% fearing data loss and 35.5% citing assistants who will not type (https://www.ovid.com/jnls/srmj/fulltext/10.4103/srmjrds.srmjrds_144_23~evaluating-the-knowledge-and-perception-of-electronic-health). 88.3% of surveyed Maharashtra dentists prefer WhatsApp for patient data and only 46% always obtain consent (https://pmc.ncbi.nlm.nih.gov/articles/PMC12375830/).

The honest prize is small. Indian dental practice-management software is a USD 88.8M market in 2025 growing to USD 241.9M by 2033 (https://www.grandviewresearch.com/horizon/outlook/dental-practice-management-software-market/india). Ten thousand clinics at a ₹1,500 blended ARPU is about ₹18 crore ARR. The business only works if acquisition cost is near zero and margin comes from messaging, payments, memberships and labs, which is the Fresha and Cliniko pattern, not the CareStack pattern.

## What the voice-of-customer research changed

The review mining in [06-voice-of-indian-dentists.md](06-voice-of-indian-dentists.md) is the most actionable piece of the research, and it moves the positioning from features to trust.

- Practo's defining failure in dentists' own words is support silence after payment, not missing features. Practo Pro sits at 3.1 stars from about 7,600 Google Play ratings; Practo's Trustpilot profile is 1.4 stars.
- At least six dentists on Capterra in late 2025 say they left Practo Ray because they believe patient data was sold to chains or other dentists. The claim could not be verified, but it is now folklore, and "we are a tool, not a channel; we never list you, never market to your patients, never charge per patient" is a line dentists are already writing.
- Data portability is a repeated wound: a seven-year Dentee user could not get an export; a fifteen-year Practo customer says she is forced to stay because of stored data; Practo's own terms say data is unavailable after voluntary termination.
- WhatsApp sent from the clinic's own number is the single most praised feature in the category and the most cited reason for switching vendors.
- Incumbent mobile apps crash, log users out and lose entries; Dentee's iOS app is at 1.7 stars.
- Willingness to pay for a solo clinic clusters around ₹1,000 a month; ₹1,500 and above is called expensive even by satisfied users, and renewal hikes and paid message packs are resented.

## What the imaging research changed

[05-imaging-reality-india.md](05-imaging-reality-india.md) settles how X-rays get into a phone-first app. Every intraoral sensor sold in India is wired USB on a Windows PC, mostly ₹49,000 to ₹85,000 Woodpecker, Waldent and Vatech units with free vendor software that exports JPEG or, in the premium tier, uncompressed DICOM. Dentists move X-rays to WhatsApp today by exporting or screenshotting to JPEG and then using WhatsApp Web. The recommended ingestion path is a tiny Windows watch-folder agent that publishes on the clinic LAN first and syncs to the cloud later, with a DICOM C-STORE listener for the Carestream, Sirona and Planmeca tier, and the phone camera as the primary device for clinical photos (77.6% of surveyed dentists already use one). AERB registration for dental units is self-serve on eLORA, valid ten years, with QA every two years, which makes a licence wallet with reminders a cheap trust feature.

## The decisions, with recommendations

1. **Stack: Flutter 3.47.** The four canvas-heavy surfaces (odontogram with surface hit-testing and mixed dentition, six-site perio grid, image annotation, signature) decide the product, and Flutter's single renderer plus its free pdf, printing and signature packages remove risk there. Costs: a slower first month, a web renderer whose wasm path needs Chromium 119+ (https://docs.flutter.dev/platform-integration/web/wasm), and a thinner hiring pool. Prove it with a one-week odontogram spike on a ₹12,000 Android (sub-16 ms frames, surface hit-testing, mixed dentition) before committing the repo layout. Spend the existing Expo, Next.js and NestJS skills on the public site and the service layer.
2. **Backend: Supabase in Mumbai with row-level security on clinic_id, Drift on device, PowerSync for offline sync.** NestJS only for WhatsApp, payment and ABDM webhooks. FCM for push. Never Firebase Auth or Firebase phone OTP (about ₹6 per SMS against ₹0.115 for a WhatsApp authentication template). Details in [03-architecture-and-data.md](03-architecture-and-data.md).
3. **Phone first; the front desk is v2.** The dentist is the receptionist in year one. A Flutter-web desk surface is gated on a two-week spike against a real clinic PC; until then only the Windows capture-bridge agent exists on the desktop.
4. **Wedge: the owner-dentist with one to three chairs, zero to seven years into ownership, in South India first.** Start with the Telugu network and Oasis Dental Clinic as design partner and baseline zero, then alumni WhatsApp groups and IDA branch CDE talks. The free Solo tier is the AmpDent student-to-associate-to-owner funnel.
5. **MVP is five things: chart, bill, WhatsApp, recall, lab**, plus export and audit, in thirteen build-ordered items with acceptance criteria in [02-product-spec.md](02-product-spec.md). Insurance, CDT, ABDM production certification, AI radiographs, a patient app, multi-branch and inventory are explicitly out of the first 90 days.
6. **Pricing: ₹0 Solo, ₹1,499 Clinic (up to three dentists), ₹2,999 Plus, published, with no add-on ladder.** One payments rule everywhere: nothing on cash and static-QR UPI collected in clinic; a single printed 0.25% platform split only on gateway-routed remote payments and EMI; UPI MDR passed through as its own line. Given the voice-of-customer evidence, test ₹999 against ₹1,499 in the first fifteen clinics before printing the page.
7. **Open-source only the tooth geometry and notation layer; keep the chart engine proprietary.** Two drafts wanted to open-source the whole odontogram; the market section calls it the one thing nobody can copy from a package. This is the recommendation, and it is Sailendra's call.
8. **Imaging: phone camera first, Windows watch-folder agent plus DICOM listener in v2, TWAIN capture only after per-model certification.**
9. **Compliance lives in the data model from day one.** Append-only clinical rows with an audit table; two unrelated consent objects (procedure consent with tooth numbers and a signature hash, and purpose-scoped DPDP consent); guardian links for under-18s; retention classes with legal hold; a breach register with 6-hour and 72-hour timers; a tenant region pin with India-only hosting; GST class on every invoice line; registration number on every receipt. The checklist is in [04-compliance-pricing-gtm.md](04-compliance-pricing-gtm.md).
10. **Two lines never to cross.** Never hold patient money (RBI's payment-aggregator rules need ₹15 crore net worth; https://rbi.org.in/Scripts/BS_ViewMasDirections.aspx?id=12896). Never write "AI detects"; image analysis makes the app a medical device under CDSCO rules and the FDA's January 2026 guidance (https://www.fda.gov/regulatory-information/search-fda-guidance-documents/clinical-decision-support-software). Partner with Pearl or Overjet instead.

## Assets already in hand

- Seventeen procedure-specific consent templates with tooth-number merge fields in the Oasis Dental Clinic site (filling, RCT, post and core, crown, extraction, surgical removal, RPD, FPD, complete denture, implant, perio surgery, pulp therapy and more). Consumer fora have awarded ₹3 to 5 lakh for missing written consent, so these are a genuine head start.
- The Oasis admin already models appointments, flat bills and staff on Firebase; it is the paper-parallel baseline for taps-to-invoice, no-shows and ticket size, which no published Indian source measures.
- The AmpDent dental-student audience, against 28,114 BDS seats a year, is the free-tier funnel.
- The darbhas monorepo's conventions for Supabase row-level security, NestJS services and Next.js deployment carry over to the service layer and the public site.

## The three biggest risks

1. **Willingness to pay against a paper competitor.** ₹1,499 is 1 to 2% of a year-one owner's take-home, the ₹999 floor is crowded, and all-in margin is only 20 to 63% at 100 clinics once ₹3 to 10 lakh a year of ABDM certification is amortised. Same-day Telugu and Hindi support is labour one person cannot carry past a few hundred clinics.
2. **Founder capacity and scope.** One founder new to Flutter must hand-build a canvas engine, ship thirteen MVP items, and pass three security audits plus NHA functional testing. "My software has 31 features, I use 4" is the failure mode to design against.
3. **Regulatory and platform churn on thin evidence.** UPI MDR from 15 October 2026, WhatsApp in-window pricing from 1 October, cosmetic-dentistry GST at 5% or 18%, the DCI-to-NDC transition, DPDP duties from 13 May 2027 and ABDM's real exit gates all move under the product. Of the research itself, 157 claims were corrected, 82 confirmed and 24 disputed, and the ABDM, AERB, CPCB, NABH and consumer-case figures are single-pass. Nothing from those blocks goes into marketing copy before a second check.

## This week

- Run the Flutter odontogram spike; this decides the repo layout.
- Resolve the strategic decisions above (odontogram licensing, payments rule, launch price test).
- File DLT entity registration (₹5,900), open the Google Play Organization account, and run an IP-India search in classes 9, 42 and 44, because ampdent.com and "AMP" are taken in the US.
- Book 15 to 20 dentist interviews and a 100-dentist IDA poll before fixing price.
- Instrument Oasis for taps-to-invoice, no-shows and ticket size; the first real Indian baseline is publishable.
- Get a CA opinion on cosmetic-dentistry GST and the Arunachal registration threshold, and ask integration.support@nha.gov.in for the real sandbox exit gates.

## Document map

| File | What it answers |
|---|---|
| [01-market-and-positioning.md](01-market-and-positioning.md) | Who the incumbents are, what they charge, why dental-only wins, twelve unfair advantages, risks |
| [02-product-spec.md](02-product-spec.md) | Principles, the 90-day MVP with acceptance criteria, clinical and front-office specs, AI scope, v2 and v3 |
| [03-architecture-and-data.md](03-architecture-and-data.md) | Flutter versus Expo, reference architecture, offline sync, canonical tooth model, standards, integrations, costs, repo layout |
| [04-compliance-pricing-gtm.md](04-compliance-pricing-gtm.md) | India day-one compliance, export markets, pricing, wedge, channels, month-by-month plan, playbooks to copy |
| [05-imaging-reality-india.md](05-imaging-reality-india.md) | Sensors, formats, how X-rays reach WhatsApp, AERB, ingestion architecture |
| [06-voice-of-indian-dentists.md](06-voice-of-indian-dentists.md) | Attributed review and forum evidence, operational baseline table, first-90-days implications |
| [07-contradictions-and-open-questions.md](07-contradictions-and-open-questions.md) | Where sources disagreed, what was corrected, what remains open |
| [08-sources.md](08-sources.md) | The sixty primary sources most worth reading |
| [appendix/](appendix/README.md) | All 330 raw findings with verification tags and URLs |
