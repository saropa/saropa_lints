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

    test('security_rules and disposal_rules have zero dangerous .contains()',
        () {
      final rulesDir = Directory(p.join('lib', 'src', 'rules'));
      final files = [
        p.join('security', 'security_auth_storage_rules.dart'),
        p.join('security', 'security_network_input_rules.dart'),
        p.join('architecture', 'disposal_rules.dart'),
      ];
      for (final name in files) {
        final file = File(p.join(rulesDir.path, name));
        expect(file.existsSync(), isTrue);
        final lines = file.readAsLinesSync();
        final count = lines.where((line) => _isDangerousContains(line)).length;
        expect(
          count,
          0,
          reason: '$name must have zero dangerous .contains() (false-positive '
              'reduction). If you reintroduced one, use word-boundary RegExp or '
              'target_matcher_utils instead.',
        );
      }
    });

    test(
      'dangerous pattern count matches audit (Dart and publish script in sync)',
      () {
        expect(
          _dangerousPatterns.length,
          9,
          reason:
              'Publish script scripts/modules/_audit_checks.py uses the same '
              '9 patterns. Update both if adding or removing a pattern.',
        );
      },
    );
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
///
/// Files reduced to 0 and removed from baseline (no regression allowed):
/// - security_rules.dart (2026-03-01)
/// - disposal_rules.dart (2026-03-01)
/// - test_rules.dart (2026-03-01)
/// - testing_best_practices_rules.dart (2026-03-01)
/// - packages/firebase_rules.dart (2026-03-01)
/// - platforms/ios_rules.dart (2026-03-01)
/// - packages/riverpod_rules.dart (2026-03-01)
/// - performance_rules.dart (2026-03-01)
/// - resource_management_rules.dart (2026-03-01)
/// - image_rules.dart (2026-03-01)
/// - forms_rules.dart (2026-03-01)
/// - iap_rules.dart (2026-03-01)
/// - widget_lifecycle_rules.dart (2026-03-01)
/// - scroll_rules.dart (2026-03-01)
/// - widget_layout_rules.dart (2026-03-01)
/// - accessibility_rules.dart (2026-03-01)
/// - animation_rules.dart (2026-03-01)
/// - build_method_rules.dart (2026-03-01)
/// - widget_patterns_rules.dart (2026-03-01)
/// - platforms/macos_rules.dart (2026-03-01)
/// - platforms/android_rules.dart (2026-03-01)
/// - platforms/linux_rules.dart (2026-03-01)
/// - platforms/windows_rules.dart (2026-03-01)
/// - packages/bloc_rules.dart (2026-03-01)
/// - packages/hive_rules.dart (2026-03-01)
/// - packages/getx_rules.dart (2026-03-01)
/// - packages/shared_preferences_rules.dart (2026-03-01)
/// - packages/dio_rules.dart (2026-03-01)
/// - packages/provider_rules.dart (2026-03-01)
/// - packages/isar_rules.dart (2026-03-01)
/// - packages/supabase_rules.dart (2026-03-01)
/// - packages/workmanager_rules.dart (2026-03-01)
/// - packages/url_launcher_rules.dart (2026-03-01)
/// - packages/package_specific_rules.dart (2026-03-01)
/// - packages/get_it_rules.dart (2026-03-01)
/// - packages/qr_scanner_rules.dart (2026-03-01)
/// - packages/equatable_rules.dart (2026-03-01)
/// - packages/flutter_hooks_rules.dart (2026-03-01)
/// - packages/geolocator_rules.dart (2026-03-01)
/// - packages/drift_rules.dart (2026-03-01)
/// - ui_ux_rules.dart (2026-03-01)
/// - error_handling_rules.dart (2026-03-01)
/// - state_management_rules.dart (2026-03-01)
/// - collection_rules.dart (2026-03-01)
/// - internationalization_rules.dart (2026-03-01)
/// - documentation_rules.dart (2026-03-01)
/// - media_rules.dart (2026-03-01)
/// - memory_management_rules.dart (2026-03-01)
/// - crypto_rules.dart (2026-03-01)
/// - dependency_injection_rules.dart (2026-03-01)
/// - bluetooth_hardware_rules.dart (2026-03-01)
/// - exception_rules.dart (2026-03-01)
/// - type_safety_rules.dart (2026-03-01)
/// - json_datetime_rules.dart (2026-03-01)
/// - dialog_snackbar_rules.dart (2026-03-01)
/// - complexity_rules.dart (2026-03-01)
/// - debug_rules.dart (2026-03-01)
/// - stylistic_error_testing_rules.dart (2026-03-01)
/// - architecture_rules.dart (2026-03-01)
/// - migration_rules.dart (2026-03-01)
///
/// All baseline entries removed; all rule files at 0. Any new .contains()
/// anti-pattern will fail CI.
const Map<String, int> _baselineCounts = {};
