import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:imageshift/core/media/backend/dart_image_backend.dart';
import 'package:imageshift/core/media/jobs/cancellation_token.dart';
import 'package:imageshift/core/media/jobs/media_job_engine.dart';
import 'package:imageshift/core/media/jobs/resource_scheduler.dart';
import 'package:imageshift/core/media/model/media.dart';
import 'package:imageshift/core/media/output/temp_file_manager.dart';

void main() {
  test('unknown duration never fabricates a percentage', () {
    expect(const MediaProgress(MediaStage.processing).fraction, isNull);
    expect(
      const MediaProgress(
        MediaStage.processing,
        processed: Duration(seconds: 2),
        total: Duration(seconds: 4),
      ).fraction,
      .5,
    );
    expect(const MediaProgress(MediaStage.completed).fraction, 1);
  });

  test(
    'cancelled queued work exits without occupying or leaking a slot',
    () async {
      final scheduler = ResourceScheduler();
      final hold = Completer<void>();
      final first = scheduler.run(CancellationToken(), () => hold.future);
      final token = CancellationToken();
      final second = scheduler.run(
        token,
        () async => fail('Cancelled work ran'),
      );
      token.cancel();
      await expectLater(second, throwsA(isA<MediaError>()));
      hold.complete();
      await first;
      expect(await scheduler.run(CancellationToken(), () async => 42), 42);
    },
  );

  test(
    'scheduler recovers after failure and preserves bounded concurrency',
    () async {
      final scheduler = ResourceScheduler(capacity: 2);
      var active = 0, peak = 0;
      await Future.wait(
        List.generate(
          8,
          (i) => scheduler.run(CancellationToken(), () async {
            active++;
            if (active > peak) peak = active;
            await Future<void>.delayed(const Duration(milliseconds: 5));
            active--;
          }),
        ),
      );
      expect(peak, 2);
      await expectLater(
        scheduler.run(
          CancellationToken(),
          () async => throw StateError('test'),
        ),
        throwsStateError,
      );
      expect(await scheduler.run(CancellationToken(), () async => 7), 7);
    },
  );

  test(
    'staged output publishes with numbering and cleans only its own temp',
    () async {
      final dir = await Directory.systemTemp.createTemp('media_publish_');
      try {
        final original = File('${dir.path}/photo.mp4');
        await original.writeAsBytes([1, 2, 3]);
        final temp = await TempFileManager.create(dir.path, 'mp4');
        await temp.file.writeAsBytes([4, 5, 6]);
        final path = await temp.publish('photo', 'mp4');
        await temp.dispose();
        expect(path, endsWith('photo_1.mp4'));
        expect(await File(path).readAsBytes(), [4, 5, 6]);
        expect(await original.readAsBytes(), [1, 2, 3]);
        expect(await temp.directory.exists(), isFalse);
      } finally {
        await dir.delete(recursive: true);
      }
    },
  );

  test(
    'unified engine uses real image backend and survives a bad job',
    () async {
      final dir = await Directory.systemTemp.createTemp('media_engine_');
      try {
        final bytes = img.encodePng(img.Image(width: 31, height: 19));
        final input = File('${dir.path}/misnamed.bin');
        await input.writeAsBytes(bytes);
        final engine = MediaJobEngine();
        const backend = DartImageBackend();
        final stages = <MediaStage>[];
        final result = await engine.run(
          MediaJob(
            id: 'ok',
            inputPath: input.path,
            outputDirectory: dir.path,
            outputFormat: 'jpg',
          ),
          backend,
          CancellationToken(),
          onProgress: (p) => stages.add(p.stage),
        );
        expect(result.stage, MediaStage.completed);
        final output = File(result.outputPath!);
        expect(await output.exists(), isTrue);
        final outputBytes = await output.readAsBytes();
        expect(img.findFormatForData(outputBytes), img.ImageFormat.jpg);
        final decoded = img.decodeImage(outputBytes)!;
        expect([decoded.width, decoded.height], [31, 19]);
        expect(await input.readAsBytes(), bytes);
        expect(stages.last, MediaStage.completed);
        final bad = await engine.run(
          MediaJob(
            id: 'bad',
            inputPath: '${dir.path}/missing',
            outputDirectory: dir.path,
            outputFormat: 'jpg',
          ),
          backend,
          CancellationToken(),
        );
        expect(bad.stage, MediaStage.failed);
        final token = CancellationToken()..cancel();
        final cancelled = await engine.run(
          MediaJob(
            id: 'cancel',
            inputPath: input.path,
            outputDirectory: dir.path,
            outputFormat: 'jpg',
          ),
          backend,
          token,
        );
        expect(cancelled.stage, MediaStage.cancelled);
      } finally {
        await dir.delete(recursive: true);
      }
    },
  );
}
