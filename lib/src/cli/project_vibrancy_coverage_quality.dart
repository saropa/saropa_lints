import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:path/path.dart' as p;

/// Heuristic coverage-quality context: maps each `lib/*.dart` (posix, relative to
/// project `lib/`) to test files that import it, and classifies each test file as
/// trivial-only vs having at least one substantive assertion.
///
/// Standard Dart `lcov.info` does not attribute hits per test; importer + triviality
/// is an approximation aligned with
/// `plan/history/2026.04/2026.04.28/project_vibrancy_report.md`.
class ProjectCoverageQualityIndex {
  ProjectCoverageQualityIndex({
    required this.testsImportingLib,
    required this.testIsTrivial,
  });

  /// `lib/foo.dart` posix path relative to package `lib/` → absolute test file paths.
  final Map<String, Set<String>> testsImportingLib;

  /// Absolute normalized test path → `true` when the file has no non-trivial assertions.
  final Map<String, bool> testIsTrivial;
}

ProjectCoverageQualityIndex buildProjectCoverageQualityIndex({
  required String projectRoot,
  required String? packageName,
}) {
  final root = p.normalize(projectRoot);
  final testsImportingLib = <String, Set<String>>{};
  final testIsTrivial = <String, bool>{};

  for (final testPath in _collectTestDartFiles(root)) {
    final file = File(testPath);
    if (!file.existsSync()) continue;
    final content = file.readAsStringSync();
    final parsed = parseString(content: content, path: testPath);
    testIsTrivial[testPath] = !_unitHasNonTrivialAssertion(parsed.unit);
    final imports = _resolvedLibImports(
      root: root,
      packageName: packageName,
      testPath: testPath,
      unit: parsed.unit,
    );
    for (final libRel in imports) {
      testsImportingLib.putIfAbsent(libRel, () => <String>{}).add(testPath);
    }
  }

  return ProjectCoverageQualityIndex(
    testsImportingLib: testsImportingLib,
    testIsTrivial: testIsTrivial,
  );
}

/// Dart files under `test/` and `integration_test/` (absolute paths).
List<String> listProjectTestDartPaths(String root) =>
    _collectTestDartFiles(root);

List<String> _collectTestDartFiles(String root) {
  final out = <String>[];
  for (final dirName in const ['test', 'integration_test']) {
    final dir = Directory(p.join(root, dirName));
    if (!dir.existsSync()) continue;
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File) continue;
      final path = p.normalize(entity.path);
      if (!path.endsWith('.dart')) continue;
      out.add(path);
    }
  }
  out.sort();
  return out;
}

String? readPubspecPackageName(String projectRoot) {
  final file = File(p.join(projectRoot, 'pubspec.yaml'));
  if (!file.existsSync()) return null;
  final namePattern = RegExp(r'^name:\s*(\S+)');
  for (final line in file.readAsLinesSync()) {
    final m = namePattern.firstMatch(line.trimLeft());
    if (m != null) {
      final value = m.group(1);
      if (value != null && value.isNotEmpty) return value;
    }
  }
  return null;
}

Future<int?> gitLastCommitEpochSec({
  required String projectRoot,
  required String absoluteDartPath,
}) async {
  final root = p.normalize(projectRoot);
  final abs = p.normalize(absoluteDartPath);
  final rel = p.relative(abs, from: root);
  final proc = await Process.run('git', <String>[
    'log',
    '-1',
    '--format=%ct',
    '--',
    rel,
  ], workingDirectory: root);
  if (proc.exitCode != 0) return null;
  final out = proc.stdout;
  if (out is! String) return null;
  return int.tryParse(out.trim());
}

bool computeTestDriftFlag({
  required double prodDaysSinceCommit,
  required double newestLinkedTestDaysSinceCommit,
}) {
  if (prodDaysSinceCommit < 1 || prodDaysSinceCommit > 30) return false;
  return newestLinkedTestDaysSinceCommit >= prodDaysSinceCommit * 6;
}

Set<String> _resolvedLibImports({
  required String root,
  required String? packageName,
  required String testPath,
  required CompilationUnit unit,
}) {
  final out = <String>{};
  final fromDir = p.dirname(testPath);
  for (final directive in unit.directives) {
    if (directive is! ImportDirective) continue;
    final uri = directive.uri.stringValue;
    if (uri == null || uri.isEmpty) continue;
    final libRel = _resolveImportToLibRelative(
      root: root,
      packageName: packageName,
      fromDir: fromDir,
      uri: uri,
    );
    if (libRel != null) out.add(libRel);
  }
  return out;
}

String? _resolveImportToLibRelative({
  required String root,
  required String? packageName,
  required String fromDir,
  required String uri,
}) {
  if (uri.startsWith('dart:')) return null;
  final pkgMatch = RegExp(r'^package:([^/]+)/(.+)$').firstMatch(uri);
  if (pkgMatch != null) {
    if (packageName == null) return null;
    final pkg = pkgMatch.group(1);
    final underLib = pkgMatch.group(2);
    if (pkg == null || underLib == null) return null;
    if (pkg != packageName) return null;
    return p.join('lib', underLib).replaceAll('\\', '/');
  }
  final abs = p.normalize(p.join(fromDir, uri));
  final libRoot = p.join(root, 'lib');
  if (!abs.startsWith(p.normalize(libRoot))) return null;
  return p.relative(abs, from: root).replaceAll('\\', '/');
}

bool _unitHasNonTrivialAssertion(CompilationUnit unit) {
  final scanner = _NonTrivialAssertionScanner();
  unit.accept(scanner);
  return scanner.found;
}

class _NonTrivialAssertionScanner extends RecursiveAstVisitor<void> {
  bool found = false;

  static const _verifyNames = <String>{
    'verify',
    'verifyNever',
    'verifyInOrder',
    'verifyZeroInteractions',
  };

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final name = node.methodName.name;
    if (_verifyNames.contains(name)) {
      found = true;
    } else if (name == 'expect' || name == 'expectLater') {
      if (_isNonTrivialExpect(node)) {
        found = true;
      }
    } else if (name == 'assert') {
      final args = node.argumentList.arguments;
      if (args.length == 1 && !_isTriviallyTrueExpression(args[0])) {
        found = true;
      }
    }
    super.visitMethodInvocation(node);
  }
}

bool _isNonTrivialExpect(MethodInvocation node) {
  final args = node.argumentList.arguments;
  if (args.isEmpty) return false;
  if (args.length >= 2) {
    final a0 = args[0].toSource().replaceAll(RegExp(r'\s'), '');
    final a1 = args[1].toSource().replaceAll(RegExp(r'\s'), '');
    if (a0 == a1) return false;
  }
  return true;
}

bool _isTriviallyTrueExpression(Expression e) {
  if (e is BooleanLiteral) return e.value;
  if (e is IntegerLiteral) {
    final v = e.value;
    return v == 1 || v == 0;
  }
  if (e is BinaryExpression) {
    final op = e.operator.lexeme;
    if (op == '==' || op == '!=') {
      final l = e.leftOperand;
      final r = e.rightOperand;
      if (l is BooleanLiteral && r is BooleanLiteral) {
        if (op == '==' && l.value == r.value) return true;
      }
      final ls = l.toSource().replaceAll(RegExp(r'\s'), '');
      final rs = r.toSource().replaceAll(RegExp(r'\s'), '');
      if (ls == rs) return true;
    }
  }
  return false;
}
