import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../core/image_engine.dart';

class ImportedFile {
  const ImportedFile(this.path, this.name, {this.error});
  final String path, name;
  final String? error;
}

class OutputLocation {
  const OutputLocation(this.id, this.label, {this.isDocumentTree = false});
  final String id, label;
  final bool isDocumentTree;
}

/// Platform boundary. Android URIs never reach dart:io as pretend file paths.
class FileAccess {
  static const channel = MethodChannel(
    'io.github.shangguanpeiyuanbot.imageshift/files',
  );

  Future<Directory> applicationDirectory() async {
    if (Platform.isAndroid) {
      return Directory(
        (await channel.invokeMethod<String>('applicationDirectory'))!,
      );
    }
    final base = Platform.environment['LOCALAPPDATA'];
    if (base == null || base.isEmpty) {
      throw const FileSystemException('Local application data unavailable');
    }
    return Directory(p.join(base, 'ImageShift'));
  }

  Future<void> validateOutput(OutputLocation output) async {
    if (output.isDocumentTree) {
      await channel.invokeMethod<void>('validateOutput', {'tree': output.id});
    } else if (!await Directory(output.id).exists()) {
      throw const FileSystemException('Output directory no longer exists');
    }
  }

  /// Only Android-owned import/staging copies are eligible. Desktop originals
  /// and exported document URIs are never deleted by this operation.
  Future<void> releaseCache(Iterable<String> paths) async {
    if (!Platform.isAndroid) return;
    await channel.invokeMethod<void>('releaseCache', {'paths': paths.toList()});
  }

  Future<List<ImportedFile>> pickImages() async {
    if (Platform.isAndroid) {
      final result =
          await channel.invokeListMethod<dynamic>('pickImages') ?? [];
      return result.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return ImportedFile(
          map['path'] as String? ?? '',
          map['name'] as String? ?? '无法读取的文件',
          error: map['error'] as String?,
        );
      }).toList();
    }
    // Include all files so actual content, not suffix, decides acceptance.
    final files = await openFiles(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: '图片',
          extensions: [
            'jpg',
            'jpeg',
            'png',
            'webp',
            'bmp',
            'gif',
            'tif',
            'tiff',
            'tga',
            'ico',
          ],
        ),
        XTypeGroup(label: '所有文件'),
      ],
    );
    return files.map((f) => ImportedFile(f.path, f.name)).toList();
  }

  Future<OutputLocation?> pickOutput() async {
    if (Platform.isAndroid) {
      final result = await channel.invokeMapMethod<String, dynamic>(
        'pickOutput',
      );
      return result == null
          ? null
          : OutputLocation(
              result['uri'] as String,
              result['name'] as String,
              isDocumentTree: true,
            );
    }
    final path = await getDirectoryPath(confirmButtonText: '选择输出文件夹');
    return path == null ? null : OutputLocation(path, path);
  }

  Future<String> workDirectory(OutputLocation output) async {
    if (!output.isDocumentTree) return output.id;
    return (await channel.invokeMethod<String>('workDirectory'))!;
  }

  Future<String> publish(
    ConversionSuccess result,
    OutputLocation location,
  ) async {
    if (!location.isDocumentTree) return result.outputPath;
    final value = await channel.invokeMethod<String>('publish', {
      'tree': location.id,
      'path': result.outputPath,
      'name': p.basename(result.outputPath),
      'mime': switch (result.outputFormat) {
        RasterFormat.jpeg => 'image/jpeg',
        RasterFormat.png => 'image/png',
        RasterFormat.webp => 'image/webp',
        _ => throw StateError('Unimplemented output'),
      },
    });
    if (value == null) {
      throw const FileSystemException(
        'Output provider did not return a document',
      );
    }
    return value;
  }

  Future<void> openOutput(OutputLocation output) async {
    if (output.isDocumentTree) {
      await channel.invokeMethod<void>('openOutput', {'tree': output.id});
    } else if (Platform.isWindows) {
      final windows = Platform.environment['SystemRoot'];
      if (windows == null) {
        throw const FileSystemException('Windows directory unavailable');
      }
      await Process.start(p.join(windows, 'explorer.exe'), [output.id]);
    }
  }
}
