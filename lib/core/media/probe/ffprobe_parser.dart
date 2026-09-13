import '../model/media.dart';

MediaProbe parseFfprobe(Map<String, dynamic> json, {required int fileBytes}) {
  int? integer(dynamic value) => int.tryParse('$value');
  double? rate(dynamic value) {
    final parts = '$value'.split('/');
    if (parts.length != 2) return null;
    final numerator = double.tryParse(parts[0]),
        denominator = double.tryParse(parts[1]);
    if (numerator == null || denominator == null || denominator <= 0) {
      return null;
    }
    final result = numerator / denominator;
    return result.isFinite && result > 0 ? result : null;
  }

  final format = (json['format'] as Map?) ?? const {};
  final rawStreams = (json['streams'] as List?) ?? const [];
  final streams = <MediaStreamInfo>[];
  for (final raw in rawStreams.whereType<Map>()) {
    streams.add(
      MediaStreamInfo(
        index: integer(raw['index']) ?? streams.length,
        type: '${raw['codec_type'] ?? 'unknown'}',
        codec: '${raw['codec_name'] ?? 'unknown'}',
        width: integer(raw['width']),
        height: integer(raw['height']),
        sampleRate: integer(raw['sample_rate']),
        channels: integer(raw['channels']),
        bitrate: integer(raw['bit_rate']),
        framesPerSecond:
            rate(raw['avg_frame_rate']) ?? rate(raw['r_frame_rate']),
        attachedPicture: (raw['disposition'] as Map?)?['attached_pic'] == 1,
      ),
    );
  }
  final video = streams
      .where((s) => s.type == 'video' && !s.attachedPicture)
      .firstOrNull;
  final audio = streams.where((s) => s.type == 'audio').firstOrNull;
  final seconds = double.tryParse('${format['duration']}');
  if (video == null && audio == null) {
    throw const MediaError(MediaErrorCode.unsupportedFormat, '没有检测到可处理的音视频流。');
  }
  return MediaProbe(
    kind: video != null ? MediaKind.video : MediaKind.audio,
    format: '${format['format_name'] ?? 'unknown'}',
    bytes: fileBytes,
    width: video?.width,
    height: video?.height,
    streams: streams,
    duration: seconds != null && seconds.isFinite && seconds >= 0
        ? Duration(microseconds: (seconds * 1000000).round())
        : null,
    bitrate: integer(format['bit_rate']),
    metadata: {
      for (final entry in ((format['tags'] as Map?) ?? const {}).entries)
        '${entry.key}': '${entry.value}',
    },
  );
}
