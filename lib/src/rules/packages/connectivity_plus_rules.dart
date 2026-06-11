// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// connectivity_plus package lint rules.
///
/// Covers two gaps not handled by the existing connectivity_rules.dart:
///   1. `avoid_pre_v6_single_connectivity_result` — pre-upgrade readiness rule
///      for projects on connectivity_plus <6.0.0. The v6 release changed the
///      return type of checkConnectivity() / onConnectivityChanged events from
///      a single ConnectivityResult to List<ConnectivityResult>. Code that
///      uses a bare `==` / `!=` comparison against a ConnectivityResult enum
///      value will be a type error after the bump. Relocated into the
///      `connectivity_plus_6` version-gated pack (<6.0.0).
///   2. `connectivity_satellite_missing` — completeness rule targeting
///      if-else chains (NOT switch — Dart's exhaustiveness checker covers
///      those) that test >=3 ConnectivityResult values but omit the
///      `satellite` case added in v7.1.0.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';

import '../../fixes/common/replace_node_fix.dart';
import '../../import_utils.dart';
import '../../saropa_lint_rule.dart';

// =============================================================================
// avoid_pre_v6_single_connectivity_result
// =============================================================================

/// Flags binary `==` / `!=` comparisons against a `ConnectivityResult` enum
/// value that will break when upgrading connectivity_plus to v6.
///
/// Since: v4.18.0 | Rule version: v1
///
/// connectivity_plus v6 changed the return type of
/// `Connectivity().checkConnectivity()` and the event type of
/// `onConnectivityChanged` from the single-value `ConnectivityResult` to
/// `List<ConnectivityResult>`. Code that compares the result with `==` or
/// `!=` is valid on v5 but becomes a type error on v6.
///
/// The mechanical fix for the common `== X` / `!= X` pattern is to replace
/// the comparison with a `.contains(X)` call on the list side.
///
/// **BAD (connectivity_plus < 6.0.0 — breaks on upgrade):**
/// ```dart
/// final r = await Connectivity().checkConnectivity();
/// if (r == ConnectivityResult.none) { ... }    // breaks on v6
/// if (r != ConnectivityResult.wifi) { ... }    // breaks on v6
/// ```
///
/// **GOOD (works on v6+):**
/// ```dart
/// final r = await Connectivity().checkConnectivity();
/// if (r.contains(ConnectivityResult.none)) { ... }
/// if (!r.contains(ConnectivityResult.wifi)) { ... }
/// ```
///
/// Relocated to pack: `connectivity_plus_6` (gate: <6.0.0).
class AvoidPreV6SingleConnectivityResultRule extends SaropaLintRule {
  AvoidPreV6SingleConnectivityResultRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_pre_v6_single_connectivity_result',
    '[avoid_pre_v6_single_connectivity_result] A binary == or != comparison '
        'against a ConnectivityResult enum value treats the connectivity result '
        'as a single value. connectivity_plus v6 changed the return type of '
        'checkConnectivity() and the stream event type from ConnectivityResult '
        'to List<ConnectivityResult>, so this comparison will be a compile-time '
        'type error after upgrading. Replace == ConnectivityResult.x with '
        '.contains(ConnectivityResult.x) and != ConnectivityResult.x with '
        '!.contains(ConnectivityResult.x) to work correctly on both v5 and v6+. '
        'This rule is gated to projects on connectivity_plus <6.0.0 to act as '
        'an opt-in upgrade-readiness check. {v1}',
    correctionMessage:
        'Replace `r == ConnectivityResult.x` with `r.contains(ConnectivityResult.x)` '
        'and `r != ConnectivityResult.x` with `!r.contains(ConnectivityResult.x)`. '
        'The v6 API returns List<ConnectivityResult>, so equality comparisons are '
        'type errors on v6+.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        _SingleResultToContainsFix(context: context),
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addBinaryExpression((BinaryExpression node) {
      // Import gate: only fire when connectivity_plus is imported.
      if (!fileImportsPackage(node, PackageImports.connectivity)) return;

      // Only == and != operators are the migration concern.
      final TokenType op = node.operator.type;
      if (op != TokenType.EQ_EQ && op != TokenType.BANG_EQ) return;

      // One operand must be a ConnectivityResult enum access:
      //   PrefixedIdentifier whose prefix is 'ConnectivityResult'
      //   e.g. ConnectivityResult.none / ConnectivityResult.wifi
      final bool leftIsEnum = _isConnectivityResultEnum(node.leftOperand);
      final bool rightIsEnum = _isConnectivityResultEnum(node.rightOperand);

      // Exactly one side must be the enum literal; the other is the variable.
      // Both-enum (ConnectivityResult.x == ConnectivityResult.y) is not the
      // migration footgun and is omitted to avoid false positives on constant
      // equality checks.
      if (leftIsEnum == rightIsEnum) return;

      reporter.atNode(node);
    });
  }

  /// True when [expr] is `ConnectivityResult.<value>` — a PrefixedIdentifier
  /// whose prefix lexeme is exactly 'ConnectivityResult'. Syntactic check is
  /// intentional: the scan CLI does not always resolve elements, and the prefix
  /// name is unique enough to avoid collisions with other enums.
  static bool _isConnectivityResultEnum(Expression expr) {
    if (expr is! PrefixedIdentifier) return false;
    return expr.prefix.name == 'ConnectivityResult';
  }
}

