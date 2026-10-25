# amplify-dentistry

A dental-only clinic management product: Flutter apps for dentists (Android and iOS) to run clinics, patients, appointments, clinical records, billing and patient communication, India first, offline-first, WhatsApp-native, with a web front desk later.

## Status

October 2026: the first on-device build. The research phase is complete
([docs/research](docs/research/README.md), start with the
[executive summary](docs/research/00-executive-summary.md)) and the Flutter
monorepo now analyzes clean, passes every package's tests, builds for the iOS
simulator and as a debug APK, and runs an end-to-end smoke test on the
iPhone 17 simulator.

What works now, all offline on the phone's SQLite store:

- **Foundations**: `ampdent_core` (FDI tooth model, surfaces, mixed dentition,
  `Money` in paise, GST classes, every entity), `ampdent_terminology`
  (procedure catalogue, ICD-10 K00-K14, drug master with schedules, consent
  templates, recall rules, GST state codes), `ampdent_data` (Drift store,
  repositories, append-only audit log, sync outbox, first-open seeding),
  `ampdent_chart_engine` (odontogram and perio chart, golden-tested),
  `ampdent_documents` (invoice, estimate, prescription, consent, lab slip
  and record-export PDFs with content hashes), `ampdent_ui` (theme, shared
  widgets, `AppStrings`), `ampdent_messaging` (templates, opt-in ledger,
  outbox and deep-link providers) and the mirrored Supabase schema with RLS
  and audit triggers (not yet pushed to a project).
- **The app** (`apps/app_mobile`): onboarding, patients with guardian rules
  and DPDP consents, multi-chair appointment book with waitlist and
  WhatsApp confirmations, odontogram with findings, tooth states and
  procedures (pre-op radiograph guard, stage tracking), perio chart with BPE,
  treatment plans with phases and versioned estimates, procedure consent with
  e-sign, clinical notes with versions, medical history red flags and photos,
  prescriptions with allergy and schedule checks, GST invoices, payments,
  refunds and ledger, procedure-triggered recall and incomplete-treatment
  follow-up, lab cases with slips, sterilisation and licence log, patient and
  clinic export with the audit trail, and a Today dashboard with the five
  KPIs.

Also in place, waiting for a project: **sync and WhatsApp.** `ampdent_data`
ships `SupabaseSyncEngine` (outbox push in foreign-key order, keyset pull
per table with last-writer-wins or append-only policies), a `SyncScheduler`
and `RemoteClinicLinker`; the `supabase/` migrations add server-owned
`updated_at`, a `devices` table, the WhatsApp config (token in Vault), the
send queue and the `whatsapp-send` / `whatsapp-webhook` Edge Functions;
`ampdent_messaging` has the Meta Cloud API payload and webhook shapes and the
`CloudQueueMessagingProvider`; and the app signs in with Supabase Auth
(email or phone OTP, or "continue offline"), links the device to its clinic
(push, adopt or choose), shows real sync states in the shell banner, lets
the owner enter the Meta credentials under Settings > WhatsApp and switches
patient messaging to the Cloud API queue when it is enabled. All of it is
tested against fakes; **no Supabase project exists yet.** Connecting one is
the founder's next step: `docs/SETUP-CLOUD.md` walks through the project
(Mumbai, `ap-south-1`), the extensions, the migrations, the Meta app and the
`env.json` the app reads.

Not yet: server-minted invoice numbers in the app (local numbers are `DRAFT-`
prefixed and device-coded until the first sync renames them), encryption of
the local SQLite file (planned: SQLCipher through drift's encrypted
`NativeDatabase`, once PowerSync compatibility is confirmed; until then the
store relies on the OS sandbox and device lock), localisation (Hindi and
Telugu strings are deferred; every string already goes through `AppStrings`),
MSG91 SMS, ABDM, payments gateway, patient app, web front desk. See
[docs/research/02-product-spec.md](docs/research/02-product-spec.md) for the
build order.

### Running it

```bash
export PATH="/opt/homebrew/bin:$PATH"
flutter pub get                 # repo root
dart run melos run gen          # Drift codegen (packages/data); required on a fresh clone
dart run melos run analyze      # every package
dart run melos run test         # every package
cd apps/app_mobile && flutter run -d "iPhone 17"
# with a Supabase project: cp env.example.json env.json, fill it in, then
cd apps/app_mobile && flutter run -d "iPhone 17" --dart-define-from-file=env.json
```

Per-app details (tests, codegen, where data lives) are in
[apps/app_mobile/README.md](apps/app_mobile/README.md).

## Planned shape

- `apps/app_mobile`: Flutter, the dentist's phone (chart, note, prescribe, bill, next visit)
- `packages/chart_engine`: pure `dart:ui` odontogram, perio grid and image annotation
- `packages/core`, `data`, `documents`, `terminology`, `fhir_abdm`, `messaging`, `ui`
- `services/api`: NestJS for WhatsApp, payment and ABDM webhooks
- `services/capture_bridge`: Windows agent that ships RVG exports to the cloud
- `supabase/`: migrations, row-level security, audit triggers
- `web/`: Next.js public site and patient link pages

See [docs/research/03-architecture-and-data.md](docs/research/03-architecture-and-data.md) for the reasoning and the full layout.

## Toolchain

Flutter 3.47 stable (Dart 3.13), Xcode 26, Android SDK 36, Node 22 and pnpm 10 are installed on the development Mac. `flutter doctor` passes on every check.
