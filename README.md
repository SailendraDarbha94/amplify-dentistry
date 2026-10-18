# amplify-dentistry

A dental-only clinic management product: Flutter apps for dentists (Android and iOS) to run clinics, patients, appointments, clinical records, billing and patient communication, India first, offline-first, WhatsApp-native, with a web front desk later.

## Status

Research phase, October 2026. No application code yet. The product strategy, specification, architecture, compliance checklist and go-to-market plan live in [docs/research](docs/research/README.md); start with the [executive summary](docs/research/00-executive-summary.md).

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
