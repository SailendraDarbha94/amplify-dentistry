-- 0003_functions.sql
-- Trigger functions and server-side number minting for AmpDent.
--   * app.touch_updated_at()        sets updated_at on every update
--   * app.audit_row()               writes an audit_events row for every insert/update on tenant tables
--   * app.prevent_hard_delete()     raises on DELETE for clinical/financial tables (belt to the RLS braces)
--   * app.financial_year_start()    Indian FY (1 April) for a timestamp in a time zone
--   * app.next_invoice_number()     'INV/2026-27/0001' per clinic per FY, row-locked counter
--   * app.next_patient_number()     'P-00001' per clinic
--   * app.invoices_assign_number()  mints the real number when a DRAFT- invoice leaves draft status
--   * public.mint_invoice_number(), public.mint_patient_number()  RPC wrappers with role checks

-- ---------------------------------------------------------------------------
-- updated_at touch
-- ---------------------------------------------------------------------------

-- Sets new.updated_at = now() on every update.
create or replace function app.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end
$$;

-- ---------------------------------------------------------------------------
-- Audit trail
-- ---------------------------------------------------------------------------

-- Appends an audit_events row for the inserted/updated row. Runs as the function owner so it
-- succeeds even for roles that have no insert policy on audit_events (and for the service role).
-- actor_id falls back to the nil uuid when there is no JWT (service role, SQL editor).
-- device_id is read from the per-request setting app.device_id when the client sets it, else 'server'.
create or replace function app.audit_row()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_before     jsonb;
  v_after      jsonb;
  v_action     text;
  v_clinic_id  uuid;
  v_entity_id  text;
begin
  if tg_op = 'INSERT' then
    v_after := to_jsonb(new);
    v_action := 'create';
  else
    v_before := to_jsonb(old);
    v_after := to_jsonb(new);
    if v_before = v_after then
      return new;
    end if;
    if (v_before ->> 'status') is distinct from (v_after ->> 'status') then
      v_action := case when v_after ->> 'status' = 'deleted' then 'softDelete' else 'statusChange' end;
    else
      v_action := 'update';
    end if;
  end if;

  -- Tenant tables carry clinic_id; the clinics table is its own tenant.
  v_clinic_id := coalesce((v_after ->> 'clinic_id')::uuid, (v_after ->> 'id')::uuid);
  v_entity_id := v_after ->> 'id';

  insert into public.audit_events
    (clinic_id, actor_id, action, entity_type, entity_id, before, after, device_id, occurred_at)
  values
    (v_clinic_id,
     coalesce((select auth.uid()), '00000000-0000-0000-0000-000000000000'::uuid),
     v_action,
     tg_table_name,
     v_entity_id,
     v_before,
     v_after,
     coalesce(nullif(current_setting('app.device_id', true), ''), 'server'),
     now());
  return new;
end
$$;

revoke all on function app.audit_row() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Hard-delete guard
-- ---------------------------------------------------------------------------

-- Raises for any DELETE. Attached to append-only tables so even the service role cannot remove rows.
create or replace function app.prevent_hard_delete()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'Rows in %.% are append-only; set a status instead of deleting', tg_table_schema, tg_table_name
    using errcode = 'restrict_violation';
end
$$;

-- ---------------------------------------------------------------------------
-- Number minting
-- ---------------------------------------------------------------------------

-- 1 April of the Indian financial year containing p_at, evaluated in p_tz.
create or replace function app.financial_year_start(p_at timestamptz, p_tz text default 'Asia/Kolkata')
returns date
language sql
stable
set search_path = ''
as $$
  select case
    when extract(month from (p_at at time zone p_tz)) >= 4
      then make_date(extract(year from (p_at at time zone p_tz))::int, 4, 1)
    else make_date(extract(year from (p_at at time zone p_tz))::int - 1, 4, 1)
  end;
$$;

-- Next invoice number for a clinic in the FY starting p_fy_start, e.g. 'INV/2026-27/0001'.
-- The upsert takes a row lock on the counter, so concurrent callers serialise and never share a value.
create or replace function app.next_invoice_number(p_clinic uuid, p_fy_start date)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_fy_start  date := make_date(extract(year from p_fy_start)::int, 4, 1);
  v_value     integer;
  v_label     text;
