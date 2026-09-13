import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:imageshift/application/workspace_controller.dart';
import 'package:imageshift/core/image_engine.dart';
import 'package:imageshift/core/services/image_inspector.dart';
import 'package:imageshift/platform/file_access.dart';
import 'package:imageshift/ui/widgets/crop_dialog.dart';
import 'package:imageshift/ui/widgets/preview_panel.dart';

void main() {
  late Directory temp;
  late File source;
  setUp(() {
    temp = Directory.systemTemp.createTempSync('imageshift_preview_');
    source = File('${temp.path}/source.png')
      ..writeAsBytesSync(img.encodePng(img.Image(width: 2400, height: 100)));
  });
  tearDown(() => temp.deleteSync(recursive: true));

  test(
    'full resolution inspection retains pixels beyond thumbnail bound',
    () async {
      final thumbnail = await const ImageInspector().inspect(
        source.path,
        previewSize: 2048,
      );
      final full = await const ImageInspector().inspect(
        source.path,
        fullResolution: true,
      );
      expect(img.decodePng(thumbnail.thumbnail)!.width, 2048);
      expect(img.decodePng(full.thumbnail)!.width, 2400);
      expect(img.decodePng(full.thumbnail)!.height, 100);
    },
  );

  Future<void> finishIo(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 350));
    });
    await tester.pumpAndSettle();
  }

  for (final size in [const Size(390, 844), const Size(1100, 800)]) {
    testWidgets('crop ratio, reset and apply use actual image at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      CropRegion? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await showCropEditor(context, path: source.path);
                  },
                  child: const Text('open'),
                ),
              );
            },
          ),
        ),
      );
      await tester.runAsync(() => tester.tap(find.text('open')));
      await finishIo(tester);
      expect(find.text('自由裁剪'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<double>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1 : 1').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('重置范围'));
      await tester.pumpAndSettle();
      expect(find.text('自由裁剪'), findsOneWidget);
      await tester.tap(find.text('应用裁剪'));
      await tester.pumpAndSettle();
      await finishIo(tester);
      expect(result, isNotNull);
      result!.validate();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('preview loads full pixels and returns to fit', (tester) async {
    final asset = ImageAsset(
      id: 'preview',
      file: ImportedFile(source.path, 'source.png'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showImageDetails(context, asset),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() => tester.tap(find.text('open')));
    await finishIo(tester);
    expect(find.text('100%'), findsOneWidget);
    await tester.runAsync(() => tester.tap(find.text('100%')));
    await finishIo(tester);
    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    expect(viewer.transformationController!.value.entry(0, 0), 1);
    await tester.tap(find.text('适应窗口'));
    await tester.pumpAndSettle();
    expect(viewer.transformationController!.value.entry(0, 0), lessThan(1));
    expect(tester.takeException(), isNull);
  });
}
