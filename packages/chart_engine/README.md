# ampdent_chart_engine

Pure `dart:ui` odontogram and six-site periodontal chart for AmpDent. Depends
only on `ampdent_core` and Flutter.

- `Odontogram`: 32 permanent + 20 primary teeth laid out as the clinician views
  the patient, procedural tooth shapes with five tappable crown faces, root
  silhouettes, FDI / Universal / Palmer labels, overlays for findings and
  planned or completed work, selection ring, badges. Scrolls horizontally when
  the width cannot hold 16 teeth at 44 px; `compact` stacks quadrant rows.
- `PerioChart` + `PerioNumberPad`: one arch and aspect at a time, PD / GM /
  bleeding / plaque / mobility / furcation grid with 4 mm amber and 6 mm red
  thresholds, auto-advance helpers (`perioEntrySequence`, `PerioEntryCursor`).

See the doc comment in `lib/ampdent_chart_engine.dart` for the public API.
Golden images live in `test/goldens/`; regenerate with
`flutter test --update-goldens`.
