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
  BaselineFile({
    required this.violations,
    DateTime? generated,
  }) : generated = generated ?? DateTime.now();

  /// Current baseline file format version.
  static const int currentVersion = 1;

  /// When this baseline was generated.
  final DateTime generated;

  /// Map of file path -> rule name -> list of line numbers.
  final Map<String, Map<String, List<int>>> violations;

  /// Loads a baseline file from the given path.
  ///
  /// Returns null if the file doesn't exist or is invalid.
  static BaselineFile? load(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      return null;
    }

    try {
      final content = file.readAsStringSync();
      final json = jsonDecode(content) as Map<String, dynamic>;
      return BaselineFile.fromJson(json);
    } catch (e) {
      // Invalid JSON or format - return null
      return null;
    }
  }

  /// Creates a [BaselineFile] from parsed JSON.
  factory BaselineFile.fromJson(Map<String, dynamic> json) {
    final version = json['version'] as int? ?? 1;
    if (version > currentVersion) {
      throw FormatException(
        'Baseline file version $version is newer than supported version $currentVersion',
      );
    }

    final generatedStr = json['generated'] as String?;
    final generated = generatedStr != null
        ? DateTime.tryParse(generatedStr)
        : DateTime.now();

    final violationsRaw = json['violations'] as Map<String, dynamic>? ?? {};
    final violations = <String, Map<String, List<int>>>{};

    for (final entry in violationsRaw.entries) {
      final filePath = entry.key;
      final rulesRaw = entry.value as Map<String, dynamic>? ?? {};
      final rules = <String, List<int>>{};

      for (final ruleEntry in rulesRaw.entries) {
        final ruleName = ruleEntry.key;
        final linesRaw = ruleEntry.value as List<dynamic>? ?? [];
        final lines = linesRaw.whereType<int>().toList();
        if (lines.isNotEmpty) {
          rules[ruleName] = lines;
        }
      }

      if (rules.isNotEmpty) {
        violations[filePath] = rules;
      }
    }

    return BaselineFile(
      violations: violations,
      generated: generated,
    );
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
  void save(String path) {
    final file = File(path);
    final encoder = const JsonEncoder.withIndent('  ');
    file.writeAsStringSync(encoder.convert(toJson()));
  }

  /// Checks if a specific violation is baselined.
  ///
  /// [filePath] should be normalized (forward slashes).
  bool isBaselined(String filePath, String ruleName, int line) {
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