/// Quick fix: rewrite the binary expression as a `.contains(...)` call.
///
/// `r == ConnectivityResult.x`  →  `r.contains(ConnectivityResult.x)`
/// `r != ConnectivityResult.x`  →  `!r.contains(ConnectivityResult.x)`
///
/// The fix targets the entire BinaryExpression node. It identifies which
/// operand is the ConnectivityResult enum literal and which is the variable
/// side, then constructs the replacement from their source text.
class _SingleResultToContainsFix extends ReplaceNodeFix {
  _SingleResultToContainsFix({required super.context});

  @override
  FixKind get fixKind => FixKind(
    'saropa.fix.connectivitySingleResultToContains',
    80,
    'Replace with .contains(...) for v6 compatibility',
  );

  @override
  AstNode? findTargetNode(AstNode node) {
    // Walk up from the covering node to the BinaryExpression so the full
    // expression is replaced (the covering node may be a sub-identifier).
    AstNode? current = node;
    while (current != null && current is! BinaryExpression) {
      current = current.parent;
    }
    return current;
  }

  @override
  String computeReplacement(AstNode node) {
    if (node is! BinaryExpression) return node.toSource();

    final bool isNotEqual = node.operator.type == TokenType.BANG_EQ;

    final Expression left = node.leftOperand;
    final Expression right = node.rightOperand;

    // Identify the enum side (ConnectivityResult.x) and the variable side.
    final bool leftIsEnum =
        AvoidPreV6SingleConnectivityResultRule._isConnectivityResultEnum(left);

    final String varSrc = leftIsEnum ? right.toSource() : left.toSource();
    final String enumSrc = leftIsEnum ? left.toSource() : right.toSource();

    final String containsExpr = '$varSrc.contains($enumSrc)';

    // `!=` negates the contains call.
    return isNotEqual ? '!$containsExpr' : containsExpr;
  }
}

// =============================================================================
// connectivity_satellite_missing
// =============================================================================

