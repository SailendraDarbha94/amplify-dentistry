# supabase/

Postgres schema, Row Level Security, triggers and storage policies for AmpDent. It is the server-side
mirror of the Dart entities in `packages/core/lib/src/entities/` and of the Drift schema in `packages/data`.
SQL only; no Dart lives here.

```
migrations/0001_schema.sql     tables, domains, indexes, counter tables (schema app)
migrations/0002_rls.sql        membership helpers + policies on every table
migrations/0003_functions.sql  audit trigger, updated_at touch, hard-delete guard, invoice/patient numbering
migrations/0004_storage.sql    private bucket clinic-media + object policies
migrations/0005_invoice_dentist_and_number.sql  treating dentist frozen on issued invoices; minted invoice numbers immutable
seed.sql                       intentionally empty (catalogue/drug seeds ship in the app)
tests/local_supabase_stub.sql  auth/storage shims so the migrations run on plain PostgreSQL
tests/smoke.sql                behavioural checks (isolation, roles, numbering, append-only, audit)
tests/run_local.sh             initdb a scratch cluster and run everything above
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
`auth.users`, `auth.uid()`, `storage.buckets`/`storage.objects`/`storage.foldername()` and Supabase's default
grants), then the migrations, `seed.sql`, and `tests/smoke.sql`. Never apply the stub to a real project.

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
| `createdAt` / `updatedAt` | `created_at` / `updated_at timestamptz not null default now()`; `updated_at` touched by trigger |

Column names are the snake_case of the Dart field names (`historyOfPresentIllness` -> `history_of_present_illness`,
`reminder24hSentAt` -> `reminder_24h_sent_at`). Dart `toJson()` keys are camelCase; the data layer maps them.

Extra columns not in the Dart entities: `clinics.region` (default `'in'`, for later UK/EU/GCC pinning),
`clinic_members.user_id` (link to `auth.users`, drives RLS), `profiles` (one row per auth user),
`gst_rates` (per-clinic GST rate history per `GstClass`, required by CLAUDE.md), and `audit_events.created_at`.

## Tables

Platform: `profiles`, `clinics`, `clinic_members`, `chairs`, `gst_rates`, `catalog_items` (clinic_id nullable:
null = platform-wide row), `drugs` (same), `labs`.

Tenant (clinic_id not null): `patients`, `appointments`, `visits`, `tooth_state_records`, `findings`,
`clinical_notes`, `medical_histories`, `perio_exams`, `treatment_plans`, `treatment_plan_lines`, `procedures`,
`estimates`, `consent_records`, `data_consents`, `invoices`, `payments`, `adjustments`, `ledger_entries`,
`prescriptions`, `image_records`, `lab_cases`, `implant_records`, `recalls`, `message_logs`,
`sterilisation_cycles`, `licences`, `audit_events`.

Internal (`app` schema, not exposed): `app.invoice_counters (clinic_id, fy_start, last_value)`,
`app.patient_counters (clinic_id, last_value)`.

Secondary indexes: `patients (clinic_id, phone)`, unique `patients (clinic_id, patient_number)`,
`appointments (clinic_id, starts_at)`, `procedures (clinic_id, patient_id, status)`, unique
`invoices (clinic_id, number)`, `recalls (clinic_id, due_at, status)`,
`audit_events (clinic_id, entity_type, entity_id, occurred_at)`, plus `(clinic_id, patient_id, ...)` on every
patient-scoped table and `clinic_members (user_id)` for the RLS lookup.

## RLS model

- RLS is enabled on every public table; `anon` has all table privileges revoked.
- Membership lives in `clinic_members (user_id, clinic_id, role, is_active)`, unique per `(clinic_id, user_id)`.
  Helpers are `STABLE SECURITY DEFINER` with `search_path = ''`: `app.current_clinic_ids()`,
  `app.clinic_ids_with_role(variadic roles)`, `app.has_role(clinic, variadic roles)` (RPC checks only),
  `app.clinic_has_members(clinic)`. `auth.uid()` is always wrapped as `(select auth.uid())` and every policy
  predicate has the shape `clinic_id in (select app.<set_returning_helper>(...))`, so the planner evaluates the
  membership lookup once per statement as an InitPlan rather than once per row (Supabase RLS performance guidance).
- Every policy is `to authenticated`. Tenant tables: `select`/`insert`/`update` where
  `clinic_id in (select app.current_clinic_ids())`.
- **No DELETE policy** on clinical or financial tables (`procedures`, `findings`, `tooth_state_records`,
  `consent_records`, `data_consents`, `clinical_notes`, `perio_exams`, `prescriptions`, `invoices`, `payments`,
  `ledger_entries`, `audit_events`, `message_logs` and the rest). A `delete` through the API affects zero rows. A
  `BEFORE DELETE` trigger (`app.prevent_hard_delete`) additionally raises for append-only tables even for the
  service role.
- Financial tables (`invoices`, `payments`, `adjustments`, `ledger_entries`): select for `ownerDentist`,
  `receptionist`, `accountant`; insert/update for `ownerDentist`, `receptionist`, via
  `clinic_id in (select app.clinic_ids_with_role(...))`. Associate dentists do not see money.
- `audit_events`: select + insert for members (clients log `view`/`export`/`print`); no update, no delete.
- `clinics`: any signed-in user may insert one; a user may then insert themselves as `ownerDentist` only while
  the clinic has no members (`app.clinic_has_members`). Owners manage `clinic_members` and clinic settings.
- `catalog_items` / `drugs`: rows with `clinic_id is null` are readable by all members and writable by nobody
  through the API; clinic rows are tenant-scoped, owners may delete them.
- `profiles`: self only.
- Role names in policies are the Dart `ClinicRole.name` values (`ownerDentist`, not `owner_dentist`).

## Triggers and functions (0003)

- `app.touch_updated_at()` on every table with `updated_at`.
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
- No rate limiting or `pg_cron` jobs (reminders, recall due-date sweeps run from the service layer).
- Auditing covers insert/update only; the few deletable config tables (`chairs`, `labs`, clinic `catalog_items`,
  `drugs`) are not audited on delete because `AuditAction` has no `delete` member.
- Platform-wide catalogue rows are not seeded; the app writes its own copy per clinic from
  `package:ampdent_terminology`.
