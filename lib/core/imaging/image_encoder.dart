import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../models/conversion_error.dart';
import '../models/image_format.dart';

class ImageEncoder {
  const ImageEncoder();

  Uint8List encode(
    img.Image pixels,
    RasterFormat format, {
    int quality = 90,
    int backgroundRgb = 0xffffff,
    int pngCompression = 6,
  }) {
    if (!supportedOutputFormats.contains(format)) {
      throw const ConversionError(
        ConversionErrorCode.unsupportedFormat,
        '当前输出仅支持 JPG、PNG 和无损 WebP。',
      );
    }
    if (quality < 1 || quality > 100) {
      throw const ConversionError(
        ConversionErrorCode.invalidOptions,
        'JPG 质量必须在 1–100 之间。',
      );
    }
    try {
      switch (format) {
        case RasterFormat.jpeg:
          final rgb = img.Image(
            width: pixels.width,
            height: pixels.height,
            numChannels: 3,
          );
          img.fill(
            rgb,
            color: img.ColorRgb8(
              (backgroundRgb >> 16) & 255,
              (backgroundRgb >> 8) & 255,
              backgroundRgb & 255,
            ),
          );
          img.compositeImage(rgb, pixels);
          if (pixels.hasExif) rgb.exif = img.ExifData.from(pixels.exif);
          return img.encodeJpg(rgb, quality: quality);
        case RasterFormat.png:
          return img.encodePng(pixels, level: pngCompression);
        case RasterFormat.webp:
          // The 4.9.2 API is lossless only; there is no lossy quality parameter.
          return img.encodeWebP(
            pixels.convert(
              format: img.Format.uint8,
              numChannels: pixels.hasAlpha ? 4 : 3,
            ),
          );
        default:
          throw StateError('Output format not implemented');
      }
    } catch (error) {
      throw ConversionError(
        ConversionErrorCode.encodeFailed,
        '图片编码失败，请更换输出格式或使用较小图片。',
        detail: error.toString(),
      );
    }
  }
}
