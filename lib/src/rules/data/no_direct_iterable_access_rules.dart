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

/// Warns when a `List` (or other non-`Map` indexable collection) is indexed
/// directly with `[]` instead of a bounds-safe accessor.
///
/// Since: v14.4.0 | Updated: v14.4.0 | Rule version: v1
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
/// list.length` form guarding the `else` branch); an early-return guard
/// clause (`if (index >= list.length) return;` followed by the unguarded
/// access); a loop variable bounded by the enclosing `for`
/// loop/collection-`for`'s own `< list.length` condition; or a preceding
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
        'returns null on a missing key instead of throwing. {v1}',
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

      // Inside a `for (var i = 0; i < list.length; i++)` loop (or the
      // collection-literal `for` form) whose condition provably bounds the
      // index expression (edge case 2 in the proposal).
      if (_isGuardedByBoundingForLoop(node, target)) return;

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

  /// True when [node] sits inside the `then` branch of an `if` statement (or
  /// element) whose condition proves the index in-bounds (`_isBoundsGuardCondition`),
  /// OR inside the `else` branch of an `if` whose condition proves the index
  /// *out*-of-bounds (`_isUnsafeGuardCondition`) — the else branch runs only
  /// when that condition is false, i.e. when the index is safe.
  bool _isGuardedByBoundsCheck(IndexExpression node, Expression target) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is IfStatement) {
        if (_isDescendantOf(node, current.thenStatement) &&
            _isBoundsGuardCondition(current.expression, node.index, target)) {
          return true;
        }
        final Statement? elseStatement = current.elseStatement;
        if (elseStatement != null &&
            _isDescendantOf(node, elseStatement) &&
            _isUnsafeGuardCondition(current.expression, node.index, target)) {
          return true;
        }
      }
      if (current is IfElement) {
        if (_isDescendantOf(node, current.thenElement) &&
            _isBoundsGuardCondition(current.expression, node.index, target)) {
          return true;
        }
        final CollectionElement? elseElement = current.elseElement;
        if (elseElement != null &&
            _isDescendantOf(node, elseElement) &&
            _isUnsafeGuardCondition(current.expression, node.index, target)) {
          return true;
        }
      }
      current = current.parent;
    }
    return false;
  }

  /// True when [node] is inside a `for (init; condition; update)` loop (a
  /// statement or a collection-literal `for` element) whose `condition`
  /// proves [node]'s index expression is bounded by `<target>.length` — the
  /// classic bounded index-loop pattern the proposal calls out as safe.
  /// Covers both `ForStatement` (`for (...) { ... }`) and `ForElement`
  /// (`[for (...) items[i]]` inside a list/set/map literal); the latter was
  /// previously unhandled and false-positived on collection-for loops.
  bool _isGuardedByBoundingForLoop(IndexExpression node, Expression target) {
    AstNode? current = node.parent;
    while (current != null) {
      ForLoopParts? parts;
      if (current is ForStatement) {
        parts = current.forLoopParts;
      } else if (current is ForElement) {
        parts = current.forLoopParts;
      }
      if (parts is ForParts &&
          parts.condition != null &&
          _isBoundsGuardCondition(parts.condition!, node.index, target)) {
        return true;
      }
      current = current.parent;
    }
    return false;
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

    final TokenType op = condition.operator.type;
    final String indexSource = indexExpr.toSource();
    final String targetSource = target.toSource();

    if (op == TokenType.LT) {
      // index < list.length
      if (condition.leftOperand.toSource() != indexSource) return false;
      final String? lengthTargetSource = _lengthTargetSource(
        condition.rightOperand,
      );
      return lengthTargetSource == targetSource;
    }

    if (op == TokenType.GT) {
      // list.length > index — the reversed form of the same guard
      // (edge case 5: reversed comparison operand order).
      if (condition.rightOperand.toSource() != indexSource) return false;
      final String? lengthTargetSource = _lengthTargetSource(
        condition.leftOperand,
      );
      return lengthTargetSource == targetSource;
    }

    return false;
  }

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

    final TokenType op = condition.operator.type;
    final String indexSource = indexExpr.toSource();
    final String targetSource = target.toSource();

    if (op == TokenType.GT_EQ) {
      // index >= list.length
      if (condition.leftOperand.toSource() != indexSource) return false;
      final String? lengthTargetSource = _lengthTargetSource(
        condition.rightOperand,
      );
      return lengthTargetSource == targetSource;
    }

    if (op == TokenType.LT_EQ) {
      // list.length <= index — the reversed form of the same guard.
      if (condition.rightOperand.toSource() != indexSource) return false;
      final String? lengthTargetSource = _lengthTargetSource(
        condition.leftOperand,
      );
      return lengthTargetSource == targetSource;
    }

    return false;
  }

  /// If [expr] is a `.length` access (`x.length`), the source of `x`;
  /// otherwise null. Handles both `PrefixedIdentifier` (`list.length`) and
  /// `PropertyAccess` (`this.list.length`, `getList().length`) shapes.
  String? _lengthTargetSource(Expression expr) {
    if (expr is PrefixedIdentifier && expr.identifier.name == 'length') {
      return expr.prefix.toSource();
    }
    if (expr is PropertyAccess &&
        expr.propertyName.name == 'length' &&
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
