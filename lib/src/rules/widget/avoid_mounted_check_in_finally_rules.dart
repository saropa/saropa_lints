import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../../saropa_lint_rule.dart';
import '../../target_matcher_utils.dart'
    show extractTargetName, isWidgetOrStateClass;

// =============================================================================
// avoid_mounted_check_in_finally
// =============================================================================
//
// PREMISE CORRECTION (v2) — READ BEFORE EDITING THIS FILE.
//
// v1 of this rule flagged ANY `if (mounted) { setState(...); }` sitting inside
// a `finally` block, and its correctionMessage told authors to move the guard
// out to a statement AFTER the try/finally. That advice was wrong and actively
// harmful. Verified empirically against the Dart VM (throwaway program, run
// 2026-09-04): when the try body throws and there is no catch clause, the
// `finally` block runs and the exception then keeps propagating — the
// statements written after the try/finally NEVER execute. Observed output:
//
//   A: try body start
//   A: finally ran
//   caseA propagated: Bad state: A boom      <- "AFTER try/finally" never ran
//   B: try body start
//   B: finally ran (guarded update would run here)
//
// The analyzer independently agrees: the statement after the try/finally is
// reported as `dead_code`. So the v1 "GOOD" example loses the state reset on
// every error path (`_isLoading` stuck true forever), while the v1 "BAD"
// example — the guarded update inside `finally` — is the correct, idiomatic,
// error-resilient shape. v1 punished correct code.
//
// v2 therefore keeps the rule name (consumers' tier config and any `// ignore:`
// comments reference it) but retargets detection at a pattern that IS genuinely
// broken: an ORDERING bug inside the `finally` block. When a `finally` block
// makes an UNGUARDED widget-mutating call and then, further down the SAME
// block, guards a later call with `mounted`, the guard proves the author knew
// the async gap existed — and the earlier call already ran and already threw.
// That is a real crash, not a style preference.
// =============================================================================

