-- 0012_unlink_member.sql
-- Owner-side undo of a staff binding (the counterpart of 0010's claim): a member who lost their phone or
-- changed number is unbound from their auth account so the owner can mint a fresh invite code, without
-- the SQL editor.
--   app.unlink_member(p_member)  owner RPC: sets clinic_members.user_id to null for a member row of the
--   caller's clinic that is bound to an account other than the caller's own, retires any live invite
--   code for that member, and leaves an explicit audit row. The clinic_members update is audited by the
--   row trigger (actor = the owner) as every other member edit is.
-- The unbound account stops seeing the clinic at its next request (app.current_clinic_ids is derived
-- from clinic_members.user_id); nothing that account recorded is touched.

create or replace function app.unlink_member(p_member uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user    uuid := (select auth.uid());
  v_member  record;
begin
  if v_user is null then
    raise exception 'sign in to unlink a member' using errcode = 'insufficient_privilege';
  end if;

  select m.id, m.clinic_id, m.user_id
    into v_member
    from public.clinic_members as m
   where m.id = p_member
     for update;

  if v_member.id is null or not app.has_role(v_member.clinic_id, 'ownerDentist') then
    raise exception 'only the clinic owner may unlink member %', p_member
      using errcode = 'insufficient_privilege';
  end if;
  if v_member.user_id is null then
    raise exception 'member % has no account to unlink', p_member using errcode = 'invalid_parameter_value';
  end if;
  if v_member.user_id = v_user then
    raise exception 'you cannot unlink your own account' using errcode = 'invalid_parameter_value';
  end if;

  update public.clinic_members
     set user_id = null
   where id = v_member.id;

  update public.member_invites
     set expires_at = now()
   where member_id = v_member.id
     and claimed_at is null
     and expires_at > now();

  insert into public.audit_events (clinic_id, actor_id, action, entity_type, entity_id, after, device_id)
  values (v_member.clinic_id, v_user, 'statusChange', 'clinic_members', v_member.id::text,
          jsonb_build_object('member_id', v_member.id, 'status', 'unlinked'),
          coalesce(nullif(current_setting('app.device_id', true), ''), 'server'));

  return true;
end
$$;

revoke all on function app.unlink_member(uuid) from public, anon;
grant execute on function app.unlink_member(uuid) to authenticated, service_role;

-- PostgREST-facing wrapper (schema public). Same grants as the app.* function it calls.
create or replace function public.unlink_member(p_member uuid)
returns boolean language sql set search_path = '' as
$$ select app.unlink_member(p_member); $$;

revoke all on function public.unlink_member(uuid) from public, anon;
grant execute on function public.unlink_member(uuid) to authenticated, service_role;
