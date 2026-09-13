import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../core/media/adapter/bilibili_cache_adapter.dart';
import '../core/media/adapter/kwm_adapter.dart';
import '../core/media/backend/dart_image_backend.dart';
import '../core/media/backend/ffmpeg_backend.dart';
import '../core/media/backend/media_backend.dart';
import '../core/media/backend/vips_image_backend.dart';
import '../core/media/jobs/cancellation_token.dart';
import '../core/media/jobs/media_job_engine.dart';
import '../core/media/model/media.dart';
import '../core/imaging/format_detector.dart';
import '../core/models/conversion_task.dart';
import '../core/models/edit_options.dart';
import '../core/models/image_format.dart';
import '../core/media/model/transcode_options.dart';
import '../platform/file_access.dart';
import '../platform/android_media_runner.dart';
import 'local_library.dart';
import 'media_library.dart';
import 'media_recovery_store.dart';

class MediaEntry {
  MediaEntry(this.id, this.file);
  final String id;
  final ImportedFile file;
  MediaProbe? probe;
  MediaBackend? backend;
  String? audioPath, error, published;
  String outputFormat = '';
  MediaProgress progress = const MediaProgress(MediaStage.queued);
  MediaResult? result;
  TranscodeOptions options = const TranscodeOptions();
  ResizeOptions? resize;
  int jpegQuality = 90;
  bool get finished => progress.stage == MediaStage.completed;
}

class MediaWorkspaceController extends ChangeNotifier {
  MediaWorkspaceController({
    FileAccess? files,
    this.ffmpeg,
    MediaBackend? imageBackend,
    this.library,
    this.recovery,
    this.externalBusy,
  }) : files = files ?? FileAccess(),
       imageBackend = imageBackend ?? const VipsImageBackend();
  final FileAccess files;
  final LocalLibrary? library;
  final bool Function()? externalBusy;
  MediaRecoveryStore? recovery;
  List<Map<String, dynamic>> recoverable = [];
  final _activePresets = <MediaKind, MediaPreset>{};
  FfmpegBackend? ffmpeg;
  final MediaBackend imageBackend;
  final engine = MediaJobEngine();
  final entries = <MediaEntry>[];
  OutputLocation? output;
  bool _busy = false,
      _restoring = false,
      _restoreCancelled = false,
      disposed = false,
      forceTranscode = false;
  bool get isWorking => _busy || _restoring;
  bool get busy => isWorking || (externalBusy?.call() ?? false);
  set busy(bool value) => _busy = value;
  String? message;
  CancellationToken? _token;
  int _id = 0;
  void refresh() {
    if (!disposed) notifyListeners();
  }

  Future<void> initialize() async {
    try {
      if (library != null || recovery != null) {
        recovery ??= MediaRecoveryStore(await files.applicationDirectory());
        recoverable = await recovery!.read();
      }
    } catch (_) {
      message = '无法读取上次未完成队列。';
    }
    refresh();
    if (ffmpeg != null) return;
    if (Platform.isAndroid) {
      try {
        ffmpeg = await FfmpegBackend.discover(
          ffmpegPath: 'ffmpeg',
          ffprobePath: 'ffprobe',
          cancellation: CancellationToken(),
          runner: AndroidMediaRunner(),
        );
      } catch (_) {
        message = '当前设备的原生音视频组件不可用。图片工具仍可使用。';
      }
      refresh();
      return;
    }
    if (!Platform.isWindows) return;
    final directory = p.join(
      p.dirname(Platform.resolvedExecutable),
      'media',
      'ffmpeg',
    );
    if (await File(p.join(directory, 'ffmpeg.exe')).exists() &&
        await File(p.join(directory, 'ffprobe.exe')).exists()) {
      try {
        ffmpeg = await FfmpegBackend.discover(
          ffmpegPath: p.join(directory, 'ffmpeg.exe'),
          ffprobePath: p.join(directory, 'ffprobe.exe'),
          cancellation: CancellationToken(),
        );
      } catch (_) {
        message = '音视频组件无法启动，请检查应用文件是否完整。图片工具仍可使用。';
      }
    }
    refresh();
  }

