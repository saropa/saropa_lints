import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';

import '../../saropa_lint_rule.dart';

/// Warns when a `throw` statement throws a raw `String` instead of a typed
/// exception class.
///
/// Since: v15.2.12 | Updated: v15.2.12 | Rule version: v1
///
/// A bare `String` thrown as an error is legal Dart, but it cannot be caught
/// selectively by type: `catch (e) { ... }` sees only an `Object`, and any
/// `on String catch` clause is unusual and brittle. Every catch site is
/// forced to either swallow all errors or pattern-match on message text,
/// which breaks the moment the wording changes. A project-defined
/// `Exception`/`Error` subclass gives callers a real type to branch on
/// (`if (e is InvalidAgeException)`), independent of the message text.
///
/// This rule targets ONLY the bare-`String` case. Generic `throw
/// Exception(...)`/`throw Error(...)` calls are a related but distinct
/// smell already covered by `avoid_generic_exceptions` — flagging both here
/// too would double-report the same violation under two rule names.
///
/// ## Deliberate scoping — do NOT add Exception-hierarchy walking
///
/// Detection asks only two questions about the thrown expression: is it a
/// `StringLiteral`, or is its resolved static type `String`? It never inspects
/// the Exception/Error class hierarchy. That is why `throw ArgumentError(...)`,
/// `throw StateError(...)` and `throw UnimplementedError(...)` are exempt
/// STRUCTURALLY rather than via an allow-list, and why classes that implement
/// `Exception` indirectly (through a base class or a mixin) are never
/// mis-flagged. Adding hierarchy inspection — or looking at a constructor's
/// `String` ARGUMENT instead of the thrown expression's own type — would
/// reintroduce exactly that false-positive class. Guarded by the GOOD cases in
/// `test/rules/flow/prefer_typed_exceptions_test.dart`.
///
/// ## Known limitation: `dynamic`-typed holders are missed
///
/// `final dynamic message = 'boom'; throw message;` is NOT reported. The
/// declared type is `dynamic`, so `staticType.isDartCoreString` is false even
/// though the value is a `String` at runtime. This is inherent to
/// static-type-only detection; closing it would require value/flow analysis
/// that this rule deliberately avoids, and the resulting heuristic would cost
/// far more in false positives than the rare `dynamic` holder is worth. The
/// miss is pinned as current behavior by a test so it cannot change silently.
///
/// **BAD:**
/// ```dart
/// void validate(int age) {
///   if (age < 0) {
///     throw 'Age cannot be negative';
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class InvalidAgeException implements Exception {
///   const InvalidAgeException(this.message);
///   final String message;
/// }
///
/// void validate(int age) {
///   if (age < 0) {
///     throw const InvalidAgeException('Age cannot be negative');
///   }
/// }
/// ```
class PreferTypedExceptionsRule extends SaropaLintRule {
  PreferTypedExceptionsRule() : super(code: _code);

  /// Architectural-hygiene smell, not an immediate bug in the flagged code
  /// itself — matches the rule's Comprehensive tier placement.
  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'reliability'};

  @override
  RuleCost get cost => RuleCost.low;

  // Detection needs the resolved static type of the thrown expression (to
  // catch `throw someStringVariable;`, not just literal `throw 'text';`),
  // so this rule requires a resolved analysis context.
  @override
  bool get usesTypeResolution => true;

  // Cheap pre-filter: every violation contains the `throw` keyword, so files
  // without it can never match and are skipped before parsing.
  @override
  Set<String>? get requiredPatterns => const {'throw'};

  static const LintCode _code = LintCode(
    'prefer_typed_exceptions',
    "[prefer_typed_exceptions] Throwing a raw String instead of a typed "
        "exception class. A String thrown as an error cannot be caught "
        "selectively by type — catch (e) sees only an Object, and callers "
        "are forced to either catch everything or inspect message text, "
        "which breaks the moment the wording changes. A project-defined "
        "exception subclass (implements Exception) gives callers a real "
        "type to branch on instead. {v1}",
    correctionMessage:
        'Define a purpose-specific exception class implementing Exception '
        '(or extending Error) and throw an instance of it instead of a raw '
        'String. Example: throw const InvalidAgeException("Age cannot be '
        'negative") instead of throw "Age cannot be negative".',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addThrowExpression((ThrowExpression node) {
      final Expression thrown = node.expression;

      // Literal case (`throw 'text';`) is decidable from the AST node kind
      // alone — no type resolution needed, and it also covers the common
      // interpolated-string case (`throw 'Bad: $reason';`).
      if (thrown is StringLiteral) {
        reporter.atNode(node);
        return;
      }

      // Non-literal case (`throw someStringVariable;` or `throw
      // buildMessage();` where the return type is String): only the
      // resolved static type distinguishes this from a legitimate typed
      // exception, so check the type rather than the expression shape.
      final DartType? staticType = thrown.staticType;
      if (staticType != null && staticType.isDartCoreString) {
        reporter.atNode(node);
      }
    });
  }
}
