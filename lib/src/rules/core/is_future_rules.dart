// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';

import '../../saropa_lint_rule.dart';

/// Warns when a runtime `is Future` / `is Future<T>` type check is used to
/// branch behavior on whether a value is asynchronous.
///
/// Since: v14.3.3 | Updated: v14.3.3 | Rule version: v1
///
/// A runtime `is Future` check is fragile: `Future<T>` erasure and
/// `FutureOr<T>` make the test unreliable across generic boundaries, and a
/// value that is synchronously available under `FutureOr<T>` still needs
/// uniform handling. The correct fix is almost always to type the parameter
/// as `FutureOr<T>` and `await` it directly — `await` on a non-Future value
/// simply returns that value, so the branch becomes unnecessary.
///
/// Fires on both `x is Future` and the negated `x is! Future` — the negation
/// does not change the underlying fragility, only which branch runs first.
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
    '[is_future] Runtime "is Future" type check used to branch on whether a '
        'value is asynchronous. This is fragile: Future<T> generic erasure '
        'and FutureOr<T> make the check unreliable across generic '
        'boundaries, and a Future subclass or a synchronously-available '
        'FutureOr<T> value can produce surprising results. {v1}',
    correctionMessage:
        'Type the parameter as FutureOr<T> and use "await value" directly — '
        'awaiting a non-Future value simply returns it, making the runtime '
        'check unnecessary. If the source type is genuinely outside your '
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
      // need to worry about that near-miss separately — verified against
      // the identical `_staticTypeIsFuture` helper pattern used elsewhere
      // in this package (lib/src/rules/core/async_rules.dart).
      if (testedType.isDartAsyncFuture) {
        reporter.atNode(node);
      }
    });
  }
}
