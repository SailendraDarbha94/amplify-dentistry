# Findings: Payments, financing and tax plumbing for an Indian dental SaaS (RBI PA regime, UPI MDR, EMI partners, IRDAI membership plans, GST on dentistry and on the SaaS itself)

Raw research output from the multi-agent sweep (October 2026). Each finding carries a verification tag:

- `gap-fill-unverified` (14): from the gap-fill round; not fact-checked

## Summary

PAYMENT ARCHITECTURE DECISION. Do not become a Payment Aggregator. RBI's Master Direction on Regulation of Payment Aggregators (RBI/DPSS/2025-26/141, 15 Sep 2025) requires a non-bank PA to be an Indian company with Rs 15 crore net worth at application and Rs 25 crore by the end of the third financial year, escrow with a scheduled commercial bank, board-approved merchant onboarding and CDD. Critically for a vertical SaaS, para 13(g) requires that merchant funds be credited "in the merchant's bank account only" and a Payment Gateway is defined as technology "without any involvement in handling of funds"; so the moment the SaaS receives or holds patient money for many clinics, even for a day, it is doing PA business without authorisation. The compliant design is: the SaaS is a technology/PG-style platform, each clinic is onboarded as a sub-merchant (Razorpay Route "Linked Account", Cashfree Easy Split "vendor", PayU Split Settlements "child merchant") under the licensed PA's KYC, the PA settles directly to the clinic's bank/VPA, and the platform takes its commission as a programmatic split. Razorpay has explicitly rebuilt Route around the Sept 2025 MD: Route now requires the platform to show domestic turnover above Rs 40 lakh (GST-3B) or export turnover above Rs 5 lakh (self-declaration if unregistered), and "payer-payee transparency" — the linked account must be the party that directly serves the customer; non-compliant Route users were cut off from 1 Jan 2026. A clinic-pays-dentist flow satisfies that test cleanly. Cost per transaction (ex-18% GST on fees): Razorpay standard plan 2% platform fee on UPI/cards/netbanking (UPI QR 0.99%), Route transfer fee 0.1% on the split amount, Subscriptions 0.9%, Bajaj Finserv EMI 6% (3m) to 13.5% (12m); Cashfree 1.95% on UPI/cards, 2.2% credit-card EMI, 1.5% debit-card EMI, +1.9% cardless EMI, Easy Split 0.2% per split, instant settlement 0.3%, UPI AutoPay Rs 7.5 mandate + Rs 5/Rs 15 per debit. Negotiated UPI rates well below the rack 1.95-2% are normal for volume, so "payments margin" is realistically a 0.2-0.5% platform split layered on a negotiated PA rate, not a 2% take. From 15 Oct 2026 (if not deferred) UPI P2M above Rs 2,000 carries 0.4% MDR capped at Rs 300, GST-exclusive, and that cost will be passed to clinics by every PA; AutoPay/mandate debits, P2P and merchants receiving under Rs 1 lakh/month via UPI are exempt.

TAX LOGIC. The GST position is now resolvable with primary sources, though one line item still needs a CA opinion. Health care services by a clinical establishment remain exempt (Notification 12/2017-CT(R) entry 74); para 2(zg) excludes "hair transplant or cosmetic or plastic surgery" except reconstruction after congenital defects, developmental abnormalities, injury or trauma. The 56th GST Council (3 Sep 2025, effective 22 Sep 2025 via Notification 15/2025-CT(R)) moved "Beauty and physical well-being services falling under group 99972" from 18% with ITC to 5% without ITC (press release Annexure III item 14; FAQ Q72). Group 99972 in the Scheme of Classification of Services includes 999722 "cosmetic treatment (including cosmetic/plastic surgery)". So the three versions circulating in the plan are reconciled: pure aesthetic dentistry (whitening, veneers for aesthetics, smile design, dental jewellery) is NOT exempt; it is either 5% without ITC if classified under 99972 as a beauty/cosmetic treatment, or 18% with ITC if classified under 9993 human health/dental services that fail the exemption. No CBIC circular or AAR specific to cosmetic dentistry after 22 Sep 2025 was found. Goods: FAQ Q24 states 5% "applies on all medical devices, instruments, apparatus used in medical, surgical, dental and veterinary uses"; 9018/9019/9020/9022 went 12% to 5% and 9025/9027 18% to 5%; HSN 9021 (artificial teeth, dental fittings, implants as appliances implanted in the body) does not appear in any change list, consistent with its pre-existing 5% entry. When a crown/implant/aligner is supplied as part of treatment it is a composite supply whose principal supply is exempt health care, so no GST; only stand-alone retail of the device (e.g. selling a retainer or whitening kit over the counter) is 5%. Rule 46A lets a registered clinic issue one invoice-cum-bill of supply to an unregistered patient for mixed exempt + taxable lines; e-invoicing (IRN) applies only to B2B/export lines of taxpayers above Rs 5 crore, so almost no patient bill needs an IRN. The SaaS subscription sold to dentists is 18% (SAC 9983/9973 class); for an unregistered dentist the place of supply is the address on record (IGST Act s.12(2)(b)), so IGST interstate and CGST+SGST intrastate.

