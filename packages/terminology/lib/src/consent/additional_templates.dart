part of '../consent_templates.dart';

/// Templates added beyond the ported set: implied consent for examination,
/// orthodontics, whitening and clinical photography.
const List<ConsentTemplate> additionalConsentTemplates = [
  ConsentTemplate(
    code: 'GENERAL-EXAM',
    title: 'Examination, Radiographs and Scaling',
    languageCode: _en,
    version: _v1,
    placeholders: toothlessConsentPlaceholders,
    procedureCodes: [
      'CONS-NEW',
      'CONS-PERIODIC',
      'XR-IOPA',
      'XR-BW',
      'XR-OPG',
      'SCALING-ADULT',
      'SCALING-CHILD',
      'SCALING-STAIN',
      'PERIO-SRP',
      'PERIO-MAINT',
    ],
    body:
        'I mr/ms/mrs {name_of_patient} aged {patient_age}, {patient_gender}, consent to a clinical examination of my mouth, teeth and gums by Dr. {doctor_name} and the clinic team. I understand that dental radiographs (X-rays) may be taken where they are needed to diagnose my condition, that the radiation dose from dental radiographs is small and that I should inform the dentist if I am or may be pregnant. I consent to scaling and polishing (professional cleaning) where recommended, and I have been told that mild gum soreness, bleeding and temporary sensitivity to cold are common for a few days afterwards. I have given a complete and truthful medical history, including medicines, allergies and any heart, bleeding, diabetic, thyroid or other conditions, and I will inform the clinic of any change. I understand that this consent covers examination, radiographs and cleaning only and that any other treatment will be explained to me separately with its own estimate before it begins.$consentFooter',
  ),
  ConsentTemplate(
    code: 'ORTHO',
    title: 'Orthodontic Treatment (Fixed Appliances / Aligners)',
    languageCode: _en,
    version: _v1,
    placeholders: toothlessConsentPlaceholders,
    procedureCodes: [
      'ORTHO-METAL',
      'ORTHO-CERAMIC',
      'ORTHO-SELF-LIG',
      'ORTHO-LINGUAL',
      'ALIGNER-ARCH',
      'ALIGNER-CASE',
      'ORTHO-EXPANDER',
    ],
    body:
        'I mr/ms/mrs {name_of_patient} aged {patient_age}, {patient_gender}, have been explained by Dr. {doctor_name} about the irregularity of my teeth and bite and the proposed orthodontic treatment with fixed braces and/or removable clear aligners. I understand that treatment usually takes 12 to 30 months, requires regular adjustment visits every 4 to 8 weeks, and depends on my cooperation in wearing elastics or aligners for the advised hours, keeping appointments and maintaining excellent oral hygiene. I have been told that extraction of some teeth, interproximal reduction (slight slimming of teeth) or additional appliances may be needed, and that the final result and treatment time cannot be guaranteed. Risks explained to me include tooth decay and white spot marks if cleaning is poor, gum inflammation, root shortening, tooth soreness after adjustments, cheek and lip ulcers, loosening of previously treated teeth or crowns, and jaw-joint discomfort. I understand that teeth tend to move back after treatment and that I must wear retainers as advised, possibly indefinitely, to maintain the result. The estimate, payment schedule and the charges for broken or lost appliances have been explained to me. I hereby agree to undergo orthodontic treatment and to follow the instructions and appointment schedule given to me.$consentFooter',
  ),
  ConsentTemplate(
    code: 'WHITENING',
    title: 'Teeth Whitening',
    languageCode: _en,
    version: _v1,
    placeholders: toothlessConsentPlaceholders,
    procedureCodes: [
      'WHITENING-OFFICE',
      'WHITENING-HOME',
      'WHITENING-INTERNAL',
    ],
    body:
        'I mr/ms/mrs {name_of_patient} aged {patient_age}, {patient_gender}, have requested teeth whitening (bleaching) and Dr. {doctor_name} has explained that this is a cosmetic procedure performed at my request and not a medical necessity. I understand that whitening lightens natural tooth structure only and does not change the colour of existing fillings, crowns, veneers or bridges, which may then look darker and may need replacement at additional cost. I have been told that the degree of whitening varies between people, that tetracycline and fluorosis stains respond poorly, and that the result fades over time and may need top-up treatment. Risks explained to me include temporary tooth sensitivity, gum irritation or whitening of the gums where the gel touches them, and uneven colour if the gel is not applied as directed. I confirm that I am not pregnant or breastfeeding, that I am over 18 years of age or accompanied by a guardian, and that I have no untreated decay, cracks or gum disease that the dentist has advised treating first. I understand that GST may apply to this service as a cosmetic procedure. I hereby agree to undergo teeth whitening and to follow the instructions given.$consentFooter',
  ),
  ConsentTemplate(
    code: 'PHOTO-USE',
    title: 'Clinical Photography and Sharing',
    languageCode: _en,
    version: _v1,
    placeholders: toothlessConsentPlaceholders,
    procedureCodes: ['DIAG-PHOTO', 'SMILE-DESIGN-CONS', 'ORTHO-CONS'],
    body:
        'I mr/ms/mrs {name_of_patient} aged {patient_age}, {patient_gender}, consent to clinical photographs, intraoral scans, videos and radiographs of my mouth, teeth and face being taken by Dr. {doctor_name} and the clinic team as part of my dental record. I understand that these images are personal data under the Digital Personal Data Protection Act, 2023 and that they will be used for the purposes of diagnosis, treatment planning, monitoring my treatment and maintaining my record. I agree that the images may be shared, only to the extent necessary, with a dental laboratory fabricating my prosthesis or appliance, and with another registered dentist or specialist for a second opinion or referral; the clinic will share them through secure channels and not through personal messaging where clinical content would be exposed. I understand that the images will not be used for teaching, publication, marketing or social media unless I sign a separate consent, that I may withdraw this consent at any time by informing the clinic in writing, and that withdrawal will not affect images already lawfully used but will stop any further sharing. I may ask to see or receive a copy of my images at any time.$consentFooter',
  ),
];

