import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:imageshift/core/image_engine.dart';
import 'package:path/path.dart' as p;

import '../support/image_fixtures.dart';

void main() {
  late Directory sandbox;
  late Directory output;
  const service = ConversionService();

  setUp(() {
    sandbox = Directory.systemTemp.createTempSync('imageshift_test_');
    output = Directory(p.join(sandbox.path, 'output'))..createSync();
  });
  tearDown(() => sandbox.deleteSync(recursive: true));

  File input(String name, List<int> bytes) =>
      File(p.join(sandbox.path, name))..writeAsBytesSync(bytes);

  ConversionTask task(
    File source, {
    RasterFormat format = RasterFormat.png,
    ResizeOptions? resize,
    int quality = 90,
    String? directory,
  }) => ConversionTask(
    id: 'test-conversion',
    inputPath: source.path,
    outputDirectory: directory ?? output.path,
    outputFormat: format,
    resize: resize,
    jpegQuality: quality,
  );

  /// Real file, independent header/decoder check, dimensions, bytes and status.
  img.Image verifyOutput(
    ConversionResult result,
    RasterFormat format,
    int width,
    int height,
  ) {
    expect(result, isA<ConversionSuccess>(), reason: describeResult(result));
    final success = result as ConversionSuccess;
    expect(success.status, TaskStatus.succeeded);
    expect(success.taskId, 'test-conversion');
    final file = File(success.outputPath);
    expect(file.existsSync(), isTrue);
    final bytes = file.readAsBytesSync();
    expect(bytes.length, greaterThan(0));
    expect(success.outputBytes, bytes.length);
    expect(success.inputBytes, greaterThan(0));
    expect(p.extension(file.path), '.${format.extension}');
    final expected = switch (format) {
      RasterFormat.jpeg => img.ImageFormat.jpg,
      RasterFormat.png => img.ImageFormat.png,
      RasterFormat.webp => img.ImageFormat.webp,
      _ => throw StateError('Unexpected test output format'),
    };
    expect(img.findFormatForData(bytes), expected);
    final decoded = img.decodeImage(bytes);
    expect(decoded, isNotNull);
    expect((decoded!.width, decoded.height), (width, height));
    expect((success.width, success.height), (width, height));
    expect(success.outputFormat, format);
    return decoded;
  }

  void verifyFailure(ConversionResult result, ConversionErrorCode code) {
    expect(result, isA<ConversionFailure>(), reason: describeResult(result));
    final failure = result as ConversionFailure;
    expect(failure.status, TaskStatus.failed);
    expect(failure.error.code, code, reason: failure.error.detail);
    expect(failure.error.message, isNotEmpty);
    expect(output.listSync(), isEmpty);
  }

  for (final format in RasterFormat.values) {
    test(
      '${format.label} content → PNG with no usable filename extension',
      () async {
        final bytes = fixtureBytes(format);
        final source = input('照片-$format.bin', bytes);
        final result = await service.convert(task(source));
        verifyOutput(result, RasterFormat.png, 32, 24);
        expect((result as ConversionSuccess).inputFormat, format);
        expect(source.readAsBytesSync(), bytes);
        if (format == RasterFormat.tga) {
          final rgba = alphaFixture();
          final rgbaSource = input('rgba-tga.bin', img.encodeTga(rgba));
          final rgbaResult = await service.convert(task(rgbaSource));
          final decoded = verifyOutput(rgbaResult, RasterFormat.png, 48, 24);
          expect(decoded.getPixel(8, 12).a, 0);
          expect(decoded.getPixel(24, 12).a, 128);
          expect(decoded.getPixel(40, 12).r, 255);
        }
      },
    );
  }

  test('PNG → JPG with real PNG content named .jpg', () async {
    final source = input('photo.jpg', fixtureBytes(RasterFormat.png));
    final result = await service.convert(
      task(source, format: RasterFormat.jpeg),
    );
    verifyOutput(result, RasterFormat.jpeg, 32, 24);
    expect((result as ConversionSuccess).inputFormat, RasterFormat.png);
  });

  test(
    'transparent PNG → JPG white background and correct half alpha',
    () async {
      final source = input('alpha.png', img.encodePng(alphaFixture()));
      final result = await service.convert(
        task(source, format: RasterFormat.jpeg, quality: 100),
      );
      final decoded = verifyOutput(result, RasterFormat.jpeg, 48, 24);
      final transparent = decoded.getPixel(8, 12);
      expect(transparent.r, closeTo(255, 3));
      expect(transparent.g, closeTo(255, 3));
      expect(transparent.b, closeTo(255, 3));
      final half = decoded.getPixel(24, 12);
      expect(half.r, closeTo(255, 3));
      expect(half.g, closeTo(127, 4));
      expect(half.b, closeTo(127, 4));
      final opaque = decoded.getPixel(40, 12);
      expect(opaque.r, closeTo(255, 3));
      expect(opaque.g, closeTo(0, 3));
      expect(opaque.b, closeTo(0, 3));
    },
  );

  test('PNG → PNG preserves alpha', () async {
    final source = input('alpha.png', img.encodePng(alphaFixture()));
    final decoded = verifyOutput(
      await service.convert(task(source)),
      RasterFormat.png,
      48,
      24,
    );
    expect(decoded.getPixel(8, 12).a, 0);
    expect(decoded.getPixel(24, 12).a, 128);
    expect(decoded.getPixel(40, 12).a, 255);
  });

  test(
    'PNG → lossless WebP preserves RGB and alpha, native Flutter cross-decode',
    () async {
      final original = alphaFixture();
      final source = input('alpha.png', img.encodePng(original));
      final result = await service.convert(
        task(source, format: RasterFormat.webp),
      );
      final decoded = verifyOutput(result, RasterFormat.webp, 48, 24);
      for (final x in [8, 24, 40]) {
        expect(decoded.getPixel(x, 12).a, original.getPixel(x, 12).a);
        if (x >= 16) {
          expect(decoded.getPixel(x, 12).r, 255);
          expect(decoded.getPixel(x, 12).g, 0);
        }
      }
      final bytes = File((result as ConversionSuccess).outputPath)
          .readAsBytesSync();
      expect(String.fromCharCodes(bytes.sublist(12, 16)), 'VP8L');
      final codec = await ui.instantiateImageCodec(bytes);
      try {
        final frame = await codec.getNextFrame();
        try {
          expect((frame.image.width, frame.image.height), (48, 24));
          final rgba = (await frame.image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          expect(rgba.getUint8((12 * 48 + 8) * 4 + 3), 0);
          expect(rgba.getUint8((12 * 48 + 24) * 4 + 3), 128);
          expect(rgba.getUint8((12 * 48 + 40) * 4), 255);
        } finally {
          frame.image.dispose();
        }
      } finally {
        codec.dispose();
      }
    },
  );

  test('PNG → WebP losslessly preserves a nonuniform RGB fixture', () async {
    final original = rgbFixture();
    final source = input('rgb.png', img.encodePng(original));
    final decoded = verifyOutput(
      await service.convert(task(source, format: RasterFormat.webp)),
      RasterFormat.webp,
      32,
      24,
    );
    for (final pixel in original) {
      final actual = decoded.getPixel(pixel.x, pixel.y);
      expect([actual.r, actual.g, actual.b], [pixel.r, pixel.g, pixel.b]);
    }
  });

  test('grayscale + alpha PNG → WebP keeps the alpha channel', () async {
    final pixels = img.Image(width: 8, height: 8, numChannels: 2);
    for (final pixel in pixels) {
      pixel
        ..r = 120
        ..a = 128;
    }
    final source = input('gray-alpha.png', img.encodePng(pixels));
    final decoded = verifyOutput(
      await service.convert(task(source, format: RasterFormat.webp)),
      RasterFormat.webp,
      8,
      8,
    );
    expect(decoded.getPixel(4, 4).a, 128);
    expect(decoded.getPixel(4, 4).r, 120);
  });

  test('16-bit PNG → WebP scales values into the 8-bit output range', () async {
    final pixels = img.Image(
      width: 8,
      height: 8,
      numChannels: 4,
      format: img.Format.uint16,
    );
    for (final pixel in pixels) {
      pixel
        ..r = 65535
        ..g = 32768
        ..b = 0
        ..a = 65535;
    }
    final source = input('16bit.png', img.encodePng(pixels));
    final decoded = verifyOutput(
      await service.convert(task(source, format: RasterFormat.webp)),
      RasterFormat.webp,
      8,
      8,
    );
    expect(decoded.getPixel(4, 4).r, 255);
    expect(decoded.getPixel(4, 4).g, closeTo(128, 1));
    expect(decoded.getPixel(4, 4).b, 0);
  });

  test('ICO embedded dimensions cannot bypass pixel limit', () async {
    final bytes = fixtureBytes(RasterFormat.ico);
    bytes[6] = 1;
    bytes[7] = 1;
    final source = input('misleading.ico', bytes);
    const limited = ConversionService(limits: ResourceLimits(maxPixels: 100));
    verifyFailure(
      await limited.convert(task(source)),
      ConversionErrorCode.resourceLimit,
    );
  });

  test('cyclic TIFF directory fails instead of looping', () async {
    final bytes = fixtureBytes(RasterFormat.tiff);
    final data = ByteData.sublistView(bytes);
    final endian = bytes[0] == 0x49 ? Endian.little : Endian.big;
    final offset = data.getUint32(4, endian);
    final count = data.getUint16(offset, endian);
    data.setUint32(offset + 2 + count * 12, offset, endian);
    verifyFailure(
      await service.convert(task(input('cycle.tiff', bytes))),
      ConversionErrorCode.corruptImage,
    );
  });

  final sizes = <String, (ResizeOptions, int, int)>{
    'exact width and height': (
      const ResizeOptions(width: 20, height: 10, keepAspectRatio: false),
      20,
      10,
    ),
    'aspect fit inside square': (
      const ResizeOptions(width: 16, height: 16),
      16,
      12,
    ),
    'no upscale with aspect ratio': (
      const ResizeOptions(width: 64, height: 64),
      32,
      24,
    ),
    'upscale explicitly allowed': (
      const ResizeOptions(width: 64, height: 64, preventUpscale: false),
      64,
      48,
    ),
    'no upscale without aspect ratio': (
      const ResizeOptions(width: 16, height: 100, keepAspectRatio: false),
      16,
      24,
    ),
    'single pixel quantization': (
      const ResizeOptions(width: 1, height: 1),
      1,
      1,
    ),
  };
  for (final entry in sizes.entries) {
    test('resize: ${entry.key}', () async {
      final source = input('size.png', fixtureBytes(RasterFormat.png));
      final (options, width, height) = entry.value;
      verifyOutput(
        await service.convert(task(source, resize: options)),
        RasterFormat.png,
        width,
        height,
      );
    });
  }

  test('JPEG EXIF orientation 6 is baked before resizing and output', () async {
    final pixels = img.Image(width: 32, height: 24, numChannels: 3);
    for (final pixel in pixels) {
      pixel
        ..r = pixel.x < 16 ? 255 : 0
        ..g = 0
        ..b = pixel.x >= 16 ? 255 : 0;
    }
    pixels.exif.imageIfd.orientation = 6;
    final source = input('oriented.jpg', img.encodeJpg(pixels, quality: 100));
    final result = await service.convert(task(source));
    final decoded = verifyOutput(result, RasterFormat.png, 24, 32);
    expect(decoded.getPixel(12, 4).r, greaterThan(245));
    expect(decoded.getPixel(12, 28).b, greaterThan(245));
    expect((result as ConversionSuccess).inputWidth, 24);
    final resized = await service.convert(
      task(source, resize: const ResizeOptions(width: 12, height: 12)),
    );
    verifyOutput(resized, RasterFormat.png, 9, 12);
  });

  test('JPG quality is effective and both ends of range encode', () async {
    final source = input(
      'quality.png',
      fixtureBytes(RasterFormat.png, rgbFixture(width: 128, height: 96)),
    );
    final low = await service.convert(
      task(source, format: RasterFormat.jpeg, quality: 1),
    );
    final high = await service.convert(
      task(source, format: RasterFormat.jpeg, quality: 100),
    );
    verifyOutput(low, RasterFormat.jpeg, 128, 96);
    verifyOutput(high, RasterFormat.jpeg, 128, 96);
    expect(
      (high as ConversionSuccess).outputBytes,
      greaterThan((low as ConversionSuccess).outputBytes),
    );
  });

  test(
    'existing outputs get photo_1 and photo_2; originals remain intact',
    () async {
      final source = input('photo.png', fixtureBytes(RasterFormat.png));
      final existing = File(p.join(output.path, 'photo.jpg'))
        ..writeAsStringSync('keep me');
      for (final number in [1, 2]) {
        final result = await service.convert(
          task(source, format: RasterFormat.jpeg),
        );
        verifyOutput(result, RasterFormat.jpeg, 32, 24);
        expect(
          p.basename((result as ConversionSuccess).outputPath),
          'photo_$number.jpg',
        );
      }
      expect(existing.readAsStringSync(), 'keep me');
      expect(source.readAsBytesSync(), fixtureBytes(RasterFormat.png));
    },
  );

  test(
    'same-format conversion in source directory never overwrites input',
    () async {
      final bytes = fixtureBytes(RasterFormat.png);
      final source = input('original.png', bytes);
      final result = await service.convert(
        task(source, directory: sandbox.path),
      );
      verifyOutput(result, RasterFormat.png, 32, 24);
      expect(
        p.basename((result as ConversionSuccess).outputPath),
        'original_1.png',
      );
      expect(source.readAsBytesSync(), bytes);
    },
  );

  test('directories also occupy output names', () async {
    Directory(p.join(output.path, 'photo.png')).createSync();
    final source = input('photo.bmp', fixtureBytes(RasterFormat.bmp));
    final result = await service.convert(task(source));
    verifyOutput(result, RasterFormat.png, 32, 24);
    expect(p.basename((result as ConversionSuccess).outputPath), 'photo_1.png');
  });

  test(
    'concurrent isolates reserve distinct names without overwrites',
    () async {
      final source = input('parallel.png', fixtureBytes(RasterFormat.png));
      final results = await Future.wait(
        List.generate(4, (_) => service.convert(task(source))),
      );
      for (final result in results) {
        verifyOutput(result, RasterFormat.png, 32, 24);
      }
      expect(
        results.cast<ConversionSuccess>().map((r) => r.outputPath).toSet(),
        hasLength(4),
      );
      expect(output.listSync(), hasLength(4));
    },
  );

  test('missing input maps to read failure with no output', () async {
    verifyFailure(
      await service.convert(task(File(p.join(sandbox.path, 'missing.png')))),
      ConversionErrorCode.readFailed,
    );
  });
  test('directory input maps to read failure', () async {
    verifyFailure(
      await service.convert(task(File(sandbox.path))),
      ConversionErrorCode.readFailed,
    );
  });
  test('text disguised as jpg is invalid image', () async {
    verifyFailure(
      await service.convert(task(input('bad.jpg', 'not an image'.codeUnits))),
      ConversionErrorCode.invalidImage,
    );
  });
  test('empty file is invalid image', () async {
    verifyFailure(
      await service.convert(task(input('empty.png', []))),
      ConversionErrorCode.invalidImage,
    );
  });
  test('known unsupported PSD signature reports unsupported format', () async {
    verifyFailure(
      await service.convert(
        task(input('fake.png', [...'8BPS'.codeUnits, ...List.filled(30, 0)])),
      ),
      ConversionErrorCode.unsupportedFormat,
    );
  });
  test(
    'truncated PNG with valid magic is corrupt, not a conversion success',
    () async {
      final bytes = fixtureBytes(RasterFormat.png);
      verifyFailure(
        await service.convert(task(input('broken.png', bytes.sublist(0, 25)))),
        ConversionErrorCode.corruptImage,
      );
    },
  );
  test('corrupted PNG checksum is rejected without output', () async {
    final bytes = fixtureBytes(RasterFormat.png);
    bytes[29] ^= 0xff; // IHDR CRC, not the format signature.
    verifyFailure(
      await service.convert(task(input('crc.png', bytes))),
      ConversionErrorCode.corruptImage,
    );
  });
  test('missing output directory maps to write failure', () async {
    final source = input('input.png', fixtureBytes(RasterFormat.png));
    verifyFailure(
      await service.convert(
        task(source, directory: p.join(sandbox.path, 'missing')),
      ),
      ConversionErrorCode.writeFailed,
    );
  });
  test(
    'file used as output directory is preserved and reports write failure',
    () async {
      final source = input('input.png', fixtureBytes(RasterFormat.png));
      final blocker = input('not-a-directory', [1, 2, 3]);
      verifyFailure(
        await service.convert(task(source, directory: blocker.path)),
        ConversionErrorCode.writeFailed,
      );
      expect(blocker.readAsBytesSync(), [1, 2, 3]);
    },
  );
  test('unimplemented output format fails explicitly', () async {
    final source = input('input.png', fixtureBytes(RasterFormat.png));
    verifyFailure(
      await service.convert(task(source, format: RasterFormat.tiff)),
      ConversionErrorCode.unsupportedFormat,
    );
  });
  test('invalid resize is rejected before writing', () async {
    final source = input('input.png', fixtureBytes(RasterFormat.png));
    verifyFailure(
      await service.convert(
        task(source, resize: const ResizeOptions(width: 0, height: -1)),
      ),
      ConversionErrorCode.invalidOptions,
    );
  });
  for (final quality in [0, 101]) {
    test('invalid JPG quality $quality fails', () async {
      final source = input('input.png', fixtureBytes(RasterFormat.png));
      verifyFailure(
        await service.convert(
          task(source, format: RasterFormat.jpeg, quality: quality),
        ),
        ConversionErrorCode.invalidOptions,
      );
    });
  }
  test('input byte limit is enforced', () async {
    final source = input('input.png', fixtureBytes(RasterFormat.png));
    const limited = ConversionService(
      limits: ResourceLimits(maxInputBytes: 10),
    );
    verifyFailure(
      await limited.convert(task(source)),
      ConversionErrorCode.resourceLimit,
    );
  });
  test('input pixel limit is enforced before frame decoding', () async {
    final source = input('input.png', fixtureBytes(RasterFormat.png));
    const limited = ConversionService(limits: ResourceLimits(maxPixels: 100));
    verifyFailure(
      await limited.convert(task(source)),
      ConversionErrorCode.resourceLimit,
    );
  });
  test('oversized output is rejected before allocation', () async {
    final source = input('input.png', fixtureBytes(RasterFormat.png));
    verifyFailure(
      await service.convert(
        task(
          source,
          resize: const ResizeOptions(
            width: 20000,
            height: 20000,
            preventUpscale: false,
          ),
        ),
      ),
      ConversionErrorCode.resourceLimit,
    );
  });
  for (final format in [
    RasterFormat.gif,
    RasterFormat.png,
    RasterFormat.tiff,
    RasterFormat.ico,
  ]) {
    test(
      '${format.label} animation/multiple images are rejected rather than flattened',
      () async {
        final sequence = rgbFixture();
        sequence.addFrame(rgbFixture());
        final bytes = format == RasterFormat.tiff
            ? twoPageTiff()
            : format == RasterFormat.ico
            ? img.IcoEncoder().encodeImages([rgbFixture(), rgbFixture()])
            : fixtureBytes(format, sequence);
        expect(
          img.decodeImage(bytes)!.numFrames,
          2,
          reason: 'The fixture must really contain two frames/pages',
        );
        verifyFailure(
          await service.convert(task(input('sequence.bin', bytes))),
          ConversionErrorCode.unsupportedSequence,
        );
      },
    );
  }

  test('truncated WebP and JPEG headers cannot pass as images', () async {
    for (final format in [RasterFormat.webp, RasterFormat.jpeg]) {
      final bytes = Uint8List.fromList(fixtureBytes(format).take(16).toList());
      verifyFailure(
        await service.convert(task(input('truncated-$format.bin', bytes))),
        ConversionErrorCode.corruptImage,
      );
    }
  });
}

String describeResult(ConversionResult result) => result is ConversionFailure
    ? '${result.error}: ${result.error.detail}'
    : result.runtimeType.toString();
