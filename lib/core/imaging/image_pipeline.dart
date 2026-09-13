import 'dart:math' as math;

import 'package:image/image.dart' as img;

import '../models/conversion_task.dart';
import '../models/edit_options.dart';
import 'image_resizer.dart';
import 'resource_limits.dart';

class ImagePipeline {
  const ImagePipeline({this.limits = const ResourceLimits()});
  final ResourceLimits limits;

  img.Image apply(
    img.Image source, {
    ResizeOptions? resize,
    EditOptions edits = const EditOptions(),
  }) {
    edits.validate();
    var pixels = ImageResizer(limits: limits).resize(source, resize);
    final crop = edits.crop;
    if (crop != null) {
      final x = (crop.left * pixels.width).floor().clamp(0, pixels.width - 1);
      final y = (crop.top * pixels.height).floor().clamp(0, pixels.height - 1);
      pixels = img.copyCrop(
        pixels,
        x: x,
        y: y,
        width: math.max(1, (crop.width * pixels.width).floor()),
        height: math.max(1, (crop.height * pixels.height).floor()),
      );
    }
    if (edits.quarterTurns % 4 != 0) {
      pixels = img.copyRotate(pixels, angle: (edits.quarterTurns % 4) * 90);
    }
    if (edits.flipHorizontal) {
      pixels = img.flipHorizontal(img.Image.from(pixels));
    }
    if (edits.flipVertical) pixels = img.flipVertical(img.Image.from(pixels));
    if (edits.stripMetadata) {
      pixels = img.Image.from(pixels)
        ..exif = img.ExifData()
        ..textData = null
        ..iccProfile = null;
    }
    return pixels;
  }
}
