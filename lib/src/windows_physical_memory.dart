/// In-process total-RAM probe for Windows via `GlobalMemoryStatusEx`.
///
/// Exists so plugin startup does not spawn a process. The memory subsystem
/// sizes its adaptive RSS cap from total physical RAM, and on Windows it used
/// to get that number by running `powershell ... Get-CimInstance` from
/// `Plugin.start()`. That spawn took ~360 ms of the ~390 ms `start()` cost per
/// plugin isolate (measured against the two-package reproducer in
/// `plans/history/2026.11/2026.11.27/infra_dart_analyze_parent_folder_skips_second_package.md`).
/// `dart analyze <parent>` starts one plugin isolate per package and exits as
/// soon as the first isolate reports idle, so that delay was enough for the
/// second package's diagnostics to be dropped. A direct kernel32 call costs
/// microseconds and keeps the isolate ready as soon as `register()` returns.
library;

import 'dart:ffi';
import 'dart:io' show Platform;

/// Size in bytes of the Win32 `MEMORYSTATUSEX` struct: two `DWORD`s
/// (`dwLength`, `dwMemoryLoad`) followed by seven `DWORDLONG`s.
const int _memoryStatusExSize = 64;

/// Byte offset of `ullTotalPhys` inside `MEMORYSTATUSEX`.
const int _totalPhysOffset = 8;

/// `HEAP_ZERO_MEMORY` flag for `HeapAlloc`, so unused fields start at zero.
const int _heapZeroMemory = 0x08;

/// Returns total physical memory in MB, or `null` when the probe cannot run.
///
/// `null` (rather than -1) tells the caller to fall back to its process-based
/// probe, so a failure here never loses the RAM figure, it only costs the old
/// spawn. Returns `null` on every non-Windows platform without touching FFI.
int? windowsTotalPhysicalMemoryMb() {
  // Guard first: kernel32 exists only on Windows, and opening it elsewhere
  // would throw (caught below, but there is no reason to pay for it).
  if (!Platform.isWindows) return null;
  try {
    return _queryGlobalMemoryStatus();
  } on Object {
    // Missing export, blocked FFI, or any loader failure: let the caller use
    // its fallback instead of crashing plugin startup.
    return null;
  }
}

/// Calls `GlobalMemoryStatusEx` on a heap-allocated `MEMORYSTATUSEX` and
/// reads `ullTotalPhys`. Uses kernel32's own heap functions (the same pattern
/// as `tryEnableAnsiWindows` in `init/display.dart`) so no `package:ffi`
/// dependency is needed for an allocator.
int? _queryGlobalMemoryStatus() {
  final kernel32 = DynamicLibrary.open('kernel32.dll');
  final getProcessHeap = kernel32
      .lookupFunction<IntPtr Function(), int Function()>('GetProcessHeap');
  final heapAlloc = kernel32
      .lookupFunction<
        Pointer<Void> Function(IntPtr, Uint32, IntPtr),
        Pointer<Void> Function(int, int, int)
      >('HeapAlloc');
  final heapFree = kernel32
      .lookupFunction<
        Int32 Function(IntPtr, Uint32, Pointer<Void>),
        int Function(int, int, Pointer<Void>)
      >('HeapFree');
  final globalMemoryStatusEx = kernel32
      .lookupFunction<
        Int32 Function(Pointer<Void>),
        int Function(Pointer<Void>)
      >('GlobalMemoryStatusEx');

  final heap = getProcessHeap();
  final buffer = heapAlloc(heap, _heapZeroMemory, _memoryStatusExSize);
  // A null allocation means the probe cannot run; report "unknown".
  if (buffer.address == 0) return null;
  try {
    // The API rejects the call unless dwLength holds the struct size.
    buffer.cast<Uint32>().value = _memoryStatusExSize;
    // BOOL result: zero means failure (for example a wrong dwLength).
    if (globalMemoryStatusEx(buffer) == 0) return null;
    final totalBytes = Pointer<Uint64>.fromAddress(
      buffer.address + _totalPhysOffset,
    ).value;
    // A zero total is not a real machine; treat it as "unknown" so the caller
    // falls back rather than sizing caps from 0 MB.
    if (totalBytes <= 0) return null;
    return totalBytes ~/ (1 << 20);
  } finally {
    // Always release the buffer, including on the early returns above.
    heapFree(heap, 0, buffer);
  }
}
