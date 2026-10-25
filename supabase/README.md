# supabase/

Postgres schema, Row Level Security, triggers, storage policies, the sync contract and the WhatsApp
delivery pipeline (SQL + two Deno Edge Functions) for AmpDent. The schema is the server-side mirror of the
Dart entities in `packages/core/lib/src/entities/` and of the Drift schema in `packages/data`. No Dart lives
here. Connecting a real project: `docs/SETUP-CLOUD.md`.

```
migrations/0001_schema.sql     tables, domains, indexes, counter tables (schema app)
migrations/0002_rls.sql        membership helpers + policies on every table
migrations/0003_functions.sql  audit trigger, updated_at touch, hard-delete guard, invoice/patient numbering
migrations/0004_storage.sql    private bucket clinic-media + object policies
migrations/0005_invoice_dentist_and_number.sql  treating dentist frozen on issued invoices; minted invoice numbers immutable
migrations/0006_immutable_rows_bootstrap_parity.sql  no UPDATE on append-only tables; bootstrap pinned to clinics.created_by; Drift parity (settings table, renamed/added columns)
migrations/0007_estimate_binding_rx_snapshot.sql  Drift v4 parity: estimate plan binding, declined-estimate reason, prescription patient snapshot
migrations/0008_sync_and_whatsapp.sql  server-owned updated_at + pull indexes, devices, message_logs delivery columns and replay guards,
                               clinic_whatsapp_configs (token in Vault), send queue + claim/result/status/reply RPCs and public wrappers
migrations/0009_whatsapp_cron.sql  app.runtime_config, pg_cron + pg_net, app.invoke_whatsapp_send() every minute
config.toml                    CLI config: Postgres 17, Edge Function entries (verify_jwt per function)
functions/deno.json            import map + tasks for the functions (deno test / deno check)
functions/_shared/templates.json  template export written by packages/messaging/tool/export_templates.dart
functions/_shared/{templates,meta,signature,supabase}.ts  loader, Cloud API payload/send/parse, HMAC, service client
functions/whatsapp-send/       claims a batch, sends via graph.facebook.com, records results (cron-driven)
functions/whatsapp-webhook/    GET verification, POST statuses + inbound "1" replies (HMAC-verified)
seed.sql                       intentionally empty (catalogue/drug seeds ship in the app)
tests/local_supabase_stub.sql  auth/storage/vault/pg_net shims so the migrations run on plain PostgreSQL
tests/smoke.sql                behavioural checks (isolation, roles, numbering, append-only, bootstrap, parity columns, audit)
tests/smoke_sync_whatsapp.sql  sync columns, devices, WhatsApp config/queue/webhook RPCs, replay guards
tests/run_local.sh             initdb a scratch cluster, run everything above, then the Deno tests when deno is installed
```

## Applying

Region: create the project in **ap-south-1 (Mumbai)**. The ABDM Health Data Management Policy and the
DPDP rules both require health data to stay in India; pick the region at project creation, it cannot be
changed later.

```bash
supabase login
supabase link --project-ref <ref>        # the Mumbai project
supabase db push                         # applies migrations/*.sql in filename order
supabase db push --dry-run               # to see what would run
```

`supabase db push` records each file in `supabase_migrations.schema_migrations` and never re-runs it; add new
files (`0005_...sql`) rather than editing applied ones. If your CLI version insists on 14-digit timestamp
prefixes, rename the files (`20261018000001_schema.sql`, ...) without changing their order.

