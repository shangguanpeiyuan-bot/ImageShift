import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:imageshift/core/media/backend/ffmpeg_backend.dart';
import 'package:imageshift/core/media/backend/vips_image_backend.dart';
import 'package:imageshift/core/media/jobs/cancellation_token.dart';
import 'package:imageshift/core/media/jobs/media_job_engine.dart';
import 'package:imageshift/core/media/model/media.dart';
import 'package:imageshift/core/media/model/transcode_options.dart';
import 'package:imageshift/platform/android_media_runner.dart';
import 'package:imageshift/platform/file_access.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  for (final imageTest in [true, false]) {
    testWidgets(
      'Android packaged ${imageTest ? 'image' : 'audio'} libraries and no-replace publication',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: Text('ImageShift native verification')),
          ),
        );
        await tester.runAsync(() async {
          final directory = await Directory.systemTemp.createTemp(
            'native-verification-',
          );
          final token = CancellationToken();
          final engine = MediaJobEngine();
          await AndroidMediaRunner.beginBatch(token);
          try {
            expect(await FileAccess().availableMemoryBytes(), greaterThan(0));
            if (imageTest) {
              final source = File('${directory.path}/原图.png');
              final pixels = img.Image(width: 40, height: 20, numChannels: 4);
              pixels.setPixelRgba(20, 10, 255, 0, 0, 255);
              final original = img.encodePng(pixels);
              await source.writeAsBytes(original);
              for (final format in ['jpg', 'png', 'webp']) {
                final result = await const VipsImageBackend().execute(
                  MediaJob(
                    id: format,
                    inputPath: source.path,
                    outputDirectory: directory.path,
                    outputStem: '原图',
                    outputFormat: format,
                  ),
                  await const VipsImageBackend().probe(source.path, token),
                  token,
                  (_) {},
                );
                expect(
                  result.stage,
                  MediaStage.completed,
                  reason: '$format ${result.error}',
                );
                final decoded = img.decodeImage(
                  await File(result.outputPath!).readAsBytes(),
                )!;
                expect([decoded.width, decoded.height], [40, 20]);
                expect(decoded.getPixel(0, 0).a, format == 'jpg' ? 255 : 0);
                if (format == 'jpg') {
                  expect(decoded.getPixel(0, 0).r, greaterThanOrEqualTo(250));
                }
              }
              expect(await source.readAsBytes(), original);
              expect(
                const VipsImageBackend().outputFormats,
                isNot(contains('tiff')),
              );
              final unsupported = await engine.run(
                MediaJob(
                  id: 'tiff',
                  inputPath: source.path,
                  outputDirectory: directory.path,
                  outputFormat: 'tiff',
                ),
                const VipsImageBackend(),
                token,
              );
              expect(unsupported.error?.code, MediaErrorCode.unsupportedFormat);
            } else {
              final runner = AndroidMediaRunner();
              final backend = await FfmpegBackend.discover(
                ffmpegPath: 'ffmpeg',
                ffprobePath: 'ffprobe',
                cancellation: token,
                runner: runner,
              );
              // Actual device capability is part of the test log, without user paths.
              debugPrint(
                'ANDROID_ENCODERS=${backend.verifiedEncoders.toList()..sort()}',
              );
              final wav = '${directory.path}/tone.wav';
              final generated = await runner.run('ffmpeg', [
                '-v',
                'error',
                '-f',
                'lavfi',
                '-i',
                'sine=frequency=440:duration=1',
                '-c:a',
                'pcm_s16le',
                wav,
              ], token);
              expect(generated.exitCode, 0, reason: generated.stdout);
              for (final format in FfmpegBackend.audioEncoders.keys) {
                expect(
                  backend.verifiedEncoders,
                  contains(FfmpegBackend.audioEncoders[format]),
                );
                final result = await engine.run(
                  MediaJob(
                    id: 'audio-$format',
                    inputPath: wav,
                    outputDirectory: directory.path,
                    outputFormat: format,
                  ),
                  backend,
                  token,
                );
                expect(
                  result.stage,
                  MediaStage.completed,
                  reason: '$format ${result.error}',
                );
                expect(await File(result.outputPath!).length(), greaterThan(0));
                expect(result.probe!.kind, MediaKind.audio);
                final decoded = await runner.run('ffmpeg', [
                  '-v',
                  'error',
                  '-i',
                  result.outputPath!,
                  '-f',
                  'null',
                  '-',
                ], token);
                expect(
                  decoded.exitCode,
                  0,
                  reason: '$format ${decoded.stdout}',
                );
              }
            }
          } finally {
            await AndroidMediaRunner.endBatch();
            await directory.delete(recursive: true);
          }
        });
      },
    );
  }
  testWidgets('Android four video containers, codecs and cancellation', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Text('Android video verification')),
      ),
    );
    await tester.runAsync(() async {
      final directory = await Directory.systemTemp.createTemp(
        'video-verification-',
      );
      final token = CancellationToken();
      final runner = AndroidMediaRunner();
      await AndroidMediaRunner.beginBatch(token);
      try {
        final backend = await FfmpegBackend.discover(
          ffmpegPath: 'ffmpeg',
          ffprobePath: 'ffprobe',
          cancellation: token,
          runner: runner,
        );
        final video = '${directory.path}/source.mp4';
        final generated = await runner.run('ffmpeg', [
          '-v',
          'error',
          '-f',
          'lavfi',
          '-i',
          'testsrc2=size=64x48:rate=10:duration=0.5',
          '-f',
          'lavfi',
          '-i',
          'sine=duration=0.5',
          '-c:v',
          'libopenh264',
          '-colorspace',
          'bt709',
          '-color_primaries',
          'bt709',
          '-color_trc',
          'bt709',
          '-c:a',
          'aac',
          video,
        ], token);
        expect(generated.exitCode, 0, reason: generated.stdout);
        final engine = MediaJobEngine();
        for (final format in ['mp4', 'mkv', 'mov', 'webm']) {
          final result = await backend.execute(
            MediaJob(
              id: format,
              inputPath: video,
              outputDirectory: directory.path,
              outputFormat: format,
            ),
            await backend.probe(video, token),
            token,
            (_) {},
          );
          expect(
            result.stage,
            MediaStage.completed,
            reason: '$format ${result.error}',
          );
          expect(
            result.probe!.streams.where((s) => s.type == 'video').length,
            1,
          );
          expect(
            result.probe!.streams.where((s) => s.type == 'audio').length,
            1,
          );
          final decode = await runner.run('ffmpeg', [
            '-v',
            'error',
            '-i',
            result.outputPath!,
            '-f',
            'null',
            '-',
          ], token);
          expect(decode.exitCode, 0, reason: decode.stdout);
        }
        expect(backend.verifiedEncoders, isNot(contains('libvpx-vp9')));
        for (final codec in ['h264', 'hevc', 'av1']) {
          final result = await engine.run(
            MediaJob(
              id: codec,
              inputPath: video,
              outputDirectory: directory.path,
              outputFormat: 'mkv',
              forceTranscode: true,
              transcode: TranscodeOptions(
                videoCodec: codec,
                width: 32,
                height: 24,
              ),
            ),
            backend,
            token,
          );
          expect(
            result.stage,
            MediaStage.completed,
            reason: '$codec ${result.error}',
          );
          expect(
            result.probe!.streams.firstWhere((s) => s.type == 'video').codec,
            codec,
          );
          expect([result.probe!.width, result.probe!.height], [32, 24]);
          final decode = await runner.run('ffmpeg', [
            '-v',
            'error',
            '-i',
            result.outputPath!,
            '-f',
            'null',
            '-',
          ], token);
          expect(decode.exitCode, 0, reason: decode.stdout);
        }
        final cancellation = CancellationToken();
        final timer = Timer(
          const Duration(milliseconds: 500),
          cancellation.cancel,
        );
        try {
          await expectLater(
            runner.run('ffmpeg', [
              '-v',
              'error',
              '-re',
              '-f',
              'lavfi',
              '-i',
              'sine=duration=60',
              '-f',
              'null',
              '-',
            ], cancellation),
            throwsA(
              isA<MediaError>().having(
                (e) => e.code,
                'code',
                MediaErrorCode.cancelled,
              ),
            ),
          );
        } finally {
          timer.cancel();
        }
      } finally {
        await AndroidMediaRunner.endBatch();
        await directory.delete(recursive: true);
      }
    });
  });
  testWidgets('Android foreground batch survives Home between commands', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Text('Background batch verification')),
      ),
    );
    await tester.runAsync(() async {
      final runner = AndroidMediaRunner();
      final token = CancellationToken();
      await AndroidMediaRunner.beginBatch(token);
      debugPrint('BATCH_BACKGROUND_READY');
      try {
        for (var index = 0; index < 2; index++) {
          final result = await runner.run('ffmpeg', [
            '-v',
            'error',
            '-re',
            '-f',
            'lavfi',
            '-i',
            'sine=duration=8',
            '-f',
            'null',
            '-',
          ], token);
          expect(result.exitCode, 0, reason: result.stdout);
          debugPrint('BATCH_BACKGROUND_COMPLETED_$index');
        }
      } finally {
        await AndroidMediaRunner.endBatch();
      }
    });
  });
}
