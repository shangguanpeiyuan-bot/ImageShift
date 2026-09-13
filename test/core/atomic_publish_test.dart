import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:imageshift/core/media/output/temp_file_manager.dart';

void main() {
  test(
    'concurrent publishers never replace existing Unicode outputs',
    () async {
      final root = await Directory.systemTemp.createTemp('imageshift_atomic_');
      addTearDown(() => root.delete(recursive: true));
      final existing = await File('${root.path}/照片.png')
          .writeAsBytes([9, 8, 7]);
      final outputs = await Future.wait(
        List.generate(20, (index) async {
          final temp = await TempFileManager.create(
            root.path.replaceAll('\\', '/'),
            'png',
          );
          try {
            await temp.file.writeAsBytes([index, 1, 2], flush: true);
            return await temp.publish('照片', 'png');
          } finally {
            await temp.dispose();
          }
        }),
      );
      expect(outputs.toSet().length, 20);
      expect(await existing.readAsBytes(), [9, 8, 7]);
      final values = await Future.wait(
        outputs.map((path) async => (await File(path).readAsBytes()).first),
      );
      expect(values.toSet(), Set.from(List.generate(20, (i) => i)));
      expect(root.listSync().whereType<Directory>(), isEmpty);
    },
  );
}
