import 'dart:ffi';
import 'dart:io';

import 'package:libvips_ffi_api/libvips_ffi_api.dart' as api;
import 'package:libvips_ffi_windows/libvips_ffi_windows.dart' as core;
import 'package:path/path.dart' as p;

/// Initialize once per isolate; never call global vips_shutdown while another
/// isolate might still own native images. Production uses bundled libraries.
void initializeVips({String? windowsLibraryDirectory}) {
  if (api.isVipsApiInitialized) return;
  final directory =
      windowsLibraryDirectory ?? p.dirname(Platform.resolvedExecutable);
  final names = Platform.isWindows
      ? ['libglib-2.0-0.dll', 'libgobject-2.0-0.dll', 'libvips-42.dll']
      : ['libglib-2.0.so', 'libgobject-2.0.so', 'libvips.so'];
  final libraries = [
    for (final name in names)
      DynamicLibrary.open(Platform.isWindows ? p.join(directory, name) : name),
  ];
  Pointer<T> lookup<T extends NativeType>(String symbol) {
    for (final library in libraries.reversed) {
      try {
        return library.lookup<T>(symbol);
      } on ArgumentError {
        /* next */
      }
    }
    throw ArgumentError('Missing native symbol $symbol');
  }

  core.initVipsWithLookup(lookup, libraries.last, 'ImageShift');
  api.initVipsApiWithLookup(lookup, libraries.last, 'ImageShift');
  core.vipsBindings.vips_cache_set_max(0);
  core.vipsBindings.vips_cache_set_max_mem(32 * 1024 * 1024);
  core.vipsBindings.vips_concurrency_set(2);
}