begin
  if p_fy_start <> v_fy_start then
    raise exception 'p_fy_start must be 1 April (got %)', p_fy_start using errcode = 'invalid_parameter_value';
  end if;

  insert into app.invoice_counters as c (clinic_id, fy_start, last_value)
  values (p_clinic, v_fy_start, 1)
  on conflict (clinic_id, fy_start) do update
    set last_value = c.last_value + 1
  returning c.last_value into v_value;

  v_label := to_char(v_fy_start, 'YYYY') || '-' || to_char(v_fy_start + interval '1 year', 'YY');
  return 'INV/' || v_label || '/' || case when v_value < 10000 then lpad(v_value::text, 4, '0') else v_value::text end;
end
$$;

-- Next patient number for a clinic, e.g. 'P-00001'.
create or replace function app.next_patient_number(p_clinic uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_value integer;
begin
  insert into app.patient_counters as c (clinic_id, last_value)
  values (p_clinic, 1)
  on conflict (clinic_id) do update
    set last_value = c.last_value + 1
  returning c.last_value into v_value;

  return 'P-' || case when v_value < 100000 then lpad(v_value::text, 5, '0') else v_value::text end;
end
$$;

revoke all on function app.next_invoice_number(uuid, date) from public, anon, authenticated;
revoke all on function app.next_patient_number(uuid) from public, anon, authenticated;
revoke all on function app.financial_year_start(timestamptz, text) from public, anon;
grant execute on function app.financial_year_start(timestamptz, text) to authenticated, service_role;

-- When an offline 'DRAFT-...' invoice is synced with a non-draft status, replace the number with a minted one.
create or replace function app.invoices_assign_number()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tz text;
begin
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

-- RPC: mint an invoice number for the caller's clinic (billing roles only).
create or replace function public.mint_invoice_number(p_clinic uuid, p_issued_at timestamptz default now())
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tz text;
begin
  if not app.has_role(p_clinic, 'ownerDentist', 'receptionist') then
    raise exception 'not permitted to mint invoice numbers for clinic %', p_clinic
      using errcode = 'insufficient_privilege';
  end if;
  select c.time_zone into v_tz from public.clinics as c where c.id = p_clinic;
  return app.next_invoice_number(p_clinic, app.financial_year_start(p_issued_at, coalesce(v_tz, 'Asia/Kolkata')));
end
$$;

-- RPC: mint a patient number for the caller's clinic (any active member).
create or replace function public.mint_patient_number(p_clinic uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not (p_clinic in (select app.current_clinic_ids())) then
    raise exception 'not a member of clinic %', p_clinic using errcode = 'insufficient_privilege';
  end if;
  return app.next_patient_number(p_clinic);
end
$$;

revoke all on function public.mint_invoice_number(uuid, timestamptz) from public, anon;
revoke all on function public.mint_patient_number(uuid) from public, anon;
grant execute on function public.mint_invoice_number(uuid, timestamptz) to authenticated, service_role;
grant execute on function public.mint_patient_number(uuid) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Attach triggers
-- ---------------------------------------------------------------------------

do $$
declare
  t record;
  append_only constant text[] := array[
    'procedures', 'findings', 'tooth_state_records', 'consent_records', 'data_consents', 'clinical_notes',
    'perio_exams', 'prescriptions', 'medical_histories', 'estimates', 'treatment_plans', 'treatment_plan_lines',
    'image_records', 'implant_records', 'sterilisation_cycles',
    'invoices', 'payments', 'adjustments', 'ledger_entries',
    'audit_events', 'message_logs'
  ];
begin
  for t in
    select c.relname,
           exists (select 1 from pg_attribute a
                   where a.attrelid = c.oid and a.attname = 'updated_at' and not a.attisdropped) as has_updated_at,
           exists (select 1 from pg_attribute a
                   where a.attrelid = c.oid and a.attname = 'clinic_id' and not a.attisdropped) as has_clinic_id
    from pg_class as c
    join pg_namespace as n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r'
  loop
    if t.has_updated_at then
      execute format(
        'create trigger %I before update on public.%I
           for each row execute function app.touch_updated_at()',
        t.relname || '_touch_updated_at', t.relname);
    end if;

    if (t.has_clinic_id or t.relname = 'clinics') and t.relname <> 'audit_events' then
      execute format(
        'create trigger %I after insert or update on public.%I
           for each row execute function app.audit_row()',
        t.relname || '_audit', t.relname);
    end if;

    if t.relname = any (append_only) then
      execute format(
        'create trigger %I before delete on public.%I
           for each row execute function app.prevent_hard_delete()',
        t.relname || '_prevent_hard_delete', t.relname);
    end if;
  end loop;
end
$$;

create trigger invoices_assign_number
  before insert or update of status, number on public.invoices
  for each row execute function app.invoices_assign_number();
