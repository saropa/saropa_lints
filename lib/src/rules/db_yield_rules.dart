// ignore_for_file: depend_on_referenced_packages, deprecated_member_use, always_specify_types

/// Rules for database and heavy I/O yield patterns in Flutter applications.
///
/// Flutter runs UI and Dart code on the same thread. Long-running database
/// reads/writes or file I/O can block frame rendering, causing visible jank.
/// Inserting `await DelayUtils.yieldToUI()` after heavy operations gives the
/// framework a chance to process pending frames before continuing.
///
/// **Rules in this file:**
///
/// - [RequireYieldBetweenDbAwaitsRule] — flags DB/IO awaits not followed by
///   `yieldToUI()`, which may block the UI thread.
/// - [AvoidReturnAwaitDbRule] — flags `return await dbCall()` where the
///   caller has no opportunity to yield before returning the result.
///
/// **Heuristic approach:** Detection uses method-name and target-name matching
/// rather than static type resolution, because database packages are optional
/// dependencies. This means false positives are possible for identically-named
/// methods in unrelated packages. False negatives occur for custom wrappers
/// that hide the DB call behind an indirection layer.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

// ---------------------------------------------------------------------------
// Shared DB/IO detection helpers
// ---------------------------------------------------------------------------

bool _isDbRelatedAwait(AwaitExpression awaitExpr) {
  final expr = awaitExpr.expression;
  if (expr is! MethodInvocation) return false;
  if (_matchesHeavyIoName(expr.methodName.name)) return true;
  if (expr.target != null && _hasHeavyIoTarget(expr.target!)) return true;
  return false;
}

bool _matchesHeavyIoName(String name) {
  if (name.length >= 2 &&
      name[0] == 'd' &&
      name[1] == 'b' &&
      (name.length == 2 || name[2] == name[2].toUpperCase())) {
    return true;
  }
  const heavyIoMethods = {
    // Isar
    'findAll', 'findFirst', 'writeTxn', 'deleteAll', 'putAll',
    // sqflite
    'rawQuery', 'rawInsert', 'rawUpdate', 'rawDelete',
    // File / asset I/O
    'loadJsonFromAsset', 'readAsString', 'readAsBytes',
    'writeAsString', 'writeAsBytes', 'readAsLines',
  };
  return heavyIoMethods.contains(name);
}

bool _hasHeavyIoTarget(Expression target, [int depth = 0]) {
  // Guard against deeply nested chains (e.g. a.b.c.d.e.f...).
  if (depth > 6) return false;

  if (target is SimpleIdentifier && _knownIoTargets.contains(target.name)) {
    return true;
  }
  if (target is PrefixedIdentifier) {
    return _knownIoTargets.contains(target.prefix.name);
  }
  if (target is MethodInvocation && target.target != null) {
    return _hasHeavyIoTarget(target.target!, depth + 1);
  }
  if (target is PropertyAccess && target.target != null) {
    return _hasHeavyIoTarget(target.target!, depth + 1);
  }
  return false;
}

/// Identifiers that indicate a database or heavy-IO receiver.
const Set<String> _knownIoTargets = {
  'isar',
  'database',
  'db',
  'box',
  'store',
  'collection',
};

bool _isYieldToUI(Statement statement) {
  if (statement is! ExpressionStatement) return false;
  final expr = statement.expression;
  if (expr is! AwaitExpression) return false;
  final inner = expr.expression;
  if (inner is MethodInvocation) {
    return inner.methodName.name == 'yieldToUI' ||
        inner.methodName.name == 'waitWithoutBlocking';
  }
  return false;
}

// ---------------------------------------------------------------------------
// Rule 1: require_yield_between_db_awaits
// ---------------------------------------------------------------------------

