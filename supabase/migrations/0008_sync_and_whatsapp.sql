-- 0008_sync_and_whatsapp.sql
-- Server side of offline-first sync and WhatsApp Cloud API delivery.
--
-- Sync (docs/research/03-architecture-and-data.md, "Offline-first sync and conflict policy"):
--   1. updated_at is server-assigned on every tenant table. The touch trigger now fires BEFORE INSERT as
--      well as BEFORE UPDATE, so a phone's clock never leaks into the pull cursor. Pull queries are
--      `where clinic_id = $1 and updated_at > $cursor order by updated_at, id`; every tenant table gets an
--      index on (clinic_id, updated_at). audit_events gains updated_at so it can be pulled the same way.
--   2. public.devices: one row per installed app (device_id in the outbox and audit trail), with the
--      clinic's primary device flagged (one per clinic).
--
-- WhatsApp ("Integrations: WhatsApp"): the phone queues message_logs rows offline; the server sends them.
--   3. message_logs: provider ('deeplink' = sent from the phone via wa.me, 'cloud_api' = sent by the
--      whatsapp-send Edge Function), attempts, next_attempt_at, last_error, provider_payload, claimed_at.
--      A claim is claimed_at + a 10-minute lease on next_attempt_at while status stays 'queued': the Dart
--      MessageStatus enum (the contract) has no 'sending' member and a pulled row with an unknown status
--      would throw on every phone. The phone stamps the provider inside variables._provider (MessageLog has
--      no provider field); a trigger copies it into the column. For cloud_api rows the server owns delivery
--      state: a replayed upsert from a phone can only cancel a still-queued row, never regress a sent one.
--   4. public.clinic_whatsapp_configs: one Meta phone number per clinic. The permanent access token is
--      stored in Supabase Vault; the table holds only the vault secret id. Owners read the row; nobody
--      writes it directly: app.set_whatsapp_config() / app.set_whatsapp_enabled() are the only writers.
--   5. app.whatsapp_send_queue (view) + app.claim_whatsapp_batch() / app.record_whatsapp_result() for the
--      sender, app.apply_whatsapp_status() for delivery webhooks, app.confirm_appointment_from_reply() for
--      an inbound "1", app.whatsapp_verify_token_matches() for webhook verification. All SECURITY DEFINER
--      and executable by service_role only. A confirmed appointment cannot be replayed back to scheduled.
--   6. public.* wrappers with the same names, because PostgREST exposes schema public only.
--
-- Requires Supabase Vault (Dashboard > Integrations > Vault, or `create extension supabase_vault`).
-- Vault-dependent statements are guarded so the scratch run (tests/run_local.sh, which ships a plaintext
-- Vault shim) and a project without Vault both apply cleanly; the RPCs raise a clear error at call time.

-- ---------------------------------------------------------------------------
-- 1. Server-owned updated_at and pull indexes
-- ---------------------------------------------------------------------------

do $$
declare
  t record;
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
    if not t.has_updated_at then
      execute format('alter table public.%I add column updated_at timestamptz not null default now()', t.relname);
    end if;
    -- Re-create the touch trigger so it also fires on insert: the server owns updated_at.
    execute format('drop trigger if exists %I on public.%I', t.relname || '_touch_updated_at', t.relname);
    execute format(
      'create trigger %I before insert or update on public.%I
         for each row execute function app.touch_updated_at()',
      t.relname || '_touch_updated_at', t.relname);
    if t.has_clinic_id then
      execute format('create index if not exists %I on public.%I (clinic_id, updated_at)',
                     t.relname || '_clinic_updated_idx', t.relname);
    end if;
  end loop;
end
$$;

comment on function app.touch_updated_at() is
  'Sets updated_at = now() on insert and update; the server clock is the sync cursor, never the device clock.';

-- ---------------------------------------------------------------------------
-- 2. Devices
-- ---------------------------------------------------------------------------