  Future<void> pick() async {
    if (busy) return;
    try {
      await importFiles(await files.pickMedia());
    } catch (_) {
      message = '无法打开本地文件，请重新选择。';
      refresh();
    }
  }

  Future<void> importFiles(
    List<ImportedFile> picked, {
    bool fromRecovery = false,
  }) async {
    if (busy && !fromRecovery) return;
    busy = true;
    _token = CancellationToken();
    refresh();
    try {
      for (final file in picked) {
        if (_token!.isCancelled || disposed) break;
        if (entries.length >= 500) {
          message = '单次工作台最多保留 500 项，请先移除已完成项。';
          break;
        }
        if (entries.any((e) => p.equals(e.file.path, file.path))) continue;
        final entry = MediaEntry('media-${_id++}', file);
        entries.add(entry);
        entry.progress = const MediaProgress(MediaStage.probing);
        refresh();
        try {
          if (file.error != null) {
            throw MediaError(MediaErrorCode.permissionDenied, file.error!);
          }
          if (await Directory(file.path).exists() && ffmpeg != null) {
            final prepared = await BilibiliCacheAdapter(ffmpeg!)
                .prepare(file.path, _token!);
            entry.audioPath = prepared.additionalPaths.single;
            // Prepared primary source is kept separately from the user-visible directory.
            final probe = await ffmpeg!.probe(prepared.primaryPath, _token!);
            entry.probe = probe;
            entry.backend = ffmpeg;
            _preparedInputs[entry.id] = prepared.primaryPath;
          } else {
            await _probeEntry(entry);
          }
          entry.outputFormat = switch (entry.probe!.kind) {
            MediaKind.image => 'jpg',
            MediaKind.video => 'mp4',
            MediaKind.audio => 'flac',
            _ => '',
          };
          final formats = outputs(entry);
          if (formats.isEmpty) {
            throw const MediaError(
              MediaErrorCode.unsupportedFormat,
              '当前平台没有能完整保留这些媒体流的输出方式。',
            );
          }
          if (!formats.contains(entry.outputFormat)) {
            entry.outputFormat = formats.first;
          }
          entry.progress = const MediaProgress(MediaStage.queued);
          final preset = _activePresets[entry.probe!.kind];
          if (preset != null) _apply(entry, preset);
        } catch (error) {
          entry.error = error is MediaError
              ? error.message
              : '未识别到当前平台支持的媒体内容。';
          entry.progress = const MediaProgress(MediaStage.failed);
        }
        refresh();
      }
    } finally {
      busy = false;
      await saveRecovery();
      refresh();
      if (disposed) await _cleanupPrepared();
    }
  }

