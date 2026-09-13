import '../core/media/model/media.dart';
import '../core/media/model/transcode_options.dart';
import '../core/models/conversion_task.dart';

/// Parameters only: never stores original paths or media bytes.
class MediaPreset {
  const MediaPreset({
    required this.id,
    required this.name,
    required this.kind,
    required this.format,
    this.options = const TranscodeOptions(),
    this.resize,
    this.jpegQuality = 90,
  });
  final String id, name, format;
  final MediaKind kind;
  final TranscodeOptions options;
  final ResizeOptions? resize;
  final int jpegQuality;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'format': format,
    'jpegQuality': jpegQuality,
    'width': resize?.width,
    'height': resize?.height,
    'options': {
      'videoCodec': options.videoCodec,
      'width': options.width,
      'height': options.height,
      'fps': options.framesPerSecond,
      'videoKbps': options.videoKbps,
      'audioKbps': options.audioKbps,
      'sampleRate': options.sampleRate,
      'channels': options.channels,
      'stripMetadata': options.stripMetadata,
    },
  };
  static MediaPreset fromJson(Map<String, dynamic> data) {
    final values = Map<String, dynamic>.from(data['options'] as Map);
    final options = TranscodeOptions(
      videoCodec: values['videoCodec'] as String?,
      width: values['width'] as int?,
      height: values['height'] as int?,
      framesPerSecond: values['fps'] as int?,
      videoKbps: values['videoKbps'] as int?,
      audioKbps: values['audioKbps'] as int?,
      sampleRate: values['sampleRate'] as int?,
      channels: values['channels'] as int?,
      stripMetadata: values['stripMetadata'] == true,
    );
    options.validate();
    final quality = data['jpegQuality'] as int;
    final width = data['width'] as int?, height = data['height'] as int?;
    final name = data['name'] as String;
    final kind = MediaKind.values.byName(data['kind'] as String);
    final format = data['format'] as String;
    if (name.isEmpty ||
        name.length > 60 ||
        quality < 1 ||
        quality > 100 ||
        (width == null) != (height == null) ||
        (width != null && (width < 1 || height! < 1)) ||
        !{
          'jpg',
          'png',
          'webp',
          'tiff',
          'mp4',
          'mkv',
          'mov',
          'webm',
          'mp3',
          'wav',
          'flac',
          'aac',
          'm4a',
          'ogg',
          'opus',
        }.contains(format)) {
      throw const FormatException('Invalid media preset');
    }
    return MediaPreset(
      id: data['id'] as String,
      name: name,
      kind: kind,
      format: format,
      jpegQuality: quality,
      resize: width == null
          ? null
          : ResizeOptions(width: width, height: height!),
      options: options,
    );
  }
}

class MediaHistoryRecord {
  const MediaHistoryRecord({
    required this.time,
    required this.total,
    required this.completed,
    required this.failed,
    required this.cancelled,
    required this.inputBytes,
    required this.outputBytes,
  });
  final DateTime time;
  final int total, completed, failed, cancelled, inputBytes, outputBytes;
  Map<String, dynamic> toJson() => {
    'time': time.toIso8601String(),
    'total': total,
    'completed': completed,
    'failed': failed,
    'cancelled': cancelled,
    'inputBytes': inputBytes,
    'outputBytes': outputBytes,
  };
  static MediaHistoryRecord fromJson(Map<String, dynamic> data) {
    int number(String key) {
      final v = data[key] as int;
      if (v < 0 || v > 1 << 52) throw const FormatException();
      return v;
    }

    return MediaHistoryRecord(
      time: DateTime.parse(data['time'] as String),
      total: number('total'),
      completed: number('completed'),
      failed: number('failed'),
      cancelled: number('cancelled'),
      inputBytes: number('inputBytes'),
      outputBytes: number('outputBytes'),
    );
  }
}
