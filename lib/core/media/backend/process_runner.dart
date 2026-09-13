import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../jobs/cancellation_token.dart';
import '../model/media.dart';

class MediaProcessOutput {
  const MediaProcessOutput(this.exitCode, this.stdout, this.stderr);
  final int exitCode;
  final String stdout, stderr;
}

/// Argument vectors only: no shell, no interpolated command strings.
abstract interface class MediaCommandRunner {
  Future<MediaProcessOutput> run(
    String executable,
    List<String> arguments,
    CancellationToken token, {
    void Function(String)? onLine,
    Duration timeout = const Duration(hours: 24),
  });
}

class MediaProcessRunner implements MediaCommandRunner {
  const MediaProcessRunner();
  @override
  Future<MediaProcessOutput> run(
    String executable,
    List<String> arguments,
    CancellationToken token, {
    void Function(String)? onLine,
    Duration timeout = const Duration(hours: 24),
  }) async {
    token.throwIfCancelled();
    final process = await Process.start(
      executable,
      arguments,
      runInShell: false,
    );
    var ended = false;
    Timer? killTimer;
    void stop() {
      if (ended) return;
      try {
        process.stdin.writeln('q');
      } catch (_) {
        /* may already be closed */
      }
      killTimer ??= Timer(const Duration(seconds: 2), () {
        if (!ended) process.kill(ProcessSignal.sigkill);
      });
    }

    final removeCancellation = token.onCancel(stop);
    final out = StringBuffer(), err = StringBuffer();
    final stdoutDone = process.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .listen((line) {
          if (out.length < 4 * 1024 * 1024) out.writeln(line);
          onLine?.call(line);
        })
        .asFuture<void>();
    final stderrDone = process.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen((chunk) {
          if (err.length < 16384) err.write(chunk);
        })
        .asFuture<void>();
    try {
      final code = await process.exitCode.timeout(
        timeout,
        onTimeout: () async {
          process.kill(ProcessSignal.sigkill);
          await process.exitCode;
          throw const MediaError(MediaErrorCode.processFailed, '媒体处理超时。');
        },
      );
      await Future.wait([stdoutDone, stderrDone]);
      token.throwIfCancelled();
      return MediaProcessOutput(code, out.toString(), err.toString());
    } finally {
      ended = true;
      killTimer?.cancel();
      removeCancellation();
      try {
        await process.stdin.close();
      } catch (_) {
        // A process can close stdin while completing or being cancelled.
      }
    }
  }
}
