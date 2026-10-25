-- smoke_sync_whatsapp.sql
-- Behavioural checks for 0008/0009 (sync columns, devices, WhatsApp config + queue + webhook RPCs).
-- Runs after smoke.sql and reuses its fixtures: clinic A (owner user 1, associate user 3, patient Asha),
-- clinic B (owner user 2). The Vault and pg_net shims from local_supabase_stub.sql stand in for the
-- managed extensions, so the whole path (token in Vault, claim, result, status, reply) runs locally.

\set ON_ERROR_STOP on
\set QUIET on

-- Server-owned updated_at, devices --------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
set local app.device_id = 'aaaaaaaa-0000-0000-0000-0000000000d1';

-- A phone that sends its own updated_at is overruled by the server clock.
insert into public.patients (id, clinic_id, patient_number, first_name, phone, created_at, updated_at)
values ('aaaaaaaa-0000-0000-0000-0000000000f2', 'aaaaaaaa-0000-0000-0000-000000000001', 'P-00002', 'Ravi',
        '+919222222222', '2000-01-01 00:00+05:30', '2000-01-01 00:00+05:30');

do $$
declare
  v timestamptz;
begin
  select updated_at into v from public.patients where id = 'aaaaaaaa-0000-0000-0000-0000000000f2';
  if v <> now() then raise exception 'updated_at must be server-assigned on insert, got %', v; end if;
end
$$;

insert into public.devices (id, clinic_id, platform, app_version, is_primary)
values ('aaaaaaaa-0000-0000-0000-0000000000d1', 'aaaaaaaa-0000-0000-0000-000000000001', 'android', '0.1.0', true);

do $$
begin
  insert into public.devices (id, clinic_id, platform, app_version, is_primary)
  values (gen_random_uuid(), 'aaaaaaaa-0000-0000-0000-000000000001', 'ios', '0.1.0', true);
  raise exception 'a clinic must have at most one primary device';
exception when unique_violation then null;
end
$$;

do $$
begin
  insert into public.devices (id, clinic_id, user_id, platform)
  values (gen_random_uuid(), 'aaaaaaaa-0000-0000-0000-000000000001', '33333333-3333-3333-3333-333333333333', 'ios');
  raise exception 'registering a device for another user should have been rejected';
exception when insufficient_privilege then null;
end
$$;

do $$
declare
  v uuid;
begin
  select user_id into v from public.devices where id = 'aaaaaaaa-0000-0000-0000-0000000000d1';
  if v <> '11111111-1111-1111-1111-111111111111' then raise exception 'devices.user_id should default to the caller'; end if;
end
$$;
commit;

-- WhatsApp config: owner only, token in Vault ------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
do $$
begin
  perform public.set_whatsapp_config('aaaaaaaa-0000-0000-0000-000000000001', '109876543210987', '123456789012345',
                                     '+91 40 0000 0001', 'EAAG-test-token-0123456789abcdefghij', 'verify-me-please-123');
  raise exception 'an associate must not configure WhatsApp';
exception when insufficient_privilege then null;
end
$$;
do $$
declare
  n integer;
begin
  select count(*) into n from public.clinic_whatsapp_configs;
  if n <> 0 then raise exception 'associate must not read the WhatsApp config, saw %', n; end if;
end
$$;
commit;

begin;
set local role authenticated;
set local request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
set local app.device_id = 'aaaaaaaa-0000-0000-0000-0000000000d1';

do $$ begin
  perform public.set_whatsapp_config('aaaaaaaa-0000-0000-0000-000000000001', '109876543210987', '123456789012345',
                                     '+91 40 0000 0001', 'EAAG-test-token-0123456789abcdefghij', 'verify-me-please-123');
end $$;

do $$
declare
  r record;
  s jsonb;
begin
  select * into r from public.clinic_whatsapp_configs where clinic_id = 'aaaaaaaa-0000-0000-0000-000000000001';
  if r.access_token_secret_id is null then raise exception 'config must point at a Vault secret'; end if;
  if r.phone_number_id <> '109876543210987' or not r.is_enabled then raise exception 'config not stored'; end if;
  if to_jsonb(r)::text like '%EAAG-test-token%' then raise exception 'the access token must never be in the table'; end if;

  s := public.get_whatsapp_status('aaaaaaaa-0000-0000-0000-000000000001');
  if not (s ->> 'configured')::boolean or not (s ->> 'enabled')::boolean then
    raise exception 'status should be configured + enabled, got %', s;
  end if;
  if s::text like '%EAAG-test-token%' then raise exception 'status must not leak the token'; end if;
