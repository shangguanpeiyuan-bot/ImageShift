import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imageshift/application/media_workspace_controller.dart';
import 'package:imageshift/ui/pages/media_workbench_page.dart';
import 'package:imageshift/core/media/backend/ffmpeg_backend.dart';
import 'package:imageshift/core/media/model/media.dart';
import 'package:imageshift/platform/file_access.dart';
import 'package:imageshift/application/media_library.dart';
import 'package:imageshift/core/media/model/transcode_options.dart';

void main() {
  test('preset summary reports incompatible entries without changing them', () {
    final c = MediaWorkspaceController(
      ffmpeg: FfmpegBackend(
        ffmpegPath: '',
        ffprobePath: '',
        verifiedEncoders: {'aac', 'libopenh264'},
      ),
    );
    addTearDown(c.dispose);
    final entry =
        MediaEntry('silent', const ImportedFile('silent.mp4', 'silent'))
          ..probe = MediaProbe(
            kind: MediaKind.video,
            format: 'mp4',
            bytes: 1,
            streams: [
              const MediaStreamInfo(index: 0, type: 'video', codec: 'h264'),
            ],
          )
          ..outputFormat = 'mp4';
    c.entries.add(entry);
    c.applyPreset(
      const MediaPreset(
        id: 'audio',
        name: '音频参数',
        kind: MediaKind.video,
        format: 'mp4',
        options: TranscodeOptions(sampleRate: 48000),
      ),
    );
    expect(entry.options.sampleRate, isNull);
    expect(c.message, contains('已应用 0 项'));
    expect(c.message, contains('1 项不兼容'));
  });
  for (final size in [
    const Size(320, 520),
    const Size(844, 270),
    const Size(1280, 620),
  ]) {
    testWidgets('media workspace fits $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = MediaWorkspaceController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MediaWorkbenchPage(controller: controller)),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('导入文件'), findsOneWidget);
      controller.ffmpeg = FfmpegBackend(
        ffmpegPath: '',
        ffprobePath: '',
        verifiedEncoders: {'flac', 'aac', 'libopenh264'},
      );
      controller.entries.add(
        MediaEntry('layout', const ImportedFile('sample.mp4', '本地视频样本.mp4'))
          ..probe = MediaProbe(
            kind: MediaKind.video,
            format: 'mp4',
            bytes: 1024,
            streams: [
              const MediaStreamInfo(index: 0, type: 'video', codec: 'h264'),
            ],
          )
          ..outputFormat = 'mp4',
      );
      controller.refresh();
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('本地视频样本.mp4'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
      expect(
        controller.outputs(controller.entries.single),
        isNot(contains('mp3')),
      );
      await tester.ensureVisible(find.text('参数'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('参数'));
      await tester.pumpAndSettle();
      expect(find.text('处理参数'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('应用'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
