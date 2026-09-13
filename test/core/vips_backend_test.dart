import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:imageshift/core/media/backend/vips_image_backend.dart';
import 'package:imageshift/core/media/jobs/cancellation_token.dart';
import 'package:imageshift/core/media/jobs/media_job_engine.dart';
import 'package:imageshift/core/media/model/media.dart';
import 'package:imageshift/core/image_engine.dart';

void main() {
  final directory = Platform.environment['IMAGESHIFT_VIPS_DIR'];
  test(
    'native image conversions preserve alpha, JPEG white background and dimensions',
    () async {
      final sandbox = await Directory.systemTemp.createTemp('vips_native_');
      try {
        final source = File('${sandbox.path}/source.png');
        final pixels = img.Image(width: 40, height: 20, numChannels: 4);
        pixels.setPixelRgba(20, 10, 255, 0, 0, 255);
        await source.writeAsBytes(img.encodePng(pixels));
        final backend = VipsImageBackend(windowsLibraryDirectory: directory);
        final engine = MediaJobEngine();
        for (final format in ['jpg', 'png', 'webp', 'tiff']) {
          final result = await engine.run(
            MediaJob(
              id: format,
              inputPath: source.path,
              outputDirectory: sandbox.path,
              outputFormat: format,
            ),
            backend,
            CancellationToken(),
          );
          expect(result.stage, MediaStage.completed, reason: '${result.error}');
          final bytes = await File(result.outputPath!).readAsBytes();
          expect(bytes, isNotEmpty);
          final decoded = img.decodeImage(bytes)!;
          expect([decoded.width, decoded.height], [40, 20]);
          if (format == 'jpg') {
            expect(decoded.getPixel(0, 0).r, greaterThanOrEqualTo(250));
            expect(decoded.getPixel(0, 0).g, greaterThanOrEqualTo(250));
            expect(decoded.getPixel(0, 0).b, greaterThanOrEqualTo(250));
          } else {
            expect(decoded.getPixel(0, 0).a, 0);
          }
        }
        final resized = await engine.run(
          MediaJob(
            id: 'resize',
            inputPath: source.path,
            outputDirectory: sandbox.path,
            outputFormat: 'png',
            imageTask: ConversionTask(
              id: 'resize',
              inputPath: source.path,
              outputDirectory: sandbox.path,
              outputFormat: RasterFormat.png,
              resize: const ResizeOptions(width: 10, height: 10),
            ),
          ),
          backend,
          CancellationToken(),
        );
        expect(resized.stage, MediaStage.completed, reason: '${resized.error}');
        expect([resized.probe!.width, resized.probe!.height], [10, 5]);
        expect(await source.readAsBytes(), img.encodePng(pixels));
      } finally {
        await sandbox.delete(recursive: true);
      }
    },
    skip: directory == null
        ? 'Requires verified native bundle IMAGESHIFT_VIPS_DIR'
        : false,
  );
}
