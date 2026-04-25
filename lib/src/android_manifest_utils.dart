import 'dart:io';

import 'package:saropa_lints/src/string_slice_utils.dart';

/// Small cached reader for AndroidManifest.xml checks used by lint rules.
///
/// The analyzer visits many files; this avoids repeated manifest I/O for the
/// same project root while keeping the logic local to this package.
class AndroidManifestChecker {
  AndroidManifestChecker._(this._manifestContent);

  final String? _manifestContent;

  static final Map<String, AndroidManifestChecker> _cache = {};

  /// Creates a checker for the project containing [filePath].
  static AndroidManifestChecker? forFile(String filePath) {
    final projectRoot = _findProjectRoot(filePath);
    if (projectRoot == null) return null;

    final cached = _cache[projectRoot];
    if (cached != null) return cached;

    final candidates = <String>[
      '$projectRoot/android/app/src/main/AndroidManifest.xml',
      '$projectRoot/android/AndroidManifest.xml',
    ];

    String? content;
    for (final path in candidates) {
      final file = File(path);
      if (file.existsSync()) {
        content = file.readAsStringSync();
        break;
      }
    }

    final checker = AndroidManifestChecker._(content);
    _cache[projectRoot] = checker;
    return checker;
  }

  /// Returns true when any candidate path has a manifest file.
  bool get hasManifest => _manifestContent != null;

  /// True when a uses-permission entry includes [permissionName].
  bool hasPermission(String permissionName) {
    final content = _manifestContent;
    if (content == null) return false;
    return content.contains('android.permission.$permissionName');
  }

  /// Raw substring search in manifest XML (foreground services, metadata, etc.).
  bool containsRaw(String needle) {
    final content = _manifestContent;
    if (content == null) return false;
    return content.contains(needle);
  }

  static String? _findProjectRoot(String filePath) {
    var current = filePath.replaceAll('\\', '/');
    while (current.contains('/')) {
      final lastSlash = current.lastIndexOf('/');
      if (lastSlash <= 0) break;
      current = current.prefix(lastSlash);
      if (File('$current/pubspec.yaml').existsSync()) {
        return current;
      }
    }
    return null;
  }
}
