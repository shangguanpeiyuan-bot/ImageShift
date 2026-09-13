import '../../models/conversion_task.dart';
import 'transcode_options.dart';

enum MediaKind { image, video, audio, unknown }

enum MediaStage {
  queued,
  probing,
  preparing,
  processing,
  finalizing,
  completed,
  failed,
  cancelled,
}

enum MediaErrorCode {
  unsupportedFormat,
  unsupportedCodec,
  unsupportedProtection,
  corruptedMedia,
  permissionDenied,
  diskFull,
  outOfMemory,
  resourceUnavailable,
  encoderUnavailable,
  decoderUnavailable,
  invalidParameters,
  cancelled,
  processFailed,
  temporaryFileFailure,
  unknown,
}

class MediaError implements Exception {
  const MediaError(this.code, this.message, {this.backend, this.exitCode});
  final MediaErrorCode code;
  final String message;
  final String? backend;
  final int? exitCode;
  @override
  String toString() => message;
}

class MediaStreamInfo {
  const MediaStreamInfo({
    required this.index,
    required this.type,
    required this.codec,
    this.width,
    this.height,
    this.sampleRate,
    this.channels,
    this.bitrate,
    this.framesPerSecond,
    this.attachedPicture = false,
  });
  final int index;

  /// Includes subtitle/data independently from the file's main media kind.
  final String type, codec;
  final int? width, height, sampleRate, channels, bitrate;
  final bool attachedPicture;
  final double? framesPerSecond;
}

class MediaProbe {
  MediaProbe({
    required this.kind,
    required this.format,
    required this.bytes,
    this.width,
    this.height,
    this.duration,
    this.bitrate,
    this.orientation,
    this.alpha,
    List<MediaStreamInfo> streams = const [],
    Map<String, String> metadata = const {},
  }) : streams = List.unmodifiable(streams),
       metadata = Map.unmodifiable(metadata);
  final MediaKind kind;
  final String format;
  final int bytes;
  final int? width, height, bitrate, orientation;
  final Duration? duration;
  final bool? alpha;
  final List<MediaStreamInfo> streams;
  final Map<String, String> metadata;
}

class MediaProgress {
  const MediaProgress(this.stage, {this.processed, this.total});
  final MediaStage stage;
  final Duration? processed, total;
  double? get fraction {
    if (stage == MediaStage.completed) return 1;
    if (processed == null || total == null || total!.inMicroseconds <= 0) {
      return null;
    }
    return (processed!.inMicroseconds / total!.inMicroseconds).clamp(0, 1);
  }
}

class MediaJob {
  const MediaJob({
    required this.id,
    required this.inputPath,
    required this.outputDirectory,
    required this.outputFormat,
    this.imageTask,
    this.outputStem,
    this.audioPath,
    this.forceTranscode = false,
    this.transcode = const TranscodeOptions(),
  });
  final String id, inputPath, outputDirectory, outputFormat;
  final String? outputStem;
  final String? audioPath;
  final bool forceTranscode;
  final TranscodeOptions transcode;
  final ConversionTask? imageTask;
}

class MediaResult {
  const MediaResult({
    required this.jobId,
    required this.stage,
    this.outputPath,
    this.probe,
    this.error,
    this.elapsed = Duration.zero,
  });
  final String jobId;
  final MediaStage stage;
  final String? outputPath;
  final MediaProbe? probe;
  final MediaError? error;
  final Duration elapsed;
}
