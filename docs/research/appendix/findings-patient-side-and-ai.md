# Findings: patient-side-and-ai

Raw research output from the multi-agent sweep (October 2026). Each finding carries a verification tag:

- `confirmed` (18): passed independent fact-check
- `corrected` (10): fact-checker corrected the claim; text below is the corrected version

## Summary

Patient side. The strongest patient-facing wedge for an India-first dental product is WhatsApp, not a standalone patient app: Indian dentists already run their practices on it (a Pune survey found 96% of GDPs use WhatsApp, 98.5% share radiographs/photos on it, 72% say patients ask queries on it, and 63% obtain no consent for doing so), and Meta's platform now bills per delivered template message with India moving to INR billing in 2026. But the WhatsApp Business Messaging Policy contains a hard caveat that must shape the architecture: businesses must not use WhatsApp "for telemedicine or to send or request any health related information" where regulations require heightened protection, and healthcare products/drugs are a restricted vertical. The compliant pattern is therefore WhatsApp as the notification and deep-link layer (confirmations, utility reminders, payment links, review requests, WhatsApp Flows for structured intake) with clinical content (consent forms, treatment plans, records, images) living behind an authenticated web/app surface. On the regulatory side, India's DCI Code of Ethics 2014 permits factual websites with fee lists and "new service" announcements but bans boasting of cases/cures, self-photographs in publicity and solicitation, so before/after galleries and review nudges need careful product design; the DPDP Act 2023 (penalties up to Rs 250 crore, under-18 = child, verifiable parental consent) and Google's review policy (no gating, no incentives, no selective solicitation) set the other guardrails. Western benchmarks show what patients expect: Dentally charges £600/yr each for Online Booking and Patient Portal add-ons on a £2,220-£6,180/yr per-location base; NexHealth and Weave ($199+/mo) bundle booking, forms, reminders, payments and reviews; Clerri (Kleer+Membersy) claims membership patients make 76% more visits and 172% more cash production. Dental tourism is real but thin on dental-specific data: IBEF puts Indian medical tourism at US$8.71bn in 2025 with 507,244 foreign medical arrivals; the e-Medical visa requires a hospital letter on letterhead naming the patient, which the product can generate; WhatClinic lists 975 Indian dental clinics with implants at Rs 15k-60k and zirconia crowns Rs 17k-20k.

