import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  group('NumberPad', () {
    testWidgets('reports digits, extra keys, backspace and done', (
      tester,
    ) async {
      final digits = <String>[];
      var backspaces = 0;
      var done = 0;
      await tester.pumpWidget(
        testApp(
          NumberPad(
            onDigit: digits.add,
            onBackspace: () => backspaces++,
            onDone: () => done++,
            extraKeys: const ['.', '00'],
          ),
        ),
      );
      await tester.tap(find.text('1'));
      await tester.tap(find.text('9'));
      await tester.tap(find.text('0'));
      await tester.tap(find.text('.'));
      await tester.tap(find.text('00'));
      await tester.tap(
        find.bySemanticsLabel(NumberPad.backspaceSemanticsLabel),
      );
      await tester.tap(find.text('Done'));
      expect(digits, ['1', '9', '0', '.', '00']);
      expect(backspaces, 1);
      expect(done, 1);
    });

    testWidgets('every key is at least 48 px tall and Done can be disabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(NumberPad(onDigit: (_) {}, onBackspace: () {}, keyHeight: 20)),
      );
      for (final d in ['1', '5', '9', '0']) {
        final size = tester.getSize(
          find.ancestor(of: find.text(d), matching: find.byType(InkWell)).first,
        );
        expect(size.height, greaterThanOrEqualTo(48), reason: 'key $d');
      }
      final doneButton = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(doneButton.onPressed, isNull);
    });

    testWidgets('can hide the Done row', (tester) async {
      await tester.pumpWidget(
        testApp(
          NumberPad(onDigit: (_) {}, onBackspace: () {}, showDone: false),
        ),
      );
      expect(find.text('Done'), findsNothing);
    });
  });
}
