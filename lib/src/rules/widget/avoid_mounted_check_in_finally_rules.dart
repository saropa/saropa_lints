import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../../saropa_lint_rule.dart';
import '../../target_matcher_utils.dart'
    show extractTargetName, isWidgetOrStateClass;

// =============================================================================
// avoid_mounted_check_in_finally
// =============================================================================

/// Flags an `if (mounted)` / `if (!mounted) return;` guard placed inside a
/// `finally` block that follows an `await` in `State` lifecycle/callback
/// code.
///
/// A `finally` block always runs — including after the widget has already
/// been disposed, and along every exception path — so a `mounted` guard
/// placed there is misleading: any statement written ABOVE the guard in the
/// same `finally` block still executes unconditionally regardless of
/// disposal state. The developer's mental model ("finally always runs, so
/// this is the safe place to check") is backwards: the `mounted` check needs
/// to happen at the point of use, immediately after each `await`, not
/// bundled into a single end-of-block gate that a later edit can silently
/// bypass by adding a new statement above it.
///
/// Since: v14.3.4 | Updated: v14.3.4 | Rule version: v1
///
/// **BAD:**
/// ```dart
/// Future<void> _submit() async {
///   setState(() => _isLoading = true);
///   try {
///     await _api.submit(_formData);
///   } finally {
///     _controller.dispose(); // Runs unconditionally, even if unmounted
///     if (mounted) { // LINT — mounted check in finally gives false confidence
///       setState(() => _isLoading = false);
///     }
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Future<void> _submit() async {
///   setState(() => _isLoading = true);
///   try {
///     await _api.submit(_formData);
///   } finally {
///     _controller.dispose();
///   }
///   if (!mounted) return; // OK — checked immediately after the await
///   setState(() => _isLoading = false);
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
  // literally, so a file without that substring can never contain one.
  @override
  Set<String>? get requiredPatterns => const {'mounted'};

  // `mounted` only exists on Flutter's State/Widget lifecycle types — pure
  // Dart files can never contain this pattern.
  @override
  bool get requiresFlutterImport => true;

  static const LintCode _code = LintCode(
    'avoid_mounted_check_in_finally',
    '[avoid_mounted_check_in_finally] This `mounted` check is inside a '
        '`finally` block. A `finally` block always runs — including after '
        'the widget has been disposed and along exception paths — so any '
        'statement written above this guard in the same block still '
        'executes unconditionally regardless of disposal state, giving a '
        'false sense of safety. Check `mounted` immediately after the '
        '`await` that crosses the async gap instead of bundling the guard '
        'into a single end-of-block check in `finally`. {v1}',
    correctionMessage: 'Move the mounted check to immediately after the '
        'await (e.g. "if (!mounted) return;" right after the await), '
        'outside the finally block.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addIfStatement((IfStatement node) {
      // Must be a direct `mounted` / `!mounted` test — compound conditions
      // (`if (mounted && x)`) are intentionally out of scope: narrowing to
      // the exact shape from the proposal avoids guessing at the semantics
      // of an arbitrary boolean expression.
      if (!_isMountedCheck(node.expression)) return;

      // Only the specific "diagnostic guard sitting inside a finally block"
      // shape matters here — find the nearest enclosing finally block
      // without crossing a function/class boundary (a nested closure has
      // its own execution context and is out of scope for this check).
      final Block? finallyBlock = _enclosingFinallyBlock(node);
      if (finallyBlock == null) return;

      final TryStatement tryStatement = finallyBlock.parent! as TryStatement;

      // Edge case 3: no `await` in the try block (or a catch clause that ran
      // instead of it) means there is no async gap for `mounted` to guard
      // against in the first place. A `try { sync(); } catch (e) { await
      // recover(); } finally { ... }` shape crosses the same async gap via
      // the catch branch, so catch clauses must be scanned too — checking
      // only `tryStatement.body` missed this exact bug class (the recovery
      // path is the one place code intentionally awaits after a failure,
      // then falls into `finally` with a stale `mounted` guard).
      if (!_containsAwait(tryStatement)) return;

      // Must be inside a State (or State-like: ConsumerState, etc.) class —
      // `mounted` is only meaningful on Flutter's widget lifecycle types.
      final ClassDeclaration? classDecl = node
          .thisOrAncestorOfType<ClassDeclaration>();
      if (classDecl == null || !isWidgetOrStateClass(classDecl)) return;

      // Edge case 2: a guard that only logs/asserts (no setState or
      // navigation) is not the unsafe-widget-tree-operation risk this rule
      // targets — only flag when the guarded body performs an operation
      // that is unsafe to run after disposal.
      if (!_guardsUnsafeOperation(node)) return;

      reporter.atNode(node);
    });
  }

  /// True for `mounted` or `!mounted` (optionally parenthesized), matching
  /// exactly the two shapes called out in the proposal. Structural check —
  /// no string matching on the condition's source text.
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

  /// Walks up from [node] looking for the nearest enclosing [Block] that is
  /// itself the `finallyBlock` of a [TryStatement], stopping at the first
  /// function or class boundary so a `mounted` check in a nested closure
  /// (which has its own, unrelated execution context) is never mistaken for
  /// living directly inside the outer method's `finally`.
  static Block? _enclosingFinallyBlock(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is TryStatement && current.finallyBlock != null) {
        // The if-statement is "inside" this finally block only when it is
        // a descendant of that specific Block (as opposed to the try body
        // or a catch clause, which are siblings under the same TryStatement).
        if (_isDescendantOf(node, current.finallyBlock!)) {
          return current.finallyBlock;
        }
      }
      if (current is FunctionBody || current is ClassDeclaration) break;
      current = current.parent;
    }
    return null;
  }

  /// True when [node] is [ancestor] or a descendant of it.
  static bool _isDescendantOf(AstNode node, AstNode ancestor) {
    AstNode? current = node;
    while (current != null) {
      if (identical(current, ancestor)) return true;
      current = current.parent;
    }
    return false;
  }

  /// True when [tryStatement]'s `try` body OR any of its `catch` clauses
  /// contains an `await` expression, not descending into nested closures
  /// (an await inside a nested function literal opens its own async gap,
  /// unrelated to this try/finally's lifecycle risk). Catch clauses matter
  /// because a recovery path (`catch (e) { await recover(); }`) crosses the
  /// same kind of async gap as the try body does, and control still falls
  /// into the same `finally` afterward.
  static bool _containsAwait(TryStatement tryStatement) {
    final visitor = _AwaitVisitor();
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

  /// True when the guard on [ifStatement] is actually load-bearing — i.e.
  /// gating at least one operation from [_unsafeMethodNames]/
  /// [_unsafeTargetNames] — as opposed to only logging or asserting (edge
  /// case 2, which should pass).
  ///
  /// Two shapes are checked:
  ///  1. `if (mounted) { setState(...); }` — the unsafe call lives directly
  ///     inside the if's `then`/`else` branch.
  ///  2. `if (!mounted) return; setState(...);` — the common early-return
  ///     guard clause, where the unsafe call is a SIBLING statement that
  ///     follows the if in the same block, only reachable when the guard
  ///     does not exit. This is exactly the shape in the proposal's own
  ///     BAD example variant, so it must be detected too.
  static bool _guardsUnsafeOperation(IfStatement ifStatement) {
    final thenVisitor = _UnsafeOperationVisitor();
    ifStatement.thenStatement.accept(thenVisitor);
    if (thenVisitor.found) return true;

    final elseVisitor = _UnsafeOperationVisitor();
    ifStatement.elseStatement?.accept(elseVisitor);
    if (elseVisitor.found) return true;

    // Shape 2: only applies when the then-branch unconditionally exits
    // (return/break/continue) and there is no else — the classic
    // "if (!mounted) return;" guard clause.
    if (ifStatement.elseStatement != null || !_isExitStatement(
      ifStatement.thenStatement,
    )) {
      return false;
    }
    return _followingSiblingsGuardUnsafeOperation(ifStatement);
  }

  /// True when [statement] unconditionally exits the enclosing block:
  /// a bare `return`/`break`/`continue`, or a `{ }` block containing only
  /// one of those as its final statement.
  static bool _isExitStatement(Statement statement) {
    final Statement inner = statement is Block && statement.statements.length == 1
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
}

/// Stops at nested closures/function bodies so an `await` inside a nested
/// callback is not mistaken for one that opens the outer try block's async
/// gap.
class _AwaitVisitor extends RecursiveAstVisitor<void> {
  bool found = false;

  @override
  void visitAwaitExpression(AwaitExpression node) {
    found = true;
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    // Do not descend — a nested closure's await is a separate async gap.
  }
}

/// Detects a call to one of the widget-tree-mutating operations this rule
/// treats as "unsafe after disposal", stopping at nested closures for the
/// same reason as [_AwaitVisitor].
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
