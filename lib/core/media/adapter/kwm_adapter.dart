import 'dart:io';
import 'dart:isolate';

import '../backend/ffmpeg_backend.dart';
import '../jobs/cancellation_token.dart';
import '../model/media.dart';
import '../output/temp_file_manager.dart';
import 'media_adapter.dart';

/// Legacy 0x400-byte KWM wrapper only. Reference and attribution:
/// docs/third_party/Unlock-Music-MIT.txt and docs/CACHE_ADAPTERS.md.
class KwmAdapter implements MediaAdapter {
  KwmAdapter(this.backend, this.workDirectory);
  final FfmpegBackend backend;
  final String workDirectory;
  @override
  String get id => 'kwm-legacy-experimental';

  static bool matches(List<int> header) =>
      header.length >= 16 &&
      (String.fromCharCodes(header.take(16)) == 'yeelion-kuwo-tme' ||
          String.fromCharCodes(header.take(16)) ==
              'yeelion-kuwo\u0000\u0000\u0000\u0000');

  @override
  Future<AdapterMatch?> inspect(String path, CancellationToken token) async {
    token.throwIfCancelled();
    final file = await File(path).open();
    try {
      return matches(await file.read(16)) ? const AdapterMatch(1) : null;
    } finally {
      await file.close();
    }
  }

  @override
  Future<PreparedMedia> prepare(String path, CancellationToken token) async {
    token.throwIfCancelled();
    final temp = await TempFileManager.create(workDirectory, 'bin');
    final control = ReceivePort();
    SendPort? worker;
    final subscription = control.listen((message) {
      worker = message as SendPort;
      if (token.isCancelled) worker!.send(true);
    });
    final remove = token.onCancel(() => worker?.send(true));
    try {
      final destination = temp.file.path;
      final port = control.sendPort;
      await _runKwmIsolate(path, destination, port);
      token.throwIfCancelled();
      final probe = await backend.probe(destination, token);
      if (probe.kind != MediaKind.audio) {
        throw const MediaError(
          MediaErrorCode.unsupportedFormat,
          'KWM 变体未识别为有效音频，未生成输出。',
        );
      }
      return PreparedMedia(destination, cleanup: temp.dispose);
    } catch (_) {
      await temp.dispose();
      rethrow;
    } finally {
      remove();
      await subscription.cancel();
      control.close();
    }
  }
}

// Keep the closure's context separate from subscriptions and completers.
Future<void> _runKwmIsolate(
  String source,
  String destination,
  SendPort parent,
) => Isolate.run(() => _decodeKwm(source, destination, parent));

Future<void> _decodeKwm(
  String source,
  String destination,
  SendPort parent,
) async {
  final control = ReceivePort();
  var cancelled = false;
  control.listen((_) => cancelled = true);
  parent.send(control.sendPort);
  RandomAccessFile? input, output;
  try {
    input = await File(source).open();
    final header = await input.read(1024);
    if (header.length != 1024 || !KwmAdapter.matches(header)) {
      throw const MediaError(
        MediaErrorCode.corruptedMedia,
        'KWM 文件头不完整或版本不受支持。',
      );
    }
    // BigInt retains unsigned 64-bit precision on every Dart platform.
    var key = BigInt.zero;
    for (var i = 31; i >= 24; i--) {
      key = (key << 8) | BigInt.from(header[i]);
    }
    final digits = key.toString();
    const fixedMask = 'MoOtOiTvINGwd2E6n0E1i7L5t2IoOoNk';
    final mask = List.generate(
      32,
      (i) => fixedMask.codeUnitAt(i) ^ digits.codeUnitAt(i % digits.length),
    );
    output = await File(destination).open(mode: FileMode.writeOnly);
    var position = 0;
    while (true) {
      if (cancelled) throw const MediaError(MediaErrorCode.cancelled, '任务已取消。');
      final chunk = await input.read(64 * 1024);
      if (chunk.isEmpty) break;
      for (var i = 0; i < chunk.length; i++) {
        chunk[i] ^= mask[(position + i) % 32];
      }
      await output.writeFrom(chunk);
      position += chunk.length;
    }
    if (position == 0) {
      throw const MediaError(MediaErrorCode.corruptedMedia, 'KWM 音频数据为空。');
    }
  } finally {
    await input?.close();
    await output?.close();
    control.close();
  }
}