/// Warns when a database or I/O `await` is not immediately followed by
/// `yieldToUI()`. See also [AvoidReturnAwaitDbRule] for return-await.
///
/// ```dart
/// // BAD
/// final data = await isar.things.findAll();
/// processData(data);
///
/// // GOOD
/// final data = await isar.things.findAll();
/// await DelayUtils.yieldToUI();
/// processData(data);
/// ```
class RequireYieldBetweenDbAwaitsRule extends SaropaLintRule {
  const RequireYieldBetweenDbAwaitsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_yield_between_db_awaits',
    problemMessage:
        '[require_yield_between_db_awaits] Database/IO await without '
        'yieldToUI() may cause UI jank.',
    correctionMessage: 'Insert `await DelayUtils.yieldToUI();` after this '
        'database/IO operation.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    void visit(FunctionBody body) {
      if (body is BlockFunctionBody) _checkBlock(body.block, reporter);
    }

    context.registry.addMethodDeclaration((n) => visit(n.body));
    context.registry.addFunctionDeclaration(
      (n) => visit(n.functionExpression.body),
    );
  }

  void _checkBlock(Block block, SaropaDiagnosticReporter reporter) {
    final stmts = block.statements;
    for (int i = 0; i < stmts.length; i++) {
      final s = stmts[i];

      // Recurse into nested blocks.
      if (s is TryStatement) {
        _checkBlock(s.body, reporter);
        for (final clause in s.catchClauses) {
          _checkBlock(clause.body, reporter);
        }
        if (s.finallyBlock != null) _checkBlock(s.finallyBlock!, reporter);
        continue;
      }
      if (s is IfStatement) {
        _visitNestedBlock(s.thenStatement, reporter);
        if (s.elseStatement != null) {
          _visitNestedBlock(s.elseStatement!, reporter);
        }
        continue;
      }
      if (s is ForStatement) {
        _visitNestedBlock(s.body, reporter);
        continue;
      }
      if (s is WhileStatement) {
        _visitNestedBlock(s.body, reporter);
        continue;
      }

      final awaitExpr = _extractInlineAwait(s);
      if (awaitExpr == null || !_isDbRelatedAwait(awaitExpr)) continue;
      if (_isFollowedBySafe(stmts, i)) continue;
      reporter.atNode(s, _code);
    }
  }

  void _visitNestedBlock(Statement s, SaropaDiagnosticReporter reporter) {
    if (s is Block) _checkBlock(s, reporter);
  }

  /// Extracts await from expression or variable statements (NOT return).
  static AwaitExpression? _extractInlineAwait(Statement s) {
    if (s is ExpressionStatement && s.expression is AwaitExpression) {
      return s.expression as AwaitExpression;
    }
    if (s is VariableDeclarationStatement) {
      for (final v in s.variables.variables) {
        if (v.initializer is AwaitExpression) {
          return v.initializer as AwaitExpression;
        }
      }
    }
    return null;
  }

  static bool _isFollowedBySafe(List<Statement> stmts, int i) {
    if (i >= stmts.length - 1) return false;
    final next = stmts[i + 1];
    if (_isYieldToUI(next)) return true;
    if (next is ExpressionStatement && next.expression is ThrowExpression) {
      return true;
    }
    return false;
  }

  @override
  List<Fix> getFixes() => [_InsertYieldAfterDbAwaitFix()];
}

// ---------------------------------------------------------------------------
// Rule 2: avoid_return_await_db
// ---------------------------------------------------------------------------

