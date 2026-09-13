import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:imageshift/core/media/adapter/bilibili_cache_adapter.dart';
import 'package:imageshift/core/media/backend/ffmpeg_backend.dart';
import 'package:imageshift/core/media/jobs/cancellation_token.dart';
import 'package:imageshift/core/media/jobs/media_job_engine.dart';
import 'package:imageshift/core/media/model/media.dart';

void main() {
  final directory = Platform.environment['IMAGESHIFT_FFMPEG_DIR'];
  test(
    'generated double m4s identifies by streams, muxes and preserves originals',
    () async {
      final sandbox = await Directory.systemTemp.createTemp('bili_adapter_');
      final cache = await Directory(p.join(sandbox.path, '本地缓存')).create();
      final ffmpeg = p.join(directory!, 'ffmpeg.exe');
      final backend = FfmpegBackend(
        ffmpegPath: ffmpeg,
        ffprobePath: p.join(directory, 'ffprobe.exe'),
        verifiedEncoders: {},
      );
      try {
        Future<void> fixture(String name, List<String> args) async {
          final result = await Process.run(ffmpeg, [
            '-v',
            'error',
            ...args,
            '-t',
            '1',
            '-movflags',
            'frag_keyframe+empty_moov',
            '-f',
            'mp4',
            p.join(cache.path, name),
          ]);
          expect(result.exitCode, 0, reason: '${result.stderr}');
        }

        await fixture('not_audio.m4s', [
          '-f',
          'lavfi',
          '-i',
          'sine=frequency=600',
          '-c:a',
          'aac',
        ]);
        await fixture('not_video.m4s', [
          '-f',
          'lavfi',
          '-i',
          'color=s=160x120:r=10',
          '-c:v',
          'libopenh264',
        ]);
        final originals = {
          for (final file in cache.listSync().whereType<File>())
            file.path: file.readAsBytesSync(),
        };
        final adapter = BilibiliCacheAdapter(backend);
        expect(
          await adapter.inspect(cache.path, CancellationToken()),
          isNotNull,
        );
        final prepared = await adapter.prepare(cache.path, CancellationToken());
        expect(prepared.primaryPath, endsWith('not_video.m4s'));
        final result = await MediaJobEngine().run(
          MediaJob(
            id: 'bili',
            inputPath: prepared.primaryPath,
            audioPath: prepared.additionalPaths.single,
            outputStem: prepared.suggestedName,
            outputDirectory: sandbox.path,
            outputFormat: 'mp4',
          ),
          backend,
          CancellationToken(),
        );
        expect(result.stage, MediaStage.completed, reason: '${result.error}');
        final probe = await backend.probe(
          result.outputPath!,
          CancellationToken(),
        );
        expect(probe.streams.map((s) => s.codec), containsAll(['h264', 'aac']));
        expect([probe.width, probe.height], [160, 120]);
        expect(probe.duration!.inMilliseconds, inInclusiveRange(900, 1400));
        for (final entry in originals.entries) {
          expect(File(entry.key).readAsBytesSync(), entry.value);
        }
      } finally {
        await sandbox.delete(recursive: true);
      }
    },
    skip: directory == null ? 'Requires verified FFmpeg bundle' : false,
  );
}
