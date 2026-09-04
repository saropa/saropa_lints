import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/element/type.dart';

import '../../saropa_lint_rule.dart';

/// The result of walking up from an [IndexExpression] to find the nearest
/// enclosing [Block]: the block's statement list, plus the index within it
/// of the statement that (transitively) contains the access. Both the
/// early-return guard check and the `RangeError.checkValidIndex` guard
/// check need to look only at statements that run strictly *before* the
/// access, so they share this lookup rather than re-deriving it.
typedef _BlockContext = ({List<Statement> statements, int nodeIndex});

/// A condition plus the two branches it selects between, normalized across
/// the three AST shapes that express "run this only when the condition
/// holds": `IfStatement` (`if (c) {...} else {...}`), `IfElement` (the
/// collection-literal `[if (c) a else b]` form), and `ConditionalExpression`
/// (the ternary `c ? a : b`). The guard analysis is identical for all three
/// — only the node classes differ — so they are normalized here instead of
/// being handled by three near-duplicate branches.
typedef _Branches = ({
  Expression condition,
  AstNode thenNode,
  AstNode? elseNode,
});

/// Warns when a `List` (or other non-`Map` indexable collection) is indexed
/// directly with `[]` instead of a bounds-safe accessor.
///
/// Since: v14.4.0 | Updated: v14.4.0 | Rule version: v2
///
/// `list[index]` throws `RangeError` the instant `index` falls outside the
/// list's bounds. That failure mode is easy to miss when the index comes
/// from user input, an API response, or a computed offset rather than a
/// literal loop counter. `Map` is deliberately out of scope: `Map`'s `[]`
/// already returns `null` on a miss instead of throwing, so it carries none
/// of the crash risk this rule targets.
///
/// The rule does not flag access that is statically provable to be safe:
/// a constant index into a constant list literal; an index guarded by an
/// explicit `index < list.length` check (in an `if`'s `then` branch, its
/// reversed form `list.length > index`, or the negated `index >=
/// list.length` form guarding the `else` branch); the `list.isNotEmpty` /
/// `list.isEmpty` emptiness idiom guarding a literal `[0]` access; the
/// same guards expressed as a ternary (`list.isEmpty ? fallback : list[0]`);
/// an early-return guard clause (`if (index >= list.length) return;`
/// followed by the unguarded access); a loop variable bounded by the
/// enclosing `for`/collection-`for`/`while`/`do-while` loop's own
/// `< list.length` condition; or a preceding
/// `RangeError.checkValidIndex(index, list)` call, dart:core's own
/// recommended way to validate an index explicitly.
///
/// Example of **bad** code:
/// ```dart
/// String firstItemLabel(List<String> items) {
///   return items[0]; // Throws RangeError if items is empty
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// String firstItemLabel(List<String> items) {
///   return items.elementAtOrNull(0) ?? '';
/// }
/// ```
class NoDirectIterableAccessRule extends SaropaLintRule {
  NoDirectIterableAccessRule() : super(code: _code);

