import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../image_engine.dart';
import '../imaging/image_resizer.dart';
import 'image_worker.dart';

class ImageInspection {
  const ImageInspection({
    required this.format,
    required this.width,
    required this.height,
    required this.bytes,
    required this.hasAlpha,
    required this.metadata,
    required this.thumbnail,
  });
  final RasterFormat format;
  final int width, height, bytes;
  final bool hasAlpha;
  final Map<String, String> metadata;
  final Uint8List thumbnail;
}

class ImageInspector {
  const ImageInspector();
  Future<ImageInspection> inspect(
    String path, {
    int previewSize = 160,
    bool fullResolution = false,
    ResizeOptions? resize,
    EditOptions edits = const EditOptions(),
  }) => ImageWorker.run(
    () => Isolate.run(
      () => inspectSync(
        path,
        previewSize: previewSize,
        fullResolution: fullResolution,
        resize: resize,
        edits: edits,
      ),
    ),
  );

  static ImageInspection inspectSync(
    String path, {
    int previewSize = 160,
    bool fullResolution = false,
    ResizeOptions? resize,
    EditOptions edits = const EditOptions(),
  }) {
    const limits = ResourceLimits();
    Uint8List bytes;
    try {
      final handle = File(path).openSync();
      try {
        final length = handle.lengthSync();
        if (length > limits.maxInputBytes) {
          throw const ConversionError(
            ConversionErrorCode.resourceLimit,
            '文件超过 128 MiB 读取上限。',
          );
        }
        bytes = handle.readSync(length + 1);
      } finally {
        handle.closeSync();
      }
    } on FileSystemException {
      throw const ConversionError(
        ConversionErrorCode.readFailed,
        '无法读取此文件，请检查权限或重新选择。',
      );
    }
    final decoded = const ImageDecoder().decode(bytes);
    final source = decoded.pixels;
    final fields = <String, String>{};
    if (decoded.originalOrientation != null) {
      fields['原始 EXIF 方向'] = '${decoded.originalOrientation}（预览已校正）';
    }
    if (source.hasExif && !source.exif.isEmpty) {
      fields['EXIF'] = '检测到';
      for (final tag in {
        'Make': '相机品牌',
        'Model': '相机型号',
        'DateTime': '文件时间',
      }.entries) {
        final value = source.exif.imageIfd[tag.key]?.toString();
        if (value != null && value.isNotEmpty) fields[tag.value] = value;
      }
      final date = source.exif.exifIfd['DateTimeOriginal']?.toString();
      if (date != null) fields['拍摄时间'] = date;
      if (!source.exif.gpsIfd.isEmpty) fields['GPS'] = '检测到位置标签';
    }
    if (source.iccProfile != null) fields['ICC'] = '检测到色彩配置';
    for (final entry in (source.textData ?? <String, String>{}).entries.take(
      20,
    )) {
      fields['文本 · ${entry.key}'] = entry.value.length > 300
          ? '${entry.value.substring(0, 300)}…'
          : entry.value;
    }
    final pixels = const ImagePipeline().apply(
      source,
      resize: resize,
      edits: edits,
    );
    final thumb = fullResolution
        ? pixels
        : const ImageResizer().resize(
            pixels,
            ResizeOptions(
              width: previewSize.clamp(32, 2048),
              height: previewSize.clamp(32, 2048),
            ),
          );
    // Preview bytes carry pixels only; metadata stays in the inspection model.
    thumb.exif = img.ExifData();
    thumb.textData = null;
    thumb.iccProfile = null;
    return ImageInspection(
      format: decoded.format,
      width: pixels.width,
      height: pixels.height,
      bytes: bytes.length,
      hasAlpha: source.hasAlpha,
      metadata: Map.unmodifiable(fields),
      thumbnail: img.encodePng(thumb),
    );
  }
}
