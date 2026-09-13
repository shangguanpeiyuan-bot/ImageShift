import '../core/image_engine.dart';

enum ResizeMode { bounds, percent, width, height, longest, shortest }

class EditorSettings {
  RasterFormat format = RasterFormat.jpeg;
  bool keepFormat = false;
  int quality = 90, pngCompression = 6, backgroundRgb = 0xffffff;
  bool resizeEnabled = false, keepRatio = true, preventUpscale = true;
  ResizeMode resizeMode = ResizeMode.bounds;
  int width = 1920, height = 1080, percent = 50, edge = 1920;
  CropRegion? crop;
  int quarterTurns = 0;
  bool flipHorizontal = false, flipVertical = false, stripMetadata = false;
  bool renameEnabled = false, sequence = false;
  String prefix = '', suffix = '';
  int start = 1, digits = 3;

  EditOptions get edits => EditOptions(
    crop: crop,
    quarterTurns: quarterTurns,
    flipHorizontal: flipHorizontal,
    flipVertical: flipVertical,
    stripMetadata: stripMetadata,
    backgroundRgb: backgroundRgb,
    pngCompression: pngCompression,
  );
  RenameOptions get rename => RenameOptions(
    prefix: prefix,
    suffix: suffix,
    useSequence: sequence,
    start: start,
    digits: digits,
  );

  ResizeOptions? resizeFor(int sourceWidth, int sourceHeight) {
    if (!resizeEnabled) return null;
    if ((resizeMode == ResizeMode.bounds && (width <= 0 || height <= 0)) ||
        (resizeMode == ResizeMode.percent &&
            (percent <= 0 || percent > 1000)) ||
        (resizeMode != ResizeMode.bounds &&
            resizeMode != ResizeMode.percent &&
            (edge <= 0 || edge > 16384))) {
      throw const ConversionError(
        ConversionErrorCode.invalidOptions,
        '尺寸参数无效，请输入有效的正整数。',
      );
    }
    var w = width, h = height;
    if (resizeMode != ResizeMode.bounds) {
      final scale = switch (resizeMode) {
        ResizeMode.percent => percent / 100,
        ResizeMode.width => edge / sourceWidth,
        ResizeMode.height => edge / sourceHeight,
        ResizeMode.longest =>
          edge / (sourceWidth > sourceHeight ? sourceWidth : sourceHeight),
        ResizeMode.shortest =>
          edge / (sourceWidth < sourceHeight ? sourceWidth : sourceHeight),
        ResizeMode.bounds => 1.0,
      };
      w = (sourceWidth * scale).round();
      h = (sourceHeight * scale).round();
      if (w < 1) w = 1;
      if (h < 1) h = 1;
    }
    return ResizeOptions(
      width: w,
      height: h,
      keepAspectRatio: resizeMode != ResizeMode.bounds || keepRatio,
      preventUpscale: preventUpscale,
    );
  }
}
