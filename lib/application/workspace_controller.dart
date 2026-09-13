import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../core/image_engine.dart';
import '../core/services/image_inspector.dart';
import '../core/services/image_worker.dart';
import '../platform/file_access.dart';
import 'editor_settings.dart';
import 'editor_serialization.dart';
import 'local_library.dart';

class ImageAsset {
  ImageAsset({required this.id, required this.file});
  final String id;
  final ImportedFile file;
  ImageInspection? info;
  String? error;
  bool selected = true;
  TaskStatus status = TaskStatus.pending;
  ConversionSuccess? output;
  String? publishedPath;
}

enum FileSort { name, size, resolution, format }

class WorkspaceController extends ChangeNotifier {
  WorkspaceController({
    FileAccess? files,
    ConversionService? service,
    this.library,
  }) : files = files ?? FileAccess(),
       service = service ?? const ConversionService() {
    queue = TaskQueue(runner: _runTask, onChanged: _queueChanged);
    if (library != null) {
      settings.apply(library!.defaults);
      outputLocation = library!.output;
    }
  }
  final FileAccess files;
  final ConversionService service;
  final LocalLibrary? library;
  final inspector = const ImageInspector();
  late final TaskQueue queue;
  final settings = EditorSettings();
  final List<ImageAsset> assets = [];
  OutputLocation? outputLocation;
  ImageAsset? focused;
  ImageInspection? preview;
  String? previewError, message;
  bool importing = false, picking = false, previewLoading = false;
  bool _disposed = false;
  int _nextId = 0, _previewGeneration = 0;
  Timer? _debounce;
  Timer? _saveDebounce;
  String search = '';
  RasterFormat? filterFormat;
  TaskStatus? filterStatus;
  FileSort sort = FileSort.name;
  bool ascending = true;
  int page = 0;
  bool preparing = false;
  bool Function()? externalBusy;
  bool get isWorking => importing || picking || preparing || queue.isRunning;
  bool get busy => isWorking || (externalBusy?.call() ?? false);
  int get selectedCount =>
      assets.where((a) => a.selected && a.info != null).length;
  List<ImageAsset> get visibleAssets {
    final list = assets
        .where(
          (a) =>
              a.file.name.toLowerCase().contains(search.toLowerCase()) &&
              (filterFormat == null || a.info?.format == filterFormat) &&
              (filterStatus == null || a.status == filterStatus),
        )
        .toList();
    list.sort((a, b) {
      final comparison = switch (sort) {
        FileSort.name => a.file.name.toLowerCase().compareTo(
          b.file.name.toLowerCase(),
        ),
        FileSort.size => (a.info?.bytes ?? 0).compareTo(b.info?.bytes ?? 0),
        FileSort.resolution =>
          ((a.info?.width ?? 0) * (a.info?.height ?? 0)).compareTo(
            (b.info?.width ?? 0) * (b.info?.height ?? 0),
          ),
        FileSort.format => (a.info?.format.label ?? '').compareTo(
          b.info?.format.label ?? '',
        ),
      };
      return ascending ? comparison : -comparison;
    });
    return list;
  }

  void refresh() {
    if (!_disposed) notifyListeners();
  }

  void navigate(int value) {
    page = value;
    refresh();
  }

  void clearMessage() {
    message = null;
    refresh();
  }

  Future<void> pickImages() async {
    if (busy) return;
    picking = true;
    refresh();
    List<ImportedFile> picked = [];
    try {
      picked = await files.pickImages();
    } catch (_) {
      message = '无法打开或读取所选文件，请重新选择。';
    } finally {
      picking = false;
      refresh();
    }
    if (!_disposed) await importFiles(picked);
  }

  Future<void> importFiles(List<ImportedFile> inputs) async {
    if (busy || inputs.isEmpty || _disposed) return;
    importing = true;
    page = 1;
    refresh();
    var failed = 0;
    try {
      for (final file in inputs) {
        if (_disposed) break;
        if (assets.length >= 500) {
          message = '本批最多保留 500 项，请处理后清空再导入。';
          break;
        }
        if (file.path.isNotEmpty &&
            assets.any((a) => p.equals(a.file.path, file.path))) {
          continue;
        }
        final asset = ImageAsset(id: 'image-${_nextId++}', file: file);
        assets.add(asset);
        refresh();
        try {
          if (file.error != null) {
            throw ConversionError(ConversionErrorCode.readFailed, file.error!);
          }
          asset.info = await inspector.inspect(file.path);
          focused ??= asset;
        } catch (error) {
          asset.error = error is ConversionError ? error.message : '无法识别此图片。';
          asset.status = TaskStatus.failed;
          asset.selected = false;
          failed++;
        }
        refresh();
      }
      if (failed > 0) message = '$failed 个文件无法导入，详情已保留在列表；其他图片可以继续处理。';
    } finally {
      importing = false;
      refresh();
      requestPreview();
    }
  }

