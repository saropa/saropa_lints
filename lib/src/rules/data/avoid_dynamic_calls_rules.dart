// ignore_for_file: depend_on_referenced_packages

/// Detects method calls, property access, and operator invocations
/// performed on a receiver whose static type is `dynamic`.
///
/// Complements the narrower JSON-scoped rules in `type_safety_rules.dart`
/// (`AvoidDynamicJsonAccessRule`, `AvoidDynamicJsonChainsRule`) with a
/// general receiver-type check that fires for ANY dynamically-typed
/// receiver — not only `jsonDecode()` results.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';

import '../../saropa_lint_rule.dart';

/// Warns when a call, property access, or operator is invoked on a
/// receiver whose static type is `dynamic`.
///
/// Since: v15.2.12 | Rule version: v1
///
/// A call on a `dynamic` receiver defers all member-resolution and
/// type-checking to runtime. Typos in method names, wrong argument
/// counts, and type mismatches all compile silently and only surface as
/// a `NoSuchMethodError` in production. This defeats the entire point of
/// Dart's static type system for that call site.
///
/// **Exemption**: calls inside a `noSuchMethod` override are intentional
/// dynamic dispatch and are skipped.
///
/// **BAD:**
/// ```dart
/// void process(dynamic data) {
///   data.calculateTotal(); // no compile-time check this method exists
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void process(Invoice data) {
///   data.calculateTotal(); // statically verified
/// }
/// // or, if the dynamic type is unavoidable (e.g. plugin bridge):
/// void process(dynamic data) {
///   (data as Invoice).calculateTotal();
/// }
/// ```
class AvoidDynamicCallsRule extends SaropaLintRule {
  AvoidDynamicCallsRule() : super(code: _code);

  /// Calls on a dynamic receiver bypass all compile-time verification and
  /// are a frequent, hard-to-test source of production NoSuchMethodError
  /// crashes — warrants a WARNING, consistent with the sibling JSON-access
  /// rules (`avoid_dynamic_json_access`, `avoid_unsafe_cast`).
  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'reliability', 'type-safety'};

  @override
  RuleCost get cost => RuleCost.medium;

  // Detection depends entirely on resolved static types (DynamicType
  // checks below), so this rule must run in a resolved context.
  @override
  bool get usesTypeResolution => true;

  static const LintCode _code = LintCode(
    'avoid_dynamic_calls',
    '[avoid_dynamic_calls] Calling a method, accessing a property, or using '
        'an operator on a receiver typed dynamic bypasses the analyzer\'s '
        'static type checking entirely. Typos in member names, wrong '
        'argument counts, and type mismatches all compile silently and only '
        'surface as a NoSuchMethodError crash at runtime, in production, '
        'often in a code path unit tests never exercise. {v1}',
    correctionMessage:
        'Give the receiver a concrete type (change the parameter/variable/'
        'field type) so the compiler can verify the member exists. If a '
        'concrete type is genuinely unavailable (e.g. a plugin or '
        'reflection bridge), cast explicitly with "as SpecificType" before '
        'calling, so the unsafe boundary is a single visible line.',
    severity: DiagnosticSeverity.WARNING,
  );

  /// Binary operators that resolve to an actual operator-method call on the
  /// left operand (`+`, `<`, `&`, ...). Deliberately excludes `==`, `!=`,
  /// `&&`, and `||` — those resolve through `Object.==`/`bool` logic that
  /// is not meaningfully "unchecked" the way a dynamic arithmetic or
  /// comparison operator call is, and flagging them would just be noise on
  /// ordinary null/bool checks.
  static const Set<String> _operatorInvocationTokens = <String>{
    '+', '-', '*', '/', '~/', '%',
    '<', '<=', '>', '>=',
    '&', '|', '^', '<<', '>>', '>>>',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (_isInsideNoSuchMethod(node)) return;
      if (_hasDynamicStaticType(node.target)) {
        reporter.atNode(node);
      }
    });

    context.addPropertyAccess((PropertyAccess node) {
      if (_isInsideNoSuchMethod(node)) return;
      if (_hasDynamicStaticType(node.target)) {
        reporter.atNode(node);
      }
    });

    context.addPrefixedIdentifier((PrefixedIdentifier node) {
      if (_isInsideNoSuchMethod(node)) return;
      // Import prefixes (e.g. `math.pi`) resolve the prefix identifier to
      // a PrefixElement with no static type — the DynamicType check below
      // naturally excludes them without needing an explicit element check.
      if (_hasDynamicStaticType(node.prefix)) {
        reporter.atNode(node);
      }
    });

    context.addIndexExpression((IndexExpression node) {
      if (_isInsideNoSuchMethod(node)) return;
      if (_hasDynamicStaticType(node.target)) {
        reporter.atNode(node);
      }
    });

    context.addBinaryExpression((BinaryExpression node) {
      if (!_operatorInvocationTokens.contains(node.operator.lexeme)) return;
      if (_isInsideNoSuchMethod(node)) return;
      if (_hasDynamicStaticType(node.leftOperand)) {
        reporter.atNode(node);
      }
    });
  }

  /// Returns true when [expression]'s resolved static type is exactly
  /// `dynamic`. Uses the resolved `DartType` rather than any name/source
  /// matching, per the false-positive doctrine — a field or variable named
  /// "dynamic-something" or holding an `Object` never matches here.
  bool _hasDynamicStaticType(Expression? expression) {
    if (expression == null) return false;
    return expression.staticType is DynamicType;
  }

  /// `noSuchMethod` overrides intentionally dispatch dynamically; a call
  /// made on `invocation.positionalArguments[0]` or similar inside one is
  /// the whole point of the override, not an oversight to flag.
  bool _isInsideNoSuchMethod(AstNode node) {
    final MethodDeclaration? method =
        node.thisOrAncestorOfType<MethodDeclaration>();
    return method?.name.lexeme == 'noSuchMethod';
  }
}