AI side. There is a clean regulatory line the product should respect. Anything that analyzes a radiograph, CBCT or intraoral image to detect pathology, measure bone loss or chart findings is a medical device: the FDA CDS guidance (final, Jan 29 2026) states that software processing medical images fails Criterion 1, and critically that software providing recommendations to patients or caregivers rather than HCPs "meet[s] the definition of a device". The dental AI imaging vendors have accordingly stacked 510(k)s: Overjet holds at least 12 (caries, calculus, periapical radiolucency, charting, pediatric caries, CBCT Assist Dec 2025, Iris Apr 2026), Pearl holds 8 Second Opinion clearances (first K210365 in Mar 2022 through Panoramic K250525 in Nov 2025), VideaHealth 4, Diagnocat its first US clearance K252934 in Jan 2026, and Dental Monitoring a De Novo. In India, CDSCO's Medical Device Rules 2017 now license all devices (Class A/B from Oct 2022, C/D from Oct 2023) and CDSCO has published a Sept 2021 software classification notice and a medical-device-software guidance; a small team should not ship diagnostic image AI without that path or a partner who holds clearances. What is realistic with Claude/OpenAI APIs and no clearance: ambient note generation and voice-driven perio/restorative charting (Bola AI, Videa Voice Perio, Kiroku at £27-£90/mo all do this unregulated; Anthropic offers a BAA on HIPAA-configured API), LLM front-desk and WhatsApp booking assistants (Arini claims 1M+ booked appointments; Meta's Feb 2026 AI Providers fee hits only general-purpose assistants, not business-specific bots), plain-language explanation of a dentist-authored treatment plan (safe only if it explains the dentist's plan and does not generate recommendations to the patient), patient education, smile simulation marketed as cosmetic visualisation (SmileCloud sells it without regulatory claims), and in-house aligner staging via vendor tools rather than your own.

## Findings

### 1. `confirmed` · confidence high

Meta switched the WhatsApp Business Platform to per-delivered-template-message pricing on July 1 2025 (marketing always billed; utility free inside the 24h customer-service window, billed outside; service/free-form replies inside the window free since Nov 1 2024; 72h free window after click-to-WhatsApp ads). India-specific: marketing rate increased Jan 1 2026, INR billing localisation launched Jan 1 2026 and all India WABAs must migrate to INR by Dec 31 2026 or delivery stops Jan 1 2027. Meta changes rates only on quarter-start dates with 1-month notice.

**Why it matters:** Model WhatsApp as a metered cost per clinic: appointment confirmations/reminders should be authored as UTILITY templates (cheap, and free when the patient replies first), recall/promo nudges as MARKETING (most expensive, needs opt-in). Build the WABA on INR billing from day one and expose per-clinic message spend in the admin.

Sources:
- https://developers.facebook.com/docs/whatsapp/pricing
- https://developers.facebook.com/docs/whatsapp/pricing/updates-to-pricing
- https://whatsappbusiness.com/products/platform-pricing/

### 2. `corrected` · confidence high

The WhatsApp Business Messaging Policy (https://whatsappbusiness.com/policy/, "Last updated: September 23, 2026"; business.whatsapp.com/policy 301-redirects there) says in Section 3 "Protect Data and Comply with Law": "Don't use WhatsApp for telemedicine or to send or request any health related information" — but only "if applicable regulations prohibit distribution of such information to systems that do not meet heightened requirements to handle health related information" (i.e. it is a conditional, regulation-triggered ban such as HIPAA in the US, not an absolute global ban; India currently has no such heightened-protection regime in force for dental clinics, so the clause does not automatically bite in India). Section 4 lists "Medical and healthcare products" and "Drugs, whether prescription, recreational, or otherwise" among regulated/restricted goods, and states these prohibitions "apply irrespective of the global or local licenses, registrations, or other approvals your business may hold"; over-the-counter drugs are carved out for an "Allowed Countries" list that includes India. Businesses may only initiate conversations with approved Message Templates, and "Outside the 24-hour customer service window, you may only send messages via approved Message Templates." Automation is allowed when responding inside the 24-hour window but the business "must also have available prompt, clear, and direct escalation paths" (in-chat human agent transfer, phone, email, web support, in-store visit, or support form). CORRECTION: opt-in itself is mandatory (Meta's opt-in doc: businesses "are required to obtain opt-in permission" and must clearly state the business name and that the person is opting in), but obtaining "separate opt-in by specific message category" and providing opt-out instructions and honoring them are listed under "Best Practices for Opt-In" as recommendations, not as hard policy requirements.

**Why it matters:** Architect WhatsApp as a notification + deep-link channel, not a clinical record channel: send 'your treatment plan is ready' with a link to an authenticated portal rather than the plan/X-ray itself; never send prescriptions or diagnoses in-chat; keep an opt-in ledger per message category (reminders vs marketing) in the patient record; always give a 'talk to the clinic' escape hatch in any LLM bot.

Sources:
- https://whatsappbusiness.com/policy/
- https://business.whatsapp.com/policy
- https://developers.facebook.com/docs/whatsapp/overview/getting-opt-in

<details><summary>Fact-check notes</summary>

Fetched https://whatsappbusiness.com/policy/ directly (2026-10-11). Verified verbatim: telemedicine sentence exists but is explicitly conditional on "applicable regulations" requiring "heightened requirements to handle health related information"; "Medical and healthcare products" and "Drugs, whether prescription, recreational, or otherwise" are in the Section 4 restricted list with the "irrespective of the global or local licenses, registrations, or other approvals" sentence; OTC drugs are allowed in listed countries including India; template-only outside the 24-hour window is verbatim; automation clause uses "must" for escalation paths. The claim's inaccuracy: per-category opt-in and honouring opt-outs appear under the heading "Best Practices for Opt-In" ("Obtaining separate opt-in by specific message category"; "Provide clear instructions for how people can opt out ... and honor these requests") — framed as things a business "can" do, not requirements. Meta's developer opt-in page confirms opt-in is required but per-category opt-in is only recommended to reduce blocks. Policy date is Sept 23, 2026, so the content is current as of October 2026. India-vs-global: the telemedicine clause is effectively a US-HIPAA-style trigger; the claim's parenthetical is correct but the policy should not be presented as banning dental clinic WhatsApp messaging in India. Note: the two requested WebSearch queries could not be run because the per-turn web search budget was exhausted by other agents; findings rest on the primary source fetches only.

</details>

### 3. `corrected` · confidence high

Meta's WhatsApp "AI Providers" policy (Business Solution Terms updated Jan 15 2026) lets AI Providers (LLM/generative-AI/general-purpose assistant providers) offer general-purpose AI assistants on WhatsApp only in markets where Meta is legally required to permit it. In those markets Meta charges AI Providers per non-template message (e.g. type text/image), reported as pricing_category AI_BOT in the Analytics API and category "general_purpose_ai" (billable true, pricing_model PMP, type regular) in webhooks. The charged-market list has changed: Italy was charged Feb 16 - May 12 2026; 29 EU/EEA countries (Austria through Sweden, incl. Iceland, Liechtenstein, Norway) were charged Mar 11 - May 12 2026; effective May 13 2026 Meta stopped charging in those markets, and as of Oct 2026 only Brazil (+55, from Mar 11 2026, no end date) remains listed. Meta states this "does NOT change how or what Meta charges all other businesses" (no charge for non-template messages inside an open customer-service window; window mechanics unchanged). India is not mentioned anywhere; an Indian dental clinic running its own patient-service bot is an ordinary business, not an "AI Provider", so none of this applies to it.

**Why it matters:** A clinic-specific booking/FAQ bot built on Claude or OpenAI is treated as normal business messaging, so the LLM front-desk assistant is viable on WhatsApp. Keep it narrowly scoped to the clinic's own services so it is never classified as a general-purpose assistant.

Sources:
- https://developers.facebook.com/documentation/business-messaging/whatsapp/pricing/ai-providers.md

<details><summary>Fact-check notes</summary>

The stated source (Meta's ai-providers pricing page, fetched 2026-10-11) confirms the Jan 15 2026 ToS date, the Feb 16 2026 charging start, the per-non-template-message model, the webhook category general_purpose_ai (plus Analytics pricing_category AI_BOT), and the verbatim sentence that the policy "does NOT change how or what Meta charges all other businesses using the WhatsApp Business Platform." However the claim is stale/imprecise on dates and markets: (1) Feb 16 2026 applied to Italy only; Brazil and the 29 EU/EEA countries started Mar 11 2026, not Feb 16. (2) "Effective May 13, 2026 ... Meta will no longer charge" non-template messages in Italy and the EU/EEA countries (all listed with end date May 12 2026); only Brazil has no end date, so as of Oct 2026 the present-tense "charges ... (Italy, EU/EEA, Brazil)" is wrong. (3) Rate cards were updated May 12 2026 with new versions dated July 1 2026, so any specific price would need re-checking; the page gives no per-message amounts. (4) The page does not specifically mention "customer-service bots"; it says "all other businesses". The page gives no reason for the May 13 reversal (no mention of AGCM/European Commission). Caveat: the per-turn WebSearch budget was exhausted before my two fresh searches could run, so corroboration beyond Meta's own page (e.g. regulator press releases) was not possible in this pass; the correction rests on the primary source. India-vs-global: the policy names no Indian scope; it is irrelevant to an Indian dental clinic SaaS whose WhatsApp bot is business-specific customer service, not a general-purpose AI assistant.

</details>

### 4. `confirmed` · confidence medium

WhatsApp Flows provide 'interactive, form-like experiences with structured screens' inside WhatsApp, with endpoint data exchange and encryption, and a Flow can be attached as a button on an approved template (buttons.flow_id, flow_action navigate/data_exchange) and sent via the /messages endpoint.

**Why it matters:** Pre-visit intake (medical history, allergies, pregnancy, anticoagulants), appointment slot selection and post-op symptom check-ins can be completed inside WhatsApp without the patient installing an app, which fits Indian patient behaviour. Keep the Flow payload to non-sensitive fields and push anything clinical to the portal given the policy above.

Sources:
- https://developers.facebook.com/documentation/business-messaging/whatsapp/flows/llms.txt
- https://developers.facebook.com/documentation/business-messaging/whatsapp/flows/guides/flows-templates.md
- https://developers.facebook.com/documentation/business-messaging/whatsapp/flows/guides/sendingaflow.md
- https://developers.facebook.com/documentation/business-messaging/whatsapp/flows/guides/implementingyourflowendpoint.md
- https://developers.facebook.com/docs/whatsapp/pricing

### 5. `confirmed` · confidence high

A peer-reviewed survey of 105 general dental practitioners in Pune (J Contemp Dent Pract, Oct 2018) found 96.19% had WhatsApp, 67.32% sought second opinions on it, 98.52% sent clinical photographs and 98.52% sent radiographs for second opinion, 72.27% said patients ask queries on WhatsApp, and 63.23% obtained no patient consent for sharing clinical material (36.76% only verbal consent).

**Why it matters:** Indian dentists' real workflow is WhatsApp-first and consent-poor. A niche product wins by formalising what they already do: in-app 'ask a colleague' referral/second-opinion sharing with a logged consent, and a WhatsApp inbox linked to the patient chart so patient queries stop living in the dentist's personal phone.

Sources:
- https://www.thejcdp.com/doi/JCDP/pdf/10.5005/jp-journals-10024-2415
- https://pubmed.ncbi.nlm.nih.gov/30498184/
- https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=pubmed&id=30498184&rettype=abstract&retmode=text
- https://api.crossref.org/works/10.5005/jp-journals-10024-2415
- https://www.ebi.ac.uk/europepmc/webservices/rest/search?query=DOI:10.5005/jp-journals-10024-2415&format=json&resultType=core
- https://api.semanticscholar.org/graph/v1/paper/DOI:10.5005/jp-journals-10024-2415?fields=title,abstract,year,venue,authors,externalIds
- https://www.thejcdp.com/doi/10.5005/jp-journals-10024-2415

### 6. `confirmed` · confidence high

The Revised Dentists (Code of Ethics) Regulations 2014 (DCI, No.DE-97-2014) permit websites 'where all information is factual' including 'details of treatment facilities available and the fees' (8.2.9) and announcements of new equipment/services 'without boastful claims' (8.2.7), but make it unethical to 'boast of cases, operations, cures or remedies or permit the publication of report thereof through any mode' (8.2), to print a self-photograph on letterhead/signboard (8.3.1), to employ agents/canvassers to obtain patients (8.1.4), or to run camps/handbills targeting schools, colleges and old-age homes (8.1.2). Records must be kept at least 3 years from start of treatment and furnished within 72 hours on request (3.3.1-3.3.2); 'efforts shall be made to digitalize' records (3.3.4).

**Why it matters:** Design before/after galleries, testimonials and review-request flows as patient-consented, factual, non-superlative content; avoid any 'best in city' copy generators, referral-commission features or bulk school-camp campaign tools. Build the 72-hour records export and 3-year (recommend longer) retention into the records module as a selling point ('DCI-compliant records').

Sources:
- https://dciindia.gov.in/Rule_Regulation.aspx
- https://indiankanoon.org/doc/7714501/
- https://dciindia.gov.in/Rule_Regulation/Gazette_Notification_reg_DCI_Revised_Dentists_Code_of_Ethics_Regulations_2014_27.06.2014.pdf
- https://dciindia.gov.in/Dentistact1948.aspx
- https://dciindia.gov.in/GazetteList.aspx
- https://dciindia.gov.in/Rule_Regulation/Gazette/30. Revised Dentists (Code of Ethics) Regulations, 2014/Revised Dentists (Code of Ethics) Regulations, 2014 (2nd amendment).pdf
- https://dciindia.gov.in/Rule_Regulation/Gazette/30. Revised Dentists (Code of Ethics) Regulations, 2014/Revised Dentists (Code of Ethics) Regulations, 2014 (2nd amend corri.).pdf
- https://indiankanoon.org/doc/7714501/ (checked: Kerala HC judgment, does not contain the regulation text)

### 7. `confirmed` · confidence medium

India's Telemedicine Practice Guidelines (March 2020, MCI Board of Governors with NITI Aayog) apply to Registered Medical Practitioners 'enrolled in the State Register or the National Register under the IMC Act 1956', i.e. allopathic doctors; dentists registered under the Dentists Act 1948 are not in scope. The guidelines expressly allow WhatsApp/chat as a telemedicine tool, treat patient-initiated contact as implied consent, require explicit consent for RMP-initiated consults, and limit prescribing by consult mode (List O any mode; List A video first consult; List B follow-up).

**Why it matters:** There is no DCI-issued teledentistry framework equivalent, so any tele-consult/e-prescription feature for dentists sits in a grey zone; mirror the MoHFW guideline (consent capture, identity verification, no Schedule X/narcotics, video for first consults) as a self-imposed standard and market it as 'built to the national telemedicine guideline' rather than claiming DCI compliance.

Sources:
- https://www.mohfw.gov.in/pdf/Telemedicine.pdf
- https://www.pib.gov.in/PressReleasePage.aspx?PRID=2242888
- https://dciindia.gov.in/Rule_Regulation/National_Dental_Commission_Act,_2023.pdf
- https://dciindia.gov.in/GazetteList.aspx
- https://dciindia.gov.in/
- https://europepmc.org/article/PMC/PMC8106416
- https://europepmc.org/article/PMC/PMC9122142
- https://europepmc.org/article/PMC/PMC13544647

### 8. `confirmed` · confidence high

Google's Maps user-contributed content policy prohibits merchants from offering incentives for reviews, offering incentives to revise/remove negative reviews, discouraging or prohibiting negative reviews or 'selectively solicit[ing] positive reviews', pressuring users to review on-premises, and setting staff review quotas; genuine solicitation without influence on content is permitted.

**Why it matters:** The review-request feature must send the same Google link to every completed patient (no NPS pre-screen that routes unhappy patients away from Google), no discount-for-review coupons, and ideally a delayed send after the patient leaves. Combine with DCI 8.2 (no boasting) when auto-generating review-response text.

Sources:
- https://support.google.com/contributionpolicy/answer/7400114
- https://support.google.com/contributionpolicy/answer/7445749
- https://support.google.com/business/answer/3038177

### 9. `confirmed` · confidence high

India's DPDP Act 2023 requires notice-and-consent for personal data, treats anyone under 18 as a child requiring parental/guardian consent and age verification, obliges data fiduciaries to keep data accurate, secure, erased when purpose ends, and to notify the Data Protection Board and each affected individual of breaches; penalties up to Rs 250 crore for security failures and Rs 200 crore for children's-data violations; appeals go to TDSAT.

**Why it matters:** Family accounts need a guardian-consent model (a parent's ABHA/phone owns minors' records until 18), consent for marketing/photos must be separable from consent for treatment, and the backend needs breach logging and per-purpose consent receipts. This is a selling point against generic EHRs that have not adapted to DPDP.

Sources:
- https://prsindia.org/billtrack/digital-personal-data-protection-bill-2023
- https://prsindia.org/files/bills_acts/acts_parliament/2023/Digital_Personal_Data_Protection_Act,_2023.pdf
- https://en.wikipedia.org/wiki/Digital_Personal_Data_Protection_Act,_2023
- https://en.wikipedia.org/wiki/Digital_Personal_Data_Protection_Rules,_2025
- https://www.scconline.com/blog/post/2025/11/14/meity-notified-digital-personal-data-protection-rules-2025/
- https://www.livelaw.in/top-stories/digital-personal-data-protection-rules-2025-notified-309928
- https://www.meity.gov.in/static/uploads/2025/11/53450e6e5dc0bfa85ebd78686cadad39.pdf

### 10. `confirmed` · confidence high

For US/UK credibility: under 45 CFR 164.508 a HIPAA authorization is required to use PHI (including identifiable photos) for marketing unless face-to-face or nominal gift; the authorization must specify the information, recipients, purpose, expiry, revocation right, and disclose any third-party remuneration; the individual gets a copy and treatment cannot be conditioned on signing.

**Why it matters:** Ship a standalone 'photo/testimonial use' e-consent template separate from the treatment consent, with expiry, revocation and an audit copy delivered to the patient; this satisfies HIPAA, DPDP and DCI simultaneously and makes before/after galleries safe to use.

Sources:
- https://www.law.cornell.edu/cfr/text/45/164.508
- https://www.law.cornell.edu/cfr/text/45/164.514
- https://www.law.cornell.edu/cfr/text/45/164.501
- https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/lawful-basis/consent/
- https://www.gdc-uk.org/standards-guidance/standards-and-guidance/standards-for-the-dental-team
- https://www.gdc-uk.org/standards-guidance/standards-and-guidance/gdc-guidance-for-dental-professionals

### 11. `corrected` · confidence high

Dentally (Henry Schein One UK Ltd; cloud dental PMS sold in the UK, Australia, Canada, Ireland and New Zealand — not India) publishes three tiers, not four, priced per month per site excluding VAT and scaled by number of surgeries: Starter £125/£195/£265/£335/£395/£455/£515/£575 per month for 1–8 surgeries (£1,500–£6,900/yr), Essentials £220–£720/month (£2,640–£8,640/yr), Pro £320–£945/month (£3,840–£11,340/yr); 9+ surgeries is "Contact us" and the FAQ says web prices are "indicative" with tailored proposals. Dentally Portal (online appointment booking, digital forms/medical history, Kiosk and Concierge check-in) is bundled in Essentials and Pro and is an add-on for Starter; no separate add-on price (e.g. "£600/location/year"), no per-SMS rate (e.g. "£0.085") and no "£5,000 onboarding fee" are published — Dentally offers three onboarding packages (full/part/no shutdown) without a listed price. The portal does let patients book, complete medical-history and other forms (with mobile-number + OTP verification), view treatment plans and make payments, as of October 2026.

**Why it matters:** A concrete Western price anchor: booking + portal are valued at roughly £1,200/location/year on top of the PMS, and SMS is metered. For India, WhatsApp utility messages are an order of magnitude cheaper than UK SMS, so bundling booking/portal/messaging into the base plan is a defensible differentiator.

Sources:
- https://www.dentally.com/
- https://www.dentally.com/features/patient-portal
- https://www.dentally.com/en-gb/pricing
- https://www.dentally.com/en-gb/resources/faqs
- https://www.dentally.com/en-gb/product/dentally-portal
- https://www.dentally.com/features/patient-portal (404 as of 2026-10-11)

<details><summary>Fact-check notes</summary>

Fetched https://www.dentally.com/en-gb/pricing on 2026-10-11 (via WebFetch and raw HTML via curl): the page shows exactly three packages (Starter, Essentials, Pro) with monthly prices "Excluding VAT" driven by a 1–9 surgeries slider; 1 surgery = £125/£220/£320 per month, 3 surgeries = £265/£380/£510, 8 surgeries = £575/£720/£945, 9 = "Contact us". The row "Dentally Portal (Digital Forms, Online Appointment Booking, Kiosk and Concierge)" appears in the comparison table; the FAQ page (https://www.dentally.com/en-gb/resources/faqs) states "Upgrading to the essentials plan for £220 a month unlocks ... access to a patient portal" and that for Starter/Essentials "examples of add-ons could include Dentally Vision or Portal" at extra cost, with no amounts given. No "£600", "£0.085", "160-char", "£5,000" or annual tier figures (£2,220/£6,180) appear anywhere on the pricing, FAQ, homepage or portal pages, so the claim's four-tier annual pricing, add-on prices, SMS rate and onboarding fee are unsupported on the live site as of Oct 2026 (they may derive from an older/third-party price sheet). The stated source https://www.dentally.com/features/patient-portal returns HTTP 404; the live portal page is https://www.dentally.com/en-gb/product/dentally-portal, which confirms online booking, online medical-history/forms (home or in-practice tablet via Concierge), OTP-secured access, and that the homepage describes Portal as making "bookings, forms, and payments simple". Region selector lists UK/AU/CA/IE/NZ only — Dentally has no India offering, so it is a global-comparator only for the India-first product. Caveat: the per-turn WebSearch budget was exhausted before my searches ran, so no fresh web searches could be performed; evidence is from direct fetches of dentally.com pages only.

</details>

### 12. `corrected` · confidence high

NexHealth (US) sells modular patient-experience software (Scheduling, Communications, Forms, Payments, Insurance Verification, Insights, built on its "Synchronizer" integration layer) on quote-based pricing with no published dollar prices; billing is month-to-month or annual (paid up front), with no cancellation fees but 90 days' notice required to not renew an annual contract, plus an offer to buy out existing vendor contracts. NexHealth claims to integrate with "dozens" of EHR/PMS systems; its supported-systems list shows roughly 70 named systems (several are versions of the same product, e.g. multiple Dentrix entries), not "about 100". Vendor-reported outcomes on nexhealth.com: last-minute cancellations filled in 16 minutes, balances collected 26 days faster, Perfect Smile Dental 35+ monthly Google bookings and 40% more positive reviews, Bastida Dental Group saving ~$2K/month in Zocdoc new-patient fees, Norbo Dental +$150K/yr from waitlist automation; these are undated marketing figures, not audited results. Weave's pricing page says plans start "from $199 per month" but publishes no per-tier price (all tiers show "Get Pricing"); tiers are Pro (1,500 bulk texts/month), Elite (3,000, "Most Popular") and Ultimate (15,000, up to 15 VoIP phones); features include VoIP phones, Text to Pay, Reviews, Digital Forms and AI Call Intelligence (marked "NEW", tier availability not shown); Insurance Verification and Practice Analytics are marked dental-only (Weave also serves optometry and veterinary). Both vendors are US-centric: NexHealth's integration list is US PMS/EHRs and its insurance verification targets US payers, and Weave's VoIP/text-to-pay/insurance features are built for the US market; neither has India-relevant pricing, PMS integrations or insurance workflows, so these figures are US benchmarks, not Indian market facts.

**Why it matters:** Feature parity checklist for the patient-engagement layer: online booking from Google Business Profile, automated waitlist backfill, pre-visit digital forms, two-way messaging, text/WhatsApp-to-pay, review requests and missed-call auto-text. Marketplace fees (Zocdoc, and Practo Prime in India) are a pain point you can position against with direct booking.

Sources:
- https://www.nexhealth.com/
- https://www.nexhealth.com/pricing
- https://www.nexhealth.com/resources
- https://www.getweave.com/pricing
- https://www.nexhealth.com/integrations

<details><summary>Fact-check notes</summary>

Checked 2026-10-11 via WebFetch of all four stated sources plus nexhealth.com/integrations. Mostly supported, with corrections: (1) Integration count: NexHealth says "dozens of EHRs" and lists ~70 named systems (71 entries incl. "Other"), not "about 100" - the claim overstates. (2) Cancellation terms: "no cancellation fees" is correct, but annual customers must give 90 days' non-renewal notice and monthly customers notice before the next cycle - the claim omits this. (3) Outcome stats: 16 minutes, 26 days faster, 35+ Google bookings (Perfect Smile Dental), $2K/month Zocdoc (Bastida Dental Group) all appear on the NexHealth homepage; the 16-min and 26-day figures are NOT on the /resources page the claim cites (they're homepage stats), and all are undated vendor marketing. (4) Weave: "from $199 per month" confirmed, but the page gives no per-tier prices; Pro/Elite/Ultimate with 1,500/3,000/15,000 bulk texts confirmed; Ultimate includes up to 15 phones; AI Call Intelligence marked NEW; Insurance Verification and Practice Analytics marked dental-only confirmed (eyewear notifications are optometry-only, vaccine reminders vet-only). The Weave AI Call Intelligence feature URL I guessed returned 404, so tier availability/launch date unverified. (5) India-vs-global: the claim is accurate as a US description but neither vendor is relevant to Indian pricing, PMS integrations, or insurance; should be framed as US benchmarks. Note: the WebSearch budget for this turn was exhausted before my two fresh searches could run, so acquisition/pricing-change news was not independently verified beyond the live vendor pages fetched today.

</details>

### 13. `confirmed` · confidence medium

Practo claims 30 crore+ patients/year, 1 lakh+ doctor partners, online booking across 9,000+ hospitals/clinics, and 10,000+ clinics on Practo Ray (its PMS, pitched at 'up to 70% fewer no-shows' and '3-click billing'); Ray is multi-specialty, not dental-specific.

**Why it matters:** Practo is the incumbent patient-discovery channel in India; a dental-only product should integrate (import Practo bookings, or at minimum reconcile) rather than fight it for discovery, while competing on clinical depth (tooth charting, perio, consent templates) that Ray lacks.

Sources:
- https://www.practo.com/providers/clinics
- https://www.practo.com/company/about
- https://www.practo.com/providers

### 14. `corrected` · confidence medium

Clerri (clerri.com) is the US dental membership-plan platform formed when Kleer and Membersy merged in May 2024 and rebranded as Clerri in July 2025 (kleer.com now 301-redirects to clerri.com). Its own marketing claims, as of Oct 2026: 25,000+ dentists, 200+ dental groups, "7 of the 10 largest DSOs", 50 US states. The homepage asserts membership patients deliver "76% more visits, 146% more procedures, 172% more cash production" than cash/insurance patients, but these are unsourced, self-reported vendor marketing figures with an explicit disclaimer ("Estimates are illustrative and not a guarantee of results"); Clerri's own /dentists page describes the 172% figure differently (an "average lift versus before joining a plan", i.e. members vs their own pre-enrollment behavior) and gives softer FAQ figures (members visit 2-3x more and accept ~2x more treatment than *uninsured* patients; ~$807 more production/year). The "86% accepted on a membership" number is a UI mockup in a treatment-plan illustration, not a reported result. Plans carry the US regulatory disclosure "Dental membership plans are NOT INSURANCE" (Clerri LLC is a licensed discount medical plan operator in 36 states; The CDI Group administers in California under Knox-Keene); plan setup uses Stripe products ("pick a Stripe product, set the fee"). Clerri names 13 PMS integrations (Dentrix, Dentrix Ascend, Dentrix Enterprise, Eaglesoft, Open Dental, Oryx, XLDent, Denticon, CareStack, Curve, Dolphin, PracticeWorks, Cloud9) while also claiming "20+" systems / "over 90%" of PMS coverage. Pricing is unpublished (per-practice quote, free setup, month-to-month). Everything here is US-only: the "not insurance"/DMPO framing is a US state-regulatory construct and none of the figures speak to the Indian dental market, where there is no comparable DMPO regime and private dental insurance penetration is minimal.

**Why it matters:** India has very low dental insurance penetration, so an in-house annual membership (e.g., Rs 2,999/yr for two cleanings, X-rays and 10% off treatment) with UPI autopay is a natural loyalty/recall mechanic; vendor stats suggest it lifts recall compliance and case acceptance. Check Indian insurance-regulation (IRDAI) wording so plans are framed as prepaid discounts, not insurance.

Sources:
- https://clerri.com/
- https://clerri.com/dentists
- https://clerri.com/integrations
- https://clerri.com/blog
- https://clerri.com/blog/kleer-is-now-clerri
- https://www.kleer.com/ (301 redirect to https://clerri.com/)

<details><summary>Fact-check notes</summary>

Fetched clerri.com homepage (Oct 2026): confirms verbatim "25,000+ Dentists", "200+ Groups", "50 States", "76% more visits", "146% more procedures", "172% more cash production", "86% accepted on a membership" (inside a treatment-plan mockup), "Dental membership plans are NOT INSURANCE", "pick a Stripe product, set the fee", "13 systems supported", plus the disclaimer "Estimates are illustrative and not a guarantee of results." No baseline, sample size, or methodology is given anywhere. Fetched clerri.com/dentists: the FAQ instead says members visit "2x to 3x more often than uninsured patients", accept "about 2x more treatment than uninsured patients", add "$807 more production per year", and frames 172% as "average lift versus before joining a plan" -- a different comparator than the homepage's "vs cash/insurance patients", so the claim's framing of 172% is not consistently supported even by Clerri itself. The "86%" is a mockup graphic, so the claim's "example treatment acceptance of 86%" overstates it as data. Fetched clerri.com/integrations: names exactly 13 PMSs but also says "20+" and "over 90%" coverage, so "13" is the named list, not a hard total. Fetched clerri.com/blog and the "Kleer Is Now Clerri" post (dated Oct 7, 2026): Kleer + Membersy joined forces May 2024, became Clerri July 2025; DMPO licenses in 36 states, Knox-Keene in CA, offices in Austin TX and Philadelphia PA; pricing unpublished. kleer.com returns 301 to clerri.com, confirming the Kleer lineage. membersy.com returned 403; clerri.com/about and /press 404. Fresh WebSearch could not be run: the per-turn WebSearch budget was already exhausted by sibling agents, so independent third-party corroboration (e.g. press releases, Dental Economics coverage) was not obtained; verification rests on Clerri's own pages. India lens: the entire "not insurance"/discount-medical-plan construct and all metrics are US-specific; nothing supports applying these lift figures to India.

</details>

### 15. `confirmed` · confidence high

Indian medical tourism was US$8.71bn in 2025, projected US$16.2bn by 2030 (13% CAGR), with 507,244 foreign nationals arriving for medical treatment in 2025 (about 5.5% of foreign tourist arrivals); no dental-specific breakdown is published. India's e-Medical Visa (multiple entry, up to 1 year per the main page, 60 days per the FAQ) requires 'a letter from the hospital in India, on its letterhead' with tentative admission date, patient name, nationality and passport number, applied at least 4 days before travel; up to two e-Medical Attendant visas are issued per patient.

**Why it matters:** A 'dental tourism pack' is cheap to build and highly differentiating: one-click visa invitation letter on clinic letterhead, itemised multi-currency quote with tooth numbers and FDI codes, treatment timeline across visits, records/X-ray export bundle (DICOM + PDF) for the home dentist, and an aftercare/warranty document. Note the dental share of the market is unquantified.

Sources:
- https://www.ibef.org/industry/healthcare-india
- https://indianvisaonline.gov.in/evisa/tvoa.html
- https://www.medicaltourism.com/destinations/india
- https://www.ibef.org/industry/healthcare-india/infographic
- https://www.ibef.org/industry/healthcare-india/showcase
- https://indianvisaonline.gov.in/evisa/
- https://www.mordorintelligence.com/industry-reports/india-medical-tourism-market

### 16. `corrected` · confidence medium

As of 2026-10-10 (page cache date), WhatClinic's India dentistry hub lists 975 clinics with 2,009 verified patient reviews (a separate link counts 3,087 dentistry reviews), with "prices from Rs 543"; the most recent displayed review is dated 14-08-2026. Prices on WhatClinic are per-clinic listings from a handful of first-page clinics, not a national average, and the ranges are wider than the claim states: implants Rs 15,000-54,000 on the sampled listings (e.g. Dr.Teeth Mumbai Rs 18,000-54,000; Dr.Motiwala Hyderabad Rs 38,713-48,391; Shah's Dental Serenity from Rs 15,000) - a Rs 60,000 ceiling is not shown and the dedicated implants page could not be fetched (404); crowns Rs 1,200 (metal) to Rs 30,000 across 964 crown clinics, with zirconia listed at Rs 8,500-25,600 depending on clinic (Joymitras Hyderabad Rs 8,500-16,000; Aarthi Priyas Chennai Rs 9,500-11,000; Trisa Navi Mumbai Rs 10,000-25,000; Dr. Pimenta's Goa Rs 17,920-25,600), so "zirconia Rs 17-20k" is a single-clinic figure, not typical; composite veneers Rs 10,000-12,000 (Dental Creations, Mumbai, single listing); "Hollywood smile" Rs 90,000-230,000 (Dr.Teeth, Mumbai, the only such listing); teeth whitening across 953 clinics ranges Rs 2,000-35,000 with most clinics in Rs 5,000-15,000 (the Rs 5,000-10,000 figure is one Vadodara clinic). Popular locations shown, in order: Goa, Tamil Nadu, Mumbai, Bangalore, Vadodara, Gujarat, Chennai, Kerala, Ahmedabad, Calangute, Hyderabad; the listing sample is heavily skewed to Mumbai, Goa, Chennai and Hyderabad clinics that court medical tourists, so these prices overstate what a typical Indian neighbourhood clinic charges and should not be used as Indian market benchmarks.

**Why it matters:** These are the price points foreign and NRI patients will benchmark against; the quoting engine should support package pricing (implant + abutment + crown) and show line items so quotes are comparable to Western itemised estimates. Goa's presence signals leisure-plus-dental travel as a segment.

Sources:
- https://www.whatclinic.com/dentists/india
- https://www.whatclinic.com/dentists/india/dental-crowns
- https://www.whatclinic.com/dentists/india/teeth-whitening

<details><summary>Fact-check notes</summary>

Fetched https://www.whatclinic.com/dentists/india (cached 2026/10/10): confirms "All 975 clinics that provide Dentistry in India" and "2009 verified patient reviews", Hollywood smile Rs 90,000-230,000 (Dr.Teeth Mumbai, only listing), composite veneers Rs 10,000-12,000 (Dental Creations Mumbai), whitening Rs 5,000-10,000 (Dr Preay Mehta's Dental Spa Vadodara) and locations list. Implant listings on the hub top out at Rs 54,000 (Dr.Teeth), not Rs 60,000; the implants sub-pages /dental-implants and /dental-implants-treatment returned 404 so the 60k ceiling could not be verified. Fetched /dentists/india/dental-crowns (964 clinics, 1,556 reviews, "prices from Rs 3,036"): crown prices run Rs 1,200 (metal, Joymitras Hyderabad) to Rs 30,000; zirconia prices span Rs 8,500-25,600 across four clinics, so "zirconia Rs 17-20k" matches only Dr. Pimenta's (Calangute) Rs 17,920-25,600 and is not representative; claim's Rs 4,000-20,000 crown range roughly matches Dent Ally (Rs 4,500-20,000) but understates the spread. Fetched /dentists/india/teeth-whitening (953 clinics, 1,338 reviews, "prices from Rs 3,036"): whitening ranges Rs 2,000-6,000 (Joymitras) up to Rs 20,000-35,000 (Park Dental Hyderabad) and Rs 5,000-90,000 (Stunning Dentistry Delhi), with most clinics Rs 5,000-15,000; so the claim's Rs 5-10k is a single-clinic figure. India-vs-global lens: WhatClinic is a medical-tourism directory; the sampled clinics (Mumbai, Goa/Calangute, Chennai, Hyderabad) price for international/affluent patients, so the numbers are upper-end Indian prices, not typical tier-2/3 clinic pricing (e.g. Arunachal Pradesh). The headline counts and the single-listing figures (975 clinics, 2,009 reviews, Hollywood smile, composite veneers) hold; the generalized price ranges and "zirconia Rs 17-20k" and "whitening Rs 5-10k" are overgeneralized from one clinic each, hence refuted/corrected. Note: the turn's WebSearch budget was exhausted, so the two requested fresh WebSearch queries could not be run; verification relied on three live WhatClinic page fetches dated 2026-10-10.

</details>

### 17. `confirmed` · confidence high

Razorpay charges 2% + 18% GST on UPI and domestic cards, 2.15% on corporate cards, up to 3% on international cards, and lists Payment Links at no extra platform fee beyond gateway charges (Payment Pages/Buttons add 0.2%); no healthcare-specific plan exists.

**Why it matters:** Send-a-payment-link over WhatsApp after the visit is viable at ~2% cost; international-card acceptance for dental tourists costs up to 3%, so quote in INR and let the patient bear FX where possible. Budget gateway fees into membership/EMI pricing.

Sources:
- https://razorpay.com/pricing/
- https://razorpay.com/payment-links/
- https://razorpay.com/docs/payments/payment-links/

### 18. `confirmed` · confidence high

The FDA's final Clinical Decision Support guidance (issued Jan 29 2026) states that software intended to 'acquire, process, or analyze a medical image' (including enhancement, measurement, identifying normal/abnormal structures, CADe/CADx) fails Non-Device criterion 1 and remains a device, and that 'software functions that support or provide recommendations to patients or caregivers - not HCPs - meet the definition of a device'. Non-device CDS must let the HCP independently review the basis and must not provide a specific diagnostic/treatment directive.

**Why it matters:** Two bright lines for a small team: (1) do not ship your own radiograph/CBCT/intraoral-photo analysis in the US without a 510(k) or a cleared partner; (2) an LLM 'explain your treatment plan' feature must only restate the dentist's already-authored plan and generic education, never generate recommendations to the patient, or it becomes a device. For the dentist-facing side, keep LLM output as reviewable suggestions with visible rationale.

Sources:
- https://www.fda.gov/regulatory-information/search-fda-guidance-documents/clinical-decision-support-software
- https://www.fda.gov/media/109618/download

### 19. `confirmed` · confidence high

Dental AI radiograph vendors hold stacked FDA 510(k)s: Overjet at least 12 (Dental Assist K210187 2021; Caries Assist 2022/2023; Calculus Assist Dec 2022; Periapical Radiolucency Assist Sep 2023; Charting Assist Feb/Aug 2024; Caries Assist-Pediatric Mar 2024; Image Enhancement Sep 2024; CBCT Assist Dec 5 2025; Iris Intelligent Imaging System Apr 10 2026); Pearl 8 Second Opinion clearances (original K210365 Mar 2022; CC Jan 2025; PA Radiolucency Contours Apr 2025; Pediatric, BLE, 3D May 2025; CS Jun 2025; Panoramic K250525 Nov 14 2025); VideaHealth 4 (Caries Assist Apr 2022, Perio Assist Feb 2023, Dental Assist Dec 2023, Videa Dental AI K251002 Sep 19 2025); Diagnocat K252934 Jan 15 2026; Denti.AI Detect Oct 2023; Dental Monitoring (De Novo + 510(k) May 2024); Dentsply DS Core Detect/Diagnosis/CBCT Anatomy 2025-26; 3Shape TRIOS Dx Apr 2026. Pearl claims native integration with 40+ imaging/PMS systems and patient-facing colour overlays, comparison mode and exportable reports; Diagnocat claims 40+ conditions on 2D and 60+ on 3D with 'patient-friendly, print-ready reports'.

**Why it matters:** Each pathology/measurement is a separate clearance costing years; do not build this. Instead design the imaging module with a partner slot (API/overlay import from Pearl, Diagnocat or Overjet) and sell AI findings as an upsell, since vendors claim AI overlays lift case acceptance (Videa: +20%). Note that none of these vendors states an Indian CDSCO licence on their sites.

Sources:
- https://api.fda.gov/device/510k.json?search=applicant:%22overjet%22&limit=20
- https://api.fda.gov/device/510k.json?search=device_name:%22second+opinion%22&limit=20
- https://api.fda.gov/device/510k.json?search=applicant:%22videahealth%22&limit=20
- https://www.fda.gov/medical-devices/artificial-intelligence-enabled-medical-devices/list-artificial-intelligence-enabled-medical-devices
- https://www.hellopearl.com/products/second-opinion
- https://diagnocat.com/
- https://www.videa.ai/
- https://api.fda.gov/device/510k.json?search=applicant:%22overjet%22&limit=20&skip=10

### 20. `corrected` · confidence medium

Under India's Medical Devices Rules 2017 (G.S.R. 78(E), 31 Jan 2017) all medical devices, including software, are regulated: S.O. 648(E) dated 11 Feb 2020 widened the device definition and G.S.R. 102(E) dated 11 Feb 2020 brought in registration, with licensing mandatory for Class A/B devices from 1 Oct 2022 and Class C/D from 1 Oct 2023; non-sterile, non-measuring Class A devices are exempt from licensing (G.S.R. 777(E), 14 Oct 2022) and need registration only. Class C/D manufacturing licences are granted by CDSCO (CLA) in Forms MD-9/MD-10 (applications MD-7/MD-8); import licences for all classes are MD-15 (application MD-14). Medical-device applications and the risk-classification lists run on the "CDSCO Online System for Medical Devices" (cdscomdonline.gov.in), which CDSCO's own page still also calls SUGAM. CDSCO's notice "Classification of Medical Devices Pertaining to Software" (File No. 29/Misc./03/2020-DC(198), published 13 Sep 2021) is the PRIMARY source classifying a "Diabetic Retinopathy Detection Device" software as Class C; the same notice classifies "Orthodontic Software" (diagnosis/treatment planning) as Class C, "Dental Abutment Design Software" as Class C, "Chairside dental CAD/CAM unit software" as Class B and "Supporting software for root canal treatment" planning as Class B. CDSCO published a "Guidance Document on Medical Device Software" (Doc No. CDSCO/MD/GD/MDSW/01/2026, listed 21 Jul 2026) which (a) states that Hospital/Clinical Information Systems used only for patient admission, appointment scheduling, insurance/billing and storing/transferring patient records are NOT medical devices, but become one if they add medical-purpose functions such as image analysis or clinical decision support; (b) classifies standalone software via a 3x3 matrix (critical/serious/non-serious situation x treat-diagnose/drive/inform); and (c) says that if a software is not on the published risk-classification list the applicant must apply on the CDSCO MD Online portal to obtain its risk class. The claim that CDSCO "activated a SUGAM Risk Classification Module on 27 Nov 2025 for novel intended uses" could not be verified: no CDSCO notice uses that phrase; the only 27 Nov 2025 items are risk-classification lists for Radiotherapy and Interventional Radiology, and the nearest notice is "Provision for Risk Classification of In-Vitro Diagnostic Medical Devices on the CDSCO Online System for Medical Devices" (6 Feb 2026). The cited i3cglobal page returns HTTP 404.

**Why it matters:** Diagnostic image-analysis AI sold in India is a notified medical device needing a CDSCO licence (likely Class B or C depending on claimed impact, by analogy with the retinopathy example), so treat it exactly as you treat the FDA line. Practice-management, scheduling, billing, consent and education functions are not devices. Read the two CDSCO software PDFs directly before writing any 'AI detects caries' copy.

Sources:
- https://cdsco.gov.in/opencms/opencms/en/Medical-Device-Diagnostics/Medical-Device-Diagnostics/
- https://cdsco.gov.in/opencms/system/modules/CDSCO.WEB/elements/download_file_division.jsp?num_id=NzY1OQ==
- https://cdsco.gov.in/opencms/system/modules/CDSCO.WEB/elements/download_file_division.jsp?num_id=MTQ1MTM=
- https://www.i3cglobal.com/samd-registration-india/
- https://cdsco.gov.in/opencms/resources/UploadCDSCOWeb/2018/UploadPublic_NoticesFiles/Software.pdf
- https://cdsco.gov.in/opencms/resources/UploadCDSCOWeb/2018/UploadPublic_NoticesFiles/Guidance%20document%20on%20Medical%20Device%20Software%20under%20MDR-2017.pdf
- https://cdsco.gov.in/opencms/opencms/en/Notifications/Public-Notices/
- https://cdscomdonline.gov.in/NewMedDev/ListOfApprovedRiskDevice

<details><summary>Fact-check notes</summary>

VERIFIED from CDSCO's Medical Device & Diagnostics page (fetched 11 Oct 2026): "S.O. 648(E) dated 11.02.2020 Medical Device Definition"; "G.S.R. 102(E) dated 11.02.2020 Registration of certain medical devices"; "Regulation of all Class A & B Medical Devices under Licensing regime, w.e.f 01.10.2022" (released 30 Sep 2022); "Regulation of all Class C & D Medical Devices Under Licensing regime, w.e.f 01.10.2023"; G.S.R. 777(E) dated 14.10.2022 exempting non-sterile non-measuring Class A devices; manufacturing licences for Class C/D via MD-7/MD-8 -> MD-9/MD-10, import via MD-14 -> MD-15 "on the SUGAM portal"; "Classification of Medical Device pertaining to Software under the provisions of Medical Devices Rules 2017" released 13 Sep 2021; "Guidance document on Medical Device Software under MDR-2017" released 21 Jul 2026. I downloaded both PDFs directly from cdsco.gov.in (the stated download_file_division.jsp links only return an iframe wrapper pointing to /opencms/resources/UploadCDSCOWeb/2018/UploadPublic_NoticesFiles/Software.pdf and ".../Guidance document on Medical Device Software under MDR-2017.pdf"). The 2021 notice (File No. 29/Misc./03/2020-DC (198), DCGI) row 25: "Diabetic Retinopathy Detection Device ... diagnostic screening to identify retinal diseases" = Class C; row 11 "Orthodontic Software ... diagnosis and treatment planning of orthodontic patients" = C; row 12 "Dental Abutment Design Software For Dental Laboratory" = C; row 44 "Chairside dental CAD/CAM unit software" = B; row 59 "Supporting software for root canal treatment" plan = B; Note 1: software driving/influencing a device takes the device's class. So the retinopathy Class C fact is from a PRIMARY CDSCO source, not merely a secondary one; the i3cglobal URL returned HTTP 404 and i3cglobal.com/samd/ has no India content. The guidance document carries Doc No. CDSCO/MD/GD/MDSW/01/2026, confirming the 2026 date; its Section 5.2 lists "Hospital/Clinical Information systems (HIS/CIS) ... intended only for patient admission, for scheduling patient appointments/visits, for insurance and billing/invoicing purposes ... to store and transfer patient information" as NOT medical devices, with the NOTE that adding image analysis/CDS/real-time monitoring functions "may be considered as a medical device"; Table 2 gives the standalone-MDSW classification matrix; Section 7 says CLA's MDSW list is published on the Online System for Medical Devices (cdscomdonline.gov.in/NewMedDev/ListOfApprovedRiskDevice) and that unlisted software requires an application on the CDSCO MD Online portal for a risk class; Table 5 note ii) confirms Class A (non-sterile, non-measuring) is exempt from licensing and needs registration under Chapter IIIB. NOT VERIFIED / REFUTED: "SUGAM Risk Classification Module activated Nov 27 2025 for novel intended uses" - the CDSCO Public Notices page (both halves fetched) has no entry with "Risk Classification Module" or "novel intended use"; the 27 Nov 2025 entries are "Risk classification list of medical devices pertaining to Radiotherapy" and "...Interventional Radiology"; the closest notice is "Provision for Risk Classification of In-Vitro Diagnostic Medical Devices on the CDSCO Online System for Medical Devices" (6 Feb 2026). Also, the device portal itself is branded "CDSCO Online System for Medical Devices" (cdscomdonline.gov.in), not SUGAM, although CDSCO's division page still says SUGAM. Caveat: WebSearch could not be run (per-turn search budget exhausted by the parent workflow), so verification relied on direct fetches of CDSCO primary sources; the India-vs-global lens finds no conflation - all facts are India-specific, and the dental-relevant takeaway is that a scheduling/billing/records clinic app is outside MDR 2017 unless it adds diagnostic/treatment-planning or AI image-analysis features (which CDSCO precedent puts at Class B-C).

</details>

### 21. `confirmed` · confidence high

Voice-driven charting and ambient dental scribing are shipped today as unregulated features: Bola AI offers Voice Perio (hands-free perio charting), Voice Restorative ('less than 2 minutes' per chart) and AI Scribe, integrated with Dentrix, Dentrix Ascend, Eaglesoft, Open Dental, Curve and Fuse, claiming 99% accuracy and 7-9M exams; VideaHealth now bundles Voice Perio and Voice Notes alongside its cleared imaging AI; Dentrix Ascend advertises Voice Notes and 'Clinical AI Documentation'; Kiroku (UK, founded 2017) sells an ambient Co-Pilot that writes notes into 50-80+ dental templates at A$50/£26.99 and A$165/£89.99 per month, states GDPR/HIPAA compliance, stores notes not audio, and recommends asking patient permission before recording.

**Why it matters:** This is the highest-value AI feature a small team can build with Claude/OpenAI without clearance: a tooth-numbered voice grammar ('16 MB 3-2-4 bleeding'), structured note templates per procedure (RCT, extraction, crown, scaling), multilingual (Hindi/Telugu/English code-switching) ambient notes, and a recording-consent toggle. Price Kiroku-like (~Rs 2,000-5,000/dentist/month) and store transcripts not audio.

Sources:
- https://bola.ai/
- https://www.videa.ai/
- https://www.dentrixascend.com/
- https://www.trykiroku.com/
- https://www.videa.ai/news
- https://www.trykiroku.com/pricing
- https://www.trykiroku.com/about

### 22. `confirmed` · confidence high

Anthropic offers a BAA for HIPAA-ready services: the Claude API with HIPAA configuration enabled (no Zero Data Retention required for those), and HIPAA-ready Enterprise plans; ZDR is requested via Sales and is reviewed per organisation.

**Why it matters:** For US/UK credibility the scribe and chatbot can run on the Claude API under a BAA; for India, DPDP has no BAA concept but the same HIPAA-configured endpoint plus no-training/ZDR settings is the right default and a good trust-page talking point.

Sources:
- https://privacy.claude.com/en/articles/8956058-i-have-a-question-about-hipaa-compliance
- https://privacy.claude.com/en/articles/8114513-business-associate-agreements-baa-for-commercial-customers
- https://platform.claude.com/docs/en/manage-claude/api-and-data-retention
- https://platform.claude.com/docs/en/build-with-claude/zero-data-retention
- https://www.anthropic.com/news/healthcare-life-sciences
- https://claude.com/contact-sales

### 23. `confirmed` · confidence medium

LLM front-desk agents for dentistry are a live category: Arini sells a 24/7 AI phone receptionist plus reactivation of inactive patients and online scheduling, claiming 1,000,000+ booked appointments and case studies of $1.5M+ overflow production (1,600+ calls/month) and $1M+ production at single groups; Dentrix Ascend now advertises AI call summaries, 'Ascend MCP' agent layer and AI review responses. Henry Schein One's Ascend also advertises AI agents that call payers for eligibility.

**Why it matters:** In India the equivalent is a WhatsApp + missed-call AI receptionist (book, reschedule, answer price/timing FAQs, trigger recall) rather than voice phone AI; it is buildable on Claude with function-calling into your scheduling API and needs no clearance. Expose an MCP/agent interface early so dentists can ask 'who is due for recall this month' in natural language.

Sources:
- https://www.arini.ai/
- https://www.dentrixascend.com/
- https://www.dentrixascend.com/ai
- https://www.henryscheinone.com/news

### 24. `corrected` · confidence medium

SmileCloud (smilecloud.com, checked 2026-10-11) sells web-based AI smile design that "turns a single photo into a facially aligned smile design", a "patent pending" photorealistic before/after video tool (10 videos/month on Starter; 30/month per subscription shared across the team on Business), mobile apps "available for iOS and Android", 3D Blueprint and Biometric Motion (Business tier only), and in-app ordering from third-party design/manufacturing partners such as Metalab ("optional, on-demand, and fully managed by third-party providers"). Tiers are Lite, Starter, Business and Dental Group (quote-based, 3+ locations); the pricing page shows no currency amounts in the region fetched, offers monthly or annual billing ("Save up to 20%") and a 14-day free trial of the full Business plan with no credit card. The homepage lists four US patent numbers (12,154,243; 12,154,244; 12,496,172; 12,544,197) plus Dutch patent NL 2037626 for Blueprint. It is NOT true that SmileCloud makes no device/regulatory claims: the pricing page states Blueprint is "registered as a medical device", available only in specific countries (e.g. Germany, France, Italy) with Instructions for Use, and Blueprint/Biometric Motion are shown as "Not available in your region"; no FDA or CE-certificate claim is made. Digital Smile Design (digitalsmiledesign.com) monetises mainly via courses/DSD Online, team consultancy, a Planning Center & Lab, DSD Clinic Certification/membership and a Patient Management Portal, with no software pricing on-site; however it does offer a self-serve "DSD App" for clinicians on the Apple App Store (page title bills it as "free high-impact smile design"), so "no self-serve software" is an overstatement. Dental Monitoring (dentalmonitoring.com) describes itself as "FDA DE NOVO APPROVED & MDR CERTIFIED", "the orthodontic industry's first and only AI-powered Software as a Medical Device", with 2M+ patients monitored, 8,000+ dental professionals, 50 countries, 2B+ photos, 60+ parameters (21 under cleared indications), 80+ patents, a $150M growth round valuing it over $1B, and an acquisition of Loum; its footer notes only some modules are medical devices and status "may differ across countries". None of the three sites mentions India availability or Indian regulatory (CDSCO) status; SmileCloud's device features are explicitly region-restricted and Dental Monitoring's offices are in Austin, Paris, London, Sydney, Hong Kong and Tokyo.

**Why it matters:** Cosmetic smile simulation is sold as a visualisation/communication tool without device claims, so a 'show me my new smile' feature is feasible via SmileCloud-style partnership or your own generative pipeline, provided marketing never implies diagnosis or treatment outcome guarantees. Remote monitoring that drives clinical decisions (aligner tracking) is regulated, so leave it to Dental Monitoring or keep it to patient-submitted photos reviewed by the dentist.

Sources:
- https://www.smilecloud.com/
- https://www.smilecloud.com/pricing
- https://digitalsmiledesign.com/
- https://dentalmonitoring.com/
- https://www.smilecloud.com/blueprint
- https://www.smilecloud.com/metalab
- https://digitalsmiledesign.com/dsd-app
- https://dentalmonitoring.com/about-us/

<details><summary>Fact-check notes</summary>

Fetched all four stated sources plus smilecloud.com/blueprint, smilecloud.com/metalab, digitalsmiledesign.com/dsd-app and dentalmonitoring.com/about-us on 2026-10-11. Confirmed: SmileCloud single-photo AI design, 10/30 video simulations (Starter/Business), iOS+Android, Blueprint, Biometric Motion, Metalab integration, Lite/Starter/Business/Dental Group tiers, annual billing "Save up to 20%", 14-day trial (full Business plan, no card), four US patent numbers; DSD course/Planning Center/portal model; Dental Monitoring "FDA De Novo approved & MDR certified", 2M+ patients, 8,000+ professionals, 50 countries. Refuted/corrected: (1) SmileCloud DOES make a device claim: pricing page says Blueprint is "registered as a medical device" with country-limited availability (Germany, France, Italy listed) and Instructions for Use, and Blueprint/Biometric Motion show "Not available in your region" (homepage itself lists no FDA/CE). (2) Patents: four US numbers plus NL 2037626 for Blueprint; the video simulation tool is "patent pending", not patented. (3) Pricing page lists monthly-or-annual billing, not annual-only, and shows no currency amounts in the fetched region. (4) Metalab is a third-party provider, not a SmileCloud-run lab. (5) DSD has a self-serve DSD App for any clinician (free per page title), so "rather than self-serve software" is overstated. (6) India context: none of the sites mention India; SmileCloud device features are region-gated; Dental Monitoring lists no India office. Limitation: the per-turn WebSearch budget was exhausted, so no fresh WebSearch queries could be run; verification relied on direct fetches of the vendors' current pages. Dental Monitoring's exact FDA De Novo date and any 2025-26 acquisition/ownership change could not be independently checked.

</details>

### 25. `confirmed` · confidence medium

3Shape Clear Aligner Studio lets clinics scan, auto-segment, wax-up and stage aligners in a guided in-house workflow with lab-grade setup options and compatibility with many printers/trimmers, embedded in the 3Shape Unite ecosystem; it discloses no pricing or AI claims and notes Ortho System products are region-restricted.

**Why it matters:** Aligner planning is a scanner-vendor ecosystem play (3Shape, Align ClinCheck, uLab); the clinic app should integrate case status and patient-facing aligner-wear reminders/compliance check-ins, not try to do tooth-movement staging.

Sources:
- https://www.3shape.com/en/software/clear-aligner-studio
- https://www.3shape.com/en/software/unite
- https://www.3shape.com/en/software/ortho-system

### 26. `confirmed` · confidence medium

Consult-PRO offers 3D animated dental procedure videos in 20 languages via chairside, web, email/weblink and cloud DSO products on a 15-day free trial, with pricing and third-party embedding terms not published; Pearl and Diagnocat both position AI overlays and 'patient-friendly' reports as case-acceptance tools.

**Why it matters:** Procedure explainers in Indian languages are a gap no global vendor fills well; licensing an animation library or generating short vernacular explainer clips per procedure (RCT, extraction, crown, implant) that attach to the e-sign consent flow is low-regulatory-risk and directly tied to case acceptance.

Sources:
- https://www.consult-pro.com/
- https://www.hellopearl.com/products/second-opinion
- https://diagnocat.com/
- https://www.consult-pro.com/free-trial

### 27. `corrected` · confidence medium

Treatment-plan e-acceptance is offered by some, not all, Western engagement suites, and the two vendors named behave differently. Dental Intelligence (dentalintel.com) does offer it: patients can "digitally review, sign and submit treatment plans" sent by text/email or on a kiosk, with the signed copy filed to the chart, plus online intake forms and procedure-code-triggered digital consents that "automatically populate applicable tooth numbers", integrated with Dentrix/Dentrix Ascend, Eaglesoft, Open Dental, Denticon and Fuse (write-back "varies across PMS integrations"). Yapi (now branded "Yapi + DoctorLogic") offers paperless online forms, appointment/recall reminders and "Treatment Plan Reminders" (Yapi Premier tier) that read plan status from Dentrix, Eaglesoft or Open Dental and chase already-accepted, unscheduled treatment, but its public pages do not advertise digital treatment-plan presentation or e-signature acceptance. Dentally Portal (UK/IE/AU/NZ/CA markets; the URL /features/patient-portal is dead, current page is /en-gb/product/dentally-portal) offers online medical history and forms, online booking, payments and "online signing" gated by a verified mobile number and OTP, and patients can view treatment plans, but the page does not claim online treatment-plan acceptance. In India, Practo Ray's public page advertises patient records, templates, automated appointment SMS and course-of-treatment scheduling but no consent forms, e-signature, tooth chart or treatment-plan acceptance, and Dentee's homepage likewise advertises none; so, as of October 2026, tooth-numbered e-consent is not advertised by the Indian-market tools reviewed (Practo Ray, Dentee), though this is a two-vendor sample, not a market-wide survey.

**Why it matters:** Your existing consent templates with {tooth_numbers} placeholders are a genuine niche asset: make the treatment plan itself the e-sign object (plan line items with FDI tooth numbers + price + consent text), capture signature/OTP via a portal link sent on WhatsApp, and store the signed PDF against the 3-year DCI retention rule.

Sources:
- https://yapiapp.com/
- https://www.dentally.com/features/patient-portal
- https://yapiapp.com/treatment-plan-reminders/
- https://www.dentalintel.com/
- https://www.dentalintel.com/treatment-plans
- https://www.dentalintel.com/consents
- https://www.dentalintel.com/online-dental-forms
- https://www.dentally.com/features

<details><summary>Fact-check notes</summary>

Checked directly on 2026-10-11 (web search budget was exhausted for this turn, so verification used direct page fetches of vendor sites). (1) Stated source https://www.dentally.com/features/patient-portal returns HTTP 404; the live page is https://www.dentally.com/en-gb/product/dentally-portal, which describes online medical history, forms, booking, payments and "online signing can only be accessed with a verified mobile number", and a testimonial about patients viewing treatment plans at home, but no online treatment-plan acceptance. Dentally's region selector covers UK, Australia, Canada, Ireland, New Zealand (not US/India). (2) https://yapiapp.com/ shows "Yapi + DoctorLogic" branding, paperless online forms, confirmations/recall reminders, integrations with Dentrix Office/Ascend, Eaglesoft, Open Dental; https://yapiapp.com/treatment-plan-reminders/ describes automated texts for accepted-but-unscheduled treatment (Yapi Premier) reading status from the PMS, with no mention of digital presentation or e-signature. So "Yapi-class tools offer treatment-plan presentation" is not supported for Yapi. (3) https://www.dentalintel.com/treatment-plans: patients "digitally review, sign and submit treatment plans in minutes", sent via text/email or kiosk, integrates with Eaglesoft, Dentrix, Dentrix Ascend, Denticon, Fuse, Open Dental. https://www.dentalintel.com/consents: consents auto-triggered by procedure codes, "We even automatically populate applicable tooth numbers and/or provider names", e-signature stored in the PMS. https://www.dentalintel.com/online-dental-forms: paperless intake, PDF saved to chart, "Write-back capabilities vary across PMS integrations". Note: tooth-numbered e-consent therefore IS a shipped Western feature (DI), relevant context for the India gap. (4) https://www.practo.com/ray: page lists patient records/templates, automated appointment SMS, course-of-treatment scheduling; no consent form, e-signature, tooth chart or treatment-plan acceptance features named. https://www.dentee.com/ homepage advertises none of these either. The claim's "standard" generalization and the Yapi attribution are what is refuted; the India-side statement holds for the tools checked but is a narrow sample.

</details>

### 28. `corrected` · confidence medium

Partially corrected (core numbers verified on 2026-10-11; characterisation needed fixes). Vendor-reported AI/patient-side metrics, as of October 2026: VideaHealth (videa.ai) lists +10% same-store growth, +20% case acceptance and +119% increase in caries detection as unattributed, un-footnoted "Proven results" with no timeframe or methodology; its +8% gross production per patient (and +20% periodontal treatment-plan value) come from a single customer case study (Independence Dental), not an aggregate; the homepage does not mention FDA clearance and shows "90,000+ clinicians". Pearl's Second Opinion page gives two inconsistent accuracy figures, 94% ("validated by an independent third party", unnamed, no citation) and "over 95%" in the FAQ, so Pearl's figure is not strictly "unaudited" but its validator and study are undisclosed; Pearl also claims a 30% average lift in case acceptance, 37% more disease identified, 35%/44% more diagnoses (footnotes 1-3 whose text is absent) and FDA clearance for intraoral and panoramic radiographs. NexHealth's resources page offers only single-practice case studies: Perfect Smile Dental Care ("more than 35 new bookings from Google", the word "monthly" appears only in the headline, and "a 40% increase in positive patient reviews", no baseline/timeframe), Bastida Dental Group (~$2k/month saved vs Zocdoc), Daily Smiles Dental (fewer no-shows, no number). None of the three pages publishes an aggregate or independently verified online-booking conversion rate or no-show-reduction percentage. India/global context: none of the three pages mentions India, Indian pricing, or CDSCO status; Pearl's only regulatory reference is US FDA, and the production/case-acceptance figures derive from US (and one UK/Scotland) practices, so they cannot be assumed to transfer to Indian clinics.

**Why it matters:** Do not quote industry conversion numbers in your pitch; instead instrument your own funnel (WhatsApp sent -> link opened -> slot booked -> attended) from day one so you can publish real Indian benchmarks, which no competitor has.

Sources:
- https://www.videa.ai/
- https://www.hellopearl.com/products/second-opinion
- https://www.nexhealth.com/resources

<details><summary>Fact-check notes</summary>

Fetched all three stated sources on 2026-10-11. videa.ai: "Proven results" block shows +10% same-store growth, +20% case acceptance, 119% increase in caries detection, 90K clinicians; no footnotes, no methodology, no FDA mention; the +8% gross production per patient and +20% periodontal treatment-plan value are from the Independence Dental customer case study (single customer), so the claim's framing of +8% as a general Videa statistic is imprecise. hellopearl.com/products/second-opinion: says "94% accuracy" and "validated by an independent third party to be 94% accurate in detecting dental disease" (third party unnamed), while the FAQ says "over 95% accuracy" (internal inconsistency confirmed); also claims 30% average case-acceptance lift, per-procedure lifts (+37% SRP, +34% crowns, +23% RCT, +19% fillings, +18% implants), 35%/44%/2x diagnosis stats with footnotes 1-3 whose text is not on the page, FDA clearance for intraoral and panoramic radiographs, 7M+ verified cases; India not mentioned. The claim's blanket "unaudited" label is therefore wrong for Pearl, which asserts (unverifiable) third-party validation. nexhealth.com/resources: Perfect Smile Dental Care case study headline "35+ Monthly Google Bookings" but body says only "more than 35 new bookings from Google" with no period; "a 40% increase in positive patient reviews" with no baseline; Bastida Dental Group saves ~$2k/month in booking fees; Daily Smiles Dental reports reduced no-shows with no figure; Dr. Stitt "45 surgeries booked in two days" (2026-09-10). No aggregate or independent online-booking conversion or no-show-reduction statistic on any page, confirming the last sentence of the claim. Limitations: the WebSearch budget for this run was exhausted (200-call shared cap), so the required 2 fresh extended searches could not be performed; no independent third-party audit of any figure was located, and India-specific availability/pricing remains unverified.

</details>

## Open questions

- CDSCO's 13 Sep 2021 'Classification of Medical Device pertaining to Software' and the Medical Device Software guidance PDFs would not parse; the exact class assigned to dental image-analysis/CDS software (and whether a Class A SaMD can use the non-sterile, non-measuring licence exemption) must be read from the originals before any AI-imaging claim is made in India.
- Has the Dental Council of India issued any teledentistry or digital-consent guidance since 2020? The MoHFW telemedicine guidelines cover only IMC-registered RMPs, leaving dentists without an explicit framework.
- What are the current India INR rate-card figures for marketing, utility and authentication templates (they live in Meta's downloadable rate cards, not on the pricing page), and what did the Jan 1 2026 marketing increase move the rate to?
- Do Pearl, Overjet, Diagnocat or VideaHealth hold CDSCO import licences or an Indian authorised agent, and do they offer white-label/API access to overlays for a third-party PMS in India?
- The web-search budget was exhausted this turn, so no vendor pricing for Pearl, Overjet, Videa, Diagnocat, Bola, NexHealth or Arini was obtained (all are quote-only); a follow-up with search enabled should pull G2/Capterra and reseller price points.
- openFDA and the FDA AI-enabled device list disagree on several K-numbers for the same Overjet/Videa/Pearl devices (e.g., Overjet Caries Assist K212519 vs K211966); confirm the canonical K-numbers in the 510(k) database before citing them in marketing or regulatory documents.
- Dental-specific share of India's 507k medical-tourism arrivals, and the main source countries for dental tourists (Gulf NRIs, Africa, UK, Australia), are not published; worth validating with a few Goa/Kerala/Bangalore clinics before investing in the tourism pack.
- Under IRDAI rules, how must an in-house dental membership plan be worded to avoid being treated as insurance, and can it be sold with UPI autopay mandates?
- ABDM/ABHA integration (M1-M3 milestones, FHIR profiles, Digital Health Incentive Scheme payments) could not be read because the NHA sites are JavaScript-only; confirm whether dental clinics are eligible for DHIS incentives and whether ABHA-linked record export satisfies the 'records export' need for tourists.
- Does any Indian patient-facing app (Practo, Clove Dental, Sabka Dentist) already offer family accounts with guardian consent for minors in a DPDP-compliant way, or is this an open niche?
