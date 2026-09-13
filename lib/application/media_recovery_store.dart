import 'dart:io';

import 'local_library.dart';

/// Short-lived pending queue, separate from permanent summary-only history.
class MediaRecoveryStore {
  MediaRecoveryStore(Directory applicationDirectory)
    : store = LibraryStore(
        Directory('${applicationDirectory.path}/media-recovery'),
      );
  final LibraryStore store;
  Future<void> _pending = Future.value();
  Future<void> _serial(Future<void> Function() action) {
    final next = _pending.then((_) => action());
    _pending = next.catchError((_) {});
    return next;
  }

  Future<List<Map<String, dynamic>>> read() async {
    await _pending;
    final data = await store.read();
    final time = DateTime.tryParse('${data['savedAt']}');
    if (time == null ||
        DateTime.now().difference(time) > const Duration(hours: 24)) {
      await clear();
      return [];
    }
    return (data['queue'] is List ? data['queue'] as List : [])
        .take(500)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> save(List<Map<String, dynamic>> queue) => _serial(() async {
    if (queue.isEmpty) {
      await _clear();
      return;
    }
    await store.write({
      'schema': 1,
      'savedAt': DateTime.now().toIso8601String(),
      'queue': queue.take(500).toList(),
    });
  });
  Future<void> clear() => _serial(_clear);
  Future<void> _clear() async {
    // Deletes only our three metadata files, never inputs, outputs or directories.
    for (final name in [
      'library.json',
      'library.previous.json',
      'library.pending.json',
    ]) {
      final file = File('${store.directory.path}/$name');
      if (await file.exists()) await file.delete();
    }
  }
}
