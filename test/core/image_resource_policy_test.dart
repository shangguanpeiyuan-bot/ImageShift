import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:imageshift/core/media/jobs/image_resource_policy.dart';
import 'package:imageshift/core/media/model/media.dart';
import 'package:imageshift/platform/windows_memory.dart';

void main() {
  test(
    'available memory and decoder characteristics govern large image admission',
    () {
      MediaProbe probe(String format) => MediaProbe(
        kind: MediaKind.image,
        format: format,
        bytes: 2000000,
        width: 10000,
        height: 10000,
      );
      MediaJob job(int budget) => MediaJob(
        id: 'budget',
        inputPath: '',
        outputDirectory: '',
        outputFormat: 'jpg',
        memoryBudgetBytes: budget,
      );
      checkImageResources(probe('png'), job(256 * 1024 * 1024));
      expect(
        () => checkImageResources(probe('webp'), job(256 * 1024 * 1024)),
        throwsA(
          isA<MediaError>().having(
            (e) => e.code,
            'code',
            MediaErrorCode.resourceUnavailable,
          ),
        ),
      );
      checkImageResources(probe('webp'), job(1024 * 1024 * 1024));
      expect(
        () => checkImageResources(probe('jpg'), job(0)),
        throwsA(isA<MediaError>()),
      );
    },
  );
  test('Windows reads actual available memory', () {
    expect(windowsAvailableMemory(), greaterThan(0));
  }, skip: !Platform.isWindows);
}