/// Flags an if-else chain that tests a `ConnectivityResult` value against
/// three or more enum cases but omits `ConnectivityResult.satellite`.
///
/// Since: v4.18.0 | Rule version: v1
///
/// `ConnectivityResult.satellite` was added in connectivity_plus v7.1.0. Code
/// written against earlier versions that enumerates connectivity types via
/// if-else chains may silently misclassify a satellite connection (e.g. falling
/// into a generic `else` branch or an `assert(false)` default).
///
/// This rule targets **if-else chains only** — NOT switch statements. Dart 3's
/// exhaustiveness checker already errors on a non-exhaustive `switch` over an
/// enum, so switches are already covered at the SDK level. The if-else form
/// has no compiler-enforced exhaustiveness and is the real gap.
///
/// Conservative threshold: the chain must cover >=3 distinct ConnectivityResult
/// values before the rule fires, to avoid flagging intentional single-target
/// or two-value checks.
///
/// **BAD:**
/// ```dart
/// void handleResult(ConnectivityResult r) {
///   if (r == ConnectivityResult.wifi) {
///     ...
///   } else if (r == ConnectivityResult.mobile) {
///     ...
///   } else if (r == ConnectivityResult.ethernet) {
///     ...
///   }
///   // ConnectivityResult.satellite is silently ignored
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void handleResult(ConnectivityResult r) {
///   if (r == ConnectivityResult.wifi) {
///     ...
///   } else if (r == ConnectivityResult.mobile) {
///     ...
///   } else if (r == ConnectivityResult.ethernet) {
///     ...
///   } else if (r == ConnectivityResult.satellite) {
///     ...
///   }
/// }
/// ```
///
/// No quick fix: the behavior for a satellite connection is caller-defined.
class ConnectivitySatelliteMissingRule extends SaropaLintRule {
  ConnectivitySatelliteMissingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'connectivity_satellite_missing',
    '[connectivity_satellite_missing] An if-else chain tests a value against '
        'three or more ConnectivityResult enum cases but does not include a test '
        'for ConnectivityResult.satellite, which was added in connectivity_plus '
        'v7.1.0. Code written against earlier versions may silently misclassify '
        'satellite connections by falling through to a generic else branch or '
        'an assert(false) default. This rule fires only on if-else chains (not '
        'switch statements, which are already covered by Dart\'s exhaustiveness '
        'checker). Requires >=3 covered values to avoid flagging intentional '
        'single-value or two-value checks. Add a branch for '
        'ConnectivityResult.satellite to handle it explicitly. {v1}',
    correctionMessage:
        'Add an `else if (r == ConnectivityResult.satellite)` branch to handle '
        'satellite connections explicitly. ConnectivityResult.satellite was added '
        'in connectivity_plus v7.1.0 and may reach devices on v7.1+.',
    severity: DiagnosticSeverity.WARNING,
  );

  // No fixGenerators: the behavior for satellite is caller-defined.
  // A TODO-only branch insert is banned by the project quick-fix rules.

  /// Minimum number of distinct ConnectivityResult values an if-else chain
  /// must cover before the missing-satellite lint fires. This guards against
  /// flagging intentional single-target or two-value checks.
  static const int _minCoveredValues = 3;

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addIfStatement((IfStatement node) {
      // Import gate: only fire when connectivity_plus is imported.
      if (!fileImportsPackage(node, PackageImports.connectivity)) return;

      // Only examine the top-level IfStatement of a chain — skip nested heads
      // that are themselves the `else` branch of an outer if, to avoid
      // double-reporting the same chain.
      if (_isElseBranchHead(node)) return;

      // Walk the if-else chain and collect all ConnectivityResult values tested.
      final Set<String> coveredValues = <String>{};
      _collectConnectivityValues(node, coveredValues);

      // Need >=3 covered values to look like an enumeration attempt.
      if (coveredValues.length < _minCoveredValues) return;

      // The chain is interesting — check whether satellite is covered.
      if (coveredValues.contains('satellite')) return;

      reporter.atNode(node);
    });
  }

  /// True when [node] is itself the statement of an else clause — i.e., it is
  /// not the root of a chain but an inner link. Walking up to the parent
  /// IfStatement and checking its elseStatement identity is the reliable way
  /// to detect this without pattern-matching on source text.
  bool _isElseBranchHead(IfStatement node) {
    final AstNode? parent = node.parent;
    if (parent is! IfStatement) return false;
    // The parent's elseStatement is this node — we are an else-if branch.
    return parent.elseStatement == node;
  }

  /// Recursively walks an if-else chain and collects the leaf name of every
  /// `ConnectivityResult.<value>` that appears as an operand in a `==` or `!=`
  /// binary condition. Descends into nested else-if statements.
  void _collectConnectivityValues(IfStatement node, Set<String> coveredValues) {
    // Inspect the condition of this if statement.
    _collectFromExpression(node.expression, coveredValues);

    // Descend into the else branch if it is another if statement.
    final Statement? elseStmt = node.elseStatement;
    if (elseStmt is IfStatement) {
      _collectConnectivityValues(elseStmt, coveredValues);
    }
  }

  /// Collects ConnectivityResult enum leaf names from a single expression.
  ///
  /// Handles simple `r == ConnectivityResult.x` / `ConnectivityResult.x == r`
  /// comparisons and `&&`/`||` conjunctions that chain conditions on the same
  /// variable (conservative: just gather whatever enum values appear).
  void _collectFromExpression(Expression expr, Set<String> coveredValues) {
    if (expr is BinaryExpression) {
      final TokenType op = expr.operator.type;

      // For == / !=, check each operand for a ConnectivityResult prefix.
      if (op == TokenType.EQ_EQ || op == TokenType.BANG_EQ) {
        _tryAddEnumValue(expr.leftOperand, coveredValues);
        _tryAddEnumValue(expr.rightOperand, coveredValues);
        return;
      }

      // For && / ||, recurse into both sides to pick up chained conditions.
      if (op == TokenType.AMPERSAND_AMPERSAND || op == TokenType.BAR_BAR) {
        _collectFromExpression(expr.leftOperand, coveredValues);
        _collectFromExpression(expr.rightOperand, coveredValues);
      }
    }
  }

  /// If [expr] is `ConnectivityResult.<value>`, adds the leaf name (e.g.
  /// `'wifi'`, `'satellite'`) to [coveredValues].
  void _tryAddEnumValue(Expression expr, Set<String> coveredValues) {
    if (expr is! PrefixedIdentifier) return;
    if (expr.prefix.name != 'ConnectivityResult') return;
    coveredValues.add(expr.identifier.name);
  }
}