  void focus(ImageAsset asset) {
    focused = asset;
    preview = null;
    refresh();
    requestPreview();
  }

  void toggle(ImageAsset asset, bool selected) {
    if (busy) return;
    asset.selected = selected && asset.info != null;
    refresh();
  }

  void selectAll(bool selected) {
    if (busy) return;
    for (final a in assets) {
      a.selected = selected && a.info != null;
    }
    refresh();
  }

  void removeSelected() {
    if (busy) return;
    _releaseAssets(assets.where((a) => a.selected).toList());
    assets.removeWhere((a) => a.selected);
    if (!assets.contains(focused)) {
      focused = assets.where((a) => a.info != null).firstOrNull;
    }
    preview = null;
    refresh();
    requestPreview();
  }

  void clear() {
    if (busy) return;
    _releaseAssets(assets.toList());
    assets.clear();
    focused = null;
    preview = null;
    _previewGeneration++;
    refresh();
  }

  void _releaseAssets(List<ImageAsset> removed) {
    final paths = removed
        .expand(
          (a) => [a.file.path, if (a.output != null) a.output!.outputPath],
        )
        .where((path) => path.isNotEmpty)
        .toList();
    // Let any already-running preview finish reading its private copy first.
    unawaited(
      ImageWorker.run(() => files.releaseCache(paths)).catchError((_) {
        message = '部分临时缓存未能清理，可在系统应用设置中清理缓存。';
        refresh();
      }),
    );
  }

