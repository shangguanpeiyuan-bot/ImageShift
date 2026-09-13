import '../../models/conversion_task.dart';
import '../../models/edit_options.dart';
import '../../models/image_format.dart';
import '../../services/conversion_service.dart';
import '../../services/image_inspector.dart';
import '../jobs/cancellation_token.dart';
import '../model/media.dart';
import 'media_backend.dart';

/// Compatibility backend: preserves v1 image semantics and resource guards.
/// Native routing must be verified before relaxing any of those guards.
class DartImageBackend implements MediaBackend {
  const DartImageBackend();
  @override
  String get id => 'dart-image';

  @override
  Future<MediaProbe> probe(String path, CancellationToken cancellation) async {
    cancellation.throwIfCancelled();
    final info = await const ImageInspector().inspect(path);
    cancellation.throwIfCancelled();
    return MediaProbe(
      kind: MediaKind.image,
      format: info.format.extension,
      bytes: info.bytes,
      width: info.width,
      height: info.height,
      alpha: info.hasAlpha,
      metadata: info.metadata,
    );
  }

  @override
  bool supports(MediaProbe input, MediaJob job) =>
      input.kind == MediaKind.image &&
      supportedOutputFormats.any((f) => f.extension == job.outputFormat);

  @override
  Future<MediaResult> execute(
    MediaJob job,
    MediaProbe input,
    CancellationToken cancellation,
    ProgressCallback onProgress,
  ) async {
    cancellation.throwIfCancelled();
    onProgress(const MediaProgress(MediaStage.processing));
    final format = supportedOutputFormats.firstWhere(
      (f) => f.extension == job.outputFormat,
    );
    final supplied = job.imageTask;
    final task = ConversionTask(
      id: job.id,
      inputPath: job.inputPath,
      outputDirectory: job.outputDirectory,
      outputFormat: format,
      outputStem: job.outputStem,
      resize: supplied?.resize,
      jpegQuality: supplied?.jpegQuality ?? 90,
      edits: supplied?.edits ?? const EditOptions(),
    );
    final result = await const ConversionService().convert(task);
    if (result is ConversionSuccess) {
      // This v1 backend is non-interruptible once encoding starts. Preserve a
      // finished output and report completion, never claim it was cancelled.
      return MediaResult(
        jobId: job.id,
        stage: MediaStage.completed,
        outputPath: result.outputPath,
        elapsed: result.elapsed,
        probe: MediaProbe(
          kind: MediaKind.image,
          format: result.outputFormat.extension,
          bytes: result.outputBytes,
          width: result.width,
          height: result.height,
        ),
      );
    }
    final failure = result as ConversionFailure;
    throw MediaError(
      MediaErrorCode.processFailed,
      failure.error.message,
      backend: id,
    );
  }
}
