import 'dart:io';

import 'package:imageshift/core/image_engine.dart';

/// Read-only verification of files produced through the native Windows UI.
void main() {
  for (final item in {
    'landscape': (1280, 800),
    'legacy': (640, 400),
    'mountain': (1280, 800),
    'transparent': (400, 300),
  }.entries) {
    final file = File('artifacts/phase-b/smoke-output/${item.key}.jpg');
    final decoded = const ImageDecoder().decode(file.readAsBytesSync());
    if (decoded.format != RasterFormat.jpeg ||
        decoded.pixels.width != item.value.$1 ||
        decoded.pixels.height != item.value.$2) {
      throw StateError('Unexpected output: ${file.path}');
    }
    if (item.key == 'transparent') {
      final pixel = decoded.pixels.getPixel(0, 0);
      if (pixel.r < 250 || pixel.g < 250 || pixel.b < 250) {
        throw StateError('Transparent corner was not composited onto white');
      }
    }
    stdout.writeln(
      '${file.path}: JPEG ${decoded.pixels.width}x${decoded.pixels.height}, ${file.lengthSync()} bytes OK',
    );
  }
}