  final Map<String, String> _preparedInputs = {};
  final Map<String, Future<void> Function()> _preparedCleanup = {};
  Future<void> _probeEntry(MediaEntry entry) async {
    final handle = await File(entry.file.path).open();
    final header = await handle.read(65536);
    await handle.close();
    if (KwmAdapter.matches(header) && ffmpeg != null) {
      final prepared = await KwmAdapter(
        ffmpeg!,
        Directory.systemTemp.path,
      ).prepare(entry.file.path, _token!);
      _preparedInputs[entry.id] = prepared.primaryPath;
      _preparedCleanup[entry.id] = prepared.cleanup!;
      entry.probe = await ffmpeg!.probe(prepared.primaryPath, _token!);
      entry.backend = ffmpeg;
      return;
    }
    var imageCandidate = false;
    try {
      const FormatDetector().detect(header);
      imageCandidate = true;
    } catch (_) {
      // Conservative TGA candidate; its complete size is validated by the decoder.
      imageCandidate =
          header.length >= 18 &&
          header[1] == 0 &&
          header[2] == 2 &&
          (header[16] == 24 || header[16] == 32);
    }
    if (header.length >= 12 &&
        String.fromCharCodes(header.sublist(4, 8)) == 'ftyp' &&
        {
          'heic',
          'heix',
          'hevc',
          'hevx',
          'mif1',
          'msf1',
          'avif',
          'avis',
        }.contains(String.fromCharCodes(header.sublist(8, 12)))) {
      throw const MediaError(
        MediaErrorCode.unsupportedFormat,
        'HEIF / AVIF 图片能力尚未完成验证。',
      );
    }
    final candidates = imageCandidate
        ? <MediaBackend>[imageBackend, const DartImageBackend()]
        : <MediaBackend>[?ffmpeg];
    for (final backend in candidates) {
      try {
        entry.probe = await backend.probe(entry.file.path, _token!);
        entry.backend = backend;
        return;
      } on MediaError catch (error) {
        if (error.code == MediaErrorCode.cancelled) rethrow;
        // Recognized animation must never fall through to FFmpeg's first-frame path.
        if (error.message.contains('动画') || error.message.contains('多页')) {
          rethrow;
        }
      } catch (_) {
        /* Try the next content probe. */
      }
    }
    throw MediaError(
      MediaErrorCode.unsupportedFormat,
      ffmpeg == null ? '当前平台尚无经过验证的音视频后端，或文件格式不受支持。' : '文件损坏、受保护或格式不受支持。',
    );
  }

  List<String> outputs(MediaEntry entry) {
    final List<String> candidates = switch (entry.probe?.kind) {
      MediaKind.image =>
        entry.backend is VipsImageBackend
            ? (entry.backend as VipsImageBackend).outputFormats.toList()
            : ['jpg', 'png', 'webp'],
      MediaKind.video => [
        ...FfmpegBackend.videoFormats,
        if (entry.audioPath == null &&
            entry.probe!.streams.any((s) => s.type == 'audio'))
          ...FfmpegBackend.audioEncoders.keys.where(
            (f) =>
                ffmpeg?.verifiedEncoders.contains(
                  FfmpegBackend.audioEncoders[f],
                ) ??
                false,
          ),
      ],
      MediaKind.audio =>
        FfmpegBackend.audioEncoders.keys
            .where(
              (f) =>
                  ffmpeg?.verifiedEncoders.contains(
                    FfmpegBackend.audioEncoders[f],
                  ) ??
                  false,
            )
            .toList(),
      _ => [],
    };
    if (entry.probe?.kind == MediaKind.image) return candidates;
    return candidates.where((format) {
      try {
        ffmpeg!.encodingArguments(entry.probe!, format);
        return true;
      } on MediaError {
        return false;
      }
    }).toList();
  }

  Future<void> chooseOutput() async {
    if (busy) return;
    try {
      output = await files.pickOutput() ?? output;
      await saveRecovery();
    } catch (_) {
      message = '无法选择输出目录。';
    }
    refresh();
  }

  void cancel() {
    if (_restoring) _restoreCancelled = true;
    _token?.cancel();
    refresh();
  }

  void remove(MediaEntry entry) {
    if (busy) return;
    entries.remove(entry);
    _preparedInputs.remove(entry.id);
    unawaited(_preparedCleanup.remove(entry.id)?.call());
    unawaited(files.releaseCache([entry.file.path]).catchError((Object _) {}));
    unawaited(saveRecovery());
    // Removing a row does not delete any original or completed output.
    refresh();
  }