-- One row per installed app. id is the device_id the client writes into audit_events and the outbox.
create table public.devices (
  id            uuid primary key default gen_random_uuid(),
  clinic_id     uuid not null references public.clinics (id),
  user_id       uuid not null references auth.users (id) default auth.uid(),
  platform      text not null check (platform in ('android', 'ios', 'other')),
  app_version   text not null default '',
  last_seen_at  timestamptz not null default now(),
  is_primary    boolean not null default false,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
comment on table public.devices is
  'Installed app instances. is_primary marks the clinic''s primary device (one per clinic), which runs '
  'scheduled local jobs such as recall sweeps. Registered by the app on sign-in and heartbeat.';
create index devices_clinic_id_idx on public.devices (clinic_id);
create index devices_clinic_updated_idx on public.devices (clinic_id, updated_at);
create index devices_user_id_idx on public.devices (user_id);
create unique index devices_one_primary_per_clinic on public.devices (clinic_id) where is_primary;

alter table public.devices enable row level security;
revoke all on table public.devices from anon;

create policy devices_select_member on public.devices
  for select to authenticated
  using (clinic_id in (select app.current_clinic_ids()));
-- A member registers only their own device.
create policy devices_insert_own on public.devices
  for insert to authenticated
  with check (clinic_id in (select app.current_clinic_ids()) and user_id = (select auth.uid()));
-- The device's user keeps its heartbeat; the owner can move the primary flag or retire any device.
create policy devices_update_own_or_owner on public.devices
  for update to authenticated
  using (
    clinic_id in (select app.current_clinic_ids())
    and (user_id = (select auth.uid()) or clinic_id in (select app.clinic_ids_with_role('ownerDentist')))
  )
  with check (
    clinic_id in (select app.current_clinic_ids())
    and (user_id = (select auth.uid()) or clinic_id in (select app.clinic_ids_with_role('ownerDentist')))
  );

create trigger devices_touch_updated_at
  before insert or update on public.devices
  for each row execute function app.touch_updated_at();
create trigger devices_audit
  after insert or update on public.devices
  for each row execute function app.audit_row();

-- ---------------------------------------------------------------------------
-- 3. message_logs delivery columns
-- ---------------------------------------------------------------------------

alter table public.message_logs
  add column provider          text not null default 'deeplink'
                               check (provider in ('deeplink', 'cloud_api', 'sms_gateway')),
  add column attempts          integer not null default 0 check (attempts >= 0),
  add column next_attempt_at   timestamptz,
  add column last_error        text,
  add column claimed_at        timestamptz,
  add column provider_payload  jsonb check (provider_payload is null or jsonb_typeof(provider_payload) = 'object');

comment on column public.message_logs.provider is
  'deeplink: the phone opened wa.me and the dentist pressed send; cloud_api: queued for the whatsapp-send '
  'Edge Function; sms_gateway: reserved for MSG91. Copied from variables._provider when the phone sets it.';
comment on column public.message_logs.next_attempt_at is
  'Earliest time the sender may (re)try. After a claim it is the lease expiry (claim + 10 minutes).';
comment on column public.message_logs.claimed_at is
  'When claim_whatsapp_batch() last handed the row to the sender; null until the first claim.';
comment on column public.message_logs.provider_payload is
  'Provider metadata (Meta pricing/conversation objects, error details). Never the message body.';

create index message_logs_send_queue_idx
  on public.message_logs (next_attempt_at, created_at)
  where provider = 'cloud_api' and status = 'queued';

-- Phones write MessageLog rows; the server owns their delivery. Before insert/update:
--   * provider follows variables._provider when the phone stamped it (MessageLogKeys in ampdent_messaging);
--   * for cloud_api rows written through the API (current_user = authenticated, i.e. PostgREST upserts
--     replaying a stale local row), delivery columns keep the server's values and the only status change
--     accepted is queued -> cancelled. Server-side functions (SECURITY DEFINER, service role) are exempt.
create or replace function app.message_logs_before_write()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_stamped text := new.variables ->> '_provider';
begin
  if v_stamped in ('deeplink', 'cloud_api', 'sms_gateway') then
    new.provider := v_stamped;
  end if;
  if tg_op = 'UPDATE' and current_user = 'authenticated' and old.provider = 'cloud_api' then
    new.provider := old.provider;
    new.provider_message_id := coalesce(old.provider_message_id, new.provider_message_id);
    new.sent_at := coalesce(old.sent_at, new.sent_at);
    new.delivered_at := coalesce(old.delivered_at, new.delivered_at);
    new.error := coalesce(old.error, new.error);
    new.attempts := old.attempts;
    new.next_attempt_at := old.next_attempt_at;
    new.claimed_at := old.claimed_at;
    new.last_error := old.last_error;
    new.provider_payload := old.provider_payload;
    if not (new.status = 'cancelled' and old.status = 'queued') then
      new.status := old.status;
    end if;
  end if;
  return new;
end
$$;
revoke all on function app.message_logs_before_write() from public, anon, authenticated;

create trigger message_logs_before_write
  before insert or update on public.message_logs
  for each row execute function app.message_logs_before_write();

-- A confirmation that arrived by WhatsApp survives a phone replaying the appointment as 'scheduled'
-- (the app never moves confirmed back to scheduled; it goes to arrived/cancelled/rescheduled instead).
create or replace function app.appointments_keep_confirmed()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if current_user = 'authenticated' and old.status = 'confirmed' and new.status = 'scheduled' then
    new.status := old.status;
    new.confirmed_at := coalesce(new.confirmed_at, old.confirmed_at);
  end if;
  return new;
end
$$;
revoke all on function app.appointments_keep_confirmed() from public, anon, authenticated;

create trigger appointments_keep_confirmed
  before update of status on public.appointments
  for each row execute function app.appointments_keep_confirmed();

-- ---------------------------------------------------------------------------
-- 4. Per-clinic WhatsApp configuration (token in Vault)
-- ---------------------------------------------------------------------------

create table public.clinic_whatsapp_configs (
  clinic_id               uuid primary key references public.clinics (id),
  phone_number_id         text not null check (phone_number_id ~ '^[0-9]{5,32}$'),
  waba_id                 text not null check (waba_id ~ '^[0-9]{5,32}$'),
  display_phone           text,
  access_token_secret_id  uuid not null,
  verify_token            text not null check (length(verify_token) between 8 and 128),
  is_enabled              boolean not null default true,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now()
);
comment on table public.clinic_whatsapp_configs is
  'Meta WhatsApp Cloud API binding per clinic. access_token_secret_id points at the Vault secret holding '
  'the permanent system-user token; the token itself is never stored here. Written only through '
  'app.set_whatsapp_config() / app.set_whatsapp_enabled().';
create unique index clinic_whatsapp_configs_phone_number_id_uniq
  on public.clinic_whatsapp_configs (phone_number_id);

-- Foreign key into vault.secrets when the Vault tables are reachable (REFERENCES privilege may be
-- withheld on a managed project; the RPCs below still guarantee the secret exists).
do $$
begin
  if to_regclass('vault.secrets') is not null then
    begin
      alter table public.clinic_whatsapp_configs
        add constraint clinic_whatsapp_configs_secret_fk
        foreign key (access_token_secret_id) references vault.secrets (id);
    exception when insufficient_privilege or undefined_table then
      raise notice 'clinic_whatsapp_configs: Vault FK skipped (%)', sqlerrm;
    end;
  else
    raise notice 'clinic_whatsapp_configs: Vault not installed, FK skipped; enable Vault before using WhatsApp';
  end if;
end
$$;

alter table public.clinic_whatsapp_configs enable row level security;
revoke all on table public.clinic_whatsapp_configs from anon;
-- Owners may read their clinic's binding; there is deliberately no insert/update/delete policy.
create policy clinic_whatsapp_configs_select_owner on public.clinic_whatsapp_configs
  for select to authenticated
  using (clinic_id in (select app.clinic_ids_with_role('ownerDentist')));

create trigger clinic_whatsapp_configs_touch_updated_at
  before insert or update on public.clinic_whatsapp_configs
  for each row execute function app.touch_updated_at();

-- Raises a readable error when Vault is missing instead of "relation vault.secrets does not exist".
create or replace function app.assert_vault_available()
returns void
language plpgsql
stable
set search_path = ''
as $$
begin
  if to_regprocedure('vault.create_secret(text,text,text,uuid)') is null then
    raise exception 'Supabase Vault is not enabled on this project; enable it under Integrations > Vault'
      using errcode = 'feature_not_supported';
  end if;
end
$$;
revoke all on function app.assert_vault_available() from public, anon, authenticated;

-- Owner RPC: bind (or re-bind) the clinic's Meta phone number. The token goes to Vault only.
create or replace function app.set_whatsapp_config(
  p_clinic uuid,
  p_phone_number_id text,
  p_waba_id text,
  p_display_phone text,
  p_access_token text,
  p_verify_token text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_secret   uuid;
  v_name     text := 'whatsapp_access_token:' || p_clinic::text;
  v_desc     text := 'Meta WhatsApp Cloud API permanent token for clinic ' || p_clinic::text;
begin
  if not app.has_role(p_clinic, 'ownerDentist') then
    raise exception 'only the clinic owner may configure WhatsApp for clinic %', p_clinic
      using errcode = 'insufficient_privilege';
  end if;
  if coalesce(length(trim(p_access_token)), 0) < 20 then
    raise exception 'access token looks too short' using errcode = 'invalid_parameter_value';
  end if;
  perform app.assert_vault_available();

  select c.access_token_secret_id into v_secret
  from public.clinic_whatsapp_configs as c
  where c.clinic_id = p_clinic
  for update;

  if v_secret is null then
    v_secret := vault.create_secret(trim(p_access_token), v_name, v_desc);
    insert into public.clinic_whatsapp_configs
      (clinic_id, phone_number_id, waba_id, display_phone, access_token_secret_id, verify_token, is_enabled)
    values
      (p_clinic, trim(p_phone_number_id), trim(p_waba_id), nullif(trim(p_display_phone), ''), v_secret,
       trim(p_verify_token), true);
  else
    perform vault.update_secret(v_secret, trim(p_access_token), v_name, v_desc);
    update public.clinic_whatsapp_configs
       set phone_number_id = trim(p_phone_number_id),
           waba_id = trim(p_waba_id),
           display_phone = nullif(trim(p_display_phone), ''),
           verify_token = trim(p_verify_token),
           is_enabled = true
     where clinic_id = p_clinic;
  end if;

  -- Explicit audit row without the token or the verify token.
  insert into public.audit_events (clinic_id, actor_id, action, entity_type, entity_id, after, device_id)
  values (p_clinic, (select auth.uid()), 'settingsChange', 'ClinicWhatsappConfig', p_clinic::text,
          jsonb_build_object('phone_number_id', trim(p_phone_number_id), 'waba_id', trim(p_waba_id),
                             'display_phone', nullif(trim(p_display_phone), ''), 'is_enabled', true),
          coalesce(nullif(current_setting('app.device_id', true), ''), 'server'));
end
$$;

-- Owner RPC: pause or resume sending without touching the token.
create or replace function app.set_whatsapp_enabled(p_clinic uuid, p_enabled boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not app.has_role(p_clinic, 'ownerDentist') then
    raise exception 'only the clinic owner may change WhatsApp settings for clinic %', p_clinic
      using errcode = 'insufficient_privilege';
  end if;
  update public.clinic_whatsapp_configs set is_enabled = p_enabled where clinic_id = p_clinic;
  if not found then
    raise exception 'WhatsApp is not configured for clinic %', p_clinic using errcode = 'no_data_found';
  end if;
  insert into public.audit_events (clinic_id, actor_id, action, entity_type, entity_id, after, device_id)
  values (p_clinic, (select auth.uid()), 'settingsChange', 'ClinicWhatsappConfig', p_clinic::text,
          jsonb_build_object('is_enabled', p_enabled),
          coalesce(nullif(current_setting('app.device_id', true), ''), 'server'));
end
$$;

-- Member RPC: configuration state without secrets, plus queue depth for the settings screen.
create or replace function app.get_whatsapp_status(p_clinic uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  c      public.clinic_whatsapp_configs%rowtype;
  v_queued integer;
  v_failed integer;
begin
  if not (p_clinic in (select app.current_clinic_ids())) then
    raise exception 'not a member of clinic %', p_clinic using errcode = 'insufficient_privilege';
  end if;
  select * into c from public.clinic_whatsapp_configs where clinic_id = p_clinic;
  select count(*) filter (where status in ('queued', 'sending')),
         count(*) filter (where status = 'failed' and updated_at > now() - interval '24 hours')
    into v_queued, v_failed
  from public.message_logs
  where clinic_id = p_clinic and provider = 'cloud_api';
  return jsonb_build_object(
    'configured', c.clinic_id is not null,
    'enabled', coalesce(c.is_enabled, false),
    'phoneNumberId', c.phone_number_id,
    'wabaId', c.waba_id,
    'displayPhone', c.display_phone,
    'updatedAt', c.updated_at,
    'queuedCount', v_queued,
    'failedLast24h', v_failed);
end
$$;

revoke all on function app.set_whatsapp_config(uuid, text, text, text, text, text) from public, anon;
revoke all on function app.set_whatsapp_enabled(uuid, boolean) from public, anon;
revoke all on function app.get_whatsapp_status(uuid) from public, anon;
grant execute on function app.set_whatsapp_config(uuid, text, text, text, text, text) to authenticated, service_role;
grant execute on function app.set_whatsapp_enabled(uuid, boolean) to authenticated, service_role;
grant execute on function app.get_whatsapp_status(uuid) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 5. Send queue, claim, result, status, inbound reply (service role only)
-- ---------------------------------------------------------------------------

-- Cloud API rows that are due: queued and past next_attempt_at (null = never attempted; a value in the
-- future is either a retry backoff or the lease of a claim still in flight).
create view app.whatsapp_send_queue as
select m.id, m.clinic_id, m.patient_id, m.template_code, m.category, m.to_phone, m.variables,
       m.status, m.attempts, m.claimed_at, m.next_attempt_at, m.created_at,
       c.phone_number_id, c.waba_id, c.access_token_secret_id
from public.message_logs as m
join public.clinic_whatsapp_configs as c on c.clinic_id = m.clinic_id and c.is_enabled
where m.channel = 'whatsapp'
  and m.provider = 'cloud_api'
  and m.status = 'queued'
  and (m.next_attempt_at is null or m.next_attempt_at <= now())
order by m.created_at;

revoke all on app.whatsapp_send_queue from public, anon, authenticated;
grant select on app.whatsapp_send_queue to service_role;

-- Atomically claims up to p_limit due rows (claimed_at = now(), attempts + 1, next_attempt_at = 10-minute
-- lease) and returns them with the decrypted token. Row locks + SKIP LOCKED mean concurrent callers never
-- see the same row, and a claimed row is not due again until its lease expires (a crashed worker).
create or replace function app.claim_whatsapp_batch(p_limit integer default 25)
returns table (
  id uuid, clinic_id uuid, patient_id uuid, template_code text, category text, to_phone text,
  variables jsonb, attempts integer, patient_language text, phone_number_id text, waba_id text,
  access_token text)
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.assert_vault_available();
  return query
  with picked as (
    select m.id
    from public.message_logs as m
    where m.id in (select q.id from app.whatsapp_send_queue as q)
    order by m.created_at
    limit greatest(1, least(coalesce(p_limit, 25), 100))
    for update skip locked
  ),
  claimed as (
    update public.message_logs as m
       set claimed_at = now(),
           attempts = m.attempts + 1,
           next_attempt_at = now() + interval '10 minutes'
      from picked
     where m.id = picked.id
    returning m.id, m.clinic_id, m.patient_id, m.template_code, m.category, m.to_phone, m.variables,
              m.attempts, m.created_at
  )
  select cl.id, cl.clinic_id, cl.patient_id, cl.template_code, cl.category, cl.to_phone, cl.variables,
         cl.attempts, coalesce(p.preferred_language, 'en'), c.phone_number_id, c.waba_id,
         s.decrypted_secret
  from claimed as cl
  join public.clinic_whatsapp_configs as c on c.clinic_id = cl.clinic_id
  join vault.decrypted_secrets as s on s.id = c.access_token_secret_id
  left join public.patients as p on p.id = cl.patient_id
  order by cl.created_at;
end
$$;

-- Records the outcome of one send attempt. p_status: 'sent' | 'retry' | 'failed'.
-- 'retry' keeps the row queued with exponential backoff (1, 2, 4, ... minutes) until the sixth attempt,
-- then fails. Returns false when the row is not a claimed, still-queued row (already resolved, cancelled
-- by the clinic meanwhile, or never claimed).
create or replace function app.record_whatsapp_result(
  p_id uuid, p_status text, p_provider_message_id text default null, p_error text default null)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_attempts integer;
begin
  select attempts into v_attempts
  from public.message_logs
  where id = p_id and status = 'queued' and claimed_at is not null
  for update;
  if not found then
    return false;
  end if;
  if p_status = 'sent' then
    update public.message_logs
       set status = 'sent', sent_at = now(), provider_message_id = p_provider_message_id,
           error = null, last_error = null, next_attempt_at = null
     where id = p_id;
  elsif p_status = 'retry' and v_attempts < 6 then
    update public.message_logs
       set last_error = p_error,
           next_attempt_at = now() + (interval '1 minute' * power(2, v_attempts - 1))
     where id = p_id;
  elsif p_status in ('retry', 'failed') then
    update public.message_logs
       set status = 'failed', error = p_error, last_error = p_error, next_attempt_at = null
     where id = p_id;
  else
    raise exception 'unknown result status %', p_status using errcode = 'invalid_parameter_value';
  end if;
  return true;
end
$$;

-- Applies a delivery status from the Meta webhook. Statuses only move forward (sent < delivered < read);
-- 'failed' is applied at any point except after 'read'. Returns false when the message id is unknown.
create or replace function app.apply_whatsapp_status(
  p_provider_message_id text, p_status text, p_timestamp timestamptz default now(),
  p_error text default null, p_payload jsonb default null)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id      uuid;
  v_current text;
  v_rank    constant jsonb := '{"queued":0,"sent":1,"delivered":2,"read":3,"failed":4,"cancelled":4}';
begin
  if p_status not in ('sent', 'delivered', 'read', 'failed') then
    raise exception 'unknown WhatsApp status %', p_status using errcode = 'invalid_parameter_value';
  end if;
  select id, status into v_id, v_current
  from public.message_logs where provider_message_id = p_provider_message_id
  order by created_at desc limit 1
  for update;
  if v_id is null then
    return false;
  end if;
  if p_status = 'failed' then
    if v_current = 'read' then return true; end if;
    update public.message_logs
       set status = 'failed', error = p_error, last_error = p_error,
           provider_payload = coalesce(provider_payload, '{}'::jsonb) || coalesce(p_payload, '{}'::jsonb)
     where id = v_id;
    return true;
  end if;
  if (v_rank ->> p_status)::int <= (v_rank ->> v_current)::int then
    return true;  -- out-of-order or duplicate webhook
  end if;
  update public.message_logs
     set status = p_status,
         sent_at = coalesce(sent_at, case when p_status = 'sent' then p_timestamp else sent_at end),
         delivered_at = coalesce(delivered_at, case when p_status in ('delivered', 'read') then p_timestamp end),
         provider_payload = coalesce(provider_payload, '{}'::jsonb) || coalesce(p_payload, '{}'::jsonb)
   where id = v_id;
  return true;
end
$$;

-- Inbound reply handling: "1" (or yes / confirm) from a patient's or guardian's number confirms the next
-- scheduled appointment in the clinic that owns p_phone_number_id. Returns the appointment id or null.
-- p_context_message_id is the wamid the patient replied to; when it is one of ours it pins the patient.
create or replace function app.confirm_appointment_from_reply(
  p_phone text, p_text text, p_phone_number_id text default null, p_context_message_id text default null)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_last10   text := right(regexp_replace(coalesce(p_phone, ''), '\D', '', 'g'), 10);
  v_clinic   uuid;
  v_patient  uuid;
  v_appt     uuid;
begin
  if lower(trim(coalesce(p_text, ''))) not in ('1', 'yes', 'y', 'confirm', 'confirmed', 'ok', 'haan', 'ha') then
    return null;
  end if;
  if length(v_last10) < 10 then
    return null;
  end if;
  if p_phone_number_id is not null then
    select clinic_id into v_clinic from public.clinic_whatsapp_configs where phone_number_id = p_phone_number_id;
    if v_clinic is null then return null; end if;
  end if;
  if p_context_message_id is not null then
    select m.clinic_id, m.patient_id into v_clinic, v_patient
    from public.message_logs as m
    where m.provider_message_id = p_context_message_id
      and (v_clinic is null or m.clinic_id = v_clinic)
    order by m.created_at desc limit 1;
  end if;

  perform set_config('app.device_id', 'whatsapp-webhook', true);

  select a.id into v_appt
  from public.appointments as a
  join public.patients as p on p.id = a.patient_id
  where a.status = 'scheduled'
    and a.starts_at between now() - interval '2 hours' and now() + interval '3 days'
    and (v_clinic is null or a.clinic_id = v_clinic)
    and (v_patient is null or a.patient_id = v_patient)
    and (
      right(regexp_replace(p.phone, '\D', '', 'g'), 10) = v_last10
      or right(regexp_replace(coalesce(p.guardian_phone, ''), '\D', '', 'g'), 10) = v_last10
      or right(regexp_replace(coalesce(p.alt_phone, ''), '\D', '', 'g'), 10) = v_last10
    )
  order by a.starts_at
  limit 1
  for update of a skip locked;

  if v_appt is null then
    return null;
  end if;
  update public.appointments
     set status = 'confirmed', confirmed_at = coalesce(confirmed_at, now())
   where id = v_appt;
  return v_appt;
end
$$;

-- Webhook GET verification: true when p_token is any enabled clinic's verify token.
create or replace function app.whatsapp_verify_token_matches(p_token text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.clinic_whatsapp_configs as c
    where c.verify_token = p_token and length(coalesce(p_token, '')) >= 8);
$$;

revoke all on function app.claim_whatsapp_batch(integer) from public, anon, authenticated;
revoke all on function app.record_whatsapp_result(uuid, text, text, text) from public, anon, authenticated;
revoke all on function app.apply_whatsapp_status(text, text, timestamptz, text, jsonb) from public, anon, authenticated;
revoke all on function app.confirm_appointment_from_reply(text, text, text, text) from public, anon, authenticated;
revoke all on function app.whatsapp_verify_token_matches(text) from public, anon, authenticated;
grant execute on function app.claim_whatsapp_batch(integer) to service_role;
grant execute on function app.record_whatsapp_result(uuid, text, text, text) to service_role;
grant execute on function app.apply_whatsapp_status(text, text, timestamptz, text, jsonb) to service_role;
grant execute on function app.confirm_appointment_from_reply(text, text, text, text) to service_role;
grant execute on function app.whatsapp_verify_token_matches(text) to service_role;

-- ---------------------------------------------------------------------------
-- 6. PostgREST-facing wrappers (schema public). Same grants as the app.* function they call.
-- ---------------------------------------------------------------------------

create or replace function public.set_whatsapp_config(
  p_clinic uuid, p_phone_number_id text, p_waba_id text, p_display_phone text, p_access_token text, p_verify_token text)
returns void language sql set search_path = '' as
$$ select app.set_whatsapp_config(p_clinic, p_phone_number_id, p_waba_id, p_display_phone, p_access_token, p_verify_token); $$;

create or replace function public.set_whatsapp_enabled(p_clinic uuid, p_enabled boolean)
returns void language sql set search_path = '' as
$$ select app.set_whatsapp_enabled(p_clinic, p_enabled); $$;

create or replace function public.get_whatsapp_status(p_clinic uuid)
returns jsonb language sql stable set search_path = '' as
$$ select app.get_whatsapp_status(p_clinic); $$;

create or replace function public.claim_whatsapp_batch(p_limit integer default 25)
returns table (
  id uuid, clinic_id uuid, patient_id uuid, template_code text, category text, to_phone text,
  variables jsonb, attempts integer, patient_language text, phone_number_id text, waba_id text,
  access_token text)
language sql set search_path = '' as
$$ select * from app.claim_whatsapp_batch(p_limit); $$;

create or replace function public.record_whatsapp_result(
  p_id uuid, p_status text, p_provider_message_id text default null, p_error text default null)
returns boolean language sql set search_path = '' as
$$ select app.record_whatsapp_result(p_id, p_status, p_provider_message_id, p_error); $$;

create or replace function public.apply_whatsapp_status(
  p_provider_message_id text, p_status text, p_timestamp timestamptz default now(),
  p_error text default null, p_payload jsonb default null)
returns boolean language sql set search_path = '' as
$$ select app.apply_whatsapp_status(p_provider_message_id, p_status, p_timestamp, p_error, p_payload); $$;

create or replace function public.confirm_appointment_from_reply(
  p_phone text, p_text text, p_phone_number_id text default null, p_context_message_id text default null)
returns uuid language sql set search_path = '' as
$$ select app.confirm_appointment_from_reply(p_phone, p_text, p_phone_number_id, p_context_message_id); $$;

create or replace function public.whatsapp_verify_token_matches(p_token text)
returns boolean language sql stable set search_path = '' as
$$ select app.whatsapp_verify_token_matches(p_token); $$;

revoke all on function public.set_whatsapp_config(uuid, text, text, text, text, text) from public, anon;
revoke all on function public.set_whatsapp_enabled(uuid, boolean) from public, anon;
revoke all on function public.get_whatsapp_status(uuid) from public, anon;
grant execute on function public.set_whatsapp_config(uuid, text, text, text, text, text) to authenticated, service_role;
grant execute on function public.set_whatsapp_enabled(uuid, boolean) to authenticated, service_role;
grant execute on function public.get_whatsapp_status(uuid) to authenticated, service_role;

revoke all on function public.claim_whatsapp_batch(integer) from public, anon, authenticated;
revoke all on function public.record_whatsapp_result(uuid, text, text, text) from public, anon, authenticated;
revoke all on function public.apply_whatsapp_status(text, text, timestamptz, text, jsonb) from public, anon, authenticated;
revoke all on function public.confirm_appointment_from_reply(text, text, text, text) from public, anon, authenticated;
revoke all on function public.whatsapp_verify_token_matches(text) from public, anon, authenticated;
grant execute on function public.claim_whatsapp_batch(integer) to service_role;
grant execute on function public.record_whatsapp_result(uuid, text, text, text) to service_role;
grant execute on function public.apply_whatsapp_status(text, text, timestamptz, text, jsonb) to service_role;
grant execute on function public.confirm_appointment_from_reply(text, text, text, text) to service_role;
grant execute on function public.whatsapp_verify_token_matches(text) to service_role;
