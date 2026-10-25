import 'dart:io';
import 'dart:typed_data';

import 'package:ampdent_mobile/core/stored_file_path.dart';
import 'package:ampdent_mobile/features/consent/consent_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  final png = Uint8List.fromList([137, 80, 78, 71, 1, 2, 3]);

  setUp(() async {
    root = await Directory.systemTemp.createTemp('ampdent-signatures');
  });
  tearDown(() async {
    if (root.existsSync()) await root.delete(recursive: true);
  });

  test(
    'saves under a store-relative, clinic and patient scoped path',
    () async {
      final store = FileSignatureStore(directory: root);
      final path = await store.save(
        'consent-1',
        png,
        clinicId: 'clinic-a',
        patientId: 'patient-7',
      );
      expect(
        path,
        'clinics/clinic-a/patients/patient-7/signatures/consent-1.png',
      );
      expect(isAbsoluteStoredPath(path), isFalse);
      expect(File('${root.path}/$path').existsSync(), isTrue);
      expect(await store.read(path), png);
      expect(
        await store.read('clinics/x/patients/y/signatures/none.png'),
        isNull,
      );
    },
  );

  test('the same relative path reads back after the container moves', () async {
    final path = await FileSignatureStore(directory: root)
        .save('consent-2', png, clinicId: 'clinic-a', patientId: 'patient-7');
    // Simulate iOS giving the app a new container: move the tree wholesale.
    final moved = await Directory.systemTemp.createTemp('ampdent-moved');
    addTearDown(() => moved.delete(recursive: true));
    await File('${root.path}/$path')
        .copy((await File('${moved.path}/$path').create(recursive: true)).path);
    await root.delete(recursive: true);
    expect(await FileSignatureStore(directory: moved).read(path), png);
  });

  test(
    'legacy absolute paths are re-rooted once their container is gone',
    () async {
      final oldContainer = await Directory.systemTemp.createTemp('ampdent-old');
      final legacy = File('${oldContainer.path}/signatures/legacy.png');
      await legacy.create(recursive: true);
      await legacy.writeAsBytes(png);
      final store = FileSignatureStore(directory: root);
      // While the old container exists the absolute path is used as is.
      expect(await store.read(legacy.path), png);

      // After an app update the old container is gone but the files were
      // carried into the new one at the same relative location.
      await File('${root.path}/signatures/legacy.png').create(recursive: true);
      await File('${root.path}/signatures/legacy.png').writeAsBytes(png);
      await oldContainer.delete(recursive: true);
      expect(await store.read(legacy.path), png);
      expect(
        (await store.resolve(legacy.path)).path,
        '${root.path}/signatures/legacy.png',
      );
      // An absolute path with no known folder tail stays as it is.
      expect(await store.read('/definitely/not/here.png'), isNull);
    },
  );

  test(
    'resolveStoredFile roots relative paths and honours drive letters',
    () async {
      final file = await resolveStoredFile(
        'clinics/c/x.png',
        root: () async => root,
        folder: 'signatures',
      );
      expect(file.path, '${root.path}/clinics/c/x.png');
      expect(isAbsoluteStoredPath(r'C:\Users\x\signatures\a.png'), isTrue);
      expect(isAbsoluteStoredPath('/var/mobile/x.png'), isTrue);
      expect(isAbsoluteStoredPath('licences/a.jpg'), isFalse);
    },
  );

  test('in-memory store mirrors the relative path contract', () async {
    final store = InMemorySignatureStore();
    final path = await store.save(
      'c1',
      png,
      clinicId: 'clinic-a',
      patientId: 'p1',
    );
    expect(path, SignatureStore.relativePath('clinic-a', 'p1', 'c1'));
    expect(await store.read(path), png);
  });
}
