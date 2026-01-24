// ignore_for_file: unused_local_variable, unused_element

import 'dart:io';

/// BAD: User input (parameters) used in file path without sanitization

/// Path traversal vulnerability - user can pass '../../../etc/passwd'
Future<File> badUserPath(String userPath) async {
  // expect_lint: avoid_path_traversal
  return File('/data/$userPath');
}

/// Path traversal vulnerability in Directory
Future<Directory> badUserDirectory(String dirName) async {
  // expect_lint: avoid_path_traversal
  return Directory('/storage/$dirName');
}

/// Path traversal vulnerability with concatenation
Future<File> badConcatenation(String filename) async {
  // expect_lint: avoid_path_traversal
  return File('/data/' + filename);
}

/// GOOD: Trusted sources (should NOT trigger)

/// Using path_provider - trusted system API
Future<File> goodPathProvider() async {
  final dir = await getApplicationDocumentsDirectory();
  return File('${dir.path}/app_data.json');
}

/// Using private constant subdirectory
class WidgetPathUtils {
  static const String _imageSubdirectory = 'widget_images';
  static String? _cachedContainerPath;

  Future<Directory> getImageDirectory() async {
    return Directory('$_cachedContainerPath/$_imageSubdirectory');
  }

  Future<Directory> getAppImageDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    return Directory('${appDir.path}/$_imageSubdirectory');
  }
}

/// Using MethodChannel to get system path - trusted source
Future<Directory> goodMethodChannelPath() async {
  final containerPath = await _getContainerPath();
  return Directory('$containerPath/images');
}

Future<String> _getContainerPath() async {
  return '/app/container';
}

/// GOOD: User input WITH proper sanitization

/// Sanitized user input - has basename check
Future<File> goodSanitizedBasename(String userPath) async {
  final sanitized = basename(userPath);
  return File('/data/$sanitized');
}

/// Sanitized user input - has startsWith validation
Future<File> goodSanitizedStartsWith(String userPath) async {
  final file = File('/data/$userPath');
  if (!file.path.startsWith('/data/')) {
    throw SecurityException('Invalid path');
  }
  return file;
}

/// Sanitized user input - has traversal check with throw
Future<File> goodDotDotCheck(String userPath) async {
  if (userPath.contains('..')) {
    throw SecurityException('Path traversal detected');
  }
  return File('/data/$userPath');
}

/// Sanitized user input - uses path.normalize
Future<File> goodNormalize(String userPath) async {
  final normalized = normalize(userPath);
  return File('/data/$normalized');
}

/// Sanitized user input - uses isWithin check
Future<File> goodIsWithin(String userPath) async {
  final file = File('/data/$userPath');
  if (!isWithin('/data', file.path)) {
    throw SecurityException('Invalid path');
  }
  return file;
}

class Directory {
  final String path;
  Directory(this.path);
}

class File {
  final String path;
  File(this.path);
}

Future<Directory> getApplicationDocumentsDirectory() async {
  return Directory('/app/documents');
}

String basename(String path) => path.split('/').last;
String normalize(String path) => path.replaceAll('..', '');
bool isWithin(String parent, String child) => child.startsWith(parent);

class SecurityException implements Exception {
  final String message;
  SecurityException(this.message);
}
