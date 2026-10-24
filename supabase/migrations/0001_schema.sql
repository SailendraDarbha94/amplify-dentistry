-- 0001_schema.sql
-- AmpDent (amplify-dentistry) Supabase/Postgres schema.
-- Mirrors packages/core/lib/src/entities/*.dart one table per entity.
-- Conventions:
--   * uuid primary keys are client-generated (UUID v4); the default is a convenience only.
--   * every tenant table carries clinic_id -> clinics(id), indexed, used by RLS.
--   * money is bigint paise (column suffix _paise); never numeric/float.
--   * tooth ids are FDI storage keys ('11'..'85', supernumerary '11+1') as text.
--   * surface sets are the sorted canonical face string ('MOD', 'F', '' ...).
--   * enums are text with CHECK lists equal to the Dart enum .name values.
--   * list / map fields are jsonb.
--   * created_at / updated_at are timestamptz with defaults; updated_at is touched by trigger (0003).

create schema if not exists app;

comment on schema app is 'Internal helpers (functions, counters, domains). Not exposed through the API.';

-- ---------------------------------------------------------------------------
-- Domains and validation helpers
-- ---------------------------------------------------------------------------

-- FDI two-digit code with optional supernumerary suffix, e.g. '11', '55', '11+1'.
create domain app.tooth_key as text
  check (value ~ '^[1-8][1-8](\+[0-9]+)?$');

-- Canonical surface string: zero or more of M O D F L V R W, each at most once.
create domain app.surface_set as text
  check (value ~ '^[MODFLVRW]{0,8}$');

-- True when p is a jsonb array whose elements are all valid tooth keys.
create or replace function app.is_tooth_key_array(p jsonb)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p is not null
     and jsonb_typeof(p) = 'array'
     and not exists (
       select 1
       from jsonb_array_elements(p) as e
       where jsonb_typeof(e) <> 'string'
          or not (e #>> '{}') ~ '^[1-8][1-8](\+[0-9]+)?$'
     );
$$;

-- ---------------------------------------------------------------------------
-- Platform tables (not tenant scoped)
-- ---------------------------------------------------------------------------

-- One row per auth user; display data only, no clinic data.
create table public.profiles (
  id            uuid primary key references auth.users (id) on delete cascade,
  display_name  text not null default '',
  phone         text,
  email         text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- Clinic (Dart: Clinic).
create table public.clinics (
  id                uuid primary key default gen_random_uuid(),
  name              text not null,
  legal_name        text,
  address_lines     jsonb not null default '[]'::jsonb,
  city              text not null,
  state_code        text not null,
  pincode           text not null,
  phone             text not null,
  whatsapp_phone    text,
  email             text,
  gstin             text,
  default_notation  text not null default 'fdi'
                    check (default_notation in ('fdi', 'universal', 'palmer')),
  time_zone         text not null default 'Asia/Kolkata',
  upi_vpa           text,
  logo_path         text,
  region            text not null default 'in',
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

-- Clinic membership and staff record (Dart: ClinicMember). user_id links to auth and drives RLS.
create table public.clinic_members (
  id                    uuid primary key default gen_random_uuid(),
  clinic_id             uuid not null references public.clinics (id),
  user_id               uuid references auth.users (id) on delete set null,
  display_name          text not null,
  role                  text not null
                        check (role in ('ownerDentist', 'associateDentist', 'visitingSpecialist',
                                        'receptionist', 'assistant', 'accountant', 'lab')),
  registration_number   text,
  registration_council  text,
  qualifications        jsonb not null default '[]'::jsonb,
  hpr_id                text,
  phone                 text not null,
  email                 text,
  fee_share_percent     numeric(5, 2),
  is_active             boolean not null default true,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);
create index clinic_members_clinic_id_idx on public.clinic_members (clinic_id);
create index clinic_members_user_id_idx on public.clinic_members (user_id);
create unique index clinic_members_clinic_user_uniq on public.clinic_members (clinic_id, user_id)
  where user_id is not null;

-- Dental chair / operatory (Dart: Chair).
create table public.chairs (
  id          uuid primary key default gen_random_uuid(),
  clinic_id   uuid not null references public.clinics (id),
  name        text not null,
  sort_order  integer not null default 0,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index chairs_clinic_id_idx on public.chairs (clinic_id);

-- GST rate history per clinic per GstClass (CLAUDE.md: rates come from clinic config with history).
create table public.gst_rates (
  id              uuid primary key default gen_random_uuid(),
  clinic_id       uuid not null references public.clinics (id),
  gst_class       text not null
                  check (gst_class in ('exemptHealthcare', 'cosmeticTaxable', 'goods', 'standardTaxable')),
  rate_percent    numeric(5, 2) not null check (rate_percent >= 0 and rate_percent <= 100),
  itc_available   boolean not null default true,
  effective_from  date not null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (clinic_id, gst_class, effective_from)
);
create index gst_rates_clinic_id_idx on public.gst_rates (clinic_id);

-- Procedure catalogue (Dart: CatalogItem). clinic_id null = platform-wide row.
create table public.catalog_items (
  id                         uuid primary key default gen_random_uuid(),
  clinic_id                  uuid references public.clinics (id),
  code                       text not null,
  name                       text not null,
  layman_name                text not null,
  category                   text not null
                             check (category in ('diagnostic', 'preventive', 'restorative', 'endodontic',
                                                 'periodontal', 'prosthodontic', 'oralSurgery', 'orthodontic',
                                                 'pediatric', 'implant', 'cosmetic', 'other')),
  treatment_area             text not null
                             check (treatment_area in ('surface', 'tooth', 'quadrant', 'sextant', 'arch',
                                                       'toothRange', 'mouth')),
  default_fee_paise          bigint not null default 0,
  fee_min_paise              bigint not null default 0,
  fee_max_paise              bigint not null default 0,
  gst_class                  text not null default 'exemptHealthcare'
                             check (gst_class in ('exemptHealthcare', 'cosmeticTaxable', 'goods', 'standardTaxable')),
  sac_hsn_code               text not null default '999312',
  duration_minutes           integer not null default 30,
  stages                     jsonb not null default '[]'::jsonb,
  recall_interval            text
                             check (recall_interval is null or recall_interval in
                                    ('threeMonths', 'sixMonths', 'nineMonths', 'twelveMonths', 'fifteenMonths',
                                     'eighteenMonths', 'twentyOneMonths', 'twentyFourMonths')),
  consent_template_code      text,
  requires_pre_op_radiograph boolean not null default false,
  external_codes             jsonb not null default '{}'::jsonb,
  is_active                  boolean not null default true,
  sort_order                 integer not null default 0,
  created_at                 timestamptz not null default now(),
  updated_at                 timestamptz not null default now()
);
create index catalog_items_clinic_id_idx on public.catalog_items (clinic_id);
create unique index catalog_items_clinic_code_uniq on public.catalog_items (clinic_id, code)
  where clinic_id is not null;
create unique index catalog_items_global_code_uniq on public.catalog_items (code)
  where clinic_id is null;

-- Drug master (Dart: Drug). clinic_id null = platform-wide row; the seed ships in the app.
create table public.drugs (
  id                       uuid primary key default gen_random_uuid(),
  clinic_id                uuid references public.clinics (id),
  generic_name             text not null,
  brand_names              jsonb not null default '[]'::jsonb,
  strength                 text not null,
  form                     text not null
                           check (form in ('tablet', 'capsule', 'syrup', 'suspension', 'injection', 'mouthwash',
                                           'gel', 'ointment', 'paste', 'drops', 'varnish', 'toothpaste', 'other')),
  schedule                 text not null default 'h'
                           check (schedule in ('otc', 'h', 'h1', 'x', 'g')),
  schedule_effective_from  date,
  category                 text not null,
  default_dose             text not null,
  default_frequency        text not null,
  default_duration_days    integer not null,
  route                    text not null,
  allergy_group            text,
  pregnancy_caution        boolean not null default false,
  pediatric_caution        boolean not null default false,
  is_active                boolean not null default true,
  created_at               timestamptz not null default now(),
  updated_at               timestamptz not null default now()
);
create index drugs_clinic_id_idx on public.drugs (clinic_id);

-- External dental laboratory (Dart: Lab). turnaround_days maps LabCaseType name -> working days.
create table public.labs (
  id               uuid primary key default gen_random_uuid(),
  clinic_id        uuid not null references public.clinics (id),
  name             text not null,
  phone            text,
  whatsapp_phone   text,
  turnaround_days  jsonb not null default '{}'::jsonb,
  is_active        boolean not null default true,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create index labs_clinic_id_idx on public.labs (clinic_id);

-- ---------------------------------------------------------------------------
-- Patients, scheduling
-- ---------------------------------------------------------------------------

-- Patient (Dart: Patient). ABHA columns exist; ABDM integration does not yet.
create table public.patients (
  id                  uuid primary key default gen_random_uuid(),
  clinic_id           uuid not null references public.clinics (id),
  patient_number      text not null,
  first_name          text not null,
  last_name           text,
  phone               text not null,
  alt_phone           text,
  email               text,
  date_of_birth       date,
  approx_age_years    numeric(5, 2),
  age_recorded_at     timestamptz,
  sex                 text not null default 'unspecified'
                      check (sex in ('male', 'female', 'other', 'unspecified')),
  address_lines       jsonb not null default '[]'::jsonb,
  city                text,
  pincode             text,
  abha_number         text,
  abha_address        text,
  guardian_name       text,
  guardian_relation   text,
  guardian_phone      text,
  preferred_language  text not null default 'en',
  tags                jsonb not null default '[]'::jsonb,
  notes               text,
  is_active           boolean not null default true,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);
create index patients_clinic_id_idx on public.patients (clinic_id);
create index patients_clinic_phone_idx on public.patients (clinic_id, phone);
create unique index patients_clinic_patient_number_uniq on public.patients (clinic_id, patient_number);

-- Appointment (Dart: Appointment).
create table public.appointments (
  id                        uuid primary key default gen_random_uuid(),
  clinic_id                 uuid not null references public.clinics (id),
  patient_id                uuid not null references public.patients (id),
  provider_id               uuid not null references public.clinic_members (id),
  chair_id                  uuid references public.chairs (id),
  starts_at                 timestamptz not null,
  ends_at                   timestamptz not null,
  status                    text not null default 'scheduled'
                            check (status in ('scheduled', 'confirmed', 'arrived', 'inChair', 'completed',
                                              'cancelled', 'noShow', 'rescheduled')),
  reason                    text not null default '',
  planned_procedure_ids     jsonb not null default '[]'::jsonb,
  source                    text not null default 'phone'
                            check (source in ('walkIn', 'phone', 'whatsapp', 'online', 'practo', 'recall')),
  notes                     text,
  confirmed_at              timestamptz,
  reminder_24h_sent_at      timestamptz,
  reminder_morning_sent_at  timestamptz,
  arrived_at                timestamptz,
  cancelled_reason          text,
  created_at                timestamptz not null default now(),
  updated_at                timestamptz not null default now(),
  check (ends_at > starts_at)
);
create index appointments_clinic_id_idx on public.appointments (clinic_id);
create index appointments_clinic_starts_at_idx on public.appointments (clinic_id, starts_at);
create index appointments_clinic_patient_idx on public.appointments (clinic_id, patient_id);

-- Visit / encounter (Dart: Visit).
create table public.visits (
  id               uuid primary key default gen_random_uuid(),
  clinic_id        uuid not null references public.clinics (id),
  patient_id       uuid not null references public.patients (id),
  provider_id      uuid not null references public.clinic_members (id),
  appointment_id   uuid references public.appointments (id),
  started_at       timestamptz not null,
  ended_at         timestamptz,
  chief_complaint  text,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create index visits_clinic_id_idx on public.visits (clinic_id);
create index visits_clinic_patient_idx on public.visits (clinic_id, patient_id, started_at desc);

-- ---------------------------------------------------------------------------
-- Clinical record (append-only; deletes blocked by RLS and trigger)
-- ---------------------------------------------------------------------------

-- Tooth state history (Dart: ToothStateRecord). Latest effective_from per tooth wins.
create table public.tooth_state_records (
  id              uuid primary key default gen_random_uuid(),
  clinic_id       uuid not null references public.clinics (id),
  patient_id      uuid not null references public.patients (id),
  tooth           app.tooth_key not null,
  state           text not null
                  check (state in ('present', 'unerupted', 'erupting', 'impacted', 'missing', 'extracted',
                                   'exfoliated', 'retainedPrimary', 'implant', 'supernumerary')),
  effective_from  timestamptz not null,
  source          text not null
                  check (source in ('ageDefault', 'clinician', 'procedure', 'import')),
  procedure_id    uuid,
  recorded_by     uuid not null references public.clinic_members (id),
  note            text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index tooth_state_records_clinic_id_idx on public.tooth_state_records (clinic_id);
create index tooth_state_records_clinic_patient_idx
  on public.tooth_state_records (clinic_id, patient_id, tooth, effective_from desc);

-- Clinical finding / diagnosis (Dart: Finding).
create table public.findings (
  id                        uuid primary key default gen_random_uuid(),
  clinic_id                 uuid not null references public.clinics (id),
  patient_id                uuid not null references public.patients (id),
  visit_id                  uuid references public.visits (id),
  tooth                     app.tooth_key,
  surfaces                  app.surface_set not null default '',
  snomed_code               text,
  icd10_code                text,
  description               text not null,
  icdas                     text
                            check (icdas is null or icdas in
                                   ('sound', 'firstVisualChange', 'distinctVisualChange', 'enamelBreakdown',
                                    'dentineShadow', 'distinctCavity', 'extensiveCavity')),
  status                    text not null default 'active'
                            check (status in ('active', 'resolved', 'existingPrior', 'deleted')),
  recorded_at               timestamptz not null,
  recorded_by               uuid not null references public.clinic_members (id),
  resolved_at               timestamptz,
  resolved_by_procedure_id  uuid,
  note                      text,
  created_at                timestamptz not null default now(),
  updated_at                timestamptz not null default now()
);
create index findings_clinic_id_idx on public.findings (clinic_id);
create index findings_clinic_patient_status_idx on public.findings (clinic_id, patient_id, status);

-- Versioned case-sheet note (Dart: ClinicalNote).
create table public.clinical_notes (
  id                          uuid primary key default gen_random_uuid(),
  clinic_id                   uuid not null references public.clinics (id),
  patient_id                  uuid not null references public.patients (id),
  visit_id                    uuid not null references public.visits (id),
  author_id                   uuid not null references public.clinic_members (id),
  chief_complaint             text,
  history_of_present_illness  text,
  past_dental_history         text,
  past_medical_history        text,
  personal_history            text,
  extraoral_exam              text,
  intraoral_exam              text,
  provisional_diagnosis       text,
  investigations              text,
  final_diagnosis             text,
  treatment_done              text,
  advice                      text,
  follow_up                   text,
  free_text                   text,
  version                     integer not null default 1 check (version >= 1),
  supersedes_note_id          uuid references public.clinical_notes (id),
  signed_at                   timestamptz,
  created_at                  timestamptz not null default now(),
  updated_at                  timestamptz not null default now()
);
create index clinical_notes_clinic_id_idx on public.clinical_notes (clinic_id);
create index clinical_notes_clinic_patient_idx on public.clinical_notes (clinic_id, patient_id, created_at desc);
create index clinical_notes_visit_idx on public.clinical_notes (visit_id);

-- Structured medical history snapshot (Dart: MedicalHistory). allergies is a jsonb array of AllergyEntry.
create table public.medical_histories (
  id                     uuid primary key default gen_random_uuid(),
  clinic_id              uuid not null references public.clinics (id),
  patient_id             uuid not null references public.patients (id),
  recorded_at            timestamptz not null,
  recorded_by            uuid not null references public.clinic_members (id),
  allergies              jsonb not null default '[]'::jsonb,
  medications            jsonb not null default '[]'::jsonb,
  diabetes               boolean not null default false,
  hba1c                  numeric(4, 1),
  hypertension           boolean not null default false,
  cardiac_condition      text,
  bleeding_disorder      boolean not null default false,
  anticoagulant          text,
  antiresorptive         text,
  antiresorptive_route   text
                         check (antiresorptive_route is null or antiresorptive_route in ('oral', 'intravenous')),
  antiresorptive_years   numeric(4, 1),
  oncology_treatment     boolean not null default false,
  pregnant               boolean not null default false,
  pregnancy_trimester    integer check (pregnancy_trimester is null or pregnancy_trimester between 1 and 3),
  asthma                 boolean not null default false,
  epilepsy               boolean not null default false,
  thyroid                boolean not null default false,
  steroids               boolean not null default false,
  hepatitis              boolean not null default false,
  hiv                    boolean not null default false,
  smoking                text not null default 'never'
                         check (smoking in ('never', 'former', 'current')),
  alcohol                boolean not null default false,
  other_notes            text,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now()
);
create index medical_histories_clinic_id_idx on public.medical_histories (clinic_id);
create index medical_histories_clinic_patient_idx
  on public.medical_histories (clinic_id, patient_id, recorded_at desc);

-- Periodontal examination (Dart: PerioExam). sites/teeth are jsonb arrays; bpe maps Sextant name -> BpeCode name.
create table public.perio_exams (
  id           uuid primary key default gen_random_uuid(),
  clinic_id    uuid not null references public.clinics (id),
  patient_id   uuid not null references public.patients (id),
  visit_id     uuid references public.visits (id),
  examined_at  timestamptz not null,
  examiner_id  uuid not null references public.clinic_members (id),
  sites        jsonb not null default '[]'::jsonb,
  teeth        jsonb not null default '[]'::jsonb,
  bpe          jsonb not null default '{}'::jsonb,
  stage        text check (stage is null or stage in ('stage1', 'stage2', 'stage3', 'stage4')),
  grade        text check (grade is null or grade in ('gradeA', 'gradeB', 'gradeC')),
  note         text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index perio_exams_clinic_id_idx on public.perio_exams (clinic_id);
create index perio_exams_clinic_patient_idx on public.perio_exams (clinic_id, patient_id, examined_at desc);

-- ---------------------------------------------------------------------------
-- Treatment planning and procedures
-- ---------------------------------------------------------------------------

-- Treatment plan header (Dart: TreatmentPlan). phases is a jsonb array of PlanPhase.
create table public.treatment_plans (
  id                        uuid primary key default gen_random_uuid(),
  clinic_id                 uuid not null references public.clinics (id),
  patient_id                uuid not null references public.patients (id),
  title                     text not null,
  status                    text not null default 'active'
                            check (status in ('active', 'inactive', 'saved', 'accepted', 'completed', 'superseded')),
  phases                    jsonb not null default '[]'::jsonb,
  version                   integer not null default 1 check (version >= 1),
  supersedes_plan_id        uuid references public.treatment_plans (id),
  presented_at              timestamptz,
  accepted_at               timestamptz,
  accepted_by_signer_name   text,
  accepted_signature_hash   text,
  snapshot_hash             text,
  created_by                uuid not null references public.clinic_members (id),
  created_at                timestamptz not null default now(),
  updated_at                timestamptz not null default now()
);
create index treatment_plans_clinic_id_idx on public.treatment_plans (clinic_id);
create index treatment_plans_clinic_patient_idx on public.treatment_plans (clinic_id, patient_id, status);

-- Treatment plan line (Dart: TreatmentPlanLine).
create table public.treatment_plan_lines (
  id                 uuid primary key default gen_random_uuid(),
  plan_id            uuid not null references public.treatment_plans (id),
  clinic_id          uuid not null references public.clinics (id),
  patient_id         uuid not null references public.patients (id),
  catalog_item_id    uuid not null references public.catalog_items (id),
  code               text not null,
  name               text not null,
  layman_name        text not null,
  tooth              app.tooth_key,
  teeth              jsonb not null default '[]'::jsonb check (app.is_tooth_key_array(teeth)),
  surfaces           app.surface_set not null default '',
  treatment_area     text not null
                     check (treatment_area in ('surface', 'tooth', 'quadrant', 'sextant', 'arch', 'toothRange', 'mouth')),
  phase_index        integer not null default 0,
  sequence           integer not null default 0,
  quantity           integer not null default 1 check (quantity >= 1),
  unit_fee_paise     bigint not null default 0,
  discount_paise     bigint not null default 0,
  gst_class          text not null default 'exemptHealthcare'
                     check (gst_class in ('exemptHealthcare', 'cosmeticTaxable', 'goods', 'standardTaxable')),
  is_alternative     boolean not null default false,
  alternative_group  text,
  procedure_id       uuid,
  note               text,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);
create index treatment_plan_lines_clinic_id_idx on public.treatment_plan_lines (clinic_id);
create index treatment_plan_lines_plan_idx on public.treatment_plan_lines (plan_id, phase_index, sequence);
create index treatment_plan_lines_clinic_patient_idx on public.treatment_plan_lines (clinic_id, patient_id);

-- Procedure record (Dart: ProcedureRecord). Append-only; lifecycle via status.
create table public.procedures (
  id                uuid primary key default gen_random_uuid(),
  clinic_id         uuid not null references public.clinics (id),
  patient_id        uuid not null references public.patients (id),
  visit_id          uuid references public.visits (id),
  plan_id           uuid references public.treatment_plans (id),
  plan_line_id      uuid references public.treatment_plan_lines (id),
  catalog_item_id   uuid not null references public.catalog_items (id),
  code              text not null,
  name              text not null,
  tooth             app.tooth_key,
  teeth             jsonb not null default '[]'::jsonb check (app.is_tooth_key_array(teeth)),
  surfaces          app.surface_set not null default '',
  treatment_area    text not null
                    check (treatment_area in ('surface', 'tooth', 'quadrant', 'sextant', 'arch', 'toothRange', 'mouth')),
  status            text not null default 'planned'
                    check (status in ('planned', 'plannedInactive', 'accepted', 'inProgress', 'completed',
                                      'existingCurrentProvider', 'existingOtherProvider', 'referred',
                                      'condition', 'deleted')),
  provider_id       uuid not null references public.clinic_members (id),
  fee_paise         bigint not null default 0,
  discount_paise    bigint not null default 0,
  stage_index       integer not null default 0 check (stage_index >= 0),
  total_stages      integer not null default 1 check (total_stages >= 1),
  stage_names       jsonb not null default '[]'::jsonb,
  planned_at        timestamptz,
  accepted_at       timestamptz,
  started_at        timestamptz,
  completed_at      timestamptz,
  lab_case_id       uuid,
  note              text,
  pre_op_image_ids  jsonb not null default '[]'::jsonb,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);
create index procedures_clinic_id_idx on public.procedures (clinic_id);
create index procedures_clinic_patient_status_idx on public.procedures (clinic_id, patient_id, status);
create index procedures_clinic_provider_idx on public.procedures (clinic_id, provider_id, completed_at desc);

-- Late FKs from clinical tables to procedures.
alter table public.tooth_state_records
  add constraint tooth_state_records_procedure_fk foreign key (procedure_id) references public.procedures (id);
alter table public.findings
  add constraint findings_resolved_by_procedure_fk
  foreign key (resolved_by_procedure_id) references public.procedures (id);
alter table public.treatment_plan_lines
  add constraint treatment_plan_lines_procedure_fk foreign key (procedure_id) references public.procedures (id);

-- Versioned estimate (Dart: Estimate). lines is a jsonb array of EstimateLine; version > 1 needs justification.
create table public.estimates (
  id                    uuid primary key default gen_random_uuid(),
  clinic_id             uuid not null references public.clinics (id),
  patient_id            uuid not null references public.patients (id),
  plan_id               uuid references public.treatment_plans (id),
  version               integer not null default 1 check (version >= 1),
  number                text not null,
  lines                 jsonb not null default '[]'::jsonb,
  subtotal_paise        bigint not null default 0,
  discount_total_paise  bigint not null default 0,
  tax_total_paise       bigint not null default 0,
  grand_total_paise     bigint not null default 0,
  issued_at             timestamptz not null,
  issued_by             uuid not null references public.clinic_members (id),
  justification         text,
  valid_until           timestamptz,
  status                text not null default 'draft'
                        check (status in ('draft', 'issued', 'accepted', 'superseded')),
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  check (version = 1 or justification is not null)
);
create index estimates_clinic_id_idx on public.estimates (clinic_id);
create index estimates_clinic_patient_idx on public.estimates (clinic_id, patient_id, issued_at desc);
create unique index estimates_clinic_number_uniq on public.estimates (clinic_id, number);

-- ---------------------------------------------------------------------------
-- Consent
-- ---------------------------------------------------------------------------

-- Procedure consent with e-signature (Dart: ConsentRecord). Never merged with data_consents.
create table public.consent_records (
  id                            uuid primary key default gen_random_uuid(),
  clinic_id                     uuid not null references public.clinics (id),
  patient_id                    uuid not null references public.patients (id),
  template_code                 text not null,
  template_version_hash         text not null,
  language_code                 text not null,
  procedure_ids                 jsonb not null default '[]'::jsonb,
  plan_id                       uuid references public.treatment_plans (id),
  teeth                         jsonb not null default '[]'::jsonb check (app.is_tooth_key_array(teeth)),
  rendered_text                 text not null,
  signer_name                   text not null,
  signer_relation               text not null
                                check (signer_relation in ('self', 'parent', 'guardian', 'spouse', 'attendant')),
  signer_phone                  text,
  signature_image_path          text,
  otp_verified                  boolean not null default false,
  signed_at                     timestamptz not null,
  dentist_id                    uuid not null references public.clinic_members (id),
  dentist_registration_number   text not null,
  discussion_note               text,
  witness_name                  text,
  device_id                     text not null,
  document_hash                 text not null,
  pdf_path                      text,
  created_at                    timestamptz not null default now(),
  updated_at                    timestamptz not null default now()
);
create index consent_records_clinic_id_idx on public.consent_records (clinic_id);
create index consent_records_clinic_patient_idx on public.consent_records (clinic_id, patient_id, signed_at desc);

-- DPDP purpose-scoped data consent (Dart: DataConsent).
create table public.data_consents (
  id              uuid primary key default gen_random_uuid(),
  clinic_id       uuid not null references public.clinics (id),
  patient_id      uuid not null references public.patients (id),
  purpose         text not null
                  check (purpose in ('treatmentRecords', 'billing', 'appointmentReminders', 'recallReminders',
                                     'marketing', 'photoUse', 'thirdPartySharing', 'research')),
  granted         boolean not null,
  notice_version  text not null,
  language_code   text not null,
  channel         text not null,
  granted_at      timestamptz not null,
  withdrawn_at    timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index data_consents_clinic_id_idx on public.data_consents (clinic_id);
create index data_consents_clinic_patient_purpose_idx
  on public.data_consents (clinic_id, patient_id, purpose, granted_at desc);

-- ---------------------------------------------------------------------------
-- Billing (append-only)
-- ---------------------------------------------------------------------------

-- Invoice / receipt header (Dart: Invoice). lines is a jsonb array of InvoiceLine (each with gst_class + SAC/HSN).
-- Local drafts use 'DRAFT-' numbers; app.next_invoice_number() mints the real one on first sync.
create table public.invoices (
  id                    uuid primary key default gen_random_uuid(),
  clinic_id             uuid not null references public.clinics (id),
  patient_id            uuid not null references public.patients (id),
  number                text not null,
  document_type         text not null
                        check (document_type in ('receipt', 'taxInvoice', 'invoiceCumBillOfSupply', 'billOfSupply')),
  status                text not null default 'draft'
                        check (status in ('draft', 'issued', 'partiallyPaid', 'paid', 'voided')),
  issued_at             timestamptz not null,
  lines                 jsonb not null default '[]'::jsonb,
  subtotal_paise        bigint not null default 0,
  discount_total_paise  bigint not null default 0,
  taxable_total_paise   bigint not null default 0,
  tax_total_paise       bigint not null default 0,
  grand_total_paise     bigint not null default 0,
  amount_paid_paise     bigint not null default 0,
  notes                 text,
  issued_by             uuid not null references public.clinic_members (id),
  void_reason           text,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  check (status = 'draft' or number not like 'DRAFT-%'),
  check (status <> 'voided' or void_reason is not null)
);
create index invoices_clinic_id_idx on public.invoices (clinic_id);
create unique index invoices_clinic_number_uniq on public.invoices (clinic_id, number);
create index invoices_clinic_patient_idx on public.invoices (clinic_id, patient_id, issued_at desc);
create index invoices_clinic_status_idx on public.invoices (clinic_id, status);

-- Payment event (Dart: Payment). Token, last four and brand only; no PAN, no expiry, no CVV, ever.
create table public.payments (
  id             uuid primary key default gen_random_uuid(),
  clinic_id      uuid not null references public.clinics (id),
  patient_id     uuid not null references public.patients (id),
  invoice_id     uuid references public.invoices (id),
  amount_paise   bigint not null,
  method         text not null
                 check (method in ('cash', 'upi', 'card', 'netBanking', 'emi', 'cheque', 'wallet', 'other')),
  reference      text,
  gateway_token  text,
  card_last4     text check (card_last4 is null or card_last4 ~ '^[0-9]{4}$'),
  card_brand     text,
  received_at    timestamptz not null,
  received_by    uuid not null references public.clinic_members (id),
  is_refund      boolean not null default false,
  note           text,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create index payments_clinic_id_idx on public.payments (clinic_id);
create index payments_clinic_patient_idx on public.payments (clinic_id, patient_id, received_at desc);
create index payments_invoice_idx on public.payments (invoice_id);

-- Typed ledger adjustment (Dart: Adjustment).
create table public.adjustments (
  id            uuid primary key default gen_random_uuid(),
  clinic_id     uuid not null references public.clinics (id),
  patient_id    uuid not null references public.patients (id),
  invoice_id    uuid references public.invoices (id),
  type          text not null
                check (type in ('discount', 'writeOff', 'refund', 'specialistShare', 'correction')),
  amount_paise  bigint not null,
  reason        text not null,
  approved_by   uuid not null references public.clinic_members (id),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create index adjustments_clinic_id_idx on public.adjustments (clinic_id);
create index adjustments_clinic_patient_idx on public.adjustments (clinic_id, patient_id);

-- Patient ledger posting (Dart: LedgerEntry). amount signed: charges +, payments -.
create table public.ledger_entries (
  id            uuid primary key default gen_random_uuid(),
  clinic_id     uuid not null references public.clinics (id),
  patient_id    uuid not null references public.patients (id),
  entry_type    text not null
                check (entry_type in ('charge', 'payment', 'adjustment', 'refund')),
  amount_paise  bigint not null,
  reference_id  uuid not null,
  occurred_at   timestamptz not null,
  description   text not null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create index ledger_entries_clinic_id_idx on public.ledger_entries (clinic_id);
create index ledger_entries_clinic_patient_idx on public.ledger_entries (clinic_id, patient_id, occurred_at);
create index ledger_entries_reference_idx on public.ledger_entries (reference_id);

-- ---------------------------------------------------------------------------
-- Prescriptions, imaging, lab, implants
-- ---------------------------------------------------------------------------

-- Prescription (Dart: Prescription). lines is a jsonb array of PrescriptionLine. Registration number mandatory.
create table public.prescriptions (
  id                                 uuid primary key default gen_random_uuid(),
  clinic_id                          uuid not null references public.clinics (id),
  patient_id                         uuid not null references public.patients (id),
  visit_id                           uuid references public.visits (id),
  prescriber_id                      uuid not null references public.clinic_members (id),
  prescriber_name                    text not null,
  prescriber_registration_number     text not null,
  prescriber_qualifications          jsonb not null default '[]'::jsonb,
  issued_at                          timestamptz not null,
  diagnosis                          text,
  lines                              jsonb not null default '[]'::jsonb,
  is_repeatable                      boolean not null default false,
  dispensed_by_clinic                boolean not null default false,
  verification_code                  text not null,
  document_hash                      text,
  pdf_path                           text,
  created_at                         timestamptz not null default now(),
  updated_at                         timestamptz not null default now()
);
create index prescriptions_clinic_id_idx on public.prescriptions (clinic_id);
create index prescriptions_clinic_patient_idx on public.prescriptions (clinic_id, patient_id, issued_at desc);
create unique index prescriptions_clinic_verification_code_uniq on public.prescriptions (clinic_id, verification_code);

-- Image / radiograph / document metadata (Dart: ImageRecord). Bytes live in Storage bucket clinic-media.
create table public.image_records (
  id                   uuid primary key default gen_random_uuid(),
  clinic_id            uuid not null references public.clinics (id),
  patient_id           uuid not null references public.patients (id),
  visit_id             uuid references public.visits (id),
  kind                 text not null
                       check (kind in ('photoIntraoral', 'photoExtraoral', 'periapical', 'bitewing', 'occlusal',
                                       'opg', 'cbct', 'scan', 'document', 'other')),
  file_path            text not null,
  thumbnail_path       text,
  captured_at          timestamptz not null,
  teeth                jsonb not null default '[]'::jsonb check (app.is_tooth_key_array(teeth)),
  fmx_slot             text,
  is_pre_operative     boolean not null default false,
  procedure_id         uuid references public.procedures (id),
  note                 text,
  sha256               text,
  sharing_consent_id   uuid references public.data_consents (id),
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);
create index image_records_clinic_id_idx on public.image_records (clinic_id);
create index image_records_clinic_patient_idx on public.image_records (clinic_id, patient_id, captured_at desc);

-- Lab case (Dart: LabCase).
create table public.lab_cases (
  id                  uuid primary key default gen_random_uuid(),
  clinic_id           uuid not null references public.clinics (id),
  patient_id          uuid not null references public.patients (id),
  procedure_id        uuid references public.procedures (id),
  lab_id              uuid not null references public.labs (id),
  case_type           text not null
                      check (case_type in ('crownPfm', 'crownZirconia', 'crownMetal', 'bridge', 'inlayOnlay', 'veneer',
                                           'completeDenture', 'partialDenture', 'castPartial', 'nightGuard',
                                           'aligner', 'retainer', 'implantCrown', 'other')),
  teeth               jsonb not null default '[]'::jsonb check (app.is_tooth_key_array(teeth)),
  material            text,
  shade               text,
  impression_type     text,
  instructions        text,
  lab_fee_paise       bigint not null default 0,
  status              text not null default 'created'
                      check (status in ('created', 'sent', 'received', 'qualityChecked', 'fitted',
                                        'remakeRequested', 'cancelled')),
  sent_at             timestamptz,
  due_at              timestamptz,
  received_at         timestamptz,
  quality_checked_at  timestamptz,
  fitted_at           timestamptz,
  remake_reason       text,
  remake_of_case_id   uuid references public.lab_cases (id),
  slip_pdf_path       text,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);
create index lab_cases_clinic_id_idx on public.lab_cases (clinic_id);
create index lab_cases_clinic_status_due_idx on public.lab_cases (clinic_id, status, due_at);
create index lab_cases_clinic_patient_idx on public.lab_cases (clinic_id, patient_id);

alter table public.procedures
  add constraint procedures_lab_case_fk foreign key (lab_case_id) references public.lab_cases (id);

-- Implant placement record (Dart: ImplantRecord). Lot number and UDI for traceability.
create table public.implant_records (
  id                     uuid primary key default gen_random_uuid(),
  clinic_id              uuid not null references public.clinics (id),
  patient_id             uuid not null references public.patients (id),
  tooth                  app.tooth_key not null,
  procedure_id           uuid references public.procedures (id),
  brand                  text not null,
  system                 text,
  diameter_mm            numeric(4, 2) not null,
  length_mm              numeric(4, 2) not null,
  lot_number             text not null,
  udi                    text,
  expiry_date            date,
  placed_at              timestamptz not null,
  insertion_torque_ncm   numeric(5, 1),
  graft_material         text,
  membrane               text,
  status                 text not null default 'placed'
                         check (status in ('placed', 'loaded', 'failed', 'explanted')),
  note                   text,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now()
);
create index implant_records_clinic_id_idx on public.implant_records (clinic_id);
create index implant_records_clinic_patient_idx on public.implant_records (clinic_id, patient_id);

-- ---------------------------------------------------------------------------
-- Recall, messaging, compliance, audit
-- ---------------------------------------------------------------------------

-- Procedure-triggered recall (Dart: Recall).
create table public.recalls (
  id                          uuid primary key default gen_random_uuid(),
  clinic_id                   uuid not null references public.clinics (id),
  patient_id                  uuid not null references public.patients (id),
  type                        text not null
                              check (type in ('hygiene', 'review', 'orthoAdjustment', 'implantReview', 'postOp', 'custom')),
  triggered_by_procedure_id   uuid references public.procedures (id),
  due_at                      timestamptz not null,
  interval                    text
                              check (interval is null or interval in
                                     ('threeMonths', 'sixMonths', 'nineMonths', 'twelveMonths', 'fifteenMonths',
                                      'eighteenMonths', 'twentyOneMonths', 'twentyFourMonths')),
  status                      text not null default 'due'
                              check (status in ('due', 'notified', 'scheduled', 'completed', 'dismissed')),
  last_notified_at            timestamptz,
  notify_count                integer not null default 0,
  appointment_id              uuid references public.appointments (id),
  estimated_value_paise       bigint not null default 0,
  note                        text,
  created_at                  timestamptz not null default now(),
  updated_at                  timestamptz not null default now()
);
create index recalls_clinic_id_idx on public.recalls (clinic_id);
create index recalls_clinic_due_status_idx on public.recalls (clinic_id, due_at, status);
create index recalls_clinic_patient_idx on public.recalls (clinic_id, patient_id);

-- WhatsApp / SMS delivery log (Dart: MessageLog). No clinical content in bodies (CLAUDE.md).
create table public.message_logs (
  id                   uuid primary key default gen_random_uuid(),
  clinic_id            uuid not null references public.clinics (id),
  patient_id           uuid references public.patients (id),
  channel              text not null check (channel in ('whatsapp', 'sms')),
  category             text not null
                       check (category in ('utility', 'authentication', 'marketing', 'service')),
  template_code        text not null,
  to_phone             text not null,
  variables            jsonb not null default '{}'::jsonb,
  rendered_preview     text not null,
  status               text not null default 'queued'
                       check (status in ('queued', 'sent', 'delivered', 'read', 'failed', 'cancelled')),
  provider_message_id  text,
  error                text,
  cost_paise           integer,
  sent_at              timestamptz,
  delivered_at         timestamptz,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);
create index message_logs_clinic_id_idx on public.message_logs (clinic_id);
create index message_logs_clinic_created_idx on public.message_logs (clinic_id, created_at desc);
create index message_logs_clinic_patient_idx on public.message_logs (clinic_id, patient_id);
create index message_logs_provider_message_idx on public.message_logs (provider_message_id);

-- Autoclave cycle log (Dart: SterilisationCycle).
create table public.sterilisation_cycles (
  id                            uuid primary key default gen_random_uuid(),
  clinic_id                     uuid not null references public.clinics (id),
  cycle_number                  text not null,
  autoclave_name                text not null,
  cycled_at                     timestamptz not null,
  cycle_type                    text not null
                                check (cycle_type in ('classB', 'classN', 'classS', 'chemical')),
  temperature_c                 numeric(5, 1),
  pressure_kpa                  numeric(6, 1),
  duration_minutes              integer,
  chemical_indicator_passed     boolean not null default true,
  biological_indicator_result   text
                                check (biological_indicator_result is null or biological_indicator_result in
                                       ('notDone', 'pending', 'pass', 'fail')),
  load_contents                 text,
  operator_id                   uuid not null references public.clinic_members (id),
  note                          text,
  created_at                    timestamptz not null default now(),
  updated_at                    timestamptz not null default now()
);
create index sterilisation_cycles_clinic_id_idx on public.sterilisation_cycles (clinic_id);
create index sterilisation_cycles_clinic_cycled_idx on public.sterilisation_cycles (clinic_id, cycled_at desc);

-- Licence / registration with expiry (Dart: Licence).
create table public.licences (
  id             uuid primary key default gen_random_uuid(),
  clinic_id      uuid not null references public.clinics (id),
  kind           text not null
                 check (kind in ('aerbRegistration', 'biomedicalWasteAuthorisation',
                                 'clinicalEstablishmentRegistration', 'tradeLicence', 'fireNoc',
                                 'gstRegistration', 'dentalCouncilRegistration', 'other')),
  identifier     text not null,
  authority      text,
  issued_at      timestamptz,
  expires_at     timestamptz,
  qa_due_at      timestamptz,
  document_path  text,
  note           text,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create index licences_clinic_id_idx on public.licences (clinic_id);
create index licences_clinic_expires_idx on public.licences (clinic_id, expires_at);

-- Immutable audit trail (Dart: AuditEvent). Written by app.audit_row() and by clients for view/export/print.
-- actor_id is the nil uuid when written by the service role.
create table public.audit_events (
  id            uuid primary key default gen_random_uuid(),
  clinic_id     uuid not null references public.clinics (id),
  actor_id      uuid not null default '00000000-0000-0000-0000-000000000000',
  action        text not null
                check (action in ('create', 'update', 'statusChange', 'softDelete', 'view', 'export', 'print',
                                  'share', 'login', 'logout', 'settingsChange')),
  entity_type   text not null,
  entity_id     text not null,
  before        jsonb,
  after         jsonb,
  reason        text,
  device_id     text not null default 'server',
  occurred_at   timestamptz not null default now(),
  created_at    timestamptz not null default now()
);
create index audit_events_clinic_id_idx on public.audit_events (clinic_id);
create index audit_events_clinic_entity_idx
  on public.audit_events (clinic_id, entity_type, entity_id, occurred_at);
create index audit_events_clinic_occurred_idx on public.audit_events (clinic_id, occurred_at desc);

-- ---------------------------------------------------------------------------
-- Server-side counters (app schema, never exposed through the API)
-- ---------------------------------------------------------------------------

-- Per-clinic, per-financial-year invoice sequence. fy_start is 1 April of the FY.
create table app.invoice_counters (
  clinic_id   uuid not null references public.clinics (id),
  fy_start    date not null,
  last_value  integer not null default 0,
  primary key (clinic_id, fy_start)
);

-- Per-clinic patient number sequence.
create table app.patient_counters (
  clinic_id   uuid primary key references public.clinics (id),
  last_value  integer not null default 0
);
