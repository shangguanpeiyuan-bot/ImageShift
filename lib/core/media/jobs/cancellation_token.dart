import 'dart:async';

import '../model/media.dart';

class CancellationToken {
  final Completer<void> _signal = Completer<void>();
  final _listeners = <void Function()>{};
  bool get isCancelled => _signal.isCompleted;
  Future<void> get whenCancelled => _signal.future;
  void cancel() {
    if (isCancelled) return;
    _signal.complete();
    final listeners = _listeners.toList();
    _listeners.clear();
    for (final listener in listeners) {
      listener();
    }
  }

  /// Remove subscriptions after a job ends; batch tokens outlive individual jobs.
  void Function() onCancel(void Function() listener) {
    if (isCancelled) {
      listener();
      return () {};
    }
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }

  void throwIfCancelled() {
    if (isCancelled) {
      throw const MediaError(MediaErrorCode.cancelled, '任务已取消。');
    }
  }
}
