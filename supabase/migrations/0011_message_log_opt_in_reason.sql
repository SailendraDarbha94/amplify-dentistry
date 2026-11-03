-- 0011_message_log_opt_in_reason.sql
-- The DPDP opt-in reason that allowed a message to be sent becomes a server column, so the trail
-- replicates with the row instead of staying on the phone that queued it.
--   1. message_logs.opt_in_reason text (nullable): the opt-in rule the phone recorded when it queued the
--      row (a MessagingPolicy reason such as 'transactional' or 'appointment_reminders_consent'); never
--      clinical content. Rows sent from the server (cloud_api) and deep-link rows carry it alike.
--   2. Backfill from the legacy variables._opt_in_reason stamp that older builds wrote next to _provider.
--   3. app.message_logs_before_write() copies the stamp into the column when the column is null, exactly
--      as it does for provider, so a phone that still stamps variables keeps a consistent server row.
-- The phones' sync engine pushes the column from this migration on (SyncTable 'message_logs' no longer
-- lists it as local-only) and pulls it back like any other message_logs column.

-- ---------------------------------------------------------------------------
-- 1. Column
-- ---------------------------------------------------------------------------

alter table public.message_logs
  add column opt_in_reason text check (opt_in_reason is null or length(opt_in_reason) between 1 and 120);

comment on column public.message_logs.opt_in_reason is
  'DPDP opt-in rule the phone recorded when it queued the message (MessagingPolicy reason); null for rows queued before it was recorded.';

-- ---------------------------------------------------------------------------
-- 2. Backfill from the legacy variables stamp
-- ---------------------------------------------------------------------------

update public.message_logs
   set opt_in_reason = left(variables ->> '_opt_in_reason', 120)
 where opt_in_reason is null
   and coalesce(variables ->> '_opt_in_reason', '') <> '';

-- ---------------------------------------------------------------------------
-- 3. Before-write trigger: the stamp fills the column when the column is empty
-- ---------------------------------------------------------------------------

create or replace function app.message_logs_before_write()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_stamped text := new.variables ->> '_provider';
  v_reason  text := new.variables ->> '_opt_in_reason';
begin
  if v_stamped in ('deeplink', 'cloud_api', 'sms_gateway') then
    new.provider := v_stamped;
  end if;
  if new.opt_in_reason is null and coalesce(v_reason, '') <> '' then
    new.opt_in_reason := left(v_reason, 120);
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