/// Placeholders used by the DPDP notice.
const List<String> dataNoticePlaceholders = [
  'name_of_patient',
  'clinic_name',
  'doctor_name',
  'registration_number',
  'grievance_contact',
  'date',
];

/// DPDP Act 2023 s.5 notice: what is collected, for which purposes, how to
/// withdraw, and where to complain. Purposes map one-to-one to
/// `DataConsent` rows.
const DataNoticeTemplate dpdpDataProcessingNotice = DataNoticeTemplate(
  code: 'DATA-PROCESSING',
  title: 'Notice on Processing of Your Personal Data',
  languageCode: _en,
  version: _v1,
  placeholders: dataNoticePlaceholders,
  purposes: [
    'treatment',
    'billing',
    'appointmentReminders',
    'recall',
    'labSharing',
    'referral',
    'abdmLinking',
    'marketing',
  ],
  body:
      'Dear {name_of_patient},\n\n'
      '{clinic_name} (Data Fiduciary), through Dr. {doctor_name} (Registration No. {registration_number}), gives you this notice under section 5 of the Digital Personal Data Protection Act, 2023 before processing your personal data.\n\n'
      'What we collect: your name, date of birth, mobile number, address, guardian details if you are under 18, medical and dental history, clinical findings, tooth charts, radiographs, photographs, prescriptions, consent records, invoices and payment records (not card numbers), and your ABHA number if you choose to share it.\n\n'
      'Why we process it (each purpose can be accepted or declined separately, except treatment and billing, which are necessary to provide you care and comply with law):\n'
      '1. Treatment: diagnosis, treatment planning, clinical records and follow-up care.\n'
      '2. Billing: estimates, invoices, receipts, GST compliance and accounts.\n'
      '3. Appointment reminders: confirmations and reminders by WhatsApp or SMS, sent as a notification with a secure link and without clinical content in the message.\n'
      '4. Recall: reminders when a check-up or follow-up is due.\n'
      '5. Laboratory sharing: sharing impressions, scans and photographs with a dental laboratory only as needed to make your crown, denture or appliance.\n'
      '6. Referral: sharing your record with another registered practitioner for a second opinion or specialist care.\n'
      '7. ABDM linking: linking your record to your Ayushman Bharat Health Account if you request it.\n'
      '8. Marketing: information about clinic offers and health camps.\n\n'
      'Your rights: you may access a summary of your personal data, ask for correction or updating, ask for erasure where the law no longer requires us to keep it, nominate a person to exercise your rights if you are unable to, and withdraw any consent you have given. Clinical records are retained for the period required by dental regulations and consumer law even after withdrawal.\n\n'
      'How to withdraw: tell the clinic in person, by WhatsApp or by writing; withdrawal takes effect for future processing and is as easy as giving consent.\n\n'
      'Grievance: contact our grievance officer at {grievance_contact}. If you are not satisfied with our response, you may complain to the Data Protection Board of India.\n\n'
      'Date of notice: {date}',
);
