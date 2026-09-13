import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:imageshift/core/image_engine.dart';
import 'package:imageshift/core/services/image_inspector.dart';
import 'package:imageshift/application/editor_settings.dart';
import 'package:path/path.dart' as p;

import '../support/image_fixtures.dart';

void main() {
  late Directory sandbox, output;
  setUp(() {
    sandbox = Directory.systemTemp.createTempSync('imageshift_b_');
    output = Directory(p.join(sandbox.path, 'out'))..createSync();
  });
  tearDown(() => sandbox.deleteSync(recursive: true));
  File input(img.Image pixels, {RasterFormat format = RasterFormat.png}) =>
      File(p.join(sandbox.path, 'source.${format.extension}'))
        ..writeAsBytesSync(fixtureBytes(format, pixels));
  Future<(ConversionSuccess, img.Image)> convert(
    File source, {
    EditOptions edits = const EditOptions(),
    ResizeOptions? resize,
    RasterFormat format = RasterFormat.png,
    String? stem,
  }) async {
    final original = source.readAsBytesSync();
    final result = await const ConversionService().convert(
      ConversionTask(
        id: 'b',
        inputPath: source.path,
        outputDirectory: output.path,
        outputFormat: format,
        edits: edits,
        resize: resize,
        outputStem: stem,
      ),
    );
    expect(
      result,
      isA<ConversionSuccess>(),
      reason: result is ConversionFailure
          ? '${result.error}: ${result.error.detail}'
          : null,
    );
    final success = result as ConversionSuccess;
    final file = File(success.outputPath);
    expect(file.existsSync(), isTrue);
    final bytes = file.readAsBytesSync();
    expect(const FormatDetector().detect(bytes), format);
    final decoded = img.decodeImage(bytes)!;
    expect((decoded.width, decoded.height), (success.width, success.height));
    expect(bytes.length, success.outputBytes);
    expect(source.readAsBytesSync(), original);
    return (success, decoded);
  }

  test('crop extracts the requested pixels into a new PNG', () async {
    final pixels = rgbFixture(width: 40, height: 20);
    final (_, result) = await convert(
      input(pixels),
      edits: const EditOptions(crop: CropRegion(.25, .25, .5, .5)),
    );
    expect((result.width, result.height), (20, 10));
    expect(result.getPixel(0, 0).r, pixels.getPixel(10, 5).r);
    expect(result.getPixel(19, 9).b, pixels.getPixel(29, 14).b);
  });
  for (final turns in [1, 2, 3, -1]) {
    test(
      'rotation $turns quarter turns preserves spatial correspondence',
      () async {
        final source = rgbFixture(width: 40, height: 20);
        final (_, result) = await convert(
          input(source),
          edits: EditOptions(quarterTurns: turns),
        );
        expect((
          result.width,
          result.height,
        ), turns.isOdd ? (20, 40) : (40, 20));
        final (x, y) = switch (turns % 4) {
          1 => (19, 0),
          2 => (39, 19),
          _ => (0, 39),
        };
        expect(result.getPixel(x, y).r, source.getPixel(0, 0).r);
        expect(result.getPixel(x, y).g, source.getPixel(0, 0).g);
      },
    );
  }
  for (final horizontal in [true, false]) {
    test(
      '${horizontal ? 'horizontal' : 'vertical'} flip moves pixels correctly',
      () async {
        final source = rgbFixture(width: 40, height: 20);
        final (_, result) = await convert(
          input(source),
          edits: EditOptions(
            flipHorizontal: horizontal,
            flipVertical: !horizontal,
          ),
        );
        expect(
          result.getPixel(horizontal ? 39 : 0, horizontal ? 0 : 19).b,
          source.getPixel(0, 0).b,
        );
        expect(
          result.getPixel(0, 0).g,
          source.getPixel(horizontal ? 39 : 0, horizontal ? 0 : 19).g,
        );
      },
    );
  }
  test('pipeline applies resize then crop then rotate and never re-encodes intermediate files', () async {
    final (_, result) = await convert(
      input(rgbFixture(width: 80, height: 40)),
      resize: const ResizeOptions(width: 40, height: 20),
      edits: const EditOptions(
        crop: CropRegion(0, 0, .5, 1),
        quarterTurns: 1,
        flipHorizontal: true,
      ),
    );
    expect((result.width, result.height), (20, 20));
    expect(output.listSync().length, 1);
  });
  for (final color in [0x000000, 0x2070c0]) {
    test('transparent PNG -> JPG uses actual RGB background $color', () async {
      final (_, result) = await convert(
        input(alphaFixture()),
        format: RasterFormat.jpeg,
        edits: EditOptions(backgroundRgb: color),
      );
      final pixel = result.getPixel(5, 10);
      expect(pixel.r, closeTo((color >> 16) & 255, 4));
      expect(pixel.g, closeTo((color >> 8) & 255, 4));
      expect(pixel.b, closeTo(color & 255, 4));
    });
  }
  test(
    'PNG compression changes encoded size without changing decoded pixels',
    () async {
      final file = input(rgbFixture(width: 160, height: 80));
      final (fast, a) = await convert(
        file,
        edits: const EditOptions(pngCompression: 0),
      );
      final (small, b) = await convert(
        file,
        edits: const EditOptions(pngCompression: 9),
      );
      expect(small.outputBytes, lessThan(fast.outputBytes));
      expect(a.getBytes(), b.getBytes());
    },
  );
  test('JPEG EXIF inspector reads real camera/date/orientation and cleaner removes EXIF', () async {
    final source = rgbFixture(width: 40, height: 20);
    source.exif.imageIfd['Make'] = 'ImageShift Test Camera';
    source.exif.imageIfd['Model'] = 'Fixture 1';
    source.exif.exifIfd['DateTimeOriginal'] = '2026:09:13 12:34:56';
    source.exif.imageIfd.orientation = 6;
    final file = input(source, format: RasterFormat.jpeg);
    final info = await const ImageInspector().inspect(file.path);
    expect(info.metadata['相机品牌'], 'ImageShift Test Camera');
    expect(info.metadata['拍摄时间'], '2026:09:13 12:34:56');
    expect(info.metadata['原始 EXIF 方向'], contains('6'));
    expect((info.width, info.height), (20, 40));
    final (_, preserved) = await convert(file, format: RasterFormat.jpeg);
    expect(
      preserved.exif.imageIfd['Make']?.toString(),
      'ImageShift Test Camera',
    );
    expect(preserved.exif.imageIfd.hasOrientation, isFalse);
    final (clean, cleaned) = await convert(
      file,
      format: RasterFormat.jpeg,
      edits: const EditOptions(stripMetadata: true),
    );
    expect(cleaned.exif.isEmpty, isTrue);
    expect(
      latin1.decode(File(clean.outputPath).readAsBytesSync()),
      isNot(contains('ImageShift Test Camera')),
    );
  });
  test(
    'PNG cleaner strips actual text and ICC chunks while retaining alpha',
    () async {
      final source = alphaFixture()
        ..textData = {'Author': 'private-test-name'}
        ..iccProfile = img.IccProfile(
          'test-profile',
          img.IccProfileCompression.none,
          Uint8List.fromList(List.generate(128, (i) => i)),
        );
      final file = input(source);
      final original = img.decodePng(file.readAsBytesSync())!;
      expect(original.textData?['Author'], 'private-test-name');
      expect(original.iccProfile, isNotNull);
      final (clean, result) = await convert(
        file,
        edits: const EditOptions(stripMetadata: true),
      );
      expect(result.textData, isNull);
      expect(result.iccProfile, isNull);
      expect(result.getPixel(0, 0).a, 0);
      final raw = latin1.decode(File(clean.outputPath).readAsBytesSync());
      expect(raw, isNot(contains('iCCP')));
      expect(raw, isNot(contains('tEXt')));
    },
  );
  test('rename preview, filename sanitization and existing output protection agree', () async {
    const rename = RenameOptions(
      prefix: 'ImageShift_',
      suffix: '_edit',
      useSequence: true,
      start: 7,
      digits: 4,
    );
    final stem = rename.stem('original.png', 1);
    expect(stem, 'ImageShift_0008_edit');
    final file = input(rgbFixture());
    final (a, _) = await convert(file, stem: stem);
    final (b, _) = await convert(file, stem: stem);
    expect(p.basename(a.outputPath), '$stem.png');
    expect(p.basename(b.outputPath), '${stem}_1.png');
    expect(OutputNamer.sanitizeStem('../CON:bad?'), isNot(contains('/')));
    expect(
      const RenameOptions(prefix: 'pre_', suffix: '_post').stem('photo.jpg', 0),
      'pre_photo_post',
    );
  });
  for (final edits in [
    const EditOptions(crop: CropRegion(-.1, 0, .2, .2)),
    const EditOptions(crop: CropRegion(0, 0, 0, 1)),
    const EditOptions(crop: CropRegion(.5, 0, 1, 1)),
    const EditOptions(pngCompression: 10),
    const EditOptions(backgroundRgb: -1),
  ]) {
    test(
      'invalid edit options fail without creating an output ${edits.crop?.left}/${edits.pngCompression}/${edits.backgroundRgb}',
      () async {
        final result = await const ConversionService().convert(
          ConversionTask(
            id: 'bad',
            inputPath: input(rgbFixture()).path,
            outputDirectory: output.path,
            outputFormat: RasterFormat.png,
            edits: edits,
          ),
        );
        expect(result, isA<ConversionFailure>());
        expect(
          (result as ConversionFailure).error.code,
          ConversionErrorCode.invalidOptions,
        );
        expect(output.listSync(), isEmpty);
      },
    );
  }
  test(
    'inspection returns small thumbnails and correct original dimensions',
    () async {
      final file = input(rgbFixture(width: 1000, height: 500));
      final info = await const ImageInspector().inspect(file.path);
      expect((info.width, info.height), (1000, 500));
      final thumb = img.decodePng(info.thumbnail)!;
      expect((thumb.width, thumb.height), (160, 80));
    },
  );
  test(
    'resize modes resolve against each source rather than first batch image',
    () {
      final settings = EditorSettings()
        ..resizeEnabled = true
        ..resizeMode = ResizeMode.longest
        ..edge = 100;
      expect(
        (
          settings.resizeFor(400, 200)!.width,
          settings.resizeFor(400, 200)!.height,
        ),
        (100, 50),
      );
      expect(
        (
          settings.resizeFor(200, 400)!.width,
          settings.resizeFor(200, 400)!.height,
        ),
        (50, 100),
      );
      settings
        ..resizeMode = ResizeMode.percent
        ..percent = 25;
      expect(settings.resizeFor(400, 200)!.width, 100);
      settings.percent = 0;
      expect(
        () => settings.resizeFor(400, 200),
        throwsA(isA<ConversionError>()),
      );
    },
  );
}
