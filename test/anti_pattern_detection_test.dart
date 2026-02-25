import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// CI guard test that prevents new `.contains()` anti-patterns in rule files.
///
/// The `.contains()` anti-pattern on identifier names, method names, type
/// names, and `.toSource()` results is the #1 source of false positives
/// across saropa_lints rules. This test scans all rule files and fails if
/// new violations are introduced beyond the grandfathered baseline.
///
/// See: bugs/string_contains_false_positive_audit.md
void main() {
  group('Anti-pattern detection', () {
    test('no new .contains() anti-patterns in rule files', () {
      final rulesDir = Directory(p.join('lib', 'src', 'rules'));
      expect(rulesDir.existsSync(), isTrue, reason: 'rules dir must exist');

      final ruleFiles = rulesDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();

      expect(ruleFiles, isNotEmpty, reason: 'must find rule .dart files');

      final violations = <String, int>{};
      final staleBaselines = <String>[];

      for (final file in ruleFiles) {
        final relativePath = _relativize(file.path);
        final lines = file.readAsLinesSync();
        var count = 0;

        for (var i = 0; i < lines.length; i++) {
          if (_isDangerousContains(lines[i])) {
            count++;
          }
        }

        if (count > 0) {
          violations[relativePath] = count;
        }

        // Check for stale baseline entries
        final baseline = _baselineCounts[relativePath];
        if (baseline != null && count == 0) {
          staleBaselines.add(relativePath);
        }
      }

      // Check for new violations beyond baseline
      final newViolations = <String>[];
      for (final entry in violations.entries) {
        final baseline = _baselineCounts[entry.key];
        if (baseline == null) {
          newViolations.add(
            '${entry.key}: ${entry.value} NEW violations '
            '(file not in baseline)',
          );
        } else if (entry.value > baseline) {
          newViolations.add(
            '${entry.key}: ${entry.value} violations '
            '(baseline: $baseline, +${entry.value - baseline} new)',
          );
        }
      }

      if (newViolations.isNotEmpty) {
        fail(
          'New .contains() anti-patterns detected!\n'
          'These cause false positives in lint rules.\n'
          'Use exact-match sets, startsWith/endsWith, or '
          'target_matcher_utils.dart instead.\n\n'
          '${newViolations.join('\n')}\n\n'
          'If this is intentional, update _baselineCounts in '
          'test/anti_pattern_detection_test.dart.',
        );
      }

      // Report improvements (baseline reductions)
      final improvements = <String>[];
      for (final entry in _baselineCounts.entries) {
        final actual = violations[entry.key] ?? 0;
        if (actual < entry.value && actual > 0) {
          improvements.add(
            '  ${entry.key}: ${entry.value} -> $actual '
            '(reduced by ${entry.value - actual})',
          );
        }
      }

      if (improvements.isNotEmpty || staleBaselines.isNotEmpty) {
        // ignore: avoid_print
        print(
          '\nBaseline can be tightened:\n'
          '${improvements.join('\n')}'
          '${staleBaselines.map((f) => '  $f: can be removed').join('\n')}',
        );
      }
    });

    test('baseline entries are not stale', () {
      final rulesDir = Directory(p.join('lib', 'src', 'rules'));
      final ruleFiles = rulesDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();

      final actualFiles = ruleFiles.map((f) => _relativize(f.path)).toSet();

      final staleEntries = _baselineCounts.keys
          .where((key) => !actualFiles.contains(key))
          .toList();

      if (staleEntries.isNotEmpty) {
        fail(
          'Stale baseline entries (files no longer exist):\n'
          '${staleEntries.join('\n')}\n\n'
          'Remove these from _baselineCounts.',
        );
      }
    });
  });
}

/// Detects dangerous `.contains()` patterns in a single line of code.
///
/// Returns true if the line contains a pattern known to cause false
/// positives when used in lint rule detection logic.
bool _isDangerousContains(String line) {
  final trimmed = line.trim();

  // Skip comments
  if (trimmed.startsWith('//') || trimmed.startsWith('*')) return false;

  // Skip lines that are clearly not detection logic
  if (trimmed.startsWith('import ') || trimmed.startsWith('export ')) {
    return false;
  }

  // Patterns that cause false positives in lint rules:
  // 1. Substring matching on identifier/type/method names
  // 2. String searching in function body source
  // 3. String interpolation in .contains() calls
  return _dangerousPatterns.any((pattern) => pattern.hasMatch(trimmed));
}

