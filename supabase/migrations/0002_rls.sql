-- 0002_rls.sql
-- Row Level Security for AmpDent.
-- Model: one schema, clinic_id on every tenant row, membership in public.clinic_members (user_id, clinic_id, role).
-- Follows Supabase RLS performance guidance:
--   * auth.uid() is always wrapped as (select auth.uid()) so it is evaluated once per statement;
--   * membership lookups live in STABLE SECURITY DEFINER functions with an empty search_path;
--   * every policy is scoped `to authenticated`;
--   * every column a policy filters on is indexed (clinic_id everywhere, clinic_members.user_id);
--   * role checks go through set-returning helpers used as `col in (select app.clinic_ids_with_role(...))`,
--     which the planner runs once per statement (InitPlan) instead of once per row.
-- No DELETE policy exists on any clinical or financial table, so deletes are impossible through the API.

grant usage on schema app to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Membership helpers
-- ---------------------------------------------------------------------------

-- Clinics the calling user is an active member of.
create or replace function app.current_clinic_ids()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select cm.clinic_id
  from public.clinic_members as cm
  where cm.user_id = (select auth.uid())
    and cm.is_active;
$$;

-- True when the calling user holds one of p_roles in p_clinic (Dart ClinicRole names).
create or replace function app.has_role(p_clinic uuid, variadic p_roles text[])
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.clinic_members as cm
    where cm.clinic_id = p_clinic
      and cm.user_id = (select auth.uid())
      and cm.is_active
      and cm.role = any (p_roles)
  );
$$;

-- Clinics in which the calling user holds one of p_roles (for policies that compare ids as text).
create or replace function app.clinic_ids_with_role(variadic p_roles text[])
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select cm.clinic_id
  from public.clinic_members as cm
  where cm.user_id = (select auth.uid())
    and cm.is_active
    and cm.role = any (p_roles);
$$;

-- True when the clinic already has at least one member (used to gate bootstrap of the first owner).
create or replace function app.clinic_has_members(p_clinic uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.clinic_members as cm where cm.clinic_id = p_clinic);
$$;

revoke all on function app.current_clinic_ids() from public, anon;
revoke all on function app.has_role(uuid, text[]) from public, anon;
revoke all on function app.clinic_has_members(uuid) from public, anon;
revoke all on function app.clinic_ids_with_role(text[]) from public, anon;
grant execute on function app.current_clinic_ids() to authenticated, service_role;
grant execute on function app.has_role(uuid, text[]) to authenticated, service_role;
grant execute on function app.clinic_ids_with_role(text[]) to authenticated, service_role;
grant execute on function app.clinic_has_members(uuid) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Enable RLS everywhere; anon never reads clinic data.
-- ---------------------------------------------------------------------------

do $$
declare
  t record;
begin
  for t in
    select c.relname
    from pg_class as c
    join pg_namespace as n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r'
  loop
    execute format('alter table public.%I enable row level security', t.relname);
    execute format('revoke all on table public.%I from anon', t.relname);
  end loop;
end
$$;

-- ---------------------------------------------------------------------------
-- Platform tables
-- ---------------------------------------------------------------------------

create policy profiles_select_self on public.profiles
  for select to authenticated
  using (id = (select auth.uid()));
create policy profiles_insert_self on public.profiles
  for insert to authenticated
  with check (id = (select auth.uid()));
create policy profiles_update_self on public.profiles
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

create policy clinics_select_member on public.clinics
  for select to authenticated
  using (id in (select app.current_clinic_ids()));
-- Any signed-in user may create a clinic; the first clinic_members row makes them its owner.
create policy clinics_insert_authenticated on public.clinics
  for insert to authenticated
  with check (true);
create policy clinics_update_owner on public.clinics
  for update to authenticated
  using (id in (select app.clinic_ids_with_role('ownerDentist')))
  with check (id in (select app.clinic_ids_with_role('ownerDentist')));

create policy clinic_members_select_member on public.clinic_members
  for select to authenticated
  using (clinic_id in (select app.current_clinic_ids()));
-- Owners add staff; a user may bootstrap themselves as ownerDentist of a clinic that has no members yet.
create policy clinic_members_insert_owner on public.clinic_members
  for insert to authenticated
  with check (
    clinic_id in (select app.clinic_ids_with_role('ownerDentist'))
    or (
      user_id = (select auth.uid())
      and role = 'ownerDentist'
      and not app.clinic_has_members(clinic_id)
    )
  );
create policy clinic_members_update_owner on public.clinic_members
  for update to authenticated
  using (clinic_id in (select app.clinic_ids_with_role('ownerDentist')))
  with check (clinic_id in (select app.clinic_ids_with_role('ownerDentist')));

