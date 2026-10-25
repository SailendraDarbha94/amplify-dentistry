import 'dart:io';

import 'package:ampdent_mobile/features/compliance/licence_document_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  late Directory root;
  late Directory source;
  final clock = DateTime.utc(2026, 10, 25, 9);

  setUp(() async {
    root = await Directory.systemTemp.createTemp('ampdent-licences');
    source = await Directory.systemTemp.createTemp('ampdent-picked');
  });
  tearDown(() async {
    for (final d in [root, source]) {
      if (d.existsSync()) await d.delete(recursive: true);
    }
  });

  test('stores the scan under a relative licences/ path', () async {
    final picked = File('${source.path}/IMG_0001.JPG');
    await picked.writeAsBytes(List<int>.generate(32, (i) => i));
    final store = LicenceDocumentStore(
      baseDirectory: () async => root,
      clock: () => clock,
    );
    final path = await store.store(XFile(picked.path), licenceId: 'lic-1');
    expect(path, 'licences/lic-1-${clock.millisecondsSinceEpoch}.jpg');
    final resolved = await store.resolve(path);
    expect(resolved.path, '${root.path}/$path');
    expect(resolved.existsSync(), isTrue);
    expect(await resolved.readAsBytes(), await picked.readAsBytes());
  });

  test('a legacy absolute path is re-rooted after a container move', () async {
    final old = await Directory.systemTemp.createTemp('ampdent-old-container');
    final legacy = File('${old.path}/licences/lic-9-1.jpg');
    await legacy.create(recursive: true);
    await legacy.writeAsBytes([1, 2, 3]);
    await File('${root.path}/licences/lic-9-1.jpg').create(recursive: true);
    await old.delete(recursive: true);
    final store = LicenceDocumentStore(baseDirectory: () async => root);
    expect(
      (await store.resolve(legacy.path)).path,
      '${root.path}/licences/lic-9-1.jpg',
    );
  });
}
