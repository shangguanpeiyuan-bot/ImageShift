import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:imageshift/core/media/adapter/kwm_adapter.dart';
import 'package:imageshift/core/media/backend/ffmpeg_backend.dart';
import 'package:imageshift/core/media/jobs/cancellation_token.dart';
import 'package:imageshift/core/media/model/media.dart';

void main() {
  test('KWM identification requires content magic, not its suffix', () {
    expect(KwmAdapter.matches('yeelion-kuwo-tme'.codeUnits), isTrue);
    expect(
      KwmAdapter.matches('yeelion-kuwo\u0000\u0000\u0000\u0000'.codeUnits),
      isTrue,
    );
    expect(KwmAdapter.matches('not-audio.kwm'.codeUnits), isFalse);
  });
  final binary = Platform.environment['IMAGESHIFT_FFMPEG_DIR'];
  test(
    'legacy KWM streams an independent synthetic fixture to real audio',
    () async {
      final sandbox = await Directory.systemTemp.createTemp('kwm-test-');
      try {
        final backend = await FfmpegBackend.discover(
          ffmpegPath: '$binary/ffmpeg.exe',
          ffprobePath: '$binary/ffprobe.exe',
          cancellation: CancellationToken(),
        );
        final source = File('test/fixtures/media/kwm-legacy-synthetic.bin')
            .absolute;
        final original = await source.readAsBytes();
        final prepared = await KwmAdapter(
          backend,
          sandbox.path,
        ).prepare(source.path, CancellationToken());
        final probe = await backend.probe(
          prepared.primaryPath,
          CancellationToken(),
        );
        expect(probe.kind, MediaKind.audio);
        expect(probe.streams.single.codec, 'pcm_s16le');
        expect(probe.streams.single.sampleRate, 44100);
        expect(probe.duration!.inMilliseconds, 100);
        final bytes = await File(prepared.primaryPath).readAsBytes();
        expect(bytes.length, original.length - 1024);
        final decoded = await backend.runner.run(backend.ffmpegPath, [
          '-v',
          'error',
          '-i',
          prepared.primaryPath,
          '-f',
          'null',
          '-',
        ], CancellationToken());
        expect(decoded.exitCode, 0);
        expect(await source.readAsBytes(), original);
        await prepared.cleanup!();
        expect(sandbox.listSync(), isEmpty);
        final corrupt = await File('${sandbox.path}/broken.kwm')
            .writeAsString('yeelion-kuwo-tme');
        await expectLater(
          KwmAdapter(
            backend,
            sandbox.path,
          ).prepare(corrupt.path, CancellationToken()),
          throwsA(isA<MediaError>()),
        );
        expect(sandbox.listSync().length, 1);
      } finally {
        await sandbox.delete(recursive: true);
      }
    },
    skip: binary == null ? 'Requires verified FFmpeg bundle' : false,
  );
}
