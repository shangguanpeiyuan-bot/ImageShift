import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import '../files/output_namer.dart';
import '../imaging/image_decoder.dart';
import '../imaging/image_encoder.dart';
import '../imaging/image_pipeline.dart';
import '../imaging/resource_limits.dart';
import '../models/conversion_error.dart';
import '../models/conversion_task.dart';
import '../models/image_format.dart';
import 'image_worker.dart';

class ConversionService {
  const ConversionService({this.limits = const ResourceLimits()});
  final ResourceLimits limits;

  /// CPU and file work stay off the UI isolate. Phase B owns the bounded queue;
  /// callers must not start an unbounded number of these single-file jobs.
  Future<ConversionResult> convert(ConversionTask task) async {
    final workerLimits = limits;
    try {
      return await ImageWorker.run(
        () => Isolate.run(() => _convertFile(task, workerLimits)),
      );
    } catch (error) {
      return ConversionFailure(
        taskId: task.id,
        error: ConversionError(
          ConversionErrorCode.unexpected,
          '后台处理未能完成，请使用较小图片后重试。',
          detail: error.toString(),
        ),
      );
    }
  }
}

ConversionResult _convertFile(ConversionTask task, ResourceLimits limits) {
  final timer = Stopwatch()..start();
  try {
    if (!supportedOutputFormats.contains(task.outputFormat)) {
      throw const ConversionError(
        ConversionErrorCode.unsupportedFormat,
        '当前输出仅支持 JPG、PNG 和无损 WebP。',
      );
    }
    if (task.jpegQuality < 1 ||
        task.jpegQuality > 100 ||
        (task.resize != null &&
            (task.resize!.width <= 0 || task.resize!.height <= 0))) {
      throw const ConversionError(
        ConversionErrorCode.invalidOptions,
        '请检查质量参数以及目标宽度和高度。',
      );
    }
    final bytes = _readInput(task.inputPath, limits);
    final decoded = ImageDecoder(limits: limits).decode(bytes);
    final pixels = ImagePipeline(limits: limits)
        .apply(decoded.pixels, resize: task.resize, edits: task.edits);
    final encoded = const ImageEncoder().encode(
      pixels,
      task.outputFormat,
      quality: task.jpegQuality,
      backgroundRgb: task.edits.backgroundRgb,
      pngCompression: task.edits.pngCompression,
    );
    final output = _writeOutput(task, encoded);
    return ConversionSuccess(
      taskId: task.id,
      outputPath: output.path,
      inputFormat: decoded.format,
      outputFormat: task.outputFormat,
      inputWidth: decoded.pixels.width,
      inputHeight: decoded.pixels.height,
      width: pixels.width,
      height: pixels.height,
      inputBytes: bytes.length,
      outputBytes: encoded.length,
      elapsed: timer.elapsed,
    );
  } on ConversionError catch (error) {
    return ConversionFailure(taskId: task.id, error: error);
  } catch (error) {
    return ConversionFailure(
      taskId: task.id,
      error: ConversionError(
        ConversionErrorCode.unexpected,
        '图片处理未能完成，请更换图片后重试。',
        detail: error.toString(),
      ),
    );
  }
}

Uint8List _readInput(String path, ResourceLimits limits) {
  try {
    final input = File(path);
    if (input.statSync().type != FileSystemEntityType.file) {
      throw const FileSystemException('Input is not a readable regular file');
    }
    final handle = input.openSync();
    try {
      final length = handle.lengthSync();
      if (length > limits.maxInputBytes) {
        throw const ConversionError(
          ConversionErrorCode.resourceLimit,
          '文件超过当前读取大小上限。',
        );
      }
      // Bound the actual read too, in case another application grows the file.
      final bytes = handle.readSync(length + 1);
      if (bytes.length > limits.maxInputBytes) {
        throw const ConversionError(
          ConversionErrorCode.resourceLimit,
          '文件超过当前读取大小上限。',
        );
      }
      return bytes;
    } finally {
      handle.closeSync();
    }
  } on FileSystemException catch (error) {
    throw ConversionError(
      ConversionErrorCode.readFailed,
      '无法读取文件，请检查文件是否存在以及读取权限。',
      detail: error.toString(),
    );
  }
}

File _writeOutput(ConversionTask task, Uint8List encoded) {
  File? reserved;
  try {
    if (!Directory(task.outputDirectory).existsSync()) {
      throw const FileSystemException('Output directory does not exist');
    }
    reserved = const OutputNamer().reserve(
      inputPath: task.inputPath,
      outputDirectory: task.outputDirectory,
      format: task.outputFormat,
      outputStem: task.outputStem,
    );
    reserved.writeAsBytesSync(encoded, flush: true);
    return reserved;
  } catch (error) {
    // Only remove the new output we reserved, never an existing user file.
    if (reserved != null) {
      try {
        reserved.deleteSync();
      } on FileSystemException {
        // The primary failure remains visible. The directory may need cleanup.
      }
    }
    if (error is ConversionError) rethrow;
    throw ConversionError(
      ConversionErrorCode.writeFailed,
      '无法保存图片，请检查输出目录、写入权限和可用空间。',
      detail: error.toString(),
    );
  }
}
