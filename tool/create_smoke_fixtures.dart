import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

void main() {
  final root = Directory('artifacts/phase-b/smoke-input')
    ..createSync(recursive: true);
  Directory('artifacts/phase-b/smoke-output').createSync(recursive: true);
  final landscape = img.Image(width: 1280, height: 800, numChannels: 3);
  for (final pixel in landscape) {
    final x = pixel.x / landscape.width, y = pixel.y / landscape.height;
    final mountain = .42 + .12 * math.sin(x * 9) + .06 * math.sin(x * 21);
    if (y < mountain) {
      pixel
        ..r = 190 - y * 30
        ..g = 221 - y * 20
        ..b = 224 - y * 10;
    } else if (y < .72) {
      pixel
        ..r = 35 + x * 50
        ..g = 90 + x * 50
        ..b = 85 + x * 40;
    } else {
      pixel
        ..r = 40 + y * 25
        ..g = 125 + y * 30
        ..b = 131 + y * 30;
    }
  }
  File('${root.path}/mountain.png').writeAsBytesSync(img.encodePng(landscape));
  File('${root.path}/landscape.jpg').writeAsBytesSync(img.encodeJpg(landscape));
  File('${root.path}/legacy.bmp')
      .writeAsBytesSync(img.encodeBmp(img.copyResize(landscape, width: 640)));
  final alpha = img.Image(width: 400, height: 300, numChannels: 4);
  for (final pixel in alpha) {
    pixel
      ..r = 10
      ..g = 145
      ..b = 124
      ..a =
          ((pixel.x - 200) * (pixel.x - 200) +
                  (pixel.y - 150) * (pixel.y - 150) <
              120 * 120
          ? 190
          : 0);
  }
  File('${root.path}/transparent.png').writeAsBytesSync(img.encodePng(alpha));
  File('${root.path}/damaged.png')
      .writeAsStringSync('This is not a valid image.');
}
