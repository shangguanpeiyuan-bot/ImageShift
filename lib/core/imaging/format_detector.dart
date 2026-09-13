import 'dart:typed_data';

import '../models/conversion_error.dart';
import '../models/image_format.dart';

/// Identifies a candidate from content only. A decoder must validate it next.
class FormatDetector {
  const FormatDetector();

  RasterFormat detect(Uint8List data) {
    if (_matches(data, [137, 80, 78, 71, 13, 10, 26, 10])) {
      return RasterFormat.png;
    }
    if (_matches(data, [0xff, 0xd8, 0xff])) return RasterFormat.jpeg;
    if (_matches(data, [0x42, 0x4d])) return RasterFormat.bmp;
    if (_matches(data, 'RIFF'.codeUnits) &&
        _matches(data, 'WEBP'.codeUnits, 8)) {
      return RasterFormat.webp;
    }
    if (_matches(data, 'GIF87a'.codeUnits) ||
        _matches(data, 'GIF89a'.codeUnits)) {
      return RasterFormat.gif;
    }
    if (_matches(data, [0x49, 0x49, 42, 0]) ||
        _matches(data, [0x4d, 0x4d, 0, 42])) {
      return RasterFormat.tiff;
    }
    if (_matches(data, [0, 0, 1, 0])) return RasterFormat.ico;

    // TGA has no mandatory magic. Accept a conservative uncompressed truecolor
    // subset only: no color map, 24/32-bit, reserved bits clear, valid data size.
    if (data.length >= 18 &&
        data[1] == 0 &&
        data[2] == 2 &&
        data.sublist(3, 8).every((b) => b == 0) &&
        (data[16] == 24 || data[16] == 32) &&
        data[17] & 0xc0 == 0 &&
        (data[17] & 0x0f) <= (data[16] == 32 ? 8 : 0)) {
      final width = data[12] | (data[13] << 8);
      final height = data[14] | (data[15] << 8);
      final end = 18 + data[0] + width * height * (data[16] ~/ 8);
      final hasFooter =
          data.length >= end + 26 &&
          _matches(data, 'TRUEVISION-XFILE.\u0000'.codeUnits, data.length - 18);
      if (width > 0 && height > 0 && (end == data.length || hasFooter)) {
        return RasterFormat.tga;
      }
    }

    if (_matches(data, '8BPS'.codeUnits) ||
        _matches(data, [0x76, 0x2f, 0x31, 0x01]) ||
        _matches(data, 'ftyp'.codeUnits, 4) ||
        _matches(data, [0x49, 0x49, 43, 0]) ||
        _matches(data, [0x4d, 0x4d, 0, 43])) {
      throw const ConversionError(
        ConversionErrorCode.unsupportedFormat,
        '当前版本不支持此文件格式。',
      );
    }
    throw const ConversionError(
      ConversionErrorCode.invalidImage,
      '未识别到有效图片内容，请选择受支持的图片文件。',
    );
  }

  bool _matches(Uint8List data, List<int> signature, [int offset = 0]) {
    if (offset < 0 || data.length < offset + signature.length) return false;
    for (var i = 0; i < signature.length; i++) {
      if (data[offset + i] != signature[i]) return false;
    }
    return true;
  }
}