  Future<void> start() async {
    if (busy || output == null) return;
    busy = true;
    message = null;
    _token = CancellationToken();
    final batch = entries.where((e) => !e.finished).toList();
    refresh();
    try {
      if (Platform.isAndroid) await AndroidMediaRunner.beginBatch(_token!);
      await saveRecovery();
      await files.validateOutput(output!);
      final directory = await files.workDirectory(output!);
      for (final entry in entries.where(
        (e) => !e.finished && e.probe != null,
      )) {
        if (_token!.isCancelled) {
          entry.progress = const MediaProgress(MediaStage.cancelled);
          continue;
        }
        entry.error = null;
        final available = await files.availableMemoryBytes();
        final result = await engine.run(
          MediaJob(
            id: entry.id,
            inputPath: _preparedInputs[entry.id] ?? entry.file.path,
            audioPath: entry.audioPath,
            outputDirectory: directory,
            outputStem: p.basenameWithoutExtension(entry.file.name),
            outputFormat: entry.outputFormat,
            forceTranscode: forceTranscode,
            memoryBudgetBytes: available == null ? null : available ~/ 3,
            transcode: entry.options,
            imageTask: entry.probe!.kind == MediaKind.image
                ? ConversionTask(
                    id: entry.id,
                    inputPath: entry.file.path,
                    outputDirectory: directory,
                    outputFormat: RasterFormat.values.firstWhere(
                      (f) => f.extension == entry.outputFormat,
                    ),
                    resize: entry.resize,
                    jpegQuality: entry.jpegQuality,
                    edits: EditOptions(
                      stripMetadata: entry.options.stripMetadata,
                    ),
                  )
                : null,
          ),
          entry.backend!,
          _token!,
          onProgress: (progress) {
            entry.progress = progress;
            refresh();
          },
        );
        entry.result = result;
        entry.error = result.error?.message;
        if (result.stage == MediaStage.completed) {
          try {
            entry.progress = const MediaProgress(MediaStage.finalizing);
            entry.published = await files.publishMedia(
              result.outputPath!,
              _mime(entry.outputFormat),
              output!,
            );
            entry.progress = const MediaProgress(MediaStage.completed);
          } catch (_) {
            entry.error = '转换完成但保存到所选目录失败，请重新授权后重试。';
            entry.progress = const MediaProgress(MediaStage.failed);
          }
        }
        refresh();
        if (entry.finished) await _preparedCleanup.remove(entry.id)?.call();
        await saveRecovery();
      }
    } catch (_) {
      message = '无法访问输出目录，请重新选择并检查可用空间。';
      for (final entry in batch.where(
        (e) => e.progress.stage == MediaStage.queued,
      )) {
        entry.progress = const MediaProgress(MediaStage.failed);
        entry.error = message;
      }
    } finally {
      if (Platform.isAndroid) {
        try {
          await AndroidMediaRunner.endBatch();
        } catch (_) {
          message = '任务已结束，但后台通知状态无法确认。';
        }
      }
      busy = false;
      final l = library;
      if (l != null && l.recordHistory && batch.isNotEmpty) {
        l.mediaHistory.insert(
          0,
          MediaHistoryRecord(
            time: DateTime.now(),
            total: batch.length,
            completed: batch.where((e) => e.finished).length,
            failed: batch
                .where((e) => e.progress.stage == MediaStage.failed)
                .length,
            cancelled: batch
                .where((e) => e.progress.stage == MediaStage.cancelled)
                .length,
            inputBytes: batch
                .where((e) => e.finished)
                .fold(0, (sum, e) => sum + (e.probe?.bytes ?? 0)),
            outputBytes: batch
                .where((e) => e.finished)
                .fold(0, (sum, e) => sum + (e.result?.probe?.bytes ?? 0)),
          ),
        );
        if (l.mediaHistory.length > 200) {
          l.mediaHistory.removeRange(200, l.mediaHistory.length);
        }
        await l.save();
      }
      await saveRecovery();
      refresh();
      if (disposed) await _cleanupPrepared();
    }
  }

  MediaPreset presetFor(MediaEntry entry, String name) => MediaPreset(
    id: DateTime.now().microsecondsSinceEpoch.toString(),
    name: name,
    kind: entry.probe!.kind,
    format: entry.outputFormat,
    options: entry.options,
    resize: entry.resize,
    jpegQuality: entry.jpegQuality,
  );

