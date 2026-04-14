// ignore_for_file: unused_local_variable, unused_element
// Test fixture for avoid_unverified_native_library rule (OWASP M2)
//
// Rule: avoid_unverified_native_library
// Severity: ERROR | Impact: Critical | Tier: Essential
//
// Flags DynamicLibrary.open() calls with absolute paths, relative paths
// containing directory separators, or non-constant (variable) arguments.
// All of these bypass the app bundle's verified native library set.

import 'dart:ffi';

// =============================================================================
// BAD: Dynamic or path-containing arguments — should trigger
// =============================================================================

void testVariablePath(String userPath) {
  // BAD: Attacker can control the library location via a variable
  // expect_lint: avoid_unverified_native_library
  DynamicLibrary.open(userPath);
}

void testAbsoluteUnixPaths() {
  // BAD: Absolute Unix path — can be substituted on compromised device
  // expect_lint: avoid_unverified_native_library
  DynamicLibrary.open('/usr/lib/libcrypto.so');

  // BAD: Absolute macOS path
  // expect_lint: avoid_unverified_native_library
  DynamicLibrary.open('/usr/local/lib/libssl.dylib');
}

void testRelativePaths() {
  // BAD: Forward slash makes this a directory-relative path
  // expect_lint: avoid_unverified_native_library
  DynamicLibrary.open('libs/libbar.so');

  // BAD: Directory traversal — walks outside the bundle
  // expect_lint: avoid_unverified_native_library
  DynamicLibrary.open('../libs/libfoo.dylib');
}

void testWindowsAbsolutePath() {
  // BAD: Windows absolute path — not from verified bundle
  // cspell:disable-next-line
  // expect_lint: avoid_unverified_native_library
  DynamicLibrary.open(r'C:\Windows\System32\library.dll');
}

// =============================================================================
// GOOD: Bundled library names only — should NOT trigger
// =============================================================================

void testBundledLibraryNames() {
  // GOOD: Simple name — Flutter/Dart resolves from the verified app bundle
  DynamicLibrary.open('libfoo.dylib');
  DynamicLibrary.open('libbar.so');
  DynamicLibrary.open('library.dll');

  // GOOD: Versioned library name with no path separator
  DynamicLibrary.open('libcrypto.1.1.so');
}
