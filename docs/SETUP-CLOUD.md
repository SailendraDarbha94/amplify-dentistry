# Connecting AmpDent to the cloud: Supabase (Mumbai) and WhatsApp Cloud API

The founder's runbook, from an empty Supabase account to a clinic whose phones sync and whose WhatsApp
messages are sent by the server. Done in order it is one sitting (about two hours of clicking, plus the
waits for Meta business verification and template approval, which run in the background).

Nothing in the repository contains a credential. Every secret below is named, never valued; each is
entered once into Supabase, Meta, or the app. The design behind each step is in
`docs/research/03-architecture-and-data.md` (Multi-tenancy; Auth and phone OTP; Offline-first sync and
conflict policy; Integrations: WhatsApp) and the server contract in `supabase/README.md`.

## 0. What you will end up with

```
phone A (owner)  ──push/pull (PostgREST, anon key + user JWT)──>  Supabase project, ap-south-1
phone B (staff)  ──push/pull────────────────────────────────────>    Postgres + RLS (0001..0009)
                                                                     pg_cron, every minute
                                                                       -> app.invoke_whatsapp_send()
                                                                       -> Edge Function whatsapp-send ──> graph.facebook.com (Meta Cloud API)
                                                                     Edge Function whatsapp-webhook <── Meta statuses + patient replies
```

Each phone keeps working with no network; its writes queue in `sync_outbox` and drain when the engine
runs (after a write with a 5 s debounce, every 5 minutes, on app resume, or from Settings > Account >
Sync now). WhatsApp messages queued by a phone become `message_logs` rows on the server; the server sends
them and the phones pull the delivery status back.

## 1. Secrets and settings, by name

Keep this table in your password manager. The right-hand column is the only place each value lives.

| Name | What it is | Where it goes |
| --- | --- | --- |
| Supabase database password | chosen at project creation | your password manager; the CLI asks for it on `supabase link` / `db push` |
| `SUPABASE_URL` | `https://<project-ref>.supabase.co` | `apps/app_mobile/env.json` (gitignored) |
| `SUPABASE_ANON_KEY` | the anon / publishable key (Settings > API) | `apps/app_mobile/env.json`; the only key that ships in the app |
| service_role key | the legacy JWT-form secret key (Settings > API) | Vault secret `ampdent_cron_bearer` (step 5); never in the app, never in git |
| `WHATSAPP_APP_SECRET` | Meta App > App settings > Basic > App secret | `supabase secrets set` (step 6) |
| `WHATSAPP_VERIFY_TOKEN` | a random string you invent (32+ chars) | `supabase secrets set` and Meta's webhook form (steps 6, 8.5) |
| `WHATSAPP_SEND_BEARER` | optional random string; only when the project has no legacy JWT keys | `supabase secrets set` and Vault `ampdent_cron_bearer` (step 5, variant) |
| `WHATSAPP_BATCH_SIZE` | optional, default 25 | `supabase secrets set` |
| `app.runtime_config.functions_base_url` | `https://<project-ref>.supabase.co/functions/v1` | SQL, step 5 |
| Meta permanent access token | system-user token with `whatsapp_business_messaging` + `whatsapp_business_management` | typed by the clinic owner into the app (Settings > WhatsApp); stored in Vault as `whatsapp_access_token:<clinic_id>` by the `set_whatsapp_config` RPC; never on the phone |
| Phone number id, WABA id | Meta App > WhatsApp > API setup | typed into the app; stored in `clinic_whatsapp_configs` |
| Clinic verify token | any string 8-128 chars the owner invents | typed into the app; accepted by the webhook GET as an alternative to `WHATSAPP_VERIFY_TOKEN` |

`SUPABASE_URL`, `SUPABASE_ANON_KEY` and `SUPABASE_SERVICE_ROLE_KEY` are injected into every Edge Function
by the platform; you never set those three as function secrets.

## 2. Prerequisites

- Supabase account with billing enabled (the free tier pauses idle projects; a paused project stops the
  WhatsApp cron). Supabase CLI 2.116 or newer (`brew upgrade supabase`), `psql`.