-- Shared catalogues: platform rows (clinic_id null) are readable by every member; clinic rows are tenant scoped.
create policy catalog_items_select on public.catalog_items
  for select to authenticated
  using (clinic_id is null or clinic_id in (select app.current_clinic_ids()));
create policy catalog_items_insert on public.catalog_items
  for insert to authenticated
  with check (clinic_id in (select app.current_clinic_ids()));
create policy catalog_items_update on public.catalog_items
  for update to authenticated
  using (clinic_id in (select app.current_clinic_ids()))
  with check (clinic_id in (select app.current_clinic_ids()));
create policy catalog_items_delete_owner on public.catalog_items
  for delete to authenticated
  using (clinic_id in (select app.clinic_ids_with_role('ownerDentist')));

create policy drugs_select on public.drugs
  for select to authenticated
  using (clinic_id is null or clinic_id in (select app.current_clinic_ids()));
create policy drugs_insert on public.drugs
  for insert to authenticated
  with check (clinic_id in (select app.current_clinic_ids()));
create policy drugs_update on public.drugs
  for update to authenticated
  using (clinic_id in (select app.current_clinic_ids()))
  with check (clinic_id in (select app.current_clinic_ids()));
create policy drugs_delete_owner on public.drugs
  for delete to authenticated
  using (clinic_id in (select app.clinic_ids_with_role('ownerDentist')));

-- ---------------------------------------------------------------------------
-- Tenant tables: select / insert / update for members; never delete.
-- ---------------------------------------------------------------------------

do $$
declare
  t text;
  tenant_tables constant text[] := array[
    'chairs', 'gst_rates', 'labs',
    'patients', 'appointments', 'visits',
    'tooth_state_records', 'findings', 'clinical_notes', 'medical_histories', 'perio_exams',
    'treatment_plans', 'treatment_plan_lines', 'procedures', 'estimates',
    'consent_records', 'data_consents',
    'prescriptions', 'image_records', 'lab_cases', 'implant_records',
    'recalls', 'message_logs', 'sterilisation_cycles', 'licences'
  ];
begin
  foreach t in array tenant_tables loop
    execute format(
      'create policy %I on public.%I for select to authenticated
         using (clinic_id in (select app.current_clinic_ids()))',
      t || '_select_member', t);
    execute format(
      'create policy %I on public.%I for insert to authenticated
         with check (clinic_id in (select app.current_clinic_ids()))',
      t || '_insert_member', t);
    execute format(
      'create policy %I on public.%I for update to authenticated
         using (clinic_id in (select app.current_clinic_ids()))
         with check (clinic_id in (select app.current_clinic_ids()))',
      t || '_update_member', t);
  end loop;
end
$$;

-- Configuration rows an owner may remove outright (no clinical or financial content).
create policy chairs_delete_owner on public.chairs
  for delete to authenticated
  using (clinic_id in (select app.clinic_ids_with_role('ownerDentist')));
create policy labs_delete_owner on public.labs
  for delete to authenticated
  using (clinic_id in (select app.clinic_ids_with_role('ownerDentist')));

-- ---------------------------------------------------------------------------
-- Financial tables: read for ownerDentist / receptionist / accountant; write for ownerDentist / receptionist.
-- ---------------------------------------------------------------------------

do $$
declare
  t text;
  financial_tables constant text[] := array['invoices', 'payments', 'adjustments', 'ledger_entries'];
begin
  foreach t in array financial_tables loop
    -- clinic_ids_with_role already implies active membership, so current_clinic_ids() is not repeated.
    execute format(
      'create policy %I on public.%I for select to authenticated
         using (clinic_id in (select app.clinic_ids_with_role(''ownerDentist'', ''receptionist'', ''accountant'')))',
      t || '_select_billing_roles', t);
    execute format(
      'create policy %I on public.%I for insert to authenticated
         with check (clinic_id in (select app.clinic_ids_with_role(''ownerDentist'', ''receptionist'')))',
      t || '_insert_billing_roles', t);
    execute format(
      'create policy %I on public.%I for update to authenticated
         using (clinic_id in (select app.clinic_ids_with_role(''ownerDentist'', ''receptionist'')))
         with check (clinic_id in (select app.clinic_ids_with_role(''ownerDentist'', ''receptionist'')))',
      t || '_update_billing_roles', t);
  end loop;
end
$$;

-- ---------------------------------------------------------------------------
-- Audit events: members read their clinic's trail and may append (view/export/print events); never update or delete.
-- ---------------------------------------------------------------------------

create policy audit_events_select_member on public.audit_events
  for select to authenticated
  using (clinic_id in (select app.current_clinic_ids()));
create policy audit_events_insert_member on public.audit_events
  for insert to authenticated
  with check (clinic_id in (select app.current_clinic_ids()));