  Future<void> savePreset(MediaEntry entry, String name) async {
    final l = library;
    if (l == null || name.trim().isEmpty || l.mediaPresets.length >= 100) {
      return;
    }
    l.mediaPresets.add(
      presetFor(
        entry,
        name.trim().substring(0, name.trim().length.clamp(0, 60)),
      ),
    );
    await l.save();
    message = l.storageError ?? '已保存媒体预设。';
    refresh();
  }

  void _apply(MediaEntry entry, MediaPreset preset) {
    if (!outputs(entry).contains(preset.format)) return;
    if (entry.probe!.kind != MediaKind.image) {
      try {
        ffmpeg!.encodingArguments(
          entry.probe!,
          preset.format,
          options: preset.options,
        );
      } on MediaError {
        message = '该预设与当前媒体流或平台编码器不兼容，已保留原参数。';
        return;
      }
    }
    entry.outputFormat = preset.format;
    entry.options = preset.options;
    entry.resize = preset.resize;
    entry.jpegQuality = preset.jpegQuality;
  }

  void applyPreset(MediaPreset preset) {
    if (busy) return;
    _activePresets[preset.kind] = preset;
    for (final entry in entries.where(
      (e) => !e.finished && e.probe?.kind == preset.kind,
    )) {
      _apply(entry, preset);
    }
    message = '已应用预设：${preset.name}，下一次导入同类媒体也会使用。';
    unawaited(saveRecovery());
    refresh();
  }

  Future<void> saveRecovery() async {
    if (recovery == null || _restoring) return;
    try {
      await recovery!.save([
        ...recoverable,
        for (final entry in entries)
          if (!entry.finished && entry.probe != null)
            {
              'path': entry.file.path,
              'name': entry.file.name,
              'preset': presetFor(entry, '未完成任务').toJson(),
              'output': locationJson(output),
            },
      ]);
    } catch (_) {
      message = '未完成队列暂存失败；请检查磁盘空间。';
    }
  }

  Future<void> restorePending() async {
    if (busy) return;
    final saved = recoverable;
    recoverable = [];
    _restoring = true;
    _restoreCancelled = false;
    refresh();
    for (var index = 0; index < saved.length; index++) {
      if (_restoreCancelled || disposed) {
        recoverable = saved.skip(index).toList();
        break;
      }
      final item = saved[index];
      try {
        final path = item['path'] as String;
        if (!p.isAbsolute(path)) continue;
        await importFiles([
          ImportedFile(path, item['name'] as String),
        ], fromRecovery: true);
        final entry = entries
            .where((e) => p.equals(e.file.path, path))
            .firstOrNull;
        if (entry?.probe != null) {
          _apply(
            entry!,
            MediaPreset.fromJson(
              Map<String, dynamic>.from(item['preset'] as Map),
            ),
          );
        }
        output ??= locationFromJson(item['output']);
      } catch (_) {
        message = '部分未完成任务已不可访问，请重新选择原文件。';
      }
    }
    _restoring = false;
    await saveRecovery();
    refresh();
  }

  Future<void> discardRecovery() async {
    recoverable = [];
    await recovery?.clear();
    refresh();
  }

  static String _mime(String format) => switch (format) {
    'jpg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'tiff' => 'image/tiff',
    'mp4' => 'video/mp4',
    'mkv' => 'video/x-matroska',
    'mov' => 'video/quicktime',
    'webm' => 'video/webm',
    'mp3' => 'audio/mpeg',
    'wav' => 'audio/wav',
    'flac' => 'audio/flac',
    'aac' => 'audio/aac',
    'm4a' => 'audio/mp4',
    'ogg' => 'audio/ogg',
    'opus' => 'audio/ogg',
    _ => 'application/octet-stream',
  };
  @override
  void dispose() {
    disposed = true;
    _token?.cancel();
    if (!isWorking) unawaited(_cleanupPrepared());
    super.dispose();
  }

  Future<void> _cleanupPrepared() async {
    final cleanup = _preparedCleanup.values.toList();
    _preparedCleanup.clear();
    for (final dispose in cleanup) {
      await dispose();
    }
  }
}