Local verification without Docker (what `tests/run_local.sh` does): it starts a throwaway PostgreSQL 17
cluster on port 54329, applies `tests/local_supabase_stub.sql` (roles `anon`/`authenticated`/`service_role`,
`auth.users`, `auth.uid()`, `storage.buckets`/`storage.objects`/`storage.foldername()`, a plaintext stand-in
for Supabase Vault (`vault.secrets`, `vault.decrypted_secrets`, `vault.create_secret/update_secret`), a
recording stand-in for `net.http_post`, and Supabase's default grants), then the migrations, `seed.sql`,
`tests/smoke.sql` and `tests/smoke_sync_whatsapp.sql`, and finally `deno test` under `functions/` when
`deno` is on PATH (`brew install deno`; `AMPDENT_SKIP_DENO=1` skips it). pg_cron and pg_net are not
available on a plain cluster: 0009 prints a NOTICE and skips the extension and the cron job; the invoker
function is still tested through the pg_net shim. Never apply the stub to a real project.

```bash
supabase/tests/run_local.sh              # needs postgresql@17 from Homebrew
AMPDENT_KEEP=1 supabase/tests/run_local.sh   # keep the cluster running for inspection with psql -p 54329
```

The scratch server listens on TCP only (`unix_socket_directories` is empty), so a long scratch path cannot hit
macOS's 103-byte Unix-socket path limit. Docker-based `supabase start` / `supabase db lint` are not required.

## Conventions (match `packages/core`)

| Dart | SQL |
| --- | --- |
| `String id` (client UUID v4) | `uuid primary key default gen_random_uuid()` (default is a convenience; clients always send ids) |
| `clinicId` | `clinic_id uuid not null references clinics(id)`, indexed, filtered by RLS |
| `Money` (paise) | `bigint` columns suffixed `_paise` (`fee_paise`, `grand_total_paise`) |
| `ToothId` | `app.tooth_key` = `text` with `CHECK (value ~ '^[1-8][1-8](\+[0-9]+)?$')` (FDI storage key, `11+1` supernumerary) |
| `List<ToothId> teeth` | `jsonb` array of tooth keys, `CHECK (app.is_tooth_key_array(teeth))` |
| `SurfaceSet` | `app.surface_set` = `text` `CHECK ('^[MODFLVRW]{0,8}$')`, sorted canonical faces |
| enums | `text` with `CHECK (col in ('camelCaseName', ...))` listing the Dart `.name` values exactly (`inChair`, `exemptHealthcare`, `voided`) |
| value-object lists / maps (`lines`, `phases`, `allergies`, `sites`, `bpe`, `variables`, `external_codes`) | `jsonb` |
| `DateTime` | `timestamptz`; pure dates (`date_of_birth`, `expiry_date`, `schedule_effective_from`) are `date` |
| `createdAt` / `updatedAt` | `created_at` / `updated_at timestamptz not null default now()`; `updated_at` is **server-assigned** on insert and update (0008), the device value is ignored |

Column names are drift's snake_case of the Dart field names, exactly as the Drift tables in `packages/data` spell
them (`historyOfPresentIllness` -> `history_of_present_illness`, `reminder24hSentAt` -> `reminder24h_sent_at`; the
digit does not get its own underscore). Dart `toJson()` keys are camelCase; the data layer maps them. The Dart side is
the contract: `packages/data/test/schema_parity_test.dart` parses these migrations and fails when a Drift table has no
`create table public.<name>` here or a tenant table here has no Drift table (allowed exceptions: local-only
`sync_outbox` and `perio_site_readings`; server-only `profiles` and `gst_rates`).

Extra columns not in the Dart entities: `clinics.region` (default `'in'`, for later UK/EU/GCC pinning),
`clinics.created_by` (inserting auth user; gates owner bootstrap), `clinic_members.user_id` (link to `auth.users`,
drives RLS), `drugs.clinic_id` (nullable; the Dart `Drug` entity does not carry it yet), `profiles` (one row per auth
user), `gst_rates` (per-clinic GST rate history per `GstClass`, required by CLAUDE.md), and `audit_events.created_at`.
Data-layer columns the entities lack but the Drift tables have: `treatment_plan_lines.removed_at`,
`perio_exams.bpe_furcation`, and the `settings` table.

## Tables

Platform: `profiles`, `clinics`, `clinic_members`, `chairs`, `gst_rates`, `catalog_items` (clinic_id nullable:
null = platform-wide row), `drugs` (same), `labs`.

Tenant (clinic_id not null): `patients`, `appointments`, `visits`, `tooth_state_records`, `findings`,
`clinical_notes`, `medical_histories`, `perio_exams`, `treatment_plans`, `treatment_plan_lines`, `procedures`,
`estimates`, `consent_records`, `data_consents`, `invoices`, `payments`, `adjustments`, `ledger_entries`,
`prescriptions`, `image_records`, `lab_cases`, `implant_records`, `recalls`, `message_logs`,
`sterilisation_cycles`, `licences`, `audit_events`, `settings` (key/value per clinic, primary key
`(clinic_id, setting_key)`, `value_json jsonb`; the device's `settings` table, so outbox rows targeting it have a
server table. It is not audited by trigger because it has no `id`; the client audits settings changes itself).

Server-side only (no Drift table; `packages/data/test/schema_parity_test.dart` lists them under
`serverOnlyTables`): `profiles`, `gst_rates`, `devices` (0008), `clinic_whatsapp_configs` (0008).

Internal (`app` schema, not exposed): `app.invoice_counters (clinic_id, fy_start, last_value)`,
`app.patient_counters (clinic_id, last_value)`, `app.runtime_config (key, value)` (0009, service role only),
view `app.whatsapp_send_queue` (0008, service role only).

Secondary indexes: `(clinic_id, updated_at)` on every tenant table (the pull cursor, 0008),
`patients (clinic_id, phone)`, unique `patients (clinic_id, patient_number)`,
`appointments (clinic_id, starts_at)`, `procedures (clinic_id, patient_id, status)`, unique
`invoices (clinic_id, number)`, `recalls (clinic_id, due_at, status)`,
`audit_events (clinic_id, entity_type, entity_id, occurred_at)`, plus `(clinic_id, patient_id, ...)` on every
patient-scoped table and `clinic_members (user_id)` for the RLS lookup.

## RLS model

- RLS is enabled on every public table; `anon` has all table privileges revoked.
- Membership lives in `clinic_members (user_id, clinic_id, role, is_active)`, unique per `(clinic_id, user_id)`.
  Helpers are `STABLE SECURITY DEFINER` with `search_path = ''`: `app.current_clinic_ids()`,
  `app.clinic_ids_with_role(variadic roles)`, `app.has_role(clinic, variadic roles)` (RPC checks only),
  `app.clinic_has_members(clinic)`, `app.clinic_created_by(clinic)`. `auth.uid()` is always wrapped as `(select auth.uid())` and every policy
  predicate has the shape `clinic_id in (select app.<set_returning_helper>(...))`, so the planner evaluates the
  membership lookup once per statement as an InitPlan rather than once per row (Supabase RLS performance guidance).
- Every policy is `to authenticated`. Tenant tables: `select`/`insert`/`update` where
  `clinic_id in (select app.current_clinic_ids())`.
- **No UPDATE policy** on the append-only tables `payments`, `ledger_entries`, `consent_records`, `prescriptions`,
  `medical_histories`, `tooth_state_records` (0006) nor on `audit_events`. The data layer never rewrites these rows
  (a correction is a new row: refund, adjustment, new consent, new prescription, new snapshot, new tooth state), so an
  `update` through the API affects zero rows. Invoices keep their update policy because status, `amount_paid` and
  the minted number legitimately change.
- **No DELETE policy** on clinical or financial tables (`procedures`, `findings`, `tooth_state_records`,
  `consent_records`, `data_consents`, `clinical_notes`, `perio_exams`, `prescriptions`, `invoices`, `payments`,
  `ledger_entries`, `audit_events`, `message_logs` and the rest). A `delete` through the API affects zero rows. A
  `BEFORE DELETE` trigger (`app.prevent_hard_delete`) additionally raises for append-only tables even for the
  service role.
- Financial tables (`invoices`, `payments`, `adjustments`, `ledger_entries`): select for `ownerDentist`,
  `receptionist`, `accountant`; insert/update for `ownerDentist`, `receptionist`, via
  `clinic_id in (select app.clinic_ids_with_role(...))`. Associate dentists do not see money.
- `audit_events`: select + insert for members (clients log `view`/`export`/`print`); no update, no delete.
- `clinics`: any signed-in user may insert one, and the row must carry them as `created_by` (default
  `auth.uid()`, spoofing is rejected). Only that user may then insert themselves as `ownerDentist`, and only while
  the clinic has no members (`app.clinic_created_by`, `app.clinic_has_members`, both `SECURITY DEFINER` because the
  caller cannot yet read the clinic row under RLS). Owners manage `clinic_members` and clinic settings.
- `catalog_items` / `drugs`: rows with `clinic_id is null` are readable by all members and writable by nobody
  through the API; clinic rows are tenant-scoped, owners may delete them.
- `profiles`: self only.
- `devices` (0008): members read their clinic's devices; a member inserts only a row with their own
  `user_id`; the device's user or an owner updates it; no delete. One `is_primary` row per clinic (partial
  unique index).
