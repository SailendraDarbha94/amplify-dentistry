-- 0006_immutable_rows_bootstrap_parity.sql
-- Three review findings closed server-side (mirrors packages/data at Drift schema v3):
--   1. Append-only tables lose their UPDATE policy. The data layer never rewrites payments, ledger
--      postings, signed consents, prescriptions, medical-history snapshots or tooth-state records
--      (status changes happen on the documents that reference them), so the API must not either.
--      select/insert policies are unchanged; no table gains a delete policy.
--   2. Clinic bootstrap is pinned to the creator: clinics.created_by records the inserting user and
--      only that user may add the first (ownerDentist) member. Before this, any signed-in user who
--      learned a fresh clinic id during the creation window could claim it.
--   3. Schema parity with the Drift tables, where the Dart side is the contract:
--        appointments.reminder_24h_sent_at -> reminder24h_sent_at (drift's snake_case of reminder24hSentAt)
--        treatment_plan_lines.removed_at   (plan line dropped from an unaccepted plan; never deleted)
--        perio_exams.bpe_furcation         (per-sextant furcation '*' flag beside the numeric BPE code)
--        public.settings                   (per-clinic key/value settings; the sync outbox targets it)
--      drugs.clinic_id stays server-side only until the Dart Drug entity carries it.

-- ---------------------------------------------------------------------------
-- 1. Immutable rows: no UPDATE through the API
-- ---------------------------------------------------------------------------

drop policy if exists payments_update_billing_roles       on public.payments;
drop policy if exists ledger_entries_update_billing_roles on public.ledger_entries;
drop policy if exists consent_records_update_member       on public.consent_records;
drop policy if exists prescriptions_update_member         on public.prescriptions;
drop policy if exists medical_histories_update_member     on public.medical_histories;
drop policy if exists tooth_state_records_update_member   on public.tooth_state_records;

comment on table public.payments is
  'Append-only payment events. No UPDATE policy: a correction is a refund or an adjustment row.';
comment on table public.ledger_entries is
  'Append-only ledger postings. No UPDATE policy: a correction is a new posting.';
comment on table public.consent_records is
  'Signed procedure consents, immutable. No UPDATE policy: a change is a new consent.';
comment on table public.prescriptions is
  'Issued prescriptions, immutable. No UPDATE policy: a change is a new prescription.';
comment on table public.medical_histories is
  'Medical-history snapshots, append-only. No UPDATE policy: record a new snapshot.';
comment on table public.tooth_state_records is
  'Tooth-state history, append-only. No UPDATE policy: record a new state with its own effective_from.';

-- ---------------------------------------------------------------------------
-- 2. Clinic bootstrap pinned to the creating user
-- ---------------------------------------------------------------------------

alter table public.clinics
  add column created_by uuid references auth.users (id) default auth.uid();

comment on column public.clinics.created_by is
  'auth user who inserted the clinic; the only user allowed to add its first (owner) member.';

-- Creator of a clinic, readable during bootstrap when the caller is not yet a member (RLS would hide the row).
create or replace function app.clinic_created_by(p_clinic uuid)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select c.created_by from public.clinics as c where c.id = p_clinic;
$$;

revoke all on function app.clinic_created_by(uuid) from public, anon;
grant execute on function app.clinic_created_by(uuid) to authenticated, service_role;

-- A clinic row must name its creator as the caller; nobody creates a clinic on another user's behalf.
drop policy if exists clinics_insert_authenticated on public.clinics;
create policy clinics_insert_authenticated on public.clinics
  for insert to authenticated
  with check (created_by = (select auth.uid()));

-- Owners add staff; only the clinic's creator may bootstrap themselves as ownerDentist, and only while
-- the clinic has no members.
drop policy if exists clinic_members_insert_owner on public.clinic_members;
create policy clinic_members_insert_owner on public.clinic_members
  for insert to authenticated
  with check (
    clinic_id in (select app.clinic_ids_with_role('ownerDentist'))
    or (
      user_id = (select auth.uid())
      and role = 'ownerDentist'
      and app.clinic_created_by(clinic_id) = (select auth.uid())
      and not app.clinic_has_members(clinic_id)
    )
  );

-- ---------------------------------------------------------------------------
-- 3. Parity with the Drift schema
-- ---------------------------------------------------------------------------

alter table public.appointments
  rename column reminder_24h_sent_at to reminder24h_sent_at;

alter table public.treatment_plan_lines
  add column removed_at timestamptz;
comment on column public.treatment_plan_lines.removed_at is
  'Set when the line is dropped from an unaccepted plan; the row stays (append-only).';

alter table public.perio_exams
  add column bpe_furcation jsonb not null default '[]'::jsonb
  check (jsonb_typeof(bpe_furcation) = 'array');
comment on column public.perio_exams.bpe_furcation is
  'Sextant names with furcation involvement (the BPE * flag), recorded beside the numeric code in bpe.';

-- Per-clinic settings (Drift: Settings). value_json holds the JSON the device wrote; well-known keys
-- are the SettingKeys constants in packages/data (gst.rates, display.notation, counter.*, device.primary).
create table public.settings (
  clinic_id    uuid not null references public.clinics (id),
  setting_key  text not null,
  value_json   jsonb not null,
  updated_at   timestamptz not null default now(),
  primary key (clinic_id, setting_key)
);
comment on table public.settings is
  'Per-clinic key/value settings mirrored from the device settings table. Settings changes are audited '
  'by the client as entity_type Setting; the row has no id column so app.audit_row() is not attached.';

alter table public.settings enable row level security;
revoke all on table public.settings from anon;

create policy settings_select_member on public.settings
  for select to authenticated
  using (clinic_id in (select app.current_clinic_ids()));
create policy settings_insert_member on public.settings
  for insert to authenticated
  with check (clinic_id in (select app.current_clinic_ids()));
create policy settings_update_member on public.settings
  for update to authenticated
  using (clinic_id in (select app.current_clinic_ids()))
  with check (clinic_id in (select app.current_clinic_ids()));

create trigger settings_touch_updated_at
  before update on public.settings
  for each row execute function app.touch_updated_at();
