import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:imageshift/core/image_engine.dart';

import '../support/image_fixtures.dart';

void main() {
  const detector = FormatDetector();
  for (final format in RasterFormat.values) {
    test('detects ${format.label} by bytes only', () {
      expect(detector.detect(fixtureBytes(format)), format);
    });
  }
  test('RIFF without WEBP is not classified as WebP', () {
    final bytes = Uint8List.fromList([
      ...'RIFF'.codeUnits,
      4,
      0,
      0,
      0,
      ...'WAVE'.codeUnits,
    ]);
    expect(() => detector.detect(bytes), throwsA(isA<ConversionError>()));
  });
  test('arbitrary binary data is not guessed as TGA', () {
    final random = Random(71);
    for (var i = 0; i < 100; i++) {
      final bytes = Uint8List.fromList(
        List.generate(128, (_) => random.nextInt(256)),
      );
      expect(() => detector.detect(bytes), throwsA(isA<ConversionError>()));
    }
  });
  test('headerless TGA must have the exact declared uncompressed length', () {
    final bytes = fixtureBytes(RasterFormat.tga);
    expect(
      () => detector.detect(Uint8List.sublistView(bytes, 0, bytes.length - 1)),
      throwsA(isA<ConversionError>()),
    );
  });
}
