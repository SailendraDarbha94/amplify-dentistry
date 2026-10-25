-- smoke.sql
-- Behavioural checks for the AmpDent schema, run by tests/run_local.sh after the migrations.
-- Each block raises if an expectation is not met; psql runs with ON_ERROR_STOP so the script fails loudly.
-- Fixed ids make the output deterministic.

\set ON_ERROR_STOP on
\set QUIET on

-- Users ---------------------------------------------------------------------
insert into auth.users (id, phone) values
  ('11111111-1111-1111-1111-111111111111', '+919000000001'),  -- owner of clinic A
  ('22222222-2222-2222-2222-222222222222', '+919000000002'),  -- owner of clinic B
  ('33333333-3333-3333-3333-333333333333', '+919000000003');  -- associate dentist in clinic A

-- Clinic A bootstrapped by user 1 ---------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
set local app.device_id = 'phone-u1';

insert into public.clinics (id, name, city, state_code, pincode, phone, gstin)
values ('aaaaaaaa-0000-0000-0000-000000000001', 'Smile Dental', 'Hyderabad', '36', '500081', '+914000000001', null);

insert into public.clinic_members (id, clinic_id, user_id, display_name, role, registration_number, phone)
values ('aaaaaaaa-0000-0000-0000-00000000000a', 'aaaaaaaa-0000-0000-0000-000000000001',
        '11111111-1111-1111-1111-111111111111', 'Dr. Owner', 'ownerDentist', 'A-12345', '+919000000001');

insert into public.clinic_members (id, clinic_id, user_id, display_name, role, phone)
values ('aaaaaaaa-0000-0000-0000-00000000000b', 'aaaaaaaa-0000-0000-0000-000000000001',
        '33333333-3333-3333-3333-333333333333', 'Dr. Associate', 'associateDentist', '+919000000003');

do $$
begin
  if public.mint_patient_number('aaaaaaaa-0000-0000-0000-000000000001') <> 'P-00001' then
    raise exception 'first patient number should be P-00001';
  end if;
  if public.mint_patient_number('aaaaaaaa-0000-0000-0000-000000000001') <> 'P-00002' then
    raise exception 'second patient number should be P-00002';
  end if;
end
$$;

insert into public.patients (id, clinic_id, patient_number, first_name, phone, date_of_birth)
values ('aaaaaaaa-0000-0000-0000-0000000000f1', 'aaaaaaaa-0000-0000-0000-000000000001', 'P-00001', 'Asha', '+919111111111', '1990-05-01');

insert into public.catalog_items (id, clinic_id, code, name, layman_name, category, treatment_area,
                                  default_fee_paise, fee_min_paise, fee_max_paise, sac_hsn_code)
values ('aaaaaaaa-0000-0000-0000-0000000000c1', 'aaaaaaaa-0000-0000-0000-000000000001', 'RCT-MOL',
        'Root canal treatment, molar', 'Root canal', 'endodontic', 'tooth', 600000, 400000, 900000, '999312');

insert into public.procedures (id, clinic_id, patient_id, catalog_item_id, code, name, tooth, surfaces,
                               treatment_area, status, provider_id, fee_paise)
values ('aaaaaaaa-0000-0000-0000-0000000000d1', 'aaaaaaaa-0000-0000-0000-000000000001',
        'aaaaaaaa-0000-0000-0000-0000000000f1', 'aaaaaaaa-0000-0000-0000-0000000000c1', 'RCT-MOL',
        'Root canal treatment, molar', '36', 'MOD', 'tooth', 'planned', 'aaaaaaaa-0000-0000-0000-00000000000a', 600000);

update public.procedures set status = 'completed', completed_at = now()
where id = 'aaaaaaaa-0000-0000-0000-0000000000d1';

-- Supernumerary tooth key is accepted; a bad key is rejected.
insert into public.tooth_state_records (id, clinic_id, patient_id, tooth, state, effective_from, source, recorded_by)
values (gen_random_uuid(), 'aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-0000000000f1',
        '11+1', 'supernumerary', now(), 'clinician', 'aaaaaaaa-0000-0000-0000-00000000000a');

