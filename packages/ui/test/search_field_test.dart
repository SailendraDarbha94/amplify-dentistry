import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  group('SearchField', () {
    testWidgets('debounces onChanged and only emits the final value', (
      tester,
    ) async {
      final values = <String>[];
      await tester.pumpWidget(
        testApp(
          SearchField(
            onChanged: values.add,
            debounce: const Duration(milliseconds: 300),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'R');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byType(TextField), 'Ra');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byType(TextField), 'Ram');
      expect(values, isEmpty);
      await tester.pump(const Duration(milliseconds: 299));
      expect(values, isEmpty);
      await tester.pump(const Duration(milliseconds: 2));
      expect(values, ['Ram']);
    });

    testWidgets('clear button appears with text and resets immediately', (
      tester,
    ) async {
      final values = <String>[];
      await tester.pumpWidget(testApp(SearchField(onChanged: values.add)));
      expect(find.byIcon(Icons.close), findsNothing);
      await tester.enterText(find.byType(TextField), 'Sita');
      await tester.pump();
      expect(find.byIcon(Icons.close), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(values, ['']);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      // The pending debounce for 'Sita' was cancelled.
      await tester.pump(const Duration(seconds: 1));
      expect(values, ['']);
    });

    testWidgets('uses the default hint and a custom one', (tester) async {
      await tester.pumpWidget(testApp(const SearchField()));
      expect(find.text('Search'), findsOneWidget);
      await tester.pumpWidget(
        testApp(const SearchField(hintText: 'Name or phone')),
      );
      expect(find.text('Name or phone'), findsOneWidget);
    });
  });
}
