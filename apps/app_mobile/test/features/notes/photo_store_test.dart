import 'dart:convert';
import 'dart:io';

import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_mobile/core/router.dart';
import 'package:ampdent_mobile/core/session.dart';
import 'package:ampdent_mobile/features/notes/notes_providers.dart';
import 'package:ampdent_mobile/features/notes/photos/photo_gallery.dart';
import 'package:ampdent_mobile/features/notes/photos/photo_source.dart';
import 'package:ampdent_mobile/features/notes/photos/photo_store.dart';
import 'package:ampdent_mobile/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_env.dart';

/// 1x1 transparent PNG so `Image.file` decodes in widget tests.
final List<int> _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

final ToothId _t16 = ToothId.parse('16');
final ToothId _t46 = ToothId.parse('46');

void main() {
  late Directory tmp;
  late File fake;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('ampdent-photos-');
    fake = File('${tmp.path}/capture.jpg');
    await fake.writeAsBytes(_pngBytes);
  });
  tearDown(() => tmp.delete(recursive: true));

  LocalPhotoStore store() => LocalPhotoStore(
    root: () async => Directory('${tmp.path}/docs'),
    compressor: copyUncompressed,
  );

  test(
    'LocalPhotoStore writes under clinics/<clinic>/patients/<patient>/images',
    () async {
      final stored = await store().save(
        fake,
        clinicId: 'c1',
        patientId: 'p1',
        imageId: 'img1',
      );
      expect(stored.filePath, 'clinics/c1/patients/p1/images/img1.jpg');
      expect(stored.bytes, _pngBytes.length);
      expect(stored.sha256, hasLength(64));
      final file = await store().resolve(stored.filePath);
      expect(file.existsSync(), isTrue);
      expect(file.path, startsWith('${tmp.path}/docs/'));
    },
  );

  group('PhotoSaver', () {
    late AppTestEnv env;

    setUp(() async => env = await AppTestEnv.open(withPatient: true));
    tearDown(() => env.close());

    test('records the image with sorted tooth tags and pre-op flag', () async {
      final saver = PhotoSaver(
        store: store(),
        clinical: env.repos.clinical,
        ctx: testCtx,
      );
      final record = await saver.save(
        source: fake,
        patientId: testPatientId,
        kind: ImageKind.periapical,
        teeth: [_t46, _t16],
        isPreOperative: true,
        note: ' pre-op IOPA ',
        now: DateTime.utc(2026, 10, 25, 10),
      );
      expect(record.teeth, [_t16, _t46]);
      expect(record.kind, ImageKind.periapical);
      expect(record.isPreOperative, isTrue);
      expect(record.note, 'pre-op IOPA');
      expect(record.sha256, isNotNull);
      expect(
        record.filePath,
        'clinics/$testClinicId/patients/$testPatientId/images/${record.id}.jpg',
      );
      final stored = await env.repos.clinical.imagesForPatient(testPatientId);
      expect(stored.map((i) => i.id), [record.id]);
      expect((await store().resolve(record.filePath)).existsSync(), isTrue);
    });
  });

  test('pairPhotos matches the earliest pre-op with the latest later shot', () {
    ImageRecord img(
      String id,
      int day, {
      required bool preOp,
      ImageKind kind = ImageKind.photoIntraoral,
      List<ToothId>? teeth,
    }) => ImageRecord(
      id: id,
      clinicId: 'c',
      patientId: 'p',
      kind: kind,
      filePath: '$id.jpg',
      capturedAt: DateTime.utc(2026, 10, day),
      teeth: teeth ?? [_t16],
      isPreOperative: preOp,
      createdAt: DateTime.utc(2026, 10, day),
    );
    final pairs = pairPhotos([
      img('pre2', 5, preOp: true),
      img('pre1', 1, preOp: true),
      img('mid', 7, preOp: false),
      img('post', 9, preOp: false),
      img('xray', 9, preOp: false, kind: ImageKind.periapical),
      img('other', 3, preOp: false, teeth: [_t46]),
    ]);
    expect(pairs, hasLength(1));
    expect(pairs.single.tooth, _t16);
    expect(pairs.single.before.id, 'pre1');
    expect(pairs.single.after.id, 'post');
  });

  group('Photo capture page', () {
    late AppTestEnv env;
    late ProviderContainer container;

    setUp(() async {
      env = await AppTestEnv.open(withPatient: true);
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(env.db),
          initialSessionProvider.overrideWithValue(env.session),
          photoSourceProvider.overrideWithValue(FixedPhotoSource(fake)),
          photoStoreProvider.overrideWithValue(store()),
        ],
      );
    });
    tearDown(() async {
      container.dispose();
      await env.close();
    });

    testWidgets('picks, tags teeth and saves the record', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const AmpDentApp(),
        ),
      );
      await settle(tester);
      container
          .read(routerProvider)
          .go('/patients/$testPatientId/notes/photos/new');
      await settle(tester);

      await tester.tap(find.byKey(const ValueKey('photo-gallery')));
      await settle(tester);
      expect(find.byKey(const ValueKey('photo-preview')), findsOneWidget);

      Future<void> reveal(Finder finder) async {
        await tester.scrollUntilVisible(
          finder,
          120,
          scrollable: find.byType(Scrollable).first,
        );
        await settle(tester, frames: 2);
      }

      await reveal(find.text('Bitewing'));
      await tester.tap(find.text('Bitewing'));
      await settle(tester, frames: 2);
      await reveal(find.byKey(const ValueKey('photo-teeth')));
      await tester.tap(find.byKey(const ValueKey('photo-teeth')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('tooth-16')));
      await tester.tap(find.byKey(const ValueKey('tooth-17')));
      await tester.tap(find.byKey(const ValueKey('tooth-picker-done')));
      await settle(tester);
      expect(find.text('16, 17'), findsOneWidget);

      await reveal(find.byKey(const ValueKey('photo-preop')));
      await tester.tap(find.byKey(const ValueKey('photo-preop')));
      await settle(tester, frames: 2);
      // File copy and hashing are real I/O, so run them outside FakeAsync.
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('photo-save')));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await settle(tester, frames: 6);

      final images = await env.repos.clinical.imagesForPatient(testPatientId);
      expect(images, hasLength(1));
      expect(images.single.kind, ImageKind.bitewing);
      expect(images.single.isPreOperative, isTrue);
      expect(images.single.teeth.map((t) => t.storageKey).toList(), [
        '16',
        '17',
      ]);
      final file = await store().resolve(images.single.filePath);
      expect(file.existsSync(), isTrue);
    });
  });
}