- A Meta Business Manager account for the company. Business verification is required for a production
  WhatsApp number; Meta's test number works before verification (step 8.7).
- Optional, to validate the SQL and the Edge Functions on this Mac before touching the project:
  Homebrew `postgresql@17` and `deno` (`brew install postgresql@17 deno`), then
  `supabase/tests/run_local.sh`. It initdbs a throwaway cluster, applies every migration, runs the two
  smoke files and the Deno tests, and prints `ok: 38 public tables, ... migrations + smoke tests passed`
  and `ok: edge function tests passed`. No Docker.
- The app builds: `flutter pub get && dart run melos run gen` at the repo root (see `apps/app_mobile/README.md`).

## 3. Create the project

1. Dashboard > New project. Name `ampdent-prod` (later `ampdent-staging` for a second one).
2. **Region: Mumbai (ap-south-1).** Health data must stay in India (ABDM HDM policy, DPDP). The region
   cannot be changed after creation.
3. Database password: generate a long one; store it (table above).
4. Postgres version 17 (the default; `supabase/config.toml` pins `major_version = 17`).
5. Note the **project ref** (the subdomain of `https://<project-ref>.supabase.co`).
6. Settings > API: copy the anon key now (for `env.json`) and note where the service_role key is (step 5).

## 4. Enable the extensions, then push the schema

Dashboard > Database > Extensions: enable `pg_cron` (schema `pg_catalog`) and `pg_net` (schema
`extensions`). Dashboard > Integrations > Vault > Enable (installs `supabase_vault`). Do this before the
push: migration 0009 schedules the cron job only when `pg_cron` already exists, and 0008 adds the
foreign key into `vault.secrets` only when Vault is reachable (otherwise both print a NOTICE and the
fallbacks below apply).

```bash
cd /path/to/amplify-dentistry
supabase login                                  # opens the browser once
supabase link --project-ref <project-ref>       # asks for the database password
supabase db push --dry-run                      # lists 0001_schema.sql ... 0009_whatsapp_cron.sql
supabase db push
```

If the CLI insists on 14-digit timestamp prefixes, rename the nine files in order
(`20261018000001_schema.sql`, ...) without changing their sequence; `supabase db push` records each file
in `supabase_migrations.schema_migrations` and never re-runs it, so later changes are new files, never
edits to applied ones.

Check in the SQL editor:

```sql
select count(*) from pg_tables where schemaname = 'public';                      -- 38
select jobname, schedule, command from cron.job;                                 -- ampdent-whatsapp-send, * * * * *
select extname from pg_extension where extname in ('pg_cron', 'pg_net', 'supabase_vault');  -- three rows
```

If `cron.job` is empty (extensions enabled after the push), run once:

```sql
select cron.schedule('ampdent-whatsapp-send', '* * * * *', 'select app.invoke_whatsapp_send()');
```

The Drift schema on the phone and the SQL schema are kept in step by
`packages/data/test/schema_parity_test.dart` (every Drift table has a server table and vice versa, with
the named exceptions `sync_outbox`, `sync_state`, `perio_site_readings` locally and `profiles`,
`gst_rates`, `devices`, `clinic_whatsapp_configs` on the server). Run `cd packages/data && flutter test`
after any schema change on either side.

## 5. Settings the cron job reads

The minute job needs the Edge Functions base URL (in `app.runtime_config`) and a bearer token (in Vault).
SQL editor, as `postgres`:

```sql
insert into app.runtime_config (key, value)
values ('functions_base_url', 'https://<project-ref>.supabase.co/functions/v1')
on conflict (key) do update set value = excluded.value;

-- The bearer whatsapp-send accepts: the service_role key in its legacy JWT form (Settings > API >
-- Project API keys). Paste it between the quotes; the row is encrypted by Vault.
select vault.create_secret('<service_role_key>', 'ampdent_cron_bearer', 'bearer for the whatsapp-send cron');
```

