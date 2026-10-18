# amplify-dentistry

Dental-only clinic management platform. Flutter monorepo (pub workspace + Melos). India first, offline-first, WhatsApp-native, cash/UPI/GST billing, no insurance plumbing in the core. The research that drives every decision lives in `docs/research/` (start with `00-executive-summary.md`; the build order is in `02-product-spec.md`; the data model and stack in `03-architecture-and-data.md`).

## Layout

```
apps/app_mobile/        ampdent_mobile      Flutter app: Android + iOS, the dentist's phone
packages/core/          ampdent_core        pure Dart domain model (NO Flutter imports)
packages/terminology/   ampdent_terminology seed vocabularies: procedure catalogue, ICD-10 K00-K14, drugs, consent templates, recall rules
packages/chart_engine/  ampdent_chart_engine dart:ui odontogram + perio chart widgets (depends only on core + Flutter)
packages/data/          ampdent_data        Drift/SQLite local store, repositories, audit log, sync interface
packages/documents/     ampdent_documents   PDF generation (pdf/printing): invoice, estimate, Rx, consent, lab slip, record export
packages/ui/            ampdent_ui          theme + shared widgets
packages/messaging/     ampdent_messaging   WhatsApp/SMS templates, opt-in ledger, outbox, provider interfaces
supabase/               SQL migrations, RLS policies, audit triggers (mirror of the Drift schema)
services/               later: NestJS webhooks (WhatsApp, payments, ABDM), Windows capture bridge
docs/research/          the research corpus; cite it, do not duplicate it
```

Dependency direction: `core` <- `terminology` <- `data`/`documents`/`chart_engine`/`messaging` <- `app_mobile`. Never import a sibling package's `src/` directly; use its barrel file (`package:ampdent_core/ampdent_core.dart`).

## Commands

```bash
flutter pub get                 # at the repo root; resolves the whole workspace
dart run melos run analyze      # analyze every package
dart run melos run test         # test every package with a test/ dir
dart run melos run gen          # build_runner where needed (packages/data)
cd packages/<p> && flutter test # one package
cd apps/app_mobile && flutter run -d "iPhone 17"
```

Adding a dependency: edit the member `pubspec.yaml`, then run `flutter pub get` from the repo root. Prefer the dependencies already declared; do not add state-management, routing or codegen libraries beyond `flutter_riverpod`, `go_router`, `drift`/`drift_dev`/`build_runner`.

## Non-negotiable domain rules

- **FDI (ISO 3950) is the stored tooth key.** `ToothId` in `ampdent_core` is canonical; Universal and Palmer are display conversions. Never store Universal numbers.
- **Surfaces are canonical faces** (`M D O F L V R W` as `ToothSurface`), rendered as O/I, B/F, L/P by tooth type and arch at display time. Stored as a sorted surface string.
- **Clinical rows are append-only.** Procedures, findings, tooth states, perio measurements, notes, consents, invoices and payments are never hard-deleted; use status transitions and `AuditEvent`. Only `deleted` as a status, never a row delete.
- **Mixed dentition is first-class.** An arch position can hold a primary and a permanent tooth at once, each with its own state and history.
- **Money is `Money` (integer paise).** Never doubles for currency.
- **Every invoice line carries a `GstClass`** (exempt healthcare SAC 999312, cosmetic taxable, goods HSN 9021, standard). Rates come from clinic config with a rate-history table; cosmetic defaults to 18% and is configurable to 5% without ITC.
- **Registration number on every prescription, certificate and receipt** (DCI Code 3.4.1). Estimates precede treatment and are versioned.
- **Two unrelated consents:** `ConsentRecord` (procedure consent with tooth numbers, risks, signer capacity, signature hash) and `DataConsent` (DPDP purpose-scoped). Never merge them.
- **Guardian required for under-18 patients.** All messaging routes to the guardian.
- **No clinical content in WhatsApp message bodies**: send a notification plus an authenticated link. Never write "AI detects" anywhere.
- **Never store card numbers.** Gateway token, last four digits and brand only. Never hold patient money.
- **Offline-first.** Every write must succeed with no network; IDs are client-generated UUID v4 strings; invoice numbers are minted server-side on first sync (local draft numbers are prefixed `DRAFT-`).

## Code conventions

- Dart 3.13 / Flutter 3.47. `prefer_single_quotes`, `always_declare_return_types`, `prefer_final_locals`. Run `dart format` before finishing.
- Plain immutable Dart classes with `const` constructors, `copyWith`, manual `toJson`/`fromJson`; no freezed, no json_serializable. Drift is the only codegen.
- Riverpod 3 (`Notifier`, `AsyncNotifier`, `Provider`), no riverpod_generator. go_router for navigation; each feature exposes `List<RouteBase> get <feature>Routes` in `lib/features/<feature>/routes.dart`.
- Repositories are abstract classes in `ampdent_data` (`PatientRepository`, ...) with Drift implementations; the app depends on the abstractions via providers.
- Widgets must work one-handed on a 360x800 phone, offline, with large tap targets (min 48dp); dentist screens assume gloves and a hurry.
- Every package has tests; `chart_engine` has golden tests; `core` has exhaustive notation/conversion tests; `data` has repository tests against an in-memory database.
- Strings shown to users go through `AppStrings` (en, hi, te planned); do not hard-code Hindi/Telugu yet, keep English with a translation hook.
- No `print`; use the `Logger` from `ampdent_core`.
- Keep each file under ~400 lines; split by concern.

## Scope guardrails

In scope now: patients, appointment book, odontogram, findings, procedures, treatment plan with estimate, consent + e-sign, clinical notes + photos, prescriptions, invoice/receipt/ledger with GST, procedure-triggered recall, lab cases, export + audit, sterilisation/licence log. Local SQLite only; sync and WhatsApp send go through interfaces with local outbox implementations.

Out of scope: insurance/CDT, ABDM production calls, AI radiograph analysis, patient app, Flutter web front desk, multi-branch, inventory, payroll, video, memberships, marketing broadcasts.