- `clinic_whatsapp_configs` (0008): owners may select; there is no insert/update/delete policy at all. Writes
  go through `set_whatsapp_config` / `set_whatsapp_enabled` (SECURITY DEFINER, owner check inside).
- Role names in policies are the Dart `ClinicRole.name` values (`ownerDentist`, not `owner_dentist`).

## Triggers and functions (0003)

- `app.touch_updated_at()` on every table with `updated_at`, `before insert or update` since 0008: the
  server clock is the only source of `updated_at`.
- `app.audit_row()` (`SECURITY DEFINER`) after insert/update on every tenant table and `clinics`: writes
  `audit_events` with `actor_id = (select auth.uid())` (nil uuid for the service role), `action` =
  `create` / `update` / `statusChange` / `softDelete` (when `status` becomes `deleted`), `before`/`after` as
  `jsonb`, `device_id` from the per-request setting `app.device_id` (set it with
  `set_config('app.device_id', '<device>', true)` or a PostgREST header hook) else `'server'`. Platform-wide
  rows (`catalog_items` / `drugs` with `clinic_id null`) belong to no tenant and are skipped.
- `app.prevent_hard_delete()` before delete on append-only tables.
- `app.financial_year_start(at, tz)` -> 1 April of the Indian FY in the clinic's time zone.
- `app.next_invoice_number(clinic, fy_start)` -> `INV/2026-27/0001`; counter upsert takes a row lock, so
  concurrent callers never share a number. `app.next_patient_number(clinic)` -> `P-00001`.
