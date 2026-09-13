import 'dart:async';

import '../model/media.dart';

class CancellationToken {
  final Completer<void> _signal = Completer<void>();
  bool get isCancelled => _signal.isCompleted;
  Future<void> get whenCancelled => _signal.future;
  void cancel() {
    if (!isCancelled) _signal.complete();
  }

  void throwIfCancelled() {
    if (isCancelled) {
      throw const MediaError(MediaErrorCode.cancelled, '任务已取消。');
    }
  }
}
