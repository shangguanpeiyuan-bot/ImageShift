import 'package:path/path.dart' as p;

import 'conversion_error.dart';

/// Fractions of the oriented image AFTER resizing, BEFORE rotation/flipping.
class CropRegion {
  const CropRegion(this.left, this.top, this.width, this.height);
  final double left, top, width, height;

  void validate() {
    if (![left, top, width, height].every((v) => v.isFinite) ||
        left < 0 ||
        top < 0 ||
        width <= 0 ||
        height <= 0 ||
        left + width > 1.000001 ||
        top + height > 1.000001) {
      throw const ConversionError(
        ConversionErrorCode.invalidOptions,
        '裁剪范围必须位于图片内。',
      );
    }
  }
}

class EditOptions {
  const EditOptions({
    this.crop,
    this.quarterTurns = 0,
    this.flipHorizontal = false,
    this.flipVertical = false,
    this.stripMetadata = false,
    this.backgroundRgb = 0xffffff,
    this.pngCompression = 6,
  });
  final CropRegion? crop;
  final int quarterTurns;
  final bool flipHorizontal, flipVertical, stripMetadata;
  final int backgroundRgb, pngCompression;

  void validate() {
    crop?.validate();
    if (backgroundRgb < 0 ||
        backgroundRgb > 0xffffff ||
        pngCompression < 0 ||
        pngCompression > 9) {
      throw const ConversionError(
        ConversionErrorCode.invalidOptions,
        '背景颜色或 PNG 压缩等级无效。',
      );
    }
  }
}

class RenameOptions {
  const RenameOptions({
    this.prefix = '',
    this.suffix = '',
    this.useSequence = false,
    this.start = 1,
    this.digits = 3,
  });
  final String prefix, suffix;
  final bool useSequence;
  final int start, digits;

  String stem(String name, int index) {
    if (start < 0 || digits < 1 || digits > 8 || index < 0) {
      throw const ConversionError(
        ConversionErrorCode.invalidOptions,
        '编号起始值或位数无效。',
      );
    }
    final body = useSequence
        ? (start + index).toString().padLeft(digits, '0')
        : p.basenameWithoutExtension(name);
    return '$prefix$body$suffix';
  }
}
