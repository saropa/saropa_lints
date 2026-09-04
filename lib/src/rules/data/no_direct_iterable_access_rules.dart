import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/element/type.dart';

import '../../saropa_lint_rule.dart';

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
/// a constant index into a constant list literal, an index immediately
/// guarded by an explicit `index < list.length` check, or a loop variable
/// bounded by the enclosing `for` loop's own `< list.length` condition.
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
      if (!targetType.isDartCoreList) return;

      // A constant index into a constant list literal is statically
      // provable to be in range (edge case 3 in the proposal), e.g.
      // `const [1, 2, 3][1]`.
      if (_isProvablySafeConstantAccess(node, target)) return;

      // Preceded by an explicit `index < list.length` bounds check
      // (edge case 1 in the proposal).
      if (_isGuardedByBoundsCheck(node, target)) return;

      // Inside a `for (var i = 0; i < list.length; i++)` loop whose
      // condition provably bounds the index expression (edge case 2 in the
      // proposal).
      if (_isGuardedByBoundingForLoop(node, target)) return;

      reporter.atNode(node);
    });
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
  /// element) whose condition is exactly `<index> < <target>.length` (or the
  /// `<=`/`!=`-with-appropriate-sense variants), i.e. the developer already
  /// guarded the access before indexing.
  bool _isGuardedByBoundsCheck(IndexExpression node, Expression target) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is IfStatement &&
          _isDescendantOf(node, current.thenStatement) &&
          _isBoundsGuardCondition(current.expression, node.index, target)) {
        return true;
      }
      if (current is IfElement &&
          _isDescendantOf(node, current.thenElement) &&
          _isBoundsGuardCondition(current.expression, node.index, target)) {
        return true;
      }
      current = current.parent;
    }
    return false;
  }

  /// True when [node] is inside a `for (init; condition; update)` loop whose
  /// `condition` is exactly `<loopVar> < <target>.length`, where `<loopVar>`
  /// is the same expression as [node]'s index — the classic bounded
  /// index-loop pattern the proposal calls out as safe.
  bool _isGuardedByBoundingForLoop(IndexExpression node, Expression target) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is ForStatement) {
        final ForLoopParts parts = current.forLoopParts;
        if (parts is ForParts && parts.condition != null) {
          if (_isBoundsGuardCondition(parts.condition!, node.index, target)) {
            return true;
          }
        }
      }
      current = current.parent;
    }
    return false;
  }

  /// True when [condition] is a `<` (or `<=`) comparison between
  /// [indexExpr] and `<target>.length`. Uses exact `toSource()` equality on
  /// the index and target expressions (not `.contains()`), so `i2 < list.length`
  /// does not spuriously match a guard intended for `i`.
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
    if (op != TokenType.LT && op != TokenType.LT_EQ) return false;

    final String indexSource = indexExpr.toSource();
    if (condition.leftOperand.toSource() != indexSource) return false;

    final Expression right = condition.rightOperand;
    final String? lengthTargetSource = _lengthTargetSource(right);
    return lengthTargetSource != null &&
        lengthTargetSource == target.toSource();
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
