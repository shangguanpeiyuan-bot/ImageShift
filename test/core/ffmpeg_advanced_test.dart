import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:imageshift/core/media/backend/ffmpeg_backend.dart';
import 'package:imageshift/core/media/jobs/cancellation_token.dart';
import 'package:imageshift/core/media/jobs/media_job_engine.dart';
import 'package:imageshift/core/media/model/media.dart';
import 'package:imageshift/core/media/model/transcode_options.dart';
import 'package:imageshift/application/media_workspace_controller.dart';
import 'package:imageshift/application/media_recovery_store.dart';
import 'package:imageshift/platform/file_access.dart';

void main() {
  final directory = Platform.environment['IMAGESHIFT_FFMPEG_DIR'];
  group('verified native AV advanced', () {
    late Directory sandbox;
    late FfmpegBackend backend;
    late String ffmpeg, source;
    setUpAll(() async {
      sandbox = await Directory.systemTemp.createTemp('imageshift_advanced_');
      ffmpeg = p.join(directory!, 'ffmpeg.exe');
      backend = await FfmpegBackend.discover(
        ffmpegPath: ffmpeg,
        ffprobePath: p.join(directory, 'ffprobe.exe'),
        cancellation: CancellationToken(),
      );
      source = p.join(sandbox.path, 'source.mkv');
      final fixture = await Process.run(ffmpeg, [
        '-v',
        'error',
        '-f',
        'lavfi',
        '-i',
        'color=c=blue:s=160x120:r=10',
        '-f',
        'lavfi',
        '-i',
        'sine=frequency=440:sample_rate=44100',
        '-t',
        '1',
        '-c:v',
        'libopenh264',
        '-c:a',
        'aac',
        '-metadata',
        'title=local fixture',
        source,
      ]);
      expect(fixture.exitCode, 0, reason: '${fixture.stderr}');
    });
    tearDownAll(() => sandbox.delete(recursive: true));
    test(
      'missing replacement audio never restores a task with original audio',
      () async {
        final selected = p.join(sandbox.path, 'selected-audio.wav');
        final fixture = await Process.run(ffmpeg, [
          '-v',
          'error',
          '-i',
          source,
          '-map',
          '0:a:0',
          selected,
        ]);
        expect(fixture.exitCode, 0);
        final recovery = MediaRecoveryStore(
          Directory(p.join(sandbox.path, 'queue')),
        );
        final controller = MediaWorkspaceController(
          ffmpeg: backend,
          files: _SelectedAudioFiles(selected),
          recovery: recovery,
        );
        await controller.importFiles([ImportedFile(source, 'source.mkv')]);
        await controller.chooseReplacementAudio(controller.entries.single);
        expect(controller.entries.single.audioPath, selected);
        final saved = await recovery.read();
        expect(saved.single['audioPath'], selected);
        controller.dispose();
        // Delete only the synthetic test fixture to simulate lost permission/file.
        await File(selected).delete();
        final restored = MediaWorkspaceController(
          ffmpeg: backend,
          recovery: recovery,
        );
        addTearDown(restored.dispose);
        await restored.initialize();
        await restored.restorePending();
        expect(restored.entries, isEmpty);
        expect(restored.message, contains('该任务未恢复'));
        expect(await File(source).exists(), isTrue);
      },
    );
    test('replacement audio remux keeps video, truncates long audio and preserves sources', () async {
      final replacement = p.join(sandbox.path, 'replacement.wav');
      final fixture = await Process.run(ffmpeg, [
        '-v',
        'error',
        '-f',
        'lavfi',
        '-i',
        'sine=frequency=880:sample_rate=48000',
        '-t',
        '2',
        replacement,
      ]);
      expect(fixture.exitCode, 0);
      final original = await File(source).readAsBytes();
      final audioOriginal = await File(replacement).readAsBytes();
      final result = await MediaJobEngine().run(
        MediaJob(
          id: 'replacement',
          inputPath: source,
          audioPath: replacement,
          outputDirectory: sandbox.path,
          outputFormat: 'mkv',
          outputStem: 'replacement-video',
        ),
        backend,
        CancellationToken(),
      );
      expect(result.stage, MediaStage.completed, reason: '${result.error}');
      expect(await File(result.outputPath!).exists(), isTrue);
      expect(result.probe!.streams.map((s) => s.codec), ['h264', 'pcm_s16le']);
      expect(
        result.probe!.duration!.inMilliseconds,
        inInclusiveRange(900, 1150),
      );
      Future<String> hash(String path, String stream) async {
        final output = await Process.run(ffmpeg, [
          '-v',
          'error',
          '-i',
          path,
          '-map',
          stream,
          '-c',
          'copy',
          '-f',
          'streamhash',
          '-hash',
          'sha256',
          '-',
        ]);
        expect(output.exitCode, 0, reason: '${output.stderr}');
        return (output.stdout as String).trim();
      }

      expect(
        await hash(result.outputPath!, '0:v:0'),
        await hash(source, '0:v:0'),
      );
      final decoded = await Process.run(ffmpeg, [
        '-v',
        'error',
        '-i',
        result.outputPath!,
        '-f',
        'null',
        '-',
      ]);
      expect(decoded.exitCode, 0, reason: '${decoded.stderr}');
      expect(await File(source).readAsBytes(), original);
      expect(await File(replacement).readAsBytes(), audioOriginal);
    });
    test(
      'audio-only edits preserve the exact compressed video stream',
      () async {
        final original = await File(source).readAsBytes();
        final result = await MediaJobEngine().run(
          MediaJob(
            id: 'audio-only',
            inputPath: source,
            outputDirectory: sandbox.path,
            outputFormat: 'mp4',
            outputStem: 'audio-only',
            transcode: const TranscodeOptions(sampleRate: 48000, channels: 1),
          ),
          backend,
          CancellationToken(),
        );
        expect(result.stage, MediaStage.completed, reason: '${result.error}');
        expect(await File(result.outputPath!).exists(), isTrue);
        final audio = result.probe!.streams.firstWhere(
          (s) => s.type == 'audio',
        );
        expect([audio.sampleRate, audio.channels], [48000, 1]);
        Future<String> compressedVideoHash(String path) async {
          final hash = await Process.run(ffmpeg, [
            '-v',
            'error',
            '-i',
            path,
            '-map',
            '0:v:0',
            '-c',
            'copy',
            '-f',
            'streamhash',
            '-hash',
            'sha256',
            '-',
          ]);
          expect(hash.exitCode, 0, reason: '${hash.stderr}');
          return (hash.stdout as String).trim();
        }

        expect(
          await compressedVideoHash(result.outputPath!),
          await compressedVideoHash(source),
        );
        final decoded = await Process.run(ffmpeg, [
          '-v',
          'error',
          '-i',
          result.outputPath!,
          '-f',
          'null',
          '-',
        ]);
        expect(decoded.exitCode, 0, reason: '${decoded.stderr}');
        expect(await File(source).readAsBytes(), original);
      },
    );
    for (final codec in ['h264', 'hevc', 'av1', 'vp9']) {
      test(
        '$codec transcode resizes, changes fps and audio parameters',
        () async {
          final result = await MediaJobEngine().run(
            MediaJob(
              id: codec,
              inputPath: source,
              outputDirectory: sandbox.path,
              outputFormat: 'mkv',
              outputStem: codec,
              transcode: TranscodeOptions(
                videoCodec: codec,
                width: 80,
                height: 80,
                framesPerSecond: 5,
                videoKbps: 400,
                sampleRate: 48000,
                channels: 1,
                audioKbps: 96,
              ),
            ),
            backend,
            CancellationToken(),
          );
          expect(result.stage, MediaStage.completed, reason: '${result.error}');
          final probe = result.probe!;
          expect([probe.width, probe.height], [80, codec == 'hevc' ? 64 : 60]);
          expect(
            probe.streams.firstWhere((s) => s.type == 'video').codec,
            codec,
          );
          expect(
            probe.streams.firstWhere((s) => s.type == 'video').framesPerSecond,
            closeTo(5, 0.01),
          );
          final audio = probe.streams.firstWhere((s) => s.type == 'audio');
          expect([audio.sampleRate, audio.channels], [48000, 1]);
          expect(
            probe.metadata['TITLE'] ?? probe.metadata['title'],
            'local fixture',
          );
          final decoded = await Process.run(ffmpeg, [
            '-v',
            'error',
            '-i',
            result.outputPath!,
            '-f',
            'null',
            '-',
          ]);
          expect(decoded.exitCode, 0, reason: '${decoded.stderr}');
        },
      );
    }
    test('audio cover and title survive MP3 FLAC M4A conversions', () async {
      final cover = File(p.join(sandbox.path, 'cover.jpg'));
      await cover.writeAsBytes(img.encodeJpg(img.Image(width: 32, height: 32)));
      final covered = p.join(sandbox.path, 'covered.mp3');
      final fixture = await Process.run(ffmpeg, [
        '-v',
        'error',
        '-i',
        source,
        '-i',
        cover.path,
        '-map',
        '0:a:0',
        '-map',
        '1:v:0',
        '-c:a',
        'libmp3lame',
        '-c:v',
        'copy',
        '-disposition:v',
        'attached_pic',
        '-metadata',
        'title=local cover',
        covered,
      ]);
      expect(fixture.exitCode, 0, reason: '${fixture.stderr}');
      for (final target in ['mp3', 'flac', 'm4a']) {
        final result = await MediaJobEngine().run(
          MediaJob(
            id: target,
            inputPath: covered,
            outputDirectory: sandbox.path,
            outputFormat: target,
          ),
          backend,
          CancellationToken(),
        );
        expect(
          result.stage,
          MediaStage.completed,
          reason: '$target ${result.error}',
        );
        expect(result.probe!.kind, MediaKind.audio);
        expect(
          result.probe!.streams.any(
            (s) => s.attachedPicture && s.codec == 'mjpeg',
          ),
          isTrue,
        );
        expect(result.probe!.metadata['title'], 'local cover');
        final decoded = await Process.run(ffmpeg, [
          '-v',
          'error',
          '-i',
          result.outputPath!,
          '-f',
          'null',
          '-',
        ]);
        expect(decoded.exitCode, 0, reason: '${decoded.stderr}');
      }
    });
    test(
      'complete local HLS remux preserves streams and source segments',
      () async {
        final playlist = p.join(sandbox.path, 'local.m3u8');
        final fixture = await Process.run(ffmpeg, [
          '-v',
          'error',
          '-i',
          source,
          '-c',
          'copy',
          '-f',
          'hls',
          '-hls_time',
          '1',
          '-hls_list_size',
          '0',
          playlist,
        ]);
        expect(fixture.exitCode, 0, reason: '${fixture.stderr}');
        final original = await File(playlist).readAsBytes();
        final result = await MediaJobEngine().run(
          MediaJob(
            id: 'hls',
            inputPath: playlist,
            outputDirectory: sandbox.path,
            outputFormat: 'mp4',
          ),
          backend,
          CancellationToken(),
        );
        expect(result.stage, MediaStage.completed, reason: '${result.error}');
        expect(
          result.probe!.streams.map((s) => s.codec),
          containsAll(['h264', 'aac']),
        );
        expect(await File(playlist).readAsBytes(), original);
        final decoded = await Process.run(ffmpeg, [
          '-v',
          'error',
          '-i',
          result.outputPath!,
          '-f',
          'null',
          '-',
        ]);
        expect(decoded.exitCode, 0, reason: '${decoded.stderr}');
      },
    );
  }, skip: directory == null ? 'Requires verified FFmpeg runtime' : false);
}

class _SelectedAudioFiles extends FileAccess {
  _SelectedAudioFiles(this.path);
  final String path;
  @override
  Future<List<ImportedFile>> pickMedia() async => [
    ImportedFile(path, 'replacement.wav'),
  ];
}