/// Flags a widget-mutating call that runs UNGUARDED inside a `finally` block
/// which later guards a sibling call with `mounted` — an ordering bug where
/// the guard was placed too far down the block.
///
/// A `mounted` guard inside `finally` is CORRECT and encouraged: `finally`
/// runs on both the success and the exception path, so it is the only place a
/// "reset the spinner no matter what happened" update can live. (Moving it
/// after the try/finally, as this rule wrongly advised in v1, makes it
/// unreachable whenever the try body throws — verified against the Dart VM;
/// the analyzer reports such a trailing statement as `dead_code`.)
///
/// What is broken is a `finally` block that mixes both styles: an unguarded
/// `setState` / `Navigator` / `ScaffoldMessenger` call, followed by a
/// `mounted`-guarded call in the same block. The later guard is evidence that
/// the author knew the widget could already be disposed — the earlier,
/// unguarded call is then a straight crash on the disposed path. Hoist the
/// guard above the first unsafe call (or move that call inside the existing
/// guard) so the whole block is protected.
///
/// Since: v14.3.4 | Updated: v14.3.4 | Rule version: v2
///
/// **BAD:**
/// ```dart
/// Future<void> _submit() async {
///   try {
///     await _api.submit(_formData);
///   } finally {
///     setState(() => _isLoading = false); // LINT — unguarded, crashes if disposed
///     if (mounted) {
///       Navigator.of(context).pop(); // The author knew disposal was possible
///     }
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Future<void> _submit() async {
///   try {
///     await _api.submit(_formData);
///   } finally {
///     _controller.dispose(); // Plain cleanup — safe when unmounted
///     if (mounted) {
///       // One guard covering every widget-tree operation in the block.
///       setState(() => _isLoading = false);
///       Navigator.of(context).pop();
///     }
///   }
/// }
/// ```
class AvoidMountedCheckInFinallyRule extends SaropaLintRule {
  AvoidMountedCheckInFinallyRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'flutter', 'widget', 'async'};

  @override
  RuleCost get cost => RuleCost.low;

  // Cheap pre-parse skip: a violation always spells the `mounted` identifier
  // literally (the trailing guard is part of the pattern), so a file without
  // that substring can never contain one.
  @override
  Set<String>? get requiredPatterns => const {'mounted'};

  // `mounted` only exists on Flutter's State/Widget lifecycle types — pure
  // Dart files can never contain this pattern.
  @override
  bool get requiresFlutterImport => true;

  static const LintCode _code = LintCode(
    'avoid_mounted_check_in_finally',
    '[avoid_mounted_check_in_finally] This widget-tree operation runs '
        'UNGUARDED inside a `finally` block, but a later statement in the '
        'same block is guarded by `mounted`. The `finally` block runs on the '
        'exception path too, after an `await` that may have outlived the '
        'widget, so this earlier call executes against a possibly-disposed '
        'State and throws — while the guard below shows the author already '
        'knew disposal was possible. The guard was simply placed too far '
        'down the block. {v2}',
    correctionMessage:
        'Hoist the existing `mounted` guard above this call '
        '(or move this call inside that guard) so every widget-tree '
        'operation in the finally block is covered by one check. Keep the '
        'guard inside `finally` — code placed after the try/finally never '
        'runs when the try body throws.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Entry point is still the `mounted` guard: it is the cheap, distinctive
    // anchor. But it is now the EVIDENCE of author intent, not the defect —
    // the defect is the unguarded sibling reported below it.
    context.addIfStatement((IfStatement node) {
      // Must be a direct `mounted` / `!mounted` test — compound conditions
      // (`if (mounted && x)`) are intentionally out of scope: narrowing to
      // the exact shape avoids guessing at the semantics of an arbitrary
      // boolean expression.
      if (!_isMountedCheck(node.expression)) return;

      // The guard must be a DIRECT statement of a `finally` block. Requiring
      // direct membership (rather than mere descendance) is what makes the
      // "statements before it in the same list" ordering argument sound, and
      // it also excludes guards nested inside a closure or a deeper block,
      // whose execution order relative to the block's statements is not a
      // simple lexical one.
      final Block? finallyBlock = _directlyEnclosingFinallyBlock(node);
      if (finallyBlock == null) return;

      final TryStatement tryStatement = finallyBlock.parent! as TryStatement;

      // No async gap means nothing can have disposed the widget mid-flight,
      // so an unguarded call in `finally` is not the bug this rule targets.
      // Awaits are looked for in this try statement AND in every ENCLOSING
      // try statement (v1 bug: only the innermost try was inspected, so an
      // inner `finally` whose guard protects against an OUTER await's async
      // gap was missed entirely). Only awaits that lexically precede the
      // finally block count — an await written after it cannot have run.
      if (!_hasPrecedingAsyncGap(tryStatement, finallyBlock.offset)) return;

      // Must be inside a State (or State-like: ConsumerState, etc.) class —
      // `mounted` is only meaningful on Flutter's widget lifecycle types.
      final ClassDeclaration? classDecl = node
          .thisOrAncestorOfType<ClassDeclaration>();
      if (classDecl == null || !isWidgetOrStateClass(classDecl)) return;

      // The guard must itself protect a widget-tree operation. A guard that
      // only logs is not evidence that the author was reasoning about
      // disposal safety, so it cannot convict an earlier sibling.
      if (!_guardsUnsafeOperation(node)) return;

      // The actual defect: the first unguarded widget-tree operation written
      // ABOVE the guard in the same block. Reported at that statement, not at
      // the guard, because the guard is the correct code.
      final Statement? offender = _firstUnguardedUnsafeSibling(
        finallyBlock,
        node,
      );
      if (offender == null) return;

      reporter.atNode(offender);
    });
  }

  /// True for `mounted` or `!mounted` (optionally parenthesized), matching
  /// exactly the two guard shapes in scope. Structural check — no string
  /// matching on the condition's source text.
  static bool _isMountedCheck(Expression expr) {
    if (expr is ParenthesizedExpression) {
      return _isMountedCheck(expr.expression);
    }
    if (expr is SimpleIdentifier) return expr.name == 'mounted';
    if (expr is PrefixExpression && expr.operator.type == TokenType.BANG) {
      return _isMountedCheck(expr.operand);
    }
    return false;
  }

  /// Returns the `finally` [Block] when [node] is one of its DIRECT
  /// statements, else null. Direct membership is required so that "statements
  /// before this one in the same list" is a true statement about execution
  /// order.
  static Block? _directlyEnclosingFinallyBlock(Statement node) {
    final AstNode? block = node.parent;
    if (block is! Block) return null;
    final AstNode? tryStatement = block.parent;
    if (tryStatement is! TryStatement) return null;
    // A Block whose parent is a TryStatement is either its body or its
    // finallyBlock; only the latter qualifies.
    return identical(tryStatement.finallyBlock, block) ? block : null;
  }

  /// True when an `await` that lexically precedes [beforeOffset] exists in
  /// [tryStatement] or in any ENCLOSING try statement within the same
  /// function body.
  ///
  /// The enclosing walk fixes a v1 false negative: for
  /// `try { await x(); try { y(); } finally { /* guard */ } } finally { }`
  /// the inner try contains no await of its own, yet the outer `await`
  /// already opened the async gap the inner guard is protecting against.
  /// The walk stops at the first [FunctionBody] because a try in an enclosing
  /// closure belongs to a different invocation.
  static bool _hasPrecedingAsyncGap(
    TryStatement tryStatement,
    int beforeOffset,
  ) {
    AstNode? current = tryStatement;
    while (current != null) {
      if (current is TryStatement &&
          _containsAwait(current, beforeOffset: beforeOffset)) {
        return true;
      }
      if (current is FunctionBody) break;
      current = current.parent;
    }
    return false;
  }

  /// True when [tryStatement]'s `try` body OR any of its `catch` clauses
  /// contains an `await` expression starting before [beforeOffset], not
  /// descending into nested closures (an await inside a nested function
  /// literal opens its own async gap, unrelated to this try/finally's
  /// lifecycle risk).
  ///
  /// Catch clauses matter because a recovery path
  /// (`catch (e) { await recover(); }`) crosses the same kind of async gap as
  /// the try body does, and control still falls into the same `finally`
  /// afterward. The offset bound matters for the enclosing-try walk: an
  /// `await` written after the inner try cannot have run before its finally.
  static bool _containsAwait(
    TryStatement tryStatement, {
    required int beforeOffset,
  }) {
    final visitor = _AwaitVisitor(beforeOffset: beforeOffset);
    tryStatement.body.accept(visitor);
    if (visitor.found) return true;
    for (final CatchClause catchClause in tryStatement.catchClauses) {
      catchClause.body.accept(visitor);
      if (visitor.found) return true;
    }
    return false;
  }

  /// Method names that mutate widget state or the navigation/overlay stack
  /// — the operations that are genuinely unsafe to run after a widget has
  /// been disposed. Kept as an explicit allow-list rather than any form of
  /// substring matching, per the false-positive doctrine.
  static const Set<String> _unsafeMethodNames = {
    'setState',
    'showDialog',
    'showModalBottomSheet',
    'showBottomSheet',
    'showMenu',
    'showGeneralDialog',
    'showSnackBar',
    'showLicensePage',
  };

  /// Type/target names whose method calls (`Navigator.of(context).pop()`,
  /// `ScaffoldMessenger.of(context)...`) mutate the widget tree or overlay
  /// stack and are unsafe once the widget is unmounted.
  static const Set<String> _unsafeTargetNames = {
    'Navigator',
    'ScaffoldMessenger',
  };

  /// True when the guard on [ifStatement] actually protects a widget-tree
  /// operation — the evidence that the author was reasoning about disposal.
  ///
  /// Two shapes are checked:
  ///  1. `if (mounted) { setState(...); }` — the unsafe call lives directly
  ///     inside the if's `then`/`else` branch.
  ///  2. `if (!mounted) return; setState(...);` — the early-return guard
  ///     clause, where the unsafe call is a SIBLING statement that follows
  ///     the if in the same block, only reachable when the guard does not
  ///     exit.
  static bool _guardsUnsafeOperation(IfStatement ifStatement) {
    final thenVisitor = _UnsafeOperationVisitor();
    ifStatement.thenStatement.accept(thenVisitor);
    if (thenVisitor.found) return true;

    final elseVisitor = _UnsafeOperationVisitor();
    ifStatement.elseStatement?.accept(elseVisitor);
    if (elseVisitor.found) return true;

    // Shape 2 only applies when the then-branch unconditionally exits and
    // there is no else — the classic "if (!mounted) return;" guard clause.
    if (ifStatement.elseStatement != null ||
        !_isExitStatement(ifStatement.thenStatement)) {
      return false;
    }
    return _followingSiblingsGuardUnsafeOperation(ifStatement);
  }

  /// True when [statement] unconditionally exits the enclosing block:
  /// a bare `return`/`break`/`continue`, or a `{ }` block containing only
  /// one of those as its final statement.
  static bool _isExitStatement(Statement statement) {
    final Statement inner =
        statement is Block && statement.statements.length == 1
        ? statement.statements.single
        : statement;
    return inner is ReturnStatement ||
        inner is BreakStatement ||
        inner is ContinueStatement;
  }

  /// Scans the statements that follow [ifStatement] in its enclosing block
  /// for an unsafe operation — the code path that only runs when the guard
  /// clause above did NOT exit.
  static bool _followingSiblingsGuardUnsafeOperation(IfStatement ifStatement) {
    final AstNode? parent = ifStatement.parent;
    if (parent is! Block) return false;
    final int index = parent.statements.indexOf(ifStatement);
    if (index == -1) return false;

    final visitor = _UnsafeOperationVisitor();
    for (final Statement sibling in parent.statements.skip(index + 1)) {
      sibling.accept(visitor);
      if (visitor.found) return true;
    }
    return false;
  }

  /// Returns the first statement in [finallyBlock] that appears BEFORE
  /// [guard] and performs a widget-tree operation without any `mounted`
  /// protection of its own — the actual defect this rule reports.
  ///
  /// Returns null (no violation) when:
  ///  * no preceding statement touches the widget tree — the ordinary,
  ///    correct `finally { cleanup(); if (mounted) { setState(); } }` shape;
  ///  * a preceding statement is itself a `mounted` guard, in which case the
  ///    block is already reasoning about disposal correctly and any nested
  ///    unsafe call is protected;
  ///  * a preceding statement is an `if (!mounted) return;`-style early
  ///    return, which protects everything after it, including [guard].
  static Statement? _firstUnguardedUnsafeSibling(
    Block finallyBlock,
    IfStatement guard,
  ) {
    for (final Statement statement in finallyBlock.statements) {
      // Stop at the guard: statements after it are not part of the ordering
      // bug (they are either inside the guard or a separate concern).
      if (identical(statement, guard)) return null;

      // A preceding `mounted` guard means the block already protects itself;
      // for `if (!mounted) return;` everything below is protected outright,
      // and for `if (mounted) { ... }` the unsafe work is inside the guard.
      // Either way, no unguarded call has been established, and no later
      // statement can be convicted, so bail out entirely.
      if (statement is IfStatement && _isMountedCheck(statement.expression)) {
        return null;
      }

      final visitor = _UnsafeOperationVisitor();
      statement.accept(visitor);
      if (visitor.found) return statement;
    }
    return null;
  }
}

