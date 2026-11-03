import 'package:ampdent_data/ampdent_data.dart';
import 'package:ampdent_mobile/core/app_shell.dart';
import 'package:ampdent_mobile/core/clinic_link.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_mobile/core/sync_banner.dart';
import 'package:ampdent_mobile/core/sync_repair.dart';
import 'package:ampdent_ui/ampdent_ui.dart' show AppStrings, ConfirmSheet;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'cloud_test_support.dart';

/// The repair screen over the data package's `SyncRepairService`: held rows
/// are listed, the banner counts them, Retry re-queues the chain and
/// "Discard my change" restores the server's copy.
void main() {
  late FakeSupabase fake;
  late AppTestEnv env;

  setUp(() async {
    fake = FakeSupabase();
    env = await openCloudEnv(fake, withPatient: true);
    await signIn(env.container, fake);
    expect((await runLink(env.container)).phase, LinkPhase.linked);
  });
  tearDown(() => env.close());

  Future<OutboxEntry> entryFor(String table) async =>
      (await env.repos.outbox.pending(testClinicId))
          .firstWhere((e) => e.targetTable == table);

  /// Presses the [ConfirmSheet] button labelled [label] through its widget:
  /// on the 360 x 800 test surface with the Ahem font the sheet's buttons
  /// sit below the fold, where a tap would land on the barrier.
  void pressSheetButton(WidgetTester tester, String label) {
    final button = find.ancestor(
      of: find.descendant(
        of: find.byType(ConfirmSheet),
        matching: find.text(label),
      ),
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
    );
    tester.widget<ButtonStyleButton>(button.first).onPressed!();
  }

  // A plain query, not the stream: drift's stream cancellation runs through
  // a zero timer, which the widget test's fake clock never fires while a
  // `.first`/`.future` await blocks the test body.
  Future<int> heldCount() => env.repos.outbox.heldCount(testClinicId);

  test('banner spec points at the repair screen while rows are held', () {
    final spec = syncBannerSpec(
      const SyncState(status: SyncStatus.offline, quarantinedCount: 2),
      strings: AppStrings.en,
      now: DateTime(2026, 10, 25, 9),
    )!;
    expect(spec.kind, SyncBannerKind.attention);
    expect(spec.text, '2 changes need attention');
    expect(spec.opensRepair, isTrue);
    expect(spec.canRetry, isFalse);
    expect(
      syncBannerSpec(
        const SyncState(status: SyncStatus.disabled, quarantinedCount: 2),
        strings: AppStrings.en,
        now: DateTime(2026, 10, 25, 9),
      ),
      isNull,
      reason: 'no engine: nothing to repair against',
    );
  });

  testWidgets('held rows: the banner counts them, the page lists them, Retry '
      're-queues the chain', (tester) async {
    final patient = await entryFor('patients');
    final chair = await entryFor('chairs');
    await env.repos.outbox.quarantine(
      [patient.id],
      error: 'PostgrestException 403 on patients',
      statusCode: 403,
    );
    await env.repos.outbox.block([chair.id], parentId: patient.id);
    expect(await heldCount(), 2);

    await env.pumpApp(tester);
    await settle(tester, frames: 10);
    expect(find.text('2 changes need attention'), findsOneWidget);
    await tester.tap(find.byKey(shellSyncBannerKey));
    await settle(tester, frames: 12);
    expect(env.location, '/settings/account/sync-repair');

    expect(find.byKey(ValueKey('repair-row-${patient.id}')), findsOneWidget);
    expect(find.byKey(ValueKey('repair-row-${chair.id}')), findsOneWidget);
    expect(find.textContaining('Patient: '), findsOneWidget);
    expect(find.text('Rejected 403'), findsOneWidget);
    expect(find.text('Blocked'), findsOneWidget);
    expect(find.text('PostgrestException 403 on patients'), findsOneWidget);
    // Never clinical content: the patient label is the number or name only.
    expect(find.textContaining('+9198'), findsNothing);

    await tester.tap(find.byKey(ValueKey('repair-retry-${patient.id}')));
    await settle(tester, frames: 12);
    expect(find.text('Re-queued 2 changes'), findsOneWidget);
    expect(await heldCount(), 0);
    expect(find.byKey(const ValueKey('repair-empty')), findsOneWidget);
    // The re-queued rows went out on the sync that followed.
    expect(fake.row('patients', testPatientId), isNotNull);
  });

  testWidgets('Discard my change asks first, then restores the server copy', (
    tester,
  ) async {
    // The server already holds the patient as first saved.
    await seedTableFromDatabase(fake, env.db, 'patients');
    final before = (await env.repos.patients.getById(testPatientId))!;
    await env.repos.patients.upsert(
      testCtx,
      before.copyWith(firstName: 'Renamed'),
    );
    final entry = (await env.repos.outbox.pending(testClinicId))
        .lastWhere((e) => e.targetTable == 'patients');
    await env.repos.outbox.quarantine(
      [entry.id],
      error: 'PostgrestException 409 on patients',
      statusCode: 409,
    );

    await env.pumpApp(tester);
    await env.go(tester, '/settings/account');
    await settle(tester, frames: 10);
    expect(find.text('1 change needs attention'), findsWidgets);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('account-sync-repair')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('account-sync-repair')));
    await settle(tester, frames: 12);
    expect(env.location, '/settings/account/sync-repair');

    await tester.tap(find.byKey(ValueKey('repair-discard-${entry.id}')));
    await settle(tester, frames: 8);
    expect(find.text('Discard this change?'), findsOneWidget);
    // Cancel keeps everything.
    pressSheetButton(tester, 'Cancel');
    await settle(tester, frames: 8);
    expect(find.byType(ConfirmSheet), findsNothing);
    expect(await heldCount(), 1);

    await tester.tap(find.byKey(ValueKey('repair-discard-${entry.id}')));
    await settle(tester, frames: 8);
    expect(find.byType(ConfirmSheet), findsOneWidget);
    pressSheetButton(tester, 'Discard my change');
    await settle(tester, frames: 15);
    expect(find.byKey(const ValueKey('repair-discard-result')), findsOneWidget);
    expect(find.textContaining('1 restored from the server'), findsOneWidget);
    expect(await heldCount(), 0);
    final after = (await env.repos.patients.getById(testPatientId))!;
    expect(after.firstName, 'Asha', reason: 'server copy restored');
  });

  testWidgets('signed out: the page shows the count and asks to sign in', (
    tester,
  ) async {
    final patient = await entryFor('patients');
    await env.repos.outbox.quarantine(
      [patient.id],
      error: 'PostgrestException 403 on patients',
      statusCode: 403,
    );
    await env.container.read(cloudAuthProvider.notifier).signOut();
    expect(env.container.read(syncRepairServiceProvider), isNull);
    await env.pumpApp(tester);
    await env.go(tester, '/settings/account/sync-repair');
    await settle(tester, frames: 10);
    expect(find.byKey(const ValueKey('repair-unavailable')), findsOneWidget);
    expect(find.text('1 change needs attention'), findsOneWidget);
    expect(find.textContaining('Sign in and link'), findsOneWidget);
  });
}
