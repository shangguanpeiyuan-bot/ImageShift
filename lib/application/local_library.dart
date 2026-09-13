import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../core/image_engine.dart';
import '../platform/file_access.dart';
import 'editor_settings.dart';
import 'editor_serialization.dart';
import 'media_library.dart';

/// Two generations survive interrupted writes; no images or input paths here.
class LibraryStore {
  LibraryStore(this.directory);
  final Directory directory;
  Future<void> _pending = Future.value();
  Future<Map<String, dynamic>> read() async {
    for (final name in ['library.json', 'library.previous.json']) {
      final f = File('${directory.path}/$name');
      if (!await f.exists()) continue;
      try {
        if (await f.length() > 4 * 1024 * 1024) continue;
        final data = jsonDecode(await f.readAsString());
        if (data is Map<String, dynamic> && data['schema'] == 1) return data;
      } catch (_) {
        /* Try the last complete generation. */
      }
    }
    return {};
  }

  Future<void> write(Map<String, dynamic> value) {
    final encoded = jsonEncode(value);
    final next = _pending.then((_) async {
      await directory.create(recursive: true);
      final current = File('${directory.path}/library.json');
      final backup = File('${directory.path}/library.previous.json');
      final temp = File('${directory.path}/library.pending.json');
      await temp.writeAsString(encoded, flush: true);
      if (await current.exists()) {
        // Keep only a parseable previous generation; a broken current file
        // must never destroy the last usable backup.
        try {
          final old = jsonDecode(await current.readAsString());
          if (old is Map && old['schema'] == 1) {
            if (await backup.exists()) await backup.delete();
            await current.rename(backup.path);
          } else {
            await current.delete();
          }
        } on FormatException {
          await current.delete();
        }
      }
      await temp.rename(current.path);
    });
    _pending = next.catchError((_) {});
    return next;
  }
}

class SavedPreset {
  SavedPreset(this.id, this.name, this.parameters, {this.builtIn = false});
  final String id;
  String name;
  final Map<String, dynamic> parameters;
  final bool builtIn;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'parameters': parameters,
  };
}

class HistoryEntry {
  HistoryEntry({
    required this.id,
    required this.time,
    required this.total,
    required this.succeeded,
    required this.failed,
    required this.cancelled,
    required this.inputBytes,
    required this.outputBytes,
    required this.parameters,
    this.output,
  });
  final String id;
  final DateTime time;
  final int total, succeeded, failed, cancelled, inputBytes, outputBytes;
  final Map<String, dynamic> parameters;
  final OutputLocation? output;
  Map<String, dynamic> toJson() => {
    'id': id,
    'time': time.toIso8601String(),
    'total': total,
    'succeeded': succeeded,
    'failed': failed,
    'cancelled': cancelled,
    'inputBytes': inputBytes,
    'outputBytes': outputBytes,
    'parameters': parameters,
    'output': locationJson(output),
  };
}

Map<String, dynamic>? locationJson(OutputLocation? o) =>
    o == null ? null : {'id': o.id, 'label': o.label, 'tree': o.isDocumentTree};
OutputLocation? locationFromJson(dynamic data) {
  if (data is! Map || data['id'] is! String || data['label'] is! String) {
    return null;
  }
  return OutputLocation(
    data['id'] as String,
    data['label'] as String,
    isDocumentTree: data['tree'] == true,
  );
}

class LocalLibrary extends ChangeNotifier {
  LocalLibrary({this.store});
  final LibraryStore? store;
  ThemeMode theme = ThemeMode.system;
  bool welcomed = false,
      rememberParameters = true,
      autoOpen = false,
      completionNotice = true;
  bool recordHistory = true;
  EditorSettings defaults = EditorSettings();
  OutputLocation? output;
  final List<SavedPreset> presets = [];
  final List<HistoryEntry> history = [];
  final List<MediaPreset> mediaPresets = [];
  final List<MediaHistoryRecord> mediaHistory = [];
  String? storageError;
  bool _disposed = false;
  static List<SavedPreset> get builtIns {
    SavedPreset preset(
      String id,
      String name,
      void Function(EditorSettings) edit,
    ) {
      final s = EditorSettings();
      edit(s);
      return SavedPreset(id, name, s.toJson(), builtIn: true);
    }

    return [
      preset('web', '网页优化 JPG', (s) {
        s.quality = 80;
        s.resizeEnabled = true;
        s.width = 1920;
        s.height = 1920;
        s.stripMetadata = true;
      }),
      preset('jpg', '高清 JPG', (s) => s.quality = 95),
      preset('webp', '无损 WebP', (s) => s.format = RasterFormat.webp),
      preset('1080', '1080p 边界框', (s) {
        s.resizeEnabled = true;
        s.width = 1920;
        s.height = 1080;
      }),
      preset('4k', '4K 边界框', (s) {
        s.resizeEnabled = true;
        s.width = 3840;
        s.height = 2160;
      }),
    ];
  }

