// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';

import '../../saropa_lint_rule.dart';

/// Warns when a runtime `is Future` / `is Future<T>` type check is used to
/// branch behavior on a value that carries NO static evidence of being
/// asynchronous — typically a `dynamic` or `Object` value.
///
/// Since: v14.3.3 | Updated: v14.3.4 | Rule version: v2
///
/// A runtime `is Future` check on an untyped value is fragile: `Future<T>`
/// generic erasure makes the test unreliable across generic boundaries, and
/// the branch usually duplicates logic that `await` would unify. The fix is
/// almost always to type the value as `FutureOr<T>` and `await` it directly —
/// `await` on a non-Future value simply returns that value, so the branch
/// becomes unnecessary.
///
/// **FutureOr narrowing is exempt (v2).** When the tested expression is
/// ALREADY statically typed `FutureOr<T>` and the `is` clause names the
/// matching `Future<T>`, the check is the canonical, analyzer-recommended way
/// to narrow a `FutureOr<T>` — and it is the ONLY way to do so in a
/// synchronous context, where `await` is not available because the enclosing
/// function cannot be made `async` (an overridden synchronous interface
/// method, a getter, a `build()` method). Reporting there was a false
/// positive: the rule's own correction ("type the parameter as `FutureOr<T>`")
/// was already satisfied, so the diagnostic was unactionable. v2 therefore
/// consults `node.expression.staticType` and stays silent on that idiom.
///
/// Fires on both `x is Future` and the negated `x is! Future` — the negation
/// does not change the underlying fragility, only which branch runs first.
/// It also fires on the nullable form `x is Future<T>?`, since
/// `isDartAsyncFuture` is true for both `Future<T>` and `Future<T>?`.
///
/// **Known gap:** this rule only inspects `IsExpression` nodes, so Dart 3
/// pattern-matching equivalents such as `switch (result) { case Future(): }`
/// or `if (result case Future _)` are structurally different AST nodes
/// (object/type patterns, not `is` checks) and are NOT currently flagged,
/// even though they express the same fragile runtime check. Left as a
/// follow-up rather than in scope for v1.
///
/// **Scope note:** this rule only matches the literal `Future` type written
/// in the `is` clause — it does not walk supertypes to catch a custom class
/// that merely *extends/implements* `Future` (e.g. `x is MyCustomFuture`).
/// That is a deliberate, narrower scope than `_staticTypeIsFuture` in
/// `async_rules.dart` (which walks `allSupertypes` to catch such custom
/// subclasses when checking a *value's* static type) — matching a
/// user-written custom-Future type isn't the same fragile pattern this rule
/// targets, since the author controls that type directly.
///
/// **BAD:**
/// ```dart
/// void handle(dynamic result) {
///   if (result is Future) {
///     result.then((value) => print(value));
///   } else {
///     print(result);
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Future<void> handle(FutureOr<Object?> result) async {
///   final value = await result; // FutureOr<T> + await handles both cases.
///   print(value);
/// }
/// ```
///
/// **GOOD (FutureOr narrowing in a synchronous context):**
/// ```dart
/// // Overriding a synchronous interface method — `await` is unavailable
/// // because the signature forbids making this function async, so the
/// // `is Future<T>` narrowing of an already-FutureOr<T> value is correct.
/// int? tryReadSync(FutureOr<int> value) {
///   if (value is Future<int>) return null;
///   return value; // Promoted to int by the narrowing above.
/// }
/// ```
class IsFutureRule extends SaropaLintRule {
  IsFutureRule() : super(code: _code);

  /// Code quality issue — a fragile async pattern with a low-effort fix.
  /// Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'reliability', 'type-safety'};

  // Type resolution is required to tell `Future<T>` apart from `FutureOr<T>`
  // (see _isExactFutureType below), so this cannot be a cheap syntactic rule.
  @override
  RuleCost get cost => RuleCost.high;
  @override
  bool get usesTypeResolution => true;

  // Cheap syntactic pre-filter: skip files that don't even mention "Future"
  // before paying for AST traversal and type resolution.
  @override
  Set<String>? get requiredPatterns => const {'Future'};

  static const LintCode _code = LintCode(
    'is_future',
    '[is_future] Runtime "is Future" type check used to branch on whether an '
        'untyped value is asynchronous. This is fragile: the tested value has '
        'no static type saying it may be async (typically dynamic or Object), '
        'Future<T> generic erasure makes the check unreliable across generic '
        'boundaries, and the two branches usually duplicate logic that a '
        'single await would unify. Narrowing a value already typed '
        'FutureOr<T> with "is Future<T>" is the correct idiom and is NOT '
        'reported. {v2}',
    correctionMessage:
        'Type the value as FutureOr<T> instead of dynamic/Object, then use '
        '"await value" directly — awaiting a non-Future value simply returns '
        'it, making the runtime check unnecessary. If the enclosing function '
        'cannot be async, keep FutureOr<T> and narrow with "is Future<T>", '
        'which this rule allows. If the source type is genuinely outside your '
        'control, wrap it with "await Future.value(x)" instead of branching.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addIsExpression((IsExpression node) {
      final DartType? testedType = node.type.type;
      if (testedType == null) return;

      // Only the literal `Future` / `Future<T>` type-check is fragile in the
      // way this rule documents. `isDartAsyncFuture` is false for
      // `FutureOr<T>` (it is a distinct DartType), so this check does not
      // need to worry about that near-miss separately. `isDartAsyncFuture`
      // is also true for the nullable form `Future<T>?`, so this
      // deliberately fires on `x is Future<T>?` too — nullability doesn't
      // change the underlying fragility. Note this is NOT the same check as
      // `_staticTypeIsFuture` in async_rules.dart: that helper walks
      // `allSupertypes` to also catch custom classes that extend/implement
      // `Future`, whereas this rule intentionally checks only the literal
      // annotation type and does not walk supertypes (see the "Scope note"
      // in the class DartDoc above).
      if (!testedType.isDartAsyncFuture) return;

      // v2 false-positive guard: consult the type of the VALUE being tested,
      // not just the type written in the `is` clause. `FutureOr<T>` values
      // legitimately need `is Future<T>` to narrow, and in a synchronous
      // context (an overridden sync interface method, a getter) that is the
      // only available mechanism because `await` would force the function to
      // become async. Reporting there produced an unactionable diagnostic.
      if (_isFutureOrNarrowing(node.expression.staticType, testedType)) return;

      reporter.atNode(node);
    });
  }

  /// True when [valueType] is `FutureOr<T>` and [testedType] is the matching
  /// `Future<T>` — i.e. the `is` check is a legitimate narrowing rather than
  /// a fragile runtime probe of an untyped value.
  ///
  /// Deliberately narrow: it demands STATIC evidence (a `FutureOr` value
  /// type) before suppressing. Anything else — `dynamic`, `Object`, an
  /// unresolved type, or a mismatched type argument — still reports, so the
  /// intended target (`dynamic result; if (result is Future)`) is untouched.
  static bool _isFutureOrNarrowing(DartType? valueType, DartType testedType) {
    // No resolution (syntactic scan pass) or a non-FutureOr value: the rule
    // has no evidence this is a narrowing, so keep reporting.
    if (valueType == null || !valueType.isDartAsyncFutureOr) return false;

    // Both `FutureOr<T>` and `Future<T>` are modeled as InterfaceType by the
    // analyzer, so the type arguments are directly comparable. A missing
    // argument list means the type is raw/erased; treat that as a match
    // because a raw `is Future` on a FutureOr value is still narrowing.
    final DartType? valueArg = _singleTypeArgument(valueType);
    final DartType? testedArg = _singleTypeArgument(testedType);
    if (valueArg == null || testedArg == null) return true;

    // `FutureOr<int>` narrowed by `is Future<int>` — the canonical idiom.
    // A mismatch (e.g. `FutureOr<int>` tested against `Future<String>`) is
    // NOT narrowing and stays reported.
    return valueArg == testedArg;
  }

  /// The sole type argument of [type], or null when [type] is not a
  /// single-argument interface type (raw `Future`, `dynamic`, InvalidType).
  static DartType? _singleTypeArgument(DartType type) {
    if (type is! InterfaceType) return null;
    final List<DartType> args = type.typeArguments;
    if (args.length != 1) return null;
    // A `dynamic` argument means the annotation was written raw (`Future`),
    // which carries no distinguishing information — report it as "no
    // argument" so the caller treats it as a match.
    return args.first is DynamicType ? null : args.first;
  }
}
