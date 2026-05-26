/// Counts "stub" tests per file: `test(...)` / `testWidgets(...)` bodies that
/// contain no assertion (no `expect`/`expectLater`/`verify`/`check` call and no
/// `assert`). Such tests pass without verifying anything — coverage they earn is
/// misleading. Heuristic (parsed AST, name-based); a custom matcher wrapper can
/// hide an assertion, so treat as a signal, not a verdict.
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;

const Set<String> _testFns = {'test', 'testWidgets'};
const Set<String> _assertionFns = {
  'expect',
  'expectLater',
  'verify',
  'verifyNever',
  'verifyInOrder',
  'check',
};

/// Returns project-relative posix path → stub-test count for files under `test/`.
/// Only files with at least one stub appear.
Map<String, int> scanStubTests(String projectPath) {
  final root = Directory(p.join(projectPath, 'test'));
  if (!root.existsSync()) return const {};
  final result = <String, int>{};
  for (final entity in root.listSync(recursive: true, followLinks: false)) {
    if (entity is! File || !entity.path.endsWith('_test.dart')) continue;
    final count = stubCountIn(entity.readAsStringSync());
    if (count > 0) {
      final rel = p
          .relative(entity.path, from: projectPath)
          .replaceAll('\\', '/');
      result[rel] = count;
    }
  }
  return result;
}

/// Counts assertion-free `test`/`testWidgets` bodies in [content].
int stubCountIn(String content) {
  final unit = parseString(content: content, throwIfDiagnostics: false).unit;
  final visitor = _StubVisitor();
  unit.visitChildren(visitor);
  return visitor.stubs;
}

class _StubVisitor extends RecursiveAstVisitor<void> {
  int stubs = 0;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (_testFns.contains(node.methodName.name)) {
      final callback = node.argumentList.arguments
          .whereType<FunctionExpression>()
          .firstOrNull;
      if (callback != null && !_hasAssertion(callback.body)) stubs++;
    }
    node.visitChildren(this);
  }
}

bool _hasAssertion(AstNode body) {
  final detector = _AssertionDetector();
  body.accept(detector);
  return detector.found;
}

class _AssertionDetector extends RecursiveAstVisitor<void> {
  bool found = false;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (_assertionFns.contains(node.methodName.name)) found = true;
    if (!found) node.visitChildren(this);
  }

  @override
  void visitAssertStatement(AssertStatement node) => found = true;
}
