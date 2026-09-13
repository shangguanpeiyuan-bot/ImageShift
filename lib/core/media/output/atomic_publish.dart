import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;

/// Native no-replace publication. A failed call never removes its destination.
bool publishWithoutReplacement(String source, String destination) {
  if (source.contains('\u0000') || destination.contains('\u0000')) {
    throw const FileSystemException('Invalid output path');
  }
  if (Platform.isWindows) {
    final library = DynamicLibrary.open('kernel32.dll');
    final move = library
        .lookupFunction<
          Int32 Function(Pointer<Utf16>, Pointer<Utf16>),
          int Function(Pointer<Utf16>, Pointer<Utf16>)
        >('MoveFileW');
    String extended(String path) {
      path = p.normalize(p.absolute(path)).replaceAll('/', r'\');
      if (path.startsWith(r'\\?\')) return path;
      if (path.startsWith(r'\\')) return r'\\?\UNC\' + path.substring(2);
      return r'\\?\' + path;
    }

    final from = extended(source).toNativeUtf16(),
        to = extended(destination).toNativeUtf16();
    try {
      return move(from, to) != 0;
    } finally {
      calloc.free(from);
      calloc.free(to);
    }
  }
  if (Platform.isAndroid) {
    final library = DynamicLibrary.open('libc.so');
    final from = source.toNativeUtf8(), to = destination.toNativeUtf8();
    try {
      // NDK 28.2 stdio.h: API 30, AT_FDCWD=-100, RENAME_NOREPLACE=1.
      try {
        final rename = library
            .lookupFunction<
              Int32 Function(
                Int32,
                Pointer<Utf8>,
                Int32,
                Pointer<Utf8>,
                Uint32,
              ),
              int Function(int, Pointer<Utf8>, int, Pointer<Utf8>, int)
            >('renameat2');
        return rename(-100, from, -100, to, 1) == 0;
      } on ArgumentError {
        // Older bionic lacks the wrapper, while Android's Linux kernel has
        // the syscall. Numbers come from the NDK's per-ABI uapi headers.
        final number = switch (Abi.current()) {
          Abi.androidArm64 => 276,
          Abi.androidX64 => 316,
          Abi.androidArm => 382,
          _ => throw const FileSystemException('Unsupported Android ABI'),
        };
        final syscall = library
            .lookupFunction<
              IntPtr Function(
                IntPtr,
                IntPtr,
                Pointer<Utf8>,
                IntPtr,
                Pointer<Utf8>,
                IntPtr,
              ),
              int Function(int, int, Pointer<Utf8>, int, Pointer<Utf8>, int)
            >('syscall');
        return syscall(number, -100, from, -100, to, 1) == 0;
      }
    } finally {
      calloc.free(from);
      calloc.free(to);
    }
  }
  final link = DynamicLibrary.process()
      .lookupFunction<
        Int32 Function(Pointer<Utf8>, Pointer<Utf8>),
        int Function(Pointer<Utf8>, Pointer<Utf8>)
      >('link');
  final from = source.toNativeUtf8(), to = destination.toNativeUtf8();
  // Both paths are on the destination volume. The staging link is removed
  // by TempFileManager after a successful publish; the complete output remains.
  try {
    return link(from, to) == 0;
  } finally {
    calloc.free(from);
    calloc.free(to);
  }
}
