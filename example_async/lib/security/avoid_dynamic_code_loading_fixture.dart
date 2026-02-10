// ignore_for_file: unused_local_variable, avoid_eval_like_patterns
// Test fixture for avoid_dynamic_code_loading and
// avoid_unverified_native_library rules (OWASP M2)

import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

// =============================================================================
// avoid_dynamic_code_loading
// =============================================================================

Future<void> testDynamicIsolateSpawn(String userUrl) async {
  // BAD: Loading code from any URI via spawnUri
  // expect_lint: avoid_dynamic_code_loading
  await Isolate.spawnUri(Uri.parse(userUrl), <String>[], null);

  // BAD: Even static URIs are flagged (spawnUri inherently loads external code)
  // expect_lint: avoid_dynamic_code_loading
  await Isolate.spawnUri(
    Uri.parse('package:myapp/worker.dart'),
    <String>[],
    null,
  );
}

Future<void> testPackageManagementCommands() async {
  // BAD: Running package management at runtime
  // expect_lint: avoid_dynamic_code_loading
  await Process.run('pub', <String>['get']);

  // expect_lint: avoid_dynamic_code_loading
  await Process.run('flutter', <String>['pub', 'add', 'some_package']);

  // expect_lint: avoid_dynamic_code_loading
  await Process.run('dart', <String>['pub', 'get']);

  // expect_lint: avoid_dynamic_code_loading
  await Process.run('npm', <String>['install']);

  // expect_lint: avoid_dynamic_code_loading
  await Process.start('yarn', <String>['add', 'some_package']);
}

// GOOD: Isolate.run for compute-heavy tasks (should NOT trigger)
Future<int> testIsolateRun() async {
  return await Isolate.run(() => 42);
}

// GOOD: Non-package-management commands (should NOT trigger)
Future<void> testNonPackageProcessRun() async {
  await Process.run('ls', <String>['-la']);
  await Process.run('git', <String>['status']);
  await Process.run('echo', <String>['hello']);
}

// =============================================================================
// avoid_unverified_native_library
// =============================================================================

void testDynamicLibraryPath(String libraryPath) {
  // BAD: Dynamic library path (variable)
  // expect_lint: avoid_unverified_native_library
  DynamicLibrary.open(libraryPath);
}

void testAbsolutePath() {
  // BAD: Absolute path
  // expect_lint: avoid_unverified_native_library
  DynamicLibrary.open('/usr/lib/libcrypto.so');
}

void testRelativePathWithDirectory() {
  // BAD: Relative path with directory traversal
  // expect_lint: avoid_unverified_native_library
  DynamicLibrary.open('../libs/libfoo.dylib');
}

void testWindowsPath() {
  // BAD: Windows absolute path
  // cspell:disable-next-line
  // expect_lint: avoid_unverified_native_library
  DynamicLibrary.open(r'C:\Windows\System32\library.dll');
}

// GOOD: Bundled library name only (should NOT trigger)
void testBundledLibrary() {
  DynamicLibrary.open('libfoo.dylib');
  DynamicLibrary.open('libbar.so');
  DynamicLibrary.open('library.dll');
}