  /// A missed bounds check turns into a runtime crash the moment the index
  /// is out of range, so this is a reliability/correctness issue, not merely
  /// a style nit.
  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'reliability', 'type-safety'};

  // Requires walking ancestor if/for statements to look for a bounds guard,
  // so this is pricier than a single-node type check.
  @override
  RuleCost get cost => RuleCost.high;

  @override
  bool get usesTypeResolution => true;

  // Every violation is a `[` index operator, so this is a cheap syntactic
  // pre-filter before the (expensive) resolved-type + guard analysis runs.
  @override
  Set<String>? get requiredPatterns => const {'['};

  static const LintCode _code = LintCode(
    'no_direct_iterable_access',
    '[no_direct_iterable_access] Direct index access (list[index]) throws a '
        'RangeError the instant index falls outside the list bounds, '
        'crashing the app. This is especially dangerous when the index '
        'comes from user input, an API response, or a computed offset '
        'rather than a literal loop counter that is provably in range. '
        'Map is not affected by this rule because its [] operator already '
        'returns null on a missing key instead of throwing. {v2}',
    correctionMessage:
        'Use list.elementAtOrNull(index) with an explicit fallback (e.g. '
        '?? defaultValue), or guard the access with an '
        'index < list.length check before indexing.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addIndexExpression((IndexExpression node) {
      final Expression target = node.realTarget;
      final DartType? targetType = target.staticType;
      if (targetType == null) return;

      // Map's [] returns null on a miss rather than throwing, so it is
      // explicitly out of scope regardless of any other indexable interface
      // it might also implement.
      if (targetType.isDartCoreMap) return;

      // Only the List hazard is in scope for this rule (see proposal
      // "Alternatives Considered" — Map access rejected as out of scope).
      // Uses a supertype walk rather than a bare `isDartCoreList` check so
      // typed-data lists (Uint8List, Float64List, ...) and custom classes
      // that `implements List<T>` are also covered — they throw the same
      // RangeError on out-of-bounds `[]` and were previously silently
      // out of scope.
      if (!_isListLike(targetType)) return;

      // A constant index into a constant list literal is statically
      // provable to be in range (edge case 3 in the proposal), e.g.
      // `const [1, 2, 3][1]`.
      if (_isProvablySafeConstantAccess(node, target)) return;

      // Preceded by an explicit `index < list.length` bounds check
      // (edge case 1 in the proposal).
      if (_isGuardedByBoundsCheck(node, target)) return;

      // Inside a `for (var i = 0; i < list.length; i++)` loop — or the
      // collection-literal `for`, `while`, or `do-while` form — whose
      // condition provably bounds the index expression (edge case 2 in the
      // proposal).
      if (_isGuardedByBoundingLoop(node, target)) return;

      // Preceded by an early-return guard clause in the same enclosing
      // block, e.g. `if (index >= values.length) return -1;` — the most
      // common real-world guard-clause idiom, distinct from the nested-`if`
      // form above because the access sits *after*, not *inside*, the `if`.
      if (_isGuardedByEarlyReturnClause(node, target)) return;

      // Preceded by dart:core's own recommended explicit validation,
      // `RangeError.checkValidIndex(index, list)`.
      if (_isGuardedByRangeErrorCheck(node, target)) return;

      reporter.atNode(node);
    });
  }

  /// True when [type] is `List` or a type that (transitively) implements
  /// `List` — this catches typed-data lists (`Uint8List`, `Float64List`,
  /// etc., which `extends List<int>`/`List<double>`) and any custom class
  /// that `implements List<T>`, all of which throw the identical
  /// `RangeError` on out-of-bounds `[]` that a bare `isDartCoreList` check
  /// would miss.
  bool _isListLike(DartType type) {
    if (type.isDartCoreList) return true;
    if (type is InterfaceType) {
      for (final InterfaceType supertype in type.allSupertypes) {
        if (supertype.isDartCoreList) return true;
      }
    }
    return false;
  }

  /// True when [node] indexes a list literal ([target]) with a constant
  /// integer whose value falls within the literal's known element count —
  /// e.g. `const [1, 2, 3][1]`. Both the target and the index must be
  /// syntactically constant; a variable holding a list literal is NOT
  /// treated as constant here because later mutation could change its
  /// length.
  bool _isProvablySafeConstantAccess(IndexExpression node, Expression target) {
    if (target is! ListLiteral) return false;

    final Expression indexExpr = node.index;
    if (indexExpr is! IntegerLiteral) return false;

    final int? indexValue = indexExpr.value;
    if (indexValue == null) return false;

    return indexValue >= 0 && indexValue < target.elements.length;
  }

  /// True when [node] sits inside the `then` branch of a conditional whose
  /// condition proves the index in-bounds (`_isBoundsGuardCondition`), OR
  /// inside the `else` branch of a conditional whose condition proves the
  /// index *out*-of-bounds (`_isUnsafeGuardCondition`) — the else branch runs
  /// only when that condition is false, i.e. when the index is safe.
  ///
  /// "Conditional" covers `if` statements, collection-literal `if` elements,
  /// AND ternaries (`ConditionalExpression`). Ternaries were previously not
  /// walked at all, so the extremely common expression-bodied guard
  /// `int f(List<int> v) => v.isEmpty ? -1 : v[0];` false-positived even
  /// though it is provably safe.
  bool _isGuardedByBoundsCheck(IndexExpression node, Expression target) {
    AstNode? current = node.parent;
    while (current != null) {
      if (_isGuardingConditional(current, node, target)) return true;
      current = current.parent;
    }
    return false;
  }

  /// True when the single conditional node [current] guards [node]'s access:
  /// [node] is in the branch that only executes when the index is in range.
  /// Returns false for any node that is not one of the three conditional
  /// shapes `_conditionalBranches` understands.
  bool _isGuardingConditional(
    AstNode current,
    IndexExpression node,
    Expression target,
  ) {
    final _Branches? branches = _conditionalBranches(current);
    if (branches == null) return false;

    // `then` branch: reached only when the condition proved the index in
    // bounds.
    if (_isDescendantOf(node, branches.thenNode) &&
        _isBoundsGuardCondition(branches.condition, node.index, target)) {
      return true;
    }

    // `else` branch: reached only when the condition — which proved the
    // index OUT of bounds — was false, so the index is in bounds here.
    final AstNode? elseNode = branches.elseNode;
    return elseNode != null &&
        _isDescendantOf(node, elseNode) &&
        _isUnsafeGuardCondition(branches.condition, node.index, target);
  }

  /// Normalizes the three conditional AST shapes into a common
  /// condition/then/else triple; null for any other node type.
  _Branches? _conditionalBranches(AstNode node) {
    if (node is IfStatement) {
      return (
        condition: node.expression,
        thenNode: node.thenStatement,
        elseNode: node.elseStatement,
      );
    }
    if (node is IfElement) {
      return (
        condition: node.expression,
        thenNode: node.thenElement,
        elseNode: node.elseElement,
      );
    }
    if (node is ConditionalExpression) {
      return (
        condition: node.condition,
        thenNode: node.thenExpression,
        elseNode: node.elseExpression,
      );
    }
    return null;
  }

  /// True when [node] is inside a loop whose own condition proves [node]'s
  /// index expression is bounded by `<target>.length` — the classic bounded
  /// index-loop pattern the proposal calls out as safe.
  ///
  /// Covers every loop form that carries a boolean condition:
  /// * `ForStatement` — `for (var i = 0; i < list.length; i++) { ... }`
  /// * `ForElement` — `[for (var i = 0; i < list.length; i++) list[i]]`
  /// * `WhileStatement` — `while (i < list.length) { ... list[i] ... }`,
  ///   the standard hand-rolled cursor loop, previously unhandled and
  ///   false-positived even though the condition is checked before every
  ///   iteration of the body.
  /// * `DoStatement` — `do { ... } while (i < list.length);`
  ///
  /// Caveat on `do-while`: its condition runs AFTER the body, so the FIRST
  /// iteration is not actually guarded by it. It is accepted anyway because
  /// this is a `RuleType.bug` rule held to the zero-false-positive standard:
  /// a developer who wrote the bound is expressing intent, and the cost of
  /// accepting it is a rare false negative rather than noise on correct code.
  /// `for`/`while` share the separate (already accepted) caveat that the body
  /// could mutate the index or the list between the check and the access.
  bool _isGuardedByBoundingLoop(IndexExpression node, Expression target) {
    AstNode? current = node.parent;
    while (current != null) {
      final Expression? condition = _loopCondition(current);
      if (condition != null &&
          _isBoundsGuardCondition(condition, node.index, target)) {
        return true;
      }
      current = current.parent;
    }
    return false;
  }

  /// The boolean condition controlling [node] if it is a loop that has one;
  /// null otherwise (including `for-in`, which has no condition to reason
  /// about, and every non-loop node).
  Expression? _loopCondition(AstNode node) {
    ForLoopParts? parts;
    if (node is ForStatement) {
      parts = node.forLoopParts;
    } else if (node is ForElement) {
      parts = node.forLoopParts;
    }
    // `ForEachParts` (for-in) has no condition, so only the C-style
    // `ForParts` shape can bound an index.
    if (parts is ForParts) return parts.condition;

    if (node is WhileStatement) return node.condition;
    if (node is DoStatement) return node.condition;
    return null;
  }

  /// Guard clause + early return, e.g.:
  /// ```dart
  /// if (index >= values.length) return -1;
  /// return values[index]; // safe — guarded above
  /// ```
  /// True when a statement preceding [node]'s statement, in the same
  /// enclosing block, is an `if` whose condition is provably the negation
  /// of a bounds guard (`_isUnsafeGuardCondition`) and whose `then` branch
  /// always exits the block (`return`/`break`/`continue`/`throw`) — i.e.
  /// control only reaches [node] when the index is in bounds.
  bool _isGuardedByEarlyReturnClause(IndexExpression node, Expression target) {
    final _BlockContext? context = _enclosingBlockContext(node);
    if (context == null) return false;

    for (int i = 0; i < context.nodeIndex; i++) {
      final Statement statement = context.statements[i];
      // An `if/else` here is handled by the else-branch check in
      // `_isGuardedByBoundsCheck`, not this early-return form.
      if (statement is! IfStatement || statement.elseStatement != null) {
        continue;
      }
      if (_isTerminatingStatement(statement.thenStatement) &&
          _isUnsafeGuardCondition(statement.expression, node.index, target)) {
        return true;
      }
    }
    return false;
  }

  /// True when [statement] unconditionally exits its enclosing block/loop —
  /// `return`, `break`, `continue`, or `throw` — so that any code after an
  /// `if` guarded by [statement] as its `then` branch is unreachable unless
  /// the guard condition was false.
  bool _isTerminatingStatement(Statement statement) {
    if (statement is ReturnStatement ||
        statement is BreakStatement ||
        statement is ContinueStatement) {
      return true;
    }
    if (statement is ExpressionStatement &&
        statement.expression is ThrowExpression) {
      return true;
    }
    if (statement is Block && statement.statements.isNotEmpty) {
      return _isTerminatingStatement(statement.statements.last);
    }
    return false;
  }

  /// Preceded by dart:core's own recommended explicit validation:
  /// `RangeError.checkValidIndex(index, list)` as a statement before
  /// [node]'s statement in the same enclosing block. This call throws
  /// immediately on an invalid index, so it is the developer explicitly
  /// acknowledging and handling the bounds hazard — recognizing it avoids
  /// penalizing dart:core's own textbook-idiomatic guard.
  bool _isGuardedByRangeErrorCheck(IndexExpression node, Expression target) {
    final _BlockContext? context = _enclosingBlockContext(node);
    if (context == null) return false;

    final String indexSource = node.index.toSource();
    final String targetSource = target.toSource();
    for (int i = 0; i < context.nodeIndex; i++) {
      final Statement statement = context.statements[i];
      if (statement is! ExpressionStatement) continue;
      final Expression expression = statement.expression;
      if (expression is! MethodInvocation) continue;
      if (expression.methodName.name != 'checkValidIndex') continue;
      if (expression.target?.toSource() != 'RangeError') continue;

      final NodeList<Expression> args = expression.argumentList.arguments;
      if (args.length < 2) continue;
      if (args[0].toSource() == indexSource &&
          args[1].toSource() == targetSource) {
        return true;
      }
    }
    return false;
  }

  /// Walks up from [node] to find the nearest enclosing [Block] and the
  /// index, within that block's statement list, of the statement that
  /// (transitively) contains [node]. Returns null if [node] is not inside a
  /// block (e.g. an arrow-function body with no braces) — in that case
  /// there are no preceding statements to check, so the early-return and
  /// RangeError.checkValidIndex guards simply don't apply.
  _BlockContext? _enclosingBlockContext(IndexExpression node) {
    AstNode current = node;
    AstNode? parent = current.parent;
    while (parent != null) {
      if (current is Statement && parent is Block) {
        final int index = parent.statements.indexOf(current);
        if (index != -1) {
          return (statements: parent.statements, nodeIndex: index);
        }
      }
      current = parent;
      parent = current.parent;
    }
    return null;
  }

  /// True when [condition] proves [indexExpr] is in-bounds for
  /// `<target>.length`: a `<` comparison (`index < list.length`), its
  /// reversed form (`list.length > index`), or an `&&` combination where
  /// either operand is such a comparison. Uses exact `toSource()` equality
  /// on the index and target expressions (not `.contains()`), so
  /// `i2 < list.length` does not spuriously match a guard intended for `i`.
  /// Deliberately excludes `<=`/`>=`: `index <= list.length` still allows
  /// `index == list.length`, which throws — accepting it would be the
  /// original `<=` bug this fix removes.
  bool _isBoundsGuardCondition(
    Expression condition,
    Expression indexExpr,
    Expression target,
  ) {
    // `list.isNotEmpty` — by far the most common bounds-guard idiom in Dart,
    // and previously unrecognized because the old implementation bailed out
    // on anything that was not a BinaryExpression (a getter access is a
    // PrefixedIdentifier/PropertyAccess, never a BinaryExpression).
    if (_isNotEmptyGuard(condition, indexExpr, target)) return true;

    // `(...)` — unwrap so parentheses never defeat an otherwise valid guard.
    if (condition is ParenthesizedExpression) {
      return _isBoundsGuardCondition(condition.expression, indexExpr, target);
    }

    // `!X` is safe exactly when `X` proves the index out of bounds, e.g.
    // `if (!values.isEmpty)` or `if (!(index >= values.length))`.
    if (condition is PrefixExpression &&
        condition.operator.type == TokenType.BANG) {
      return _isUnsafeGuardCondition(condition.operand, indexExpr, target);
    }

    if (condition is! BinaryExpression) return false;

    // `a && b` — either operand may be the bounds guard.
    if (condition.operator.type == TokenType.AMPERSAND_AMPERSAND) {
      return _isBoundsGuardCondition(
            condition.leftOperand,
            indexExpr,
            target,
          ) ||
          _isBoundsGuardCondition(condition.rightOperand, indexExpr, target);
    }

    return _isInBoundsComparison(condition, indexExpr, target);
  }

  /// The `<`/`>` half of [_isBoundsGuardCondition], split out only to keep
  /// that method within the project's function-length limit. Uses exact
  /// `toSource()` equality (never `.contains()`) on both the index and the
  /// `.length` target.
  bool _isInBoundsComparison(
    BinaryExpression condition,
    Expression indexExpr,
    Expression target,
  ) {
    final TokenType op = condition.operator.type;
    final String indexSource = indexExpr.toSource();
    final String targetSource = target.toSource();

    if (op == TokenType.LT) {
      // index < list.length
      if (condition.leftOperand.toSource() != indexSource) return false;
      return _lengthTargetSource(condition.rightOperand) == targetSource;
    }

    if (op == TokenType.GT) {
      // list.length > index — the reversed form of the same guard
      // (edge case 5: reversed comparison operand order).
      if (condition.rightOperand.toSource() != indexSource) return false;
      return _lengthTargetSource(condition.leftOperand) == targetSource;
    }

    return false;
  }

  /// True when [condition] is `<target>.isNotEmpty` AND [indexExpr] is the
  /// literal `0` — i.e. the access is provably `list[0]` on a list the
  /// condition just proved non-empty.
  ///
  /// The literal-`0` restriction is load-bearing, not conservatism for its
  /// own sake: `isNotEmpty` only proves `length >= 1`, so index `0` is the
  /// ONLY index it makes safe. Accepting `values.isNotEmpty` as a guard for
  /// `values[i]` or even `values[1]` would suppress a real RangeError.
  bool _isNotEmptyGuard(
    Expression condition,
    Expression indexExpr,
    Expression target,
  ) =>
      _isLiteralZero(indexExpr) &&
      _propertyTargetSource(condition, 'isNotEmpty') == target.toSource();

  /// The mirror of [_isNotEmptyGuard]: `<target>.isEmpty` proves `list[0]`
  /// is UNSAFE, so it is a valid early-return / else-branch guard (control
  /// reaches the access only when this condition was false).
  bool _isEmptyGuard(
    Expression condition,
    Expression indexExpr,
    Expression target,
  ) =>
      _isLiteralZero(indexExpr) &&
      _propertyTargetSource(condition, 'isEmpty') == target.toSource();

  /// True when [indexExpr] is the integer literal `0`. Emptiness guards
  /// bound the length at 1, so only this index is provably in range.
  bool _isLiteralZero(Expression indexExpr) =>
      indexExpr is IntegerLiteral && indexExpr.value == 0;

  /// True when [condition] proves [indexExpr] is OUT-of-bounds for
  /// `<target>.length`: the negation of `_isBoundsGuardCondition`, namely
  /// `index >= list.length`, its reversed form `list.length <= index`, or
  /// an `||` combination where either operand is such a comparison. Used by
  /// the early-return guard clause and by the `else`-branch guard, both of
  /// which reach the access only when this condition is false.
  bool _isUnsafeGuardCondition(
    Expression condition,
    Expression indexExpr,
    Expression target,
  ) {
    // `list.isEmpty` — the getter form of "out of bounds for index 0". Like
    // `isNotEmpty` above, this is not a BinaryExpression, so the old
    // implementation's leading BinaryExpression bail-out made
    // `if (values.isEmpty) return -1; return values[0];` false-positive.
    if (_isEmptyGuard(condition, indexExpr, target)) return true;

    // `(...)` — unwrap so parentheses never defeat an otherwise valid guard.
    if (condition is ParenthesizedExpression) {
      return _isUnsafeGuardCondition(condition.expression, indexExpr, target);
    }

    // `!X` proves the index out of bounds exactly when `X` proves it in
    // bounds, e.g. `if (!values.isNotEmpty) return -1;`.
    if (condition is PrefixExpression &&
        condition.operator.type == TokenType.BANG) {
      return _isBoundsGuardCondition(condition.operand, indexExpr, target);
    }

    if (condition is! BinaryExpression) return false;

    // `a || b` — either operand being true is enough to be unsafe, so
    // reaching the access requires BOTH to be false, i.e. either operand
    // alone proves safety once negated.
    if (condition.operator.type == TokenType.BAR_BAR) {
      return _isUnsafeGuardCondition(
            condition.leftOperand,
            indexExpr,
            target,
          ) ||
          _isUnsafeGuardCondition(condition.rightOperand, indexExpr, target);
    }

    return _isOutOfBoundsComparison(condition, indexExpr, target);
  }

  /// The `>=`/`<=` half of [_isUnsafeGuardCondition], split out only to keep
  /// that method within the project's function-length limit.
  bool _isOutOfBoundsComparison(
    BinaryExpression condition,
    Expression indexExpr,
    Expression target,
  ) {
    final TokenType op = condition.operator.type;
    final String indexSource = indexExpr.toSource();
    final String targetSource = target.toSource();

    if (op == TokenType.GT_EQ) {
      // index >= list.length
      if (condition.leftOperand.toSource() != indexSource) return false;
      return _lengthTargetSource(condition.rightOperand) == targetSource;
    }

    if (op == TokenType.LT_EQ) {
      // list.length <= index — the reversed form of the same guard.
      if (condition.rightOperand.toSource() != indexSource) return false;
      return _lengthTargetSource(condition.leftOperand) == targetSource;
    }

    return false;
  }

  /// If [expr] is a `.length` access (`x.length`), the source of `x`;
  /// otherwise null.
  String? _lengthTargetSource(Expression expr) =>
      _propertyTargetSource(expr, 'length');

  /// If [expr] reads the getter [propertyName] off some receiver, the source
  /// of that receiver; otherwise null. Handles both `PrefixedIdentifier`
  /// (`list.length`, `list.isEmpty`) and `PropertyAccess`
  /// (`this.list.length`, `getList().isNotEmpty`) shapes — a getter read
  /// parses as one or the other depending on how the receiver is written,
  /// and both must be recognized or the guard is missed.
  String? _propertyTargetSource(Expression expr, String propertyName) {
    if (expr is PrefixedIdentifier && expr.identifier.name == propertyName) {
      return expr.prefix.toSource();
    }
    if (expr is PropertyAccess &&
        expr.propertyName.name == propertyName &&
        expr.target != null) {
      return expr.target!.toSource();
    }
    return null;
  }

  /// True when [node] is a descendant of [ancestor] in the AST.
  bool _isDescendantOf(AstNode node, AstNode ancestor) {
    AstNode? current = node;
    while (current != null) {
      if (current == ancestor) return true;
      current = current.parent;
    }
    return false;
  }
}
