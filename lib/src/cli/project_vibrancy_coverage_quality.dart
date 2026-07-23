import 'dart:io';
import 'dart:math' as math;

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

/// Dart files under `bin/` (absolute paths). CLI entry points call into
/// lib/ functions; without these in the usage set, functions whose only
/// caller is a bin/ script are falsely flagged `unused`.
List<String> listProjectBinDartPaths(String root) {
  final dir = Directory(p.join(root, 'bin'));
  if (!dir.existsSync()) return const <String>[];
  final out = <String>[];
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is! File) continue;
    final path = p.normalize(entity.path);
    if (!path.endsWith('.dart')) continue;
    out.add(path);
  }
  out.sort();
  return out;
}

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

/// Age score from a function's median blame-line age: 100 for code touched
/// today decaying exponentially to ~37 at one year; 50 when no git history
/// covers the span (unknown age is scored neutral, not fresh or stale).
///
/// BUG FIX (2026-07-16): the previous in-place formula was `e * -days / 365`
/// — a hand-rolled exponential decay written as multiplication BY the
/// constant e, which is negative for every positive age and clamped to 0, so
/// ageScore was uniformly 0 on any project with git history.
double ageScoreFromDays(double? days) {
  if (days == null) return 50.0;
  return (100.0 * math.exp(-days / 365.0)).clamp(0.0, 100.0);
}

/// Flags recently rewritten complex code — the validated "fresh_code" signal.
///
/// Validated against a 29-incident corpus of rule-bug fixes mined from this
/// repo's own history (plans/PLAN_vibrancy_flight_risk_scoring.md, Findings,
/// hardened instrument 2026-07-16): offending functions were markedly YOUNGER
/// than the surrounding pool (age-alone median percentile 33.9 — below 50
/// means young code, not old, caused incidents), and recency-times-complexity
/// was the equal-best predictor tested (median percentile 67.9 vs 65.3 for
/// complexity-alone, with the most top-decile hits, 9/29 — the difference is
/// not statistically significant at n=29, so the claim is "as good as the
/// best baseline while carrying recency information complexity misses", not
/// "proven better"). The elaborate multiplicative flight-risk composite was
/// significantly WORSE than complexity-alone (p ~ 0.05) and stays unshipped
/// behind its research gate.
///
/// Thresholds: 90 days matches the churn window the validation used;
/// complexity > 10 matches the existing `complex` flag so the pair reads as
/// "complex AND fresh". Null age (no git history for the span) never flags —
/// absence of history is not evidence of freshness.
bool computeFreshCodeFlag({
  required double? medianAgeDays,
  required int complexity,
}) {
  if (medianAgeDays == null) return false;
  return medianAgeDays <= 90 && complexity > 10;
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
