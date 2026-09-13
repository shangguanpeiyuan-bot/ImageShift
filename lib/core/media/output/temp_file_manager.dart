import 'dart:io';

import 'package:path/path.dart' as p;

import '../../files/output_namer.dart';
import '../model/media.dart';

/// Owns only its freshly created staging directory and exclusive reservation.
/// Staging on the destination volume avoids cross-volume rename copies.
class TempFileManager {
  TempFileManager._(this.directory, this.file);
  final Directory directory;
  final File file;
  bool _closed = false;

  static Future<TempFileManager> create(
    String outputDirectory,
    String extension,
  ) async {
    if (!RegExp(r'^[a-z0-9]+$').hasMatch(extension)) {
      throw const MediaError(MediaErrorCode.invalidParameters, '输出格式无效。');
    }
    final parent = Directory(outputDirectory);
    if (!await parent.exists()) {
      throw const MediaError(MediaErrorCode.temporaryFileFailure, '输出目录不存在。');
    }
    final directory = await parent.createTemp('.imageshift-');
    return TempFileManager._(
      directory,
      File(p.join(directory.path, 'output.$extension')),
    );
  }

  Future<String> publish(String stem, String extension) async {
    if (_closed || !await file.exists() || await file.length() == 0) {
      throw const MediaError(MediaErrorCode.temporaryFileFailure, '未生成完整输出。');
    }
    final name = OutputNamer.sanitizeStem(stem);
    for (var i = 0; ; i++) {
      final candidate = File(
        p.join(directory.parent.path, '$name${i == 0 ? '' : '_$i'}.$extension'),
      );
      try {
        await candidate.create(exclusive: true);
      } on FileSystemException {
        if (await FileSystemEntity.type(candidate.path, followLinks: false) !=
            FileSystemEntityType.notFound) {
          continue;
        }
        rethrow;
      }
      try {
        // Replace only the empty file exclusively created above, never a
        // pre-existing output. No check-then-overwrite of a user's file.
        await file.rename(candidate.path);
        return candidate.path;
      } catch (_) {
        await candidate.delete();
        rethrow;
      }
    }
  }

  Future<void> dispose() async {
    if (_closed) return;
    _closed = true;
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}
