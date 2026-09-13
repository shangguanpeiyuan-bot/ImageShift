import 'dart:io';
import 'dart:typed_data';

import '../../models/image_format.dart';
import '../model/media.dart';

/// libvips PNG loaders can expose only the first APNG frame. Inspect chunks
/// without allocating the image or reading an arbitrarily large chunk.
void rejectPngAnimation(File file, RasterFormat format) {
  if (format != RasterFormat.png) return;
  final handle = file.openSync();
  try {
    final length = handle.lengthSync();
    var offset = 8;
    while (offset + 12 <= length) {
      handle.setPositionSync(offset);
      final header = handle.readSync(8);
      if (header.length != 8) break;
      final size = ByteData.sublistView(header).getUint32(0);
      final type = String.fromCharCodes(header.sublist(4));
      if (type == 'acTL') {
        throw const MediaError(
          MediaErrorCode.unsupportedFormat,
          '当前转换不能完整保留 APNG 动画。',
        );
      }
      if (offset + 12 + size > length) {
        throw const MediaError(MediaErrorCode.corruptedMedia, 'PNG 数据不完整。');
      }
      if (type == 'IEND') return;
      offset += 12 + size;
    }
    throw const MediaError(MediaErrorCode.corruptedMedia, 'PNG 数据不完整。');
  } finally {
    handle.closeSync();
  }
}
