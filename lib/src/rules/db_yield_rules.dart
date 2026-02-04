// ignore_for_file: depend_on_referenced_packages, deprecated_member_use, always_specify_types

/// Rules for database and heavy I/O yield patterns in Flutter applications.
///
/// Flutter runs UI and Dart code on the same thread. Long-running database
/// writes or heavy I/O can block frame rendering, causing visible jank.
/// Inserting `await DelayUtils.yieldToUI()` after heavy operations gives the
/// framework a chance to process pending frames before continuing.
///
/// **Rules in this file:**
///
/// - [RequireYieldAfterDbWriteRule] — WARNING: flags DB/IO *write* awaits not
///   followed by `yieldToUI()`, which hold exclusive locks and block the UI.
/// - [SuggestYieldAfterDbReadRule] — INFO: flags DB/IO *bulk read* awaits not
///   followed by `yieldToUI()`, which may cause jank during deserialization.
///   Single reads (`findFirst`) are excluded.
/// - [AvoidReturnAwaitDbRule] — WARNING: flags `return await dbWriteCall()`
///   where the caller has no opportunity to yield before returning. Read
///   operations are excluded.
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
// Shared DB/IO classification
// ---------------------------------------------------------------------------

/// Classifies a database or I/O operation by its impact on the UI thread.
enum _DbOperationType {
  /// Exclusive-lock operations: writeTxn, putAll, deleteAll, rawInsert, etc.
  write,

  /// CPU-bound bulk reads: findAll, rawQuery, readAsString, readAsBytes, etc.
  bulkRead,

  /// Fast single-object reads: findFirst.
  singleRead,
}

/// Classifies the awaited expression as a DB/IO operation, or returns `null`
/// if the expression is not recognised as a heavy I/O call.
_DbOperationType? _classifyDbAwait(AwaitExpression awaitExpr) {
  final expr = awaitExpr.expression;
  if (expr is! MethodInvocation) return null;
  final name = expr.methodName.name;

  // 1. Check explicit method names.
  final explicit = _classifyExplicitMethod(name);
  if (explicit != null) return explicit;

  // 2. Check db* prefix pattern (e.g. dbContactSave, dbFetchAll).
  if (_isDbPrefix(name)) return _classifyByHeuristic(name);

  // 3. Check if the target is a known IO object (isar, database, etc.).
  if (expr.target != null && _hasHeavyIoTarget(expr.target!)) {
    return _classifyByHeuristic(name);
  }

  return null;
}

// -- Explicit method classification ----------------------------------------

const Set<String> _writeMethods = {
  // Isar
  'writeTxn', 'deleteAll', 'putAll',
  // sqflite
  'rawInsert', 'rawUpdate', 'rawDelete',
  // File I/O
  'writeAsString', 'writeAsBytes',
};

const Set<String> _bulkReadMethods = {
  // Isar
  'findAll',
  // sqflite
  'rawQuery',
  // File / asset I/O
  'readAsString', 'readAsBytes', 'readAsLines', 'loadJsonFromAsset',
};

const Set<String> _singleReadMethods = {'findFirst'};

_DbOperationType? _classifyExplicitMethod(String name) {
  if (_writeMethods.contains(name)) return _DbOperationType.write;
  if (_bulkReadMethods.contains(name)) return _DbOperationType.bulkRead;
  if (_singleReadMethods.contains(name)) return _DbOperationType.singleRead;
  return null;
}

// -- db* prefix and heuristic classification -------------------------------

/// Returns `true` if [name] matches the `db*` prefix convention
/// (e.g. `dbContactSave`, `dbFetchAll`).
bool _isDbPrefix(String name) {
  return name.length >= 2 &&
      name[0] == 'd' &&
      name[1] == 'b' &&
      (name.length == 2 || name[2] == name[2].toUpperCase());
}

/// Heuristic: classify a method name by looking for write- or read-like
/// substrings. Falls back to [_DbOperationType.write] (safer to yield).
_DbOperationType _classifyByHeuristic(String name) {
  final lower = name.toLowerCase();
  for (final kw in _writeKeywords) {
    if (lower.contains(kw)) return _DbOperationType.write;
  }
  for (final kw in _readKeywords) {
    if (lower.contains(kw)) return _DbOperationType.bulkRead;
  }
  // Unknown — default to write (safer to yield than not).
  return _DbOperationType.write;
}

const List<String> _writeKeywords = [
  'save',
  'add',
  'put',
  'delete',
  'remove',
  'update',
  'write',
  'insert',
];

const List<String> _readKeywords = [
  'load',
  'get',
  'find',
  'read',
  'fetch',
  'query',
  'count',
  'list',
  'stream',
];

