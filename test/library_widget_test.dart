import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imageshift/app/imageshift_app.dart';
import 'package:imageshift/application/local_library.dart';
import 'package:imageshift/application/workspace_controller.dart';

void main() {
  for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
    for (final size in [
      const Size(320, 640),
      const Size(844, 390),
      const Size(1100, 800),
    ]) {
      for (final theme in [ThemeMode.light, ThemeMode.dark]) {
        testWidgets('library pages $platform $size $theme', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final l = LocalLibrary()
            ..welcomed = true
            ..theme = theme;
          final c = WorkspaceController(library: l);
          await l.addPreset('一段很长的自定义预设名称，用于验证窄屏排版', c.settings);
          await tester.pumpWidget(ImageShiftApp(controller: c, library: l));
          await tester.pumpAndSettle();
          for (final page in [5, 6, 7]) {
            c.navigate(page);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: 'page $page');
          }
          await tester.pumpWidget(const SizedBox());
          c.dispose();
          await l.save();
          l.dispose();
        }, variant: TargetPlatformVariant.only(platform));
      }
    }
  }
  testWidgets('theme and preset actions update actual app state', (
    tester,
  ) async {
    final l = LocalLibrary()..welcomed = true;
    final c = WorkspaceController(library: l);
    await tester.pumpWidget(ImageShiftApp(controller: c, library: l));
    await tester.pumpAndSettle();
    c.navigate(6);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<ThemeMode>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('深色').last);
    await tester.pumpAndSettle();
    expect(l.theme, ThemeMode.dark);
    c.navigate(7);
    await tester.pumpAndSettle();
    expect(find.textContaining('内置 · 无损 WebP'), findsOneWidget);
    expect(find.textContaining('webp · 质量'), findsNothing);
    await tester.tap(find.text('网页优化 JPG'));
    await tester.pumpAndSettle();
    expect(c.settings.quality, 80);
    expect(c.settings.resizeEnabled, isTrue);
    expect(c.settings.stripMetadata, isTrue);
    expect(c.page, 1);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    await l.save();
    l.dispose();
  });
}
