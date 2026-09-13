import 'dart:io';

import 'package:path/path.dart' as p;

import '../backend/ffmpeg_backend.dart';
import '../jobs/cancellation_token.dart';
import '../model/media.dart';
import 'media_adapter.dart';

/// Accepts the explicitly selected local directory only. Never searches user
/// profiles or guesses video/audio roles by file size.
class BilibiliCacheAdapter implements MediaAdapter {
  const BilibiliCacheAdapter(this.backend);
  final FfmpegBackend backend;
  @override
  String get id => 'bilibili-local-dash';

  Future<List<File>> _streams(String path) async {
    final directory = Directory(path);
    if (!await directory.exists()) return [];
    final files = <File>[];
    await for (final entry in directory.list(followLinks: false)) {
      if (entry is File && p.extension(entry.path).toLowerCase() == '.m4s') {
        files.add(entry);
      }
    }
    return files;
  }

  @override
  Future<AdapterMatch?> inspect(
    String path,
    CancellationToken cancellation,
  ) async {
    cancellation.throwIfCancelled();
    final files = await _streams(path);
    if (files.length != 2) return null;
    try {
      await prepare(path, cancellation);
      return const AdapterMatch(.95);
    } on MediaError catch (error) {
      if (error.code == MediaErrorCode.cancelled) rethrow;
      return null;
    }
  }

  @override
  Future<PreparedMedia> prepare(
    String path,
    CancellationToken cancellation,
  ) async {
    final files = await _streams(path);
    if (files.length != 2) {
      throw const MediaError(
        MediaErrorCode.unsupportedFormat,
        '请选择包含一条视频和一条音频 m4s 的本地缓存目录。',
      );
    }
    String? video, audio;
    for (final file in files) {
      final probe = await backend.probe(file.absolute.path, cancellation);
      final videos = probe.streams.where(
        (s) => s.type == 'video' && !s.attachedPicture,
      );
      final audios = probe.streams.where((s) => s.type == 'audio');
      if (videos.length == 1 && audios.isEmpty && video == null) {
        video = file.absolute.path;
      } else if (audios.length == 1 && videos.isEmpty && audio == null) {
        audio = file.absolute.path;
      } else {
        throw const MediaError(
          MediaErrorCode.unsupportedFormat,
          '缓存流结构不明确，无法安全合并。',
        );
      }
    }
    if (video == null || audio == null) {
      throw const MediaError(MediaErrorCode.unsupportedFormat, '缺少可识别的音频或视频流。');
    }
    return PreparedMedia(
      video,
      additionalPaths: [audio],
      suggestedName: p.basename(path),
    );
  }
}