/// Finds an `await` starting before [beforeOffset]. Stops at nested
/// closures/function bodies so an `await` inside a nested callback is not
/// mistaken for one that opens the enclosing try block's async gap.
class _AwaitVisitor extends RecursiveAstVisitor<void> {
  _AwaitVisitor({required this.beforeOffset});

  /// Only awaits that lexically precede this offset count — an await written
  /// after the `finally` block under inspection cannot have executed before
  /// that block runs.
  final int beforeOffset;

  bool found = false;

  @override
  void visitAwaitExpression(AwaitExpression node) {
    if (node.offset < beforeOffset) found = true;
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    // Do not descend — a nested closure's await is a separate async gap.
  }
}

/// Detects a call to one of the widget-tree-mutating operations this rule
/// treats as "unsafe after disposal", stopping at nested closures.
///
/// Closures are skipped for two reasons: a callback registered inside
/// `finally` runs later in a different context, and — critically for the
/// `setState(() => ...)` shape — the argument closure is not where the
/// unsafe call happens; the `setState` invocation itself is, and that is
/// matched before any descent occurs.
class _UnsafeOperationVisitor extends RecursiveAstVisitor<void> {
  bool found = false;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (found) return;
    if (AvoidMountedCheckInFinallyRule._unsafeMethodNames.contains(
      node.methodName.name,
    )) {
      found = true;
      return;
    }
    final Expression? target = node.target;
    if (target != null &&
        AvoidMountedCheckInFinallyRule._unsafeTargetNames.contains(
          _rootTargetName(target),
        )) {
      found = true;
      return;
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    // Do not descend — a nested closure is a separate execution context.
  }

  /// Extracts the leading identifier name from a method-invocation target,
  /// unwrapping one level of `.of(context)` on top of [extractTargetName]
  /// (`Navigator.of(context).pop()` has a target of `Navigator.of(context)`,
  /// itself a [MethodInvocation] whose own target is the `Navigator`
  /// identifier).
  static String _rootTargetName(Expression target) {
    if (target is MethodInvocation) {
      final Expression? inner = target.target;
      return inner != null ? _rootTargetName(inner) : target.methodName.name;
    }
    return extractTargetName(target);
  }
}