Variant for a project that exposes only the new `sb_secret_...` keys (no JWT-form service_role key): the
API gateway's `verify_jwt` cannot validate those, so set `verify_jwt = false` for `whatsapp-send` in
`supabase/config.toml`, invent a long random string, store it as the Vault secret `ampdent_cron_bearer`
**and** set the same string as the function secret `WHATSAPP_SEND_BEARER` (step 6). The function checks
the bearer itself either way (`_shared/supabase.ts`, `isServiceRequest`).

To rotate the bearer later: `select vault.update_secret(id, '<new value>') from vault.secrets where name = 'ampdent_cron_bearer'`.

## 6. Function secrets and deployment

```bash
supabase secrets set WHATSAPP_APP_SECRET='<Meta app secret, step 8.4>'
supabase secrets set WHATSAPP_VERIFY_TOKEN='<random string you invent now, 32+ chars>'
# optional
supabase secrets set WHATSAPP_SEND_BEARER='<same string as the Vault secret; only with verify_jwt=false>'
supabase secrets set WHATSAPP_BATCH_SIZE=25

supabase functions deploy whatsapp-send
supabase functions deploy whatsapp-webhook
```

`supabase/config.toml` carries `verify_jwt = true` for `whatsapp-send` (cron calls it with the bearer)
and `verify_jwt = false` for `whatsapp-webhook` (Meta sends no Supabase JWT; its `X-Hub-Signature-256`
HMAC under `WHATSAPP_APP_SECRET` is the authentication). The two URLs:

