import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/src/cli/cross_file_analyzer.dart';
import 'package:test/test.dart';

/// Tests for --exclude glob filtering in cross-file analysis.
///
/// Uses the cross_file_fixture which has 4 files:
///   lib/a.dart  (imports b.dart — part of a→b→c→a cycle)
///   lib/b.dart  (imports c.dart)
///   lib/c.dart  (imports a.dart)
///   lib/orphan.dart  (no importers, no imports)
void main() {
  final fixturePath = p.join(
    Directory.current.path,
    'test',
    'fixtures',
    'cross_file_fixture',
  );

  group('excludeGlobs filtering', () {
    test('no excludes returns all files', () async {
      final result = await runCrossFileAnalysis(
        projectPath: fixturePath,
      );
      expect(result.stats['fileCount'], 4);
      // No excludes active → includedPaths should be empty (signals "use all").
      expect(result.includedPaths, isEmpty);
    });

    test('excluding orphan.dart removes it from unused files', () async {
      // Without exclude: orphan.dart appears as unused.
      final baseline = await runCrossFileAnalysis(
        projectPath: fixturePath,
      );
      expect(
        baseline.unusedFiles.any((f) => f.endsWith('orphan.dart')),
        isTrue,
        reason: 'orphan.dart should be unused when not excluded',
      );

      // With exclude: orphan.dart is filtered out entirely.
      final filtered = await runCrossFileAnalysis(
        projectPath: fixturePath,
        excludeGlobs: ['**/orphan.dart'],
      );
      expect(
        filtered.unusedFiles.any((f) => f.endsWith('orphan.dart')),
        isFalse,
        reason: 'orphan.dart should be excluded from results',
      );
      // includedPaths should be populated when excludes are active.
      expect(filtered.includedPaths, isNotEmpty);
      expect(
        filtered.includedPaths.any((f) => f.endsWith('orphan.dart')),
        isFalse,
        reason: 'orphan.dart should not be in includedPaths',
      );
    });

    test('excluding all files yields empty results', () async {
      final result = await runCrossFileAnalysis(
        projectPath: fixturePath,
        excludeGlobs: ['**/*.dart'],
      );
      expect(result.unusedFiles, isEmpty);
      expect(result.circularDependencies, isEmpty);
      expect(result.includedPaths, isEmpty);
    });

    test('single-star glob does not match nested paths', () async {
      // *.dart should match top-level only, not lib/a.dart.
      final result = await runCrossFileAnalysis(
        projectPath: fixturePath,
        excludeGlobs: ['*.dart'],
      );
      // All 4 fixture files are under lib/, so none match a top-level *.dart
      // glob and the result should be identical to no-exclude.
      expect(result.stats['fileCount'], 4);
      expect(
        result.unusedFiles.any((f) => f.endsWith('orphan.dart')),
        isTrue,
        reason: 'single * should not match files in subdirectories',
      );
    });
  });
}
