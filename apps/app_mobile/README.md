# ampdent_mobile

AmpDent, the dentist's chairside app for Android and iOS. Dental-only clinic
management: patients, appointment book, odontogram and perio chart, findings
and procedures, treatment plan with versioned estimate, consent with e-sign,
clinical notes and photos, prescriptions, GST invoices and ledger,
procedure-triggered recall, lab cases, sterilisation and licence log, export
and audit. Offline-first on a local SQLite store; with a Supabase project
configured the store syncs through `SupabaseSyncEngine` and WhatsApp
messages are queued for the Cloud API worker, otherwise sends open WhatsApp
on the phone through a deep link.

The product and domain rules live in the repo root `CLAUDE.md` and in
`docs/research/` (start with `02-product-spec.md`). This file is only about
running, testing and the layout of this package.

## Run

Everything happens from the repo root first (pub workspace):

```bash
export PATH="/opt/homebrew/bin:$PATH"   # Flutter 3.47 / Dart 3.13
flutter pub get                          # resolves the whole workspace
dart run melos run gen                   # generates packages/data/lib/src/db/app_database.g.dart
```

`app_database.g.dart` is gitignored, so `gen` is mandatory on a fresh clone
before anything in this app compiles.

```bash
cd apps/app_mobile
flutter run -d "iPhone 17"               # any booted simulator / connected device
flutter build ios --simulator --no-codesign
flutter build apk --debug
```

To run against a Supabase project pass the configuration file:

```bash
cp env.example.json env.json          # env.json is gitignored
# fill in SUPABASE_URL and SUPABASE_ANON_KEY (Settings > API of the project)
flutter run -d "iPhone 17" --dart-define-from-file=env.json
```

iOS plugins are resolved with Swift Package Manager (no CocoaPods step).
Android needs the SDK platform the Flutter Gradle plugin asks for; the first
build downloads it.

A fresh install opens the three-step onboarding (clinic, dentist with
registration number, chairs); the app then lands on the Today tab. With the
cloud configured a step 0 comes first: sign in (email and password, or phone
and a one-time code) or continue offline.

## Cloud vs offline

| | `env.json` absent or empty | `env.json` present |
|---|---|---|
| Sync engine | `NoopSyncEngine`; the outbox fills, banner says "Not synced yet - N changes waiting" | `SupabaseSyncEngine` once signed in and the device is linked (with this install's `DeviceInfo` for the `devices` heartbeat after each push); banner shows offline / N waiting / syncing / synced at hh:mm / error (tap to retry) / *N changes need attention* (tap opens the repair screen); `SyncScheduler` runs after writes (5 s debounce), every 5 min and on resume; `CloudLifecycle` asks it to probe reachability (`Reachability`, one request to `/auth/v1/health`) on resume and every 60 s in the foreground, never in the background |
| Sign-in | not offered; Settings > Account says "Cloud not configured" | step 0 of a fresh install (skippable: "Continue offline", remembered in `sync_state`), or later from Settings > Account; "I have an invite code" takes a staff member's code, claimed right after sign-in |
| Clinic link | none | after sign-in `ClinicLinkController` first claims a pending invite code (`claim_member_invite` binds the member row to the account), then applies the `RemoteClinicLinker` rules: local clinic and no server clinic -> push; server clinic and empty phone -> adopt (full pull, onboarding skipped); same clinic on both -> link only; different clinics -> chooser (keep local and sign out, or discard local and adopt); nothing anywhere -> the sign-in page offers *join with an invite code* or *Create a new clinic*, and the router's sign-in gate holds until one is chosen (never a silent second clinic). The device is registered in `public.devices`, primary when `device.primary` names it |
| Staff invites | not offered | Settings > Members > *Invite to sign in* (owner, linked phone) calls `create_member_invite` and shows the 8-character code with its 72-hour expiry, copy and share (`share_plus`; the share text carries the code and the `ampdent://app/invite/<code>` link, which opens the app on the sign-in page with the code prefilled through the `/invite/:code` route); *Unlink account* calls `unlink_member` so a member who lost their phone or number can be invited again; the code is never stored on the phone |
| Sync repair | none needed | Settings > Account & sync > *Changes needing attention* (`/settings/account/sync-repair`) lists the rows the server rejected for good and the rows blocked behind them (`SyncRepairService` of the running engine); *Retry* re-queues the chain and syncs, *Discard my change* (confirmed) drops the local change and restores the server's copy where one exists |
| Audit log | all local rows | More > Audit log hides the server's own trigger rows (`device_id = 'server'`) unless *Include server entries* is on |
| WhatsApp | deep link (wa.me) from the phone, logged with `MessageLog.provider = deeplink` | Settings > WhatsApp reads `get_whatsapp_status`; the owner saves the Meta credentials through `set_whatsapp_config` (token to Vault, never stored locally) and can pause sending; while enabled the `CloudQueueMessagingProvider` queues rows (`MessageLog.provider = cloudApi`, `optInReason` = the DPDP rule that allowed the send) for the `whatsapp-send` Edge Function and the patient timeline shows queued / sent / delivered / read / failed |

Everything is testable without a project: `test/cloud/fake_supabase.dart`
fakes GoTrue, PostgREST and the RPCs (WhatsApp and member invites) behind
`package:http`'s `MockClient`, and `AppTestEnv.open(cloudClient: ...)` wires
it in (with the reachability probe stubbed to null; pass `reachability:` to
test it over a `MockClient`). Two fake-clock rules for widget tests that
touch sync: open and close the `AppTestEnv` (and any scratch database) in
`setUp` / `tearDown`, never inside the `testWidgets` body, and read outbox
counts with a query rather than awaiting a drift stream's `.first` (drift's
teardown runs through zero timers that the widget test's fake clock only
fires while frames are pumped; a database opened in the body can stall the
adopt path for good). The founder's step list
for a real project (Mumbai, `ap-south-1`) and a Meta app is
`docs/SETUP-CLOUD.md`. The four
tabs are Today, Patients, Schedule and More; every feature registers its own
routes in `lib/features/<feature>/routes.dart` and `lib/core/router.dart`
spreads them into the `StatefulShellRoute`.

