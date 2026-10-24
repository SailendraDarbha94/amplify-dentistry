import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  group('StatusBadge', () {
    testWidgets('each tone resolves to its AppColors entry', (tester) async {
      await tester.pumpWidget(
        testApp(
          Column(
            children: [
              for (final tone in BadgeTone.values)
                StatusBadge(label: tone.name, tone: tone),
            ],
          ),
        ),
      );
      final context = tester.element(find.byType(Column));
      final colors = AppColors.of(context);
      final expected = <BadgeTone, Color>{
        BadgeTone.success: colors.success,
        BadgeTone.warning: colors.warning,
        BadgeTone.danger: colors.danger,
        BadgeTone.info: colors.info,
        BadgeTone.planned: colors.planned,
        BadgeTone.completed: colors.completed,
        BadgeTone.caries: colors.caries,
        BadgeTone.existing: colors.existing,
        BadgeTone.neutral: Theme.of(context).colorScheme.onSurfaceVariant,
      };
      for (final entry in expected.entries) {
        final text = tester.widget<Text>(find.text(entry.key.name));
        expect(text.style?.color, entry.value, reason: entry.key.name);
      }
    });

    testWidgets('dark theme swaps to the dark palette', (tester) async {
      await tester.pumpWidget(
        testApp(
          const StatusBadge(label: 'Paid', tone: BadgeTone.success),
          dark: true,
        ),
      );
      final text = tester.widget<Text>(find.text('Paid'));
      expect(text.style?.color, const AppColors.dark().success);
    });

    testWidgets('shows an optional icon', (tester) async {
      await tester.pumpWidget(
        testApp(
          const StatusBadge(
            label: 'Due',
            tone: BadgeTone.warning,
            icon: Icons.schedule,
          ),
        ),
      );
      expect(find.byIcon(Icons.schedule), findsOneWidget);
    });
  });
}
