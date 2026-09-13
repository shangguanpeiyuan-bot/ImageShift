import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../model/media.dart';

/// Resolves every HLS reference before FFmpeg can open it. Network, encrypted,
/// live, traversal and symlink escapes are rejected, including nested playlists.
Future<void> validateLocalMediaReferences(String path) async {
  final file = File(path);
  final handle = await file.open();
  late String header;
  try {
    header = utf8
        .decode(await handle.read(4096), allowMalformed: true)
        .trimLeft();
  } finally {
    await handle.close();
  }
  if (header.startsWith('ffconcat') ||
      header.startsWith('<?xml') ||
      header.contains('<MPD') ||
      header.contains('<!DOCTYPE') ||
      header.startsWith('[playlist]')) {
    throw const MediaError(
      MediaErrorCode.unsupportedFormat,
      '此清单类型尚未完成本地引用验证，请选择实际媒体文件。',
    );
  }
  if (!header.startsWith('#EXTM3U')) return;
  final root = await file.parent.resolveSymbolicLinks();
  final visited = <String>{};
  var references = 0;
  Future<void> visit(String manifest, int depth) async {
    if (depth > 8 || visited.length >= 1000) {
      throw const MediaError(
        MediaErrorCode.resourceUnavailable,
        '播放列表层级或数量过多。',
      );
    }
    final canonical = await File(manifest).resolveSymbolicLinks();
    if (!p.isWithin(root, canonical)) {
      throw const MediaError(
        MediaErrorCode.permissionDenied,
        '播放列表引用了所选目录之外的文件。',
      );
    }
    if (!visited.add(canonical)) return;
    if (await File(canonical).length() > 1024 * 1024) {
      throw const MediaError(MediaErrorCode.resourceUnavailable, '播放列表文本过大。');
    }
    final content = await File(canonical).readAsString();
    if (!content.trimLeft().startsWith('#EXTM3U')) {
      throw const MediaError(MediaErrorCode.corruptedMedia, '无效的 HLS 播放列表。');
    }
    if (content.contains('#EXTINF:') && !content.contains('#EXT-X-ENDLIST')) {
      throw const MediaError(
        MediaErrorCode.unsupportedFormat,
        '仅支持已完整下载的本地 HLS，不处理直播列表。',
      );
    }
    for (final raw in const LineSplitter().convert(content)) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if ((line.startsWith('#EXT-X-KEY:') ||
              line.startsWith('#EXT-X-SESSION-KEY:')) &&
          !RegExp(r':METHOD=NONE(?:,|$)').hasMatch(line)) {
        throw const MediaError(
          MediaErrorCode.unsupportedProtection,
          '此 HLS 含加密或保护信息，当前不支持。',
        );
      }
      final matches = RegExp('URI="([^"]+)"').allMatches(line).toList();
      if (line.startsWith('#') && line.contains('URI=') && matches.isEmpty) {
        throw const MediaError(MediaErrorCode.corruptedMedia, '播放列表 URI 格式无效。');
      }
      final paths = line.startsWith('#')
          ? matches.map((m) => m.group(1)!)
          : [line];
      for (final relative in paths) {
        if (++references > 10000) {
          throw const MediaError(
            MediaErrorCode.resourceUnavailable,
            '播放列表引用数量过多。',
          );
        }
        if (p.isAbsolute(relative) ||
            relative.contains(RegExp(r'[:%?\\]')) ||
            relative.split('/').contains('..')) {
          throw const MediaError(
            MediaErrorCode.permissionDenied,
            '仅允许当前目录内的本地媒体片段。',
          );
        }
        final target = await File(p.join(p.dirname(canonical), relative))
            .resolveSymbolicLinks();
        if (!p.isWithin(root, target) || !await File(target).exists()) {
          throw const MediaError(
            MediaErrorCode.permissionDenied,
            '本地片段缺失或引用越出所选目录。',
          );
        }
        final input = await File(target).open();
        late String signature;
        try {
          signature = utf8
              .decode(await input.read(16), allowMalformed: true)
              .trimLeft();
        } finally {
          await input.close();
        }
        if (signature.startsWith('#EXTM3U')) await visit(target, depth + 1);
      }
    }
  }

  await visit(path, 0);
}
