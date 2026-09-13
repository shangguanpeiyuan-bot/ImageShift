import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:imageshift/core/media/probe/local_playlist_guard.dart';
import 'package:imageshift/core/media/model/media.dart';

void main() {
  test('local HLS validates segments and rejects network, traversal, DRM and live references', () async {
    final directory = await Directory.systemTemp.createTemp('imageshift_hls_');
    addTearDown(() => directory.delete(recursive: true));
    await File('${directory.path}/part.ts').writeAsBytes([0x47, 0, 0, 0]);
    final manifest = File('${directory.path}/local.m3u8');
    const valid = '#EXTM3U\n#EXTINF:1,\npart.ts\n#EXT-X-ENDLIST\n';
    await manifest.writeAsString(valid);
    await validateLocalMediaReferences(manifest.path);
    for (final content in [
      valid.replaceAll('part.ts', 'https://example.invalid/part.ts'),
      valid.replaceAll('part.ts', '../part.ts'),
      valid.replaceAll('part.ts', '%2e%2e/part.ts'),
      valid.replaceAll(
        '#EXTINF:',
        '#EXT-X-KEY:METHOD=AES-128,URI="part.ts"\n#EXTINF:',
      ),
      valid.replaceAll('#EXT-X-ENDLIST', ''),
      '<?xml version="1.0"?><MPD/>',
      'ffconcat version 1.0\nfile ../other.mp4',
    ]) {
      await manifest.writeAsString(content);
      await expectLater(
        validateLocalMediaReferences(manifest.path),
        throwsA(isA<MediaError>()),
      );
    }
    await manifest.writeAsString(
      '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1000\nchild.m3u8',
    );
    await File(
      '${directory.path}/child.m3u8',
    ).writeAsString(valid.replaceAll('part.ts', 'https://example.invalid/x'));
    await expectLater(
      validateLocalMediaReferences(manifest.path),
      throwsA(isA<MediaError>()),
    );
  });
}
