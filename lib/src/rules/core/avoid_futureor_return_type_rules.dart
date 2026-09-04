import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import '../../saropa_lint_rule.dart';

/// Flags functions, methods, and getters that declare `FutureOr<T>` as
/// their return type.
///
/// Since: v14.3.4 | Updated: v14.3.5 | Rule version: v2
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

  // Both halves of this rule are resolution work: the return type is matched
  // by resolved DartType (isDartAsyncFutureOr, not the source lexeme), and
  // the override exemption walks the resolved supertype chain
  // (declaredFragment.element.enclosingElement.allSupertypes) to catch
  // overrides that omit `@override`. See _futureOrAnnotation and
  // _isOverride dartdocs for why neither can be done syntactically.
  @override
  RuleCost get cost => RuleCost.medium;

  // Fast pre-filter: skip files that never mention FutureOr at all before
  // paying for AST traversal.
  //
  // KNOWN GAP (deliberate, perf trade-off): a typedef alias declared in
  // ANOTHER file (`typedef MyFutureOr<T> = FutureOr<T>;`) and used here
  // means this file's source may never contain the literal text
  // "FutureOr", so the file is skipped before the resolved-type check
  // below ever runs. Same-file aliases are covered (the typedef itself
  // supplies the literal). Dropping this pre-filter would make the rule
  // visit every function/method declaration in every file in the project;
  // that cost is not worth closing the cross-file alias case, which is
  // rare in practice.
  @override
  Set<String>? get requiredPatterns => const {'FutureOr'};

  static const LintCode _code = LintCode(
    'avoid_futureor_return_type',
    '[avoid_futureor_return_type] Declaring FutureOr<T> as a function, '
        'method, or getter return type forces every caller to perform a '
        'runtime `is Future<T>` check (or blindly await a value that may '
        'not be a Future) before it can safely use the result. This '
        'ambiguity leaks into the entire call chain and makes the API '
        'harder to consume correctly. {v2}',
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
    // lookup is needed here at all.
    context.addFunctionDeclaration((FunctionDeclaration node) {
      final TypeAnnotation? futureOr = _futureOrAnnotation(node.returnType);
      if (futureOr == null) return;
      reporter.atNode(futureOr);
    });

    context.addMethodDeclaration((MethodDeclaration node) {
      // Setters never carry a meaningful return type; skip them outright.
      if (node.isSetter) return;

      // ORDER MATTERS (perf): the return-type match runs FIRST so that
      // _isOverride's allSupertypes walk is paid for only by the handful
      // of methods that actually return FutureOr. The previous shape
      // passed `_isOverride(node)` as an argument, which Dart evaluates
      // eagerly BEFORE the callee could bail — so every method
      // declaration in any file mentioning "FutureOr" paid for a full
      // supertype walk, even the ones rejected on the very next line.
      final TypeAnnotation? futureOr = _futureOrAnnotation(node.returnType);
      if (futureOr == null) return;

      // Overriding methods are skipped: the return type there is
      // constrained by the supertype/interface being implemented, so
      // flagging it would point the fix at a declaration the author
      // cannot change alone without also changing the base declaration —
      // a distinct, separate concern.
      if (_isOverride(node)) return;

      reporter.atNode(futureOr);
    });
  }

  /// Returns [returnType] when it RESOLVES to `dart:async`'s `FutureOr<T>`,
  /// otherwise null.
  ///
  /// Resolution, not the source lexeme, is the correct test here. The
  /// previous implementation compared `NamedType.name.lexeme` against the
  /// literal string 'FutureOr', which was wrong in both directions:
  ///
  /// - FALSE POSITIVE: a user-defined `class FutureOr<T>` that has nothing
  ///   to do with `dart:async` was flagged, and the correction message
  ///   ("make it async and return Future<T>") is nonsense for it — there
  ///   is no sync/async ambiguity in a plain value wrapper.
  /// - FALSE NEGATIVE: `typedef MyFutureOr<T> = FutureOr<T>;` used as a
  ///   return type has the lexeme 'MyFutureOr' but resolves to exactly the
  ///   `dart:async.FutureOr<T>` this rule exists to flag, so the caller-side
  ///   ambiguity was shipped unflagged behind an alias.
  ///
  /// `isDartAsyncFutureOr` checks the resolved type's element identity
  /// (name plus owning `dart:async` library), so it closes both at once and
  /// is unaffected by aliasing or by a trailing `?` on the annotation. It
  /// is the same API already used in `core/async_rules.dart` and
  /// `scan/scan_rule_tracer.dart`.
  ///
  /// A null resolved type (unresolved/erroneous source) is treated as
  /// "not FutureOr" — silence beats guessing, per the false-positive
  /// doctrine.
  TypeAnnotation? _futureOrAnnotation(TypeAnnotation? returnType) {
    if (returnType == null) return null;
    final DartType? type = returnType.type;
    if (!(type?.isDartAsyncFutureOr ?? false)) return null;
    return returnType;
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
