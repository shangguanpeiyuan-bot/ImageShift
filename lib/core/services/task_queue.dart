import '../models/conversion_error.dart';
import '../models/conversion_task.dart';

typedef TaskRunner = Future<ConversionResult> Function(ConversionTask task);

class QueueEntry {
  QueueEntry(this.task);
  final ConversionTask task;
  TaskStatus status = TaskStatus.pending;
  ConversionResult? result;
}

/// One worker at a time. Cancellation affects pending work; a running codec
/// finishes and safely publishes its new file. No partial success is invented.
class TaskQueue {
  TaskQueue({required this.runner, this.onChanged});
  final TaskRunner runner;
  void Function()? onChanged;
  final List<QueueEntry> _entries = [];
  List<QueueEntry> get entries => List.unmodifiable(_entries);
  bool isRunning = false;
  bool cancellationRequested = false;
  final Stopwatch _clock = Stopwatch();
  Duration get elapsed => _clock.elapsed;
  int count(TaskStatus status) =>
      _entries.where((e) => e.status == status).length;
  int get completed => _entries.where((e) => e.result != null).length;
  int get inputBytes => _entries
      .map((e) => e.result)
      .whereType<ConversionSuccess>()
      .fold(0, (n, r) => n + r.inputBytes);
  int get outputBytes => _entries
      .map((e) => e.result)
      .whereType<ConversionSuccess>()
      .fold(0, (n, r) => n + r.outputBytes);

  Future<void> start(List<ConversionTask> tasks) async {
    if (isRunning) throw StateError('A queue is already running');
    if (tasks.map((t) => t.id).toSet().length != tasks.length) {
      throw ArgumentError('Task IDs must be unique');
    }
    _entries
      ..clear()
      ..addAll(tasks.map(QueueEntry.new));
    cancellationRequested = false;
    isRunning = true;
    _clock
      ..reset()
      ..start();
    onChanged?.call();
    try {
      for (final entry in _entries) {
        if (entry.status == TaskStatus.cancelled) continue;
        entry.status = TaskStatus.processing;
        onChanged?.call();
        try {
          entry.result = await runner(entry.task);
        } catch (error) {
          entry.result = ConversionFailure(
            taskId: entry.task.id,
            error: ConversionError(
              ConversionErrorCode.unexpected,
              '此文件处理失败，可单独重试。',
              detail: error.toString(),
            ),
          );
        }
        entry.status = entry.result!.status;
        onChanged?.call();
      }
    } finally {
      isRunning = false;
      _clock.stop();
      onChanged?.call();
    }
  }

  void cancel() {
    if (!isRunning) return;
    cancellationRequested = true;
    for (final entry in _entries.where((e) => e.status == TaskStatus.pending)) {
      entry.result = ConversionCancelled(entry.task.id);
      entry.status = TaskStatus.cancelled;
    }
    onChanged?.call();
  }
}
