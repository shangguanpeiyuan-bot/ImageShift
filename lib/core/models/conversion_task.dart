import 'conversion_error.dart';
import 'image_format.dart';
import 'edit_options.dart';

enum TaskStatus { pending, processing, succeeded, failed, cancelled }

class ResizeOptions {
  const ResizeOptions({
    required this.width,
    required this.height,
    this.keepAspectRatio = true,
    this.preventUpscale = true,
  });

  final int width;
  final int height;
  final bool keepAspectRatio;
  final bool preventUpscale;
}

/// Immutable input to an isolated, single-file conversion. No UI or handles.
class ConversionTask {
  const ConversionTask({
    required this.id,
    required this.inputPath,
    required this.outputDirectory,
    required this.outputFormat,
    this.jpegQuality = 90,
    this.resize,
    this.edits = const EditOptions(),
    this.outputStem,
  });

  final String id;
  final String inputPath;
  final String outputDirectory;
  final RasterFormat outputFormat;
  final int jpegQuality;
  final ResizeOptions? resize;
  final EditOptions edits;
  final String? outputStem;
}

sealed class ConversionResult {
  const ConversionResult(this.taskId);
  final String taskId;
  TaskStatus get status;
}

class ConversionSuccess extends ConversionResult {
  const ConversionSuccess({
    required String taskId,
    required this.outputPath,
    required this.inputFormat,
    required this.outputFormat,
    required this.inputWidth,
    required this.inputHeight,
    required this.width,
    required this.height,
    required this.inputBytes,
    required this.outputBytes,
    required this.elapsed,
  }) : super(taskId);

  @override
  TaskStatus get status => TaskStatus.succeeded;
  final String outputPath;
  final RasterFormat inputFormat;
  final RasterFormat outputFormat;

  /// Input dimensions after EXIF orientation is applied.
  final int inputWidth;
  final int inputHeight;
  final int width;
  final int height;
  final int inputBytes;
  final int outputBytes;
  final Duration elapsed;
}

class ConversionFailure extends ConversionResult {
  const ConversionFailure({required String taskId, required this.error})
    : super(taskId);

  @override
  TaskStatus get status => TaskStatus.failed;
  final ConversionError error;
}

class ConversionCancelled extends ConversionResult {
  const ConversionCancelled(super.taskId);
  @override
  TaskStatus get status => TaskStatus.cancelled;
}
