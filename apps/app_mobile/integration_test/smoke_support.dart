/// Helpers for the on-device smoke test: the in-memory environment the app
/// boots with, polling waits that tolerate real device timing, and key-based
/// taps and text entry.
library;

import 'package:ampdent_data/ampdent_data.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_mobile/core/router.dart';
import 'package:ampdent_mobile/core/session.dart';
import 'package:ampdent_mobile/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Device id the smoke run acts as until onboarding persists it.
const String smokeDeviceId = 'device-smoke';

/// Default wait before a polling helper gives up.
const Duration smokeTimeout = Duration(seconds: 30);

/// Boots the real [AmpDentApp] over a fresh in-memory database (global
/// catalogue and drug master seeded, no clinic), wired exactly like `main`
/// minus the on-device file store.
class SmokeEnv {
  SmokeEnv._(this.db)
    : repos = DriftRepositories(db),
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          initialSessionProvider.overrideWithValue(
            const AppSession(deviceId: smokeDeviceId),
          ),
        ],
      );

  /// The open in-memory database.
  final AppDatabase db;

  /// Repositories over [db] for assertions.
  final DriftRepositories repos;

  /// Riverpod container with the app overrides.
  final ProviderContainer container;

  /// Opens a fresh environment.
  static Future<SmokeEnv> open() async {
    await initializeDateFormatting('en_IN');
    return SmokeEnv._(AppDatabase.inMemory());
  }

  /// The app router.
  GoRouter get router => container.read(routerProvider);

  /// Matched location of the top-most route, including imperative pushes.
  String get location =>
      router.routerDelegate.currentConfiguration.last.matchedLocation;

  /// The live session (clinic and member once onboarding completes).
  AppSession get session => container.read(appSessionProvider);

  /// Pumps the full app and lets the first frame settle. [surface] pins the
  /// logical size (the widget-test twin uses a 360 x 800 phone); on a device
  /// the real screen is used.
  Future<void> pumpApp(WidgetTester tester, {Size? surface}) async {
    if (surface != null) {
      tester.view.physicalSize = surface;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AmpDentApp(),
      ),
    );
    await settle(tester);
  }

  /// Pumps until the router reports [location] as the top-most route.
  Future<void> waitForLocation(WidgetTester tester, String location) =>
      waitUntil(
        tester,
        () async => this.location == location,
        reason: 'expected route $location, at ${this.location}',
      );

  /// Releases the container and database.
  Future<void> close() async {
    container.dispose();
    await db.close();
  }
}

/// Pumps a handful of frames with real durations so database streams and
/// animations resolve without `pumpAndSettle` (which spins on indeterminate
/// progress indicators).
Future<void> settle(
  WidgetTester tester, {
  int frames = 8,
  Duration step = const Duration(milliseconds: 100),
}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(step);
  }
}

/// Pumps until [condition] holds, failing with [reason] after [timeout].
Future<void> waitUntil(
  WidgetTester tester,
  Future<bool> Function() condition, {
  Duration timeout = smokeTimeout,
  String? reason,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!await condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail(reason ?? 'Timed out after $timeout');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump();
}

/// Pumps until [finder] matches at least one widget.
Future<void> waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = smokeTimeout,
}) => waitUntil(
  tester,
  () async => finder.evaluate().isNotEmpty,
  timeout: timeout,
  reason: 'Timed out waiting for $finder',
);

/// Polls [read] until it returns a non-null value and returns it.
Future<T> waitForValue<T extends Object>(
  WidgetTester tester,
  Future<T?> Function() read, {
  Duration timeout = smokeTimeout,
  String? reason,
}) async {
  T? value;
  await waitUntil(
    tester,
    () async {
      value = await read();
      return value != null;
    },
    timeout: timeout,
    reason: reason,
  );
  return value!;
}

/// Clears any SnackBar and waits for its exit animation, so it cannot sit
/// over a bottom button (the shell Scaffold's SnackBar overlaps the bottom
/// bar of the page Scaffold inside it).
Future<void> dismissSnackBars(WidgetTester tester) async {
  final messengers = find.byType(ScaffoldMessenger);
  if (messengers.evaluate().isNotEmpty) {
    tester.state<ScaffoldMessengerState>(messengers.first).clearSnackBars();
  }
  await tester.pump();
  final deadline = DateTime.now().add(const Duration(seconds: 3));
  while (find.byType(SnackBar).evaluate().isNotEmpty &&
      DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Brings the widget keyed [key] into view and returns a finder for it.
///
/// Lazy lists only build the rows near the viewport and `find.byKey` skips
/// rows that are built but scrolled off screen, so the lookup ignores the
/// offstage flag, scrolls a built widget into view with `ensureVisible`
/// (either direction) and, when nothing is built yet, sweeps every visible
/// scrollable in steps until the row appears or [timeout] elapses.
Future<Finder> reveal(
  WidgetTester tester,
  String key, {
  Duration timeout = smokeTimeout,
}) async {
  final finder = find.byKey(ValueKey(key), skipOffstage: false);
  final deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for key $key. ${_treeDiagnostics()}');
    }
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) break;
    await _sweepScrollables(tester);
  }
  // Scroll only as far as needed: realigning an already visible widget to
  // the viewport edge would push its neighbours off screen (and leave a page
  // scrolled when the user comes back to it).
  final context = finder.evaluate().single;
  await Scrollable.ensureVisible(
    context,
    alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
  );
  await Scrollable.ensureVisible(
    context,
    alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
  );
  await tester.pump();
  return finder;
}

/// Advances every visible scrollable with content by one step, wrapping back
/// to the start at the end, so repeated calls visit the whole range.
Future<void> _sweepScrollables(WidgetTester tester) async {
  final elements = find.byType(Scrollable).hitTestable().evaluate().toList();
  for (final element in elements.reversed) {
    final state = (element as StatefulElement).state as ScrollableState;
    final position = state.position;
    if (!position.hasContentDimensions || position.maxScrollExtent <= 0) {
      continue;
    }
    final atEnd = position.pixels >= position.maxScrollExtent - 0.5;
    position.jumpTo(
      atEnd
          ? position.minScrollExtent
          : (position.pixels + 300).clamp(
              position.minScrollExtent,
              position.maxScrollExtent,
            ),
    );
    await tester.pump();
  }
}

/// Keys and scrollables currently in the tree, for timeout messages.
String _treeDiagnostics() {
  final keys = find
      .byWidgetPredicate((w) => w.key is ValueKey<String>, skipOffstage: false)
      .evaluate()
      .map((e) => (e.widget.key! as ValueKey<String>).value)
      .toList();
  final scrollables = find.byType(Scrollable).hitTestable().evaluate().length;
  return 'Visible scrollables: $scrollables. Keys in tree (${keys.length}): '
      '${keys.take(60).join(', ')}';
}

/// Reveals the widget keyed [key], taps it and settles.
Future<void> tapKey(WidgetTester tester, String key, {int frames = 8}) async {
  final finder = await reveal(tester, key);
  await dismissSnackBars(tester);
  await tester.tap(finder);
  await settle(tester, frames: frames);
}

/// Reveals the text field keyed [key] and types [text] into it.
Future<void> enterKey(WidgetTester tester, String key, String text) async {
  final finder = await reveal(tester, key);
  await tester.enterText(finder, text);
  await settle(tester, frames: 2);
}
