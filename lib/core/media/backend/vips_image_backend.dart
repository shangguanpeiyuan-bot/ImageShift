import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:libvips_ffi_api/libvips_ffi_api.dart' as vips;
import 'package:libvips_ffi_windows/libvips_ffi_windows.dart' as core;
import 'package:path/path.dart' as p;

import '../../imaging/format_detector.dart';
import '../../models/conversion_task.dart';
import '../jobs/cancellation_token.dart';
import '../jobs/image_resource_policy.dart';
import '../model/media.dart';
import '../output/temp_file_manager.dart';
import '../probe/image_sequence_guard.dart';
import 'media_backend.dart';
import 'vips_runtime.dart';

class VipsImageBackend implements MediaBackend {
  const VipsImageBackend({this.windowsLibraryDirectory});
  final String? windowsLibraryDirectory;
  @override
  String get id => 'libvips';

  // This Android bundle has no TIFF saver (device-tested); do not advertise
  // desktop capabilities on Android. Keep input decoding separately probed.
  Set<String> get outputFormats => {
    'jpg',
    'png',
    'webp',
    if (!Platform.isAndroid) 'tiff',
  };

  @override
  Future<MediaProbe> probe(String path, CancellationToken cancellation) async {
    cancellation.throwIfCancelled();
    final directory = windowsLibraryDirectory;
    final info = await Isolate.run(() => _inspect(path, directory));
    cancellation.throwIfCancelled();
    return info;
  }

  @override
  bool supports(MediaProbe input, MediaJob job) =>
      input.kind == MediaKind.image && outputFormats.contains(job.outputFormat);

  @override
  Future<MediaResult> execute(
    MediaJob job,
    MediaProbe input,
    CancellationToken cancellation,
    ProgressCallback onProgress,
  ) async {
    cancellation.throwIfCancelled();
    if (!supports(input, job)) {
      throw const MediaError(
        MediaErrorCode.unsupportedFormat,
        '此平台的图片后端不支持该输出格式。',
      );
    }
    checkImageResources(input, job);
    final temp = await TempFileManager.create(
      job.outputDirectory,
      job.outputFormat,
    );
    final watch = Stopwatch()..start();
    try {
      final directory = windowsLibraryDirectory;
      final output = temp.file.path;
      onProgress(const MediaProgress(MediaStage.processing));
      await Isolate.run(() => _convert(job, output, directory));
      // Native synchronous evaluation finishes before cleanup. A cancelled
      // result is never published even if the encoder already wrote bytes.
      cancellation.throwIfCancelled();
      onProgress(const MediaProgress(MediaStage.finalizing));
      final verified = await probe(output, cancellation);
      final published = await temp.publish(
        job.outputStem ?? p.basenameWithoutExtension(job.inputPath),
        job.outputFormat,
      );
      return MediaResult(
        jobId: job.id,
        stage: MediaStage.completed,
        outputPath: published,
        probe: verified,
        elapsed: watch.elapsed,
      );
    } finally {
      await temp.dispose();
    }
  }
}

MediaProbe _inspect(String path, String? directory) {
  initializeVips(windowsLibraryDirectory: directory);
  final file = File(path);
  final handle = file.openSync();
  final header = handle.readSync(65536);
  handle.closeSync();
  // Strong content signatures, never the filename. Native decode then
  // verifies the candidate. Additional HEIF/AVIF loaders are not enabled yet.
  final format = const FormatDetector().detect(header);
  rejectPngAnimation(file, format);
  final pipeline = vips.VipsPipeline.fromFile('$path[access=sequential]');
  try {
    if (core.vipsBindings.vips_image_get_n_pages(pipeline.image.pointer) > 1) {
      throw const MediaError(
        MediaErrorCode.unsupportedFormat,
        '当前转换不能完整保留动画或多页图片。',
      );
    }
    final orientation = core.vipsBindings.vips_image_get_orientation(
      pipeline.image.pointer,
    );
    pipeline.autoRotate();
    return MediaProbe(
      kind: MediaKind.image,
      format: format.extension,
      bytes: file.lengthSync(),
      width: pipeline.width,
      height: pipeline.height,
      alpha: pipeline.hasAlpha,
      orientation: orientation,
    );
  } finally {
    pipeline.dispose();
  }
}

void _convert(MediaJob job, String output, String? directory) {
  initializeVips(windowsLibraryDirectory: directory);
  final options = job.imageTask;
  final resize = options?.resize;
  options?.edits.validate();
  if (options != null &&
      (options.jpegQuality < 1 || options.jpegQuality > 100)) {
    throw const MediaError(MediaErrorCode.invalidParameters, '质量必须为 1–100。');
  }
  final pipeline = vips.VipsPipeline.fromFile(
    '${job.inputPath}[access=sequential]',
  );
  try {
    if (core.vipsBindings.vips_image_get_n_pages(pipeline.image.pointer) > 1) {
      throw const MediaError(
        MediaErrorCode.unsupportedFormat,
        '当前转换不能保留动画或多页。',
      );
    }
    pipeline.autoRotate();
    if (resize != null) _resize(pipeline, resize);
    final edits = options?.edits;
    if (edits?.crop case final crop?) {
      final width = math.max(1, (pipeline.width * crop.width).round());
      final height = math.max(1, (pipeline.height * crop.height).round());
      pipeline.crop(
        (pipeline.width * crop.left).round().clamp(0, pipeline.width - width),
        (pipeline.height * crop.top).round().clamp(0, pipeline.height - height),
        width,
        height,
      );
    }
    if (edits != null) {
      if (edits.quarterTurns % 4 != 0) {
        pipeline.rotate((edits.quarterTurns % 4) * 90.0);
      }
      if (edits.flipHorizontal) pipeline.flipHorizontal();
      if (edits.flipVertical) pipeline.flipVertical();
    }
    // JPEG's native saver composites alpha using this explicit background.
    final color = edits?.backgroundRgb ?? 0xffffff;
    final background =
        '${(color >> 16) & 255} ${(color >> 8) & 255} ${color & 255}';
    final save = <String>[
      if (job.outputFormat == 'jpg') 'Q=${options?.jpegQuality ?? 90}',
      if (job.outputFormat == 'jpg') 'background=$background',
      if (job.outputFormat == 'png')
        'compression=${edits?.pngCompression ?? 6}',
      if (job.outputFormat == 'webp') 'lossless=true',
      if (edits?.stripMetadata == true) 'strip=true',
    ];
    pipeline.toFile('$output${save.isEmpty ? '' : '[${save.join(',')}]'}');
  } finally {
    pipeline.dispose();
  }
}

void _resize(vips.VipsPipeline pipeline, ResizeOptions options) {
  if (options.width < 1 || options.height < 1) {
    throw const MediaError(MediaErrorCode.invalidParameters, '尺寸必须为正数。');
  }
  var scale = math.min(
    options.width / pipeline.width,
    options.height / pipeline.height,
  );
  if (options.preventUpscale) scale = math.min(1, scale);
  if (!options.keepAspectRatio) {
    throw const MediaError(
      MediaErrorCode.invalidParameters,
      '原生图片路径暂未开放非等比尺寸调整。',
    );
  }
  if (scale != 1) pipeline.resize(scale);
}
