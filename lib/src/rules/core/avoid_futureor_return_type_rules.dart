import 'package:analyzer/dart/ast/ast.dart';

import '../../saropa_lint_rule.dart';

/// Flags functions, methods, and getters that declare `FutureOr<T>` as
/// their return type.
///
/// Since: v14.3.4 | Updated: v14.3.4 | Rule version: v1
///
/// A `FutureOr<T>` return type pushes the sync/async decision onto every
/// caller: each call site must runtime-check `is Future<T>` (or blindly
/// `await` a value that might not be a Future) before it can safely use the
/// result. This is different from `prefer_unwrapping_future_or`, which only
/// flags a `FutureOr` return when the function body has no `await` and is a
/// simple block body — this rule flags the return-type declaration itself,
/// unconditionally, because the caller-side ambiguity exists regardless of
/// what the function body does internally.
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

  // Cheap syntactic check on the return-type annotation only — no type
  // resolution required, so this stays trivial-cost.
  @override
  RuleCost get cost => RuleCost.trivial;

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
    context.addFunctionDeclaration((FunctionDeclaration node) {
      _reportIfFutureOr(reporter, node.returnType, node.metadata);
    });

    context.addMethodDeclaration((MethodDeclaration node) {
      // Setters never carry a meaningful return type; skip them outright.
      if (node.isSetter) return;
      _reportIfFutureOr(reporter, node.returnType, node.metadata);
    });
  }

  /// Reports [returnType] when it is a bare `FutureOr<...>` annotation.
  ///
  /// Overriding methods are skipped: the return type there is constrained
  /// by the supertype/interface being implemented, so flagging it would
  /// point the fix at a declaration the author cannot change alone without
  /// also changing the base declaration — a distinct, separate concern.
  void _reportIfFutureOr(
    SaropaDiagnosticReporter reporter,
    TypeAnnotation? returnType,
    NodeList<Annotation> metadata,
  ) {
    if (returnType is! NamedType) return;
    // Exact-name check only — never substring/contains matching on the
    // type name, per the project false-positive doctrine.
    if (returnType.name.lexeme != 'FutureOr') return;

    final bool isOverride = metadata.any(
      (Annotation a) => a.name.name == 'override',
    );
    if (isOverride) return;

    reporter.atNode(returnType);
  }
}
