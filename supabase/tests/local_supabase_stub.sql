-- local_supabase_stub.sql
-- Minimal shims so the AmpDent migrations run against a plain PostgreSQL 15+ cluster
-- (no Supabase platform). Creates the roles, the auth schema with auth.users and auth.uid(),
-- the storage schema with buckets/objects/foldername(), and Supabase's default grants.
-- Never apply this to a real Supabase project: the platform already provides all of it.

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin noinherit bypassrls;
  end if;
end
$$;

-- auth ---------------------------------------------------------------------
create schema if not exists auth;

create table if not exists auth.users (
  id          uuid primary key default gen_random_uuid(),
  email       text,
  phone       text,
  created_at  timestamptz not null default now()
);

-- Mirrors Supabase: reads the JWT subject from the request setting.
create or replace function auth.uid()
returns uuid
language sql
stable
as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub'
  )::uuid;
$$;

grant usage on schema auth to anon, authenticated, service_role;
grant execute on function auth.uid() to anon, authenticated, service_role;

-- storage ------------------------------------------------------------------
create schema if not exists storage;

create table if not exists storage.buckets (
  id                  text primary key,
  name                text not null,
  owner               uuid,
  public              boolean default false,
  avif_autodetection  boolean default false,
  file_size_limit     bigint,
  allowed_mime_types  text[],
  created_at          timestamptz default now(),
  updated_at          timestamptz default now()
);

create table if not exists storage.objects (
  id               uuid primary key default gen_random_uuid(),
  bucket_id        text references storage.buckets (id),
  name             text,
  owner            uuid,
  metadata         jsonb,
  path_tokens      text[] generated always as (string_to_array(name, '/')) stored,
  created_at       timestamptz default now(),
  updated_at       timestamptz default now(),
  last_accessed_at timestamptz default now()
);

alter table storage.objects enable row level security;

create or replace function storage.foldername(name text)
returns text[]
language plpgsql
immutable
as $$
declare
  parts text[];
begin
  parts := string_to_array(name, '/');
  return parts[1 : array_length(parts, 1) - 1];
end
$$;

grant usage on schema storage to anon, authenticated, service_role;
grant all on all tables in schema storage to anon, authenticated, service_role;
grant execute on function storage.foldername(text) to anon, authenticated, service_role;

-- Supabase default privileges on public --------------------------------------
grant usage on schema public to anon, authenticated, service_role;
alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
alter default privileges in schema public grant all on sequences to anon, authenticated, service_role;
alter default privileges in schema public grant execute on functions to anon, authenticated, service_role;

-- vault (Supabase Vault shim) -----------------------------------------------
-- The real extension (supabase_vault) encrypts secrets with a key held outside the database and exposes
-- them through vault.decrypted_secrets. This shim stores the plaintext so the WhatsApp config RPCs in
-- 0008 can be exercised end to end on a scratch cluster. NEVER apply this to a real project.
create schema if not exists vault;

create table if not exists vault.secrets (
  id           uuid primary key default gen_random_uuid(),
  name         text unique,
  description  text not null default '',
  secret       text not null,
  key_id       uuid,
  nonce        bytea,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create or replace view vault.decrypted_secrets as
  select id, name, description, secret, secret as decrypted_secret, key_id, nonce, created_at, updated_at
  from vault.secrets;

create or replace function vault.create_secret(
  new_secret text, new_name text default null, new_description text default '', new_key_id uuid default null)
returns uuid
language sql
as $$
  insert into vault.secrets (name, description, secret, key_id)
  values (new_name, coalesce(new_description, ''), new_secret, new_key_id)
  returning id;
$$;

create or replace function vault.update_secret(
  secret_id uuid, new_secret text default null, new_name text default null,
  new_description text default null, new_key_id uuid default null)
returns void
language sql
as $$
  update vault.secrets
     set secret = coalesce(new_secret, secret),
         name = coalesce(new_name, name),
         description = coalesce(new_description, description),
         key_id = coalesce(new_key_id, key_id),
         updated_at = now()
   where id = secret_id;
$$;

-- net (pg_net shim) ------------------------------------------------------------
-- Records every http_post so smoke.sql can check the cron invoker builds the right request.
create schema if not exists net;

create table if not exists net._requests (
  id       bigint generated always as identity primary key,
  url      text not null,
  headers  jsonb not null,
  body     jsonb,
  timeout_milliseconds integer
);

create or replace function net.http_post(
  url text, body jsonb default '{}'::jsonb, params jsonb default '{}'::jsonb,
  headers jsonb default '{"Content-Type": "application/json"}'::jsonb, timeout_milliseconds integer default 5000)
returns bigint
language sql
as $$
  insert into net._requests (url, headers, body, timeout_milliseconds)
  values (url, headers, body, timeout_milliseconds)
  returning id;
$$;
