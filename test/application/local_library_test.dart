import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imageshift/application/local_library.dart';
import 'package:imageshift/application/editor_serialization.dart';
import 'package:imageshift/application/editor_settings.dart';
import 'package:imageshift/application/workspace_controller.dart';
import 'package:imageshift/core/image_engine.dart';
import 'package:imageshift/platform/file_access.dart';

import '../support/image_fixtures.dart';

void main() {
  late Directory root;
  late LibraryStore store;
  setUp(() {
    root = Directory.systemTemp.createTempSync('imageshift_library_');
    store = LibraryStore(root);
  });
  tearDown(() => root.deleteSync(recursive: true));
  test(
    'restart restores theme, welcome, parameters, presets and directory',
    () async {
      final l = LocalLibrary(store: store)
        ..theme = ThemeMode.dark
        ..welcomed = true;
      l.defaults
        ..format = RasterFormat.webp
        ..crop = const CropRegion(.1, .2, .3, .4)
        ..flipVertical = true
        ..prefix = '旅途_';
      l.output = OutputLocation(root.path, 'output');
      await l.addPreset('我的预设', l.defaults);
      final reloaded = LocalLibrary(store: store);
      await reloaded.load();
      expect(reloaded.theme, ThemeMode.dark);
      expect(reloaded.welcomed, isTrue);
      expect(reloaded.defaults.toJson(), l.defaults.toJson());
      expect(reloaded.presets.single.name, '我的预设');
      expect(reloaded.output!.id, root.path);
      reloaded.presets.single.name = '已改名';
      await reloaded.save();
      final renamed = LocalLibrary(store: store);
      await renamed.load();
      expect(renamed.presets.single.name, '已改名');
      renamed.presets.clear();
      await renamed.save();
      final deleted = LocalLibrary(store: store);
      await deleted.load();
      expect(deleted.presets, isEmpty);
    },
  );
  test(
    'interrupted/corrupt current generation recovers complete backup',
    () async {
      await store.write({'schema': 1, 'welcomed': true, 'theme': 'dark'});
      await store.write({'schema': 1, 'theme': 'light'});
      await File('${root.path}/library.json').writeAsString('{broken');
      final l = LocalLibrary(store: store);
      await l.load();
      expect(l.theme, ThemeMode.dark);
      expect(l.welcomed, isTrue);
      await l.save();
      expect(
        jsonDecode(
          await File('${root.path}/library.json').readAsString(),
        )['theme'],
        'dark',
      );
    },
  );
  test('concurrent snapshots finish in order and leave valid JSON', () async {
    await Future.wait(
      List.generate(20, (i) => store.write({'schema': 1, 'number': i})),
    );
    expect((await store.read())['number'], 19);
  });
  test('future schemas and malformed records do not crash startup', () async {
    await store.write({'schema': 999, 'theme': 'dark'});
    expect(await store.read(), isEmpty);
    final restored = editorFromJson({
      'quality': 999,
      'width': -3,
      'format': 'bmp',
      'crop': [2, 2, 2, 2],
    });
    expect(restored.quality, 100);
    expect(restored.width, 1);
    expect(restored.format, RasterFormat.jpeg);
    expect(restored.crop, isNull);
  });
  test('history stores summaries only and clear survives restart', () async {
    final l = LocalLibrary(store: store);
    await l.record(
      HistoryEntry(
        id: 'one',
        time: DateTime(2026),
        total: 3,
        succeeded: 2,
        failed: 1,
        cancelled: 0,
        inputBytes: 100,
        outputBytes: 80,
        parameters: EditorSettings().toJson(),
      ),
    );
    final reloaded = LocalLibrary(store: store);
    await reloaded.load();
    expect(reloaded.history.single.total, 3);
    final json = await File('${root.path}/library.json').readAsString();
    expect(json, isNot(contains('thumbnail')));
    expect(json, isNot(contains('inputPath')));
    reloaded.history.clear();
    await reloaded.save();
    final empty = LocalLibrary(store: store);
    await empty.load();
    expect(empty.history, isEmpty);
  });
  test('built in presets map to usable engine settings', () {
    for (final p in LocalLibrary.builtIns) {
      final s = editorFromJson(p.parameters);
      s.edits.validate();
      expect([
        RasterFormat.jpeg,
        RasterFormat.png,
        RasterFormat.webp,
      ], contains(s.format));
      s.resizeFor(4000, 3000);
    }
  });
  test('lost output directory is cleared before conversion', () async {
    final input = File('${root.path}/source.png')
      ..writeAsBytesSync(fixtureBytes(RasterFormat.png));
    final l = LocalLibrary(store: store)
      ..output = OutputLocation('${root.path}/missing', 'gone');
    final c = WorkspaceController(library: l);
    await c.importFiles([ImportedFile(input.path, 'source.png')]);
    await c.start();
    expect(c.outputLocation, isNull);
    expect(c.queue.entries, isEmpty);
    expect(c.message, contains('已失效'));
    c.dispose();
    await l.save();
    final reloaded = LocalLibrary(store: store);
    await reloaded.load();
    expect(reloaded.output, isNull);
  });
  test(
    'completed real conversion records exact summary and reusable parameters',
    () async {
      final input = File('${root.path}/private-name.png')
        ..writeAsBytesSync(fixtureBytes(RasterFormat.png));
      final out = Directory('${root.path}/out')..createSync();
      final l = LocalLibrary(store: store)
        ..output = OutputLocation(out.path, 'out');
      final c = WorkspaceController(library: l);
      await c.importFiles([ImportedFile(input.path, 'private-name.png')]);
      c.edit((s) => s.quality = 77);
      await c.start();
      expect(l.history.single.succeeded, 1);
      expect(l.history.single.outputBytes, c.queue.outputBytes);
      expect(l.history.single.parameters['quality'], 77);
      expect(
        await File('${root.path}/library.json').readAsString(),
        isNot(contains('private-name')),
      );
      c.dispose();
      await l.save();
    },
  );
}
