import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:imageshift/core/media/backend/ffmpeg_backend.dart';
import 'package:imageshift/core/media/jobs/cancellation_token.dart';
import 'package:imageshift/core/media/jobs/media_job_engine.dart';
import 'package:imageshift/core/media/model/media.dart';
import 'package:imageshift/core/media/probe/ffprobe_parser.dart';
import 'package:path/path.dart' as p;

void main() {
  test('audio cover does not misclassify an audio file as video', () {
    final probe = parseFfprobe({
      'format': {'format_name': 'mp3', 'duration': '2.5'},
      'streams': [
        {
          'index': 0,
          'codec_type': 'audio',
          'codec_name': 'mp3',
          'sample_rate': '44100',
          'channels': 2,
        },
        {
          'index': 1,
          'codec_type': 'video',
          'codec_name': 'mjpeg',
          'disposition': {'attached_pic': 1},
        },
      ],
    }, fileBytes: 123);
    expect(probe.kind, MediaKind.audio);
    expect(probe.duration, const Duration(milliseconds: 2500));
    expect(probe.streams.first.sampleRate, 44100);
  });
  test('remux decision preserves compatible streams and rejects incompatible subtitles', () {
    final backend = FfmpegBackend(
      ffmpegPath: '',
      ffprobePath: '',
      verifiedEncoders: {},
    );
    MediaProbe input(List<MediaStreamInfo> streams) => MediaProbe(
      kind: MediaKind.video,
      format: 'matroska',
      bytes: 10,
      streams: streams,
    );
    const streams = [
      MediaStreamInfo(index: 0, type: 'video', codec: 'h264'),
      MediaStreamInfo(index: 1, type: 'audio', codec: 'aac'),
    ];
    expect(backend.canRemux(input(streams), 'mp4'), isTrue);
    expect(backend.encodingArguments(input(streams), 'mp4'), [
      '-map',
      '0',
      '-c',
      'copy',
    ]);
    final subtitles = input([
      ...streams,
      const MediaStreamInfo(index: 2, type: 'subtitle', codec: 'ass'),
    ]);
    expect(backend.canRemux(subtitles, 'mp4'), isFalse);
    expect(
      () => backend.encodingArguments(subtitles, 'mp4'),
      throwsA(isA<MediaError>()),
    );
  });

  final directory = Platform.environment['IMAGESHIFT_FFMPEG_DIR'];
  test(
    'real remux, transcode and seven audio outputs re-probe correctly',
    () async {
      final sandbox = await Directory.systemTemp.createTemp('imageshift_av_');
      final ffmpeg = p.join(directory!, 'ffmpeg.exe');
      final backend = await FfmpegBackend.discover(
        ffmpegPath: ffmpeg,
        ffprobePath: p.join(directory, 'ffprobe.exe'),
        cancellation: CancellationToken(),
      );
      try {
        final source = p.join(sandbox.path, 'source.mkv');
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
          source,
        ]);
        expect(fixture.exitCode, 0, reason: '${fixture.stderr}');
        final original = await File(source).readAsBytes();
        final engine = MediaJobEngine();
        for (final format in [
          'mp4',
          'mkv',
          'mov',
          'webm',
          'mp3',
          'wav',
          'flac',
          'aac',
          'm4a',
          'ogg',
          'opus',
        ]) {
          final progress = <MediaProgress>[];
          final result = await engine.run(
            MediaJob(
              id: format,
              inputPath: source,
              outputDirectory: sandbox.path,
              outputFormat: format,
            ),
            backend,
            CancellationToken(),
            onProgress: progress.add,
          );
          expect(
            result.stage,
            MediaStage.completed,
            reason: '$format ${result.error}',
          );
          final file = File(result.outputPath!);
          expect(await file.exists(), isTrue);
          expect(await file.length(), greaterThan(0));
          final probe = await backend.probe(file.path, CancellationToken());
          final decoded = await Process.run(ffmpeg, [
            '-v',
            'error',
            '-i',
            file.path,
            '-f',
            'null',
            '-',
          ]);
          expect(decoded.exitCode, 0, reason: '$format ${decoded.stderr}');
          expect(probe.duration!.inMilliseconds, inInclusiveRange(900, 1400));
          expect(probe.streams.any((s) => s.type == 'audio'), isTrue);
          if (FfmpegBackend.videoFormats.contains(format)) {
            expect([probe.width, probe.height], [160, 120]);
            expect(
              probe.streams.firstWhere((s) => s.type == 'video').codec,
              format == 'webm' ? 'vp9' : 'h264',
            );
          } else {
            expect(probe.kind, MediaKind.audio);
          }
          expect(progress.last.stage, MediaStage.completed);
        }
        expect(await File(source).readAsBytes(), original);
        expect(sandbox.listSync().whereType<Directory>(), isEmpty);
      } finally {
        await sandbox.delete(recursive: true);
      }
    },
    skip: directory == null
        ? 'Requires verified FFmpeg bundle via IMAGESHIFT_FFMPEG_DIR'
        : false,
  );
}
