import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:imageshift/core/image_engine.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../support/image_fixtures.dart';

void main() {
  late Directory root, output;
  setUp(() {
    root = Directory.systemTemp.createTempSync('imageshift_queue_');
    output = Directory(p.join(root.path, 'out'))..createSync();
  });
  tearDown(() => root.deleteSync(recursive: true));
  ConversionTask task(String id, {bool corrupt = false}) {
    final file = File(p.join(root.path, '$id.png'))
      ..writeAsBytesSync(corrupt ? [1, 2, 3] : fixtureBytes(RasterFormat.png));
    return ConversionTask(
      id: id,
      inputPath: file.path,
      outputDirectory: output.path,
      outputFormat: RasterFormat.jpeg,
    );
  }

  test(
    'one bad file is isolated and all valid results exist and decode',
    () async {
      final queue = TaskQueue(runner: const ConversionService().convert);
      await queue.start([
        task('first'),
        task('broken', corrupt: true),
        task('last'),
      ]);
      expect(queue.count(TaskStatus.succeeded), 2);
      expect(queue.count(TaskStatus.failed), 1);
      expect(queue.completed, 3);
      expect(queue.isRunning, isFalse);
      var bytes = 0;
      for (final result
          in queue.entries
              .map((e) => e.result)
              .whereType<ConversionSuccess>()) {
        final file = File(result.outputPath);
        expect(file.existsSync(), isTrue);
        expect(
          img.findFormatForData(file.readAsBytesSync()),
          img.ImageFormat.jpg,
        );
        final image = img.decodeJpg(file.readAsBytesSync())!;
        expect((image.width, image.height), (32, 24));
        bytes += file.lengthSync();
      }
      expect(queue.outputBytes, bytes);
    },
  );
  test(
    'cancel stops pending work but completes the active output safely',
    () async {
      final gate = Completer<void>(), entered = Completer<void>();
      final started = <String>[];
      final queue = TaskQueue(
        runner: (t) async {
          started.add(t.id);
          entered.complete();
          await gate.future;
          return const ConversionService().convert(t);
        },
      );
      final run = queue.start([task('first'), task('second'), task('third')]);
      await entered.future;
      queue.cancel();
      expect(queue.count(TaskStatus.cancelled), 2);
      expect(queue.count(TaskStatus.processing), 1);
      expect(queue.isRunning, isTrue);
      gate.complete();
      await run;
      expect(started, ['first']);
      expect(queue.count(TaskStatus.succeeded), 1);
      expect(queue.completed, 3);
      final result = queue.entries.first.result as ConversionSuccess;
      expect(
        img.decodeJpg(File(result.outputPath).readAsBytesSync()),
        isNotNull,
      );
      expect(output.listSync().length, 1);
    },
  );
  test(
    'repeated start is refused and worker concurrency stays at one',
    () async {
      var active = 0, peak = 0;
      final gate = Completer<void>();
      final queue = TaskQueue(
        runner: (t) async {
          active++;
          if (active > peak) peak = active;
          await gate.future;
          final r = await const ConversionService().convert(t);
          active--;
          return r;
        },
      );
      final run = queue.start([task('a'), task('b')]);
      await expectLater(queue.start([task('other')]), throwsStateError);
      gate.complete();
      await run;
      expect(peak, 1);
      expect(output.listSync().length, 2);
    },
  );
  test('unexpected worker exception becomes a per-file failure', () async {
    final queue = TaskQueue(
      runner: (t) async {
        if (t.id == 'bad') throw const FileSystemException('provider gone');
        return const ConversionService().convert(t);
      },
    );
    await queue.start([task('bad'), task('good')]);
    expect(queue.count(TaskStatus.failed), 1);
    expect(queue.count(TaskStatus.succeeded), 1);
  });
  test('failed file can be repaired and retried into a fresh run', () async {
    final broken = task('retry', corrupt: true);
    final queue = TaskQueue(runner: const ConversionService().convert);
    await queue.start([broken]);
    expect(queue.count(TaskStatus.failed), 1);
    File(broken.inputPath).writeAsBytesSync(fixtureBytes(RasterFormat.png));
    await queue.start([broken]);
    expect(queue.count(TaskStatus.succeeded), 1);
    expect(
      img.decodeJpg(
        File((queue.entries.single.result as ConversionSuccess).outputPath)
            .readAsBytesSync(),
      ),
      isNotNull,
    );
  });
}