// -- Target detection ------------------------------------------------------

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

// -- Statement helpers -----------------------------------------------------

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

/// Recursively walks [block] and invokes [onStatement] for each
/// non-control-flow statement. Control-flow statements (try, if, for, while)
/// are recursed into automatically.
// cspell:ignore stmts
void _visitStatementsRecursive(
  Block block,
  void Function(List<Statement> stmts, int i) onStatement,
) {
  final stmts = block.statements;
  for (int i = 0; i < stmts.length; i++) {
    final s = stmts[i];

    if (s is TryStatement) {
      _visitStatementsRecursive(s.body, onStatement);
      for (final clause in s.catchClauses) {
        _visitStatementsRecursive(clause.body, onStatement);
      }
      if (s.finallyBlock != null) {
        _visitStatementsRecursive(s.finallyBlock!, onStatement);
      }
      continue;
    }
    if (s is IfStatement) {
      final then = s.thenStatement;
      if (then is Block) _visitStatementsRecursive(then, onStatement);
      final elseS = s.elseStatement;
      if (elseS is Block) _visitStatementsRecursive(elseS, onStatement);
      continue;
    }
    if (s is ForStatement) {
      final body = s.body;
      if (body is Block) _visitStatementsRecursive(body, onStatement);
      continue;
    }
    if (s is WhileStatement) {
      final body = s.body;
      if (body is Block) _visitStatementsRecursive(body, onStatement);
      continue;
    }

    onStatement(stmts, i);
  }
}

/// Extracts await from expression or variable statements (NOT return).
AwaitExpression? _extractInlineAwait(Statement s) {
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

bool _isFollowedBySafe(List<Statement> stmts, int i) {
  if (i >= stmts.length - 1) return false;
  final next = stmts[i + 1];
  if (_isYieldToUI(next)) return true;
  if (next is ExpressionStatement && next.expression is ThrowExpression) {
    return true;
  }
  return false;
}

// ---------------------------------------------------------------------------
// Rule 1: require_yield_after_db_write (WARNING)
// ---------------------------------------------------------------------------

/// Warns when a database or I/O **write** `await` is not immediately followed
/// by `yieldToUI()`.
///
/// Write operations (`writeTxn`, `putAll`, `deleteAll`, `rawInsert`, etc.)
/// acquire exclusive locks that block both the UI thread and other write
/// transactions. A yield after the write releases the Dart event loop so
/// the framework can paint pending frames.
///
/// ```dart
/// // BAD
/// await isar.writeTxn(() => isar.contacts.putAll(contacts));
/// processData();
///
/// // GOOD
/// await isar.writeTxn(() => isar.contacts.putAll(contacts));
/// await DelayUtils.yieldToUI();
/// processData();
/// ```
class RequireYieldAfterDbWriteRule extends SaropaLintRule {
  const RequireYieldAfterDbWriteRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_yield_after_db_write',
    problemMessage:
        '[require_yield_after_db_write] Database or I/O write without a '
        'following yieldToUI() call may block the UI thread and cause visible '
        'frame drops. Write operations acquire exclusive locks that starve '
        'the framework of time to paint.',
    correctionMessage:
        'Insert `await DelayUtils.yieldToUI();` after this write operation '
        'to give the framework a chance to process pending frames.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    _registerYieldCheck(context, reporter, _code, _DbOperationType.write);
  }

  @override
  List<Fix> getFixes() => [_InsertYieldAfterDbWriteFix()];
}

// ---------------------------------------------------------------------------
// Rule 2: suggest_yield_after_db_read (INFO)
// ---------------------------------------------------------------------------

/// Suggests inserting `yieldToUI()` after a database or I/O **bulk read**.
///
/// Bulk reads (`findAll`, `rawQuery`, `readAsString`, etc.) can block the
/// UI during deserialization of large payloads. A yield is helpful but
/// situational, so this is reported as INFO rather than WARNING.
///
/// **Excluded:** `findFirst` — a single-object read is fast and does not
/// benefit from a yield. Adding one introduces unnecessary latency and
/// a stale-data window.
///
/// ```dart
/// // INFO (suggestion)
/// final all = await isar.contacts.findAll();
/// processData(all);
///
/// // OK — findFirst is excluded
/// final c = await isar.contacts.filter().idEqualTo(id).findFirst();
/// ```
class SuggestYieldAfterDbReadRule extends SaropaLintRule {
  const SuggestYieldAfterDbReadRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'suggest_yield_after_db_read',
    problemMessage:
        '[suggest_yield_after_db_read] Bulk database or I/O read without a '
        'following yieldToUI() call. Deserializing large payloads on the '
        'main isolate can cause frame drops during data-heavy workflows.',
    correctionMessage:
        'Consider inserting `await DelayUtils.yieldToUI();` after this read '
        'if the result set may be large.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    _registerYieldCheck(context, reporter, _code, _DbOperationType.bulkRead);
  }

  @override
  List<Fix> getFixes() => [_InsertYieldAfterDbReadFix()];
}