do $$
begin
  insert into public.tooth_state_records (id, clinic_id, patient_id, tooth, state, effective_from, source, recorded_by)
  values (gen_random_uuid(), 'aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-0000000000f1',
          '99', 'present', now(), 'clinician', 'aaaaaaaa-0000-0000-0000-00000000000a');
  raise exception 'tooth key 99 should have been rejected';
exception when check_violation then null;
end
$$;

do $$
begin
  insert into public.procedures (id, clinic_id, patient_id, catalog_item_id, code, name, teeth,
                                 treatment_area, provider_id)
  values (gen_random_uuid(), 'aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-0000000000f1',
          'aaaaaaaa-0000-0000-0000-0000000000c1', 'X', 'x', '["11", "xx"]'::jsonb, 'toothRange',
          'aaaaaaaa-0000-0000-0000-00000000000a');
  raise exception 'teeth array with a bad key should have been rejected';
exception when check_violation then null;
end
$$;

do $$
begin
  insert into public.findings (id, clinic_id, patient_id, description, recorded_at, recorded_by, status)
  values (gen_random_uuid(), 'aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-0000000000f1',
          'bad status', now(), 'aaaaaaaa-0000-0000-0000-00000000000a', 'bogus');
  raise exception 'unknown enum name should have been rejected';
exception when check_violation then null;
end
$$;

-- Invoice numbering: DRAFT- numbers are replaced when the invoice leaves draft, per clinic per FY.
-- Issued invoices must name a registered dentist (frozen at issue, DCI Code 3.4.1).
insert into public.invoices (id, clinic_id, patient_id, number, document_type, status, issued_at, issued_by)
values ('aaaaaaaa-0000-0000-0000-0000000000e1', 'aaaaaaaa-0000-0000-0000-000000000001',
        'aaaaaaaa-0000-0000-0000-0000000000f1', 'DRAFT-0001', 'receipt', 'draft',
        '2026-10-18 10:00+05:30', 'aaaaaaaa-0000-0000-0000-00000000000a');

do $$
begin
  update public.invoices set status = 'issued' where id = 'aaaaaaaa-0000-0000-0000-0000000000e1';
  raise exception 'issuing without a registered dentist should have been rejected';
exception when check_violation then null;
end
$$;

update public.invoices
   set status = 'issued',
       dentist_id = 'aaaaaaaa-0000-0000-0000-00000000000a',
       dentist_name = 'Dr. Owner',
       dentist_registration_number = 'A-12345'
 where id = 'aaaaaaaa-0000-0000-0000-0000000000e1';

insert into public.invoices (id, clinic_id, patient_id, number, document_type, status, issued_at, issued_by,
                             dentist_id, dentist_name, dentist_registration_number)
values ('aaaaaaaa-0000-0000-0000-0000000000e2', 'aaaaaaaa-0000-0000-0000-000000000001',
        'aaaaaaaa-0000-0000-0000-0000000000f1', 'DRAFT-0002', 'receipt', 'issued',
        '2027-03-31 23:00+05:30', 'aaaaaaaa-0000-0000-0000-00000000000a',
        'aaaaaaaa-0000-0000-0000-00000000000a', 'Dr. Owner', 'A-12345');

insert into public.invoices (id, clinic_id, patient_id, number, document_type, status, issued_at, issued_by,
                             dentist_id, dentist_name, dentist_registration_number)
values ('aaaaaaaa-0000-0000-0000-0000000000e3', 'aaaaaaaa-0000-0000-0000-000000000001',
        'aaaaaaaa-0000-0000-0000-0000000000f1', 'DRAFT-0003', 'receipt', 'issued',
        '2027-04-01 00:30+05:30', 'aaaaaaaa-0000-0000-0000-00000000000a',
        'aaaaaaaa-0000-0000-0000-00000000000a', 'Dr. Owner', 'A-12345');

