import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app/imageshift_app.dart';
import 'application/local_library.dart';
import 'application/workspace_controller.dart';
import 'platform/file_access.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'image: additional codec notices',
    ], await rootBundle.loadString('docs/third_party/image-LICENSE-other.md'));
  });
  final files = FileAccess();
  LocalLibrary library;
  try {
    library = LocalLibrary(
      store: LibraryStore(await files.applicationDirectory()),
    );
    await library.load();
  } catch (_) {
    library = LocalLibrary()..storageError = '本地存储不可用，本次设置不会保存。';
  }
  final controller = WorkspaceController(files: files, library: library);
  runApp(ImageShiftApp(controller: controller, library: library));
}