end
$$;

-- No direct writes, even for the owner.
do $$
begin
  insert into public.clinic_whatsapp_configs (clinic_id, phone_number_id, waba_id, access_token_secret_id, verify_token)
  values ('aaaaaaaa-0000-0000-0000-000000000001', '1', '1', gen_random_uuid(), 'verify-me-please-123');
  raise exception 'direct insert into clinic_whatsapp_configs should have been rejected';
exception when insufficient_privilege or unique_violation or check_violation then null;
end
$$;
do $$
begin
  update public.clinic_whatsapp_configs set is_enabled = false where clinic_id = 'aaaaaaaa-0000-0000-0000-000000000001';
  if found then raise exception 'direct update of clinic_whatsapp_configs must affect zero rows'; end if;
end
$$;

-- Re-binding rotates the token in place: same secret id, new value (checked below as superuser).
do $$ begin
  perform public.set_whatsapp_config('aaaaaaaa-0000-0000-0000-000000000001', '109876543210987', '123456789012345',
                                     '+91 40 0000 0001', 'EAAG-rotated-token-0123456789abcdefghij', 'verify-me-please-123');
  perform public.set_whatsapp_enabled('aaaaaaaa-0000-0000-0000-000000000001', false);
end $$;
do $$
begin
  if (public.get_whatsapp_status('aaaaaaaa-0000-0000-0000-000000000001') ->> 'enabled')::boolean then
    raise exception 'set_whatsapp_enabled(false) should pause sending';
  end if;
end
$$;
do $$ begin perform public.set_whatsapp_enabled('aaaaaaaa-0000-0000-0000-000000000001', true); end $$;

-- Queue fixtures: one due cloud_api row, one deep-link row (never queued), one not yet due, one for retries.
insert into public.message_logs (id, clinic_id, patient_id, channel, category, template_code, to_phone, variables,
                                 rendered_preview, status, provider)
values
  ('aaaaaaaa-0000-0000-0000-0000000000a1', 'aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-0000000000f1',
   'whatsapp', 'utility', 'APPT_REMINDER_24H', '+919111111111',
   '{"patient_name":"Asha","clinic_name":"Smile Dental","appointment_date":"Tue 27 Oct","appointment_time":"10:00 am","doctor_name":"Owner","clinic_phone":"+914000000001","_provider":"cloud_api","_opt_in_reason":"transactional"}'::jsonb,
   'Reminder: Asha ...', 'queued', 'deeplink'),
  ('aaaaaaaa-0000-0000-0000-0000000000a2', 'aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-0000000000f1',
   'whatsapp', 'utility', 'APPT_CONFIRM', '+919111111111', '{"_provider":"deeplink"}'::jsonb, 'Hi Asha ...', 'sent', 'cloud_api');

-- variables._provider (stamped by the phone) decides the provider column.
do $$
declare
  p1 text; p2 text;
begin
  select provider into p1 from public.message_logs where id = 'aaaaaaaa-0000-0000-0000-0000000000a1';
  select provider into p2 from public.message_logs where id = 'aaaaaaaa-0000-0000-0000-0000000000a2';
  if p1 <> 'cloud_api' or p2 <> 'deeplink' then raise exception 'provider should follow variables._provider, got % / %', p1, p2; end if;
end
$$;
insert into public.message_logs (id, clinic_id, patient_id, channel, category, template_code, to_phone, variables,
                                 rendered_preview, status, provider, next_attempt_at)
values
  ('aaaaaaaa-0000-0000-0000-0000000000a3', 'aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-0000000000f1',
   'whatsapp', 'utility', 'RECALL_DUE', '+919111111111', '{}'::jsonb, 'Hi Asha ...', 'queued', 'cloud_api',
   now() + interval '1 hour'),
  ('aaaaaaaa-0000-0000-0000-0000000000a4', 'aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-0000000000f2',
   'whatsapp', 'utility', 'WELCOME_NEW_PATIENT', '+919222222222', '{}'::jsonb, 'Welcome ...', 'queued', 'cloud_api',
   null);

