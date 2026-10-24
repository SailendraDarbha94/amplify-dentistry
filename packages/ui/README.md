# ampdent_ui

Design system for AmpDent: Material 3 theme (teal-blue clinical palette, 48 px
minimum touch targets), semantic `AppColors`, `AppStrings` (English now, Hindi
and Telugu later via `AppStringsScope`) and tap-first shared widgets.

Flutter only; no dependency on other `ampdent_*` packages. `MoneyText` and
`PhoneText` take already-formatted strings so `core` stays out of this package.

```dart
import 'package:ampdent_ui/ampdent_ui.dart';

MaterialApp(theme: AppTheme.light(), darkTheme: AppTheme.dark(), home: ...);
```

Tests: `cd packages/ui && flutter test`. Regenerate the sample-screen golden
with `flutter test --update-goldens test/golden/`.
