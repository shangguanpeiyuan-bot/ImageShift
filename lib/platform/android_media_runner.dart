import 'dart:async';

import 'package:flutter/services.dart';

import '../core/media/backend/process_runner.dart';
import '../core/media/jobs/cancellation_token.dart';
import '../core/media/model/media.dart';

/// JNI sessions run on native workers; Dart only receives logs and timestamps.
class AndroidMediaRunner implements MediaCommandRunner {
  static const channel = MethodChannel(
    'io.github.shangguanpeiyuanbot.imageshift/media',
  );
  static const events = EventChannel(
    'io.github.shangguanpeiyuanbot.imageshift/media-progress',
  );
  static final _stream = events.receiveBroadcastStream().asBroadcastStream();
  static int _nextId = 0;
  static StreamSubscription<dynamic>? _batchEvents;

  static Future<void> beginBatch(CancellationToken token) async {
    await _batchEvents?.cancel();
    _batchEvents = _stream.listen((event) {
      if (event is Map && event['batchCancelled'] == true) token.cancel();
    });
    try {
      await channel.invokeMethod<void>('beginBatch');
    } catch (_) {
      await _batchEvents?.cancel();
      _batchEvents = null;
      rethrow;
    }
  }

  static Future<void> endBatch() async {
    try {
      await channel.invokeMethod<void>('endBatch');
    } finally {
      await _batchEvents?.cancel();
      _batchEvents = null;
    }
  }

  @override
  Future<MediaProcessOutput> run(
    String executable,
    List<String> arguments,
    CancellationToken token, {
    void Function(String)? onLine,
    Duration timeout = const Duration(hours: 24),
  }) async {
    token.throwIfCancelled();
    final id = '${_nextId++}';
    var finished = false;
    final subscription = _stream.listen((event) {
      if (event is Map && event['id'] == id && event['timeUs'] is num) {
        onLine?.call('out_time_us=${(event['timeUs'] as num).toInt()}');
      }
    });
    Future<void> cancel() async {
      if (!finished) await channel.invokeMethod<void>('cancel', {'id': id});
    }

    final removeCancellation = token.onCancel(() {
      unawaited(cancel().catchError((Object _) {}));
    });
    var timedOut = false;
    final timer = Timer(timeout, () {
      timedOut = true;
      unawaited(cancel().catchError((Object _) {}));
    });
    try {
      final response = await channel.invokeMapMethod<String, dynamic>(
        'execute',
        {
          'id': id,
          'program': executable,
          // FFmpegKit uses real Statistics callbacks, not pipe-based CLI progress.
          'arguments': [
            for (var i = 0; i < arguments.length; i++)
              if (arguments[i] == '-progress')
                ...<String>[]
              else if (i == 0 || arguments[i - 1] != '-progress')
                arguments[i],
          ],
        },
      );
      // Wait for the native completion callback before releasing temporary files.
      if (timedOut) {
        throw const MediaError(MediaErrorCode.processFailed, '媒体处理超时，已请求停止。');
      }
      token.throwIfCancelled();
      if (response?['cancelled'] == true) {
        throw const MediaError(MediaErrorCode.cancelled, '任务已取消。');
      }
      return MediaProcessOutput(
        response!['exitCode'] as int,
        response['output'] as String,
        response['diagnostics'] as String? ?? '',
      );
    } on PlatformException {
      throw const MediaError(
        MediaErrorCode.resourceUnavailable,
        'Android 媒体组件不可用或无法启动后台任务。',
      );
    } finally {
      finished = true;
      removeCancellation();
      timer.cancel();
      await subscription.cancel();
    }
  }
}
