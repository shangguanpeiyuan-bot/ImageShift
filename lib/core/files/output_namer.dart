import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/conversion_error.dart';
import '../models/image_format.dart';

/// Reserves a new file atomically. File.exists + write alone is not safe when
/// separate workers choose the same name. Never uses rename-over-existing.
class OutputNamer {
  const OutputNamer();

  File reserve({
    required String inputPath,
    required String outputDirectory,
    required RasterFormat format,
    String? outputStem,
  }) {
    final stem = sanitizeStem(
      outputStem ?? p.basenameWithoutExtension(inputPath),
    );
    for (var index = 0; index < 10000; index++) {
      final suffix = index == 0 ? '' : '_$index';
      final file = File(
        p.join(outputDirectory, '$stem$suffix.${format.extension}'),
      );
      if (FileSystemEntity.typeSync(file.path, followLinks: false) !=
          FileSystemEntityType.notFound) {
        continue;
      }
      try {
        file.createSync(exclusive: true);
        return file;
      } on FileSystemException {
        if (FileSystemEntity.typeSync(file.path, followLinks: false) !=
            FileSystemEntityType.notFound) {
          continue;
        }
        rethrow;
      }
    }
    throw const ConversionError(
      ConversionErrorCode.writeFailed,
      '同名文件过多，请选择其他输出目录。',
    );
  }

  static String sanitizeStem(String stem) {
    stem = stem.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_');
    stem = stem.replaceAll(RegExp(r'[. ]+$'), '');
    if (stem.isEmpty ||
        RegExp(
          r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$',
          caseSensitive: false,
        ).hasMatch(stem)) {
      stem = 'image';
    }
    // Leave room for the extension and conflict suffix on both platforms.
    if (stem.length > 120) stem = stem.substring(0, 120);
    return stem;
  }
}
