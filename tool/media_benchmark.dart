import 'dart:convert';
import 'dart:io';

import 'package:imageshift/core/image_engine.dart';
import 'package:imageshift/core/media/backend/vips_image_backend.dart';
import 'package:imageshift/core/media/jobs/cancellation_token.dart';
import 'package:imageshift/core/media/jobs/media_job_engine.dart';
import 'package:imageshift/core/media/model/media.dart';

/// One conversion per process. Fixture generation and full decode validation
/// happen externally so RSS measures this backend's process, not the generator.
Future<void> main(List<String> args) async {
  if (args.length != 4) {
    throw ArgumentError('backend input outputDirectory vipsDirectory');
  }
  final input = File(args[1]).absolute;
  final watch = Stopwatch()..start();
  if (args[0] == 'before') {
    final result = await const ConversionService().convert(
      ConversionTask(
        id: 'bench',
        inputPath: input.path,
        outputDirectory: Directory(args[2]).absolute.path,
        outputFormat: RasterFormat.jpeg,
      ),
    );
    stdout.writeln(
      jsonEncode({
        'backend': 'dart-image',
        'input': input.path,
        'inputBytes': await input.length(),
        'elapsedMs': watch.elapsedMilliseconds,
        'peakRss': ProcessInfo.maxRss,
        'success': result is ConversionSuccess,
        if (result is ConversionSuccess) ...{
          'output': result.outputPath,
          'width': result.width,
          'height': result.height,
          'outputBytes': result.outputBytes,
        },
        if (result is ConversionFailure) 'error': result.error.code.name,
      }),
    );
  } else {
    final result = await MediaJobEngine().run(
      MediaJob(
        id: 'bench',
        inputPath: input.path,
        outputDirectory: Directory(args[2]).absolute.path,
        outputFormat: 'jpg',
      ),
      VipsImageBackend(windowsLibraryDirectory: args[3]),
      CancellationToken(),
    );
    stdout.writeln(
      jsonEncode({
        'backend': 'libvips',
        'input': input.path,
        'inputBytes': await input.length(),
        'elapsedMs': watch.elapsedMilliseconds,
        'peakRss': ProcessInfo.maxRss,
        'success': result.stage == MediaStage.completed,
        'output': result.outputPath,
        'width': result.probe?.width,
        'height': result.probe?.height,
        'outputBytes': result.probe?.bytes,
        'error': result.error?.message,
      }),
    );
  }
}
