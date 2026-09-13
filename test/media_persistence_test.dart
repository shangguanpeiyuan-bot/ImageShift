import 'dart:io';
import 'support/temporary_directory.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:imageshift/application/local_library.dart';
import 'package:imageshift/application/media_library.dart';
import 'package:imageshift/application/media_recovery_store.dart';
import 'package:imageshift/application/media_workspace_controller.dart';
import 'package:imageshift/core/media/backend/dart_image_backend.dart';
import 'package:imageshift/core/media/model/media.dart';
import 'package:imageshift/core/media/model/transcode_options.dart';
import 'package:imageshift/core/models/conversion_task.dart';
import 'package:imageshift/platform/file_access.dart';

void main() {
  test('media presets and summaries coexist with v1 preferences', () async {
    final folder = await Directory.systemTemp.createTemp('imageshift_library_');
    addTearDown(() => folder.delete(recursive: true));
    final store = LibraryStore(folder);
    await store.write({
      'schema': 1,
      'welcomed': true,
      'recordHistory': false,
      'presets': [],
      'history': [],
    });
    final library = LocalLibrary(store: store);
    await library.load();
    library.mediaPresets.add(
      const MediaPreset(
        id: 'video',
        name: '分享视频',
        kind: MediaKind.video,
        format: 'mp4',
        options: TranscodeOptions(videoCodec: 'h264', videoKbps: 2000),
      ),
    );
    library.mediaHistory.add(
      MediaHistoryRecord(
        time: DateTime(2026, 9, 14),
        total: 2,
        completed: 1,
        failed: 1,
        cancelled: 0,
        inputBytes: 1000,
        outputBytes: 900,
      ),
    );
    await library.save();
    final loaded = LocalLibrary(store: store);
    await loaded.load();
    expect(loaded.welcomed, isTrue);
    expect(loaded.recordHistory, isFalse);
    expect(loaded.mediaPresets.single.options.videoKbps, 2000);
    expect(loaded.mediaHistory.single.failed, 1);
    final text = await File('${folder.path}/library.json').readAsString();
    expect(text, isNot(contains('inputPath')));
    expect(text, isNot(contains('thumbnail')));
    library.dispose();
    loaded.dispose();
  });
  test(
    'recovery expiry and concurrent clear remove path metadata only',
    () async {
      final folder = await Directory.systemTemp.createTemp(
        'imageshift_recovery_',
      );
      addTearDown(() => deleteTestDirectory(folder));
      final original = await File('${folder.path}/original.bin')
          .writeAsBytes([1, 2, 3]);
      final store = MediaRecoveryStore(folder);
      await Future.wait([
        store.save([
          {'path': original.path},
        ]),
        store.clear(),
      ]);
      expect(await store.read(), isEmpty);
      await store.store.write({
        'schema': 1,
        'savedAt': DateTime.now()
            .subtract(const Duration(hours: 25))
            .toIso8601String(),
        'queue': [
          {'path': original.path},
        ],
      });
      expect(await store.read(), isEmpty);
      expect(await original.readAsBytes(), [1, 2, 3]);
      expect(store.store.directory.listSync(), isEmpty);
    },
  );
  test('pending image restores parameters, requires start and clears recovery on success', () async {
    final folder = await Directory.systemTemp.createTemp('imageshift_resume_');
    addTearDown(() => folder.delete(recursive: true));
    final source = await File('${folder.path}/private-source.png')
        .writeAsBytes(img.encodePng(img.Image(width: 40, height: 20)));
    final library = LocalLibrary(
      store: LibraryStore(Directory('${folder.path}/settings')),
    );
    final recovery = MediaRecoveryStore(folder);
    final first = MediaWorkspaceController(
      library: library,
      recovery: recovery,
      imageBackend: const DartImageBackend(),
    );
    await first.importFiles([ImportedFile(source.path, 'private-source.png')]);
    first.entries.single.resize = const ResizeOptions(width: 10, height: 10);
    first.output = OutputLocation(folder.path, 'test output');
    await first.saveRecovery();
    first.dispose();
    final restored = MediaWorkspaceController(
      library: library,
      recovery: recovery,
      imageBackend: const DartImageBackend(),
    );
    addTearDown(restored.dispose);
    addTearDown(library.dispose);
    await restored.initialize();
    expect(restored.recoverable.length, 1);
    expect(restored.entries, isEmpty);
    await restored.restorePending();
    expect(restored.entries.single.finished, isFalse);
    expect(restored.entries.single.resize!.width, 10);
    await restored.start();
    expect(
      restored.entries.single.finished,
      isTrue,
      reason: restored.entries.single.error,
    );
    final decoded = img.decodeImage(
      await File(restored.entries.single.published!).readAsBytes(),
    )!;
    expect([decoded.width, decoded.height], [10, 5]);
    expect(await recovery.read(), isEmpty);
    expect(library.mediaHistory.single.completed, 1);
    expect(
      await File('${folder.path}/settings/library.json').readAsString(),
      isNot(contains('private-source')),
    );
    expect(await source.exists(), isTrue);
  });
}
