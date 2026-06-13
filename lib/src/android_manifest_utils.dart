import 'dart:io';

import 'package:saropa_lints/src/string_slice_utils.dart';

/// Small cached reader for AndroidManifest.xml checks used by lint rules.
///
/// The analyzer visits many files; this avoids repeated manifest I/O for the
/// same project root while keeping the logic local to this package.
class AndroidManifestChecker {
  AndroidManifestChecker._(
    this._manifestContent,
    this._manifestPath,
    this._mtime,
    this._size,
  );

  final String? _manifestContent;
  final String? _manifestPath;
  final DateTime? _mtime;
  final int? _size;

  static final Map<String, AndroidManifestChecker> _cache = {};

  /// Creates a checker for the project containing [filePath].
  static AndroidManifestChecker? forFile(String filePath) {
    final projectRoot = _findProjectRoot(filePath);
    if (projectRoot == null) return null;

    final candidates = <String>[
      '$projectRoot/android/app/src/main/AndroidManifest.xml',
      '$projectRoot/android/AndroidManifest.xml',
    ];

    // Resolve the first existing manifest and capture its mtime+size. The cache
    // is keyed on these so manifest edits (a new permission, a foreground
    // service) are picked up within a long-lived analysis-server session — the
    // previous unconditional cache returned stale results until restart. This
    // mirrors InfoPlistChecker's invalidation.
    String? manifestPath;
    DateTime? currentMtime;
    int? currentSize;
    for (final path in candidates) {
      try {
        final file = File(path);
        if (file.existsSync()) {
          final st = file.statSync();
          manifestPath = path;
          currentMtime = st.modified;
          currentSize = st.size;
          break;
        }
      } on FileSystemException {
        // Try the next candidate; a transient stat failure must not pin a
        // stale entry.
      }
    }

    final cached = _cache[projectRoot];
    if (cached != null &&
        cached._manifestPath == manifestPath &&
        cached._mtime == currentMtime &&
        cached._size == currentSize) {
      return cached;
    }

    String? content;
    DateTime? storedMtime = currentMtime;
    int? storedSize = currentSize;
    if (manifestPath != null) {
      try {
        content = File(manifestPath).readAsStringSync();
      } on FileSystemException {
        content = null;
        // Do not pin mtime/size on a transient read failure: retry next time.
        storedMtime = null;
        storedSize = null;
      }
    }

    final checker = AndroidManifestChecker._(
      content,
      manifestPath,
      storedMtime,
      storedSize,
    );
    _cache[projectRoot] = checker;
    return checker;
  }

  /// Returns true when any candidate path has a manifest file.
  bool get hasManifest => _manifestContent != null;

  /// True when a uses-permission entry includes [permissionName].
  bool hasPermission(String permissionName) {
    final content = _manifestContent;
    if (content == null) return false;
    // Boundary-anchored: a bare `contains('android.permission.READ_CONTACTS')`
    // also matched `READ_CONTACTS_EXTENDED` (and any longer permission sharing
    // the prefix). The negative lookahead requires the name to end at a
    // non-identifier char (the closing quote in `android:name="..."`).
    final pattern = RegExp(
      'android\\.permission\\.${RegExp.escape(permissionName)}'
      r'(?![A-Za-z0-9_])',
    );
    return pattern.hasMatch(content);
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

  /// Clears the per-project-root cache (for tests).
  static void clearCache() {
    _cache.clear();
  }
}
