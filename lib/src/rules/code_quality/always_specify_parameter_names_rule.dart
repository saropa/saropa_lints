// ignore_for_file: depend_on_referenced_packages, always_specify_types

/// Lint rule that flags call sites passing 2+ consecutive positional arguments
/// of confusable types where named arguments could disambiguate.
///
/// Targets the classic "which argument is which" bug class:
/// `createUser('Smith', 'John')` where first/last names are silently swappable.
///
/// See proposal: plans/tier_1_quick_wins/proposal_always_specify_parameter_names.md
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import '../../saropa_lint_rule.dart';
import 'always_specify_parameter_names_helpers.dart';

/// Flags call sites that pass 2+ consecutive positional arguments of the same
/// or confusable static type without named arguments, creating silent swap risk.
///
/// ### Why this rule exists
///
/// When two adjacent positional parameters share a type (e.g. two Strings),
/// swapping them at the call site compiles cleanly and silently produces wrong
/// behavior. Named arguments make the call self-documenting and immune to
/// accidental swaps.
///
/// ### Example of **bad** code:
/// ```dart
/// void createUser(String firstName, String lastName) {}
/// createUser('Smith', 'John'); // LINT — two adjacent Strings, easy to swap
/// ```
///
/// ### Example of **good** code:
/// ```dart
/// void createUser({required String firstName, required String lastName}) {}
/// createUser(firstName: 'John', lastName: 'Smith'); // OK — named, unambiguous
/// ```
class AlwaysSpecifyParameterNamesRule extends SaropaLintRule {
  AlwaysSpecifyParameterNamesRule() : super(code: _code);

  /// INFO-level: this is advisory, not a hard error.
  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'readability', 'safety'};

  /// Medium cost: requires type resolution for every invocation.
  @override
  RuleCost get cost => RuleCost.medium;

  @override
  bool get usesTypeResolution => true;

  static const LintCode _code = LintCode(
    'always_specify_parameter_names',
    '[always_specify_parameter_names] Call passes multiple consecutive '
        'positional arguments of the same type, risking a silent argument '
        'swap that the compiler cannot catch. {v1}',
    correctionMessage:
        'Consider declaring these parameters as named to prevent accidental '
        'reordering (e.g. {required String firstName, required String lastName}).',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Method calls: foo.bar(a, b) and bar(a, b)
    context.addMethodInvocation((MethodInvocation node) {
      final element = node.methodName.element;
      _checkInvocation(
        reporter: reporter,
        arguments: node.argumentList,
        element: element,
      );
    });

    // Constructor calls: MyClass(a, b)
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final element = node.constructorName.element;
      // Skip allowlisted constructors (Offset, Point, Size, etc.)
      if (_isAllowlistedConstructor(node)) return;
      _checkInvocation(
        reporter: reporter,
        arguments: node.argumentList,
        element: element,
      );
    });

    // Function expression invocations: callback(a, b)
    context.addFunctionExpressionInvocation(
      (FunctionExpressionInvocation node) {
        final element = node.element;
        _checkInvocation(
          reporter: reporter,
          arguments: node.argumentList,
          element: element,
        );
      },
    );
  }
}

/// Returns true if the constructor invocation targets an allowlisted class
/// (e.g. Offset, Point, Size) where positional pairs are idiomatic.
bool _isAllowlistedConstructor(InstanceCreationExpression node) {
  final constructorElement = node.constructorName.element;
  if (constructorElement == null) return false;

  // enclosingElement.name is nullable for Element but non-null for classes;
  // null key safely returns null from the map, so the allowlist falls through
  final className = constructorElement.enclosingElement.name;
  final minArgs = allowlistedConstructors[className];
  if (minArgs == null) return false;

  // Only allowlist when the call has at most the expected positional count —
  // unusual overloads should still be checked.
  final positionalCount = node.argumentList.arguments
      .where((arg) => arg is! NamedExpression)
      .length;
  return positionalCount <= minArgs;
}

/// Core detection: examines an argument list against its callee's declared
/// parameters, looking for runs of 2+ consecutive positional args with
/// confusable types.
void _checkInvocation({
  required SaropaDiagnosticReporter reporter,
  required ArgumentList arguments,
  required Element? element,
}) {
  // Need the callee's parameter declarations for type resolution
  if (element is! ExecutableElement) return;

  final params = element.formalParameters;
  if (params.isEmpty) return;

  // Collect only the positional (non-named) arguments in call-site order
  final positionalArgs = collectPositionalArgs(arguments);

  // Need at least 2 positional args to form a confusable pair
  if (positionalArgs.length < 2) return;

  // Build the confusable-type-group name for each positional arg
  final typeNames = buildTypeNames(positionalArgs);

  // Find and report runs of 2+ consecutive confusable types
  final runs = findConfusableRuns(typeNames);
  for (final (start, _) in runs) {
    // Report at the first argument of each confusable run so the developer
    // sees which arguments triggered the diagnostic.
    reporter.atNode(positionalArgs[start]);
  }
}
