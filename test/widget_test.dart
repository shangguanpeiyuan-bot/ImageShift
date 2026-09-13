import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imageshift/app/imageshift_app.dart';
import 'package:imageshift/application/workspace_controller.dart';
import 'package:imageshift/core/image_engine.dart';
import 'package:imageshift/core/services/image_inspector.dart';
import 'package:imageshift/platform/file_access.dart';

import '../test/support/image_fixtures.dart';

class FakeFiles extends FileAccess {
  int picks = 0;
  @override
  Future<List<ImportedFile>> pickImages() async {
    picks++;
    return [];
  }
}

void main() {
  for (final spec in [
    (TargetPlatform.windows, const Size(1600, 1000)),
    (TargetPlatform.windows, const Size(1100, 800)),
    (TargetPlatform.windows, const Size(800, 650)),
    (TargetPlatform.android, const Size(390, 844)),
    (TargetPlatform.android, const Size(844, 390)),
    (TargetPlatform.android, const Size(320, 640)),
  ]) {
    for (final dark in [false, true]) {
      testWidgets(
        'all pages fit ${spec.$1.name} ${spec.$2} ${dark ? 'dark' : 'light'}',
        (tester) async {
          tester.view.physicalSize = spec.$2;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final c = WorkspaceController(files: FakeFiles());
          addTearDown(c.dispose);
          final asset =
              ImageAsset(
                  id: 'fixture',
                  file: const ImportedFile(
                    'fixture.png',
                    '很长的图片文件名_我的旅行照片_2026.png',
                  ),
                )
                ..info = ImageInspection(
                  format: RasterFormat.png,
                  width: 32,
                  height: 24,
                  bytes: 1000,
                  hasAlpha: false,
                  metadata: const {},
                  thumbnail: fixtureBytes(RasterFormat.png),
                );
          c.assets.add(asset);
          c.focused = asset;
          await tester.pumpWidget(
            ImageShiftApp(
              controller: c,
              themeMode: dark ? ThemeMode.dark : ThemeMode.light,
            ),
          );
          await tester.pumpAndSettle();
          expect(find.textContaining('恰到好处'), findsOneWidget);
          for (final page in [1, 2, 3, 4]) {
            c.navigate(page);
            await tester.pumpAndSettle();
            final exception = tester.takeException();
            expect(exception, isNull, reason: 'page $page');
          }
          await tester.pumpWidget(const SizedBox());
        },
        variant: TargetPlatformVariant.only(spec.$1),
      );
    }
  }
  testWidgets(
    'home import button invokes real file access boundary and cancellation is normal',
    (tester) async {
      final files = FakeFiles();
      final c = WorkspaceController(files: files);
      addTearDown(c.dispose);
      await tester.pumpWidget(ImageShiftApp(controller: c));
      await tester.pumpAndSettle();
      await tester.tap(find.text('选择图片'));
      await tester.pumpAndSettle();
      expect(files.picks, 1);
      expect(c.assets, isEmpty);
      expect(c.message, isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'mobile parameter page has working switches and no fake WebP quality',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = WorkspaceController(files: FakeFiles())
        ..settings.format = RasterFormat.webp;
      addTearDown(c.dispose);
      c.navigate(1);
      await tester.pumpWidget(ImageShiftApp(controller: c));
      await tester.pumpAndSettle();
      await tester.tap(find.text('处理参数'));
      await tester.pumpAndSettle();
      expect(find.text('WebP · 无损'), findsOneWidget);
      expect(find.byType(Slider), findsNothing);
      await tester.tap(find.text('调整尺寸'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('启用尺寸调整'));
      await tester.tap(find.text('启用尺寸调整'));
      await tester.pumpAndSettle();
      expect(c.settings.resizeEnabled, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