- `app.invoices_assign_number()` before insert/update on `invoices`: when a synced row has a `DRAFT-` number and a
  non-draft status, the real number is minted in place. Offline clients therefore never mint numbers.
- RPC wrappers for the client: `public.mint_invoice_number(p_clinic uuid, p_issued_at timestamptz default now())`
  (billing roles) and `public.mint_patient_number(p_clinic uuid)` (any member).
- 0008 guards against phones replaying stale rows (the pusher upserts whole local rows):
  `app.message_logs_before_write()` copies `variables._provider` into `provider` and, for `cloud_api` rows
  written by `authenticated`, keeps the server's delivery columns and accepts only `queued -> cancelled`;
  `app.appointments_keep_confirmed()` keeps `confirmed` when a phone replays `scheduled`.

## Sync contract (0008)

Transport is PostgREST through the Supabase client; `packages/data/lib/src/sync/` holds the engine. The
server guarantees:

- **IDs are client UUIDs; `updated_at` is server time.** Every insert/update sets `updated_at = now()`
  (transaction start). Clients send whatever they hold; it is overwritten.
- **Pull cursor per table:** `select * from <table> where clinic_id = :clinic and (updated_at > :wm or
  (updated_at = :wm and id > :last_id)) order by updated_at, id limit N`, served by the
  `<table>_clinic_updated_idx` index. Because `now()` is the transaction start, a long transaction can
  commit a row whose `updated_at` is earlier than rows already pulled; pull with a small overlap (a few
  seconds behind the watermark) and upsert idempotently.
