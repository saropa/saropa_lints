// ignore_for_file: deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/element/element.dart';

import '../../saropa_lint_rule.dart';

/// Warns when two `String` expressions are compared with `==`/`!=` (or
/// `compareTo(...) == 0`) without normalizing case first, when at least one
/// side is not a compile-time constant.
///
/// Since: v15.3.0 | Updated: v15.4.0 | Rule version: v2
///
/// v2 detection change: a normalization call on ONE side no longer exempts
/// the comparison. Normalization must match on both sides (same function),
/// or the non-normalized side must be a constant already written in the
/// matching case — so `typed.toLowerCase() == stored.toUpperCase()` is now
/// correctly reported instead of silently passing.
///
/// Case-sensitive string comparison is the far more common real-world
/// cousin of `avoid_case_sensitive_path_comparison` (which is scoped to
/// filesystem paths): comparing user-typed input, config values, or
/// external API strings with `==` silently fails whenever casing differs —
/// e.g. rejecting `"Admin"` when the stored role is `"admin"`. Both sides
/// being compile-time constants under our own control (a literal-vs-literal
/// comparison, or a `const` field like `kEnvProd`) is exempted: casing there
/// is intentional and fully within the codebase's control, so flagging it
/// only adds noise.
///
/// Example of **bad** code:
/// ```dart
/// bool isAdmin(String role) {
///   return role == 'admin'; // fails silently for "Admin", "ADMIN", etc.
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// bool isAdmin(String role) {
///   return role.toLowerCase() == 'admin'; // normalized before comparison
/// }
///
/// const kEnvProd = 'production';
/// bool isProd(String env) => env == kEnvProd; // both sides are our own constants
/// ```
class UseCompareWithoutCaseRule extends SaropaLintRule {
  UseCompareWithoutCaseRule() : super(code: _code);