WHAT CHANGED SINCE THE PLAN WAS WRITTEN. (1) UPI MDR is real law now: the Taxation and Other Laws (Amendment) Act 2026 amended s.10A of the PSS Act in August, the Finance Ministry gazette of 14 Sep 2026 fixed the Rs 2,000 free threshold, and NPCI's framework (0.4%, Rs 300 cap at Rs 75,000+, flat Rs 5 for fuel/insurance/railways/telecom/utilities, 0.02% capital markets) starts 15 Oct 2026; a Supreme Court PIL is pending (notices issued 29 Sep 2026) and on 8 Oct 2026 industry bodies asked NPCI to defer to January 2027, with a decision expected within days. (2) UPI Collect was deprecated on 28 Feb 2026, so the Flutter app must use UPI Intent on Android, QR on desktop web, and iOS keeps collect; mandates can no longer be registered by typing a VPA. (3) RBI replaced the old e-mandate circulars with the Digital Payments - E-mandate Framework, 2026 (21 Apr 2026): Rs 15,000 per debit AFA-free, Rs 1 lakh only for insurance/MF/credit-card bills, 24-hour pre-debit notice, no customer charges; a monthly clinic membership well under Rs 15,000 is fully workable on UPI AutoPay, and AutoPay debits are MDR-exempt. (4) The 57th Council (8 Oct 2026) added no dental or cosmetic clarification; it did extend e-invoicing to RCM inward supplies for Rs 5 crore+ taxpayers, created a B2C-only Annual Return Quarterly Payment scheme for turnover up to Rs 5 crore (useful for most clinics), and amended s.9(5) on ECO liability (health care is not a notified 9(5) service, so the SaaS has no deemed-supplier liability). EMI partner economics (Bajaj, SaveIN) could not be retrieved from the vendors' own sites in this run and remain stale; Fibe's healthcare EMI is up to Rs 10 lakh, 6-36 months, paid directly to the clinic.

## Findings

### 1. `gap-fill-unverified` · confidence high

RBI's Master Direction on Regulation of Payment Aggregators (RBI/DPSS/2025-26/141, 15 Sep 2025, effective immediately) defines a PA as an entity that aggregates customer payments to merchants and settles them, requires non-bank PAs to be Indian companies with Rs 15 crore net worth at application and Rs 25 crore by end of FY3, mandates escrow with a scheduled commercial bank (by 31 Dec 2025), and in para 13(g) requires that merchant funds be credited 'in the merchant's bank account only'. A Payment Gateway, defined as technology 'without any involvement in handling of funds', is outside the MD. Merchants onboarded from 1 Jan 2026 must meet the MD's CDD; a simplified process (PAN verification + physical Contact Point Verification) applies to merchants with annual turnover up to Rs 40 lakh, and CKYCR records may be pulled with consent. A PA 'shall not' run a marketplace business, and where one PA onboards merchants for another, the onboarding PA owns due diligence.

