-- 0010_member_invites.sql
-- Staff invite codes: how a member row created on the owner's phone gets bound to the auth account
-- that person signs in with, without the manual `update clinic_members set user_id = ...` step.
--   1. public.member_invites: one short-lived code per invite (8 characters, unambiguous alphabet,
--      72 hours), readable and insertable by the clinic owner only; never updated through the API.
--   2. app.create_member_invite(p_member)  owner RPC: mints a code for a member row that has no account
--      yet, retiring any earlier live code for the same member, and returns the code.
--   3. app.claim_member_invite(p_code)     any signed-in user: binds clinic_members.user_id = auth.uid(),
--      which is what makes the clinic visible to that user (app.current_clinic_ids), marks the invite
--      claimed and returns the clinic id. Expired, claimed, unknown or mismatched codes are rejected.
-- The code is a capability, so it is never written to the audit trail; the claim is audited through the
-- clinic_members update (actor = the claiming user) plus an explicit member_invites row without the code.

-- ---------------------------------------------------------------------------
-- 1. Table
-- ---------------------------------------------------------------------------

create table public.member_invites (
  id          uuid primary key default gen_random_uuid(),
  clinic_id   uuid not null references public.clinics (id),
  member_id   uuid not null references public.clinic_members (id),
  code        text not null unique check (code ~ '^[A-HJKMNP-Z2-9]{8}$'),
  created_by  uuid not null default auth.uid() references auth.users (id),
  created_at  timestamptz not null default now(),
  expires_at  timestamptz not null default now() + interval '72 hours',
  claimed_by  uuid references auth.users (id),
  claimed_at  timestamptz,
  check (claimed_at is null or claimed_by is not null)
);

comment on table public.member_invites is
  'Staff invite codes (8 chars, 72 h). Minted by app.create_member_invite, redeemed by app.claim_member_invite.';

create index member_invites_clinic_id_idx on public.member_invites (clinic_id);
create index member_invites_member_live_idx on public.member_invites (member_id, expires_at)
  where claimed_at is null;

alter table public.member_invites enable row level security;
revoke all on table public.member_invites from anon;

-- Owners see and create their clinic's invites; nobody updates or deletes rows through the API
-- (claims go through the security definer RPC below).
create policy member_invites_select_owner on public.member_invites
  for select to authenticated
  using (clinic_id in (select app.clinic_ids_with_role('ownerDentist')));

create policy member_invites_insert_owner on public.member_invites
  for insert to authenticated
  with check (
    clinic_id in (select app.clinic_ids_with_role('ownerDentist'))
    and created_by = (select auth.uid())
    and claimed_by is null
    and claimed_at is null
  );

-- ---------------------------------------------------------------------------
-- 2. Code generation
-- ---------------------------------------------------------------------------

-- Eight characters from an alphabet without 0/O, 1/I and L, drawn from the random bytes of a v4 uuid
-- (bytes 6 and 8 carry the version and variant nibbles and are skipped). 256 is a multiple of 32, so
-- each byte modulo 32 is uniform over the alphabet.
create or replace function app.new_invite_code()
returns text
language plpgsql
volatile
set search_path = ''
as $$
declare
  v_alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  v_bytes    bytea := decode(replace(gen_random_uuid()::text, '-', ''), 'hex');
  v_out      text := '';
  v_pos      integer;
begin
  foreach v_pos in array array[0, 1, 2, 3, 4, 5, 9, 10] loop
    v_out := v_out || substr(v_alphabet, (get_byte(v_bytes, v_pos) % length(v_alphabet)) + 1, 1);
  end loop;
  return v_out;
end
$$;

revoke all on function app.new_invite_code() from public, anon, authenticated;

-- Upper-cases and strips spaces and hyphens so a code read out over the phone still matches.
create or replace function app.normalise_invite_code(p_code text)
returns text
language sql
immutable
set search_path = ''
as $$
  select upper(regexp_replace(coalesce(p_code, ''), '[\s-]', '', 'g'));
$$;

revoke all on function app.normalise_invite_code(text) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3. RPCs
-- ---------------------------------------------------------------------------