  /// Silent-failure bug class (case mismatch causes incorrect branch),
  /// but the "fix" is a judgment call the author must make (which helper,
  /// which normalization), so this stays a warning rather than an error.
  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'reliability', 'type-safety'};

  @override
  RuleCost get cost => RuleCost.medium;

  // Needs staticType on both operands to confirm they are String, and
  // needs resolved elements to identify const references for the
  // both-sides-constant exemption.
  @override
  bool get usesTypeResolution => true;

  // High false-positive risk against intentionally case-sensitive
  // comparisons (enum-like internal constants, IDs, hashes, route names)
  // per the proposal — start opt-in, graduate only after real-world tuning.
  @override
  RuleStatus get ruleStatus => RuleStatus.beta;

  static const LintCode _code = LintCode(
    'use_compare_without_case',
    '[use_compare_without_case] Two String values are compared with == or '
        '!= (or the equivalent compareTo(...) == 0 form) without first '
        'normalizing their case, and at least one side is not a '
        "compile-time constant under this codebase's own control. Casing "
        'differences in user-typed input, configuration values, or external '
        'API responses are extremely common, and an unnormalized comparison '
        'silently returns false for a semantically matching value (e.g. '
        'rejecting "Admin" when the stored role is "admin"), producing a '
        'hard-to-diagnose logic bug rather than a crash. Mismatched '
        'normalization (one side .toLowerCase(), the other .toUpperCase()) '
        'is reported for the same reason: it can only ever be true for '
        'strings with no cased characters at all. {v2}',
    correctionMessage:
        'Normalize both sides with .toLowerCase() (or .toUpperCase()) '
        'before comparing, or use a case-insensitive comparison helper.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addBinaryExpression((BinaryExpression node) {
      final TokenType op = node.operator.type;
      if (op != TokenType.EQ_EQ && op != TokenType.BANG_EQ) return;

      final Expression left = node.leftOperand;
      final Expression right = node.rightOperand;

      // compareTo(x) == 0 / != 0 is the same case-sensitivity bug in a
      // different shape (proposal edge case 3) — unwrap it to the two
      // String operands being compared before running the same checks.
      final _StringPair? pair = _stringPairFor(left, right);
      if (pair == null) return;

      // Case normalization only makes a comparison safe when it lands on
      // BOTH sides in a compatible way. A normalization call on one side
      // alone is not evidence of correctness — historically this rule
      // skipped whenever EITHER side had a toLowerCase()/toUpperCase()
      // call, which silently passed the worst form of the very bug it
      // exists to catch:
      //
      //   typed.toLowerCase() == stored.toUpperCase()
      //
      // That can only ever be true for strings containing no cased
      // characters at all. `_isSafelyNormalized` therefore requires either
      // matching normalization functions on both sides, or a constant on
      // the other side that is already written in the matching case.
      if (_isSafelyNormalized(pair.left, pair.right)) return;

      // Both sides are compile-time constants under our own control (two
      // literals, or const fields/variables): casing is intentional and
      // fully known at author time, so exempt to avoid noise on
      // enum-like/route-name/ID comparisons.
      if (_isConstantString(pair.left) && _isConstantString(pair.right)) {
        return;
      }

      reporter.atNode(node);
    });
  }

  /// If this is a direct String == String comparison, returns the two
  /// operands as-is. If it is `a.compareTo(b) == 0` / `!= 0` (in either
  /// operand order), unwraps to the underlying `a`/`b` String operands.
  /// Returns null when neither shape applies, or when the operands are not
  /// statically typed String.
  static _StringPair? _stringPairFor(Expression left, Expression right) {
    // Direct `stringA == stringB`.
    if (_isStringTyped(left) && _isStringTyped(right)) {
      return _StringPair(left, right);
    }

    // `a.compareTo(b) == 0` (order 1) or `0 == a.compareTo(b)` (order 2).
    final MethodInvocation? compareToCall = left is MethodInvocation
        ? left
        : right is MethodInvocation
        ? right
        : null;
    final Expression? zeroSide = left is IntegerLiteral
        ? left
        : right is IntegerLiteral
        ? right
        : null;
    if (compareToCall == null || zeroSide is! IntegerLiteral) return null;
    if (zeroSide.value != 0) return null;
    if (compareToCall.methodName.name != 'compareTo') return null;

    final Expression? target = compareToCall.target;
    final List<Expression> args = compareToCall.argumentList.arguments;
    if (target == null || args.length != 1) return null;
    if (!_isStringTyped(target) || !_isStringTyped(args.first)) return null;

    return _StringPair(target, args.first);
  }

  /// True when [expr]'s static type is exactly `String` (nullable or not) —
  /// checked via the declared display name rather than any name/source
  /// substring match, to avoid false positives on unrelated types whose
  /// name merely contains "String".
  static bool _isStringTyped(Expression expr) {
    final displayName = expr.staticType?.getDisplayString();
    return displayName == 'String' || displayName == 'String?';
  }

  /// True when the comparison of [a] against [b] is genuinely
  /// case-insensitive.
  ///
  /// Two shapes qualify, and only these two:
  ///
  /// 1. BOTH operands are normalized with the SAME function — `toLowerCase()`
  ///    on both, or `toUpperCase()` on both. Mixing the two
  ///    (`x.toLowerCase() == y.toUpperCase()`) is a bug, not a normalization,
  ///    so it deliberately does NOT qualify.
  /// 2. ONE operand is normalized and the other is a constant string already
  ///    written in that same case (`role.toLowerCase() == 'admin'`). If the
  ///    constant carries the wrong case (`role.toLowerCase() == 'Admin'`) the
  ///    comparison is dead code, so it stays flagged.
  ///
  /// A constant whose value cannot be read statically (a `const` reference
  /// rather than a literal) is treated as matching: we cannot prove the case
  /// is wrong, and the false-positive doctrine says do not flag on a guess.
  static bool _isSafelyNormalized(Expression a, Expression b) {
    final String? normA = _caseNormalizationOf(a);
    final String? normB = _caseNormalizationOf(b);

    // Neither side normalized: nothing exempts this comparison here.
    if (normA == null && normB == null) return false;

    // Both sides normalized: safe only when the SAME function is used.
    if (normA != null && normB != null) return normA == normB;

    // Exactly one side normalized — the other side must be a constant
    // already spelled in the matching case.
    final String normalization = normA ?? normB!;
    final Expression other = normA != null ? b : a;
    return _isConstantInCase(other, normalization);
  }

  /// Returns `'toLowerCase'` / `'toUpperCase'` when [expr] is a
  /// zero-argument call of that method on a `String` receiver; null
  /// otherwise.
  ///
  /// The receiver-type and argument-count checks matter: an unrelated
  /// user-defined `toLowerCase(locale)` on some other type is NOT String
  /// case normalization, and matching it by method name alone would silently
  /// exempt a real case-sensitivity bug. Name matching is exact (never a
  /// substring check on source text) per the false-positive doctrine.
  static String? _caseNormalizationOf(Expression expr) {
    if (expr is! MethodInvocation) return null;
    final String name = expr.methodName.name;
    if (name != 'toLowerCase' && name != 'toUpperCase') return null;
    // `String.toLowerCase()`/`toUpperCase()` take no arguments.
    if (expr.argumentList.arguments.isNotEmpty) return null;
    // Must be invoked ON a String (`role.toLowerCase()`), not a bare
    // top-level/local function that happens to share the name.
    final Expression? target = expr.target;
    if (target == null || !_isStringTyped(target)) return null;
    return name;
  }

  /// True when [expr] is a constant String that is already written in the
  /// case produced by [normalization] (or a constant whose value we cannot
  /// read — see `_isSafelyNormalized` for why unknown counts as matching).
  /// A non-constant operand never qualifies: it must be normalized itself.
  static bool _isConstantInCase(Expression expr, String normalization) {
    if (!_isConstantString(expr)) return false;

    // Only string literals expose their value here; `stringValue` is null
    // for interpolated strings, which we cannot case-check.
    final String? value = expr is StringLiteral ? expr.stringValue : null;
    if (value == null) return true; // const reference / interpolation: unknown

    return normalization == 'toLowerCase'
        ? value == value.toLowerCase()
        : value == value.toUpperCase();
  }

  /// True when [expr] is a compile-time-constant String: a literal, or a
  /// reference to a `const` variable/field. Mirrors the const-detection
  /// pattern used elsewhere in this file's sibling rules
  /// (`_isEffectivelyConstantCondition` in collection_rules.dart) rather
  /// than reinventing a new heuristic.
  static bool _isConstantString(Expression expr) {
    if (expr is SimpleStringLiteral || expr is AdjacentStrings) return true;
    if (expr is SimpleIdentifier) {
      final Element? el = expr.element;
      if (el is VariableElement && el.isConst) return true;
      if (el is PropertyAccessorElement && el.variable.isConst) return true;
      return false;
    }
    // `ClassName.constField` — PrefixedIdentifier/PropertyAccess resolve
    // through the same accessor element check on their name/property.
    if (expr is PrefixedIdentifier) {
      return _isConstantString(expr.identifier);
    }
    if (expr is PropertyAccess) {
      final SimpleIdentifier prop = expr.propertyName;
      return _isConstantString(prop);
    }
    return false;
  }
}

/// The two String operands being compared, after unwrapping either a direct
/// `==`/`!=` or a `compareTo(...) == 0` shape.
class _StringPair {
  const _StringPair(this.left, this.right);

  final Expression left;
  final Expression right;
}
