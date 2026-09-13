import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imageshift/application/third_party_licenses.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'native notices are bundled and readable without network access',
    () async {
      final entries = await bundledLicenses(rootBundle).toList();
      final names = entries.expand((e) => e.packages).toSet();
      expect(
        names,
        containsAll([
          'ImageShift',
          'libvips-LGPL-2.1.txt',
          'ffmpeg-LGPL-3.0.txt',
          'android-ffmpegkit-license_openh264.txt',
          'Unlock-Music-MIT.txt',
        ]),
      );
      expect(names.any((name) => name.endsWith('.json')), isFalse);
      for (final entry in entries) {
        expect(entry.paragraphs.map((p) => p.text).join().trim(), isNotEmpty);
      }
    },
  );
}