/// Warns on `return await dbCall()` — the caller has no chance to yield.
///
/// ```dart
/// // BAD
/// return await isar.contactDBModels.findFirst();
///
/// // GOOD
/// final contact = await isar.contactDBModels.findFirst();
/// await DelayUtils.yieldToUI();
/// return contact;
/// ```
class AvoidReturnAwaitDbRule extends SaropaLintRule {
  const AvoidReturnAwaitDbRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_return_await_db',
    problemMessage:
        '[avoid_return_await_db] Returning directly from a database/IO '
        'await skips yieldToUI().',
    correctionMessage: 'Save the result to a variable, call '
        '`await DelayUtils.yieldToUI();`, then return the variable.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    void visit(FunctionBody body) {
      if (body is BlockFunctionBody) _checkBlock(body.block, reporter);
    }

    context.registry.addMethodDeclaration((n) => visit(n.body));
    context.registry.addFunctionDeclaration(
      (n) => visit(n.functionExpression.body),
    );
  }

  void _checkBlock(Block block, SaropaDiagnosticReporter reporter) {
    for (final s in block.statements) {
      // Recurse into nested blocks.
      if (s is TryStatement) {
        _checkBlock(s.body, reporter);
        for (final clause in s.catchClauses) {
          _checkBlock(clause.body, reporter);
        }
        if (s.finallyBlock != null) _checkBlock(s.finallyBlock!, reporter);
        continue;
      }
      if (s is IfStatement) {
        _visitNestedBlock(s.thenStatement, reporter);
        if (s.elseStatement != null) {
          _visitNestedBlock(s.elseStatement!, reporter);
        }
        continue;
      }
      if (s is ForStatement) {
        _visitNestedBlock(s.body, reporter);
        continue;
      }
      if (s is WhileStatement) {
        _visitNestedBlock(s.body, reporter);
        continue;
      }

      if (s is! ReturnStatement) continue;
      final expr = s.expression;
      if (expr is! AwaitExpression) continue;
      if (!_isDbRelatedAwait(expr)) continue;
      reporter.atNode(s, _code);
    }
  }

  void _visitNestedBlock(Statement s, SaropaDiagnosticReporter reporter) {
    if (s is Block) _checkBlock(s, reporter);
  }

  @override
  List<Fix> getFixes() => [_SplitReturnAwaitDbFix()];
}

// ---------------------------------------------------------------------------
// Quick Fixes
// ---------------------------------------------------------------------------

/// Inserts `await DelayUtils.yieldToUI();` after the flagged DB/IO await.
class _InsertYieldAfterDbAwaitFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addMethodDeclaration((node) {
      _tryFix(node.body, resolver, reporter, analysisError);
    });
    context.registry.addFunctionDeclaration((node) {
      _tryFix(node.functionExpression.body, resolver, reporter, analysisError);
    });
  }

  void _tryFix(
    FunctionBody body,
    CustomLintResolver resolver,
    ChangeReporter reporter,
    AnalysisError analysisError,
  ) {
    if (body is! BlockFunctionBody) return;
    for (final s in body.block.statements) {
      if (!s.sourceRange.intersects(analysisError.sourceRange)) continue;

      final source = resolver.source.contents.data;
      final indent = _leadingWhitespace(source, s.offset);

      final changeBuilder = reporter.createChangeBuilder(
        message: 'Insert await DelayUtils.yieldToUI()',
        priority: 80,
      );
      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          s.end,
          '\n${indent}await DelayUtils.yieldToUI();',
        );
      });
      return;
    }
  }
}

/// Splits `return await dbCall();` into variable + yield + return.
class _SplitReturnAwaitDbFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addMethodDeclaration((node) {
      _tryFix(node.body, resolver, reporter, analysisError);
    });
    context.registry.addFunctionDeclaration((node) {
      _tryFix(node.functionExpression.body, resolver, reporter, analysisError);
    });
  }

  void _tryFix(
    FunctionBody body,
    CustomLintResolver resolver,
    ChangeReporter reporter,
    AnalysisError analysisError,
  ) {
    if (body is! BlockFunctionBody) return;
    for (final s in body.block.statements) {
      if (!s.sourceRange.intersects(analysisError.sourceRange)) continue;
      if (s is! ReturnStatement) continue;
      final awaitExpr = s.expression;
      if (awaitExpr is! AwaitExpression) continue;

      final source = resolver.source.contents.data;
      final indent = _leadingWhitespace(source, s.offset);
      final awaitSource = awaitExpr.toSource();

      final changeBuilder = reporter.createChangeBuilder(
        message: 'Save to variable, yield, then return',
        priority: 80,
      );
      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          s.sourceRange,
          'final result = $awaitSource;\n'
          '${indent}await DelayUtils.yieldToUI();\n'
          '${indent}return result;',
        );
      });
      return;
    }
  }
}

/// Returns the leading whitespace for the line containing [offset].
String _leadingWhitespace(String source, int offset) {
  int lineStart = offset;
  while (lineStart > 0 && source[lineStart - 1] != '\n') {
    lineStart--;
  }
  final leading = source.substring(lineStart, offset);
  // Return only whitespace characters.
  final match = RegExp(r'^(\s*)').firstMatch(leading);
  return match?.group(1) ?? '';
}
