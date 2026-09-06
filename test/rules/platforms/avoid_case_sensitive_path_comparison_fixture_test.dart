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

    // Regression coverage for the false-positive bug report: root-detection
    // idiom, CLI flag literals, import URI comparisons, and "path" embedded
    // in an unrelated word all used to fire incorrectly.

    test(
      'does NOT fire on root-detection idiom (dir.path != dir.parent.path)',
      () async {
        await assertFixtureMarkers(rule, '''
class D {
  String get path => '';
  D get parent => this;
}

void f(D dir) {
  // LINT_NOT: avoid_case_sensitive_path_comparison
  while (dir.path != dir.parent.path) {}
}
''');
      },
    );

    test(
      'does NOT fire on reversed root-detection idiom (dir.parent.path == dir.path)',
      () async {
        await assertFixtureMarkers(rule, '''
class D {
  String get path => '';
  D get parent => this;
}

void f(D dir) {
  // LINT_NOT: avoid_case_sensitive_path_comparison
  if (dir.parent.path == dir.path) {}
}
''');
      },
    );

    test(
      'does NOT fire on CLI flag string literal containing "path"',
      () async {
        await assertFixtureMarkers(rule, '''
void f(String arg) {
  // LINT_NOT: avoid_case_sensitive_path_comparison
  if (arg == '--json-file-path') {}
}
''');
      },
    );

    test('does NOT fire on import URI comparison by name', () async {
      // Both operands have URI-related names — `namedUri` triggers the
      // import-URI suppression via camelCase word boundary detection.
      await assertFixtureMarkers(rule, '''
void f(String namedUri, String otherUri) {
  // LINT_NOT: avoid_case_sensitive_path_comparison
  if (namedUri == otherUri) {}
}
''');
    });

    test(
      'does NOT fire on import URI comparison via abbreviated loop variable',
      () async {
        await assertFixtureMarkers(rule, '''
void f(List<String> imports, String? firstSpec) {
  for (final imp in imports) {
    // LINT_NOT: avoid_case_sensitive_path_comparison
    if (firstSpec != null && imp == firstSpec) {}
  }
}
''');
      },
    );

    // Regression: C15 — mismatched base expressions in root-detection idiom
    // must NOT be suppressed (a.path == b.parent.path where a != b).

    test(
      'fires on mismatched root-detection idiom (a.path == b.parent.path)',
      () async {
        await assertFixtureMarkers(rule, '''
class D {
  String get path => '';
  D get parent => this;
}

void f(D a, D b) {
  // LINT: avoid_case_sensitive_path_comparison
  if (a.path == b.parent.path) {}
}
''');
      },
    );

    test(
      'fires on reversed mismatched root-detection idiom (b.parent.path == a.path)',
      () async {
        await assertFixtureMarkers(rule, '''
class D {
  String get path => '';
  D get parent => this;
}

void f(D a, D b) {
  // LINT: avoid_case_sensitive_path_comparison
  if (b.parent.path == a.path) {}
}
''');
      },
    );

    test(
      'does NOT fire when "path" is embedded in an unrelated word',
      () async {
        await assertFixtureMarkers(rule, '''
void f(String pathologyReport, String empathyNote) {
  // LINT_NOT: avoid_case_sensitive_path_comparison
  if (pathologyReport == empathyNote) {}
}
''');
      },
    );

    // False-positive guards: "uri" embedded in unrelated words must NOT
    // trigger the import-URI suppression and then bypass the path check.

    test('does NOT fire when "uri" is embedded in an unrelated word', () async {
      // "security" and "mercurial" both contain "uri" as a substring
      // but not at a camelCase word boundary — rule should ignore them,
      // and since neither looks like a path variable either, no diagnostic.
      await assertFixtureMarkers(rule, '''
void f(String securityLevel, String mercurialBuild) {
  // LINT_NOT: avoid_case_sensitive_path_comparison
  if (securityLevel == mercurialBuild) {}
}
''');
    });

    test(
      'does NOT suppress a path comparison when "uri" is embedded in operand',
      () async {
        // "filePath" is a path variable — the rule should fire even though
        // "securityToken" contains "uri" as a substring, because "uri"
        // inside "security" is not a camelCase word boundary.
        await assertFixtureMarkers(rule, '''
void f(String filePath, String securityToken) {
  // LINT: avoid_case_sensitive_path_comparison
  if (filePath == securityToken) {}
}
''');
      },
    );

    // Snake_case boundary coverage: underscores are not lowercase ASCII
    // letters, so `_hasCamelCaseWord` already treats them as word boundaries.

    test('fires on snake_case path variable (file_path)', () async {
      // "file_path" has an underscore before "path" — the boundary check
      // sees a non-lowercase character and correctly identifies "path".
      await assertFixtureMarkers(rule, '''
void f(String file_path, String other) {
  // LINT: avoid_case_sensitive_path_comparison
  if (file_path == other) {}
}
''');
    });

    test('does NOT fire on snake_case URI variables (named_uri)', () async {
      // "named_uri" has "uri" after an underscore — detected as a URI
      // variable, so the import-URI suppression should apply.
      await assertFixtureMarkers(rule, '''
void f(String named_uri, String other_uri) {
  // LINT_NOT: avoid_case_sensitive_path_comparison
  if (named_uri == other_uri) {}
}
''');
    });
  });
}