-- Appointment tomorrow for Asha, to be confirmed by her reply.
insert into public.appointments (id, clinic_id, patient_id, provider_id, starts_at, ends_at, status, reason)
values ('aaaaaaaa-0000-0000-0000-0000000000b1', 'aaaaaaaa-0000-0000-0000-000000000001',
        'aaaaaaaa-0000-0000-0000-0000000000f1', 'aaaaaaaa-0000-0000-0000-00000000000a',
        now() + interval '1 day', now() + interval '1 day 30 minutes', 'scheduled', 'RCT sitting 2');

-- Members cannot touch the sender RPCs or the queue view.
do $$
begin
  perform * from public.claim_whatsapp_batch(10);
  raise exception 'authenticated must not claim the send queue';
exception when insufficient_privilege then null;
end
$$;
do $$
begin
  perform public.apply_whatsapp_status('wamid.x', 'delivered');
  raise exception 'authenticated must not apply webhook statuses';
exception when insufficient_privilege then null;
end
$$;
do $$
begin
  perform * from app.whatsapp_send_queue;
  raise exception 'authenticated must not read the send queue';
exception when insufficient_privilege then null;
end
$$;
commit;

-- Another clinic sees nothing of it ----------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
do $$
declare
  n integer;
begin
  select count(*) into n from public.clinic_whatsapp_configs;
  if n <> 0 then raise exception 'user 2 must not see clinic A WhatsApp config, saw %', n; end if;
  select count(*) into n from public.devices;
  if n <> 0 then raise exception 'user 2 must not see clinic A devices, saw %', n; end if;
end
$$;
do $$
begin
  perform public.get_whatsapp_status('aaaaaaaa-0000-0000-0000-000000000001');
  raise exception 'user 2 must not read clinic A WhatsApp status';
exception when insufficient_privilege then null;
end
$$;
commit;

-- Superuser: Vault holds the rotated token; deployment settings for the cron invoker ------------
do $$
declare
  v text;
  n integer;
begin
  select s.decrypted_secret into v
  from vault.decrypted_secrets as s
  join public.clinic_whatsapp_configs as c on c.access_token_secret_id = s.id
  where c.clinic_id = 'aaaaaaaa-0000-0000-0000-000000000001';
  if v <> 'EAAG-rotated-token-0123456789abcdefghij' then raise exception 'Vault should hold the rotated token, got %', v; end if;
  select count(*) into n from vault.secrets where name like 'whatsapp_access_token:%';
  if n <> 1 then raise exception 'rotation must reuse the secret row, found %', n; end if;
  select count(*) into n from public.audit_events
  where entity_type = 'ClinicWhatsappConfig' and action = 'settingsChange'
    and device_id = 'aaaaaaaa-0000-0000-0000-0000000000d1';
  if n < 3 then raise exception 'config changes must be audited (without the token), got %', n; end if;
  if exists (select 1 from public.audit_events where entity_type = 'ClinicWhatsappConfig' and after::text like '%EAAG-%') then
    raise exception 'audit rows must not contain the access token';
  end if;
end
$$;

insert into app.runtime_config (key, value) values ('functions_base_url', 'https://abcdefghij.supabase.co/functions/v1/');
do $$ begin perform vault.create_secret('service-role-key-for-tests', 'ampdent_cron_bearer', 'bearer accepted by whatsapp-send'); end $$;

-- Service role: cron invoker, claim, results, webhook statuses, inbound reply -------------------
begin;
set local role service_role;

do $$
declare
  rid bigint;
begin
  rid := app.invoke_whatsapp_send();
  if rid is null then raise exception 'invoke_whatsapp_send should queue a request when rows are due'; end if;
end
$$;

do $$
declare
  n integer;
  r record;
