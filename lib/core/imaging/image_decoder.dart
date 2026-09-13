import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../models/conversion_error.dart';
import '../models/image_format.dart';
import 'format_detector.dart';
import 'resource_limits.dart';

class DecodedImage {
  const DecodedImage(this.format, this.pixels, {this.originalOrientation});
  final RasterFormat format;
  final img.Image pixels;
  final int? originalOrientation;
}

class ImageDecoder {
  const ImageDecoder({this.limits = const ResourceLimits()});
  final ResourceLimits limits;

  DecodedImage decode(Uint8List data) {
    if (data.length > limits.maxInputBytes) {
      throw const ConversionError(
        ConversionErrorCode.resourceLimit,
        '文件超过当前读取大小上限。',
      );
    }
    final format = const FormatDetector().detect(data);
    final img.Decoder decoder = switch (format) {
      RasterFormat.jpeg => img.JpegDecoder(),
      RasterFormat.png => img.PngDecoder(),
      RasterFormat.webp => img.WebPDecoder(),
      RasterFormat.bmp => img.BmpDecoder(),
      RasterFormat.gif => img.GifDecoder(),
      RasterFormat.tiff => img.TiffDecoder(),
      RasterFormat.tga => img.TgaDecoder(),
      RasterFormat.ico => img.IcoDecoder(),
    };
    try {
      if (format == RasterFormat.ico) return _decodeIco(data);
      if (format == RasterFormat.tiff) _checkTiffDirectory(data);
      final info = decoder.startDecode(data);
      if (info == null) throw const FormatException('Invalid image header');
      if (info.numFrames > 1) {
        throw const ConversionError(
          ConversionErrorCode.unsupportedSequence,
          '当前阶段不转换动画或多页图片，以免丢失帧或页面。',
        );
      }
      limits.checkDimensions(info.width, info.height);
      final pixels = decoder.decodeFrame(0);
      if (pixels == null) throw const FormatException('Image decode failed');
      limits.checkDimensions(pixels.width, pixels.height);
      if (pixels.numFrames > 1) {
        throw const ConversionError(
          ConversionErrorCode.unsupportedSequence,
          '当前阶段不转换动画或多页图片，以免丢失帧或页面。',
        );
      }
      // Normalize orientation before size calculations or format changes.
      final oriented =
          pixels.hasExif &&
              pixels.exif.imageIfd.hasOrientation &&
              pixels.exif.imageIfd.orientation != 1
          ? img.bakeOrientation(pixels)
          : pixels;
      return DecodedImage(
        format,
        oriented,
        originalOrientation: format == RasterFormat.jpeg
            ? img.decodeJpgExif(data)?.imageIfd.orientation
            : pixels.hasExif && pixels.exif.imageIfd.hasOrientation
            ? pixels.exif.imageIfd.orientation
            : null,
      );
    } on ConversionError {
      rethrow;
    } catch (error) {
      throw ConversionError(
        ConversionErrorCode.corruptImage,
        '无法解码图片，文件可能损坏或包含尚不支持的编码变体。',
        detail: error.toString(),
      );
    }
  }

  DecodedImage _decodeIco(Uint8List data) {
    final header = ByteData.sublistView(data);
    final count = header.getUint16(4, Endian.little);
    if (count > 1) {
      throw const ConversionError(
        ConversionErrorCode.unsupportedSequence,
        '当前阶段不转换包含多个图像的 ICO，以免丢失其他尺寸。',
      );
    }
    if (count != 1 || data.length < 22) {
      throw const FormatException('Invalid ICO directory');
    }
    final width = data[6] == 0 ? 256 : data[6];
    final height = data[7] == 0 ? 256 : data[7];
    limits.checkDimensions(width, height);
    final length = header.getUint32(14, Endian.little);
    final offset = header.getUint32(18, Endian.little);
    if (offset < 22 || length < 8 || offset + length > data.length) {
      throw const FormatException('ICO image lies outside the file');
    }
    final payload = Uint8List.sublistView(data, offset, offset + length);
    if (payload[0] != 137 ||
        payload[1] != 80 ||
        payload[2] != 78 ||
        payload[3] != 71) {
      throw const ConversionError(
        ConversionErrorCode.unsupportedFormat,
        '当前 ICO 输入仅支持内嵌 PNG 的单图像变体。',
      );
    }
    // Validate the payload's real size before allocation as well; an ICO
    // directory's nominal dimensions alone cannot bound an embedded PNG.
    final image = decode(payload).pixels;
    if (image.width != width || image.height != height) {
      throw const FormatException('ICO directory and payload sizes disagree');
    }
    return DecodedImage(RasterFormat.ico, image);
  }

  void _checkTiffDirectory(Uint8List data) {
    final header = ByteData.sublistView(data);
    final endian = data[0] == 0x49 ? Endian.little : Endian.big;
    final offset = header.getUint32(4, endian);
    if (offset < 8 || offset + 2 > data.length) {
      throw const FormatException('Invalid TIFF directory offset');
    }
    final entries = header.getUint16(offset, endian);
    final nextOffset = offset + 2 + entries * 12;
    if (nextOffset + 4 > data.length) {
      throw const FormatException('Truncated TIFF directory');
    }
    final next = header.getUint32(nextOffset, endian);
    if (next == offset) throw const FormatException('Cyclic TIFF directory');
    // Refuse a page chain before the dependency traverses it or decodes pages.
    if (next != 0) {
      throw const ConversionError(
        ConversionErrorCode.unsupportedSequence,
        '当前阶段不转换多页 TIFF，以免丢失页面。',
      );
    }
  }
}
