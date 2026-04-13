import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/src/cli/cross_file_analyzer.dart';
import 'package:saropa_lints/src/cli/cross_file_dot_reporter.dart';
import 'package:test/test.dart';

/// Tests for DOT graph export in cross-file analysis.
///
/// Uses the cross_file_fixture which has 4 files:
///   lib/a.dart  → imports b.dart
///   lib/b.dart  → imports c.dart
///   lib/c.dart  → imports a.dart
///   lib/orphan.dart  → no imports, no importers
void main() {
  final fixturePath = p.join(
    Directory.current.path,
    'test',
    'fixtures',
    'cross_file_fixture',
  );

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('cross_file_dot_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('exportDotGraph', () {
    test('produces valid DOT with all 4 fixture nodes', () async {
      // Build the import graph first (required before calling exportDotGraph).
      await runCrossFileAnalysis(projectPath: fixturePath);

      final dotPath = p.join(tempDir.path, 'graph.dot');
      exportDotGraph(projectPath: fixturePath, outputPath: dotPath);

      final content = File(dotPath).readAsStringSync();
      // Should be a valid DOT digraph.
      expect(content, startsWith('digraph imports {'));
      expect(content.trimRight(), endsWith('}'));

      // All 4 fixture files should appear as node labels.
      expect(content, contains('a.dart'));
      expect(content, contains('b.dart'));
      expect(content, contains('c.dart'));
      expect(content, contains('orphan.dart'));

      // Should contain edges (at least the a→b→c→a cycle = 3 edges).
      // Edge format: nX -> nY;
      final edgePattern = RegExp(r'n\d+ -> n\d+;');
      final edges = edgePattern.allMatches(content).length;
      expect(edges, greaterThanOrEqualTo(3));
    });

    test('includedPaths filters nodes in DOT output', () async {
      // Build graph, then export with only a subset of paths.
      final result = await runCrossFileAnalysis(
        projectPath: fixturePath,
        excludeGlobs: ['**/orphan.dart'],
      );

      final dotPath = p.join(tempDir.path, 'filtered.dot');
      exportDotGraph(
        projectPath: fixturePath,
        outputPath: dotPath,
        includedPaths: result.includedPaths,
      );

      final content = File(dotPath).readAsStringSync();
      // orphan.dart should NOT appear as a node label.
      expect(content, isNot(contains('orphan.dart')));
      // The cycle files should still be present.
      expect(content, contains('a.dart'));
      expect(content, contains('b.dart'));
      expect(content, contains('c.dart'));
    });

    test('creates parent directories if missing', () async {
      await runCrossFileAnalysis(projectPath: fixturePath);

      final dotPath = p.join(tempDir.path, 'nested', 'deep', 'graph.dot');
      exportDotGraph(projectPath: fixturePath, outputPath: dotPath);

      expect(File(dotPath).existsSync(), isTrue);
    });
  });
}
