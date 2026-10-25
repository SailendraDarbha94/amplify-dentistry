-- 0009_whatsapp_cron.sql
-- Scheduler for the WhatsApp sender: pg_cron calls app.invoke_whatsapp_send() every minute, which uses
-- pg_net to POST to the whatsapp-send Edge Function when the queue is non-empty.
--
--   app.runtime_config(key, value)   service-role-only settings table. Keys used here:
--     functions_base_url        https://<project-ref>.supabase.co/functions/v1   (no trailing slash)
--     cron_bearer_secret_name   name of the Vault secret holding the bearer token the function accepts
--                               (default 'ampdent_cron_bearer'; store the service_role key there)
--   app.invoke_whatsapp_send()       builds and queues the HTTP request; returns the pg_net request id
--
-- pg_cron and pg_net are Supabase-managed extensions. They are created here when the server offers them
-- (Dashboard > Database > Extensions also works); on a plain PostgreSQL scratch cluster both are skipped and
-- the cron job is not scheduled. docs/SETUP-CLOUD.md lists the manual steps.

create table app.runtime_config (
  key         text primary key,
  value       text not null,
  updated_at  timestamptz not null default now()
);
comment on table app.runtime_config is
  'Deployment settings read by server-side jobs (function URLs, Vault secret names). Service role only; '
  'never clinic data.';
revoke all on table app.runtime_config from public, anon, authenticated;
grant select, insert, update, delete on table app.runtime_config to service_role;

create trigger runtime_config_touch_updated_at
  before insert or update on app.runtime_config
  for each row execute function app.touch_updated_at();

-- Extensions (guarded so the migration applies anywhere).
do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_net') then
    if exists (select 1 from pg_namespace where nspname = 'extensions') then
      create extension if not exists pg_net with schema extensions;
    else
      create extension if not exists pg_net;
    end if;
  else
    raise notice 'pg_net not available on this server; enable it in the Supabase dashboard';
  end if;
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron;
  else
    raise notice 'pg_cron not available on this server; enable it in the Supabase dashboard';
  end if;
exception when others then
  raise notice 'extension setup skipped: %', sqlerrm;
end
$$;

-- Queues one HTTP POST to the whatsapp-send function when there is work. Returns the pg_net request id,
-- or null when nothing was sent (empty queue, missing config, missing bearer, pg_net absent).
create or replace function app.invoke_whatsapp_send()
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_url         text;
  v_secret_name text;
  v_bearer      text;
  v_request_id  bigint;
begin
  if not exists (select 1 from app.whatsapp_send_queue) then
    return null;
  end if;
  select value into v_url from app.runtime_config where key = 'functions_base_url';
  if v_url is null then
    raise notice 'app.runtime_config.functions_base_url is not set; whatsapp-send not invoked';
    return null;
  end if;
  select coalesce((select value from app.runtime_config where key = 'cron_bearer_secret_name'),
                  'ampdent_cron_bearer')
    into v_secret_name;
  if to_regclass('vault.decrypted_secrets') is null then
    raise notice 'Vault is not enabled; whatsapp-send not invoked';
    return null;
  end if;
  select s.decrypted_secret into v_bearer
  from vault.decrypted_secrets as s
  where s.name = v_secret_name
  order by s.created_at desc
  limit 1;
  if v_bearer is null then
    raise notice 'Vault secret % not found; whatsapp-send not invoked', v_secret_name;
    return null;
  end if;
  if to_regprocedure('net.http_post(text,jsonb,jsonb,jsonb,integer)') is null then
    raise notice 'pg_net is not installed; whatsapp-send not invoked';
    return null;
  end if;

  select net.http_post(
    url := rtrim(v_url, '/') || '/whatsapp-send',
    body := jsonb_build_object('source', 'pg_cron', 'queued_at', now()),
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_bearer),
    timeout_milliseconds := 20000)
  into v_request_id;
  return v_request_id;
end
$$;

revoke all on function app.invoke_whatsapp_send() from public, anon, authenticated;
grant execute on function app.invoke_whatsapp_send() to service_role;

-- Every minute. cron.schedule(name, ...) upserts by job name, so re-running this migration is safe.
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('ampdent-whatsapp-send', '* * * * *', 'select app.invoke_whatsapp_send()');
  else
    raise notice 'pg_cron missing: after enabling it run  select cron.schedule(''ampdent-whatsapp-send'', ''* * * * *'', ''select app.invoke_whatsapp_send()'');';
  end if;
end
$$;
