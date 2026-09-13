import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:imageshift/core/image_engine.dart';

/// Original, deterministic fixtures; no downloaded image assets.
img.Image rgbFixture({int width = 32, int height = 24}) {
  final image = img.Image(width: width, height: height, numChannels: 3);
  for (final pixel in image) {
    pixel
      ..r = (pixel.x * 7 + pixel.y * 3) % 256
      ..g = (pixel.x * 2 + pixel.y * 11) % 256
      ..b = (pixel.x * 13 + pixel.y * 5) % 256;
  }
  return image;
}

img.Image alphaFixture() {
  final image = img.Image(width: 48, height: 24, numChannels: 4);
  for (final pixel in image) {
    pixel
      ..r = 255
      ..g = 0
      ..b = 0
      ..a = pixel.x < 16 ? 0 : (pixel.x < 32 ? 128 : 255);
  }
  return image;
}

Uint8List fixtureBytes(RasterFormat format, [img.Image? source]) {
  final pixels = source ?? rgbFixture();
  return switch (format) {
    RasterFormat.jpeg => img.encodeJpg(pixels, quality: 95),
    RasterFormat.png => img.encodePng(pixels),
    RasterFormat.webp => img.encodeWebP(pixels),
    RasterFormat.bmp => img.encodeBmp(pixels),
    RasterFormat.gif => img.encodeGif(pixels),
    RasterFormat.tiff => img.encodeTiff(pixels),
    RasterFormat.tga => img.encodeTga(pixels),
    RasterFormat.ico => img.encodeIco(pixels),
  };
}

/// Creates a genuine two-IFD TIFF. The second directory references the same
/// immutable strip data, which is valid; unlike encodeTiff(Image.frames), this
/// actually writes a page chain. Derived only from our generated pixels.
Uint8List twoPageTiff() {
  final first = fixtureBytes(RasterFormat.tiff);
  final data = ByteData.sublistView(first);
  final endian = first[0] == 0x49 ? Endian.little : Endian.big;
  final offset = data.getUint32(4, endian);
  final count = data.getUint16(offset, endian);
  final directoryLength = 2 + count * 12 + 4;
  final result = Uint8List(first.length + directoryLength)
    ..setAll(0, first)
    ..setAll(first.length, first.sublist(offset, offset + directoryLength));
  ByteData.sublistView(result)
    ..setUint32(offset + directoryLength - 4, first.length, endian)
    ..setUint32(result.length - 4, 0, endian);
  return result;
}
