import 'dart:convert';
import 'dart:io';

import 'package:saropa_lints/src/cli/cross_file_analyzer.dart';
import 'package:saropa_lints/src/cli/cross_file_reporter.dart';
import 'package:test/test.dart';

/// Unit tests for cross-file CLI: analyzer result shape and reporter output.
void main() {
  final projectRoot = Directory.current.path;

  group('runCrossFileAnalysis', () {
    test('returns result with unusedFiles, circularDependencies, stats', () async {
      final result = await runCrossFileAnalysis(projectPath: projectRoot);
      expect(result.unusedFiles, isA<List<String>>());
      expect(result.circularDependencies, isA<List<List<String>>>());
      expect(result.stats, isA<Map<String, dynamic>>());
      expect(result.stats['fileCount'], isA<int>());
    });

    test('accepts excludeGlobs without error (reserved for future use)', () async {
      final result = await runCrossFileAnalysis(
        projectPath: projectRoot,
        excludeGlobs: ['**/*.g.dart'],
      );
      expect(result.stats['fileCount'], isA<int>());
    });
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
}