-- The phone never learns the minted number until it is written back, so a payment replays the
-- full row with the DRAFT- number: the minted number must survive and the counter must not advance.
update public.invoices
   set status = 'paid', number = 'DRAFT-0001', amount_paid_paise = 50000
 where id = 'aaaaaaaa-0000-0000-0000-0000000000e1';

do $$
declare
  n1 text; n2 text; n3 text; st text;
begin
  select number, status into n1, st from public.invoices where id = 'aaaaaaaa-0000-0000-0000-0000000000e1';
  if st <> 'paid' then raise exception 'replayed payment should have moved the status to paid, got %', st; end if;
  if n1 <> 'INV/2026-27/0001' then
    raise exception 'a replayed DRAFT- number must not renumber a minted invoice, got %', n1;
  end if;
  select number into n1 from public.invoices where id = 'aaaaaaaa-0000-0000-0000-0000000000e1';
  select number into n2 from public.invoices where id = 'aaaaaaaa-0000-0000-0000-0000000000e2';
  select number into n3 from public.invoices where id = 'aaaaaaaa-0000-0000-0000-0000000000e3';
  if n1 <> 'INV/2026-27/0001' then raise exception 'expected INV/2026-27/0001, got %', n1; end if;
  if n2 <> 'INV/2026-27/0002' then raise exception 'expected INV/2026-27/0002, got %', n2; end if;
  if n3 <> 'INV/2027-28/0001' then raise exception 'expected INV/2027-28/0001, got %', n3; end if;
  if public.mint_invoice_number('aaaaaaaa-0000-0000-0000-000000000001', '2026-12-01 00:00+05:30') <> 'INV/2026-27/0003' then
    raise exception 'mint_invoice_number should continue the FY sequence';
  end if;
end
$$;

do $$
begin
  insert into public.invoices (id, clinic_id, patient_id, number, document_type, status, issued_at, issued_by,
                               dentist_id, dentist_name, dentist_registration_number)
  values (gen_random_uuid(), 'aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-0000000000f1',
          'DRAFT-0009', 'receipt', 'voided', now(), 'aaaaaaaa-0000-0000-0000-00000000000a',
          'aaaaaaaa-0000-0000-0000-00000000000a', 'Dr. Owner', 'A-12345');
  raise exception 'voided invoice without void_reason should have been rejected';
exception when check_violation then null;
end
$$;

-- Deleting a clinical row through the API is impossible: no policy, zero rows affected.
do $$
declare
  n integer;
begin
  delete from public.procedures where id = 'aaaaaaaa-0000-0000-0000-0000000000d1';
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'delete on procedures should affect 0 rows under RLS, got %', n; end if;
end
$$;

-- Storage: member can write under own clinic prefix, not under another.
insert into storage.objects (bucket_id, name, owner)
values ('clinic-media', 'aaaaaaaa-0000-0000-0000-000000000001/aaaaaaaa-0000-0000-0000-0000000000f1/photo.jpg',
        '11111111-1111-1111-1111-111111111111');

do $$
begin
  insert into storage.objects (bucket_id, name, owner)
  values ('clinic-media', 'bbbbbbbb-0000-0000-0000-000000000001/x/photo.jpg', '11111111-1111-1111-1111-111111111111');
  raise exception 'writing under another clinic prefix should have been rejected';
exception when insufficient_privilege then null;
end
$$;

commit;

-- updated_at touch and audit trail ----------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';

update public.patients set notes = 'updated' where id = 'aaaaaaaa-0000-0000-0000-0000000000f1';

do $$
declare
  r record;
  n integer;