- **Push is an upsert** (`on conflict (id)`) of the local row; RLS decides who may write what, triggers
  mint invoice numbers, assign `updated_at`, audit, and apply the replay guards above. Append-only tables
  have no UPDATE policy, so a replayed upsert of an existing row there affects nothing.
- **Devices:** the app registers its device in `public.devices` (`id` = the `device_id` it writes into
  `audit_events` and sets as `app.device_id`), heartbeats `last_seen_at` / `app_version`, and the owner
  flags the clinic's primary device.
- **Conflict policy** (research table): last-writer-wins by server `updated_at` for demographics and notes;
  append-only elsewhere; server-minted invoice numbers; and now server-owned WhatsApp delivery state and
  webhook confirmations.

## WhatsApp delivery (0008, 0009, functions/)

```
phone (CloudQueueMessagingProvider)            server                                   Meta
  MessageLog status=queued,                     message_logs.provider = 'cloud_api'
  variables._provider = cloud_api   --push-->   (trigger copies _provider)
                                                pg_cron (every minute)
                                                  -> app.invoke_whatsapp_send()  --pg_net-->  Edge Function whatsapp-send
                                                       claim_whatsapp_batch(): claimed_at, attempts+1,
                                                       next_attempt_at = now()+10 min, token from Vault
                                                                                              POST graph.facebook.com/v21.0/{phone_number_id}/messages
                                                       record_whatsapp_result(sent|retry|failed)
                                                whatsapp-webhook  <--POST statuses / inbound--  Meta
                                                  apply_whatsapp_status(wamid, sent|delivered|read|failed)
                                                  confirm_appointment_from_reply(phone, '1', phone_number_id, context wamid)
  <--pull-- message_logs (status, provider_message_id, sent_at, delivered_at, error), appointments (confirmed)
```

- A claim never changes `status` (the Dart `MessageStatus` has no `sending`; a pulled unknown status would
  throw on every phone). `claimed_at` + the `next_attempt_at` lease make the claim atomic and idempotent;
  an expired lease (crashed worker) makes the row due again. `retry` backs off 1, 2, 4, ... minutes; the
  sixth failure is final. Permanent Meta errors (131026 undeliverable, 132001 template missing, ...) fail
  immediately; see `functions/_shared/meta.ts`.
- Statuses from the webhook move forward only (`sent < delivered < read`; `failed` applies unless already
  `read`); duplicates and out-of-order deliveries are no-ops. `provider_payload` keeps Meta's pricing and
  conversation objects.
- Inbound `1` / `yes` from a patient's, guardian's or alternate number confirms that clinic's next
  `scheduled` appointment within -2 h / +3 days (clinic resolved from `metadata.phone_number_id`, patient
  pinned by the replied-to wamid when present). Audited with `device_id = 'whatsapp-webhook'`.
