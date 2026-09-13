import 'dart:io';

/// Windows can briefly retain a directory handle after journal-file deletion.
/// Only retry sharing/directory-not-empty errors on an owned test sandbox;
/// all other errors and persistent failures still fail the test.
Future<void> deleteTestDirectory(Directory directory) async {
  final root = Directory.systemTemp.absolute.path;
  if (!directory.absolute.path.startsWith('$root${Platform.pathSeparator}')) {
    throw ArgumentError('Cleanup must stay in the test temporary directory');
  }
  for (var attempt = 0; ; attempt++) {
    try {
      if (await directory.exists()) await directory.delete(recursive: true);
      return;
    } on FileSystemException catch (error) {
      if (!Platform.isWindows ||
          attempt == 3 ||
          !{32, 145}.contains(error.osError?.errorCode)) {
        rethrow;
      }
      await Future<void>.delayed(Duration(milliseconds: 100 * (attempt + 1)));
    }
  }
}
