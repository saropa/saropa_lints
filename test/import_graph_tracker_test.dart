import 'dart:io' show Directory, Platform;

import 'package:saropa_lints/src/report/import_graph_tracker.dart';
import 'package:saropa_lints/src/saropa_lint_rule.dart' show LintImpact;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late String projectRoot;
  late String libA;
  late String libB;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('import_graph_tracker_test_');
    projectRoot = tempDir.path;
    final sep = Platform.pathSeparator;
    libA = '$projectRoot${sep}lib${sep}a.dart';
    libB = '$projectRoot${sep}lib${sep}b.dart';
  });

  tearDown(() {
    ImportGraphTracker.reset();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('setProjectInfo and collectImports build resolved package edges', () {
    const pkg = 'test_pkg';
    ImportGraphTracker.setProjectInfo(projectRoot, pkg);

    ImportGraphTracker.collectImports(libA, "import 'package:$pkg/b.dart';\n");
    ImportGraphTracker.collectImports(libB, '// leaf\n');

    ImportGraphTracker.compute();

    expect(ImportGraphTracker.importsOf(libA), contains(libB));
    expect(ImportGraphTracker.importersOf(libB), contains(libA));
    // b.dart is imported by a.dart → higher fan-in → higher fix priority.
    expect(
      ImportGraphTracker.getPriority(libB, LintImpact.high),
      greaterThan(ImportGraphTracker.getPriority(libA, LintImpact.high)),
    );
  });

  test('collectImports is idempotent per file path', () {
    ImportGraphTracker.setProjectInfo(projectRoot, 'x');
    const content = "import 'dart:async';\n";
    ImportGraphTracker.collectImports(libA, content);
    ImportGraphTracker.collectImports(libA, "import 'dart:io';\n");
    ImportGraphTracker.compute();
    expect(ImportGraphTracker.importsOf(libA), isEmpty);
  });

  test('getPriority matches graph when violation path is project-relative', () {
    const pkg = 'test_pkg';
    ImportGraphTracker.setProjectInfo(projectRoot, pkg);
    ImportGraphTracker.collectImports(libA, "import 'package:$pkg/b.dart';\n");
    ImportGraphTracker.collectImports(libB, '// leaf\n');
    ImportGraphTracker.compute();

    final relA = 'lib/a.dart';
    final relB = 'lib/b.dart';
    expect(
      ImportGraphTracker.getPriority(relB, LintImpact.high),
      greaterThan(ImportGraphTracker.getPriority(relA, LintImpact.high)),
    );
  });
}