- `deeplink` rows (sent from the dentist's phone via wa.me) are never touched by the server.
- The token lives in Supabase Vault under `whatsapp_access_token:<clinic_id>`; the table holds the secret
  id; only `claim_whatsapp_batch()` (service role) ever reads the decrypted value. Config changes are
  audited as `ClinicWhatsappConfig` / `settingsChange` without the token.

### RPCs (schema `public`, thin wrappers over `app.*`)

| RPC | Who | Returns |
| --- | --- | --- |
| `set_whatsapp_config(p_clinic, p_phone_number_id, p_waba_id, p_display_phone, p_access_token, p_verify_token)` | owner | void; token to Vault |
| `set_whatsapp_enabled(p_clinic, p_enabled)` | owner | void |
| `get_whatsapp_status(p_clinic)` | member | jsonb `{configured, enabled, phoneNumberId, wabaId, displayPhone, updatedAt, queuedCount, failedLast24h}` |
| `claim_whatsapp_batch(p_limit default 25)` | service role | rows `(id, clinic_id, patient_id, template_code, category, to_phone, variables, attempts, patient_language, phone_number_id, waba_id, access_token)` |
| `record_whatsapp_result(p_id, p_status 'sent'/'retry'/'failed', p_provider_message_id, p_error)` | service role | boolean |
| `apply_whatsapp_status(p_provider_message_id, p_status, p_timestamp, p_error, p_payload)` | service role | boolean (known id) |
| `confirm_appointment_from_reply(p_phone, p_text, p_phone_number_id, p_context_message_id)` | service role | appointment uuid or null |
| `whatsapp_verify_token_matches(p_token)` | service role | boolean |

Function secrets and deployment steps: `docs/SETUP-CLOUD.md`.

## Storage (0004)

Bucket `clinic-media`, private, 50 MiB per object, image/PDF/DICOM/STL types. Object paths are
`<clinic_id>/<patient_id>/<file>`; members of the clinic in the first path segment may select/insert/update,
only `ownerDentist` may delete. The app reads with signed URLs. `image_records.file_path` stores the object path.

## PowerSync (later)

PowerSync reads Postgres through logical replication and needs, when we get there:

1. `wal_level = logical` (Supabase default) and a publication listing the tenant tables:
   ```sql
   create publication powersync for table
     public.clinics, public.clinic_members, public.chairs, public.gst_rates, public.catalog_items, public.drugs,
     public.labs, public.patients, public.appointments, public.visits, public.tooth_state_records, public.findings,
     public.clinical_notes, public.medical_histories, public.perio_exams, public.treatment_plans,
     public.treatment_plan_lines, public.procedures, public.estimates, public.consent_records, public.data_consents,
     public.invoices, public.payments, public.adjustments, public.ledger_entries, public.prescriptions,
     public.image_records, public.lab_cases, public.implant_records, public.recalls, public.message_logs,
     public.sterilisation_cycles, public.licences, public.audit_events;
   ```
2. A replication role: `create role powersync_role with replication bypassrls login password '...'` plus
   `grant select on all tables in schema public to powersync_role`.
3. Sync Streams keyed on `clinic_id` whose predicates mirror the RLS predicates exactly (each device syncs its
   clinic's active patients and the current fortnight's schedule; images sync as metadata).
4. Uploads replay through the Supabase client, so RLS gates every write and `app.invoices_assign_number()` mints
   numbers on first sync. Domains (`app.tooth_key`, `app.surface_set`) replicate as `text`.

## Intentionally not in this schema yet

- ABDM: `patients.abha_number` / `abha_address` and `clinic_members.hpr_id` are plain columns; no HIP/HIU
  tables, consent artefacts, link tokens or field-level encryption.
- Card data: nowhere. `payments` holds `gateway_token`, `card_last4` (4 digits, CHECKed) and `card_brand` only.
- No publication, replication role or Sync Stream definitions (see PowerSync above).
- No custom access-token hook; RLS reads `clinic_members` directly, which is authoritative.
- No `branches`, `fee_schedules`, `bmw_register`, `abdm_consent_artefacts` tables; no inventory, payroll,
  insurance or CDT.
- The only `pg_cron` job is the WhatsApp sender (0009); reminder scheduling and recall due-date sweeps
  still run on the clinic's primary device and only *queue* messages.
- No inbound-message table: webhook replies other than a confirmation are counted in the function log and
  dropped (Meta's policy keeps clinical conversation out of WhatsApp anyway).
- Auditing covers insert/update only; the few deletable config tables (`chairs`, `labs`, clinic `catalog_items`,
  `drugs`) are not audited on delete because `AuditAction` has no `delete` member.
- Platform-wide catalogue rows are not seeded; the app writes its own copy per clinic from
  `package:ampdent_terminology`.