begin
  select created_at, updated_at into r from public.patients where id = 'aaaaaaaa-0000-0000-0000-0000000000f1';
  if r.updated_at <= r.created_at then raise exception 'updated_at was not touched'; end if;

  select count(*) into n from public.audit_events
  where entity_type = 'patients' and entity_id = 'aaaaaaaa-0000-0000-0000-0000000000f1'
    and action = 'create' and actor_id = '11111111-1111-1111-1111-111111111111' and device_id = 'phone-u1';
  if n <> 1 then raise exception 'expected one create audit row for the patient, got %', n; end if;

  select count(*) into n from public.audit_events
  where entity_type = 'procedures' and action = 'statusChange';
  if n <> 1 then raise exception 'expected one statusChange audit row for procedures, got %', n; end if;

  select count(*) into n from public.audit_events
  where entity_type = 'invoices' and action = 'statusChange'
    and before ->> 'number' = 'DRAFT-0001' and after ->> 'number' = 'INV/2026-27/0001';
  if n <> 1 then raise exception 'invoice number minting should be captured in the audit trail, got %', n; end if;

  select count(*) into n from public.audit_events
  where entity_type = 'clinics' and clinic_id = 'aaaaaaaa-0000-0000-0000-000000000001' and action = 'create';
  if n <> 1 then raise exception 'clinic insert should be audited under its own id, got %', n; end if;
end
$$;
commit;

-- Clinic B by user 2: isolation -------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';

insert into public.clinics (id, name, city, state_code, pincode, phone)
values ('bbbbbbbb-0000-0000-0000-000000000001', 'Pearl Dental', 'Pune', '27', '411001', '+912000000001');

insert into public.clinic_members (id, clinic_id, user_id, display_name, role, phone)
values ('bbbbbbbb-0000-0000-0000-00000000000a', 'bbbbbbbb-0000-0000-0000-000000000001',
        '22222222-2222-2222-2222-222222222222', 'Dr. Two', 'ownerDentist', '+919000000002');

-- Cannot bootstrap into clinic A, which already has members.
do $$
begin
  insert into public.clinic_members (id, clinic_id, user_id, display_name, role, phone)
  values (gen_random_uuid(), 'aaaaaaaa-0000-0000-0000-000000000001',
          '22222222-2222-2222-2222-222222222222', 'Intruder', 'ownerDentist', '+919000000002');
  raise exception 'bootstrapping into a populated clinic should have been rejected';
exception when insufficient_privilege then null;
end
$$;

do $$
declare
  n integer;
begin
  select count(*) into n from public.patients;
  if n <> 0 then raise exception 'user 2 must not see clinic A patients, saw %', n; end if;
  select count(*) into n from public.clinics;
  if n <> 1 then raise exception 'user 2 must see exactly one clinic, saw %', n; end if;
  select count(*) into n from public.invoices;
  if n <> 0 then raise exception 'user 2 must not see clinic A invoices, saw %', n; end if;
  select count(*) into n from public.audit_events where clinic_id = 'aaaaaaaa-0000-0000-0000-000000000001';
  if n <> 0 then raise exception 'user 2 must not see clinic A audit rows, saw %', n; end if;
  select count(*) into n from storage.objects;
  if n <> 0 then raise exception 'user 2 must not see clinic A media, saw %', n; end if;
end
$$;

do $$
begin
  insert into public.patients (id, clinic_id, patient_number, first_name, phone)
  values (gen_random_uuid(), 'aaaaaaaa-0000-0000-0000-000000000001', 'P-00099', 'Mallory', '+919999999999');
  raise exception 'inserting into another clinic should have been rejected';
exception when insufficient_privilege then null;
end
$$;

do $$
begin
  perform public.mint_invoice_number('aaaaaaaa-0000-0000-0000-000000000001');
  raise exception 'minting for another clinic should have been rejected';
exception when insufficient_privilege then null;
end
$$;
commit;

-- Associate dentist in clinic A: clinical yes, financial no ------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';

insert into public.findings (id, clinic_id, patient_id, tooth, surfaces, description, recorded_at, recorded_by, icdas)
values (gen_random_uuid(), 'aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-0000000000f1',
        '16', 'O', 'Occlusal caries', now(), 'aaaaaaaa-0000-0000-0000-00000000000b', 'distinctCavity');

do $$
declare
  n integer;
