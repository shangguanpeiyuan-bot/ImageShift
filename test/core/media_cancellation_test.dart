import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:imageshift/core/media/backend/process_runner.dart';
import 'package:imageshift/core/media/jobs/cancellation_token.dart';
import 'package:imageshift/core/media/model/media.dart';
import 'package:imageshift/core/media/output/temp_file_manager.dart';

void main() {
  test('completed jobs unsubscribe from batch cancellation', () {
    final token = CancellationToken();
    var calls = 0;
    final remove = token.onCancel(() => calls++);
    remove();
    token.cancel();
    token.cancel();
    expect(calls, 0);
    token.onCancel(() => calls++);
    expect(calls, 1);
  });
  final directory = Platform.environment['IMAGESHIFT_FFMPEG_DIR'];
  test(
    'cancels running FFmpeg then cleans staging and permits next job',
    () async {
      final sandbox = await Directory.systemTemp.createTemp(
        'imageshift_cancel_',
      );
      addTearDown(() => sandbox.delete(recursive: true));
      final staging = await TempFileManager.create(sandbox.path, 'flac');
      final token = CancellationToken();
      final watch = Stopwatch()..start();
      const runner = MediaProcessRunner();
      final executable = p.join(directory!, 'ffmpeg.exe');
      try {
        await expectLater(
          runner.run(
            executable,
            [
              '-v',
              'error',
              '-re',
              '-f',
              'lavfi',
              '-i',
              'sine=frequency=440',
              '-t',
              '30',
              '-c:a',
              'flac',
              '-progress',
              'pipe:1',
              staging.file.path,
            ],
            token,
            onLine: (line) {
              if (line.startsWith('out_time_us=') &&
                  (int.tryParse(line.substring(12)) ?? 0) > 0) {
                token.cancel();
              }
            },
            timeout: const Duration(seconds: 10),
          ),
          throwsA(
            isA<MediaError>().having(
              (e) => e.code,
              'code',
              MediaErrorCode.cancelled,
            ),
          ),
        );
      } finally {
        await staging.dispose();
      }
      expect(watch.elapsed, lessThan(const Duration(seconds: 8)));
      expect(sandbox.listSync(), isEmpty);
      final next = await runner.run(executable, [
        '-version',
      ], CancellationToken());
      expect(next.exitCode, 0);
    },
    skip: directory == null ? 'Requires verified FFmpeg runtime' : false,
  );
}
