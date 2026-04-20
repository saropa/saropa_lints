/// Path-based baseline for ignoring violations in specific directories.
///
/// Supports glob patterns:
/// - `lib/legacy/` - matches all files under lib/legacy/
/// - `**/generated/` - matches generated/ at any depth
/// - `*.g.dart` - matches files ending in .g.dart
/// - `lib/**/old_*.dart` - matches old_*.dart files under lib/
///
/// ## Usage
///
/// ```yaml
/// plugins:
///   saropa_lints:
///     diagnostics:
///       # ... rule overrides ...
///
///     baseline:
///       paths:
///         - "lib/legacy/"
///         - "lib/deprecated/"
///         - "**/generated/"
///         - "*.g.dart"
/// ```
library;

import 'dart:developer' as developer;
import 'package:saropa_lints/src/string_slice_utils.dart';

class BaselinePaths {
  BaselinePaths(List<String>? patterns)
    : _patterns = _compilePatterns(patterns ?? const []);

  final List<_CompiledPattern> _patterns;

  /// Check if a file path matches any of the baseline patterns.
  ///
  /// [filePath] should be the full or relative path to the file.
  /// Returns false if [filePath] is null or empty.
  bool matches(String? filePath) {
    if (filePath == null || filePath.isEmpty) return false;
    if (_patterns.isEmpty) return false;

    final normalized = _normalizePath(filePath);

    for (final pattern in _patterns) {
      if (pattern.matches(normalized)) {
        return true;
      }
    }

    return false;
  }

  /// Compile glob patterns into regex patterns for efficient matching.
  /// Skips null/empty entries; invalid patterns are wrapped in try/catch per pattern.
  static List<_CompiledPattern> _compilePatterns(List<String> patterns) {
    final result = <_CompiledPattern>[];
    for (final p in patterns) {
      if (p.trim().isEmpty) continue;
      try {
        result.add(_CompiledPattern(p));
      } catch (e, st) {
        developer.log(
          '_compilePatterns: skip malformed pattern',
          name: 'saropa_lints',
          error: e,
          stackTrace: st,
        );
        // Skip malformed pattern
      }
    }
    return result;
  }

  /// Normalize a file path for consistent matching.
  static String _normalizePath(String path) {
    // Convert backslashes to forward slashes
    var normalized = path.replaceAll('\\', '/');

    // Remove leading ./ if present
    if (normalized.startsWith('./')) {
      normalized = normalized.afterIndex(2);
    }

    // Remove leading / if present (for absolute paths)
    if (normalized.startsWith('/')) {
      normalized = normalized.afterIndex(1);
    }

    return normalized;
  }

  /// Number of patterns configured.
  int get patternCount => _patterns.length;

  /// Whether any patterns are configured.
  bool get hasPatterns => _patterns.isNotEmpty;

  @override
  String toString() => 'BaselinePaths($_patterns)';
}

/// A compiled glob pattern for efficient matching.
class _CompiledPattern {
  _CompiledPattern(this.original) : _regex = _compileGlob(original);

  final String original;
  final RegExp _regex;

  /// Check if a normalized path matches this pattern.
  bool matches(String normalizedPath) {
    return _regex.hasMatch(normalizedPath);
  }

  /// Compile a glob pattern to a regex.
  ///
  /// Supports:
  /// - `*` - matches any characters except /
  /// - `**` - matches any characters including /
  /// - `?` - matches any single character
  /// - Directory patterns (ending with /) - match all files under
  static RegExp _compileGlob(String pattern) {
    var glob = pattern.replaceAll('\\', '/');

    // Remove trailing slash but remember it was a directory pattern
    final isDirectoryPattern = glob.endsWith('/');
    if (isDirectoryPattern) {
      glob = glob.prefix(glob.length - 1);
    }

    // Escape regex special characters (except * and ?)
    glob = glob
        .replaceAll('.', r'\.')
        .replaceAll('(', r'\(')
        .replaceAll(')', r'\)')
        .replaceAll('[', r'\[')
        .replaceAll(']', r'\]')
        .replaceAll('{', r'\{')
        .replaceAll('}', r'\}')
        .replaceAll('+', r'\+')
        .replaceAll('^', r'\^')
        .replaceAll(r'$', r'\$')
        .replaceAll('|', r'\|');

    // Handle ** (match any path segment including /)
    // Must be done before single * handling
    glob = glob.replaceAll('**', '\x00DOUBLE_STAR\x00');

    // Handle * (match any characters except /)
    glob = glob.replaceAll('*', r'[^/]*');

    // Handle ? (match any single character)
    glob = glob.replaceAll('?', '.');

    // Restore ** as .* (match anything)
    glob = glob.replaceAll('\x00DOUBLE_STAR\x00', '.*');

    // For directory patterns, match anything under that directory
    if (isDirectoryPattern) {
      glob = '$glob(/.*)?';
    }

    // Anchor the pattern
    return RegExp('^$glob\$', caseSensitive: false);
  }

  @override
  String toString() => 'Pattern($original)';
}