  Future<void> load() async {
    try {
      final m = await store?.read() ?? <String, dynamic>{};
      theme =
          ThemeMode.values.where((t) => t.name == m['theme']).firstOrNull ??
          ThemeMode.system;
      welcomed = m['welcomed'] == true;
      rememberParameters = m['rememberParameters'] != false;
      autoOpen = m['autoOpen'] == true;
      completionNotice = m['completionNotice'] != false;
      recordHistory = m['recordHistory'] != false;
      if (m['defaults'] is Map) {
        defaults = editorFromJson(
          Map<String, dynamic>.from(m['defaults'] as Map),
        );
      }
      output = locationFromJson(m['output']);
      for (final value
          in (m['mediaPresets'] is List ? m['mediaPresets'] as List : []).take(
            100,
          )) {
        try {
          mediaPresets.add(
            MediaPreset.fromJson(Map<String, dynamic>.from(value as Map)),
          );
        } catch (_) {
          /* One invalid preset cannot break existing image settings. */
        }
      }
      for (final value
          in (m['mediaHistory'] is List ? m['mediaHistory'] as List : []).take(
            200,
          )) {
        try {
          mediaHistory.add(
            MediaHistoryRecord.fromJson(
              Map<String, dynamic>.from(value as Map),
            ),
          );
        } catch (_) {
          /* Ignore only this invalid summary. */
        }
      }
      for (final value
          in (m['presets'] is List ? m['presets'] as List : []).take(100)) {
        if (value is Map &&
            value['id'] is String &&
            value['name'] is String &&
            value['parameters'] is Map) {
          presets.add(
            SavedPreset(
              value['id'],
              value['name'],
              editorFromJson(Map<String, dynamic>.from(value['parameters']))
                  .toJson(),
            ),
          );
        }
      }
      for (final value
          in (m['history'] is List ? m['history'] as List : []).take(200)) {
        try {
          final v = Map<String, dynamic>.from(value as Map);
          int number(String k) => (v[k] as int).clamp(0, 1 << 52);
          history.add(
            HistoryEntry(
              id: v['id'] as String,
              time: DateTime.parse(v['time'] as String),
              total: number('total'),
              succeeded: number('succeeded'),
              failed: number('failed'),
              cancelled: number('cancelled'),
              inputBytes: number('inputBytes'),
              outputBytes: number('outputBytes'),
              parameters: editorFromJson(
                Map<String, dynamic>.from(v['parameters'] as Map),
              ).toJson(),
              output: locationFromJson(v['output']),
            ),
          );
        } catch (_) {
          /* An invalid record cannot block the library. */
        }
      }
    } catch (_) {
      storageError = '无法读取本地设置，本次使用默认值。';
    }
  }

  Future<void> save() async {
    if (!_disposed) notifyListeners();
    try {
      await store?.write({
        'schema': 1,
        'theme': theme.name,
        'welcomed': welcomed,
        'rememberParameters': rememberParameters,
        'autoOpen': autoOpen,
        'completionNotice': completionNotice,
        'recordHistory': recordHistory,
        'defaults': defaults.toJson(),
        'output': locationJson(output),
        'presets': presets.map((p) => p.toJson()).toList(),
        'history': history.map((h) => h.toJson()).toList(),
        'mediaPresets': mediaPresets.map((p) => p.toJson()).toList(),
        'mediaHistory': mediaHistory.map((h) => h.toJson()).toList(),
      });
      storageError = null;
    } catch (_) {
      storageError = '本地设置保存失败，请检查磁盘空间和权限。';
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> addPreset(String name, EditorSettings settings) async {
    if (name.trim().isEmpty || presets.length >= 100) return;
    presets.add(
      SavedPreset(
        DateTime.now().microsecondsSinceEpoch.toString(),
        name.trim().substring(0, name.trim().length.clamp(0, 60)),
        settings.toJson(),
      ),
    );
    await save();
  }

  Future<void> record(HistoryEntry entry) async {
    if (!recordHistory) return;
    history.insert(0, entry);
    if (history.length > 200) history.removeRange(200, history.length);
    await save();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
