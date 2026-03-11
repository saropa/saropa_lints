import 'dart:convert';
import 'dart:io';

/// Handles reading and writing baseline JSON files.
///
/// File format:
/// ```json
/// {
///   "version": 1,
///   "generated": "2025-01-15T10:30:00Z",
///   "violations": {
///     "lib/old.dart": {
///       "avoid_print": [42, 87],
///       "no_empty_block": [15]
///     }
///   }
/// }
/// ```
class BaselineFile {
  BaselineFile({required this.violations, DateTime? generated})
      : generated = generated ?? DateTime.now();

  /// Current baseline file format version.
  static const int currentVersion = 1;

  /// When this baseline was generated.
  final DateTime generated;

  /// Map of file path -> rule name -> list of line numbers.
  final Map<String, Map<String, List<int>>> violations;

  /// Loads a baseline file from the given path.
  ///
  /// Returns null if the file doesn't exist, path is null/empty, or content is invalid.
  static BaselineFile? load(String? path) {
    if (path == null || path.trim().isEmpty) return null;

    try {
      final file = File(path);
      if (!file.existsSync()) {
        return null;
      }

      final content = file.readAsStringSync();
      if (content.isEmpty) return null;

      final decoded = jsonDecode(content);
      if (decoded is! Map<String, dynamic>) return null;

      return BaselineFile.fromJson(decoded);
    } on FormatException {
      return null;
    } on IOException {
      return null;
    }
  }

  /// Creates a [BaselineFile] from parsed JSON.
  ///
  /// Never throws; invalid or unknown-version data yields a safe default.
  factory BaselineFile.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return BaselineFile(violations: {}, generated: DateTime.now());
    }

    final v = json['version'];
    final version = v is int ? v : 1;
    if (version > currentVersion) {
      // Unknown version: return empty baseline instead of throwing
      return BaselineFile(violations: {}, generated: DateTime.now());
    }

    final g = json['generated'];
    final generatedStr = g is String ? g : null;
    final generated = generatedStr != null && generatedStr.trim().isNotEmpty
        ? (DateTime.tryParse(generatedStr) ?? DateTime.now())
        : DateTime.now();

    final violationsRaw = json['violations'];
    final violations = <String, Map<String, List<int>>>{};

    if (violationsRaw is Map<String, dynamic>) {
      for (final entry in violationsRaw.entries) {
        final filePath = entry.key.trim();
        if (filePath.isEmpty) continue;

        final rulesRaw = entry.value;
        if (rulesRaw is! Map<String, dynamic>) continue;

        final rules = <String, List<int>>{};
        for (final ruleEntry in rulesRaw.entries) {
          final ruleName = ruleEntry.key.trim();
          if (ruleName.isEmpty) continue;

          final linesRaw = ruleEntry.value;
          if (linesRaw is! List) continue;

          final lines = linesRaw.whereType<int>().where((l) => l >= 1).toList();
          if (lines.isNotEmpty) {
            rules[ruleName] = lines;
          }
        }

        if (rules.isNotEmpty) {
          violations[filePath] = rules;
        }
      }
    }

    return BaselineFile(violations: violations, generated: generated);
  }

  /// Converts this baseline to JSON format.
  Map<String, dynamic> toJson() {
    return {
      'version': currentVersion,
      'generated': generated.toUtc().toIso8601String(),
      'violations': violations,
    };
  }

  /// Saves this baseline to the given path.
  /// No-op if [path] is null or empty. Swallows IO errors (defensive).
  void save(String? path) {
    if (path == null || path.trim().isEmpty) return;
    try {
      final file = File(path);
      final encoder = const JsonEncoder.withIndent('  ');
      file.writeAsStringSync(encoder.convert(toJson()));
    } on IOException catch (e) {
      // Best-effort write; log and continue so caller is not forced to handle.
      // Use stderr instead of print() — errors belong on stderr, not stdout.
      stderr.writeln('Baseline save failed: $e');
    }
  }

  /// Checks if a specific violation is baselined.
  ///
  /// [filePath] should be normalized (forward slashes).
  /// Returns false if [filePath], [ruleName] are null/empty or [line] < 1.
  bool isBaselined(String? filePath, String? ruleName, int line) {
    if (filePath == null || filePath.isEmpty) return false;
    if (ruleName == null || ruleName.isEmpty) return false;
    if (line < 1) return false;

    // Normalize the file path for lookup
    final normalized = _normalizePath(filePath);

    // Try exact match first
    final rules = violations[normalized];
    if (rules != null) {
      final lines = rules[ruleName];
      if (lines != null && lines.contains(line)) {
        return true;
      }
    }

    // Try with different path variations
    for (final entry in violations.entries) {
      if (_pathsMatch(entry.key, normalized)) {
        final lines = entry.value[ruleName];
        if (lines != null && lines.contains(line)) {
          return true;
        }
      }
    }

    return false;
  }

  /// Normalizes a file path for consistent lookup.
  String _normalizePath(String path) {
    // Convert backslashes to forward slashes
    var normalized = path.replaceAll('\\', '/');

    // Remove leading ./ if present
    if (normalized.startsWith('./')) {
      normalized = normalized.substring(2);
    }

    return normalized;
  }

  /// Checks if two paths refer to the same file.
  bool _pathsMatch(String a, String b) {
    final normA = _normalizePath(a);
    final normB = _normalizePath(b);

    // Exact match
    if (normA == normB) return true;

    // Check if one ends with the other (handles relative vs absolute paths)
    if (normA.endsWith(normB) || normB.endsWith(normA)) return true;

    return false;
  }

  /// Total number of baselined violations.
  int get totalViolations {
    var count = 0;
    for (final rules in violations.values) {
      for (final lines in rules.values) {
        count += lines.length;
      }
    }
    return count;
  }

  /// Number of files with baselined violations.
  int get fileCount => violations.length;

  /// Set of all rules that have baselined violations.
  Set<String> get rules {
    final result = <String>{};
    for (final rules in violations.values) {
      result.addAll(rules.keys);
    }
    return result;
  }

  @override
  String toString() => 'BaselineFile('
      'violations: $totalViolations in $fileCount files, '
      'generated: $generated)';
}
