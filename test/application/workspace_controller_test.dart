import 'dart:io';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:imageshift/application/workspace_controller.dart';
import 'package:imageshift/core/image_engine.dart';
import 'package:imageshift/platform/file_access.dart';
import 'package:path/path.dart' as p;

import '../support/image_fixtures.dart';

class TestFileAccess extends FileAccess {
  TestFileAccess(this.directory);
  final String directory;
  bool failExport = false;
  Completer<void>? preparation;
  @override
  Future<OutputLocation?> pickOutput() async =>
      OutputLocation(directory, directory);
  @override
  Future<String> workDirectory(OutputLocation output) async {
    await preparation?.future;
    return directory;
  }

  @override
  Future<String> publish(
    ConversionSuccess result,
    OutputLocation location,
  ) async {
    if (failExport) throw const FileSystemException('provider rejected write');
    return result.outputPath;
  }
}

void main() {
  late Directory root, output;
  late WorkspaceController c;
  late TestFileAccess files;
  setUp(() {
    root = Directory.systemTemp.createTempSync('imageshift_controller_');
    output = Directory(p.join(root.path, 'out'))..createSync();
    files = TestFileAccess(output.path);
    c = WorkspaceController(files: files);
  });
  tearDown(() {
    c.dispose();
    root.deleteSync(recursive: true);
  });
  ImportedFile image(String name, {bool invalid = false}) {
    final file = File(p.join(root.path, name))
      ..writeAsBytesSync(invalid ? [1, 2, 3] : fixtureBytes(RasterFormat.png));
    return ImportedFile(file.path, name);
  }

  test(
    'imports are isolated, duplicate paths ignored, true format used',
    () async {
      final good = image('misleading.jpg');
      await c.importFiles([good, image('bad.png', invalid: true), good]);
      expect(c.assets.length, 2);
      expect(c.selectedCount, 1);
      expect(c.assets.first.info!.format, RasterFormat.png);
      expect(c.assets.last.status, TaskStatus.failed);
      expect(c.message, contains('1 个文件'));
    },
  );
  test('start exports outputs and naming preview agrees with files', () async {
    await c.importFiles([image('first.png'), image('second.png')]);
    c.settings
      ..renameEnabled = true
      ..sequence = true
      ..prefix = 'ImageShift_'
      ..digits = 4;
    final preview = c.proposedName(c.assets.first, 0);
    await c.start();
    expect(c.queue.count(TaskStatus.succeeded), 2);
    expect(p.basename(c.assets.first.output!.outputPath), preview);
    for (final asset in c.assets) {
      expect(File(asset.publishedPath!).existsSync(), isTrue);
    }
  });
  test(
    'publication failure is never counted as a successful conversion',
    () async {
      await c.importFiles([image('photo.png')]);
      files.failExport = true;
      await c.start();
      expect(c.queue.count(TaskStatus.succeeded), 0);
      expect(c.queue.count(TaskStatus.failed), 1);
      expect(c.assets.single.publishedPath, isNull);
      files.failExport = false;
      await c.start(retryFailed: true);
      expect(c.queue.count(TaskStatus.succeeded), 1);
    },
  );
  test('repeated start during asynchronous directory preparation cannot duplicate work', () async {
    await c.importFiles([image('photo.png')]);
    c.outputLocation = OutputLocation(output.path, output.path);
    files.preparation = Completer<void>();
    final run = c.start();
    await c.start();
    files.preparation!.complete();
    await run;
    expect(output.listSync().length, 1);
  });
  test('search format and selection use separate real state', () async {
    await c.importFiles([image('travel.png'), image('work.png')]);
    c.search = 'travel';
    expect(c.visibleAssets.length, 1);
    c.filterFormat = RasterFormat.jpeg;
    expect(c.visibleAssets, isEmpty);
    c.selectAll(false);
    expect(c.selectedCount, 0);
  });
}
