import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const destinations = [
    AdaptiveDestination(icon: Icons.people_outline, label: 'Patients'),
    AdaptiveDestination(icon: Icons.calendar_today_outlined, label: 'Schedule'),
    AdaptiveDestination(icon: Icons.settings_outlined, label: 'Settings'),
  ];

  Widget build(double width, {ValueChanged<int>? onSelected}) => MaterialApp(
    theme: AppTheme.light(),
    home: MediaQuery(
      data: MediaQueryData(size: Size(width, 800)),
      child: SizedBox(
        width: width,
        height: 800,
        child: AdaptiveScaffold(
          body: const Text('body'),
          destinations: destinations,
          selectedIndex: 0,
          onDestinationSelected: onSelected ?? (_) {},
        ),
      ),
    ),
  );

  group('AdaptiveScaffold', () {
    testWidgets('uses NavigationBar below 600 px', (tester) async {
      tester.view.physicalSize = const Size(599, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(build(599));
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.text('body'), findsOneWidget);
    });

    testWidgets('uses NavigationRail at 600 px and above', (tester) async {
      tester.view.physicalSize = const Size(600, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(build(600));
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('forwards destination taps on both layouts', (tester) async {
      var tapped = -1;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(build(390, onSelected: (i) => tapped = i));
      await tester.tap(find.text('Schedule'));
      expect(tapped, 1);

      tester.view.physicalSize = const Size(900, 800);
      await tester.pumpWidget(build(900, onSelected: (i) => tapped = i));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      expect(tapped, 2);
    });

    testWidgets('renders the banner above the body', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: AdaptiveScaffold(
            body: const Text('body'),
            banner: const OfflineBanner(isOffline: true, pendingCount: 3),
            destinations: destinations,
            selectedIndex: 0,
            onDestinationSelected: (_) {},
          ),
        ),
      );
      expect(find.textContaining('Offline'), findsOneWidget);
      expect(find.textContaining('3 changes'), findsOneWidget);
    });
  });
}
