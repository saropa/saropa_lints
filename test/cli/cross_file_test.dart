import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/src/cli/cross_file_analyzer.dart';
import 'package:saropa_lints/src/cli/cross_file_reporter.dart';
import 'package:test/test.dart';

/// Unit tests for cross-file CLI: analyzer result shape, reporter, and fixture-based behavior.
void main() {
  final projectRoot = Directory.current.path;
  final fixturePath = p.join(
    projectRoot,
    'test',
    'fixtures',
    'cross_file_fixture',
  );

  group('runCrossFileAnalysis', () {
    test(
      'returns result with unusedFiles, circularDependencies, stats',
      () async {
        final result = await runCrossFileAnalysis(projectPath: projectRoot);
        expect(result.unusedFiles, isA<List<String>>());
        expect(result.circularDependencies, isA<List<List<String>>>());
        expect(result.stats, isA<Map<String, dynamic>>());
        expect(result.stats['fileCount'], isA<int>());
      },
    );

    test(
      'accepts excludeGlobs without error (reserved for future use)',
      () async {
        final result = await runCrossFileAnalysis(
          projectPath: projectRoot,
          excludeGlobs: ['**/*.g.dart'],
        );
        expect(result.stats['fileCount'], isA<int>());
      },
    );
  });

  group('CrossFileReporter', () {
    test('text format includes section headers', () async {
      final result = await runCrossFileAnalysis(projectPath: projectRoot);
      final buffer = StringBuffer();
      CrossFileReporter.report(result, format: 'text', sink: buffer);
      final out = buffer.toString();
      expect(out, contains('Unused Files'));
      expect(out, contains('Circular Dependencies'));
    });

    test('json format is valid and has expected keys', () async {
      final result = await runCrossFileAnalysis(projectPath: projectRoot);
      final buffer = StringBuffer();
      CrossFileReporter.report(result, format: 'json', sink: buffer);
      final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;
      expect(decoded.containsKey('unusedFiles'), isTrue);
      expect(decoded.containsKey('circularDependencies'), isTrue);
    });
  });

  group('fixture: cross_file_fixture (orphan + cycle)', () {
    test(
      'unused-files: fixture has exactly one unused file (orphan.dart)',
      () async {
        final result = await runCrossFileAnalysis(projectPath: fixturePath);
        expect(
          result.unusedFiles.any((path) => path.endsWith('orphan.dart')),
          isTrue,
        );
        expect(result.unusedFiles.length, 1);
      },
    );

    test('circular-deps: fixture has one cycle (a -> b -> c -> a)', () async {
      final result = await runCrossFileAnalysis(projectPath: fixturePath);
      expect(result.circularDependencies, isNotEmpty);
      final cycle = result.circularDependencies.first;
      expect(cycle.any((path) => path.endsWith('a.dart')), isTrue);
      expect(cycle.any((path) => path.endsWith('b.dart')), isTrue);
      expect(cycle.any((path) => path.endsWith('c.dart')), isTrue);
    });

    test('import-stats: fixture has 4 files and 3 imports', () async {
      final result = await runCrossFileAnalysis(projectPath: fixturePath);
      expect(result.stats['fileCount'], 4);
      expect(result.stats['totalImports'], 3);
    });
  });
}
