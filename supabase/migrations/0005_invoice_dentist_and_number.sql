-- 0005_invoice_dentist_and_number.sql
-- Two integrity fixes on public.invoices (mirrors packages/core Invoice and the Drift schema v2):
--   1. The treating dentist is frozen on every issued invoice (dentist_id, dentist_name,
--      dentist_qualifications, dentist_registration_number, dentist_registration_council), so the
--      receipt prints the clinician's registration number (DCI Code 3.4.1) regardless of which
--      member reprints it. A non-draft invoice must name a registered dentist.
--   2. app.invoices_assign_number() mints a number only once. The client keeps its 'DRAFT-' number
--      until the server number is written back, so every later local write (payment, void) replays the
--      DRAFT- number; the old trigger re-minted on each replay, burning sequence values and renumbering
--      the invoice. A minted number is now immutable on UPDATE.

alter table public.invoices
  add column dentist_id                   uuid references public.clinic_members (id),
  add column dentist_name                 text,
  add column dentist_qualifications       jsonb not null default '[]'::jsonb,
  add column dentist_registration_number  text,
  add column dentist_registration_council text;

alter table public.invoices
  add constraint invoices_issued_name_registered_dentist
  check (status = 'draft' or (dentist_id is not null and coalesce(dentist_registration_number, '') <> ''));

comment on column public.invoices.dentist_registration_number is
  'Treating dentist''s council registration frozen at issue (DCI Code 3.4.1); issued_by is whoever raised the bill.';

-- Mint when a DRAFT- invoice leaves draft status; never change a number that is already minted.
create or replace function app.invoices_assign_number()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tz text;
begin
  if tg_op = 'UPDATE' and old.number not like 'DRAFT-%' then
    -- Minted numbers are immutable: a client replaying its local DRAFT- number (or any other value)
    -- must not renumber the invoice or advance the per-FY counter.
    new.number := old.number;
  end if;
  if new.status <> 'draft' and new.number like 'DRAFT-%' then
    select c.time_zone into v_tz from public.clinics as c where c.id = new.clinic_id;
    new.number := app.next_invoice_number(
      new.clinic_id,
      app.financial_year_start(new.issued_at, coalesce(v_tz, 'Asia/Kolkata')));
  end if;
  return new;
end
$$;

revoke all on function app.invoices_assign_number() from public, anon, authenticated;
