/// ANSI color support and display helpers for the init tool.
library;

import 'dart:developer' as dev;
import 'dart:ffi';
import 'dart:io';

// ---------------------------------------------------------------------------
// Cross-platform ANSI color support
// ---------------------------------------------------------------------------

/// Enable ANSI virtual terminal processing on Windows 10+.
///
/// Windows supports ANSI escape codes but requires enabling
/// ENABLE_VIRTUAL_TERMINAL_PROCESSING on the console output handle.
/// Dart's [stdout.supportsAnsiEscapes] only checks the flag; this sets it.
void tryEnableAnsiWindows() {
  if (!Platform.isWindows) return;
  try {
    final k = DynamicLibrary.open('kernel32.dll');
    final getStdHandle = k
        .lookupFunction<IntPtr Function(Int32), int Function(int)>(
          'GetStdHandle',
        );
    final getMode = k
        .lookupFunction<
          Int32 Function(IntPtr, Pointer<Uint32>),
          int Function(int, Pointer<Uint32>)
        >('GetConsoleMode');
    final setMode = k
        .lookupFunction<Int32 Function(IntPtr, Uint32), int Function(int, int)>(
          'SetConsoleMode',
        );
    final getHeap = k.lookupFunction<IntPtr Function(), int Function()>(
      'GetProcessHeap',
    );
    final alloc = k
        .lookupFunction<
          Pointer<Void> Function(IntPtr, Uint32, IntPtr),
          Pointer<Void> Function(int, int, int)
        >('HeapAlloc');
    final free = k
        .lookupFunction<
          Int32 Function(IntPtr, Uint32, Pointer<Void>),
          int Function(int, int, Pointer<Void>)
        >('HeapFree');

    final handle = getStdHandle(-11); // STD_OUTPUT_HANDLE
    final heap = getHeap();
    final ptr = alloc(heap, 0x08, 4); // HEAP_ZERO_MEMORY, 4 bytes
    if (ptr.address == 0) return;

    final mode = ptr.cast<Uint32>();
    if (getMode(handle, mode) != 0) {
      setMode(
        handle,
        mode.value | 0x0004,
      ); // ENABLE_VIRTUAL_TERMINAL_PROCESSING
    }
    free(heap, 0, ptr);
  } on Object catch (e, st) {
    dev.log(
      'VTP unavailable; colors degrade to plain text',
      error: e,
      stackTrace: st,
    );
  }
}

/// Cached color support result.
bool? _hasColorSupportCache;

/// Detects if the terminal supports ANSI colors.
bool get hasColorSupport {
  return _hasColorSupportCache ??= _detectColorSupport();
}

/// Checks terminal capabilities for ANSI color support.
bool _detectColorSupport() {
  // Standard NO_COLOR / FORCE_COLOR environment variables
  if (Platform.environment.containsKey('NO_COLOR')) return false;

  if (Platform.environment.containsKey('FORCE_COLOR')) return true;

  // Not a terminal (piped, redirected)
  if (!stdout.hasTerminal) return false;

  // Dart's built-in check (reliable after VTP is enabled on Windows)
  if (stdout.supportsAnsiEscapes) return true;

  // cspell:ignore ANSICON
  // Windows: detect terminals known to support ANSI
  if (Platform.isWindows) {
    final env = Platform.environment;
    return env.containsKey('WT_SESSION') || // Windows Terminal
        env['ConEmuANSI'] == 'ON' || // ConEmu
        env['TERM_PROGRAM'] == 'vscode' || // VS Code terminal
        env.containsKey('ANSICON') || // ANSICON
        env['TERM'] == 'xterm'; // xterm-compatible
  }

  // Unix-like: most terminals support colors
  return true;
}

/// ANSI color codes (cross-platform safe).
class InitColors {
  static String get reset => hasColorSupport ? '\x1B[0m' : '';
  static String get bold => hasColorSupport ? '\x1B[1m' : '';
  static String get dim => hasColorSupport ? '\x1B[2m' : '';

  // Foreground colors
  static String get red => hasColorSupport ? '\x1B[31m' : '';
  static String get green => hasColorSupport ? '\x1B[32m' : '';
  static String get yellow => hasColorSupport ? '\x1B[33m' : '';
  static String get blue => hasColorSupport ? '\x1B[34m' : '';
  static String get magenta => hasColorSupport ? '\x1B[35m' : '';
  static String get cyan => hasColorSupport ? '\x1B[36m' : '';

  // Bright variants
  static String get brightRed => hasColorSupport ? '\x1B[91m' : '';
  static String get brightCyan => hasColorSupport ? '\x1B[96m' : '';
}

/// Wraps [text] in green (success) color.
String successText(String text) =>
    '${InitColors.green}$text${InitColors.reset}';

/// Wraps [text] in red (error) color.
String errorText(String text) => '${InitColors.red}$text${InitColors.reset}';

/// Colors a tier name according to its severity level.
String tierColor(String tier) {
  switch (tier) {
    case 'essential':
      return '${InitColors.brightRed}$tier${InitColors.reset}';
    case 'recommended':
      return '${InitColors.yellow}$tier${InitColors.reset}';
    case 'professional':
      return '${InitColors.blue}$tier${InitColors.reset}';
    case 'comprehensive':
      return '${InitColors.magenta}$tier${InitColors.reset}';
    case 'pedantic':
      return '${InitColors.brightCyan}$tier${InitColors.reset}';
    case 'stylistic':
      return '${InitColors.dim}$tier${InitColors.reset}';
    default:
      return tier;
  }
}
