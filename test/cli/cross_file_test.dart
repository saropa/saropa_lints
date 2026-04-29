import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/src/cli/cross_file_analyzer.dart';
import 'package:saropa_lints/src/cli/cross_file_html_reporter.dart';
import 'package:saropa_lints/src/cli/cross_file_reporter.dart';
import 'package:test/test.dart';
import '../../bin/cross_file.dart' as cross_file_bin;

/// Unit tests for cross-file CLI: analyzer result shape, reporter, and fixture-based behavior.
void main() {
  final projectRoot = Directory.current.path;
  final fixturePath = p.join(
    projectRoot,
    'test',
    'fixtures',
    'cross_file_fixture',
  );
  final featureFixturePath = p.join(
    projectRoot,
    'test',
    'fixtures',
    'cross_file_features_fixture',
  );
  final unusedSymbolsFixturePath = p.join(
    projectRoot,
    'test',
    'fixtures',
    'cross_file_unused_symbols_fixture',
  );
  final deadImportsFixturePath = p.join(
    projectRoot,
    'test',
    'fixtures',
    'cross_file_dead_imports_fixture',
  );

  group('runCrossFileAnalysis', () {
    test(
      'returns result with unusedFiles, circularDependencies, stats',
      () async {
        final result = await runCrossFileAnalysis(projectPath: projectRoot);
        expect(result.unusedFiles, isA<List<String>>());
        expect(result.circularDependencies, isA<List<List<String>>>());
        expect(result.missingMirrorTests, isA<List<String>>());
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
      expect(out, contains('Lib sources without mirror test'));
      expect(out, contains('Circular Dependencies'));
    });

    test('json format is valid and has expected keys', () async {
      final result = await runCrossFileAnalysis(projectPath: projectRoot);
      final buffer = StringBuffer();
      CrossFileReporter.report(result, format: 'json', sink: buffer);
      final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;
      expect(decoded.containsKey('unusedFiles'), isTrue);
      expect(decoded.containsKey('circularDependencies'), isTrue);
      expect(decoded.containsKey('missingMirrorTests'), isTrue);
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
        // Fix: hasLength gives clearer failure output than raw int matcher.
        expect(result.unusedFiles, hasLength(1));
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

    test(
      'missing mirror tests: only orphan.dart lacks test/orphan_test.dart',
      () async {
        final result = await runCrossFileAnalysis(projectPath: fixturePath);
        expect(result.missingMirrorTests, hasLength(1));
        expect(result.missingMirrorTests.single, endsWith('orphan.dart'));
      },
    );
  });

  group('fixture: cross_file_features_fixture (feature-deps)', () {
    test('detects cross-feature imports and builds adjacency map', () async {
      final result = await runCrossFileAnalysis(
        projectPath: featureFixturePath,
      );
      expect(result.featureDependencies, isNotEmpty);
      expect(result.featureDependencies['feature_a'], contains('feature_b'));
      expect(
        result.crossFeatureImports.any(
          (edge) =>
              edge.contains('lib/features/feature_a/data/a_impl.dart') &&
              edge.contains('lib/features/feature_b/data/b_impl.dart'),
        ),
        isTrue,
      );
    });

    test('text reporter includes feature dependency matrix', () async {
      final result = await runCrossFileAnalysis(
        projectPath: featureFixturePath,
      );
      final buffer = StringBuffer();
      CrossFileReporter.report(result, format: 'text', sink: buffer);
      final out = buffer.toString();
      expect(out, contains('Feature dependency matrix (from \\ to):'));
      expect(out, contains('feature_a'));
      expect(out, contains('feature_b'));
      expect(out, contains('X'));
    });
  });

  group('fixture: cross_file_unused_symbols_fixture (unused-symbols)', () {
    test('finds unused top-level symbols and skips used ones', () async {
      final result = await runCrossFileAnalysis(
        projectPath: unusedSymbolsFixturePath,
        unusedSymbolsOptions: const UnusedSymbolsOptions(),
      );
      final allUnused = result.unusedSymbols.values.expand((s) => s).toList();
      expect(allUnused, contains('UnusedClass'));
      expect(allUnused, contains('unusedTopLevelFunction'));
      expect(allUnused, contains('unusedConstValue'));
      expect(allUnused, isNot(contains('UsedClass')));
      expect(allUnused, isNot(contains('usedTopLevelFunction')));
      expect(allUnused, isNot(contains('usedConstValue')));
      expect(allUnused, isNot(contains('helperForTests')));
      expect(allUnused, isNot(contains('_privateCandidate')));
    });

    test(
      'forceHeuristic skips analyzer and still matches fixture expectations',
      () async {
        final result = await runCrossFileAnalysis(
          projectPath: unusedSymbolsFixturePath,
          unusedSymbolsOptions: const UnusedSymbolsOptions(
            forceHeuristic: true,
          ),
        );
        final allUnused = result.unusedSymbols.values.expand((s) => s).toList();
        expect(allUnused, contains('UnusedClass'));
        expect(allUnused, isNot(contains('UsedClass')));
        expect(allUnused, isNot(contains('usedTopLevelFunction')));
        expect(allUnused, isNot(contains('usedConstValue')));
      },
    );

    test('includePrivate option surfaces private unused symbols', () async {
      final result = await runCrossFileAnalysis(
        projectPath: unusedSymbolsFixturePath,
        unusedSymbolsOptions: const UnusedSymbolsOptions(includePrivate: true),
      );
      final allUnused = result.unusedSymbols.values.expand((s) => s).toList();
      expect(allUnused, contains('_privateCandidate'));
    });
  });

  group('fixture: cross_file_dead_imports_fixture (dead-imports)', () {
    test(
      'reports likely dead relative imports with alias/show/hide support',
      () async {
        final result = await runCrossFileAnalysis(
          projectPath: deadImportsFixturePath,
        );
        expect(result.deadImports, isNotEmpty);
        expect(result.deadImports['lib/consumer.dart'], isNotNull);
        expect(
          result.deadImports['lib/consumer.dart'],
          contains('unused_dep.dart'),
        );
        expect(
          result.deadImports['lib/consumer.dart'],
          contains('show_only_dead.dart'),
        );
        expect(
          result.deadImports['lib/consumer.dart'],
          isNot(contains('used_dep.dart')),
        );
        expect(
          result.deadImports['lib/consumer.dart'],
          isNot(contains('show_hide_dep.dart')),
        );
        expect(
          result.deadImports['lib/consumer.dart'],
          isNot(contains('hide_dep.dart')),
        );
        expect(
          result.deadImports['lib/consumer.dart'],
          isNot(contains('reexport_barrel.dart')),
        );
        expect(
          result.deadImports['lib/consumer.dart'],
          isNot(contains('deferred_dep.dart')),
        );
      },
    );
  });

  group('watch diff helpers', () {
    test('unused-files diff reports added/resolved counts', () {
      const prev = CrossFileResult(
        unusedFiles: ['a.dart', 'b.dart'],
        circularDependencies: [],
        missingMirrorTests: [],
        stats: {'fileCount': 2, 'totalImports': 1},
        featureDependencies: {},
        crossFeatureImports: [],
        deadImports: {},
      );
      const curr = CrossFileResult(
        unusedFiles: ['b.dart', 'c.dart'],
        circularDependencies: [],
        missingMirrorTests: [],
        stats: {'fileCount': 2, 'totalImports': 1},
        featureDependencies: {},
        crossFeatureImports: [],
        deadImports: {},
      );
      final msg = cross_file_bin.buildWatchDiffForTest(
        previous: prev,
        current: curr,
        command: 'unused-files',
      );
      expect(msg, contains('+1 new'));
      expect(msg, contains('-1 resolved'));
    });

    test('import-stats diff reports deltas', () {
      const prev = CrossFileResult(
        unusedFiles: [],
        circularDependencies: [],
        missingMirrorTests: [],
        stats: {'fileCount': 4, 'totalImports': 6},
        featureDependencies: {},
        crossFeatureImports: [],
        deadImports: {},
      );
      const curr = CrossFileResult(
        unusedFiles: [],
        circularDependencies: [],
        missingMirrorTests: [],
        stats: {'fileCount': 5, 'totalImports': 3},
        featureDependencies: {},
        crossFeatureImports: [],
        deadImports: {},
      );
      final msg = cross_file_bin.buildWatchDiffForTest(
        previous: prev,
        current: curr,
        command: 'import-stats',
      );
      expect(msg, contains('files +1'));
      expect(msg, contains('imports -3'));
    });
  });

  group('reportToHtml', () {
    test('writes report.css, feature-deps.html, and links stylesheet from index', () {
      final tmp = Directory.systemTemp.createTempSync('cf_html_');
      try {
        const result = CrossFileResult(
          unusedFiles: ['x.dart'],
          circularDependencies: [],
          missingMirrorTests: [],
          stats: {'fileCount': 1, 'totalImports': 0},
          featureDependencies: {'auth': ['profile']},
          crossFeatureImports: ['lib/f/a.dart -> lib/f/b.dart'],
          deadImports: {},
        );
        reportToHtml(result, tmp.path);
        expect(
          File(p.join(tmp.path, 'report.css')).readAsStringSync(),
          contains('--bg'),
        );
        final index = File(p.join(tmp.path, 'index.html')).readAsStringSync();
        expect(index, contains('href="report.css"'));
        expect(index, contains('feature-deps.html'));
        final featureHtml =
            File(p.join(tmp.path, 'feature-deps.html')).readAsStringSync();
        expect(featureHtml, contains('Feature dependencies'));
        expect(featureHtml, contains('Matrix'));
        expect(featureHtml, contains('href="report.css"'));
      } finally {
        if (tmp.existsSync()) {
          tmp.deleteSync(recursive: true);
        }
      }
    });
  });
}
