part of '../consent_templates.dart';

/// Standard footer appended to every procedure consent body.
const String consentFooter =
    '\n\n'
    'Clinic: {clinic_name}\n'
    'Date: {date}\n'
    'Dentist: Dr. {doctor_name}, Registration No. {registration_number}\n'
    'Signature of patient / guardian: ______________________';

/// Placeholders used by templates that name teeth.
const List<String> standardConsentPlaceholders = [
  'name_of_patient',
  'patient_age',
  'patient_gender',
  'doctor_name',
  'tooth_numbers',
  'clinic_name',
  'date',
  'registration_number',
];

/// Placeholders used by templates that do not name teeth.
const List<String> toothlessConsentPlaceholders = [
  'name_of_patient',
  'patient_age',
  'patient_gender',
  'doctor_name',
  'clinic_name',
  'date',
  'registration_number',
];

const String _en = 'en';
const String _v1 = '1.0';

/// The seventeen English templates ported verbatim from the Oasis Dental
/// Clinic consent set, each with the standard footer appended.
const List<ConsentTemplate> portedConsentTemplates = [
  ConsentTemplate(
    code: 'FILLING',
    title: 'Dental Filling',
    languageCode: _en,
    version: _v1,
    placeholders: standardConsentPlaceholders,
    procedureCodes: [
      'COMP-ANT-1',
      'COMP-ANT-2',
      'COMP-ANT-3',
      'COMP-POST-1',
      'COMP-POST-2',
      'COMP-POST-3',
      'COMP-BUILDUP',
      'GIC-1',
      'GIC-2',
      'AMAL-REST',
      'INLAY-CER',
      'VNR-COMP',
      'PED-GIC',
    ],
    body:
        'I mr/ms/mrs {name_of_patient} aged {patient_age}, {patient_gender}, have been explained by the Dr. {doctor_name} about the need for Dental filling in relation to the tooth numbered {tooth_numbers} and I have been explained about the procedure in detail including drilling of the tooth to remove the decay and placement of a Dental filling and if not treated, decay can progress and cause pain and infection. The options for dental filling materials were discussed and finalised with me. I have been explained the slight possibility of exposing the pulp (nerve of the tooth) while removal of the decay and developing pain at a later date when decay removal is close to the pulp (nerve of the tooth) and in such a case the need to undergo root canal treatment has been explained. Post-operative complications like pain and sensitivity for few days have been explained. I hereby agree to undergo the Dental filling and agree to follow-up with the doctor as per his/her advice.$consentFooter',
  ),
  ConsentTemplate(
    code: 'RCT',
    title: 'RCT',
    languageCode: _en,
    version: _v1,
    placeholders: standardConsentPlaceholders,
    procedureCodes: [
      'RCT-ANT',
      'RCT-PRE',
      'RCT-MOL',
      'RCT-SINGLE-VISIT',
      'RERCT',
      'ENDO-EMERGENCY',
      'ENDO-MTA-PLUG',
    ],
    body:
        'I mr/ms/mrs {name_of_patient} aged {patient_age}, {patient_gender}, have been explained by the Dr. {doctor_name} about the need for Root Canal Treatment/ Therapy in relation to the tooth numbered {tooth_numbers} and I have been explained about the procedure in detail including injection of local anaesthesia, drilling of a small hole (access cavity) in the tooth to clear the infection and placement of a crown later. If not treated pain and swelling can increase because of the infection of the tooth and sometimes can be threat to life as well. An alternative option of extraction of the tooth has been explained. Post-operative sequel like pain and swelling for few days have been explained. I hereby agree to undergo the root canal treatment and agree to follow-up with the doctor as per his/her advice.$consentFooter',
  ),
  ConsentTemplate(
    code: 'POST-CORE',
    title: 'Post & Core Build-Up',
    languageCode: _en,
    version: _v1,
    placeholders: standardConsentPlaceholders,
    procedureCodes: ['POST-CORE', 'POST-CORE-CAST'],
    body:
        'I mr/ms/mrs {name_of_patient} aged {patient_age}, {patient_gender}, have been explained by the Dr. {doctor_name} about the need for Post and core build up for the tooth numbered {tooth_numbers} and I have been explained about the procedure in detail including drilling of a small hole in the tooth and placement of a post and build up of the tooth core structure. If not treated, chance of fracture of the tooth at a later stage. An alternative treatment option, extraction of the tooth has been explained. Post-operative sequel like pain and swelling for few days have been explained. I hereby agree to undergo the post and core buildup of the tooth and agree to followup with the doctor as per his/her advice.$consentFooter',
  ),
  ConsentTemplate(
    code: 'CROWN',
    title: 'Crown Placement',
    languageCode: _en,
    version: _v1,
    placeholders: standardConsentPlaceholders,
    procedureCodes: [
      'CRN-PFM',
      'CRN-ZIR',
      'CRN-ZIR-LAYERED',
      'CRN-METAL',
      'CRN-EMAX',
      'CRN-TEMP',
      'ONLAY-CER',
      'VNR-CER',
      'PED-SSC',
      'PED-STRIP-CROWN',
      'IMP-CROWN',
      'SMILE-VNR',
    ],
    body:
        'I mr/ms/mrs {name_of_patient} aged {patient_age}, {patient_gender}, have been explained by the Dr. {doctor_name} about the need for dental crown in relation to the tooth numbered {tooth_numbers} and I have been explained about the procedure in detail including drilling of the tooth to reduce the size of the tooth for processing and placement of a dental crown. Variations in the nature of dental crowns are explained. I have been explained the possibility of exposing the pulp (nerve of the tooth) and the need to undergo root canal treatment if not done earlier. The risk of tooth getting fractured if not covered with dental crown has been explained. Post-operative sequels like pain and sensitivity for few days have been explained. I have been informed about the possibility of loosening of the dental crown/cap, food lodgement and in such a case i have been advised to bring the same soon to get it cemented/fixed to the tooth. I hereby agree to undergo the dental crown and agree to follow-up with the doctor as per his/her advice.$consentFooter',
  ),
  ConsentTemplate(
    code: 'CROWN-REMOVAL',
    title: 'Crown Removal',
    languageCode: _en,
    version: _v1,
    placeholders: standardConsentPlaceholders,
    procedureCodes: ['CRN-REMOVE'],
    body:
        'I mr/ms/mrs {name_of_patient} aged {patient_age}, {patient_gender}, have been explained by the Dr. {doctor_name} about the need for dental crown removal in relation to the tooth numbered {tooth_numbers} and I have been explained about the procedure in detail including application of force via crown remover and if not successful, need for use of dental air motor to cut the crown of the tooth for treatment of the tooth. In such a case replacement of the crown with new one is required and variations in the nature of dental crowns are explained. I have been explained the possibility of fracture of the tooth while crown removal and removal of the tooth if need be. The risk of tooth getting fractured if not covered with dental crown has been explained. Post-operative sequels like pain and sensitivity for few days have been explained. I have been informed about the possibility of loosening of the dental crown/cap, food lodgement and in such a case i have been advised to bring the same soon to get it cemented/fixed to the tooth. I hereby agree to undergo the dental crown and agree to follow-up with the doctor as per his/her advice.$consentFooter',
  ),
  ConsentTemplate(
    code: 'EXTRACTION',
    title: 'Extraction',
    languageCode: _en,
    version: _v1,
    placeholders: standardConsentPlaceholders,
    procedureCodes: ['EXT-SIMPLE', 'EXT-ROOT-PIECE', 'EXT-ORTHO', 'PED-EXT'],
    body:
        'I mr/ms/mrs {name_of_patient} aged {patient_age}, {patient_gender}, have been explained by the Dr. {doctor_name} about the need for the extraction of the tooth/teeth numbered {tooth_numbers} and I have been explained the procedure in detail including injection of local anaesthesia, application of force via extraction forceps for removal of the tooth/teeth. Intra-operative complications like fracture of the tooth, alveolus (tooth supporting bone) have been explained and in such cases, surgical incision, drilling of jaw bone to remove the broken tooth, placement of sutures and post-operative sequel like pain and swelling for few days have been informed. Replacement of the tooth/teeth after the extraction/removal of the tooth/teeth have also been discussed. I hereby agree to undergo the above said minor surgery and agree to follow-up with the doctor as per his/her advice.$consentFooter',
  ),
  ConsentTemplate(
    code: 'SURGICAL-EXTRACTION',
    title: 'Surgical Removal of Tooth',
    languageCode: _en,
    version: _v1,
    placeholders: standardConsentPlaceholders,
    procedureCodes: [
      'EXT-SURGICAL',
      'EXT-3M-IMPACTED',
      'OS-ALVEOLOPLASTY',
      'OS-BIOPSY',
      'OS-INCISION-DRAINAGE',
      'OS-CYST',
      'OS-TORUS',
      'APICO',
      'IMP-REMOVE',
    ],
    body:
        'I mr/ms/mrs {name_of_patient} aged {patient_age}, {patient_gender}, have been explained by the Dr. {doctor_name} about the need for the surgical removal of the tooth numbered {tooth_numbers} and I have been explained the procedure in detail including injection of local anaesthesia, surgical incision, drilling of jaw bone, splitting of tooth when required and placement of sutures. Post-operative sequel like pain and swelling for few days have been explained. I have also been explained in detail the likely hood of inferior alveolar nerve/lingual nerve injury and paresthesia of the lower lip/ half of the tongue, post-operatively. Alternative treatment with medication, as a temporary measure and repeated chances of infection if not treated have been explained. I hereby agree to undergo the above said minor surgery and agree to follow-up with the doctor as per his/her advice.$consentFooter',
  ),
  ConsentTemplate(
    code: 'RPD',
    title: 'RPD',
    languageCode: _en,
    version: _v1,
    placeholders: standardConsentPlaceholders,
    procedureCodes: ['RPD-ACRYLIC', 'RPD-CAST', 'RPD-FLEXIBLE'],
    body:
        'I mr/ms/mrs {name_of_patient} aged {patient_age}, {patient_gender}, have been explained by the Dr. {doctor_name} about the need for the removable partial denture fabrication and processing in relation to the tooth/teeth numbered {tooth_numbers}. I have been explained about the condition of the remaining teeth and the jaw bones that will support removable partial denture. The need for multiple measurement in processing the partial denture and time required in getting trained in using of the removable partial denture after fabrication and looseness of the partial denture have been explained in detail. The nature of the partial denture is removable and I have been advised to remove the partial denture at night. The need for changing the partial denture every 5-6 years has been discussed. I hereby agree to undergo the procedure as suggested by the doctor and follow up the same.$consentFooter',
  ),
  ConsentTemplate(
    code: 'FPD',
    title: 'FPD',
    languageCode: _en,
    version: _v1,
    placeholders: standardConsentPlaceholders,
    procedureCodes: [
      'BRG-PFM-UNIT',
      'BRG-ZIR-UNIT',
      'BRG-METAL-UNIT',
      'BRG-MARYLAND',
    ],
    body:
        'I mr/ms/mrs {name_of_patient} aged {patient_age}, {patient_gender}, have been explained by the Dr. {doctor_name} about the need for dental bridge/ Fixed Partial Denture(FPD) in relation to the teeth numbered {tooth_numbers} and I have been explained about the procedure in detail including drilling of the teeth to reduce the size of the supporting teeth for processing and placement of a dental bridge/ Fixed Partial Denture(FPD). Variations in the nature of dental crowns are explained and alternative option of dental implant for missing tooth has been discussed. I have been explained the possibility of exposing the pulp (nerve of the tooth) and the need to undergo root canal treatment for the supporting tooth/teeth, if not done earlier. Post-operative sequels like pain and sensitivity of teeth for few days have been explained. I have been informed about the possibility of loosening of the dental bridge/fixed partial denture, food lodgement and in such a case, i have been advised to bring the same soon to get it cemented/fixed to the teeth. I hereby agree to undergo the dental bridge/fixed partial denture and agree to follow-up with the doctor as per his/her advice.$consentFooter',
  ),
  ConsentTemplate(
    code: 'CD',
    title: 'CD',
    languageCode: _en,
    version: _v1,
    placeholders: toothlessConsentPlaceholders,
    procedureCodes: ['CD-ACRYLIC', 'CD-FLEXIBLE', 'CD-IMMEDIATE'],
    body:
        'I mr/ms/mrs {name_of_patient} aged {patient_age}, {patient_gender}, have been explained by the Dr. {doctor_name} about the need for the complete denture fabrication and processing. I have been explained about the condition of the alveolar jaw bones that will support removable complete dentures. The need for multiple measurement in processing the complete denture and time required in getting trained in using of the removable complete denture after fabrication and looseness of the complete denture have been explained in detail. Post operative sequels like development of ulcers, pain have been explained and in such case i have been advised to see the doctor. The nature of the complete denture is removable and I have been advised to remove the complete denture at night. The need for changing the complete denture every 5-6 years has been discussed. I hereby agree to undergo the procedure as suggested by the doctor and follow up the same.$consentFooter',
  ),
  ConsentTemplate(
    code: 'IMPLANT',
    title: 'Implant',
    languageCode: _en,
    version: _v1,
    placeholders: standardConsentPlaceholders,
    procedureCodes: [
      'IMP-PLACE',
      'IMP-STAGE2',
      'IMP-BONE-GRAFT',
      'IMP-SINUS-LIFT',
      'IMP-OVERDENTURE',
    ],
    body:
        'I mr/ms/mrs {name_of_patient} aged {patient_age}, {patient_gender}, have been explained by the Dr. {doctor_name} about the need for the minor oral surgery involving the placement of dental implants for the missing tooth numbers {tooth_numbers} and I have been explained the procedure in detail including injection of local anaesthesia, surgical incision, drilling of jaw bone, placement of the dental implant, and closure with sutures at the end of the procedure. post-operative sequel like pain and swelling for few days has been explained. I have been explained about the dental implant and osseointegration (implant fusion to the jaw bone) along with the chances of failures in osseointegration of the dental implant and replacement of the tooth from the implants 3-4 months later. Alternative treatments like dental bridge/ fixed partial denture /removable partial denture/ complete denture have been discussed. I have been explained in detail the likely hood of inferior alveolar nerve injury and paresthesia of the lower lip post-operatively in the case of lower jaw surgery. I have been explained in detail the likely hood of injury to the maxillary sinus and chances of bleeding through the nose, post-operatively in the case of upper jaw surgery. I hereby agree to undergo the above said minor surgery and agree to follow-up with the doctor as per his/her advice.$consentFooter',
  ),
  ConsentTemplate(
    code: 'PERIO-SURGERY',
    title: 'Perio/Gum Surgery',
    languageCode: _en,
    version: _v1,
    placeholders: standardConsentPlaceholders,
    procedureCodes: [
      'PERIO-FLAP',
      'PERIO-CURETTAGE',
      'PERIO-GINGIVECTOMY',
      'PERIO-CROWN-LENGTH',
      'PERIO-SOFT-GRAFT',
      'PERIO-BONE-GRAFT',
      'OS-FRENECTOMY',
      'OS-OPERCULECTOMY',
      'COSM-DEPIGMENTATION',
    ],
    body:
        'I mr/ms/mrs {name_of_patient} aged {patient_age}, {patient_gender}, have been explained by the Dr. {doctor_name} about the need for perio surgery (gum surgery) in relation to the teeth numbered {tooth_numbers} and I have been explained about the procedure in detail including injection of the local anaesthesia, raising of the gum tissue flap, cleaning of the roots of the teeth and bone filling when required, with closure of the flap with sutures at the end of the procedure. Post-operative sequels like pain and sensitivity of the teeth for few days have been explained. If not treated worsening of the gum condition and loosening of the teeth have been informed. I hereby agree to undergo the procedure and agree to follow-up with the doctor as per his/her advice.$consentFooter',
  ),
  ConsentTemplate(
    code: 'PULP-CAP',
    title: 'Pulp Capping',
    languageCode: _en,
    version: _v1,
    placeholders: standardConsentPlaceholders,
    procedureCodes: ['PULP-CAP-INDIRECT', 'PULP-CAP-DIRECT'],
    body:
        'I mr/ms/mrs {name_of_patient} aged {patient_age}, {patient_gender}, have been explained by the Dr. {doctor_name} about the deep decay in the tooth numbered {tooth_numbers} and the need for filling to heal the nerve of the tooth. I have been explained about the procedure in detail including injection of the local anaesthesia, drilling of the tooth to remove the decay and filling of the tooth Post-operative sequels like pain and sensitivity for few days have been explained. If not treated, chances of the tooth infection are also explained. I hereby agree to undergo the procedure and agree to follow-up with the doctor as per his/her advice.$consentFooter',
  ),
  ConsentTemplate(
    code: 'PULPOTOMY-PULPECTOMY',
    title: 'Pulpotomy/Pulpectomy',
    languageCode: _en,
    version: _v1,
    placeholders: standardConsentPlaceholders,
    procedureCodes: ['PED-PULPOTOMY', 'PED-PULPECTOMY'],
    body:
        'I mr/ms/mrs {name_of_patient} aged {patient_age}, {patient_gender}, have been explained by the Dr. {doctor_name} about the deep decay in the tooth numbered {tooth_numbers} and the need for partial removal of the nerve of the tooth (pulpotomy) or complete removal of the nerve of the tooth (pulpectomy). I have been explained about the procedure in detail including injection of the local anaesthesia, drilling of the tooth to remove the decay, partial removal or complete removal of the nerve of the tooth and filling of the tooth. Post-operative sequels like pain and sensitivity for few days have been explained. If not treated, chances of the tooth infection are also explained. I hereby agree to undergo the procedure and agree to follow-up with the doctor as per his/her advice.$consentFooter',
  ),
  ConsentTemplate(
    code: 'MYOFUNCTIONAL',
    title: 'Myofunctional Appliance',
    languageCode: _en,
    version: _v1,
    placeholders: toothlessConsentPlaceholders,
    procedureCodes: ['ORTHO-MYOFUNCTIONAL', 'PED-HABIT-APPLIANCE'],
    body:
        'I mr/ms/mrs {name_of_patient} aged {patient_age}, {patient_gender}, have been explained by the Dr. {doctor_name} about the imbalance in the growth of the jaw bones ( excess or reduced growth of the jaw bones) and their ill effects on the functioning of the jaws and cosmetic appearance of the face and the need for an appliance to control or modify the growth of the jaw bones for better function of the jaw bones and better cosmetic of the face. I have been explained about the procedure in detail including the impression taking, processing of the prosthesis in the lab and fitment of the same later. Post-operative sequels like discomfort, pain and sensitivity for few days have been explained. If not treated, chances of the improper growth of the jaws and face are also explained. I hereby agree to undergo the procedure and agree to follow-up with the doctor as per his/her advice.$consentFooter',
  ),
  ConsentTemplate(
    code: 'CLEFT',
    title: 'Cleft Lip/Palate Surgery',
    languageCode: _en,
    version: _v1,
    placeholders: toothlessConsentPlaceholders,
    procedureCodes: ['OS-CLEFT'],
    body:
        'I mr/ms/mrs {name_of_patient} aged {patient_age}, {patient_gender}, have been explained by the Dr. {doctor_name} about the condition of the cleft lip and or palate and the disability in speech, swallowing, chewing and facial deformity because of the cleft lip and palate. The need for correction of such defect by multiple surgeries. If not treated, chances of regurgitation, frequent ear infections and improper development of speech and the body as a whole. Post-operative sequel like pain and swelling for few days have been explained. I hereby agree to undergo the surgery and agree to follow-up with the doctor as per his/her advice.$consentFooter',
  ),
  ConsentTemplate(
    code: 'JAW-FRACTURE',
    title: 'Fracture of Jaw',
    languageCode: _en,
    version: _v1,
    placeholders: toothlessConsentPlaceholders,
    procedureCodes: ['OS-JAW-FRACTURE'],
    body:
        'I mr/ms/mrs {name_of_patient} aged {patient_age}, {patient_gender}, have been explained by the Dr. {doctor_name} about the fracture of the jaw bone and the need for the surgery.. If not treated, chances of the fractured jaw bone malunion or non union and development of the infection are explained. Post-operative sequel like pain and swelling for few days and if required need for binding of the teeth (intermaxillary fixation) for few weeks have been explained. I hereby agree to undergo the surgery and agree to follow-up with the doctor as per his/her advice.$consentFooter',
  ),
];
