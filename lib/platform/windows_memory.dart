import 'dart:ffi';

import 'package:ffi/ffi.dart';

final class _MemoryStatus extends Struct {
  @Uint32()
  external int length;
  @Uint32()
  external int load;
  @Uint64()
  external int totalPhysical;
  @Uint64()
  external int availablePhysical;
  @Uint64()
  external int totalPageFile;
  @Uint64()
  external int availablePageFile;
  @Uint64()
  external int totalVirtual;
  @Uint64()
  external int availableVirtual;
  @Uint64()
  external int reserved;
}

int? windowsAvailableMemory() {
  final status = calloc<_MemoryStatus>();
  try {
    status.ref.length = sizeOf<_MemoryStatus>();
    final query = DynamicLibrary.open('kernel32.dll')
        .lookupFunction<
          Int32 Function(Pointer<_MemoryStatus>),
          int Function(Pointer<_MemoryStatus>)
        >('GlobalMemoryStatusEx');
    if (query(status) == 0) return null;
    final physical = status.ref.availablePhysical;
    final commit = status.ref.availablePageFile;
    return physical < commit ? physical : commit;
  } finally {
    calloc.free(status);
  }
}