/// Regex patterns for dangerous `.contains()` usage.
final List<RegExp> _dangerousPatterns = [
  // methodName.contains( — substring match on method names
  RegExp(r'methodName\.contains\('),
  // targetSource.contains( — substring match on target expressions
  RegExp(r'targetSource\.contains\('),
  // typeName.contains( — substring match on type names
  RegExp(r'typeName\.contains\('),
  // bodySource.contains( — string searching in function bodies
  RegExp(r'bodySource\.contains\('),
  // .toSource().contains( — string searching in AST source
  RegExp(r'\.toSource\(\)\.contains\('),
  // fieldType.contains( — substring match on field types
  RegExp(r'fieldType\.contains\('),
  // disposeBody.contains( — string searching in dispose body
  RegExp(r'disposeBody\.contains\('),
  // createSource.contains( — substring match on creation source
  RegExp(r'createSource\.contains\('),
  // source.contains( — generic source text searching
  // (only when 'source' is clearly AST source, not a different variable)
  RegExp(r'\bsource\.contains\('),
];

/// Normalizes a file path to a forward-slash relative path from the project
/// root for consistent cross-platform comparison.
String _relativize(String path) {
  // Normalize separators
  var normalized = path.replaceAll(r'\', '/');

  // Strip everything up to and including lib/src/rules/
  final marker = 'lib/src/rules/';
  final idx = normalized.indexOf(marker);
  if (idx >= 0) {
    normalized = normalized.substring(idx + marker.length);
  }

  return normalized;
}

/// Baseline violation counts per file.
///
/// Each entry records the known number of `.contains()` anti-pattern
/// instances in a rule file as of the last audit. The CI test fails if
/// any file exceeds its baseline count (new violations introduced).
///
/// When you fix violations in a file, reduce the count here.
/// When a file reaches 0, remove it from this map entirely.
///
/// Baseline established: 2026-02-08
const Map<String, int> _baselineCounts = {
  // Core rule files
  'accessibility_rules.dart': 11,
  'animation_rules.dart': 10,
  'api_network_rules.dart': 143,
  'async_rules.dart': 59,
  'disposal_rules.dart': 29,
  'security_rules.dart': 74,
  'navigation_rules.dart': 52,
  'file_handling_rules.dart': 29,
  'widget_lifecycle_rules.dart': 18,
  'permission_rules.dart': 23,

  // Platform rule files
  'platforms/ios_rules.dart': 29,
  'platforms/macos_rules.dart': 13,
  'platforms/android_rules.dart': 16,
  'platforms/web_rules.dart': 5,
  'platforms/linux_rules.dart': 2,
  'platforms/windows_rules.dart': 13,

  // Package rule files
  'packages/firebase_rules.dart': 37,
  'packages/riverpod_rules.dart': 28,
  'packages/bloc_rules.dart': 16,
  'packages/hive_rules.dart': 12,
  'packages/getx_rules.dart': 5,
  'packages/shared_preferences_rules.dart': 14,
  'packages/dio_rules.dart': 6,
  'packages/provider_rules.dart': 3,
  'packages/isar_rules.dart': 7,
  'packages/supabase_rules.dart': 8,
  'packages/workmanager_rules.dart': 5,
  'packages/url_launcher_rules.dart': 17,
  'packages/package_specific_rules.dart': 19,
  'packages/get_it_rules.dart': 9,
  'packages/sqflite_rules.dart': 4,
  'packages/qr_scanner_rules.dart': 1,
  'packages/equatable_rules.dart': 2,
  'packages/flutter_hooks_rules.dart': 1,
  'packages/geolocator_rules.dart': 5,
  'packages/drift_rules.dart': 14,

  // Widget and UI rule files
  'build_method_rules.dart': 5,
  'forms_rules.dart': 20,
  'widget_layout_rules.dart': 10,
  'widget_patterns_rules.dart': 3,
  'scroll_rules.dart': 11,
  'ui_ux_rules.dart': 4,

  // Other rule files
  'test_rules.dart': 41,
  'testing_best_practices_rules.dart': 37,
  'performance_rules.dart': 25,
  'error_handling_rules.dart': 15,
  'state_management_rules.dart': 4,
  'resource_management_rules.dart': 24,
  'collection_rules.dart': 5,
  'image_rules.dart': 21,
  'internationalization_rules.dart': 8,
  'documentation_rules.dart': 6,
  'lifecycle_rules.dart': 3,
  'notification_rules.dart': 5,
  'media_rules.dart': 1,
  'memory_management_rules.dart': 5,
  'crypto_rules.dart': 2,
  'dependency_injection_rules.dart': 12,
  'bluetooth_hardware_rules.dart': 6,
  'exception_rules.dart': 1,
  'type_safety_rules.dart': 6,
  'json_datetime_rules.dart': 12,
  'dialog_snackbar_rules.dart': 2,
  'complexity_rules.dart': 1,
  'debug_rules.dart': 5,
  'stylistic_error_testing_rules.dart': 12,
  'iap_rules.dart': 22,
  'architecture_rules.dart': 2,
  'migration_rules.dart': 1,
};
