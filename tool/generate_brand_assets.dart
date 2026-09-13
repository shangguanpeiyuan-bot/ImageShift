// Run explicitly: flutter test --no-pub tool/generate_brand_assets.dart
// Uses the same original vector painter as the application, no external artwork.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:imageshift/ui/widgets/brand_mark.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('generate original launcher artwork from BrandPainter', () async {
    final recorder = ui.PictureRecorder();
    const BrandPainter().paint(ui.Canvas(recorder), const ui.Size(1024, 1024));
    final picture = recorder.endRecording();
    final raster = await picture.toImage(1024, 1024);
    final bytes = (await raster.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
    final pixels = img.decodePng(bytes)!;
    Directory('assets/branding').createSync(recursive: true);
    File('assets/branding/app_icon.png').writeAsBytesSync(bytes);
    for (final entry in Directory(
      'android/app/src/main/res',
    ).listSync().whereType<Directory>()) {
      final file = File('${entry.path}/ic_launcher.png');
      if (!file.existsSync()) continue;
      final old = img.decodePng(file.readAsBytesSync())!;
      file.writeAsBytesSync(
        img.encodePng(
          img.copyResize(
            pixels,
            width: old.width,
            height: old.height,
            interpolation: img.Interpolation.average,
          ),
        ),
      );
    }
    final sizes = [16, 24, 32, 48, 64, 128, 256];
    File('windows/runner/resources/app_icon.ico').writeAsBytesSync(
      img.IcoEncoder().encodeImages([
        for (final size in sizes)
          img.copyResize(
            pixels,
            width: size,
            height: size,
            interpolation: img.Interpolation.average,
          ),
      ]),
    );
    raster.dispose();
    picture.dispose();
    expect(
      img
          .decodePng(File('assets/branding/app_icon.png').readAsBytesSync())!
          .width,
      1024,
    );
  });
}
