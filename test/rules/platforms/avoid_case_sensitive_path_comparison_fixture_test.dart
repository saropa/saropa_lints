// Resolved-analyzer tests for `avoid_case_sensitive_path_comparison`.
//
// Runs the rule against inline fixture source with full type resolution,
// validating that:
// - String-to-string path comparisons fire (BAD)
// - Null, boolean, integer, double, and enum comparisons do NOT fire (GOOD)
// - Case-normalized comparisons do NOT fire (GOOD)
//
// Uses `assertFixtureMarkers` for declarative marker-driven assertions.
library;

import 'package:saropa_lints/src/rules/platforms/windows_rules.dart';
import 'package:test/test.dart';

import '../../support/fixture_message_harness.dart';

void main() {
  group('AvoidCaseSensitivePathComparisonRule - resolved', () {
    final rule = AvoidCaseSensitivePathComparisonRule();

    test('fires on string-to-string path comparison', () async {
      await assertFixtureMarkers(rule, '''
void f(String filePath, String otherPath) {
  // LINT: avoid_case_sensitive_path_comparison
  if (filePath == otherPath) {}
}
''');
    });

    test('fires on != string-to-string path comparison', () async {
      await assertFixtureMarkers(rule, '''
void f(String dirPath, String expected) {
  // LINT: avoid_case_sensitive_path_comparison
  if (dirPath != expected) {}
}
''');
    });

    test('does NOT fire on null check (path == null)', () async {
      await assertFixtureMarkers(rule, '''
void f(String? filePathUrl) {
  // LINT_NOT: avoid_case_sensitive_path_comparison
  if (filePathUrl == null) return;
}
''');
    });

    test('does NOT fire on reversed null check (null == path)', () async {
      await assertFixtureMarkers(rule, '''
void f(String? filePathUrl) {
  // LINT_NOT: avoid_case_sensitive_path_comparison
  if (null == filePathUrl) return;
}
''');
    });

    test('does NOT fire on not-null check (path != null)', () async {
      await assertFixtureMarkers(rule, '''
void f(String? filePathUrl) {
  // LINT_NOT: avoid_case_sensitive_path_comparison
  if (filePathUrl != null) {}
}
''');
    });

    test('does NOT fire on integer comparison', () async {
      await assertFixtureMarkers(rule, '''
void f(int pathIndex) {
  // LINT_NOT: avoid_case_sensitive_path_comparison
  if (pathIndex == 0) return;
}
''');
    });

    test('does NOT fire on boolean comparison', () async {
      await assertFixtureMarkers(rule, '''
void f(bool isPathValid) {
  // LINT_NOT: avoid_case_sensitive_path_comparison
  if (isPathValid == true) return;
}
''');
    });

    test('does NOT fire on double comparison', () async {
      await assertFixtureMarkers(rule, '''
void f(double pathLength) {
  // LINT_NOT: avoid_case_sensitive_path_comparison
  if (pathLength == 0.0) return;
}
''');
    });

    test('does NOT fire on enum comparison', () async {
      await assertFixtureMarkers(rule, '''
enum PathType { absolute, relative }

void f(PathType dirPathType) {
  // LINT_NOT: avoid_case_sensitive_path_comparison
  if (dirPathType == PathType.absolute) return;
}
''');
    });

    test('does NOT fire when toLowerCase is applied', () async {
      await assertFixtureMarkers(rule, '''
void f(String filePath, String otherPath) {
  // LINT_NOT: avoid_case_sensitive_path_comparison
  if (filePath.toLowerCase() == otherPath.toLowerCase()) {}
}
''');
    });

    test('does NOT fire when toUpperCase is applied', () async {
      await assertFixtureMarkers(rule, '''
void f(String filePath, String otherPath) {
  // LINT_NOT: avoid_case_sensitive_path_comparison
  if (filePath.toUpperCase() == otherPath.toUpperCase()) {}
}
''');
    });
  });
}
