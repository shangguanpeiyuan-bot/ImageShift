import 'dart:ffi';
import 'dart:io';

import 'package:libvips_ffi_api/libvips_ffi_api.dart';

/// Run beside the bundled libvips DLLs, or pass their verified directory.
void main(List<String> args) {
  if (args.length != 3) {
    throw ArgumentError('DLL directory, input, output required');
  }
  final libraries = [
    for (final name in [
      'libglib-2.0-0.dll',
      'libgobject-2.0-0.dll',
      'libvips-42.dll',
    ])
      DynamicLibrary.open('${args[0]}/$name'),
  ];
  Pointer<T> lookup<T extends NativeType>(String name) {
    for (final library in libraries.reversed) {
      try {
        return library.lookup<T>(name);
      } on ArgumentError {
        /* next DLL */
      }
    }
    throw ArgumentError('Missing native symbol $name');
  }

  initVipsApiWithLookup(lookup, libraries.last);
  final watch = Stopwatch()..start();
  final pipeline = VipsPipeline.fromFile('${args[1]}[access=sequential]');
  try {
    stdout.writeln(
      'vips=$vipsVersionString input=${pipeline.width}x${pipeline.height}',
    );
    pipeline.autoRotate();
    pipeline.toFile(args[2]);
  } finally {
    pipeline.dispose();
  }
  stdout.writeln(
    'elapsedMs=${watch.elapsedMilliseconds} rss=${ProcessInfo.currentRss} peak=${ProcessInfo.maxRss}',
  );
}
