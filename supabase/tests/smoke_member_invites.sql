-- smoke_member_invites.sql
-- Behavioural checks for 0010 (staff invite codes). Runs after smoke.sql and reuses its fixtures:
-- clinic A (owner user 1, associate user 3), clinic B (owner user 2). Adds two staff accounts (users 4
-- and 5) that have no membership yet, and two member rows created on the owner's phone without user_id.

\set ON_ERROR_STOP on
\set QUIET on

insert into auth.users (id, phone) values
  ('44444444-4444-4444-4444-444444444444', '+919000000004'),  -- receptionist, joins clinic A by code
  ('55555555-5555-5555-5555-555555555555', '+919000000005');  -- visiting specialist, second code

-- Owner creates the member rows (as the phone does: no user_id) and mints a code -------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
set local app.device_id = 'phone-u1';

insert into public.clinic_members (id, clinic_id, display_name, role, phone)
values ('aaaaaaaa-0000-0000-0000-00000000000c', 'aaaaaaaa-0000-0000-0000-000000000001', 'Priya', 'receptionist', '+919000000004'),
       ('aaaaaaaa-0000-0000-0000-00000000000d', 'aaaaaaaa-0000-0000-0000-000000000001', 'Dr. Visiting', 'visitingSpecialist', '+919000000005');

create temporary table invite_codes (label text primary key, code text not null) on commit preserve rows;

insert into invite_codes (label, code)
values ('priya-first', public.create_member_invite('aaaaaaaa-0000-0000-0000-00000000000c'));

do $$
declare
  c text;
  r record;
begin
  select code into c from invite_codes where label = 'priya-first';
  if c !~ '^[A-HJKMNP-Z2-9]{8}$' then raise exception 'invite code must be 8 unambiguous characters, got %', c; end if;

  select * into r from public.member_invites where code = c;
  if r.id is null then raise exception 'owner must see the invite row'; end if;
  if r.clinic_id <> 'aaaaaaaa-0000-0000-0000-000000000001' then raise exception 'invite clinic mismatch'; end if;
  if r.created_by <> '11111111-1111-1111-1111-111111111111' then raise exception 'created_by should be the owner'; end if;
  if r.expires_at < now() + interval '71 hours' or r.expires_at > now() + interval '73 hours' then
    raise exception 'invite should expire in 72 hours, got %', r.expires_at;
  end if;
  if r.claimed_at is not null then raise exception 'fresh invite must not be claimed'; end if;
end
$$;

-- Minting again retires the first code: only one live code per member.
insert into invite_codes (label, code)
values ('priya', public.create_member_invite('aaaaaaaa-0000-0000-0000-00000000000c'));

do $$
declare
  n integer;
begin
  select count(*) into n from public.member_invites
  where member_id = 'aaaaaaaa-0000-0000-0000-00000000000c' and claimed_at is null and expires_at > now();
  if n <> 1 then raise exception 'exactly one live code per member expected, got %', n; end if;
  if (select code from invite_codes where label = 'priya') = (select code from invite_codes where label = 'priya-first') then
    raise exception 'a new mint must produce a new code';
  end if;
end
$$;

