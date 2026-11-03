import 'package:ampdent_data/ampdent_data.dart';
import 'package:ampdent_mobile/core/clinic_link.dart';
import 'package:ampdent_mobile/core/member_invites.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_mobile/features/settings/member_invite_sheet.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'cloud_test_support.dart';

/// Staff invite codes: the owner mints one from Settings > Members, the
/// staff member redeems it on the sign-in page, and an account with no
/// clinic is never sent to onboarding without choosing to.
void main() {
  const staffId = 'member-priya';

  group('InviteCodes', () {
    test('normalises, displays and validates', () {
      expect(InviteCodes.normalise(' ab cd-efgh '), 'ABCDEFGH');
      expect(InviteCodes.display('abcdefgh'), 'ABCD-EFGH');
      expect(InviteCodes.isWellFormed('jkmn-pqrs'), isTrue);
      expect(InviteCodes.isWellFormed('ABCDEFG'), isFalse, reason: '7 chars');
      expect(InviteCodes.isWellFormed('ABCDEFG0'), isFalse, reason: 'zero');
      expect(InviteCodes.isWellFormed('ABCDEFGI'), isFalse, reason: 'I');
      expect(InviteCodes.validate(''), isNotNull);
      expect(InviteCodes.validate('ABCD-EFGH'), isNull);
    });

    test('share text carries the code and no clinical content', () {
      final invite = MemberInvite(
        code: 'ABCDEFGH',
        memberId: staffId,
        clinicId: testClinicId,
        expiresAt: DateTime.utc(2026, 10, 23, 8),
      );
      final text = invite.shareText(
        clinicName: 'Smile Dental',
        memberName: 'Priya',
      );
      expect(text, contains('ABCD-EFGH'));
      expect(text, contains('Smile Dental'));
      expect(text, contains('Priya'));
      expect(text, contains('I have an invite code'));
      expect(text, contains('ampdent://app/invite/ABCDEFGH'));
      expect(invite.link.toString(), 'ampdent://app/invite/ABCDEFGH');
    });

    test('builds and parses the app link', () {
      expect(
        InviteCodes.linkFor('jkmn-pqrs').toString(),
        'ampdent://app/invite/JKMNPQRS',
      );
      expect(
        InviteCodes.codeFromLink(Uri.parse('ampdent://app/invite/jkmn-pqrs')),
        'JKMNPQRS',
      );
      // The platforms hand Flutter the path only.
      expect(
        InviteCodes.codeFromLink(Uri.parse('/invite/JKMNPQRS')),
        'JKMNPQRS',
      );
      expect(
        InviteCodes.codeFromLink(
          Uri.parse('https://example.com/invite/JKMNPQRS'),
        ),
        isNull,
        reason: 'other scheme',
      );
      expect(
        InviteCodes.codeFromLink(Uri.parse('ampdent://app/patients/1')),
        isNull,
      );
      expect(
        InviteCodes.codeFromLink(Uri.parse('ampdent://app/invite/ABCDEFG0')),
        isNull,
        reason: 'malformed code',
      );
    });
  });

  group('owner phone', () {
    late FakeSupabase fake;
    late AppTestEnv env;
    late List<String> shared;

    setUp(() async {
      fake = FakeSupabase();
      shared = [];
      env = await AppTestEnv.open(
        cloudClient: fake.client(),
        overrides: [
          inviteShareProvider.overrideWithValue((text, {subject}) async {
            shared.add(text);
          }),
        ],
      );
      await env.repos.clinics.upsertMember(
        testCtx,
        remoteStaff(staffId, testClinicId),
      );
    });
    tearDown(() => env.close());

    Future<void> openInviteMenu(WidgetTester tester) async {
      await env.go(tester, '/settings/members');
      await settle(tester, frames: 10);
      await tester.tap(find.byKey(const ValueKey('member-menu-$staffId')));
      await settle(tester);
      await tester.tap(find.text('Invite to sign in'));
      await settle(tester, frames: 12);
    }

    testWidgets('Invite to sign in mints a code and shows it with expiry', (
      tester,
    ) async {
      await signIn(env.container, fake);
      expect((await runLink(env.container)).phase, LinkPhase.linked);
      // The member row reached the server (as the outbox push would do).
      fake.seed('clinic_members', {
        'id': staffId,
        'clinic_id': testClinicId,
        'user_id': null,
        'role': 'receptionist',
        'display_name': 'Priya',
        'is_active': true,
      });
      await env.pumpApp(tester);
      await openInviteMenu(tester);

      final (fn, params) = fake.rpcCalls.single;
      expect(fn, 'create_member_invite');
      expect(params['p_member'], staffId);
      expect(find.byKey(const ValueKey('invite-code')), findsOneWidget);
      expect(find.text('ABCD-EFGH'), findsOneWidget);
      expect(find.byKey(const ValueKey('invite-expiry')), findsOneWidget);
      expect(find.textContaining('Valid until'), findsOneWidget);
      final row = fake.rows('member_invites').single;
      expect(row['code'], 'ABCDEFGH');
      expect(row['member_id'], staffId);
      expect(row['claimed_at'], isNull);
      // The code is nowhere in the local store.
      expect(await findSecretInStore(env.db, 'ABCDEFGH'), isEmpty);

      await tester.tap(find.byKey(const ValueKey('invite-share')));
      await settle(tester);
      expect(shared.single, contains('ABCD-EFGH'));
      expect(shared.single, contains('Priya'));
      expect(shared.single, contains('Smile Dental'));

      await tester.tap(find.byKey(const ValueKey('invite-copy')));
      await settle(tester);
      expect(find.text('Code copied'), findsOneWidget);
    });

    testWidgets('not linked: the menu says to sign in first', (tester) async {
      await env.pumpApp(tester);
      await openInviteMenu(tester);
      expect(find.byKey(const ValueKey('invite-needs-link')), findsOneWidget);
      expect(fake.rpcCalls, isEmpty);
    });

    testWidgets('a refusal from the server is shown, not thrown', (
      tester,
    ) async {
      await signIn(env.container, fake);
      expect((await runLink(env.container)).phase, LinkPhase.linked);
      // Staff row already bound to an account.
      fake.seed('clinic_members', {
        'id': staffId,
        'clinic_id': testClinicId,
        'user_id': 'user-someone',
        'role': 'receptionist',
        'display_name': 'Priya',
        'is_active': true,
      });
      await env.pumpApp(tester);
      await openInviteMenu(tester);
      expect(find.byKey(const ValueKey('invite-refused')), findsOneWidget);
      expect(find.textContaining('already signed in'), findsOneWidget);
      expect(find.byKey(const ValueKey('invite-code')), findsNothing);
    });

    Future<void> openUnlink(WidgetTester tester) async {
      await env.go(tester, '/settings/members');
      await settle(tester, frames: 10);
      await tester.tap(find.byKey(const ValueKey('member-menu-$staffId')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('member-unlink-$staffId')));
      await settle(tester, frames: 12);
    }

    /// Presses the [ConfirmSheet] button labelled [label] through its
    /// widget: on the 360 x 800 test surface the sheet's buttons can sit
    /// below the fold, where a tap would land on the barrier.
    Future<void> confirmSheet(WidgetTester tester, String label) async {
      final button = find.ancestor(
        of: find.descendant(
          of: find.byType(ConfirmSheet),
          matching: find.text(label),
        ),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      );
      tester.widget<ButtonStyleButton>(button.first).onPressed!();
      await settle(tester, frames: 20);
    }

    testWidgets(
      'Unlink account clears the binding after confirmation; a new code '
      'can then be minted',
      (tester) async {
        await signIn(env.container, fake);
        expect((await runLink(env.container)).phase, LinkPhase.linked);
        fake.seed('clinic_members', {
          'id': staffId,
          'clinic_id': testClinicId,
          'user_id': 'user-lost-phone',
          'role': 'receptionist',
          'display_name': 'Priya',
          'is_active': true,
        });
        fake.seed('member_invites', {
          'id': 'invite-live',
          'clinic_id': testClinicId,
          'member_id': staffId,
          'code': 'JKMNPQRS',
          'created_by': fake.userId,
          'expires_at': fake.now
              .add(const Duration(hours: 10))
              .toIso8601String(),
          'claimed_by': null,
          'claimed_at': null,
        });
        await env.pumpApp(tester);
        await openUnlink(tester);
        // Confirmation first; nothing sent yet.
        expect(find.byType(ConfirmSheet), findsOneWidget);
        expect(fake.rpcCalls, isEmpty);
        await confirmSheet(tester, 'Unlink account');

        final (fn, params) = fake.rpcCalls.first;
        expect(fn, 'unlink_member');
        expect(params['p_member'], staffId);
        expect(fake.row('clinic_members', staffId)!['user_id'], isNull);
        expect(find.byKey(const ValueKey('unlink-done')), findsOneWidget);
        final live = fake.rows('member_invites').single;
        expect(
          DateTime.parse('${live['expires_at']}').isAfter(fake.now),
          isFalse,
          reason: 'the live code is retired',
        );

        // The member can be invited again.
        await openInviteMenu(tester);
        expect(find.byKey(const ValueKey('invite-code')), findsOneWidget);
        expect(fake.rpcCalls.last.$1, 'create_member_invite');
      },
    );

    testWidgets('unlinking an unbound member shows the refusal', (
      tester,
    ) async {
      await signIn(env.container, fake);
      expect((await runLink(env.container)).phase, LinkPhase.linked);
      fake.seed('clinic_members', {
        'id': staffId,
        'clinic_id': testClinicId,
        'user_id': null,
        'role': 'receptionist',
        'display_name': 'Priya',
        'is_active': true,
      });
      await env.pumpApp(tester);
      await openUnlink(tester);
      await confirmSheet(tester, 'Unlink account');
      expect(find.byKey(const ValueKey('unlink-refused')), findsOneWidget);
      expect(find.textContaining('no account to unlink'), findsOneWidget);
    });

    testWidgets('not linked: unlink says to sign in first', (tester) async {
      await env.pumpApp(tester);
      await openUnlink(tester);
      expect(find.byKey(const ValueKey('unlink-needs-link')), findsOneWidget);
      expect(fake.rpcCalls, isEmpty);
    });
  });

  group('staff phone', () {
    late FakeSupabase fake;
    AppTestEnv? env;

    /// Clinic A on the server: owned by another account, with an unbound
    /// staff row and a live invite for it.
    Future<void> seedClinicWithInvite({String code = 'JKMNPQRS'}) async {
      await seedRemoteClinic(
        fake,
        clinic: remoteClinic(testClinicId, name: 'Smile Dental'),
        owner: remoteOwner('member-owner', testClinicId),
        staff: [remoteStaff(staffId, testClinicId)],
        ownerUserId: 'user-owner',
      );
      fake.seed('member_invites', {
        'id': 'invite-seeded',
        'clinic_id': testClinicId,
        'member_id': staffId,
        'code': code,
        'created_by': 'user-owner',
        'expires_at': fake.now.add(const Duration(hours: 72)).toIso8601String(),
        'claimed_by': null,
        'claimed_at': null,
      });
    }

    // Databases are opened and closed here, outside the widget test's fake
    // clock: drift's teardown runs through zero timers that only fire in
    // real time.
    setUp(() async {
      fake = FakeSupabase(userId: 'user-priya', email: 'priya@example.com');
      await seedClinicWithInvite();
      env = await openCloudEnv(fake, withClinic: false);
    });
    tearDown(() async {
      await env?.close();
      env = null;
    });

    AppTestEnv openEnv() => env!;

    testWidgets('the invite deep link lands on the sign-in page with the code '
        'prefilled, and the claim follows sign-in', (tester) async {
      final env = openEnv();
      await env.pumpApp(tester);
      await env.go(tester, '/invite/jkmn-pqrs');
      await settle(tester, frames: 10);
      expect(env.location, '/sign-in');
      expect(env.container.read(inviteClaimProvider).pendingCode, 'JKMNPQRS');
      final field = find.byKey(const ValueKey('sign-in-invite-code'));
      expect(field, findsOneWidget);
      expect(tester.widget<TextFormField>(field).controller?.text, 'JKMN-PQRS');

      await tester.enterText(
        find.byKey(const ValueKey('sign-in-email')),
        fake.email,
      );
      await tester.enterText(
        find.byKey(const ValueKey('sign-in-password')),
        fake.password,
      );
      await tester.tap(find.byKey(const ValueKey('sign-in-submit')));
      await settle(tester, frames: 40);
      expect(
        fake.rpcCalls.singleWhere((c) => c.$1 == 'claim_member_invite').$2,
        {'p_code': 'JKMNPQRS'},
      );
      expect(env.container.read(appSessionProvider).memberId, staffId);
      expect(env.location, '/today');
    });

    testWidgets('a malformed invite link opens the sign-in page without a '
        'code', (tester) async {
      final env = openEnv();
      await env.pumpApp(tester);
      await env.go(tester, '/invite/ABCDEFG0');
      await settle(tester, frames: 10);
      expect(env.location, '/sign-in');
      expect(env.container.read(inviteClaimProvider).pendingCode, isNull);
      expect(find.byKey(const ValueKey('sign-in-invite-code')), findsNothing);
    });

    testWidgets(
      'code typed before sign-in is claimed right after it; the clinic is '
      'adopted and onboarding skipped',
      (tester) async {
        final env = openEnv();
        await env.pumpApp(tester);
        expect(env.location, '/sign-in');

        await tester.tap(find.byKey(const ValueKey('sign-in-have-invite')));
        await settle(tester);
        await tester.enterText(
          find.byKey(const ValueKey('sign-in-invite-code')),
          'jkmn-pqrs',
        );
        expect(env.container.read(inviteClaimProvider).pendingCode, 'JKMNPQRS');
        await tester.enterText(
          find.byKey(const ValueKey('sign-in-email')),
          fake.email,
        );
        await tester.enterText(
          find.byKey(const ValueKey('sign-in-password')),
          fake.password,
        );
        await tester.tap(find.byKey(const ValueKey('sign-in-submit')));
        await settle(tester, frames: 40);

        final claim = fake.rpcCalls.singleWhere(
          (c) => c.$1 == 'claim_member_invite',
        );
        expect(claim.$2['p_code'], 'JKMNPQRS');
        expect(fake.row('clinic_members', staffId)!['user_id'], fake.userId);
        expect(fake.rows('member_invites').single['claimed_by'], fake.userId);

        final link = env.container.read(clinicLinkProvider);
        expect(link.phase, LinkPhase.linked, reason: link.error);
        expect(link.link!.mode, ClinicLinkMode.adoptedRemote);
        final session = env.container.read(appSessionProvider);
        expect(session.clinicId, testClinicId);
        expect(session.memberId, staffId);
        expect(
          (await env.repos.clinics.getClinic(testClinicId))?.name,
          'Smile Dental',
        );
        expect(env.location, '/today');
        expect(env.container.read(inviteClaimProvider).pendingCode, isNull);
        expect(fake.rows('clinics'), hasLength(1), reason: 'no second clinic');
        expect(await findSecretInStore(env.db, 'JKMNPQRS'), isEmpty);
      },
    );

    testWidgets(
      'signed in with no clinic: a wrong code shows the server message and '
      'stays; a right one adopts',
      (tester) async {
        final env = openEnv();
        await signIn(env.container, fake);
        expect((await runLink(env.container)).phase, LinkPhase.unlinked);
        await env.pumpApp(tester);
        expect(env.location, '/sign-in');
        expect(find.byKey(const ValueKey('link-unlinked')), findsOneWidget);

        await tester.enterText(
          find.byKey(const ValueKey('link-invite-code')),
          'ZZZZZZZZ',
        );
        await tester.tap(find.byKey(const ValueKey('link-claim-invite')));
        await settle(tester, frames: 12);
        expect(find.byKey(const ValueKey('link-invite-error')), findsOneWidget);
        expect(find.text('invite code not recognised'), findsOneWidget);
        expect(env.location, '/sign-in');
        expect(env.container.read(signInGateProvider), isTrue);
        expect(
          env.container.read(clinicLinkProvider).phase,
          LinkPhase.unlinked,
        );

        await tester.enterText(
          find.byKey(const ValueKey('link-invite-code')),
          'JKMNPQRS',
        );
        await tester.tap(find.byKey(const ValueKey('link-claim-invite')));
        await settle(tester, frames: 30);
        final link = env.container.read(clinicLinkProvider);
        expect(link.phase, LinkPhase.linked, reason: link.error);
        expect(env.container.read(appSessionProvider).memberId, staffId);
        expect(env.location, '/today');
      },
    );

    test(
      'expired, used and mismatched codes are refused by the claim',
      () async {
        final env = openEnv();
        await signIn(env.container, fake);
        final invites = env.container.read(inviteClaimProvider.notifier);

        fake.expireInvites();
        invites.setPendingCode('JKMNPQRS');
        expect((await runLink(env.container)).phase, LinkPhase.unlinked);
        expect(
          env.container.read(inviteClaimProvider).error,
          contains('expired'),
        );
        expect(
          env.container.read(inviteClaimProvider).pendingCode,
          'JKMNPQRS',
          reason: 'the code stays for correction',
        );

        // Owner mints a fresh one; a different account used it first.
        fake.seed('member_invites', {
          'id': 'invite-2',
          'clinic_id': testClinicId,
          'member_id': staffId,
          'code': 'TUVWXYZ2',
          'created_by': 'user-owner',
          'expires_at': fake.now
              .add(const Duration(hours: 72))
              .toIso8601String(),
          'claimed_by': 'user-else',
          'claimed_at': fake.now.toIso8601String(),
        });
        invites.setPendingCode('TUVWXYZ2');
        expect((await runLink(env.container)).phase, LinkPhase.unlinked);
        expect(
          env.container.read(inviteClaimProvider).error,
          contains('already used'),
        );

        // Member row bound to another account: mismatch.
        fake.row('clinic_members', staffId)!['user_id'] = 'user-else';
        fake.seed('member_invites', {
          'id': 'invite-3',
          'clinic_id': testClinicId,
          'member_id': staffId,
          'code': 'A2B3C4D5',
          'created_by': 'user-owner',
          'expires_at': fake.now
              .add(const Duration(hours: 72))
              .toIso8601String(),
          'claimed_by': null,
          'claimed_at': null,
        });
        invites.setPendingCode('A2B3C4D5');
        expect((await runLink(env.container)).phase, LinkPhase.unlinked);
        expect(
          env.container.read(inviteClaimProvider).error,
          contains('another account'),
        );
        expect(fake.rows('clinics'), hasLength(1), reason: 'nothing created');
        expect(await listLocalClinicsCount(env.db), 0);
      },
    );

    test(
      'sign-out forgets a pending code and the create-clinic choice',
      () async {
        final env = openEnv();
        await signIn(env.container, fake);
        env.container
            .read(inviteClaimProvider.notifier)
            .setPendingCode('ABCDEFGH');
        env.container.read(createClinicChoiceProvider.notifier).choose();
        await env.container.read(cloudAuthProvider.notifier).signOut();
        expect(env.container.read(inviteClaimProvider).pendingCode, isNull);
        expect(env.container.read(createClinicChoiceProvider), isFalse);
      },
    );
  });
}

/// Number of clinic rows in the local store.
Future<int> listLocalClinicsCount(AppDatabase db) async =>
    (await db.select(db.clinics).get()).length;
