# ampdent_mobile

AmpDent, the dentist's chairside app for Android and iOS. Dental-only clinic
management: patients, appointment book, odontogram and perio chart, findings
and procedures, treatment plan with versioned estimate, consent with e-sign,
clinical notes and photos, prescriptions, GST invoices and ledger,
procedure-triggered recall, lab cases, sterilisation and licence log, export
and audit. Offline-first on a local SQLite store; WhatsApp sends go through a
deep link today and are logged for the sync stage.

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

iOS plugins are resolved with Swift Package Manager (no CocoaPods step).
Android needs the SDK platform the Flutter Gradle plugin asks for; the first
build downloads it.

A fresh install opens the three-step onboarding (clinic, dentist with
registration number, chairs); the app then lands on the Today tab. The four
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
| Device id and active member | `settings` table of the clinic (`device.id`, `session.activeMemberId`) | resolved by `bootstrapSession` on launch; in memory until onboarding completes |
| Clinical photos | files under the app documents directory, compressed JPEG with EXIF kept | paths stored on `ClinicalImage` rows |
| Consent signatures and PDFs | files under the app documents directory | hashes stored on `ConsentRecord` |
| Licence documents | `licences/` under the app documents directory | referenced from `Licence` rows |
| Exports (patient record bundle, clinic export, sterilisation log) | the temporary directory, then handed to the share sheet | nothing is kept after sharing |
| Message log | `message_logs` table | every WhatsApp/SMS deep-link send is logged, never clinical content in a body |

Tests use `AppDatabase.inMemory()`; nothing touches the file system unless a
test injects a real directory (see `test/features/notes/photo_store_test.dart`).

## Layout

```
lib/main.dart                 database, session bootstrap, ProviderScope, MaterialApp.router
lib/core/                     providers (database, repositories, messaging, fonts, clock),
                              router, shell, session, AppStrings hook, formatting, logging
lib/features/<feature>/       routes.dart + pages, providers, models and services per feature
integration_test/             on-device smoke test
test/                         widget and unit tests (see above)
```

Conventions: Riverpod 3 (`Notifier`, `AsyncNotifier`, `Provider`), go_router,
plain immutable Dart classes, strings through `AppStrings`/`MobileStrings`,
`Logger` from `ampdent_core` (no `print`), files under ~400 lines.
