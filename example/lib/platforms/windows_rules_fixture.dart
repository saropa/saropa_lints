// ignore_for_file: unused_local_variable, unused_element, avoid_print

import 'dart:io';

// =============================================================================
// avoid_hardcoded_drive_letters
// =============================================================================

/// BAD: Hardcoded Windows drive letter paths
void badDriveLetters() {
  // expect_lint: avoid_hardcoded_drive_letters
  final config = File('C:\\Users\\me\\AppData\\myapp\\config.json');

  // expect_lint: avoid_hardcoded_drive_letters
  final program = Directory('C:\\Program Files\\MyApp');

  // expect_lint: avoid_hardcoded_drive_letters
  final temp = File('D:\\temp\\cache.dat');

  // expect_lint: avoid_hardcoded_drive_letters
  final data = File('E:/backup/data.db');
}

/// GOOD: Dynamic paths
Future<void> goodDynamicPaths() async {
  final appData = Platform.environment['APPDATA'];
  final config = File('$appData\\myapp\\config.json');

  final appDir = await getApplicationSupportDirectory();
  final data = File('${appDir.path}\\data.db');
}

// =============================================================================
// avoid_forward_slash_path_assumption
// =============================================================================

/// BAD: Path concatenation with '/'
void badForwardSlashPaths() {
  final dir = '/some/directory';
  final file = 'data.txt';

  // expect_lint: avoid_forward_slash_path_assumption
  final filePath = dir + '/' + file;

  final basePath = '/base';
  final subDir = 'sub';

  // expect_lint: avoid_forward_slash_path_assumption
  final nested = '$basePath/$subDir';
}

/// GOOD: Using path.join
void goodPathJoin() {
  final dir = '/some/directory';
  final file = 'data.txt';
  final filePath = join(dir, file);
}

// =============================================================================
// avoid_case_sensitive_path_comparison
// =============================================================================

/// BAD: Case-sensitive path comparison
void badCaseSensitiveComparison() {
  final filePath = 'C:\\Users\\Me\\Documents\\file.txt';
  final expectedPath = 'C:\\Users\\me\\documents\\file.txt';

  // expect_lint: avoid_case_sensitive_path_comparison
  if (filePath == expectedPath) {
    print('Same file');
  }

  final dirPath = 'C:\\Program Files';
  final otherDirPath = 'c:\\program files';

  // expect_lint: avoid_case_sensitive_path_comparison
  if (dirPath != otherDirPath) {
    print('Different paths');
  }
}

/// GOOD: Case-insensitive comparison
void goodCaseInsensitiveComparison() {
  final filePath = 'C:\\Users\\Me\\Documents\\file.txt';
  final expectedPath = 'C:\\Users\\me\\documents\\file.txt';

  if (filePath.toLowerCase() == expectedPath.toLowerCase()) {
    print('Same file');
  }
}

// =============================================================================
// require_windows_single_instance_check
// =============================================================================

// NOTE: This rule fires on function declarations named 'main' that contain
// Platform.isWindows but lack single-instance handling. Because only one
// top-level `main` is allowed per file, these examples use comments to
// describe the expected behavior rather than `expect_lint`.

/// BAD pattern (cannot use expect_lint — only one main per file):
/// ```dart
/// void main() {
///   if (Platform.isWindows) { /* no single instance check */ }
///   runApp('MyApp');
/// }
/// ```

/// GOOD: Windows main with single instance check
void main() {
  if (Platform.isWindows) {
    // ensureSingleInstance suppresses the lint
  }
  runApp('MyApp');
}

// =============================================================================
// avoid_max_path_risk
// =============================================================================

/// BAD: Deeply nested paths
void badDeepPaths() {
  // expect_lint: avoid_max_path_risk
  final deep = p.join(
    'base',
    'company',
    'product',
    'version',
    'module',
    'feature',
    'data.json',
  );

  // expect_lint: avoid_max_path_risk
  final literal =
      'C:\\Users\\username\\AppData\\Local\\MyCompany\\MyApp\\data\\cache\\images\\file.png';
}

/// GOOD: Flat paths
void goodFlatPaths() {
  final flat = p.join('base', 'cache', 'data.json');
  final short = 'C:\\MyApp\\cache\\file.png';
}

// =============================================================================
// Mock types for compilation
// =============================================================================

Future<Directory> getApplicationSupportDirectory() async => Directory('.');
void runApp(String app) {}

/// Mock path package to provide a target for method invocation detection.
class _Path {
  String join(String a,
          [String? b, String? c, String? d, String? e, String? f, String? g]) =>
      '$a\\$b';
}

final p = _Path();
