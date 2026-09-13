import 'dart:math' as math;

import 'package:image/image.dart' as img;

import '../models/conversion_error.dart';
import '../models/conversion_task.dart';
import 'resource_limits.dart';

class ImageResizer {
  const ImageResizer({this.limits = const ResourceLimits()});
  final ResourceLimits limits;

  img.Image resize(img.Image source, ResizeOptions? options) {
    if (options == null) return source;
    if (options.width <= 0 || options.height <= 0) {
      throw const ConversionError(
        ConversionErrorCode.invalidOptions,
        '目标宽度和高度必须是正整数。',
      );
    }
    var width = options.width;
    var height = options.height;
    if (options.keepAspectRatio) {
      var scale = math.min(width / source.width, height / source.height);
      if (options.preventUpscale) scale = math.min(1.0, scale);
      width = math.max(1, (source.width * scale).floor());
      height = math.max(1, (source.height * scale).floor());
    } else if (options.preventUpscale) {
      width = math.min(width, source.width);
      height = math.min(height, source.height);
    }
    limits.checkDimensions(width, height);
    if (width == source.width && height == source.height) return source;
    return img.copyResize(
      source,
      width: width,
      height: height,
      interpolation: img.Interpolation.average,
    );
  }
}