- `https://<project-ref>.supabase.co/functions/v1/whatsapp-send` (POST; cron calls it)
- `https://<project-ref>.supabase.co/functions/v1/whatsapp-webhook` (Meta's callback URL)

Manual trigger and logs:

```bash
curl -X POST "https://<project-ref>.supabase.co/functions/v1/whatsapp-send" \
  -H "Authorization: Bearer <service_role_key>"
# -> {"claimed":0,"sent":0,"retried":0,"failed":0,"errors":[]}
supabase functions logs whatsapp-send
supabase functions logs whatsapp-webhook
```

You can deploy the functions before the Meta side exists; `whatsapp-send` simply finds an empty queue.

## 7. Auth: create the accounts

The app signs in with email + password or phone + one-time code; it has **no sign-up screen**. Accounts
are created in the dashboard (or later by an invite flow).

Dashboard > Authentication:

1. Providers > **Email**: enabled (default). Password minimum 10 characters. Leave *Confirm email* on;
   users you create by hand are confirmed in the next step, so no confirmation mail is needed and the app
   registers no deep-link scheme.
2. Providers > **Phone** (optional now): Supabase's built-in SMS senders are Twilio, MessageBird, Vonage
   and Textlocal. MSG91, the Indian route in the research, goes through the Send SMS Auth Hook
   (Authentication > Hooks > Send SMS > an Edge Function that calls MSG91's OTP API) and needs DLT
   registration (sender header + template, about ₹5,900 all-in). Until that paperwork is done, leave
   Phone off and sign staff in with email, or enable Phone with Twilio for your own testing.
3. Users > **Add user > Create new user**: the owner-dentist's email and a password, tick *Auto Confirm
   User*. Repeat for each staff member who will use their own phone. Copy each user's **UUID** (the
   `auth.users.id`); staff need it in step 9.3.

Settings > API also lists the JWT expiry; the default (1 hour, refreshed automatically by
`supabase_flutter`) is fine.

## 8. Meta side

1. **Business Manager** (business.facebook.com): Business settings > Security centre > Start
   verification. Upload the GST certificate / incorporation document; this gates the production number
   and the messaging tier limits. Days to weeks; everything below works on the test number meanwhile.
2. **Meta App**: developers.facebook.com > My apps > Create app > type *Business* > add the **WhatsApp**
   product. This creates (or lets you pick) a **WhatsApp Business Account (WABA)**. Copy the **WABA id**
   (WhatsApp > API setup).
3. **Phone number**: WhatsApp > API setup > Add phone number. Use a number not registered on consumer
   WhatsApp or the WhatsApp Business app (it is migrated off them). Verify by SMS or voice. Copy the
   **Phone number id** (a long numeric id, not the phone number). Set the display name (the clinic's name)
   and profile (address, category *Medical and health*).
4. **Permanent token and app secret**: Business settings > Users > System users > Add (name
   `ampdent-sender`, role Admin) > Add assets > Apps: your app, *Manage app*; WhatsApp accounts: the
   WABA, *Manage*. Then *Generate new token*: app = yours, expiry *Never*, permissions
   `whatsapp_business_messaging` and `whatsapp_business_management`. Copy it once; the clinic owner types
   it into the app in step 9.4, and it goes straight to Vault. The **App secret** is at App dashboard >
   App settings > Basic > App secret (Show); that one is `WHATSAPP_APP_SECRET` (step 6) and never enters
   the app.
5. **Webhook**: App dashboard > WhatsApp > Configuration > Webhook > Edit. Callback URL =
   `https://<project-ref>.supabase.co/functions/v1/whatsapp-webhook`, Verify token =
   `WHATSAPP_VERIFY_TOKEN`. *Verify and save* (Meta sends a GET; the function echoes `hub.challenge`).
   Under *Webhook fields* subscribe to **messages** (delivery statuses and inbound replies both arrive on
   it).
6. **Templates**: WhatsApp Manager > Account tools > Message templates > Create template, one per entry
   in `supabase/functions/_shared/templates.json` (23 entries; regenerate with
   `cd packages/messaging && dart run tool/export_templates.dart` after a catalogue change, the test
   `template_export_test.dart` fails while the file is stale). For each entry:
   - Name: the entry's `metaName` exactly (`appt_reminder_24h`). A mismatch fails every send with Meta
     error `(#132001)`.
   - Category: the entry's `category`. All are `UTILITY` except `OTP_AUTH`, which is `AUTHENTICATION`
     and uses Meta's fixed OTP layout (pick *One-time passcode*, *Copy code* button, 10-minute expiry;
     skip the body).
   - Language: English (the only language exported today; Hindi and Telugu are a later step).
   - Body: paste the entry's `metaBody` (the `{{1}}`, `{{2}}` form) and give a sample value per variable
     (a fictional patient name, your clinic name, a date, a time). Nothing clinical appears in any body,
     which is what keeps them in *Utility*; `{link}` is an authenticated URL sent as text.
   - Buttons: `APPT_REMINDER_24H` and `APPT_REMINDER_MORNING` carry a *Quick reply* button with text `1`
     (the entry's `buttons`). No URL buttons.
   - Submit. Utility templates are usually approved within minutes to hours; a rejection shows its reason
     in WhatsApp Manager.
7. **Test number**: before verification, WhatsApp > API setup offers a Meta test number and up to five
   recipient numbers; add your own phone. The test number has its own phone number id; the owner swaps
   to the real one later by re-saving in the app (step 9.4).
8. **Billing in INR**: WhatsApp Manager > Account tools > Payment settings: add a payment method with
   **INR** as the currency and the company's GSTIN. Meta bills per delivered template message (utility and
   authentication ₹0.115, marketing ₹0.8631, plus 18% GST; the dated figures are in the research). INR
   billing is mandatory for Indian WABAs since 1 Jan 2026 and non-INR Indian WABAs stop delivering from
   1 Jan 2027. One WABA can serve many clinics' numbers or each clinic can own its WABA; the schema holds
   one `phone_number_id` per clinic either way.

## 9. The phones

### 9.1 Build with the project

```bash
cd apps/app_mobile
cp env.example.json env.json            # env.json is gitignored
# fill in SUPABASE_URL and SUPABASE_ANON_KEY from Settings > API
flutter run -d "iPhone 17" --dart-define-from-file=env.json
flutter build apk --release --dart-define-from-file=env.json
flutter build ipa --dart-define-from-file=env.json
```

Without `env.json` the app is fully offline: `NoopSyncEngine`, WhatsApp opened from the phone via wa.me,
and Settings > Account shows "Cloud not configured". Everything else is identical, so the same build
flag is the only switch.

### 9.2 First phone: the owner

1. Fresh install: step 0 is the sign-in page. Sign in with the owner's email and password (or "Continue
   offline", remembered until the next sign-in).
2. The app checks `clinic_members` for the user. A new user with no server clinic goes through the
   three-step onboarding (clinic, dentist with registration number, chairs) and the link controller
   **pushes the local clinic**: `clinics` (RLS stamps `created_by`) and the owner's `clinic_members` row
   with `user_id` set, the only bootstrap insert the policies allow. Then the outbox drains and the first
   full pull runs.
3. The phone registers itself in `public.devices` (`id` = its device id, `platform`, `app_version`,
   `last_seen_at`, `is_primary` when the clinic's `device.primary` setting names it). Settings > Account
   lists the clinic's devices.
4. Settings > Account shows the link mode (*pushed local*), the sync status, the last push/pull and a
   *Sync now* button. The shell banner shows offline / N waiting / syncing / synced at hh:mm / error (tap
   retries).

### 9.3 Second phone: a staff member (manual step until the invite flow exists)

The app adds staff in Settings > Members, but a member row made on the phone has **no `user_id`**: the
app does not know which auth account that person will use. A staff member who signs in on an empty phone
before the link exists sees "No clinic yet" and would be sent to onboarding, which would create a second
clinic. So, once per staff member, in the SQL editor:

```sql
-- the member row created on the owner's phone (synced):
select id, display_name, role from public.clinic_members where clinic_id = '<clinic uuid>';
-- bind it to the account created in step 7.3:
update public.clinic_members set user_id = '<auth user uuid>' where id = '<member uuid>';
```

Then on the staff phone: install, sign in with that account; the app finds exactly one membership on an
empty device and **adopts** the clinic (records the clinic and member ids, skips onboarding, runs a full
pull, registers the device). A phone that already holds a different clinic is not merged automatically:
the app offers *keep local and sign out* or *discard local data and adopt*.

Role matters: only `ownerDentist` may save WhatsApp settings; billing tables are readable by owner,
receptionist and accountant only (RLS in `0002`).

### 9.4 WhatsApp in the app (owner only)

Settings > WhatsApp: enter Phone number id, WABA id, Display phone, Permanent access token (step 8.4),
Webhook verify token (any string 8-128 chars) > *Save to server*. The app calls the `set_whatsapp_config`
RPC; the token goes to Vault, the row keeps the secret id, and the page then shows *configured, enabled*
with the queue depth and failures in the last 24 h (`get_whatsapp_status`). The owner can pause sending
without re-entering the token; re-saving with a new token rotates the Vault secret in place.

While the status is *enabled*, every send from the app (appointment confirmation, reminder, invoice
link, recall...) is queued for the server (`CloudQueueMessagingProvider`, `_provider = cloud_api`, after
the DPDP opt-in check) and the patient timeline shows queued / sent / delivered / read / failed as the
pulls bring the statuses back. Otherwise, or while loading, the message opens in WhatsApp on the phone
(`_provider = deeplink`) and the server never touches that row.

## 10. End-to-end check

1. Owner phone: Settings > WhatsApp saved, status *configured, enabled*.
2. Book an appointment for a test patient whose phone is one of Meta's allowed test recipients and send the
   confirmation. Within a minute the row in `public.message_logs` goes `queued` -> `sent` (with
   `provider_message_id`), then `delivered` and `read` as the webhook reports; the timeline on the phone
   follows on the next pull.
3. Reply `1` on that phone to a reminder: the appointment flips to `confirmed` (audit row
   `device_id = whatsapp-webhook`), and the phones see it on their next pull.
4. Make a change on the staff phone (complete a procedure); the owner phone shows it after its next sync.
5. Watch the pipeline:

```sql
select id, template_code, status, attempts, next_attempt_at, last_error from public.message_logs
 where provider = 'cloud_api' order by created_at desc limit 20;
select * from app.whatsapp_send_queue;                                        -- due rows (empty when idle)
select * from cron.job_run_details order by start_time desc limit 10;
select status_code, content::text from net._http_response order by created desc limit 5;  -- pg_net responses
select id, platform, app_version, last_seen_at, is_primary from public.devices;
```

Common failures: `(#132001)` template name or language not approved under that WABA; `(#131026)` the
recipient is not a WhatsApp user or blocked the number (permanent, the row goes `failed`); `(#190)` token
invalid or revoked, re-enter it in the app; webhook `401 bad signature` means `WHATSAPP_APP_SECRET` is not
the app secret of the app that owns the webhook; `cron.job_run_details` shows runs but `net._http_response`
is empty means `functions_base_url` or the Vault bearer is missing (`app.invoke_whatsapp_send()` prints a
NOTICE). Retries back off 1, 2, 4, ... minutes; the sixth failure is final. `Sync error` on the phone with
a 4xx: the server rejected a row (RLS, constraint); the row's `sync_outbox.last_error` names it, and the
table and its children stay blocked until the row is fixed or the server accepts it (there is no repair
screen yet).

## 11. How sync reconciles (what to expect between phones)

Per table, in `packages/data/lib/src/sync/sync_tables.dart`:

- **Last writer wins by server `updated_at`** for clinic, members, chairs, settings, catalogue, drugs,
  labs, patients, appointments, visits, treatment plans and lines, procedures, findings, clinical notes,
  image and implant records, estimates, DPDP data consents, invoices, adjustments, recalls, lab cases,
  licences and message logs. A local row with an unpushed edit is never overwritten until it has been
  pushed, so a status transition made chairside (procedure completed, consent withdrawn, note signed)
  reaches the other phones, and the server still refuses row deletes.
- **Append-only** (insert when absent, never overwrite) for the tables the server itself refuses to
  update: tooth states, medical histories, procedure consents, prescriptions, payments, ledger entries,
  sterilisation cycles, audit events, and perio exams (snapshots; the phone rebuilds its
  `perio_site_readings` index for every pulled exam).
- Invoice numbers are minted by the server on first push and replace the phone's `DRAFT-` number on the
  next pull. WhatsApp delivery state is server-owned; a phone can only cancel a still-queued row.
- Each phone pulls only its clinic (RLS and the `clinic_id` filter agree) and pages by
  `(updated_at, id)`; images sync as metadata only.

## 12. Checklist

- [ ] Project in ap-south-1, Postgres 17, database password stored
- [ ] `pg_cron`, `pg_net`, Vault enabled; `supabase db push` clean; 38 public tables; `cron.job` has `ampdent-whatsapp-send`
- [ ] `app.runtime_config.functions_base_url` set; Vault secret `ampdent_cron_bearer` created
- [ ] `WHATSAPP_APP_SECRET`, `WHATSAPP_VERIFY_TOKEN` set; both functions deployed; `curl` to `whatsapp-send` returns the zero report
- [ ] Owner and staff accounts created and auto-confirmed; UUIDs noted
- [ ] Meta: business verification started, WABA, phone number, system-user token, webhook verified,
      `messages` field subscribed, 23 templates approved under their `metaName`, INR payment method
- [ ] `env.json` on the build machine; owner signed in; clinic pushed; device listed
- [ ] Staff member rows bound to their `user_id`; staff phone adopted the clinic
- [ ] Owner saved the WhatsApp settings; test message delivered; reply `1` confirmed an appointment

## 13. Not yet built (known gaps you will meet)

- No invite flow: binding a staff account to its member row is the SQL step in 9.3.
- No repair screen for a row the server permanently rejects; it is visible in `sync_outbox.last_error`
  and blocks its table until fixed.
- No `last_seen_at` heartbeat beyond (re)linking, and no connectivity plugin: offline is detected when a
  sync fails, and retried on the 5-minute interval, on resume and after the next local write.
- The server's own audit trigger rows (`device_id = 'server'`) are pulled alongside the phone's audit rows,
  so a synced write appears twice in the local audit log.
- WhatsApp templates are English only; inbound replies other than a confirmation are logged and dropped;
  Meta's per-message cost is kept raw in `provider_payload`, not totalled.
- Phone OTP needs an SMS provider on the project (step 7.2); WhatsApp OTP for staff login is a later step.
- `MessageLog` carries the provider inside `variables._provider` rather than a first-class field.
- Image bytes are not synced (metadata only); Supabase Storage upload is a later step.