-- Owner RPC: mint an invite code for p_member (a row of the caller's clinic with no account yet).
-- Any earlier live code for the same member is retired, so one code per member is ever valid.
create or replace function app.create_member_invite(p_member uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_member  record;
  v_code    text;
  v_tries   integer := 0;
begin
  if (select auth.uid()) is null then
    raise exception 'sign in to create an invite' using errcode = 'insufficient_privilege';
  end if;

  select m.id, m.clinic_id, m.user_id, m.is_active
    into v_member
    from public.clinic_members as m
   where m.id = p_member
     for update;

  if v_member.id is null or not app.has_role(v_member.clinic_id, 'ownerDentist') then
    raise exception 'only the clinic owner may invite member %', p_member
      using errcode = 'insufficient_privilege';
  end if;
  if not v_member.is_active then
    raise exception 'member % is deactivated', p_member using errcode = 'invalid_parameter_value';
  end if;
  if v_member.user_id is not null then
    raise exception 'member % is already signed in with an account', p_member
      using errcode = 'invalid_parameter_value';
  end if;

  update public.member_invites
     set expires_at = now()
   where member_id = p_member
     and claimed_at is null
     and expires_at > now();

  loop
    v_code := app.new_invite_code();
    exit when not exists (select 1 from public.member_invites as i where i.code = v_code);
    v_tries := v_tries + 1;
    if v_tries > 20 then
      raise exception 'could not mint a unique invite code' using errcode = 'internal_error';
    end if;
  end loop;

  insert into public.member_invites (clinic_id, member_id, code, created_by)
  values (v_member.clinic_id, p_member, v_code, (select auth.uid()));

  return v_code;
end
$$;

-- Any signed-in user: redeem p_code. Binds the member row to the caller, marks the invite claimed and
-- returns the clinic id. Raises invalid_parameter_value for an unknown, expired or used code, and
-- insufficient_privilege when the member row already belongs to another account or the caller is
-- already a member of that clinic under another row.
create or replace function app.claim_member_invite(p_code text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user    uuid := (select auth.uid());
  v_code    text := app.normalise_invite_code(p_code);
  v_invite  record;
  v_member  record;
begin
  if v_user is null then
    raise exception 'sign in to use an invite code' using errcode = 'insufficient_privilege';
  end if;
  if v_code !~ '^[A-HJKMNP-Z2-9]{8}$' then
    raise exception 'invite code not recognised' using errcode = 'invalid_parameter_value';
  end if;

  select i.id, i.clinic_id, i.member_id, i.expires_at, i.claimed_at
    into v_invite
    from public.member_invites as i
   where i.code = v_code
     for update;

  if v_invite.id is null then
    raise exception 'invite code not recognised' using errcode = 'invalid_parameter_value';
  end if;
  if v_invite.claimed_at is not null then
    raise exception 'invite code already used' using errcode = 'invalid_parameter_value';
  end if;
  if v_invite.expires_at <= now() then
    raise exception 'invite code expired; ask the clinic owner for a new one'
      using errcode = 'invalid_parameter_value';
  end if;

  select m.id, m.clinic_id, m.user_id, m.is_active
    into v_member
    from public.clinic_members as m
   where m.id = v_invite.member_id
     for update;

  if v_member.id is null or not v_member.is_active then
    raise exception 'the invited member row is no longer active' using errcode = 'invalid_parameter_value';
  end if;
  if v_member.user_id is not null and v_member.user_id <> v_user then
    raise exception 'this invite belongs to another account' using errcode = 'insufficient_privilege';
  end if;
  if exists (
       select 1 from public.clinic_members as o
        where o.clinic_id = v_member.clinic_id
          and o.user_id = v_user
          and o.id <> v_member.id) then
    raise exception 'you are already a member of this clinic' using errcode = 'insufficient_privilege';
  end if;

  -- The binding is the membership: app.current_clinic_ids() now lists this clinic for the caller.
  update public.clinic_members
     set user_id = v_user
   where id = v_member.id;

  update public.member_invites
     set claimed_by = v_user,
         claimed_at = now()
   where id = v_invite.id;

  -- Explicit audit row without the code.
  insert into public.audit_events (clinic_id, actor_id, action, entity_type, entity_id, after, device_id)
  values (v_member.clinic_id, v_user, 'statusChange', 'member_invites', v_invite.id::text,
          jsonb_build_object('member_id', v_member.id, 'claimed_by', v_user, 'status', 'claimed'),
          coalesce(nullif(current_setting('app.device_id', true), ''), 'server'));

  return v_member.clinic_id;
end
$$;

revoke all on function app.create_member_invite(uuid) from public, anon;
revoke all on function app.claim_member_invite(text) from public, anon;
grant execute on function app.create_member_invite(uuid) to authenticated, service_role;
grant execute on function app.claim_member_invite(text) to authenticated, service_role;

-- PostgREST-facing wrappers (schema public). Same grants as the app.* function they call.
create or replace function public.create_member_invite(p_member uuid)
returns text language sql set search_path = '' as
$$ select app.create_member_invite(p_member); $$;

create or replace function public.claim_member_invite(p_code text)
returns uuid language sql set search_path = '' as
$$ select app.claim_member_invite(p_code); $$;

revoke all on function public.create_member_invite(uuid) from public, anon;
revoke all on function public.claim_member_invite(text) from public, anon;
grant execute on function public.create_member_invite(uuid) to authenticated, service_role;
grant execute on function public.claim_member_invite(text) to authenticated, service_role;