-- A member who already has an account cannot be invited (the owner's own row).
do $$
begin
  perform public.create_member_invite('aaaaaaaa-0000-0000-0000-00000000000a');
  raise exception 'inviting a member who is already signed in should have been rejected';
exception when invalid_parameter_value then null;
end
$$;

-- The code is never written to the audit trail.
do $$
declare
  n integer;
begin
  select count(*) into n from public.audit_events
  where after::text like '%' || (select code from invite_codes where label = 'priya') || '%'
     or after::text like '%' || (select code from invite_codes where label = 'priya-first') || '%';
  if n <> 0 then raise exception 'invite codes must not appear in audit rows, found %', n; end if;
end
$$;

insert into invite_codes (label, code)
values ('visiting', public.create_member_invite('aaaaaaaa-0000-0000-0000-00000000000d'));
commit;

-- An associate (not owner) can neither mint nor read invites ------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
do $$
begin
  perform public.create_member_invite('aaaaaaaa-0000-0000-0000-00000000000c');
  raise exception 'an associate must not create invites';
exception when insufficient_privilege then null;
end
$$;
do $$
declare
  n integer;
begin
  select count(*) into n from public.member_invites;
  if n <> 0 then raise exception 'an associate must not read invites, saw %', n; end if;
end
$$;
-- The owner of another clinic cannot mint for clinic A's member either.
set local request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
do $$
begin
  perform public.create_member_invite('aaaaaaaa-0000-0000-0000-00000000000c');
  raise exception 'another clinic''s owner must not create invites for clinic A';
exception when insufficient_privilege then null;
end
$$;
commit;

-- User 4 (no membership anywhere) claims the code -------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '44444444-4444-4444-4444-444444444444';
set local app.device_id = 'phone-u4';

do $$
declare
  n integer;
begin
  select count(*) into n from public.clinics;
  if n <> 0 then raise exception 'user 4 must see no clinic before claiming, saw %', n; end if;
  select count(*) into n from public.member_invites;
  if n <> 0 then raise exception 'user 4 must not read invite rows, saw %', n; end if;
end
$$;

-- Unknown and malformed codes are rejected without leaking anything.
do $$
begin
  perform public.claim_member_invite('ZZZZZZZZ');
  raise exception 'an unknown code should have been rejected';
exception when invalid_parameter_value then null;
end
$$;
do $$
begin
  perform public.claim_member_invite('abc');
  raise exception 'a malformed code should have been rejected';
exception when invalid_parameter_value then null;
end
$$;

-- The retired first code no longer works.
do $$
begin
  perform public.claim_member_invite((select code from invite_codes where label = 'priya-first'));
  raise exception 'a retired code should have been rejected';
exception when invalid_parameter_value then null;
end
$$;

-- Lower case with a hyphen in the middle still matches (codes are read out over the phone).
do $$
declare
  c text := (select code from invite_codes where label = 'priya');
  clinic uuid;
  n integer;
  v uuid;
begin
  clinic := public.claim_member_invite(lower(substr(c, 1, 4) || '-' || substr(c, 5)));
  if clinic <> 'aaaaaaaa-0000-0000-0000-000000000001' then raise exception 'claim should return clinic A, got %', clinic; end if;

  select user_id into v from public.clinic_members where id = 'aaaaaaaa-0000-0000-0000-00000000000c';
  if v <> '44444444-4444-4444-4444-444444444444' then raise exception 'member row should now be bound to user 4, got %', v; end if;

  select count(*) into n from public.clinics;
  if n <> 1 then raise exception 'user 4 must now see clinic A, saw %', n; end if;
  select count(*) into n from public.patients;
  if n < 1 then raise exception 'user 4 (receptionist) must now see clinic A patients, saw %', n; end if;

  select count(*) into n from public.audit_events
  where entity_type = 'clinic_members' and entity_id = 'aaaaaaaa-0000-0000-0000-00000000000c'
    and action = 'update' and actor_id = '44444444-4444-4444-4444-444444444444' and device_id = 'phone-u4';
  if n <> 1 then raise exception 'the binding should be audited under the claiming user, got %', n; end if;
  select count(*) into n from public.audit_events
  where entity_type = 'member_invites' and action = 'statusChange' and after ->> 'status' = 'claimed'
    and after ->> 'member_id' = 'aaaaaaaa-0000-0000-0000-00000000000c';
  if n <> 1 then raise exception 'the claim should leave one member_invites audit row, got %', n; end if;
  select count(*) into n from public.audit_events where after::text like '%' || c || '%';
  if n <> 0 then raise exception 'the claimed code must not appear in audit rows'; end if;
end
$$;

-- A second claim of the same code is rejected.
do $$
begin
  perform public.claim_member_invite((select code from invite_codes where label = 'priya'));
  raise exception 'a used code should have been rejected';
exception when invalid_parameter_value then null;
end
$$;

-- User 4 is already a member of clinic A: a second row's code is refused for this account.
do $$
begin
  perform public.claim_member_invite((select code from invite_codes where label = 'visiting'));
  raise exception 'a member of the clinic must not claim a second row in it';
exception when insufficient_privilege then null;
end
$$;
commit;

-- Owner view of the claimed invite, and a mismatched claim by another account -------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
do $$
declare
  r record;
begin
  select * into r from public.member_invites where code = (select code from invite_codes where label = 'priya');
  if r.claimed_by <> '44444444-4444-4444-4444-444444444444' or r.claimed_at is null then
    raise exception 'owner should see the invite as claimed by user 4';
  end if;
end
$$;
-- The API cannot rewrite an invite (no update policy: zero rows affected).
do $$
begin
  update public.member_invites set expires_at = now() + interval '10 years'
  where code = (select code from invite_codes where label = 'visiting');
  if found then raise exception 'member_invites must not be updatable through the API'; end if;
end
$$;
commit;

-- Expiry: the owner's second member code, aged past 72 h by the clock, is refused --------------------
update public.member_invites set expires_at = now() - interval '1 minute'
where code = (select code from invite_codes where label = 'visiting');

begin;
set local role authenticated;
set local request.jwt.claim.sub = '55555555-5555-5555-5555-555555555555';
do $$
begin
  perform public.claim_member_invite((select code from invite_codes where label = 'visiting'));
  raise exception 'an expired code should have been rejected';
exception when invalid_parameter_value then null;
end
$$;
do $$
declare
  n integer;
begin
  select count(*) into n from public.clinics;
  if n <> 0 then raise exception 'user 5 must still see no clinic, saw %', n; end if;
end
$$;
commit;

-- A fresh code for the same member works for user 5; a code for a bound member is a mismatch for user 2 --
begin;
set local role authenticated;
set local request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
insert into invite_codes (label, code)
values ('visiting-2', public.create_member_invite('aaaaaaaa-0000-0000-0000-00000000000d'));
commit;

begin;
set local role authenticated;
set local request.jwt.claim.sub = '55555555-5555-5555-5555-555555555555';
do $$
declare
  clinic uuid;
begin
  clinic := public.claim_member_invite((select code from invite_codes where label = 'visiting-2'));
  if clinic <> 'aaaaaaaa-0000-0000-0000-000000000001' then raise exception 'claim should return clinic A'; end if;
end
$$;
commit;

-- Mismatch: the member row is bound to user 5; a code minted directly (service path) for it cannot be
-- claimed by user 2.
insert into public.member_invites (clinic_id, member_id, code, created_by)
values ('aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-00000000000d', 'MSMATCH2',
        '11111111-1111-1111-1111-111111111111');

begin;
set local role authenticated;
set local request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
do $$
begin
  perform public.claim_member_invite('MSMATCH2');
  raise exception 'a code for a member bound to another account should have been rejected';
exception when insufficient_privilege then null;
end
$$;
commit;

-- Signed-out callers cannot claim.
begin;
set local role anon;
do $$
begin
  perform public.claim_member_invite('MSMATCH2');
  raise exception 'anon must not be able to call claim_member_invite';
exception when insufficient_privilege then null;
end
$$;
commit;

-- 0012: the owner unlinks a bound member; the account loses the clinic and a new code can be minted --
begin;
set local role authenticated;
set local request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
do $$
begin
  perform public.unlink_member('aaaaaaaa-0000-0000-0000-00000000000c');
  raise exception 'an associate must not unlink members';
exception when insufficient_privilege then null;
end
$$;
commit;

begin;
set local role authenticated;
set local request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
set local app.device_id = 'phone-u1';
-- The owner's own row is refused: nobody locks themselves out.
do $$
begin
  perform public.unlink_member('aaaaaaaa-0000-0000-0000-00000000000a');
  raise exception 'the owner must not unlink their own account';
exception when invalid_parameter_value then null;
end
$$;
-- Priya (bound to user 4) is unlinked: user_id cleared, audited under the owner, no code in the row.
do $$
declare
  ok boolean;
  v uuid;
  n integer;
begin
  ok := public.unlink_member('aaaaaaaa-0000-0000-0000-00000000000c');
  if not ok then raise exception 'unlink_member should return true'; end if;
  select user_id into v from public.clinic_members where id = 'aaaaaaaa-0000-0000-0000-00000000000c';
  if v is not null then raise exception 'user_id should be null after unlink, got %', v; end if;
  select count(*) into n from public.audit_events
  where entity_type = 'clinic_members' and entity_id = 'aaaaaaaa-0000-0000-0000-00000000000c'
    and action = 'statusChange' and after ->> 'status' = 'unlinked'
    and actor_id = '11111111-1111-1111-1111-111111111111' and device_id = 'phone-u1';
  if n <> 1 then raise exception 'the unlink should leave one statusChange audit row, got %', n; end if;
  select count(*) into n from public.member_invites
  where member_id = 'aaaaaaaa-0000-0000-0000-00000000000c' and claimed_at is null and expires_at > now();
  if n <> 0 then raise exception 'no live code may survive an unlink, found %', n; end if;
end
$$;
-- A second unlink has nothing to do.
do $$
begin
  perform public.unlink_member('aaaaaaaa-0000-0000-0000-00000000000c');
  raise exception 'unlinking an unbound member should have been rejected';
exception when invalid_parameter_value then null;
end
$$;
-- The member can be invited again (0010 refused this while the row was bound).
insert into invite_codes (label, code)
values ('priya-again', public.create_member_invite('aaaaaaaa-0000-0000-0000-00000000000c'));
commit;

-- User 4 no longer sees clinic A.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '44444444-4444-4444-4444-444444444444';
do $$
declare
  n integer;
begin
  select count(*) into n from public.clinics;
  if n <> 0 then raise exception 'user 4 must not see clinic A after the unlink, saw %', n; end if;
end
$$;
commit;

-- The owner of another clinic and anon cannot unlink clinic A's members.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
do $$
begin
  perform public.unlink_member('aaaaaaaa-0000-0000-0000-00000000000d');
  raise exception 'another clinic''s owner must not unlink clinic A members';
exception when insufficient_privilege then null;
end
$$;
commit;
begin;
set local role anon;
do $$
begin
  perform public.unlink_member('aaaaaaaa-0000-0000-0000-00000000000d');
  raise exception 'anon must not be able to call unlink_member';
exception when insufficient_privilege then null;
end
$$;
commit;

drop table invite_codes;

select 'smoke member invites ok' as result;
