import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/features/notes/allergy_entry_sheet.dart';
import 'package:ampdent_terminology/ampdent_terminology.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AllergyEntry? result;

  Future<void> pumpSheet(WidgetTester tester, {AllergyEntry? existing}) async {
    result = null;
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      AppStringsScope(
        strings: AppStrings.en,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: FilledButton(
                  key: const ValueKey('open'),
                  onPressed: () async {
                    result = await AllergyEntrySheet.show(
                      context,
                      existing: existing,
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pumpAndSettle();
  }

  FilterChip chip(WidgetTester tester, String group) =>
      tester.widget<FilterChip>(find.byKey(ValueKey('allergy-group-$group')));

  /// Lets any pending caret scroll finish, scrolls the sheet until [key] is
  /// on screen, then taps it.
  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(ValueKey(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey(key)));
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) => tapKey(tester, 'allergy-save');

  testWidgets('typing a substance suggests its group and saves it', (
    tester,
  ) async {
    await pumpSheet(tester);
    await tester.enterText(
      find.byKey(const ValueKey('allergy-substance')),
      'Augmentin',
    );
    await tester.pump();
    expect(chip(tester, AllergyGroups.penicillin).selected, isTrue);

    await tester.enterText(
      find.byKey(const ValueKey('allergy-substance')),
      'Brufen',
    );
    await tester.pump();
    expect(chip(tester, AllergyGroups.penicillin).selected, isFalse);
    expect(chip(tester, AllergyGroups.nsaid).selected, isTrue);

    await save(tester);
    expect(result, isNotNull);
    expect(result!.substance, 'Brufen');
    expect(result!.allergyGroup, AllergyGroups.nsaid);
  });

  testWidgets('an unrecognised substance needs a group; Other is the escape', (
    tester,
  ) async {
    await pumpSheet(tester);
    await tester.enterText(
      find.byKey(const ValueKey('allergy-substance')),
      'Dust mites',
    );
    await tester.pump();
    await save(tester);
    expect(find.byKey(const ValueKey('allergy-group-error')), findsOneWidget);
    expect(find.text(allergyGroupRequiredText), findsOneWidget);
    expect(result, isNull);
    expect(find.byKey(const ValueKey('allergy-save')), findsOneWidget);

    await tapKey(tester, 'allergy-group-other');
    expect(find.byKey(const ValueKey('allergy-group-error')), findsNothing);
    await save(tester);
    expect(result!.allergyGroup, 'other');
  });

  testWidgets('a chip chosen by hand is not overridden by the suggestion', (
    tester,
  ) async {
    await pumpSheet(tester);
    await tapKey(tester, 'allergy-group-sulfa');
    await tester.enterText(
      find.byKey(const ValueKey('allergy-substance')),
      'Amoxicillin',
    );
    await tester.pump();
    expect(chip(tester, AllergyGroups.sulfa).selected, isTrue);
    expect(chip(tester, AllergyGroups.penicillin).selected, isFalse);
    await save(tester);
    expect(result!.allergyGroup, AllergyGroups.sulfa);
  });

  testWidgets('editing a legacy entry without a group infers it', (
    tester,
  ) async {
    await pumpSheet(
      tester,
      existing: const AllergyEntry(substance: 'Lignocaine', reaction: 'rash'),
    );
    expect(chip(tester, AllergyGroups.localAnaesthetic).selected, isTrue);
    await save(tester);
    expect(result!.allergyGroup, AllergyGroups.localAnaesthetic);
    expect(result!.reaction, 'rash');
  });
}