**Why it matters:** The SaaS must never receive, pool or hold patient money, even intraday: that is unauthorised PA business and the net-worth bar makes an own licence impossible at seed stage. Architect as a technology layer on a licensed PA with per-clinic sub-merchant KYC (PAN + bank account; CPV for sub-Rs 40 lakh clinics is the PA's job). Dentists are almost all sole proprietors under Rs 40 lakh, so the simplified CDD path is the normal onboarding flow.

Sources:
- https://rbi.org.in/Scripts/BS_ViewMasDirections.aspx?id=12896
- https://rbidocs.rbi.org.in/rdocs/notification/PDFs/141MD7D7F25DEBF1F48449E20D685E4B014E5.PDF
- https://www.rbi.org.in/Scripts/NotificationUser.aspx?Id=11822
- https://www.rbi.org.in/Scripts/BS_ViewMasterDirections.aspx?did=344

### 2. `gap-fill-unverified` · confidence high

Razorpay Route (the split-settlement product) was re-gated after the Sept 2025 MD: platforms must prove domestic turnover above Rs 40 lakh via GST-3B or export turnover above Rs 5 lakh via FIRC for FY25/FY26 (self-declaration if unregistered), and submit a written 'payer-payee transparency' use-case confirming the Linked Account 'directly interfaces with those customers'; non-compliant accounts were discontinued from 1 Jan 2026 and review takes 5-7 business days. Linked Accounts need name, phone, email, PAN/business details and a penny-tested bank account or an instantly verified VPA (VPA settlements capped at Rs 1 lakh per transfer, the NPCI limit); they are created immediately but have a 24-hour cooling period, and settlements to Linked Accounts take 2 working days. Fees: a Payment Gateway fee on the full payment plus a Transfer fee (0.1% list price) on the split amount, both plus GST; refunds can reverse transfers automatically.

**Why it matters:** A dental SaaS where the patient pays the clinic passes the payer-payee test, but the company itself must clear Rs 40 lakh turnover (or self-declare) before Route is enabled, which forces an early-stage sequencing decision: either launch with clinics on their own PA accounts and only link-generation, or use Cashfree/PayU, whose split products do not publish such a gate. VPA settlement is attractive for clinics but limits a single transfer to Rs 1 lakh.

Sources:
- https://razorpay.com/docs/payments/route/
- https://razorpay.com/docs/payments/route/faqs
- https://razorpay.com/docs/payments/route/linked-account
- https://razorpay.com/docs/payments/route/transfer-funds-to-linked-accounts
- https://razorpay.com/pricing/

### 3. `gap-fill-unverified` · confidence high

Cashfree Easy Split charges 0.2% per split on top of PG rates (pricing page shows 0.20-0.25%), allows a transaction to be split among up to 5 vendors, supports deferred settlement of up to 45 days, settles vendors on a T+1/T+2 cycle (instant settlement via schedule_option 8/9), adjusts refunds against the next settlement with vendors bearing refunds proportionally by default, and withholds disputed amounts from the merchant (platform) balance, not the vendor. Vendor KYC via the Create Vendor API takes account_type (BUSINESS/INDIVIDUAL), business_type, mandatory PAN, optional GST/CIN/Aadhaar/passport, and bank or UPI payout details; production vendors normally activate within 24 hours. PayU Split Settlements onboards a child merchant with business_entity_id (2 = Sole Proprietorship, 14 = Individual), mandatory PAN and business category, optional GSTIN, bank proof (cancelled cheque/passbook) and an e-signed Schedule C, activating in about two working days.

**Why it matters:** These are the concrete KYC fields the clinic-onboarding screen must collect: PAN of the dentist (personal PAN for proprietors), bank account or VPA, optional GSTIN, business category (use MCC 8021 Dentists/Orthodontists), signatory details. The 45-day hold and refund-adjustment mechanics should drive the product's refund/chargeback policy (platform bears disputes). The 0.1-0.25% split fee is the true cost of the 'platform margin' mechanism.

Sources:
- https://www.cashfree.com/docs/help/easy-split/faqs/faqs.md
- https://www.cashfree.com/docs/api-reference/payments/latest/easy-split/create-vendor
- https://www.cashfree.com/payment-gateway-charges/
- https://www.cashfree.com/docs/help/payments/settlements/settlements.md
- https://docs.payu.in/docs/split-settlements
- https://docs.payu.in/reference/create-child-merchant-api.md
- https://docs.payu.in/docs/add-a-sub-account

### 4. `gap-fill-unverified` · confidence high

List prices (ex 18% GST on fees): Razorpay standard plan 2% on UPI, debit/credit cards, netbanking, wallets, Pay Later and card/cardless EMI (corporate cards 2.15%; UPI QR 0.99%; international up to 3%), Route 0.1% + platform fees, Subscriptions 0.9% + platform fees, Payment Links at no extra cost, Bajaj Finance EMI platform charges 6% (3m), 7% (4m), 8% (6m), 11% (9m), 13.5% (12m) plus gateway fee. Cashfree: 1.95% on UPI (Intent/Collect/credit line/PPI), domestic cards and prepaid, RuPay credit on UPI 2.15%, credit-card EMI 2.2% (1.90% + 0.25%), HDFC debit-card EMI 1.5%, cardless EMI +1.9%, Pay Later 2.2-2.5%, international 2.95-2.99%, virtual account IMPS/NEFT Rs 20, instant settlement 0.3%, Easy Split 0.2%, UPI AutoPay Rs 7.5 mandate + Rs 5 (debit under Rs 1,000) or Rs 15 (Rs 1,000+), cards/eNACH Rs 7.5 + Rs 7.5; payouts Rs 3-15 per transfer. Razorpay states its 2% on UPI is a 'platform/technology fee, not MDR'.

**Why it matters:** Use these as the ceiling in the unit-economics model: on a Rs 8,000 RCT paid by UPI the PA fee at rack rate is Rs 156-160 + GST, so a 0.2-0.3% platform split (Rs 16-24) is the realistic 'payments margin', not a share of 2%. Negotiate a sub-1% UPI rate at volume before promising clinics anything. The Bajaj EMI subvention of 6-13.5% is a clinic-borne cost that only makes sense for tickets above roughly Rs 25,000 (implants, ortho).

Sources:
- https://razorpay.com/pricing/
- https://www.cashfree.com/payment-gateway-charges/
- https://www.cashfree.com/docs/help/account/pricing.md
- https://razorpay.com/docs/payments/payment-methods/emi/

### 5. `gap-fill-unverified` · confidence high

UPI MDR status as of 11 Oct 2026: Parliament amended s.10A of the Payment and Settlement Systems Act via the Taxation and Other Laws (Amendment) Act 2026 (Aug 2026); the Finance Ministry's gazette notification of 14 Sep 2026 protects only UPI and RuPay-debit transactions up to Rs 2,000 from charges; NPCI's framework (reported from its FAQ) sets 0.4% MDR on P2M transactions above Rs 2,000, capped at Rs 300 (reached at Rs 75,000), flat Rs 5 for fuel, insurance, railways, telecom, electricity/water/PNG and loan repayments, 0.02% capped at Rs 300 for capital markets, flat/capped processing for education, effective 15 Oct 2026, rates 'exclusive of GST' (18% on top). Exempt: consumers, P2P and self-transfers, UPI AutoPay/mandates, credit-linked UPI (separate rules), and small merchants receiving up to Rs 1 lakh per month via UPI QR (three consecutive months above Rs 1 lakh moves a merchant into P2M scope). A Supreme Court PIL was filed 17 Sep 2026 and on 29 Sep the Court asked the Centre, RBI and NPCI to explain whether MDR is 'tax or a fee'; on 8 Oct 2026 merchant bodies and fintechs asked NPCI to defer rollout to January 2027, with NPCI consulting the Finance Ministry. Healthcare/hospitals are not named in any exemption or concessional list found. PhonePe, Paytm and MobiKwik publicly support the charge; NPCI estimates Rs 13,000-15,000 crore in year one.

**Why it matters:** Dental tickets cluster between Rs 2,000 and Rs 50,000, exactly the taxed band: Rs 8 on a Rs 2,001 bill, Rs 40 on Rs 10,000, Rs 200 on Rs 50,000, plus 18% GST. Any clinic collecting over Rs 1 lakh/month by UPI is in scope. Build the fee engine to (a) tag each UPI payment with MDR-applicable yes/no and amount, (b) pass MDR through to the clinic as a separate invoice line with GST, (c) treat AutoPay membership debits as MDR-free, and (d) keep a feature flag for the 15 Oct date because deferral to Jan 2027 or a court stay is plausible this week.

Sources:
- https://www.medianama.com/2026/09/223-upi-mdr-rs-2000-threshold/
- https://www.medianama.com/2026/09/223-upi-mdr-above-rs-2000-october-15/
- https://www.medianama.com/2026/09/223-govt-role-upi-mdr-gst/
- https://www.medianama.com/2026/09/223-payment-ceos-on-upi-mdr-phonepe-paytm-mobikwik/
- https://www.medianama.com/2026/09/223-npci-ai-cyber-threats-mythos-upi-mdr/
- https://www.medianama.com/2026/10/223-npci-upi-mdr-rollout-delay/
- https://www.medianama.com/2026/09/223-supreme-court-upi-mdr-rbi-npci/
- https://www.medianama.com/2026/09/223-pil-supreme-court-charges-upi-payments/

### 6. `gap-fill-unverified` · confidence high

UPI Collect (customer types VPA/mobile number) was deprecated effective 28 Feb 2026; customers 'can no longer make payments or register UPI mandates by manually entering VPA/UPI id/mobile numbers'. Exemptions: MCC 6012/6211 (IPO/secondary market), iOS mobile app and mobile-web transactions, UPI mandates (execute/modify/revoke only), eRupi vouchers and PA-CB cross-border. Replacement flows: UPI Intent on Android apps, mobile web and WebView (prefilled, app launches), and dynamic UPI QR on desktop web ('UPI Intent is not supported on web'); Save-VPA/Validate-VPA features stop working. NPCI per-transaction limits as reproduced by Razorpay: P2M Rs 1 lakh, BFSI Rs 2 lakh, Healthcare Rs 5 lakh, Education Rs 5 lakh, MCC 6211 Rs 5 lakh; non-verified merchants can collect only up to Rs 2,000; many banks cap daily UPI at Rs 1 lakh. The NPCI deep-link scheme used by intent and QR is upi://pay with pa (payee VPA), pn (name), am (amount), tn (note), tr (transaction ref), mc (MCC), cu=INR, and optional mode/purpose/url/sign fields.

**Why it matters:** Flutter app: implement Intent (Android) and the iOS collect/intent path, and a desktop-web checkout that renders a dynamic QR; do not build VPA-entry UI. Membership-plan mandates must be registered via intent in the patient's UPI app. Get each clinic's VPA acquired under the healthcare MCC (8021) so NPCI's Rs 5 lakh healthcare cap, not the Rs 1 lakh P2M cap, applies to implant/full-mouth bills; bank-side daily caps will still fail large single payments, so offer card/netbanking fallback above Rs 1 lakh.

Sources:
- https://razorpay.com/docs/payments/payment-methods/upi/
- https://razorpay.com/docs/announcements/upi-collect-migration/standard-integration
- https://razorpay.com/docs/payments/payment-methods/transaction-limits/upi

### 7. `gap-fill-unverified` · confidence high

RBI's Digital Payments - E-mandate Framework, 2026 (RBI/DPSS/2026-27/396, 21 Apr 2026, effective immediately, covering cards/PPI/UPI) permits recurring debits without additional factor authentication up to Rs 15,000 per transaction, and up to Rs 1,00,000 only for insurance premiums, mutual fund subscriptions and credit-card bill payments; registration, first debit, modification and withdrawal all require AFA; issuers must send a pre-debit notification at least 24 hours before each charge; customers may not be charged for the e-mandate facility. Cashfree's subscription limits mirror this (UPI AutoPay Rs 15,000 without AFA, Rs 1 lakh with UPI-PIN AFA within 30 minutes; eNACH up to Rs 1 crore with no AFA; frequencies day/week/month/year/ad hoc; AutoPay processing windows from 1 Aug 2025: before 10:00, 13:00-17:00, after 21:30), and Razorpay lists UPI AutoPay mandate creation up to Rs 1 lakh with frictionless debits of Rs 15,000 (Rs 1 lakh BFSI only). UPI AutoPay/mandate debits are exempt from the new UPI MDR.

**Why it matters:** A monthly or annual clinic membership priced under Rs 15,000 can run on UPI AutoPay with one-time PIN authorisation, zero MDR, and about Rs 12.5-22.5 in PA mandate+debit fees per cycle; annual plans above Rs 15,000 need eNACH or a card SI with AFA. Build the 24-hour pre-debit notification and pause/modify/revoke flows into the app (the PSP sends the notice, but the clinic should mirror it on WhatsApp).

Sources:
- https://rbi.org.in/Scripts/BS_ViewMasDirections.aspx?id=13374
- https://www.cashfree.com/docs/payments/subscription/payment-modes
- https://razorpay.com/docs/payments/subscriptions/supported-payment-methods
- https://razorpay.com/docs/payments/recurring-payments/upi/

### 8. `gap-fill-unverified` · confidence medium

The dominant Indian dental chain, Clove Dental, sells prepaid 'Dental Health Plans' (Premium Rs 590-650, Super Speciality Rs 750, 'inclusive of all taxes') valid 6 months, containing a Rs 1,800 treatment coupon, free consultation and intraoral X-ray, Rs 3,500 off ortho/implants, 'guaranteed lifetime renewal', non-refundable and non-transferable, with no insurance disclaimer and no stated IRDAI registration. Under the Insurance Act 1938 only a registered insurer may carry on insurance business (s.3), and 'health insurance business' (s.2(6C)) means contracts providing sickness benefits or medical/surgical/hospital expense benefits; a prepaid plan that gives fixed discounts, included preventive visits and a stored-value coupon transfers no uncertain risk and is structured as a discount/prepaid-services contract, which is how the market operator has positioned it. No IRDAI circular specifically on dental discount plans was retrievable in this run (IRDAI pages are not fetchable), so the boundary between 'discount membership' and 'indemnity for uncertain treatment costs' rests on statutory text and market practice, not a regulator statement.

**Why it matters:** Design the in-house membership engine as (a) prepaid preventive services at a fixed price, (b) percentage discounts on list price, and (c) a stored-value coupon, and avoid any 'unlimited treatment' or 'we pay if you need X' promise, which is risk-bearing and insurance-like. Add the clinic as the seller of record (the SaaS only provides software) and include an explicit 'not an insurance product' disclaimer. Confirm with insurance counsel before scaling.

Sources:
- https://clovedental.in/membership/dental-health-plan-super-speciality
- https://clovedental.in/membership/dental-health-plan-premium
- https://clovedental.in/

### 9. `gap-fill-unverified` · confidence medium

Health care services by a clinical establishment or authorised medical practitioner remain exempt under Notification 12/2017-CT(R) entry 74 (heading 9993); para 2(zg) defines them as diagnosis, treatment or care for illness, injury, deformity, abnormality or pregnancy in a recognised system of medicine and excludes 'hair transplant or cosmetic or plastic surgery, except when undertaken to restore or to reconstruct anatomy or functions of body affected due to congenital defects, developmental abnormalities, injury or trauma'. The 56th GST Council (3 Sep 2025) moved 'Beauty and physical well-being services falling under group 99972' from 18% with ITC to 5% without ITC with effect from 22 Sep 2025 (Annexure III item 14 / Annexure IV item 7; FAQ Q72: 'health clubs, salons, barbers, fitness centers, yoga, etc. ... 5% without ITC'), implemented by Notification 15/2025-CT(R). Group 99972 of the Scheme of Classification of Services includes 999722 'cosmetic treatment (including cosmetic/plastic surgery), manicuring and pedicuring services'. Neither the 56th nor the 57th Council (8 Oct 2026) issued any clarification on cosmetic dentistry, and no post-Sept-2025 AAR on a dental or aesthetic clinic was found.

**Why it matters:** GST rate table for the billing engine (confidence in brackets): restorative, endodontic, periodontal, surgical, paediatric, prosthodontic treatment and orthodontic/aligner therapy for malocclusion = EXEMPT (high); dental implants, crowns, bridges, dentures and aligners supplied as part of treatment = exempt as composite supply with health care as principal supply (medium-high); veneers/crowns done to repair fractured or developmentally defective teeth = exempt under the 2(zg) reconstruction carve-out (medium); purely aesthetic whitening, bleaching, smile design, cosmetic veneers, gum contouring, dental jewellery = TAXABLE, either 5% without ITC as a 99972 cosmetic treatment or 18% with ITC as a 9993 dental service outside the exemption (medium on 'taxable', low on which rate); over-the-counter sale of whitening kits, retainers, floss = goods at 5% (HSN 9021/3306) or applicable goods rate (high). Model every line with a tax-code field (EXEMPT / COSMETIC_5_NO_ITC / COSMETIC_18 / GOODS_5 / GOODS_18) chosen per clinic by its CA, default COSMETIC_18 because it preserves ITC and is the conservative position, and keep the SAC on the invoice.

Sources:
- https://gstcouncil.gov.in/sites/default/files/2025-09/press_release_press_information_bureau.pdf
- https://gstcouncil.gov.in/sites/default/files/2025-09/faq.pdf
- https://gstcouncil.gov.in/sites/default/files/2026-10/press_release.pdf

### 10. `gap-fill-unverified` · confidence high

Goods side of the 56th Council (effective 22 Sep 2025, Notification 9/2025-CT(R)): HSN 9018 (instruments used in medical, surgical, dental or veterinary sciences), 9019, 9020 and 9022 (X-ray apparatus for medical, surgical, dental use) moved from 12% to 5%; 9025 thermometers and 9027 analytical instruments from 18% to 5%; 3005 wadding/gauze, 3006 sterile dental sutures/haemostatics, 3822 diagnostic kits, 4015 examination gloves 12% to 5%; 3306 dental floss/toothpaste and 96032100 tooth brushes incl. dental-plate brushes 18% to 5%; 'all other drugs and medicines' 12% to 5%. FAQ Q24: 'The rate of 5% applies on all medical devices, instruments, apparatus used in medical, surgical, dental and veterinary uses other than that are exempted specifically.' HSN 9021 (orthopaedic appliances, artificial parts of the body, 'other appliances which are worn or carried, or implanted in the body', including artificial teeth and dental fittings) is absent from every change list, consistent with its pre-existing 5% Schedule I entry. Individual health insurance policies became exempt.

**Why it matters:** Clinic purchase-side: consumables, handpieces, RVG/OPG units and chairs are now 5%, which matters because an exempt-output clinic cannot claim ITC, so 5% is their real cost. For the lab/supplies marketplace roadmap, implants, crowns, aligner trays and dentures sold B2B to clinics are 5% under 9021 and the SaaS must raise a 5% tax invoice with HSN on each line; the clinic then re-supplies them to patients inside an exempt treatment. The 'individual health insurance exempt' change removes GST friction from any future insurer tie-up.

Sources:
- https://gstcouncil.gov.in/sites/default/files/2025-09/press_release_press_information_bureau.pdf
- https://gstcouncil.gov.in/sites/default/files/2025-09/faq.pdf
- https://cleartax.in/s/gst-rates

### 11. `gap-fill-unverified` · confidence high

Invoicing and compliance mechanics: CGST Rule 46A allows a registered person supplying taxable and exempt goods/services to an unregistered person to issue a single 'invoice-cum-bill of supply'; e-invoicing (IRN) is mandatory only for B2B/export/B2G documents of taxpayers with turnover above Rs 5 crore (from 1 Aug 2023), B2C bills are excluded, and taxpayers above Rs 10 crore must report IRNs within 30 days (from 1 Apr 2025); the 57th Council (8 Oct 2026) recommended extending e-invoicing to RCM inward supplies from unregistered persons and import of services for Rs 5 crore+ taxpayers, an optional Annual Return Quarterly Payment scheme for taxpayers up to Rs 5 crore making only B2C supplies, a Rs 10,000 minimum for show-cause notices, late-fee waiver for sub-Rs 5 crore filers, and an amendment to s.9(5) on ECO liability. A fully exempt clinic need not register at all; a clinic with taxable cosmetic/goods turnover must register once aggregate turnover (including exempt supplies) crosses Rs 20 lakh (Rs 10 lakh in special-category states such as Arunachal Pradesh).

**Why it matters:** Billing engine requirements: one patient document that carries exempt and taxable lines with SAC/HSN per line and the words 'Invoice-cum-Bill of Supply' when the clinic is GST-registered, a plain receipt/bill of supply when it is not; IRN generation only for B2B lines (corporate dental camps, insurer/TPA, lab-to-clinic sales on the marketplace) of clinics above Rs 5 crore, which is rare; GSTR-1/3B export with exempt turnover reported, since exempt supplies count toward the registration threshold; and state-aware threshold logic (Rs 10 lakh for NE states) for the founder's own Arunachal clinic.

Sources:
- https://cleartax.in/s/e-invoicing-gst
- https://gstcouncil.gov.in/sites/default/files/2026-10/press_release.pdf
- https://gstcouncil.gov.in/sites/default/files/2025-09/faq.pdf

### 12. `gap-fill-unverified` · confidence medium

The SaaS subscription to a dentist is a taxable supply of services at 18% (SaaS/online software under heading 9973/9983, no concessional entry); when the dentist is unregistered the place of supply is the location of the recipient where an address on record exists, otherwise the supplier's location (IGST Act s.12(2)(b)), so IGST applies to clinics in other states and CGST+SGST to clinics in the company's home state; the company must register from its first interstate B2C supply unless it stays under the Rs 20 lakh threshold for interstate services. Separately, a platform that 'facilitates' clinics' services and collects consideration through a split-settlement product can be an 'electronic commerce operator': under Income-tax s.194-O it must deduct 0.1% TDS on the gross amount of services facilitated (no deduction for individual/HUF participants with PAN up to Rs 5 lakh a year; 5% if no PAN), and under CGST s.52 an ECO 'collecting consideration' must collect TCS (0.5% combined since 10 Jul 2024) on net taxable supplies, but not on exempt supplies.

**Why it matters:** Collect the clinic's state and PIN at signup as the 'address on record' and bill IGST or CGST+SGST accordingly; register under GST before the first out-of-state paid subscription. The 194-O/s.52 exposure is the sleeper issue: if the PA's split product means the SaaS 'facilitates' and 'collects' patient payments, the company may have to deduct TDS from every clinic's settlement and file TCS returns on cosmetic (taxable) lines, which changes settlement reconciliation and clinic cash flow. Structure so the PA, not the SaaS, is the collecting entity, and get a CA opinion before go-live.

Sources:
- https://cleartax.in/s/section-194o
- https://razorpay.com/docs/payments/route/faqs
- https://gstcouncil.gov.in/sites/default/files/2026-10/press_release.pdf

### 13. `gap-fill-unverified` · confidence medium

Patient financing partner terms are only partially verifiable from vendors' own pages: Fibe offers healthcare financing up to Rs 10 lakh, tenures 6 to 36 months, 'no-cost or low-cost' EMIs depending on the partner's policy, and 'directly credits the amount to the healthcare or wellness partner', with no published clinic onboarding, fee or API-partner terms; Razorpay lists Bajaj Finance EMI at platform charges of 6% (3 months) to 13.5% (12 months) plus GST and gateway fee, and offers credit-card EMI, debit-card EMI, No-Cost and Low-Cost EMI, and cardless EMI (approval required), with the merchant receiving the full amount per settlement cycle and no instant refunds on EMI; Cashfree lists credit-card EMI at 2.2%, debit-card EMI 1.5% and cardless EMI at +1.9%. Bajaj Finserv's own merchant/EMI-Network pages and SaveIN's site could not be retrieved (HTTP 403 / DNS failure), so Bajaj Health EMI Card subvention, SaveIN clinic fees, minimum tickets and any referral-share schemes remain unverified in this run.

**Why it matters:** The financing feature should ship as an integration to the PA's affordability stack (card EMI, cardless EMI, Bajaj via Razorpay) where the clinic chooses whether to subvent, with the 6-13.5% subvention surfaced in the quote so dentists price implants/ortho accordingly; a direct SaveIN/Bajaj/Fibe referral API and revenue share is a business-development conversation, not something to model as revenue until term sheets are obtained.

Sources:
- https://fibe.in/fibe-emis/healthcare/
- https://razorpay.com/pricing/
- https://razorpay.com/docs/payments/payment-methods/emi/
- https://www.cashfree.com/payment-gateway-charges/

### 14. `gap-fill-unverified` · confidence high

The original RBI PA/PG guidelines (DPSS circular of 17 Mar 2020, updated Nov 2020) already excluded cash-on-delivery, required e-commerce marketplaces to separate and license any PA activity by 30 Jun 2021, set escrow remittance on Tp+0/Tp+1 and merchant settlement at Ts+1/Td+1/Tr+1, prohibited merchants from storing card data, and set Rs 15 crore/Rs 25 crore net worth; the 2025 MD supersedes these, removes fixed settlement timelines in favour of 'fair, equitable' contractually disclosed timelines, adds PA-Physical (POS) and PA-Cross-Border categories (existing PA-P-only entities had to apply by 31 Dec 2025 or wind up by 28 Feb 2026), allows PAs to use agents only for Digital KYC and assisted V-CIP, and bars PAs from running a marketplace.

**Why it matters:** If the roadmap includes in-clinic POS/soundbox collection, that is PA-Physical territory and must also run through a licensed PA-P (Razorpay/Cashfree/PayU POS or a bank). The MD's ban on PAs running marketplaces also means the SaaS cannot later combine a lab/supplies marketplace with its own PA licence in one entity, reinforcing the sub-merchant architecture.

Sources:
- https://www.rbi.org.in/Scripts/NotificationUser.aspx?Id=11822
- https://rbi.org.in/Scripts/BS_ViewMasDirections.aspx?id=12896

## Open questions

- CA/GST opinion: is aesthetic-only dentistry (whitening, cosmetic veneers, smile design, dental jewellery) classifiable under SAC 999722 (5% without ITC, Notification 15/2025-CT(R)) or SAC 999312 dental services outside the entry-74 exemption (18% with ITC)? Request a written opinion or an Advance Ruling; nothing in the 56th/57th Council material or any found AAR addresses dental clinics after 22 Sep 2025.
- CA opinion: composite-supply treatment of implants, crowns, aligners and dentures (HSN 9021, 5%) supplied inside exempt treatment, including whether itemising the device on the patient invoice at a separate price breaks the composite supply and triggers 5% on the goods line.
- CA opinion: whether aligner therapy/orthodontics for mild crowding and veneers for enamel defects fall within the 2(zg) 'restore or reconstruct ... developmental abnormalities' carve-out, and how to document medical necessity on the record to support exemption.
- Legal (insurance) opinion: confirm that a clinic-sold prepaid dental membership (fixed preventive visits, percentage discounts, stored-value coupon, non-refundable, sold by the clinic with the SaaS as software provider) is not 'health insurance business' under s.2(6C)/s.3 of the Insurance Act 1938, and obtain any IRDAI guidance on discount cards/OPD packages (IRDAI pages were not retrievable in this run).
- CA opinion: whether the SaaS, using Razorpay Route/Cashfree Easy Split, is an 'e-commerce operator' for Income-tax s.194-O (0.1% TDS on clinic settlements) and CGST s.52 (0.5% TCS on clinics' taxable lines), and whether the PA being the collecting entity avoids it; also GST on the membership plan itself (prepaid voucher vs service) and on platform commission invoiced to exempt clinics (18%, non-creditable for them).
- Payments: verify directly with NPCI (circular/FAQ not fetchable here) whether MCC 8021/healthcare has any MDR concession or exclusion, the exact issuer/acquirer/NPCI revenue split, and whether the 15 Oct 2026 start is deferred to Jan 2027 or stayed by the Supreme Court; obtain Razorpay/Cashfree written statements on how MDR + 18% GST will be invoiced to sub-merchants (Linked Accounts/vendors) versus the platform.
- Payments: confirm with Razorpay whether a pre-revenue startup can self-declare for Route eligibility (the docs say unregistered businesses may self-declare, but the Rs 40 lakh turnover gate is written as a requirement) and get Cashfree/PayU's written position on sub-merchant onboarding of sole-proprietor dentists without GSTIN (PAN + CPV only) under the 2025 MD.
- Financing: obtain current clinic-side term sheets from Bajaj Finserv (Health EMI Network Card), SaveIN and Fibe for minimum ticket, subvention/MDR by tenor, settlement timeline, onboarding documents and whether a software platform can be an API/referral partner with revenue share; vendor sites returned 403/DNS errors in this run.
- UPI technical: obtain the current NPCI UPI Linking Specification (upi://pay and dynamic QR parameter set, signature requirement for verified merchants) and NPCI's merchant-category transaction-limit circular (healthcare Rs 5 lakh) directly, since NPCI pages render only via JavaScript and could not be fetched; confirm whether the clinic VPA must be acquired under MCC 8021 to get the healthcare limit.
- Web-search budget: the per-turn WebSearch limit was exhausted before this task began, so the memo is built from direct fetches of RBI, GST Council, vendor documentation and MediaNama; a follow-up run with search can pick up any post-8-Oct-2026 MDR deferral notice, a CBIC circular on beauty/wellness vs health services, or dental AAR rulings.
