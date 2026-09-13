import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:imageshift/core/image_engine.dart';

Future<void> main() async {
  final root = Directory(
    'artifacts/phase-c/perf-${DateTime.now().millisecondsSinceEpoch}',
  )..createSync(recursive: true);
  final out = Directory('${root.path}/out')..createSync();
  final results = <Map<String, dynamic>>[];
  for (final spec in [
    ('4K', 3840, 2160),
    ('phone12MP', 4000, 3000),
    ('24MP', 6000, 4000),
    ('8K-rejected', 7680, 4320),
    ('TIFF', 4000, 3000),
  ]) {
    final pixels = img.Image(width: spec.$2, height: spec.$3);
    for (final pixel in pixels) {
      pixel.r = pixel.x % 256;
      pixel.g = pixel.y % 256;
      pixel.b = (pixel.x + pixel.y) % 256;
    }
    final source = File(
      '${root.path}/${spec.$1}.${spec.$1 == 'TIFF' ? 'tif' : 'png'}',
    );
    source.writeAsBytesSync(
      spec.$1 == 'TIFF' ? img.encodeTiff(pixels) : img.encodePng(pixels),
    );
    final clock = Stopwatch()..start();
    final result = await const ConversionService().convert(
      ConversionTask(
        id: spec.$1,
        inputPath: source.path,
        outputDirectory: out.path,
        outputFormat: RasterFormat.jpeg,
      ),
    );
    clock.stop();
    if (spec.$1 == '8K-rejected') {
      if (result is! ConversionFailure ||
          result.error.code != ConversionErrorCode.resourceLimit) {
        throw StateError('8K must respect pixel limit');
      }
    } else {
      if (result is! ConversionSuccess) {
        throw StateError('Conversion failed: ${spec.$1}');
      }
      final decoded = const ImageDecoder().decode(
        File(result.outputPath).readAsBytesSync(),
      );
      if (decoded.pixels.width != spec.$2 ||
          decoded.pixels.height != spec.$3 ||
          decoded.format != RasterFormat.jpeg) {
        throw StateError('Output verification failed');
      }
    }
    results.add({
      'case': spec.$1,
      'width': spec.$2,
      'height': spec.$3,
      'inputBytes': source.lengthSync(),
      'elapsedMs': clock.elapsedMilliseconds,
      'status': result.status.name,
      'rssAfterVerification': ProcessInfo.currentRss,
      'processPeakRss': ProcessInfo.maxRss,
    });
    stdout.writeln(jsonEncode(results.last));
  }
  final small = File('${root.path}/batch.png')
    ..writeAsBytesSync(img.encodePng(img.Image(width: 256, height: 256)));
  final clock = Stopwatch()..start();
  final queue = TaskQueue(runner: const ConversionService().convert);
  await queue.start(
    List.generate(
      100,
      (i) => ConversionTask(
        id: 'batch-$i',
        inputPath: small.path,
        outputDirectory: out.path,
        outputFormat: RasterFormat.jpeg,
      ),
    ),
  );
  clock.stop();
  if (queue.count(TaskStatus.succeeded) != 100) {
    throw StateError('Batch failure');
  }
  for (final e in queue.entries) {
    final r = e.result as ConversionSuccess;
    final d = const ImageDecoder().decode(File(r.outputPath).readAsBytesSync());
    if (d.pixels.width != 256) throw StateError('Batch dimensions');
  }
  results.add({
    'case': 'batch100',
    'elapsedMs': clock.elapsedMilliseconds,
    'succeeded': 100,
    'uniqueOutputs': queue.entries
        .map((e) => (e.result as ConversionSuccess).outputPath)
        .toSet()
        .length,
    'processPeakRss': ProcessInfo.maxRss,
  });
  File('artifacts/phase-c/performance.json')
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(results));
  stdout.writeln(jsonEncode(results.last));
}