  void edit(void Function(EditorSettings) action) {
    if (busy) return;
    action(settings);
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 400), rememberSettings);
    refresh();
    requestPreview();
  }

  void applyParameters(Map<String, dynamic> parameters) {
    edit((s) => s.apply(editorFromJson(parameters)));
    if (!busy) navigate(1);
  }

  Future<void> rememberSettings() async {
    final l = library;
    if (l == null) return;
    if (l.rememberParameters) l.defaults = editorFromJson(settings.toJson());
    l.output = outputLocation;
    await l.save();
  }

  void requestPreview() {
    _previewGeneration++;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), _renderPreview);
  }

  Future<void> _renderPreview() async {
    if (_disposed || focused?.info == null || queue.isRunning || importing) {
      return;
    }
    // Serialize previews too. A newer request replaces an obsolete one.
    if (previewLoading) {
      _debounce = Timer(const Duration(milliseconds: 200), _renderPreview);
      return;
    }
    final generation = _previewGeneration;
    final asset = focused!;
    previewLoading = true;
    previewError = null;
    refresh();
    try {
      final info = asset.info!;
      final result = await inspector.inspect(
        asset.file.path,
        previewSize: 1024,
        resize: settings.resizeFor(info.width, info.height),
        edits: settings.edits,
      );
      if (generation == _previewGeneration) preview = result;
    } catch (error) {
      if (generation == _previewGeneration) {
        preview = null;
        previewError = error is ConversionError
            ? error.message
            : '预览失败，请检查图片与参数。';
      }
    } finally {
      previewLoading = false;
      refresh();
    }
  }

  Future<void> chooseOutput() async {
    if (busy) return;
    picking = true;
    refresh();
    try {
      outputLocation = await files.pickOutput() ?? outputLocation;
      await rememberSettings();
    } catch (_) {
      message = '未能取得可写目录，请重新选择。';
    } finally {
      picking = false;
      refresh();
    }
  }

  String proposedName(ImageAsset asset, int index) {
    final format = settings.keepFormat
        ? asset.info?.format ?? settings.format
        : settings.format;
    final stem = settings.renameEnabled
        ? settings.rename.stem(asset.file.name, index)
        : p.basenameWithoutExtension(asset.file.name);
    return '${OutputNamer.sanitizeStem(stem)}.${format.extension}';
  }

  Future<void> start({bool retryFailed = false}) async {
    if (busy) return;
    final selected = assets
        .where(
          (a) =>
              a.info != null &&
              (retryFailed ? a.status == TaskStatus.failed : a.selected),
        )
        .toList();
    if (selected.isEmpty) {
      message = '请先选择可处理的图片。';
      refresh();
      return;
    }
    if (outputLocation == null) await chooseOutput();
    if (outputLocation == null || _disposed) return;
    if (preparing || queue.isRunning) return;
    preparing = true;
    refresh();
    try {
      try {
        await files.validateOutput(outputLocation!);
      } catch (_) {
        outputLocation = null;
        if (library != null) {
          library!.output = null;
          await library!.save();
        }
        message = '输出目录已失效，请重新选择并授权目录后重试。';
        return;
      }
      final directory = await files.workDirectory(outputLocation!);
      final tasks = <ConversionTask>[];
      for (var i = 0; i < selected.length; i++) {
        final a = selected[i];
        final info = a.info!;
        tasks.add(
          ConversionTask(
            id: a.id,
            inputPath: a.file.path,
            outputDirectory: directory,
            outputFormat: settings.keepFormat ? info.format : settings.format,
            jpegQuality: settings.quality,
            resize: settings.resizeFor(info.width, info.height),
            edits: settings.edits,
            outputStem: settings.renameEnabled
                ? settings.rename.stem(a.file.name, i)
                : p.basenameWithoutExtension(a.file.name),
          ),
        );
      }
      _debounce?.cancel();
      _previewGeneration++;
      page = 3;
      await queue.start(tasks);
      await rememberSettings();
      final l = library;
      if (l != null) {
        await l.record(
          HistoryEntry(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            time: DateTime.now(),
            total: queue.entries.length,
            succeeded: queue.count(TaskStatus.succeeded),
            failed: queue.count(TaskStatus.failed),
            cancelled: queue.count(TaskStatus.cancelled),
            inputBytes: queue.inputBytes,
            outputBytes: queue.outputBytes,
            parameters: settings.toJson(),
            output: outputLocation,
          ),
        );
        if (l.completionNotice) {
          message =
              '处理结束：${queue.count(TaskStatus.succeeded)} 成功，${queue.count(TaskStatus.failed)} 失败，${queue.count(TaskStatus.cancelled)} 取消。';
        }
        if (l.autoOpen && queue.count(TaskStatus.succeeded) > 0) {
          await openOutput();
        }
      }
    } catch (error) {
      message = error is ConversionError ? error.message : '无法启动处理，请检查输出目录和参数。';
      refresh();
    } finally {
      preparing = false;
      refresh();
    }
  }

  Future<ConversionResult> _runTask(ConversionTask task) async {
    final result = await service.convert(task);
    if (result is ConversionSuccess) {
      try {
        final published = await files.publish(result, outputLocation!);
        final asset = assets.firstWhere((a) => a.id == task.id);
        final oldOutput = asset.output;
        asset.output = result;
        asset.publishedPath = published;
        if (oldOutput != null) {
          try {
            await files.releaseCache([oldOutput.outputPath]);
          } catch (_) {}
        }
      } catch (error) {
        try {
          await files.releaseCache([result.outputPath]);
        } catch (_) {}
        return ConversionFailure(
          taskId: task.id,
          error: ConversionError(
            ConversionErrorCode.writeFailed,
            error is PlatformException && error.message != null
                ? error.message!
                : '保存失败，请重新授权输出目录后重试。',
          ),
        );
      }
    }
    return result;
  }

  void _queueChanged() {
    for (final entry in queue.entries) {
      final a = assets.where((a) => a.id == entry.task.id).firstOrNull;
      if (a == null) continue;
      a.status = entry.status;
      a.error = entry.result is ConversionFailure
          ? (entry.result as ConversionFailure).error.message
          : null;
    }
    refresh();
  }

  Future<void> openOutput() async {
    if (outputLocation == null) return;
    try {
      await files.openOutput(outputLocation!);
    } catch (_) {
      message = '无法打开文件管理器。请在系统文件管理器中查看所选目录。';
      refresh();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    queue.cancel();
    _saveDebounce?.cancel();
    if (library != null) unawaited(rememberSettings());
    queue.onChanged = null;
    super.dispose();
  }
}