/// Shared registration logic for yield-checking rules.
void _registerYieldCheck(
  CustomLintContext context,
  SaropaDiagnosticReporter reporter,
  LintCode code,
  _DbOperationType targetType,
) {
  void visit(FunctionBody body) {
    if (body is! BlockFunctionBody) return;
    _visitStatementsRecursive(body.block, (stmts, i) {
      final s = stmts[i];
      final awaitExpr = _extractInlineAwait(s);
      if (awaitExpr == null) return;
      final opType = _classifyDbAwait(awaitExpr);
      if (opType != targetType) return;
      if (_isFollowedBySafe(stmts, i)) return;
      reporter.atNode(s, code);
    });
  }

  context.registry.addMethodDeclaration((n) => visit(n.body));
  context.registry.addFunctionDeclaration(
    (n) => visit(n.functionExpression.body),
  );
}

// ---------------------------------------------------------------------------
// Rule 3: avoid_return_await_db (WARNING — writes only)
// ---------------------------------------------------------------------------

/// Warns on `return await dbWriteCall()` — the caller has no chance to yield.
///
/// Only write operations are flagged. Reads (`findFirst`, `findAll`, etc.)
/// do not need a yield before returning.
///
/// ```dart
/// // BAD — write, no chance to yield
/// return await isar.writeTxn(() => isar.contacts.putAll(contacts));
///
/// // GOOD
/// final result = await isar.writeTxn(() => isar.contacts.putAll(contacts));
/// await DelayUtils.yieldToUI();
/// return result;
///
/// // OK — read, no yield needed
/// return await isar.contacts.filter().idEqualTo(id).findFirst();
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
        'write skips yieldToUI().',
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
      if (body is! BlockFunctionBody) return;
      _visitStatementsRecursive(body.block, (stmts, i) {
        final s = stmts[i];
        if (s is! ReturnStatement) return;
        final expr = s.expression;
        if (expr is! AwaitExpression) return;
        final opType = _classifyDbAwait(expr);
        if (opType != _DbOperationType.write) return;
        reporter.atNode(s, _code);
      });
    }

    context.registry.addMethodDeclaration((n) => visit(n.body));
    context.registry.addFunctionDeclaration(
      (n) => visit(n.functionExpression.body),
    );
  }

  @override
  List<Fix> getFixes() => [_SplitReturnAwaitDbFix()];
}

// ---------------------------------------------------------------------------
// Quick Fixes
// ---------------------------------------------------------------------------

/// Inserts `await DelayUtils.yieldToUI();` after a flagged DB write.
class _InsertYieldAfterDbWriteFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    _insertYieldFix(
      resolver,
      reporter,
      context,
      analysisError,
      'Insert yieldToUI() after this database write',
    );
  }
}

/// Inserts `await DelayUtils.yieldToUI();` after a flagged DB bulk read.
class _InsertYieldAfterDbReadFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    _insertYieldFix(
      resolver,
      reporter,
      context,
      analysisError,
      'Insert yieldToUI() after this database read',
    );
  }
}

/// Shared logic for inserting a yieldToUI() call after the flagged statement.
void _insertYieldFix(
  CustomLintResolver resolver,
  ChangeReporter reporter,
  CustomLintContext context,
  AnalysisError analysisError,
  String message,
) {
  void tryFix(FunctionBody body) {
    if (body is! BlockFunctionBody) return;
    for (final s in body.block.statements) {
      if (!s.sourceRange.intersects(analysisError.sourceRange)) continue;

      final source = resolver.source.contents.data;
      final indent = _leadingWhitespace(source, s.offset);

      final changeBuilder = reporter.createChangeBuilder(
        message: message,
        priority: 80,
      );
      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          s.end,
          '\n'
          '\n$indent// Let the UI catch up to reduce locks'
          '\n${indent}await DelayUtils.yieldToUI();\n',
        );
      });
      return;
    }
  }

  context.registry.addMethodDeclaration((node) => tryFix(node.body));
  context.registry.addFunctionDeclaration(
    (node) => tryFix(node.functionExpression.body),
  );
}

/// Splits `return await dbWriteCall();` into variable + yield + return.
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
