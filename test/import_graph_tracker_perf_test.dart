import 'dart:io' show Directory, Platform, stdout;

import 'package:saropa_lints/src/report/import_graph_tracker.dart';
import 'package:saropa_lints/src/saropa_lint_rule.dart'
    show LintImpact, ViolationRecord;
import 'package:test/test.dart';

void main() {
  test('ImportGraphTracker compute + ordering work is fast enough', () {
    // Synthetic performance test to validate the plan’s overhead budget.
    //
    // This is intentionally not a strict CI gate on <20ms because machine
    // load varies; we still assert a generous upper bound to catch regressions.
    // The plan doc is updated with the measured timing from this run.

    final tempDir = Directory.systemTemp.createTempSync('import_graph_perf_');
    try {
      final projectRoot = tempDir.path;
      const packageName = 'perf_pkg';

      const fileCount = 200;
      const violationCount = 500;

      ImportGraphTracker.reset();
      ImportGraphTracker.setProjectInfo(projectRoot, packageName);

      // Create a simple directed chain:
      //   file_0.dart -> file_1.dart -> ... -> file_(N-1).dart
      // This gives a single root for PROJECT STRUCTURE traversal.
      for (var i = 0; i < fileCount; i++) {
        final filePath =
            '${projectRoot}${Platform.pathSeparator}lib${Platform.pathSeparator}file_$i.dart';
        final content = i + 1 < fileCount
            ? "import 'package:$packageName/file_${i + 1}.dart';\n"
            : '';
        ImportGraphTracker.collectImports(filePath, content);
      }

      final sw = Stopwatch()..start();
      ImportGraphTracker.compute();

      // FILE IMPORTANCE ranking work (same shape as report writer).
      final files = ImportGraphTracker.allFiles.toList(growable: false);
      final scored = <double>[];
      for (final file in files) {
        scored.add(ImportGraphTracker.getFileScore(file));
        // Touch fan-in / layer getters to match ordering work.
        ImportGraphTracker.importersOf(file).length;
        ImportGraphTracker.getLayer(file);
      }
      scored.sort();

      // FIX PRIORITY ordering work (priority computation + sort).
      final violations = <ViolationRecord>[];
      for (var i = 0; i < violationCount; i++) {
        final fileIndex = i % fileCount;
        final filePath =
            '${projectRoot}${Platform.pathSeparator}lib${Platform.pathSeparator}file_$fileIndex.dart';
        violations.add(
          ViolationRecord(
            rule: 'perf_rule',
            file: filePath,
            line: i,
            message: 'perf',
          ),
        );
      }

      final priorities = violations
          .map((v) => ImportGraphTracker.getPriority(v.file, LintImpact.high))
          .toList(growable: false);
      priorities.sort((a, b) => b.compareTo(a));

      // PROJECT STRUCTURE traversal work (same graph walk style as writer).
      final allFiles = ImportGraphTracker.allFiles;
      final visited = <String>{};
      final roots = files.where((f) {
        final fanIn = ImportGraphTracker.importersOf(f).length;
        final fanOut = ImportGraphTracker.importsOf(f).length;
        return fanIn == 0 && fanOut > 0;
      });

      void dfs(String file) {
        if (!visited.add(file)) return;
        final children = ImportGraphTracker.importsOf(file).toList()..sort();
        for (final c in children) {
          if (allFiles.contains(c)) dfs(c);
        }
      }

      for (final r in roots) {
        dfs(r);
      }

      sw.stop();
      final ms = sw.elapsedMilliseconds;

      // Gentle regression guard: report ordering work should not explode.
      // If this trips, the plan’s “<20ms overhead” assumption likely broke.
      expect(ms, lessThan(2000));

      stdout.writeln(
        'ImportGraphTracker perf: compute+ordering for $fileCount files '
        'and $violationCount violations took ${sw.elapsedMilliseconds}ms.',
      );
    } finally {
      ImportGraphTracker.reset();
      try {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      } catch (_) {
        // Best-effort cleanup in tests.
      }
    }
  });
}
