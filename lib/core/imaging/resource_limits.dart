import '../models/conversion_error.dart';

/// Conservative per-file limits, not an operating-system memory guarantee.
class ResourceLimits {
  const ResourceLimits({
    this.maxInputBytes = 128 * 1024 * 1024,
    this.maxPixels = 24 * 1000 * 1000,
    this.maxDimension = 16384,
  });

  final int maxInputBytes;
  final int maxPixels;
  final int maxDimension;

  void checkDimensions(int width, int height) {
    if (width <= 0 || height <= 0) {
      throw const ConversionError(
        ConversionErrorCode.corruptImage,
        '图片尺寸无效，文件可能已损坏。',
      );
    }
    if (width > maxDimension ||
        height > maxDimension ||
        width * height > maxPixels) {
      throw const ConversionError(
        ConversionErrorCode.resourceLimit,
        '图片尺寸超过当前安全处理上限，请先使用较小图片。',
      );
    }
  }
}
