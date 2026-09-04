import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import '../../saropa_lint_rule.dart';

/// Flags functions, methods, and getters that declare `FutureOr<T>` as
/// their return type.
///
/// Since: v14.3.4 | Updated: v14.3.4 | Rule version: v1
///
/// A `FutureOr<T>` return type pushes the sync/async decision onto every
/// caller: each call site must runtime-check `is Future<T>` (or blindly
/// `await` a value that might not be a Future) before it can safely use the
/// result. This is different from `prefer_unwrapping_future_or`
/// (`code_quality_prefer_rules.dart`), which only flags a top-level
/// `FunctionDeclaration` returning `FutureOr` when the body is a
/// `BlockFunctionBody` with no `await` — a narrower, INFO-severity subset.
/// This rule flags the return-type declaration itself, unconditionally
/// (including methods and getters, which the other rule never reaches),
/// because the caller-side ambiguity exists regardless of what the function
/// body does internally. The two rules are EXPECTED to double-fire on the
/// overlapping subset (a sync top-level function with an explicit
/// `FutureOr<T>` return type) — that is a known, accepted overlap, not a
/// bug; do not "fix" one rule to silence the other without re-reading both
/// dartdocs first.
///
/// **BAD:**
/// ```dart
/// FutureOr<int> getValue() => 42;
/// ```
///
/// **GOOD:**
/// ```dart
/// Future<int> getValue() async => 42;
/// int getValueSync() => 42;
/// ```
class AvoidFutureorReturnTypeRule extends SaropaLintRule {
  AvoidFutureorReturnTypeRule() : super(code: _code);

  /// API-design smell: forces callers into runtime type checks. Not a bug,
  /// but worth flagging as it compounds across a public API surface.
  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'async', 'api-design'};

  // The return-type check itself is a cheap lexeme comparison, but the
  // override exemption now walks the resolved supertype chain
  // (declaredFragment.element.enclosingElement.allSupertypes) to catch
  // overrides that omit `@override`, which is resolution work — so this
  // is no longer trivial-cost. See _isOverride's dartdoc for why the
  // annotation-only check was insufficient.
  @override
  RuleCost get cost => RuleCost.medium;

  // Fast pre-filter: skip files that never mention FutureOr at all before
  // paying for AST traversal.
  @override
  Set<String>? get requiredPatterns => const {'FutureOr'};

  static const LintCode _code = LintCode(
    'avoid_futureor_return_type',
    '[avoid_futureor_return_type] Declaring FutureOr<T> as a function, '
        'method, or getter return type forces every caller to perform a '
        'runtime `is Future<T>` check (or blindly await a value that may '
        'not be a Future) before it can safely use the result. This '
        'ambiguity leaks into the entire call chain and makes the API '
        'harder to consume correctly. {v1}',
    correctionMessage:
        'Pick one concrete return type: make the function async and '
        'declare Future<T> if it is ever asynchronous, or declare the '
        'plain T if it never is. Split into two differently named '
        'functions if callers genuinely need both a sync and an async '
        'variant.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Top-level functions can never override anything, so no supertype
    // lookup is needed here — only the metadata fast-path check applies.
    context.addFunctionDeclaration((FunctionDeclaration node) {
      _reportIfFutureOr(reporter, node.returnType, isOverride: false);
    });

    context.addMethodDeclaration((MethodDeclaration node) {
      // Setters never carry a meaningful return type; skip them outright.
      if (node.isSetter) return;
      _reportIfFutureOr(
        reporter,
        node.returnType,
        isOverride: _isOverride(node),
      );
    });
  }

  /// Reports [returnType] when it is a bare `FutureOr<...>` annotation and
  /// [isOverride] is false.
  ///
  /// Overriding methods are skipped: the return type there is constrained
  /// by the supertype/interface being implemented, so flagging it would
  /// point the fix at a declaration the author cannot change alone without
  /// also changing the base declaration — a distinct, separate concern.
  void _reportIfFutureOr(
    SaropaDiagnosticReporter reporter,
    TypeAnnotation? returnType, {
    required bool isOverride,
  }) {
    if (returnType is! NamedType) return;
    // Exact-name check only — never substring/contains matching on the
    // type name, per the project false-positive doctrine.
    if (returnType.name.lexeme != 'FutureOr') return;
    if (isOverride) return;

    reporter.atNode(returnType);
  }

  /// True when [node] overrides a member declared by one of its class's
  /// supertypes (extends/implements/with), whether or not `@override` is
  /// physically present on the declaration.
  ///
  /// The original implementation trusted the `@override` annotation alone,
  /// which is a lint convention (`annotate_overrides`), not a language
  /// requirement — a class that `implements` an interface declaring
  /// `FutureOr<T> compute()` without adding `@override` had its override
  /// incorrectly flagged as an independent declaration the author could
  /// change unilaterally. Walking `allSupertypes` and checking for a
  /// same-named method/getter fixes this at the cost of resolution work
  /// (hence the RuleCost.medium bump above), and also covers the `@override`
  /// case for free, so the old metadata check is now redundant and removed.
  bool _isOverride(MethodDeclaration node) {
    final ExecutableElement? element = node.declaredFragment?.element;
    final Element? enclosing = element?.enclosingElement;
    if (enclosing is! InterfaceElement) return false;

    final String name = node.name.lexeme;
    for (final InterfaceType supertype in enclosing.allSupertypes) {
      final InterfaceElement superElement = supertype.element;
      if (node.isGetter) {
        if (superElement.getters.any((GetterElement g) => g.name == name)) {
          return true;
        }
      } else {
        if (superElement.methods.any((MethodElement m) => m.name == name)) {
          return true;
        }
      }
    }
    return false;
  }
}