begin
  select count(*) into n from public.patients;
  if n <> 1 then raise exception 'associate must see clinic A patients, saw %', n; end if;
  select count(*) into n from public.invoices;
  if n <> 0 then raise exception 'associate must not see invoices, saw %', n; end if;
  select count(*) into n from public.ledger_entries;
  if n <> 0 then raise exception 'associate must not see ledger, saw %', n; end if;
end
$$;

do $$
begin
  insert into public.payments (id, clinic_id, patient_id, amount_paise, method, received_at, received_by)
  values (gen_random_uuid(), 'aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-0000000000f1',
          100000, 'upi', now(), 'aaaaaaaa-0000-0000-0000-00000000000b');
  raise exception 'associate must not record payments';
exception when insufficient_privilege then null;
end
$$;

do $$
begin
  update public.audit_events set reason = 'tamper' where entity_type = 'patients';
  if found then raise exception 'audit_events must not be updatable'; end if;
end
$$;
commit;

-- Superuser / service role: hard delete still blocked by trigger ----------------------------
do $$
begin
  delete from public.procedures where id = 'aaaaaaaa-0000-0000-0000-0000000000d1';
  raise exception 'hard delete of a procedure should have raised';
exception when restrict_violation then null;
end
$$;

do $$
begin
  delete from public.audit_events where entity_type = 'patients';
  raise exception 'hard delete of audit rows should have raised';
exception when restrict_violation then null;
end
$$;

-- Platform-wide catalogue rows (clinic_id null) can be written by the service role and are not audited.
do $$
declare
  n integer;
begin
  insert into public.catalog_items (id, clinic_id, code, name, layman_name, category, treatment_area,
                                    default_fee_paise, fee_min_paise, fee_max_paise, sac_hsn_code)
  values ('99999999-0000-0000-0000-0000000000c1', null, 'CONS-NEW', 'New patient consultation', 'Check-up',
          'diagnostic', 'mouth', 50000, 30000, 100000, '999312');
  select count(*) into n from public.audit_events where entity_id = '99999999-0000-0000-0000-0000000000c1';
  if n <> 0 then raise exception 'platform catalogue rows must not produce audit rows, got %', n; end if;
end
$$;

-- Members of any clinic read platform rows; nobody writes them through the API.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
do $$
declare
  n integer;
begin
  select count(*) into n from public.catalog_items where clinic_id is null;
  if n <> 1 then raise exception 'member should read one platform catalogue row, saw %', n; end if;
  update public.catalog_items set name = 'tamper' where clinic_id is null;
  if found then raise exception 'platform catalogue rows must not be updatable through the API'; end if;
end
$$;
commit;

-- Every tenant table has an index whose first column is clinic_id.
do $$
declare
  missing text;
begin
  select string_agg(c.relname, ', ') into missing
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  join pg_attribute a on a.attrelid = c.oid and a.attname = 'clinic_id' and not a.attisdropped
  where n.nspname = 'public' and c.relkind = 'r'
    and not exists (
      select 1 from pg_index i
      where i.indrelid = c.oid and i.indkey[0] = a.attnum
    );
  if missing is not null then raise exception 'tables without a leading clinic_id index: %', missing; end if;
end
$$;

-- Every public table has RLS enabled.
do $$
declare
  missing text;
begin
  select string_agg(c.relname, ', ') into missing
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity;
  if missing is not null then raise exception 'tables without RLS: %', missing; end if;
end
$$;

-- No DELETE policy on clinical/financial tables.
do $$
declare
  offenders text;
begin
  select string_agg(tablename || '.' || policyname, ', ') into offenders
  from pg_policies
  where schemaname = 'public' and cmd = 'DELETE'
    and tablename in ('procedures', 'findings', 'tooth_state_records', 'consent_records', 'data_consents',
                      'clinical_notes', 'perio_exams', 'prescriptions', 'invoices', 'payments',
                      'ledger_entries', 'audit_events', 'message_logs');
  if offenders is not null then raise exception 'unexpected delete policies: %', offenders; end if;
end
$$;

select 'smoke ok' as result;
