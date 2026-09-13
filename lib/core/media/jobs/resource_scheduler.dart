import 'dart:async';
import 'dart:collection';

import 'cancellation_token.dart';

/// Bounded FIFO slots. Heavy work shares a slot across every backend.
/// Capacity is injected by the platform resource policy, not a media size cap.
class ResourceScheduler {
  ResourceScheduler({this.capacity = 1}) {
    if (capacity < 1) throw ArgumentError.value(capacity, 'capacity');
  }
  final int capacity;
  int _active = 0;
  final Queue<Completer<void>> _waiting = Queue();

  Future<T> run<T>(CancellationToken token, Future<T> Function() work) async {
    token.throwIfCancelled();
    if (_active >= capacity) {
      final waiter = Completer<void>();
      _waiting.add(waiter);
      await Future.any([waiter.future, token.whenCancelled]);
      if (token.isCancelled && _waiting.remove(waiter)) {
        token.throwIfCancelled();
      }
      // A completed waiter owns a transferred slot, even if cancelled now.
    } else {
      _active++;
    }
    try {
      token.throwIfCancelled();
      return await work();
    } finally {
      if (_waiting.isNotEmpty) {
        _waiting.removeFirst().complete();
      } else {
        _active--;
      }
    }
  }
}