begin
  select count(*) into n from app.whatsapp_send_queue;
  if n <> 2 then raise exception 'two rows should be due (a1, a4), saw %', n; end if;

  select count(*) as n, bool_and(access_token = 'EAAG-rotated-token-0123456789abcdefghij') as tok,
         bool_and(phone_number_id = '109876543210987') as pn, bool_and(patient_language = 'en') as lang,
         bool_and(attempts = 1) as att
    into r
  from public.claim_whatsapp_batch(10);
  if r.n <> 2 or not r.tok or not r.pn or not r.lang or not r.att then
    raise exception 'claim should return both due rows with the decrypted token: %', r;
  end if;

  select count(*) into n from public.claim_whatsapp_batch(10);
  if n <> 0 then raise exception 'a second claim must not re-deliver claimed rows, saw %', n; end if;

  select status, attempts, claimed_at, next_attempt_at into r
  from public.message_logs where id = 'aaaaaaaa-0000-0000-0000-0000000000a1';
  if r.status <> 'queued' or r.attempts <> 1 or r.claimed_at is null or r.next_attempt_at <= now() then
    raise exception 'claimed row should stay queued with a lease, got %', r;
  end if;

  if not public.record_whatsapp_result('aaaaaaaa-0000-0000-0000-0000000000a1', 'sent', 'wamid.TEST1') then
    raise exception 'record_whatsapp_result(sent) should find the claimed row';
  end if;
  if public.record_whatsapp_result('aaaaaaaa-0000-0000-0000-0000000000a1', 'sent', 'wamid.TEST1') then
    raise exception 'record_whatsapp_result must be a no-op once the row is resolved';
  end if;
  select status, sent_at, provider_message_id into r from public.message_logs where id = 'aaaaaaaa-0000-0000-0000-0000000000a1';
  if r.status <> 'sent' or r.sent_at is null or r.provider_message_id <> 'wamid.TEST1' then
    raise exception 'sent row not recorded: %', r;
  end if;

  -- Retry with backoff, then not due.
  perform public.record_whatsapp_result('aaaaaaaa-0000-0000-0000-0000000000a4', 'retry', null, '(#130429) Rate limit hit');
  select status, next_attempt_at, last_error into r from public.message_logs where id = 'aaaaaaaa-0000-0000-0000-0000000000a4';
  if r.status <> 'queued' or r.next_attempt_at <= now() or r.last_error not like '%130429%' then
    raise exception 'retry should re-queue with a future next_attempt_at: %', r;
  end if;
  select count(*) into n from app.whatsapp_send_queue;
  if n <> 0 then raise exception 'a backed-off row must not be due, saw %', n; end if;

  -- Webhook statuses move forward only.
  if not public.apply_whatsapp_status('wamid.TEST1', 'delivered', now()) then raise exception 'status: known id'; end if;
  perform public.apply_whatsapp_status('wamid.TEST1', 'sent', now());
  select status, delivered_at into r from public.message_logs where id = 'aaaaaaaa-0000-0000-0000-0000000000a1';
  if r.status <> 'delivered' or r.delivered_at is null then raise exception 'late sent must not regress delivered: %', r; end if;
  perform public.apply_whatsapp_status('wamid.TEST1', 'read', now(), null, '{"conversation":{"id":"c1"}}'::jsonb);
  perform public.apply_whatsapp_status('wamid.TEST1', 'failed', now(), 'late failure');
  select status, provider_payload into r from public.message_logs where id = 'aaaaaaaa-0000-0000-0000-0000000000a1';
  if r.status <> 'read' or r.provider_payload -> 'conversation' is null then
    raise exception 'read is terminal and the payload must be kept: %', r;
  end if;
  if public.apply_whatsapp_status('wamid.UNKNOWN', 'delivered', now()) then raise exception 'unknown ids return false'; end if;

  -- Inbound reply confirms the next scheduled appointment of the number's patient.
  if public.confirm_appointment_from_reply('919111111111', '2', '109876543210987') is not null then
    raise exception 'a reply other than 1/yes must not confirm';
  end if;
  if public.confirm_appointment_from_reply('919111111111', '1', '000000000000000') is not null then
    raise exception 'an unknown phone_number_id must not confirm anything';
  end if;
  if public.confirm_appointment_from_reply('919111111111', ' 1 ', '109876543210987', 'wamid.TEST1')
     <> 'aaaaaaaa-0000-0000-0000-0000000000b1' then
    raise exception 'reply 1 should confirm the appointment';
  end if;
  select status, confirmed_at into r from public.appointments where id = 'aaaaaaaa-0000-0000-0000-0000000000b1';
  if r.status <> 'confirmed' or r.confirmed_at is null then raise exception 'appointment not confirmed: %', r; end if;
  if public.confirm_appointment_from_reply('+91 91111 11111', 'yes', '109876543210987') is not null then
    raise exception 'nothing left to confirm';
  end if;

  if not public.whatsapp_verify_token_matches('verify-me-please-123') then raise exception 'verify token should match'; end if;
  if public.whatsapp_verify_token_matches('nope') then raise exception 'wrong verify token must not match'; end if;