## Test

```bash
cd apps/app_mobile
flutter test                             # widget and unit tests (test/)
flutter test integration_test -d "iPhone 17"   # on-device smoke test
dart run melos run test                  # from the repo root: every package
dart run melos run analyze               # from the repo root: every package
```

Widget tests run on a 360x800 surface with the Ahem test font against an
in-memory database. Two kinds of harness exist:

- `test/helpers/test_env.dart` (`AppTestEnv`) mounts the full app, router
  and shell, exactly as `main.dart` does.
- `test/features/**/*_env.dart` / `feature_harness.dart` mount one feature's
  routes with stubs for their neighbours so a feature's tests compile and
  fail independently of the others.

Run all test files in one `flutter test` invocation: concurrent `flutter
test` processes in this directory race on `build/native_assets`.

`integration_test/smoke_test.dart` boots the real app over an in-memory
database on the simulator and walks onboarding, a new patient, the
odontogram (age-default seeding, a caries finding on 16 MO), a scaling
planned from the catalogue and completed (which raises a hygiene recall), an
invoice issued from the chart and paid in cash, and then asserts the Today
KPI tiles. The flow itself lives in `integration_test/smoke_flow.dart` and
also runs as an ordinary widget test (`test/smoke_flow_test.dart`, 360x800,
Ahem font) on every `flutter test`. It uses polling waits
(`integration_test/smoke_support.dart`), not `pumpAndSettle`, because
indeterminate progress indicators never settle, and it scrolls only as far
as a target needs (realigning widgets to the viewport edge leaves pages
scrolled).

## Code generation

Only `packages/data` uses codegen (Drift). After any table change there:

```bash
dart run melos run gen                   # repo root
# or
cd packages/data && dart run build_runner build
```

The schema version is 1 with no migrations yet; a table change also needs a
`MigrationStrategy.onUpgrade` step in `packages/data/lib/src/db/app_database.dart`.

## Where data lives

| What | Where | Notes |
|---|---|---|
| Clinic, patients, clinical rows, invoices, audit log, sync outbox | `ampdent.db.sqlite` in the app documents directory (`path_provider`'s `getApplicationDocumentsDirectory`) via `drift_flutter` | opened by `AppDatabase.open('ampdent.db')` in `main.dart`; clinical rows are append-only (status transitions, never row deletes) |
| Device id | `sync_state` table (`device_id`), with the clinic setting `device.id` as a legacy fallback | resolved by `bootstrapSession` on launch; the clinic setting syncs between devices, `sync_state` does not |
| Active member | `settings` table of the clinic (`session.activeMemberId`) | resolved by `bootstrapSession` on launch |
| Clinic link, pull watermarks, last sync, "continue offline" choice | `sync_state` table | written by `RemoteClinicLinker`, `SupabaseSyncEngine` and `ContinueOfflineNotifier` |
| Supabase session | `supabase_flutter`'s own store (shared preferences) | only when `env.json` is present; sign-out clears it and keeps every local row |
| Meta access token | nowhere on the device | sent once to `set_whatsapp_config`, which stores it in Supabase Vault |
| Clinical photos | files under the app documents directory, compressed JPEG with EXIF kept | paths stored on `ClinicalImage` rows |
| Consent signatures and PDFs | files under the app documents directory | hashes stored on `ConsentRecord` |
| Licence documents | `licences/` under the app documents directory | referenced from `Licence` rows |
| Exports (patient record bundle, clinic export, sterilisation log) | the temporary directory, then handed to the share sheet | nothing is kept after sharing |
| Message log | `message_logs` table | every deep-link send and every Cloud API queue row, never clinical content in a body; the server writes delivery status back through sync |

Tests use `AppDatabase.inMemory()`; nothing touches the file system unless a
test injects a real directory (see `test/features/notes/photo_store_test.dart`).

## Layout

```
lib/main.dart                 database, session bootstrap, ProviderScope, MaterialApp.router
lib/core/                     providers (database, repositories, messaging, fonts, clock),
                              router, shell, session, AppStrings hook, formatting, logging,
                              cloud: config, auth, clinic link, member invites, sync/messaging
                              switch, sync repair providers, WhatsApp RPCs, sync banner,
                              device info, reachability probe, lifecycle hooks
lib/features/<feature>/       routes.dart + pages, providers, models and services per feature
                              (auth: sign-in, account and sync repair; settings: WhatsApp page,
                              member invite sheet; export: audit log with the server toggle)
integration_test/             on-device smoke test
test/                         widget and unit tests (see above); test/cloud/ runs against the fake Supabase
```

Conventions: Riverpod 3 (`Notifier`, `AsyncNotifier`, `Provider`), go_router,
plain immutable Dart classes, strings through `AppStrings`/`MobileStrings`,
`Logger` from `ampdent_core` (no `print`), files under ~400 lines.