end
$$;
commit;

-- Superuser: the cron request shape, the audit trail of the webhook, lease recovery -------------
do $$
declare
  r record;
  n integer;
begin
  select url, headers into r from net._requests order by id desc limit 1;
  if r.url <> 'https://abcdefghij.supabase.co/functions/v1/whatsapp-send' then raise exception 'bad function url %', r.url; end if;
  if r.headers ->> 'Authorization' <> 'Bearer service-role-key-for-tests' then raise exception 'bad bearer %', r.headers; end if;

  select count(*) into n from public.audit_events
  where entity_type = 'appointments' and entity_id = 'aaaaaaaa-0000-0000-0000-0000000000b1'
    and action = 'statusChange' and device_id = 'whatsapp-webhook';
  if n <> 1 then raise exception 'webhook confirmation should be audited as whatsapp-webhook, got %', n; end if;

  -- A worker that died mid-send leaves a claimed row; once its lease expires it is claimable again.
  update public.message_logs set next_attempt_at = now() - interval '1 second'
  where id = 'aaaaaaaa-0000-0000-0000-0000000000a4';
  insert into public.message_logs (id, clinic_id, patient_id, channel, category, template_code, to_phone, variables,
                                   rendered_preview, status, provider, attempts, claimed_at, next_attempt_at)
  values ('aaaaaaaa-0000-0000-0000-0000000000a5', 'aaaaaaaa-0000-0000-0000-000000000001',
          'aaaaaaaa-0000-0000-0000-0000000000f1', 'whatsapp', 'utility', 'RECALL_DUE', '+919111111111', '{}'::jsonb,
          'Hi ...', 'queued', 'cloud_api', 1, now() - interval '11 minutes', now() - interval '1 minute');
end
$$;

begin;
set local role service_role;
do $$
declare
  n integer;
  r record;
begin
  select count(*) into n from public.claim_whatsapp_batch(10);
  if n <> 2 then raise exception 'the backed-off row and the expired lease should both be claimable, saw %', n; end if;
  select attempts into r from public.message_logs where id = 'aaaaaaaa-0000-0000-0000-0000000000a5';
  if r.attempts <> 2 then raise exception 'recovered lease should count as a new attempt, got %', r.attempts; end if;
  perform public.record_whatsapp_result('aaaaaaaa-0000-0000-0000-0000000000a4', 'failed', null, '(#131026) Message undeliverable');
  perform public.record_whatsapp_result('aaaaaaaa-0000-0000-0000-0000000000a5', 'sent', 'wamid.TEST5');
  select status, error into r from public.message_logs where id = 'aaaaaaaa-0000-0000-0000-0000000000a4';
  if r.status <> 'failed' or r.error not like '%131026%' then raise exception 'permanent failure not recorded: %', r; end if;
end
$$;
commit;

-- Replays from a phone cannot regress server-owned state ---------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';

-- The phone still holds a1 as 'queued' with no provider id and upserts the whole row.
update public.message_logs
   set status = 'queued', provider_message_id = null, sent_at = null, delivered_at = null, error = null
 where id = 'aaaaaaaa-0000-0000-0000-0000000000a1';
-- It may cancel a row that has not been sent yet (a3 is queued, not yet due).
update public.message_logs set status = 'cancelled' where id = 'aaaaaaaa-0000-0000-0000-0000000000a3';
-- It cannot cancel a row that was already sent.
update public.message_logs set status = 'cancelled' where id = 'aaaaaaaa-0000-0000-0000-0000000000a5';
-- Deep-link rows stay fully phone-owned.
update public.message_logs set status = 'delivered' where id = 'aaaaaaaa-0000-0000-0000-0000000000a2';
-- The appointment confirmed by WhatsApp is replayed as scheduled with a new note.
update public.appointments set status = 'scheduled', notes = 'replayed from phone'
 where id = 'aaaaaaaa-0000-0000-0000-0000000000b1';

do $$
declare
  r record;
begin
  select status, provider_message_id, delivered_at into r from public.message_logs where id = 'aaaaaaaa-0000-0000-0000-0000000000a1';
  if r.status <> 'read' or r.provider_message_id <> 'wamid.TEST1' or r.delivered_at is null then
    raise exception 'a replayed queued row must not regress delivery state: %', r;
  end if;
  select status into r from public.message_logs where id = 'aaaaaaaa-0000-0000-0000-0000000000a3';
  if r.status <> 'cancelled' then raise exception 'a queued row can be cancelled by the clinic, got %', r.status; end if;
  select status into r from public.message_logs where id = 'aaaaaaaa-0000-0000-0000-0000000000a5';
  if r.status <> 'sent' then raise exception 'a sent row cannot be cancelled, got %', r.status; end if;
  select status into r from public.message_logs where id = 'aaaaaaaa-0000-0000-0000-0000000000a2';
  if r.status <> 'delivered' then raise exception 'deep-link rows are phone-owned, got %', r.status; end if;
  select status, notes, confirmed_at into r from public.appointments where id = 'aaaaaaaa-0000-0000-0000-0000000000b1';
  if r.status <> 'confirmed' or r.notes <> 'replayed from phone' or r.confirmed_at is null then
    raise exception 'confirmed must survive a scheduled replay while other columns update: %', r;
  end if;
end
$$;
commit;

-- Structure ---------------------------------------------------------------------------------
do $$
declare
  missing text;
begin
  -- (clinic_id, updated_at) pull index on every tenant table the client pulls (the WhatsApp config is
  -- keyed by clinic_id and read only through get_whatsapp_status()).
  select string_agg(c.relname, ', ') into missing
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  join pg_attribute a on a.attrelid = c.oid and a.attname = 'clinic_id' and not a.attisdropped
  join pg_attribute u on u.attrelid = c.oid and u.attname = 'updated_at' and not u.attisdropped
  where n.nspname = 'public' and c.relkind = 'r' and c.relname <> 'clinic_whatsapp_configs'
    and not exists (select 1 from pg_index i where i.indrelid = c.oid and i.indkey[0] = a.attnum and i.indkey[1] = u.attnum);
  if missing is not null then raise exception 'tables without a (clinic_id, updated_at) index: %', missing; end if;

  -- Every table with updated_at touches it on insert as well as update (tgtype bit 2 = insert, 16 = update).
  select string_agg(c.relname, ', ') into missing
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  join pg_attribute u on u.attrelid = c.oid and u.attname = 'updated_at' and not u.attisdropped
  where n.nspname = 'public' and c.relkind = 'r'
    and not exists (select 1 from pg_trigger t where t.tgrelid = c.oid and t.tgname = c.relname || '_touch_updated_at'
                    and (t.tgtype & 4) = 4 and (t.tgtype & 16) = 16);
  if missing is not null then raise exception 'tables whose touch trigger does not fire on insert: %', missing; end if;

  if not exists (select 1 from pg_attribute where attrelid = 'public.audit_events'::regclass and attname = 'updated_at') then
    raise exception 'audit_events must carry updated_at for pulls';
  end if;
  if exists (select 1 from pg_policies where schemaname = 'public'
             and tablename in ('clinic_whatsapp_configs', 'devices') and cmd = 'DELETE') then
    raise exception 'no delete policies expected on devices / clinic_whatsapp_configs';
  end if;
  if exists (select 1 from pg_policies where schemaname = 'public'
             and tablename = 'clinic_whatsapp_configs' and cmd in ('INSERT', 'UPDATE')) then
    raise exception 'clinic_whatsapp_configs must be written only through the RPCs';
  end if;
end
$$;

select 'smoke sync+whatsapp ok' as result;
