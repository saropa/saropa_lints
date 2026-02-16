// ignore_for_file: depend_on_referenced_packages, deprecated_member_use, always_specify_types

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;

import '../ignore_utils.dart';
import '../saropa_lint_rule.dart';
import '../type_annotation_utils.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Warns against any usage of adjacent strings.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Adjacent strings can be confusing and error-prone.
///
/// Example of **bad** code:
/// ```dart
/// final message = 'Hello' 'World';
/// ```
///
/// Example of **good** code:
/// ```dart
/// final message = 'HelloWorld';
/// ```
class AvoidAdjacentStringsRule extends SaropaLintRule {
  const AvoidAdjacentStringsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_adjacent_strings',
    problemMessage:
        '[avoid_adjacent_strings] Adjacent string literals detected without an explicit concatenation operator. Dart implicitly joins adjacent strings, which can mask accidental line breaks or missing commas in list literals, leading to silently merged values that are difficult to debug. {v4}',
    correctionMessage:
        'Combine into a single string literal, use the + operator for explicit concatenation, or use string interpolation to make the intent clear.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addAdjacentStrings((AdjacentStrings node) {
      reporter.atNode(node, code);
    });
  }
}

/// Warns when accessing enum values by index (`EnumName.values[i]`).
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
class AvoidEnumValuesByIndexRule extends SaropaLintRule {
  const AvoidEnumValuesByIndexRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_enum_values_by_index',
    problemMessage:
        '[avoid_enum_values_by_index] Enum value accessed by numeric index on the .values list. If enum members are reordered or new values are inserted, the index silently resolves to the wrong constant, causing incorrect behavior that the compiler cannot catch. {v4}',
    correctionMessage:
        'Use EnumName.values.byName() for string-based lookup, or switch on specific enum values to get compile-time exhaustiveness checking.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addIndexExpression((IndexExpression node) {
      final Expression? target = node.target;
      if (target is! PropertyAccess) return;

      // Check for .values property access
      if (target.propertyName.name != 'values') return;

      // Check if target is likely an enum (PascalCase identifier)
      final Expression? enumTarget = target.target;
      if (enumTarget is SimpleIdentifier) {
        final String name = enumTarget.name;
        if (name.isNotEmpty &&
            name[0] == name[0].toUpperCase() &&
            !name.startsWith('_')) {
          reporter.atNode(node, code);
        }
      } else if (enumTarget is PrefixedIdentifier) {
        final String name = enumTarget.identifier.name;
        if (name.isNotEmpty &&
            name[0] == name[0].toUpperCase() &&
            !name.startsWith('_')) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when Uri constructor is called with an invalid URI string.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// final uri = Uri.parse('not a valid uri[]');
/// ```
///
/// #### GOOD:
/// ```dart
/// final uri = Uri.parse('https://example.com/path');
/// ```
class AvoidIncorrectUriRule extends SaropaLintRule {
  const AvoidIncorrectUriRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_incorrect_uri',
    problemMessage:
        '[avoid_incorrect_uri] URI string appears to be malformed or contains invalid characters. Malformed URIs cause runtime exceptions when parsed by Uri.parse(), leading to unhandled errors in network requests, routing logic, or deep link handling. {v4}',
    correctionMessage:
        'Verify the URI syntax matches RFC 3986, ensure special characters are percent-encoded, and test with Uri.parse() to confirm validity.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final Expression? target = node.target;
      if (target is! SimpleIdentifier) return;
      if (target.name != 'Uri') return;

      final String methodName = node.methodName.name;
      if (methodName != 'parse' && methodName != 'tryParse') return;

      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isEmpty) return;

      final Expression firstArg = args.first;
      if (firstArg is! SimpleStringLiteral) return;

      final String uriString = firstArg.value;

      // Basic validation checks
      if (_hasInvalidUriCharacters(uriString)) {
        reporter.atNode(firstArg, code);
      }
    });

    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Uri') return;

      // Check for Uri() constructor with invalid string argument
      // The main Uri constructor uses named parameters, so check Uri.parse pattern above
    });
  }

  bool _hasInvalidUriCharacters(String uri) {
    // Check for obviously invalid characters
    const Set<String> invalidChars = <String>{
      '[',
      ']',
      '{',
      '}',
      '|',
      '\\',
      '^',
      '`',
      '<',
      '>',
    };

    for (int i = 0; i < uri.length; i++) {
      if (invalidChars.contains(uri[i])) {
        // Allow [ ] in IPv6 addresses
        if ((uri[i] == '[' || uri[i] == ']') && uri.contains('://[')) {
          continue;
        }
        return true;
      }
    }

    // Check for spaces (should be encoded)
    if (uri.contains(' ') && !uri.contains('%20')) {
      return true;
    }

    return false;
  }
}

/// Warns when late keyword is used.
///
/// Since: v1.8.2 | Updated: v4.13.0 | Rule version: v7
///
/// Late variables can lead to runtime errors if accessed before initialization.
/// Consider using nullable types or initializing in the constructor.
class AvoidLateKeywordRule extends SaropaLintRule {
  const AvoidLateKeywordRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_late_keyword',
    problemMessage:
        "[avoid_late_keyword] Field declared with the 'late' keyword defers initialization checking to runtime. If the field is accessed before assignment, Dart throws a LateInitializationError that crashes the app, bypassing the null safety guarantees the type system provides at compile time. {v7}",
    correctionMessage:
        'Use a nullable type with a null check, provide a default value, or initialize the field in the constructor to keep initialization errors visible at compile time.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addVariableDeclaration((VariableDeclaration node) {
      final AstNode? parent = node.parent;
      if (parent is VariableDeclarationList && parent.lateKeyword != null) {
        reporter.atNode(node, code);
      }
    });

    context.registry.addFieldDeclaration((FieldDeclaration node) {
      if (node.fields.lateKeyword != null) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when a getter is called without parentheses in print/debugPrint.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// This catches common cases where a method/getter reference is passed to
/// print instead of calling it.
///
/// Example of **bad** code:
/// ```dart
/// print(list.length);  // OK - property
/// print(myMethod);  // BAD - probably meant myMethod()
/// ```
///
/// Example of **good** code:
/// ```dart
/// print(myMethod());  // Method is called
/// ```
class AvoidMissedCallsRule extends SaropaLintRule {
  const AvoidMissedCallsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_missed_calls',
    problemMessage:
        '[avoid_missed_calls] Function reference passed without parentheses where a call was likely intended. Without the () invocation, the function is not executed and the reference is silently discarded, meaning the intended side effect or return value is lost. {v5}',
    correctionMessage:
        'Add parentheses () to invoke the function, or if the reference is intentional, assign it to a variable with an explicit function type.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (methodName != 'print' && methodName != 'debugPrint') {
        return;
      }

      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isEmpty) return;

      final Expression firstArg = args.first;

      // Check if argument is a simple identifier (potential tear-off)
      if (firstArg is SimpleIdentifier) {
        // Check if it looks like a function name (starts with verb)
        final String name = firstArg.name;
        if (_looksLikeFunctionName(name)) {
          reporter.atNode(firstArg, code);
        }
      }
    });
  }

  bool _looksLikeFunctionName(String name) {
    // Common function prefixes that indicate it should be called
    const List<String> prefixes = <String>[
      'get',
      'set',
      'fetch',
      'load',
      'save',
      'create',
      'build',
      'make',
      'compute',
      'calculate',
      'process',
      'handle',
      'on',
      'do',
      'run',
      'execute',
      'init',
      'dispose',
      'start',
      'stop',
    ];

    final String lower = name.toLowerCase();
    for (final String prefix in prefixes) {
      if (lower.startsWith(prefix) && name.length > prefix.length) {
        // Check if next char is uppercase (camelCase)
        if (name[prefix.length].toUpperCase() == name[prefix.length]) {
          return true;
        }
      }
    }
    return false;
  }
}

/// Warns when a set literal is used where another type is expected.
///
/// Since: v1.7.2 | Updated: v4.13.0 | Rule version: v2
///
/// This catches cases where `{}` is used but interpreted as a Set
/// when a Map was likely intended.
///
/// Example of **bad** code:
/// ```dart
/// Map<String, int> map = {};  // This is actually a Set literal!
/// var items = {1, 2, 3};  // Set when Map might be expected
/// ```
///
/// Example of **good** code:
/// ```dart
/// Map<String, int> map = <String, int>{};  // Explicit Map
/// Set<int> items = {1, 2, 3};  // Explicit Set type
/// ```
class AvoidMisusedSetLiteralsRule extends SaropaLintRule {
  const AvoidMisusedSetLiteralsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.high;

  static const LintCode _code = LintCode(
    name: 'avoid_misused_set_literals',
    problemMessage: '[avoid_misused_set_literals] Set literal may be misused. '
        'Empty `{}` without type annotation creates a Map, not a Set. {v2}',
    correctionMessage: 'Add explicit type annotation: `<Type>{}` for Set '
        'or `<K, V>{}` for Map.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSetOrMapLiteral((SetOrMapLiteral node) {
      // Only check empty literals without type arguments
      if (node.elements.isNotEmpty) return;
      if (node.typeArguments != null) return;

      // Check if context expects a specific type
      final DartType? contextType = node.staticType;
      if (contextType == null) return;

      // Warn if the empty literal could be ambiguous
      final String typeStr = contextType.getDisplayString();
      if (typeStr.startsWith('Map<') || typeStr.startsWith('Set<')) {
        // Type is inferred, but empty {} can be confusing
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when an object is passed as an argument to its own method.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// This rule catches potential circular reference bugs where an object
/// reference is passed to its own method.
///
/// **Note:** Literal values (int, double, string, bool, null) are excluded
/// from this check since they are values, not object references that could
/// cause circular reference issues.
///
/// Example of **bad** code:
/// ```dart
/// list.add(list);  // Adding list to itself
/// map[key] = map;  // Assigning map to itself
/// ```
///
/// Example of **good** code:
/// ```dart
/// list.add(item);
/// map[key] = value;
/// 0.isBetween(0, 10);  // OK - literals are values, not references
/// ```
class AvoidPassingSelfAsArgumentRule extends SaropaLintRule {
  const AvoidPassingSelfAsArgumentRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_passing_self_as_argument',
    problemMessage:
        '[avoid_passing_self_as_argument] Object passed as an argument to its own method, creating a self-referential call. This pattern often indicates a logic error and can lead to infinite recursion, stack overflow, or unexpected mutation of the object state during method execution. {v4}',
    correctionMessage:
        'Extract the shared logic into a separate method, pass a different object, or restructure the call to eliminate the self-reference.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final Expression? target = node.target;
      if (target == null) return;

      // Skip literals - they are values, not object references that could
      // cause circular reference issues (e.g., 0.isBetween(0, 10) is fine)
      if (target is Literal) return;

      final String targetSource = target.toSource();

      // Check if any argument matches the target
      for (final Expression arg in node.argumentList.arguments) {
        final Expression actualArg =
            arg is NamedExpression ? arg.expression : arg;
        if (actualArg.toSource() == targetSource) {
          reporter.atNode(actualArg, code);
        }
      }
    });
  }
}

/// Warns when a function calls itself directly (recursive call).
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// Recursive functions can lead to stack overflow if not properly guarded.
/// Consider using iteration or ensuring proper base cases.
///
/// Example of **bad** code:
/// ```dart
/// int factorial(int n) {
///   return n * factorial(n - 1);  // Missing base case check
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// int factorial(int n) {
///   if (n <= 1) return 1;
///   return n * factorial(n - 1);
/// }
/// // or use iteration
/// int factorial(int n) {
///   int result = 1;
///   for (int i = 2; i <= n; i++) {
///     result *= i;
///   }
///   return result;
/// }
/// ```
class AvoidRecursiveCallsRule extends SaropaLintRule {
  const AvoidRecursiveCallsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_recursive_calls',
    problemMessage:
        '[avoid_recursive_calls] Function contains a direct recursive call to itself. Without a guaranteed base case or depth limit, unbounded recursion exhausts the call stack and crashes the application with a StackOverflowError, which cannot be caught in Dart. {v5}',
    correctionMessage:
        'Verify a terminating base case exists for all input paths, or convert the recursion to an iterative approach using a loop or explicit stack.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
      final String functionName = node.name.lexeme;
      final FunctionBody body = node.functionExpression.body;

      _checkBodyForRecursion(body, functionName, reporter);
    });

    context.registry.addMethodDeclaration((MethodDeclaration node) {
      final String methodName = node.name.lexeme;
      final FunctionBody body = node.body;

      _checkBodyForRecursion(body, methodName, reporter);
    });
  }

  void _checkBodyForRecursion(
    FunctionBody body,
    String functionName,
    SaropaDiagnosticReporter reporter,
  ) {
    final _RecursiveCallVisitor visitor =
        _RecursiveCallVisitor(functionName, reporter, code);
    body.accept(visitor);
  }
}

class _RecursiveCallVisitor extends RecursiveAstVisitor<void> {
  _RecursiveCallVisitor(this.functionName, this.reporter, this.code);

  final String functionName;
  final SaropaDiagnosticReporter reporter;
  final LintCode code;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == functionName && node.realTarget == null) {
      reporter.atNode(node, code);
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    final Expression function = node.function;
    if (function is SimpleIdentifier && function.name == functionName) {
      reporter.atNode(node, code);
    }
    super.visitFunctionExpressionInvocation(node);
  }
}

/// Warns when toString() method calls itself, causing infinite recursion.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// Example of **bad** code:
/// ```dart
/// class User {
///   @override
///   String toString() => 'User: $this';  // Calls toString() recursively
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// class User {
///   final String name;
///   @override
///   String toString() => 'User: $name';
/// }
/// ```
class AvoidRecursiveToStringRule extends SaropaLintRule {
  const AvoidRecursiveToStringRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_recursive_tostring',
    problemMessage:
        '[avoid_recursive_tostring] toString() method references itself through \$this or this.toString(), creating infinite recursion. The runtime repeatedly invokes toString() until the call stack overflows, crashing the application with an unrecoverable StackOverflowError. {v5}',
    correctionMessage:
        'Reference individual fields directly (e.g. \$name, \$id) instead of \$this, or build the string using a StringBuffer to control the representation explicitly.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme != 'toString') return;
      if (node.returnType?.toSource() != 'String') {
        // Check if it could still be toString override
        final DartType? returnType = node.returnType?.type;
        if (returnType != null && !returnType.isDartCoreString) return;
      }

      final FunctionBody body = node.body;
      final _ToStringRecursionVisitor visitor =
          _ToStringRecursionVisitor(reporter, code);
      body.accept(visitor);
    });
  }
}

class _ToStringRecursionVisitor extends RecursiveAstVisitor<void> {
  _ToStringRecursionVisitor(this.reporter, this.code);

  final SaropaDiagnosticReporter reporter;
  final LintCode code;

  @override
  void visitInterpolationExpression(InterpolationExpression node) {
    // Check for $this in string interpolation
    final Expression expression = node.expression;
    if (expression is ThisExpression) {
      reporter.atNode(node, code);
    }
    super.visitInterpolationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // Check for this.toString() or toString() on this
    if (node.methodName.name == 'toString') {
      final Expression? target = node.realTarget;
      if (target == null || target is ThisExpression) {
        reporter.atNode(node, code);
      }
    }
    super.visitMethodInvocation(node);
  }
}

/// Warns when referencing discarded/underscore-prefixed variables.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// Variables starting with underscore are meant to be unused.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// final _unused = getValue();
/// print(_unused); // Using a "discarded" variable
/// ```
///
/// #### GOOD:
/// ```dart
/// final value = getValue();
/// print(value);
/// ```
class AvoidReferencingDiscardedVariablesRule extends SaropaLintRule {
  const AvoidReferencingDiscardedVariablesRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_referencing_discarded_variables',
    problemMessage:
        '[avoid_referencing_discarded_variables] Variable prefixed with underscore is referenced after declaration. The underscore prefix signals that the value is intentionally discarded, so reading it later contradicts the naming convention and confuses developers who expect underscore-prefixed variables to be unused. {v5}',
    correctionMessage:
        'Rename the variable without the underscore prefix if it is actually used, or remove the reference if the variable should remain discarded.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  // Cached regex for performance
  static final RegExp _discardedVarPattern = RegExp(r'^_[a-z]');

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSimpleIdentifier((SimpleIdentifier node) {
      final String name = node.name;

      // Check for underscore-prefixed local variables (not private members)
      // Single underscore is a wildcard, we check for _name pattern
      if (name.length > 1 &&
          name.startsWith('_') &&
          !name.startsWith('__') &&
          _discardedVarPattern.hasMatch(name)) {
        // Use resolved element to distinguish locals from members/methods
        final element = node.element;

        // If we cannot resolve the element, be conservative and skip
        if (element == null) return;

        // Only flag local variables; skip class members/getters/setters/methods/etc.
        if (element is! LocalVariableElement) {
          return;
        }

        // Skip if this identifier is part of its own declaration
        final AstNode? parent = node.parent;
        if (parent is VariableDeclaration && parent.name == node.token) return;

        // Skip assignment on the left-hand side
        if (parent is AssignmentExpression && parent.leftHandSide == node) {
          return;
        }

        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when @pragma('vm:prefer-inline') is used redundantly.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// Pragma inline annotations should only be used when necessary.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// @pragma('vm:prefer-inline')
/// int get value => 1; // Trivial getter, inlining is automatic
/// ```
///
/// #### GOOD:
/// ```dart
/// int get value => 1; // Let compiler decide
/// // OR for complex cases:
/// @pragma('vm:prefer-inline')
/// Matrix4 computeTransform() => /* complex computation */;
/// ```
class AvoidRedundantPragmaInlineRule extends SaropaLintRule {
  const AvoidRedundantPragmaInlineRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_redundant_pragma_inline',
    problemMessage:
        '[avoid_redundant_pragma_inline] Pragma inline annotation applied to a trivial method that the compiler already inlines automatically. Redundant annotations add noise to the codebase, and overusing pragma inline can prevent the compiler from making better optimization decisions. {v5}',
    correctionMessage:
        'Remove the @pragma(vm:prefer-inline) annotation from simple getters, setters, and one-line methods that the compiler inlines by default.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      // Check for pragma annotation
      bool hasPragmaInline = false;
      Annotation? pragmaAnnotation;

      for (final Annotation annotation in node.metadata) {
        if (annotation.name.name == 'pragma') {
          final ArgumentList? args = annotation.arguments;
          if (args != null && args.arguments.isNotEmpty) {
            final Expression firstArg = args.arguments.first;
            if (firstArg is SimpleStringLiteral) {
              if (firstArg.value.contains('inline')) {
                hasPragmaInline = true;
                pragmaAnnotation = annotation;
                break;
              }
            }
          }
        }
      }

      if (!hasPragmaInline || pragmaAnnotation == null) return;

      // Check if method is trivial (expression body with simple expression)
      final FunctionBody body = node.body;
      if (body is ExpressionFunctionBody) {
        final Expression expr = body.expression;
        // Simple expressions that would inline anyway
        if (expr is SimpleIdentifier ||
            expr is Literal ||
            expr is ThisExpression ||
            expr is PrefixedIdentifier) {
          reporter.atNode(pragmaAnnotation, code);
        }
      }
    });
  }
}

/// Warns when String.substring() is used.
///
/// Since: v4.1.3 | Updated: v4.13.0 | Rule version: v3
///
/// `substring` can cause runtime errors if indices are out of bounds.
/// Prefer safer alternatives like pattern matching, split, or replaceRange.
///
/// Example of **bad** code:
/// ```dart
/// final result = text.substring(5, 10);
/// ```
///
/// Example of **good** code:
/// ```dart
/// final result = text.length >= 10 ? text.substring(5, 10) : text;
/// // or use split/pattern matching for extracting parts
/// ```
class AvoidSubstringRule extends SaropaLintRule {
  const AvoidSubstringRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_string_substring',
    problemMessage:
        '[avoid_string_substring] substring() throws RangeError if start or end indices are out of bounds, causing runtime crashes when input lengths vary. '
        'This is especially dangerous with user input, API responses, or dynamically sized strings where the length cannot be guaranteed at compile time. {v3}',
    correctionMessage:
        'Check string length before calling substring(), or use safer alternatives such as split(), replaceRange(), or pattern matching. '
        'For optional extraction, consider an extension method that returns null for invalid ranges instead of throwing.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name == 'substring') {
        final DartType? targetType = node.realTarget?.staticType;
        if (targetType != null && targetType.isDartCoreString) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when unknown pragma annotations are used.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v3
///
/// Only known pragma values should be used.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// @pragma('unknown:value')
/// void foo() { }
/// ```
///
/// #### GOOD:
/// ```dart
/// @pragma('vm:prefer-inline')
/// void foo() { }
/// ```
class AvoidUnknownPragmaRule extends SaropaLintRule {
  const AvoidUnknownPragmaRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_unknown_pragma',
    problemMessage:
        '[avoid_unknown_pragma] Unrecognized pragma annotation detected. Unknown pragmas are silently ignored by the Dart compiler, which means the intended optimization or behavior hint has no effect and may mislead developers into thinking the code is optimized when it is not. {v3}',
    correctionMessage:
        'Use a recognized pragma value such as vm:prefer-inline, vm:never-inline, or dart2js:tryInline, or remove the annotation entirely.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _knownPragmas = <String>{
    'vm:prefer-inline',
    'vm:never-inline',
    'vm:entry-point',
    'vm:external-name',
    'vm:invisible',
    'vm:recognized',
    'vm:idempotent',
    'vm:cachable-idempotent',
    'vm:isolate-unsendable',
    'vm:deeply-immutable',
    'vm:awaiter-link',
    'dart2js:noInline',
    'dart2js:tryInline',
    'dart2js:as:trust',
    'dart2js:late:check',
    'dart2js:late:trust',
    'dart2js:resource-identifier',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addAnnotation((Annotation node) {
      if (node.name.name != 'pragma') return;

      final ArgumentList? args = node.arguments;
      if (args == null || args.arguments.isEmpty) return;

      final Expression firstArg = args.arguments.first;
      if (firstArg is! SimpleStringLiteral) return;

      final String pragmaValue = firstArg.value;
      if (!_knownPragmas.contains(pragmaValue)) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when a function parameter is unused.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v6
///
/// Unused parameters can indicate dead code or incomplete implementation.
///
/// Example of **bad** code:
/// ```dart
/// void process(String data, int count) {
///   print(data);  // count is never used
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// void process(String data, int count) {
///   print('$data x $count');
/// }
/// // Or mark as intentionally unused:
/// void process(String data, int _) { ... }
/// ```
class AvoidUnusedParametersRule extends SaropaLintRule {
  const AvoidUnusedParametersRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_unused_parameters',
    problemMessage:
        '[avoid_unused_parameters] Function parameter is declared but never referenced in the function body. Unused parameters add cognitive overhead for callers who must provide a value that has no effect, and they mask API design issues — either remove the parameter or complete the implementation that was supposed to use it. {v6}',
    correctionMessage:
        'Remove the parameter from the function signature, or prefix it with an underscore to indicate it is intentionally unused for interface conformance.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
      _checkParameters(
        node.functionExpression.parameters,
        node.functionExpression.body,
        reporter,
      );
    });

    context.registry.addMethodDeclaration((MethodDeclaration node) {
      // Skip overrides (parameters may be required by interface)
      for (final Annotation annotation in node.metadata) {
        if (annotation.name.name == 'override') {
          return;
        }
      }

      _checkParameters(node.parameters, node.body, reporter);
    });
  }

  void _checkParameters(
    FormalParameterList? params,
    FunctionBody? body,
    SaropaDiagnosticReporter reporter,
  ) {
    if (params == null || body == null) return;

    // Collect parameter names
    final Map<String, FormalParameter> paramMap = <String, FormalParameter>{};
    for (final FormalParameter param in params.parameters) {
      final String? name = param.name?.lexeme;
      if (name != null && !name.startsWith('_')) {
        paramMap[name] = param;
      }
    }

    if (paramMap.isEmpty) return;

    // Find all used identifiers in the body
    final Set<String> usedNames = <String>{};
    body.visitChildren(_IdentifierCollector(usedNames));

    // Report unused parameters
    for (final MapEntry<String, FormalParameter> entry in paramMap.entries) {
      if (!usedNames.contains(entry.key)) {
        reporter.atNode(entry.value, code);
      }
    }
  }
}

class _IdentifierCollector extends RecursiveAstVisitor<void> {
  _IdentifierCollector(this.names);
  final Set<String> names;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    names.add(node.name);
    super.visitSimpleIdentifier(node);
  }
}

/// Warns when weak cryptographic algorithms like MD5 or SHA1 are used.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// MD5 and SHA1 are considered cryptographically broken and should not be used
/// for security purposes.
///
/// Example of **bad** code:
/// ```dart
/// import 'dart:convert';
/// import 'package:crypto/crypto.dart';
/// final hash = md5.convert(utf8.encode('password'));
/// final hash2 = sha1.convert(utf8.encode('password'));
/// ```
///
/// Example of **good** code:
/// ```dart
/// import 'package:crypto/crypto.dart';
/// final hash = sha256.convert(utf8.encode('password'));
/// ```
class AvoidWeakCryptographicAlgorithmsRule extends SaropaLintRule {
  const AvoidWeakCryptographicAlgorithmsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_weak_cryptographic_algorithms',
    problemMessage:
        '[avoid_weak_cryptographic_algorithms] Weak or deprecated cryptographic algorithm detected (e.g. MD5, SHA-1). These algorithms have known collision vulnerabilities that allow attackers to forge hashes, compromising data integrity verification, password storage, and digital signature validation. {v5}',
    correctionMessage:
        'Replace with a stronger algorithm such as SHA-256, SHA-512, or bcrypt for password hashing. Use the crypto or pointycastle package for secure implementations.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _weakAlgorithms = <String>{
    'md5',
    'sha1',
    'MD5',
    'SHA1',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSimpleIdentifier((SimpleIdentifier node) {
      if (_weakAlgorithms.contains(node.name)) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when a function returns a value that should have @useResult.
///
/// Since: v4.9.5 | Updated: v4.13.0 | Rule version: v5
class MissingUseResultAnnotationRule extends SaropaLintRule {
  const MissingUseResultAnnotationRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'missing_use_result_annotation',
    problemMessage:
        '[missing_use_result_annotation] Function returns a value without @useResult annotation. Callers may accidentally ignore the return value, leading to missed error handling, lost data transformations, or incorrectly assuming the function has side effects when it does not. {v5}',
    correctionMessage:
        'Add @useResult annotation above the function declaration to signal that the returned value must be used. Include a reason parameter explaining what happens if the value is ignored.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      // Skip void returns and setters
      if (node.isSetter) return;
      final TypeAnnotation? returnType = node.returnType;
      if (returnType == null) return;

      final String typeStr = returnType.toSource();
      if (typeStr == 'void' || typeStr == 'Future<void>') return;

      // Skip if already has useResult annotation
      for (final Annotation annotation in node.metadata) {
        final String name = annotation.name.name;
        if (name == 'useResult' || name == 'UseResult') return;
      }

      // Check for common builder/factory patterns that should use @useResult
      final String methodName = node.name.lexeme;
      final List<String> builderPatterns = <String>[
        'build',
        'create',
        'make',
        'generate',
        'compute',
        'calculate',
        'parse',
        'convert',
        'transform',
      ];

      for (final String pattern in builderPatterns) {
        if (methodName.toLowerCase().startsWith(pattern)) {
          reporter.atToken(node.name, code);
          return;
        }
      }
    });
  }
}

/// Warns when a member is declared with type `Object`.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Using Object type is often a sign of missing generics or improper typing.
///
/// Example of **bad** code:
/// ```dart
/// class MyClass {
///   Object data;  // Too generic
///   Object process(Object input) => input;
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// class MyClass<T> {
///   T data;
///   T process(T input) => input;
/// }
/// ```
class NoObjectDeclarationRule extends SaropaLintRule {
  const NoObjectDeclarationRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'no_object_declaration',
    problemMessage:
        '[no_object_declaration] Member declared with type Object, which erases all type information. Accessing any property or method requires an unsafe downcast, bypassing compile-time type checking and risking runtime cast errors that could have been prevented with a more specific type. {v4}',
    correctionMessage:
        'Replace Object with the most specific type that applies, use generics to preserve type information, or use a sealed class hierarchy for known subtypes.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFieldDeclaration((FieldDeclaration node) {
      final TypeAnnotation? type = node.fields.type;
      if (type is NamedType && type.name.lexeme == 'Object') {
        reporter.atNode(type, code);
      }
    });

    context.registry.addMethodDeclaration((MethodDeclaration node) {
      final TypeAnnotation? returnType = node.returnType;
      if (returnType is NamedType && returnType.name.lexeme == 'Object') {
        reporter.atNode(returnType, code);
      }
    });
  }
}

/// Warns when only one inlining annotation is used.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v3
///
/// If using vm:prefer-inline, also use dart2js:tryInline for consistency.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// @pragma('vm:prefer-inline')
/// void foo() { }
/// ```
///
/// #### GOOD:
/// ```dart
/// @pragma('vm:prefer-inline')
/// @pragma('dart2js:tryInline')
/// void foo() { }
/// ```
class PreferBothInliningAnnotationsRule extends SaropaLintRule {
  const PreferBothInliningAnnotationsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_both_inlining_annotations',
    problemMessage:
        '[prefer_both_inlining_annotations] Only one inlining pragma is present, but the Dart VM and dart2js compilers use different annotations. Without both vm:prefer-inline and dart2js:tryInline, the function is only inlined on one platform, leaving the other without the intended optimization. {v3}',
    correctionMessage:
        'Add the missing counterpart annotation: use @pragma(dart2js:tryInline) alongside @pragma(vm:prefer-inline), or vice versa.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    void checkAnnotations(NodeList<Annotation> metadata, Token reportAt) {
      bool hasVmInline = false;
      bool hasDart2jsInline = false;

      for (final Annotation annotation in metadata) {
        if (annotation.name.name != 'pragma') continue;

        final ArgumentList? args = annotation.arguments;
        if (args == null || args.arguments.isEmpty) continue;

        final Expression firstArg = args.arguments.first;
        if (firstArg is! SimpleStringLiteral) continue;

        final String value = firstArg.value;
        if (value == 'vm:prefer-inline' || value == 'vm:never-inline') {
          hasVmInline = true;
        }
        if (value == 'dart2js:tryInline' || value == 'dart2js:noInline') {
          hasDart2jsInline = true;
        }
      }

      if (hasVmInline != hasDart2jsInline) {
        reporter.atToken(reportAt, code);
      }
    }

    context.registry.addMethodDeclaration((MethodDeclaration node) {
      checkAnnotations(node.metadata, node.name);
    });

    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
      checkAnnotations(node.metadata, node.name);
    });
  }
}

/// Warns when using `MediaQuery.of(context).size` instead of dedicated methods.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v6
///
/// Alias: prefer_dedicated_media_query_methods
///
/// Flutter provides dedicated methods like `MediaQuery.sizeOf(context)` which
/// are more efficient and clearer.
///
/// Example of **bad** code:
/// ```dart
/// final size = MediaQuery.of(context).size;
/// final padding = MediaQuery.of(context).padding;
/// ```
///
/// Example of **good** code:
/// ```dart
/// final size = MediaQuery.sizeOf(context);
/// final padding = MediaQuery.paddingOf(context);
/// ```
class PreferDedicatedMediaQueryMethodRule extends SaropaLintRule {
  const PreferDedicatedMediaQueryMethodRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_dedicated_media_query_method',
    problemMessage:
        '[prefer_dedicated_media_query_method] MediaQuery.of(context) accessed for a single property. This registers a dependency on the entire MediaQueryData object, causing the widget to rebuild whenever any media query value changes (orientation, padding, text scale), even if only one property is needed. {v6}',
    correctionMessage:
        'Use the dedicated method such as MediaQuery.sizeOf(context), MediaQuery.paddingOf(context), or MediaQuery.textScaleFactorOf(context) to depend only on the specific property.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _dedicatedProperties = <String>{
    'size',
    'padding',
    'viewInsets',
    'viewPadding',
    'orientation',
    'devicePixelRatio',
    'textScaleFactor',
    'platformBrightness',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addPropertyAccess((PropertyAccess node) {
      // Check for pattern: MediaQuery.of(context).size
      final Expression? target = node.target;
      if (target is! MethodInvocation) return;

      // Check if it's MediaQuery.of(...)
      final Expression? targetTarget = target.target;
      if (targetTarget is! SimpleIdentifier) return;
      if (targetTarget.name != 'MediaQuery') return;
      if (target.methodName.name != 'of') return;

      // Check if the property is one that has a dedicated method
      final String propertyName = node.propertyName.name;
      if (_dedicatedProperties.contains(propertyName)) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when enum values are found using firstWhere instead of byName.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// Example of **bad** code:
/// ```dart
/// MyEnum.values.firstWhere((e) => e.name == 'value');
/// ```
///
/// Example of **good** code:
/// ```dart
/// MyEnum.values.byName('value');
/// ```
class PreferEnumsByNameRule extends SaropaLintRule {
  const PreferEnumsByNameRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_enums_by_name',
    problemMessage:
        '[prefer_enums_by_name] Enum lookup uses firstWhere with name comparison instead of the built-in byName() method. The manual approach is more verbose, less readable, and throws a generic StateError on mismatch instead of the descriptive ArgumentError that byName() provides. {v5}',
    correctionMessage:
        'Replace .firstWhere((e) => e.name == x) with .byName(x) for cleaner code and a more descriptive error message on lookup failure.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'firstWhere') return;

      // Check if target is .values
      final Expression? target = node.target;
      if (target is! PropertyAccess) return;
      if (target.propertyName.name != 'values') return;

      // Check if the argument is a function that compares .name
      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isEmpty) return;

      final Expression firstArg = args.first;
      if (firstArg is FunctionExpression) {
        final FunctionBody body = firstArg.body;
        if (body is ExpressionFunctionBody) {
          final Expression expr = body.expression;
          // Check for pattern: e.name == 'something' or 'something' == e.name
          if (expr is BinaryExpression &&
              expr.operator.type == TokenType.EQ_EQ) {
            final bool isNameComparison = _isNameAccess(expr.leftOperand) ||
                _isNameAccess(expr.rightOperand);
            if (isNameComparison) {
              reporter.atNode(node, code);
            }
          }
        }
      }
    });
  }

  bool _isNameAccess(Expression expr) {
    if (expr is PrefixedIdentifier) {
      return expr.identifier.name == 'name';
    }
    if (expr is PropertyAccess) {
      return expr.propertyName.name == 'name';
    }
    return false;
  }
}

/// Warns when inline function callbacks should be extracted.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
class PreferExtractingFunctionCallbacksRule extends SaropaLintRule {
  const PreferExtractingFunctionCallbacksRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_extracting_function_callbacks',
    problemMessage:
        '[prefer_extracting_function_callbacks] Large inline callback detected spanning 10+ lines. Inline callbacks make code harder to read, test in isolation, and reuse across multiple call sites, reducing code maintainability and increasing complexity. {v4}',
    correctionMessage:
        'Extract this callback to a separate named method or private function. This enables unit testing the logic independently, improves readability by giving the behavior a descriptive name, and allows reuse.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const int _maxCallbackLines = 10;

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFunctionExpression((FunctionExpression node) {
      // Skip if not used as an argument
      final AstNode? parent = node.parent;
      if (parent is! NamedExpression && parent is! ArgumentList) return;

      // Check function body size
      final FunctionBody body = node.body;
      if (body is! BlockFunctionBody) return;

      final CompilationUnit unit = node.root as CompilationUnit;
      final int startLine = unit.lineInfo.getLocation(body.offset).lineNumber;
      final int endLine = unit.lineInfo.getLocation(body.end).lineNumber;
      final int lineCount = endLine - startLine + 1;

      if (lineCount > _maxCallbackLines) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when spreading a nullable collection without null-aware spread.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// final list = [...?nullableList ?? []];
/// final combined = items != null ? [...items] : [];
/// ```
///
/// #### GOOD:
/// ```dart
/// final list = [...?nullableList];
/// final combined = [...?items];
/// ```
class PreferNullAwareSpreadRule extends SaropaLintRule {
  const PreferNullAwareSpreadRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_null_aware_spread',
    problemMessage:
        '[prefer_null_aware_spread] Nullable collection spread without null-aware operator. Spreading a nullable list or set without ...? throws a runtime TypeError when the value is null, crashing the collection literal construction instead of gracefully contributing zero elements. {v4}',
    correctionMessage:
        'Replace ...nullableCollection with ...?nullableCollection so that null values are treated as empty and contribute no elements to the result.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSpreadElement((SpreadElement node) {
      // Check for ...?(x ?? []) pattern
      final Expression expr = node.expression;
      if (node.isNullAware && expr is BinaryExpression) {
        if (expr.operator.lexeme == '??') {
          final Expression right = expr.rightOperand;
          if (right is ListLiteral && right.elements.isEmpty) {
            reporter.atNode(node, code);
          }
        }
      }
    });

    // Check for ternary patterns like: items != null ? [...items] : []
    context.registry.addConditionalExpression((ConditionalExpression node) {
      final Expression condition = node.condition;
      final Expression thenExpr = node.thenExpression;
      final Expression elseExpr = node.elseExpression;

      // Check for x != null ? [...x] : [] pattern
      if (condition is BinaryExpression &&
          condition.operator.lexeme == '!=' &&
          condition.rightOperand is NullLiteral) {
        if (thenExpr is ListLiteral &&
            thenExpr.elements.length == 1 &&
            elseExpr is ListLiteral &&
            elseExpr.elements.isEmpty) {
          final CollectionElement firstElement = thenExpr.elements.first;
          if (firstElement is SpreadElement && !firstElement.isNullAware) {
            reporter.atNode(node, code);
          }
        }
      }
    });
  }
}

/// Warns when @visibleForTesting should be used on members.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Test-only members should be annotated.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// class Foo {
///   // Used only in tests but not annotated
///   void testHelper() { }
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// class Foo {
///   @visibleForTesting
///   void testHelper() { }
/// }
/// ```
class PreferVisibleForTestingOnMembersRule extends SaropaLintRule {
  const PreferVisibleForTestingOnMembersRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_visible_for_testing_on_members',
    problemMessage:
        '[prefer_visible_for_testing_on_members] Member exposed solely for testing lacks the @visibleForTesting annotation. Without the annotation, the analyzer cannot warn when production code accidentally calls the test-only member, breaking the intended encapsulation boundary. {v4}',
    correctionMessage:
        'Add the @visibleForTesting annotation from package:meta so the analyzer flags any non-test usage of this member as a warning.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _testIndicators = <String>{
    'test',
    'Test',
    'mock',
    'Mock',
    'fake',
    'Fake',
    'stub',
    'Stub',
    'spy',
    'Spy',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Skip test files
    if (resolver.path.contains('_test.dart') ||
        resolver.path.contains('/test/') ||
        resolver.path.contains('\\test\\')) {
      return;
    }

    void checkMember(Token nameToken, NodeList<Annotation> metadata) {
      final String name = nameToken.lexeme;

      // Check if name suggests it's for testing
      bool suggestsTest = false;
      for (final String indicator in _testIndicators) {
        if (name.contains(indicator)) {
          suggestsTest = true;
          break;
        }
      }

      if (!suggestsTest) return;

      // Check if already has @visibleForTesting
      for (final Annotation annotation in metadata) {
        if (annotation.name.name == 'visibleForTesting') return;
      }

      reporter.atToken(nameToken, code);
    }

    context.registry.addMethodDeclaration((MethodDeclaration node) {
      checkMember(node.name, node.metadata);
    });

    context.registry.addFieldDeclaration((FieldDeclaration node) {
      for (final VariableDeclaration variable in node.fields.variables) {
        checkMember(variable.name, node.metadata);
      }
    });
  }
}

/// Warns when a named parameter is passed as null explicitly.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Example of **bad** code:
/// ```dart
/// void foo({String? name}) { }
/// foo(name: null);  // Explicitly passing null
/// ```
///
/// Example of **good** code:
/// ```dart
/// void foo({String? name}) { }
/// foo();  // Omit the parameter instead of passing null
/// ```
class AvoidAlwaysNullParametersRule extends SaropaLintRule {
  const AvoidAlwaysNullParametersRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_always_null_parameters',
    problemMessage:
        '[avoid_always_null_parameters] Parameter is explicitly passed as null at every call site. Passing null as a constant argument adds noise, makes the call site harder to read, and defeats the purpose of optional parameters, which default to null when omitted. {v4}',
    correctionMessage:
        'Omit the parameter entirely and let the default value apply, or if null has semantic meaning, document why it is passed explicitly.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Check each method invocation for null arguments
    context.registry.addMethodInvocation((MethodInvocation node) {
      for (final Expression arg in node.argumentList.arguments) {
        // Only check named parameters passed as explicit null
        if (arg is NamedExpression && arg.expression is NullLiteral) {
          reporter.atNode(arg, code);
        }
      }
    });

    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      for (final Expression arg in node.argumentList.arguments) {
        // Only check named parameters passed as explicit null
        if (arg is NamedExpression && arg.expression is NullLiteral) {
          reporter.atNode(arg, code);
        }
      }
    });
  }
}

/// Warns when an instance method assigns to a static field.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v3
///
/// Example of **bad** code:
/// ```dart
/// class Foo {
///   static int counter = 0;
///   void increment() {
///     counter++;  // Instance method modifying static
///   }
/// }
/// ```
class AvoidAssigningToStaticFieldRule extends SaropaLintRule {
  const AvoidAssigningToStaticFieldRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_assigning_to_static_field',
    problemMessage:
        '[avoid_assigning_to_static_field] Instance method modifies a static field, coupling instance behavior to global state. This makes the class unpredictable because any instance can silently alter shared state, causing race conditions in concurrent code and making tests unreliable. {v3}',
    correctionMessage:
        'Move the assignment to a static method if the modification is class-level, or convert the static field to an instance field if the state should be per-instance.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration classNode) {
      // Collect static field names
      final Set<String> staticFields = <String>{};
      for (final ClassMember member in classNode.members) {
        if (member is FieldDeclaration && member.isStatic) {
          for (final VariableDeclaration field in member.fields.variables) {
            staticFields.add(field.name.lexeme);
          }
        }
      }

      if (staticFields.isEmpty) return;

      // Check instance methods
      for (final ClassMember member in classNode.members) {
        if (member is MethodDeclaration && !member.isStatic) {
          _checkMethodBody(member.body, staticFields, reporter);
        }
      }
    });
  }

  void _checkMethodBody(
    FunctionBody body,
    Set<String> staticFields,
    SaropaDiagnosticReporter reporter,
  ) {
    body.visitChildren(
        _StaticFieldAssignmentVisitor(staticFields, reporter, _code));
  }
}

class _StaticFieldAssignmentVisitor extends RecursiveAstVisitor<void> {
  _StaticFieldAssignmentVisitor(this.staticFields, this.reporter, this.code);

  final Set<String> staticFields;
  final SaropaDiagnosticReporter reporter;
  final LintCode code;

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    final Expression left = node.leftHandSide;
    if (left is SimpleIdentifier && staticFields.contains(left.name)) {
      reporter.atNode(node, code);
    }
    super.visitAssignmentExpression(node);
  }

  @override
  void visitPostfixExpression(PostfixExpression node) {
    final Expression operand = node.operand;
    if (operand is SimpleIdentifier && staticFields.contains(operand.name)) {
      reporter.atNode(node, code);
    }
    super.visitPostfixExpression(node);
  }

  @override
  void visitPrefixExpression(PrefixExpression node) {
    final Expression operand = node.operand;
    final TokenType op = node.operator.type;
    if ((op == TokenType.PLUS_PLUS || op == TokenType.MINUS_MINUS) &&
        operand is SimpleIdentifier &&
        staticFields.contains(operand.name)) {
      reporter.atNode(node, code);
    }
    super.visitPrefixExpression(node);
  }
}

/// Warns when an async method is called in a sync function without await.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// Example of **bad** code:
/// ```dart
/// void doWork() {
///   fetchData();  // Async call, result ignored
/// }
/// ```
class AvoidAsyncCallInSyncFunctionRule extends SaropaLintRule {
  const AvoidAsyncCallInSyncFunctionRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.high;

  static const LintCode _code = LintCode(
    name: 'avoid_async_call_in_sync_function',
    problemMessage:
        '[avoid_async_call_in_sync_function] Async function called inside a synchronous function without handling the returned Future. The Future is silently discarded, so any errors thrown by the async operation are swallowed and any result is lost, making failures invisible. {v5}',
    correctionMessage:
        'Mark the enclosing function as async and await the call, chain with .then()/.catchError() for explicit handling, or wrap with unawaited() to document the intentional fire-and-forget.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (_shouldReport(node)) {
        reporter.atNode(node, code);
      }
    });
  }

  bool _shouldReport(MethodInvocation node) {
    // Check if the return type is Future
    final DartType? returnType = node.staticType;
    if (returnType == null) return false;

    final String typeName = returnType.getDisplayString();
    if (!typeName.startsWith('Future')) return false;

    // Check if we're in a sync function
    final FunctionBody? body = _findEnclosingFunctionBody(node);
    if (body == null || body.isAsynchronous) return false;

    // Exempt cleanup calls in lifecycle methods — standard Flutter pattern.
    // dispose/didUpdateWidget/deactivate cannot be async, and
    // cancel()/close() are expected fire-and-forget cleanup calls.
    if (_isCleanupInLifecycle(node, body)) return false;

    // Exempt StreamController.close() in void callbacks (onDone/onError)
    if (_isCloseInVoidCallback(node)) return false;

    // Walk through transparent wrappers (parentheses, postfix !)
    AstNode? parent = node.parent;
    while (parent is ParenthesizedExpression || parent is PostfixExpression) {
      parent = parent?.parent;
    }

    // OK if assigned, awaited, returned, or passed as argument
    if (parent is VariableDeclaration) return false;
    if (parent is AssignmentExpression) return false;
    if (parent is ReturnStatement) return false;
    if (parent is ArgumentList) return false;
    if (parent is AwaitExpression) return false;
    if (parent is MethodInvocation) {
      final String name = parent.methodName.name;
      if (name == 'then' ||
          name == 'catchError' ||
          name == 'whenComplete' ||
          name == 'ignore') {
        return false;
      }
    }

    // Unhandled Future in sync context
    return parent is ExpressionStatement;
  }

  FunctionBody? _findEnclosingFunctionBody(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is FunctionBody) return current;
      current = current.parent;
    }
    return null;
  }

  /// Cleanup calls (cancel/close) in lifecycle methods are safe.
  /// These methods cannot be async and fire-and-forget is expected.
  bool _isCleanupInLifecycle(
    MethodInvocation node,
    FunctionBody enclosingBody,
  ) {
    final AstNode? declaration = enclosingBody.parent;
    if (declaration is! MethodDeclaration) return false;

    final String name = declaration.name.lexeme;
    if (name != 'dispose' &&
        name != 'didUpdateWidget' &&
        name != 'deactivate') {
      return false;
    }

    final String called = node.methodName.name;
    return called == 'cancel' || called == 'close';
  }

  /// StreamController.close() in onDone/onError callbacks is safe.
  /// These callbacks are void Function(), so await is impossible.
  bool _isCloseInVoidCallback(MethodInvocation node) {
    if (node.methodName.name != 'close') return false;

    final Expression? target = node.target;
    if (target != null) {
      final DartType? type = target.staticType;
      if (type is InterfaceType && type.element.name != 'StreamController') {
        return false;
      }
    }

    AstNode? current = node.parent;
    while (current != null) {
      if (current is NamedExpression) {
        final String name = current.name.label.name;
        return name == 'onDone' || name == 'onError';
      }
      if (current is MethodDeclaration || current is FunctionDeclaration) {
        break;
      }
      current = current.parent;
    }
    return false;
  }
}

/// Warns when loop conditions are too complex.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Example of **bad** code:
/// ```dart
/// while (a && b || c && d && e) { }
/// ```
class AvoidComplexLoopConditionsRule extends SaropaLintRule {
  const AvoidComplexLoopConditionsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_complex_loop_conditions',
    problemMessage:
        '[avoid_complex_loop_conditions] Loop condition contains too many operators or nested expressions, making it difficult to reason about when the loop terminates. Complex conditions increase the risk of off-by-one errors and infinite loops that are hard to diagnose. {v4}',
    correctionMessage:
        'Extract the condition into a named boolean variable or a separate method with a descriptive name that communicates the loop termination intent.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const int _maxOperators = 2;

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addWhileStatement((WhileStatement node) {
      _checkCondition(node.condition, reporter);
    });

    context.registry.addDoStatement((DoStatement node) {
      _checkCondition(node.condition, reporter);
    });

    context.registry.addForStatement((ForStatement node) {
      final ForLoopParts parts = node.forLoopParts;
      if (parts is ForParts) {
        final Expression? condition = parts.condition;
        if (condition != null) {
          _checkCondition(condition, reporter);
        }
      }
    });
  }

  void _checkCondition(
      Expression condition, SaropaDiagnosticReporter reporter) {
    final int operatorCount = _countLogicalOperators(condition);
    if (operatorCount > _maxOperators) {
      reporter.atNode(condition, code);
    }
  }

  int _countLogicalOperators(Expression expr) {
    int count = 0;
    if (expr is BinaryExpression) {
      final TokenType op = expr.operator.type;
      if (op == TokenType.AMPERSAND_AMPERSAND || op == TokenType.BAR_BAR) {
        count++;
      }
      count += _countLogicalOperators(expr.leftOperand);
      count += _countLogicalOperators(expr.rightOperand);
    } else if (expr is ParenthesizedExpression) {
      count += _countLogicalOperators(expr.expression);
    }
    return count;
  }
}

/// Warns when both sides of a binary expression are constants.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Example of **bad** code:
/// ```dart
/// if (1 > 2) { }  // Always false
/// final x = 'a' + 'b';  // Should be 'ab'
/// ```
class AvoidConstantConditionsRule extends SaropaLintRule {
  const AvoidConstantConditionsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_constant_conditions',
    problemMessage:
        '[avoid_constant_conditions] Condition evaluates to a compile-time constant, making one branch unreachable dead code. This usually indicates a logic error where the condition was intended to be dynamic, or leftover debugging code that was never cleaned up. {v4}',
    correctionMessage:
        'Remove the condition and keep only the reachable branch, or replace the constant with the intended dynamic expression that varies at runtime.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addBinaryExpression((BinaryExpression node) {
      final TokenType op = node.operator.type;

      // Only check comparison operators
      if (op != TokenType.EQ_EQ &&
          op != TokenType.BANG_EQ &&
          op != TokenType.LT &&
          op != TokenType.LT_EQ &&
          op != TokenType.GT &&
          op != TokenType.GT_EQ) {
        return;
      }

      // Check if both sides are literals
      if (_isConstant(node.leftOperand) && _isConstant(node.rightOperand)) {
        reporter.atNode(node, code);
      }
    });
  }

  bool _isConstant(Expression expr) {
    return expr is IntegerLiteral ||
        expr is DoubleLiteral ||
        expr is BooleanLiteral ||
        expr is StringLiteral ||
        expr is NullLiteral;
  }
}

/// Warns when contradicting conditions are used.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v3
///
/// Example of **bad** code:
/// ```dart
/// if (x > 5 && x < 3) { }  // Always false
/// if (x == null && x.length > 0) { }  // Second part throws
/// ```
class AvoidContradictoryExpressionsRule extends SaropaLintRule {
  const AvoidContradictoryExpressionsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_contradictory_expressions',
    problemMessage:
        '[avoid_contradictory_expressions] Contradictory conditions detected where two expressions cannot both be true simultaneously. This creates unreachable code paths that silently skip intended logic, indicating a logic error that may cause incorrect behavior or missed edge cases. {v3}',
    correctionMessage:
        'Review the boolean logic to ensure conditions are compatible, remove the contradictory branch, or correct the expression to reflect the intended behavior.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addBinaryExpression((BinaryExpression node) {
      if (node.operator.type != TokenType.AMPERSAND_AMPERSAND) return;

      // Check for x == null && x.something
      final Expression left = node.leftOperand;
      final Expression right = node.rightOperand;

      if (_isNullCheck(left, true)) {
        final String? varName = _getNullCheckedVariable(left);
        if (varName != null && _usesVariable(right, varName)) {
          reporter.atNode(node, code);
        }
      }

      // Check for opposite comparisons like x > 5 && x < 3
      if (left is BinaryExpression && right is BinaryExpression) {
        if (_areOppositeComparisons(left, right)) {
          reporter.atNode(node, code);
        }
      }
    });
  }

  bool _isNullCheck(Expression expr, bool checkingForNull) {
    if (expr is BinaryExpression) {
      final TokenType op = expr.operator.type;
      if (checkingForNull) {
        return op == TokenType.EQ_EQ &&
            (expr.leftOperand is NullLiteral ||
                expr.rightOperand is NullLiteral);
      }
      return op == TokenType.BANG_EQ &&
          (expr.leftOperand is NullLiteral || expr.rightOperand is NullLiteral);
    }
    return false;
  }

  String? _getNullCheckedVariable(Expression expr) {
    if (expr is BinaryExpression) {
      if (expr.leftOperand is NullLiteral &&
          expr.rightOperand is SimpleIdentifier) {
        return (expr.rightOperand as SimpleIdentifier).name;
      }
      if (expr.rightOperand is NullLiteral &&
          expr.leftOperand is SimpleIdentifier) {
        return (expr.leftOperand as SimpleIdentifier).name;
      }
    }
    return null;
  }

  bool _usesVariable(Expression expr, String varName) {
    if (expr is SimpleIdentifier) return expr.name == varName;
    if (expr is PrefixedIdentifier) return expr.prefix.name == varName;
    if (expr is PropertyAccess) {
      final Expression? target = expr.target;
      if (target is SimpleIdentifier) return target.name == varName;
    }
    if (expr is MethodInvocation) {
      final Expression? target = expr.target;
      if (target is SimpleIdentifier) return target.name == varName;
    }
    if (expr is BinaryExpression) {
      return _usesVariable(expr.leftOperand, varName) ||
          _usesVariable(expr.rightOperand, varName);
    }
    return false;
  }

  bool _areOppositeComparisons(BinaryExpression left, BinaryExpression right) {
    // Very basic check for x > a && x < b where b < a
    // Full implementation would be more sophisticated
    final String leftSource = left.leftOperand.toSource();
    final String rightSource = right.leftOperand.toSource();

    if (leftSource != rightSource) return false;

    final TokenType leftOp = left.operator.type;
    final TokenType rightOp = right.operator.type;

    // Check for obvious contradictions like x > 5 && x < 3
    if ((leftOp == TokenType.GT || leftOp == TokenType.GT_EQ) &&
        (rightOp == TokenType.LT || rightOp == TokenType.LT_EQ)) {
      final Expression leftVal = left.rightOperand;
      final Expression rightVal = right.rightOperand;

      if (leftVal is IntegerLiteral && rightVal is IntegerLiteral) {
        // x > 5 && x < 3 is a contradiction
        if (leftVal.value != null &&
            rightVal.value != null &&
            leftVal.value! >= rightVal.value!) {
          return true;
        }
      }
    }

    return false;
  }
}

/// Warns when catch blocks have identical bodies.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// Example of **bad** code:
/// ```dart
/// try { ... }
/// on FormatException catch (e) { print(e); }
/// on IOException catch (e) { print(e); }  // Same as above
/// ```
class AvoidIdenticalExceptionHandlingBlocksRule extends SaropaLintRule {
  const AvoidIdenticalExceptionHandlingBlocksRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  static const LintCode _code = LintCode(
    name: 'avoid_identical_exception_handling_blocks',
    problemMessage:
        '[avoid_identical_exception_handling_blocks] Multiple catch blocks contain identical handling code. Duplicated exception handling increases maintenance burden because changes must be applied to every copy, and missed updates lead to inconsistent error recovery behavior. {v5}',
    correctionMessage:
        'Combine the exception types into a single catch clause (e.g. on FormatException, IOException catch (e)) or extract the shared handling into a helper method.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addTryStatement((TryStatement node) {
      final NodeList<CatchClause> catches = node.catchClauses;
      if (catches.length < 2) return;

      final List<String> bodies = <String>[];
      for (final CatchClause clause in catches) {
        bodies.add(clause.body.toSource());
      }

      // Check for duplicates
      final Set<String> seen = <String>{};
      for (int i = 0; i < bodies.length; i++) {
        if (seen.contains(bodies[i])) {
          reporter.atNode(catches[i], code);
        }
        seen.add(bodies[i]);
      }
    });
  }
}

/// Warns when a late final field is assigned twice.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Example of **bad** code:
/// ```dart
/// late final int value;
/// void init() {
///   value = 1;
///   value = 2;  // Error at runtime
/// }
/// ```
class AvoidLateFinalReassignmentRule extends SaropaLintRule {
  const AvoidLateFinalReassignmentRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_late_final_reassignment',
    problemMessage:
        '[avoid_late_final_reassignment] Late final field has multiple assignment paths, which throws a LateInitializationError at runtime on the second write. The compiler cannot catch this statically, so the crash only surfaces during execution of the specific code path that triggers the duplicate assignment. {v4}',
    correctionMessage:
        'Ensure the late final field is assigned exactly once across all code paths, or convert it to a non-final late field if reassignment is intentional.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration classNode) {
      // Collect late final field names
      final Set<String> lateFinalFields = <String>{};
      for (final ClassMember member in classNode.members) {
        if (member is FieldDeclaration) {
          if (member.fields.isLate && member.fields.isFinal) {
            for (final VariableDeclaration field in member.fields.variables) {
              if (field.initializer == null) {
                lateFinalFields.add(field.name.lexeme);
              }
            }
          }
        }
      }

      if (lateFinalFields.isEmpty) return;

      // Track assignments per method
      for (final ClassMember member in classNode.members) {
        if (member is MethodDeclaration) {
          final Map<String, int> assignments = <String, int>{};
          member.body.visitChildren(
            _LateFinalAssignmentCounter(
                lateFinalFields, assignments, reporter, _code),
          );
        }
        if (member is ConstructorDeclaration) {
          final Map<String, int> assignments = <String, int>{};
          member.body.visitChildren(
            _LateFinalAssignmentCounter(
                lateFinalFields, assignments, reporter, _code),
          );
        }
      }
    });
  }
}

class _LateFinalAssignmentCounter extends RecursiveAstVisitor<void> {
  _LateFinalAssignmentCounter(
      this.lateFinalFields, this.assignments, this.reporter, this.code);

  final Set<String> lateFinalFields;
  final Map<String, int> assignments;
  final SaropaDiagnosticReporter reporter;
  final LintCode code;

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    final Expression left = node.leftHandSide;
    if (left is SimpleIdentifier && lateFinalFields.contains(left.name)) {
      final int count = assignments[left.name] ?? 0;
      assignments[left.name] = count + 1;
      if (count >= 1) {
        reporter.atNode(node, code);
      }
    }
    super.visitAssignmentExpression(node);
  }
}

/// Warns when Completer.completeError is called without stack trace.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Example of **bad** code:
/// ```dart
/// completer.completeError(error);  // Missing stack trace
/// ```
///
/// Example of **good** code:
/// ```dart
/// completer.completeError(error, stackTrace);
/// ```
class AvoidMissingCompleterStackTraceRule extends SaropaLintRule {
  const AvoidMissingCompleterStackTraceRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_missing_completer_stack_trace',
    problemMessage:
        '[avoid_missing_completer_stack_trace] Completer.completeError() called without passing the stack trace as the second argument. Without the original stack trace, error reports show only the completeError() call site instead of the actual failure origin, making debugging asynchronous errors significantly harder. {v4}',
    correctionMessage:
        'Pass the stack trace as the second argument to completeError(error, stackTrace) to preserve the full async error chain for debugging.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'completeError') return;

      // Check argument count
      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.length < 2) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when a map indexed by enum is missing some enum values.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v3
///
/// Example of **bad** code:
/// ```dart
/// enum Status { active, inactive, pending }
/// final map = {Status.active: 'A', Status.inactive: 'I'};  // Missing pending
/// ```
class AvoidMissingEnumConstantInMapRule extends SaropaLintRule {
  const AvoidMissingEnumConstantInMapRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_missing_enum_constant_in_map',
    problemMessage:
        '[avoid_missing_enum_constant_in_map] Map literal keyed by enum values does not include all enum constants. When a new enum value is added, this map silently returns null for the missing key instead of producing a compile-time error, leading to unexpected null values or fallback behavior at runtime. {v3}',
    correctionMessage:
        'Add entries for all enum constants to the map, or use a switch expression with exhaustiveness checking to ensure every enum value is handled.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSetOrMapLiteral((SetOrMapLiteral node) {
      if (!node.isMap) return;
      if (node.elements.isEmpty) return;

      // Resolve the enum type from the first key
      final EnumElement? enumElement = _resolveEnumKeyType(node);
      if (enumElement == null) return;

      // Get all declared enum constants
      final Set<String> allConstants = <String>{
        for (final FieldElement f in enumElement.fields)
          if (f.isEnumConstant && f.name != null) f.name!,
      };

      // Get all used constants from map keys
      final Set<String> usedConstants = <String>{};
      for (final CollectionElement element in node.elements) {
        if (element is MapLiteralEntry) {
          final Expression key = element.key;
          if (key is PrefixedIdentifier) {
            usedConstants.add(key.identifier.name);
          } else if (key is SimpleIdentifier) {
            usedConstants.add(key.name);
          }
        }
      }

      // Only flag if there are actually missing constants
      final Set<String> missing = allConstants.difference(usedConstants);
      if (missing.isNotEmpty) {
        reporter.atNode(node, code);
      }
    });
  }

  /// Resolves the enum element from a map literal's key type.
  EnumElement? _resolveEnumKeyType(SetOrMapLiteral node) {
    for (final CollectionElement element in node.elements) {
      if (element is MapLiteralEntry) {
        final Expression key = element.key;
        final DartType? keyType = key.staticType;
        if (keyType is InterfaceType && keyType.element is EnumElement) {
          return keyType.element as EnumElement;
        }
      }
    }
    return null;
  }
}

/// Warns when function parameters are reassigned.
///
/// Since: v4.2.0 | Updated: v4.13.0 | Rule version: v3
///
/// Alias: avoid_mutating_parameters (deprecated)
///
/// Parameter reassignment changes what the local variable points to, but does
/// NOT affect the caller's variable. This is purely a code clarity issue - it
/// makes it harder to track what a parameter's value is at any point in the
/// function. The original input value is lost for debugging.
///
/// **BAD:**
/// ```dart
/// void process(int value) {
///   value = value * 2;  // Reassigning parameter
/// }
///
/// void count(int n) {
///   n++;  // Postfix reassignment
///   ++n;  // Prefix reassignment
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void process(int value) {
///   final doubled = value * 2;  // Use local variable
/// }
/// ```
///
/// **Alternative:** Use `final` parameters (Dart 2.17+) to get compile-time
/// enforcement:
/// ```dart
/// void process(final int value) {
///   value = value * 2;  // Compile error!
/// }
/// ```
class AvoidParameterReassignmentRule extends SaropaLintRule {
  const AvoidParameterReassignmentRule() : super(code: _code);

  /// Style issue - low impact.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_parameter_reassignment',
    problemMessage:
        '[avoid_parameter_reassignment] Parameter is being reassigned. '
        'This hides the original input value. {v3}',
    correctionMessage:
        'Create a local variable instead of reassigning the parameter.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
      final FormalParameterList? params = node.functionExpression.parameters;
      if (params == null) return;

      final Set<String> paramNames = <String>{};
      for (final FormalParameter param in params.parameters) {
        final Token? name = param.name;
        if (name != null) paramNames.add(name.lexeme);
      }

      if (paramNames.isEmpty) return;

      node.functionExpression.body.visitChildren(
        _ParameterReassignmentVisitor(paramNames, reporter, _code),
      );
    });

    context.registry.addMethodDeclaration((MethodDeclaration node) {
      final FormalParameterList? params = node.parameters;
      if (params == null) return;

      final Set<String> paramNames = <String>{};
      for (final FormalParameter param in params.parameters) {
        final Token? name = param.name;
        if (name != null) paramNames.add(name.lexeme);
      }

      if (paramNames.isEmpty) return;

      node.body.visitChildren(
        _ParameterReassignmentVisitor(paramNames, reporter, _code),
      );
    });
  }
}

/// Visitor that detects direct reassignment of parameter variables.
///
/// Checks for: `param = value`, `param++`, `param--`, `++param`, `--param`.
class _ParameterReassignmentVisitor extends RecursiveAstVisitor<void> {
  _ParameterReassignmentVisitor(this.paramNames, this.reporter, this.code);

  final Set<String> paramNames;
  final SaropaDiagnosticReporter reporter;
  final LintCode code;

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    final Expression left = node.leftHandSide;
    if (left is SimpleIdentifier && paramNames.contains(left.name)) {
      reporter.atNode(node, code);
    }
    super.visitAssignmentExpression(node);
  }

  @override
  void visitPostfixExpression(PostfixExpression node) {
    final Expression operand = node.operand;
    if (operand is SimpleIdentifier && paramNames.contains(operand.name)) {
      reporter.atNode(node, code);
    }
    super.visitPostfixExpression(node);
  }

  @override
  void visitPrefixExpression(PrefixExpression node) {
    final TokenType op = node.operator.type;
    if (op == TokenType.PLUS_PLUS || op == TokenType.MINUS_MINUS) {
      final Expression operand = node.operand;
      if (operand is SimpleIdentifier && paramNames.contains(operand.name)) {
        reporter.atNode(node, code);
      }
    }
    super.visitPrefixExpression(node);
  }
}

/// Warns when function parameters are mutated (object state modified).
///
/// Since: v4.2.0 | Updated: v4.13.0 | Rule version: v2
///
/// Mutating a parameter modifies the caller's object, which is a hidden
/// side effect that can cause bugs. The caller may not expect their data
/// to change. This is different from parameter reassignment (which only
/// affects the local reference).
///
/// Detects:
/// - Collection mutations: `param.add()`, `param.clear()`, `param.sort()`
/// - Field assignments: `param.field = value`
/// - Index assignments: `param[i] = value`
/// - Cascade mutations: `param..add()..remove()`
///
/// **BAD:**
/// ```dart
/// void process(List<String> items) {
///   items.add('new');     // Mutates caller's list
///   items.clear();        // Mutates caller's list
/// }
///
/// void updateUser(User user) {
///   user.name = 'changed';  // Mutates caller's object
/// }
///
/// void modify(Map<String, int> map) {
///   map['key'] = 42;  // Index assignment mutation
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void process(List<String> items) {
///   final newItems = [...items, 'new'];  // Create new list
/// }
///
/// User updateUser(User user) {
///   return user.copyWith(name: 'changed');  // Return new instance
/// }
/// ```
class AvoidParameterMutationRule extends SaropaLintRule {
  const AvoidParameterMutationRule() : super(code: _code);

  /// High impact - can cause bugs in calling code.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_parameter_mutation',
    problemMessage:
        '[avoid_parameter_mutation] Parameter object is being mutated. '
        'This modifies the caller\'s data. {v2}',
    correctionMessage:
        'Create a copy of the data instead of mutating the parameter.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Known mutating methods for collection types.
  static const Set<String> _mutatingMethods = <String>{
    // List
    'add',
    'addAll',
    'insert',
    'insertAll',
    'remove',
    'removeAt',
    'removeLast',
    'removeRange',
    'removeWhere',
    'retainWhere',
    'clear',
    'sort',
    'shuffle',
    'setAll',
    'setRange',
    'fillRange',
    'replaceRange',
    // Set
    'removeAll',
    'retainAll',
    // Map
    'addEntries',
    'putIfAbsent',
    'update',
    'updateAll',
    // Queue
    'addFirst',
    'addLast',
    'removeFirst',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
      _checkFunction(
        node.functionExpression.parameters,
        node.functionExpression.body,
        reporter,
      );
    });

    context.registry.addMethodDeclaration((MethodDeclaration node) {
      _checkFunction(node.parameters, node.body, reporter);
    });
  }

  void _checkFunction(
    FormalParameterList? params,
    FunctionBody body,
    SaropaDiagnosticReporter reporter,
  ) {
    if (params == null) return;

    final Set<String> paramNames = <String>{};
    for (final FormalParameter param in params.parameters) {
      final Token? name = param.name;
      if (name != null) paramNames.add(name.lexeme);
    }

    if (paramNames.isEmpty) return;

    body.visitChildren(
      _ParameterMutationVisitor(paramNames, reporter, _code, _mutatingMethods),
    );
  }
}

/// Visitor that detects mutations of parameter objects.
///
/// Checks for: mutating method calls on collections, field assignments,
/// index assignments, and cascade mutations.
class _ParameterMutationVisitor extends RecursiveAstVisitor<void> {
  _ParameterMutationVisitor(
    this.paramNames,
    this.reporter,
    this.code,
    this.mutatingMethods,
  );

  final Set<String> paramNames;
  final SaropaDiagnosticReporter reporter;
  final LintCode code;
  final Set<String> mutatingMethods;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // Check for param.mutatingMethod() pattern (e.g., list.add())
    final Expression? target = node.target;
    if (target is SimpleIdentifier && paramNames.contains(target.name)) {
      final String methodName = node.methodName.name;
      if (mutatingMethods.contains(methodName)) {
        reporter.atNode(node, code);
      }
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    final Expression left = node.leftHandSide;

    // Check for param.field = value pattern
    if (left is PrefixedIdentifier) {
      final SimpleIdentifier prefix = left.prefix;
      if (paramNames.contains(prefix.name)) {
        reporter.atNode(node, code);
      }
    }

    // Check for param[index] = value pattern
    if (left is IndexExpression) {
      final Expression? target = left.target;
      if (target is SimpleIdentifier && paramNames.contains(target.name)) {
        reporter.atNode(node, code);
      }
    }

    super.visitAssignmentExpression(node);
  }

  @override
  void visitCascadeExpression(CascadeExpression node) {
    // Check for param..add()..remove() pattern
    final Expression target = node.target;
    if (target is SimpleIdentifier && paramNames.contains(target.name)) {
      // Check if any cascade section is a mutation
      for (final Expression section in node.cascadeSections) {
        if (section is MethodInvocation) {
          final String methodName = section.methodName.name;
          if (mutatingMethods.contains(methodName)) {
            reporter.atNode(node, code);
            return; // Report once per cascade
          }
        }
        if (section is AssignmentExpression) {
          reporter.atNode(node, code);
          return;
        }
      }
    }
    super.visitCascadeExpression(node);
  }
}

// cspell:ignore valuel
/// Warns when variable names are too similar.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Example of **bad** code:
/// ```dart
/// final value1 = 1;
/// final valuel = 2;  // Too similar to value1
/// ```
class AvoidSimilarNamesRule extends SaropaLintRule {
  const AvoidSimilarNamesRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_similar_names',
    problemMessage:
        '[avoid_similar_names] Variable name differs from another in-scope variable by only one or two characters. Near-identical names increase the risk of accidentally using the wrong variable, producing subtle bugs that pass code review because the names look correct at a glance. {v4}',
    correctionMessage:
        'Rename one or both variables to be more distinct, using descriptive names that clearly convey their different purposes (e.g. userInput vs validatedInput).',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addBlock((Block node) {
      final List<String> names = <String>[];
      final List<Token> tokens = <Token>[];

      node.visitChildren(_VariableCollector(names, tokens));

      // Check for similar names
      for (int i = 0; i < names.length; i++) {
        for (int j = i + 1; j < names.length; j++) {
          if (_areTooSimilar(names[i], names[j])) {
            reporter.atToken(tokens[j], code);
          }
        }
      }
    });
  }

  bool _areTooSimilar(String a, String b) {
    // Skip if one is much longer than the other
    if ((a.length - b.length).abs() > 2) return false;

    // Check for common confusable patterns
    // 1 and l, 0 and O
    final String normalizedA =
        a.replaceAll('1', 'l').replaceAll('0', 'O').toLowerCase();
    final String normalizedB =
        b.replaceAll('1', 'l').replaceAll('0', 'O').toLowerCase();

    if (normalizedA == normalizedB && a != b) return true;

    // Check edit distance for short names
    if (a.length <= 5 && b.length <= 5) {
      final int distance = _editDistance(a.toLowerCase(), b.toLowerCase());
      if (distance == 1) return true;
    }

    return false;
  }

  int _editDistance(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final List<List<int>> dp = List<List<int>>.generate(
      a.length + 1,
      (int i) => List<int>.generate(b.length + 1, (int j) => 0),
    );

    for (int i = 0; i <= a.length; i++) {
      dp[i][0] = i;
    }
    for (int j = 0; j <= b.length; j++) {
      dp[0][j] = j;
    }

    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        final int cost = a[i - 1] == b[j - 1] ? 0 : 1;
        dp[i][j] = <int>[
          dp[i - 1][j] + 1,
          dp[i][j - 1] + 1,
          dp[i - 1][j - 1] + cost,
        ].reduce((int a, int b) => a < b ? a : b);
      }
    }

    return dp[a.length][b.length];
  }
}

class _VariableCollector extends RecursiveAstVisitor<void> {
  _VariableCollector(this.names, this.tokens);

  final List<String> names;
  final List<Token> tokens;

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    names.add(node.name.lexeme);
    tokens.add(node.name);
    super.visitVariableDeclaration(node);
  }
}

/// Warns when nullable parameters are never passed null.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Example of **bad** code:
/// ```dart
/// void foo(String? x) { }
/// foo('a');  // Never null
/// foo('b');  // Never null
/// ```
class AvoidUnnecessaryNullableParametersRule extends SaropaLintRule {
  const AvoidUnnecessaryNullableParametersRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_unnecessary_nullable_parameters',
    problemMessage:
        '[avoid_unnecessary_nullable_parameters] Parameter declared as nullable but null is never passed at any call site. The unnecessary nullable type forces every usage within the function body to handle a null case that cannot occur, adding defensive checks and reducing code clarity. {v4}',
    correctionMessage:
        'Change the parameter type to non-nullable. If null support is needed for future callers, add it when the requirement actually arises rather than preemptively.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // This is a simplified version - full implementation would track
    // all call sites across the codebase
    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
      final FormalParameterList? params = node.functionExpression.parameters;
      if (params == null) return;

      for (final FormalParameter param in params.parameters) {
        // Check if parameter type is nullable
        TypeAnnotation? type;
        if (param is SimpleFormalParameter) {
          type = param.type;
        } else if (param is DefaultFormalParameter) {
          final FormalParameter normalParam = param.parameter;
          if (normalParam is SimpleFormalParameter) {
            type = normalParam.type;
          }
        }

        if (type == null) continue;

        // Check if nullable
        if (type.question != null) {
          // This is a simplified heuristic
          // Full implementation would analyze call sites
        }
      }
    });
  }
}

/// Warns when a function always returns null.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v6
///
/// A function that always returns null likely has the wrong return type (should
/// be `void`) or is missing meaningful implementation. This indicates dead code
/// or an incomplete implementation that should be addressed.
///
/// Note: Void functions (`void`, `Future<void>`, `FutureOr<void>`) and functions
/// with no explicit return type that only use bare `return;` statements are
/// excluded since early-exit returns are valid in those contexts.
///
/// **BAD:**
/// ```dart
/// String? getValue() {
///   if (condition) return null;
///   return null;  // Always null - should return meaningful value or be void
/// }
///
/// int? getNumber() => null;  // Expression body always returns null
/// ```
///
/// **GOOD:**
/// ```dart
/// void doSomething() {
///   if (!ready) return;  // Early exit in void function is fine
///   performAction();
/// }
///
/// String? getValue() {
///   if (condition) return cachedValue;
///   return computeValue();  // Returns meaningful values
/// }
/// ```
class FunctionAlwaysReturnsNullRule extends SaropaLintRule {
  const FunctionAlwaysReturnsNullRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'function_always_returns_null',
    problemMessage:
        '[function_always_returns_null] Function returns null on every code path, making the return type effectively void. Callers that check or use the return value are performing dead logic, and the nullable return type misleads developers into thinking the function can return meaningful data. {v6}',
    correctionMessage:
        'Change the return type to void if the function is purely side-effecting, or add meaningful return values for different code paths to make the function useful to callers.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
      _checkFunctionBody(
        node.functionExpression.body,
        node.returnType,
        node.name,
        reporter,
      );
    });

    context.registry.addMethodDeclaration((MethodDeclaration node) {
      _checkFunctionBody(node.body, node.returnType, node.name, reporter);
    });
  }

  void _checkFunctionBody(
    FunctionBody body,
    TypeAnnotation? returnType,
    Token nameToken,
    SaropaDiagnosticReporter reporter,
  ) {
    // Skip generators — they emit values via yield, not return.
    // A bare `return;` in async*/sync* ends the stream/iterable,
    // it does not "return null".
    if (body.isGenerator) return;
    if (body is BlockFunctionBody && body.star != null) return;

    // Belt-and-suspenders: also check return type for generator types.
    // Catches generators even if body.isGenerator fails to resolve
    // correctly in some analyzer versions.
    if (returnType is NamedType) {
      final String typeName = returnType.name.lexeme;
      if (typeName == 'Stream' || typeName == 'Iterable') return;
    }

    // Skip void functions - bare return statements are valid
    if (_isVoidType(returnType)) return;

    if (body is ExpressionFunctionBody) {
      if (body.expression is NullLiteral) {
        reporter.atToken(nameToken, code);
      }
      return;
    }

    if (body is BlockFunctionBody) {
      final List<ReturnStatement> returns = <ReturnStatement>[];
      body.block.visitChildren(_ReturnCollector(returns));

      if (returns.isEmpty) return;

      // Check if all returns are bare (no expression) vs explicit null
      final bool allBareReturns = returns.every(
        (ReturnStatement ret) => ret.expression == null,
      );
      final bool allNull = returns.every((ReturnStatement ret) {
        final Expression? expr = ret.expression;
        return expr == null || expr is NullLiteral;
      });

      // If no explicit return type and all returns are bare `return;`,
      // this is likely a void function with inferred type - don't flag
      if (returnType == null && allBareReturns) return;

      if (allNull && returns.isNotEmpty) {
        reporter.atToken(nameToken, code);
      }
    }
  }

  /// Returns true if [returnType] is void, `Future<void>`, or `FutureOr<void>`.
  /// These return types make bare `return;` statements valid.
  bool _isVoidType(TypeAnnotation? returnType) {
    if (returnType == null) return false;

    // Try to use the resolved DartType first (handles type aliases)
    final DartType? resolvedType = returnType.type;
    if (resolvedType != null) {
      return _isDartTypeVoid(resolvedType);
    }

    // Fall back to syntactic check if resolved type unavailable
    if (returnType is! NamedType) return false;

    final String typeName = returnType.name.lexeme;

    if (typeName == 'void') return true;

    // Check for Future<void> or FutureOr<void>
    if (typeName == 'Future' || typeName == 'FutureOr') {
      final TypeArgumentList? typeArgs = returnType.typeArguments;
      if (typeArgs == null || typeArgs.arguments.length != 1) return false;

      final TypeAnnotation arg = typeArgs.arguments.first;
      return arg is NamedType && arg.name.lexeme == 'void';
    }

    return false;
  }

  /// Returns true if [type] is void, `Future<void>`, or `FutureOr<void>`.
  bool _isDartTypeVoid(DartType type) {
    if (type is VoidType) return true;

    // Check for Future<void> or FutureOr<void>
    if (type is InterfaceType) {
      final String? name = type.element.name;
      if (name == 'Future' || name == 'FutureOr') {
        final List<DartType> typeArgs = type.typeArguments;
        if (typeArgs.length == 1 && typeArgs.first is VoidType) {
          return true;
        }
      }
    }

    return false;
  }
}

class _ReturnCollector extends RecursiveAstVisitor<void> {
  _ReturnCollector(this.returns);

  final List<ReturnStatement> returns;

  @override
  void visitReturnStatement(ReturnStatement node) {
    returns.add(node);
    super.visitReturnStatement(node);
  }

  // Don't descend into nested functions
  @override
  void visitFunctionExpression(FunctionExpression node) {
    // Skip
  }
}

/// Warns when accessing collection elements by constant index in a loop.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// Example of **bad** code:
/// ```dart
/// for (var i = 0; i < items.length; i++) {
///   print(items[0]);  // Always accessing first element
/// }
/// ```
class AvoidAccessingCollectionsByConstantIndexRule extends SaropaLintRule {
  const AvoidAccessingCollectionsByConstantIndexRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_accessing_collections_by_constant_index',
    problemMessage:
        '[avoid_accessing_collections_by_constant_index] Collection accessed by a constant index inside a loop body. This retrieves the same element on every iteration, which is wasteful and usually indicates a logic error where the loop variable was intended as the index instead. {v5}',
    correctionMessage:
        'Replace the constant index with the loop variable, or extract the element into a local variable before the loop to make the single-access intent explicit.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addForStatement((ForStatement node) {
      node.body.visitChildren(_ConstantIndexVisitor(reporter, _code));
    });

    context.registry.addWhileStatement((WhileStatement node) {
      node.body.visitChildren(_ConstantIndexVisitor(reporter, _code));
    });

    context.registry.addDoStatement((DoStatement node) {
      node.body.visitChildren(_ConstantIndexVisitor(reporter, _code));
    });
  }
}

class _ConstantIndexVisitor extends RecursiveAstVisitor<void> {
  _ConstantIndexVisitor(this.reporter, this.code);

  final SaropaDiagnosticReporter reporter;
  final LintCode code;

  @override
  void visitIndexExpression(IndexExpression node) {
    final Expression index = node.index;
    if (index is IntegerLiteral) {
      reporter.atNode(node, code);
    }
    super.visitIndexExpression(node);
  }
}

/// Warns when a class doesn't override toString().
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// Example of **bad** code:
/// ```dart
/// class User {
///   final String name;
///   User(this.name);
///   // Missing toString override
/// }
/// ```
class AvoidDefaultToStringRule extends SaropaLintRule {
  const AvoidDefaultToStringRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_default_tostring',
    problemMessage:
        '[avoid_default_tostring] Class relies on default toString() implementation which returns unhelpful output like "Instance of \'ClassName\'". During debugging, logging, or error messages, developers see meaningless object identifiers instead of the actual state values needed to diagnose issues. {v5}',
    correctionMessage:
        'Override toString() to return a string representation of the object\'s key fields and current state. Format as "ClassName(field1: value1, field2: value2)" for easy inspection during debugging.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      if (node.abstractKeyword != null) return;

      bool hasFields = false;
      bool hasToString = false;

      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration && !member.isStatic) {
          hasFields = true;
        }
        if (member is MethodDeclaration && member.name.lexeme == 'toString') {
          hasToString = true;
        }
      }

      if (hasFields && !hasToString) {
        reporter.atToken(node.name, code);
      }
    });
  }
}

/// Warns when the same constant value is defined multiple times.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v3
///
/// Example of **bad** code:
/// ```dart
/// const errorMessage = 'Error occurred';
/// const failureMessage = 'Error occurred';  // Same value
/// ```
class AvoidDuplicateConstantValuesRule extends SaropaLintRule {
  const AvoidDuplicateConstantValuesRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_duplicate_constant_values',
    problemMessage:
        '[avoid_duplicate_constant_values] Multiple constants share the same value in this scope. Duplicate constant definitions increase maintenance cost because changes must be applied to every copy, and inconsistent updates lead to subtle logic errors when the values diverge. {v3}',
    correctionMessage:
        'Consolidate duplicates into a single named constant and reference it from all usage sites to ensure changes propagate consistently.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCompilationUnit((CompilationUnit unit) {
      final Map<String, Token> seenConstants = <String, Token>{};

      for (final CompilationUnitMember declaration in unit.declarations) {
        if (declaration is TopLevelVariableDeclaration) {
          if (!declaration.variables.isConst) continue;

          for (final VariableDeclaration variable
              in declaration.variables.variables) {
            final Expression? initializer = variable.initializer;
            if (initializer is StringLiteral) {
              final String value = initializer.toSource();
              if (seenConstants.containsKey(value)) {
                reporter.atToken(variable.name, code);
              } else {
                seenConstants[value] = variable.name;
              }
            }
          }
        }
      }
    });
  }
}

/// Warns when the same initializer expression is used twice.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Example of **bad** code:
/// ```dart
/// class Foo {
///   final int a;
///   final int b;
///   Foo() : a = compute(), b = compute();  // Same initializer
/// }
/// ```
class AvoidDuplicateInitializersRule extends SaropaLintRule {
  const AvoidDuplicateInitializersRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_duplicate_initializers',
    problemMessage:
        '[avoid_duplicate_initializers] Same initialization expression appears in multiple initializer list entries. Duplicate expressions waste computation, increase the risk of inconsistent updates when one copy is changed but others are missed, and obscure the intended initialization logic. {v4}',
    correctionMessage:
        'Extract the shared expression into a local variable or factory method and reference it from each initializer to keep the logic in a single place.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addConstructorDeclaration((ConstructorDeclaration node) {
      final NodeList<ConstructorInitializer> initializers = node.initializers;
      if (initializers.length < 2) return;

      final Set<String> seenExpressions = <String>{};

      for (final ConstructorInitializer init in initializers) {
        if (init is ConstructorFieldInitializer) {
          final String exprSource = init.expression.toSource();
          if (init.expression is Literal) continue;
          if (init.expression is SimpleIdentifier) continue;

          if (seenExpressions.contains(exprSource)) {
            reporter.atNode(init, code);
          } else {
            seenExpressions.add(exprSource);
          }
        }
      }
    });
  }
}

/// Warns when an override just calls super without additional logic.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Example of **bad** code:
/// ```dart
/// @override
/// void dispose() {
///   super.dispose();  // Just calls super, no additional logic
/// }
/// ```
class AvoidUnnecessaryOverridesRule extends SaropaLintRule {
  const AvoidUnnecessaryOverridesRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_unnecessary_overrides',
    problemMessage:
        '[avoid_unnecessary_overrides] Method override only delegates to super without adding any logic. Unnecessary overrides clutter the class, obscure the inheritance chain, and add a maintenance burden because developers must inspect each override to confirm it does nothing beyond the parent implementation. {v4}',
    correctionMessage:
        'Remove the override entirely so the parent class implementation is used directly. Add the override back only when custom behavior is actually needed.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      bool hasOverride = false;
      for (final Annotation annotation in node.metadata) {
        if (annotation.name.name == 'override') {
          hasOverride = true;
          break;
        }
      }
      if (!hasOverride) return;

      final FunctionBody body = node.body;

      if (body is ExpressionFunctionBody) {
        final Expression expr = body.expression;
        if (expr is MethodInvocation) {
          final Expression? target = expr.target;
          if (target is SuperExpression &&
              expr.methodName.name == node.name.lexeme) {
            reporter.atNode(node, code);
          }
        }
      }

      if (body is BlockFunctionBody) {
        final NodeList<Statement> statements = body.block.statements;
        if (statements.length == 1) {
          final Statement stmt = statements.first;
          if (stmt is ExpressionStatement) {
            final Expression expr = stmt.expression;
            if (expr is MethodInvocation) {
              final Expression? target = expr.target;
              if (target is SuperExpression &&
                  expr.methodName.name == node.name.lexeme) {
                reporter.atNode(node, code);
              }
            }
          }
        }
      }
    });
  }
}

/// Warns when a statement has no effect.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Example of **bad** code:
/// ```dart
/// void foo() {
///   x;  // Statement has no effect
///   1 + 2;  // Result is not used
/// }
/// ```
class AvoidUnnecessaryStatementsRule extends SaropaLintRule {
  const AvoidUnnecessaryStatementsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_unnecessary_statements',
    problemMessage:
        '[avoid_unnecessary_statements] Statement produces a value or expression result that is never used and has no side effects. Dead statements clutter the code, mislead readers into thinking meaningful work is being done, and may indicate a missing assignment or function call. {v4}',
    correctionMessage:
        'Remove the statement if it is truly unused, assign the result to a variable, or call the intended method to produce the expected side effect.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addExpressionStatement((ExpressionStatement node) {
      final Expression expr = node.expression;

      if (expr is MethodInvocation) return;
      if (expr is FunctionExpressionInvocation) return;
      if (expr is AssignmentExpression) return;
      if (expr is PostfixExpression) return;
      if (expr is PrefixExpression) {
        final TokenType op = expr.operator.type;
        if (op == TokenType.PLUS_PLUS || op == TokenType.MINUS_MINUS) return;
      }
      if (expr is AwaitExpression) return;
      if (expr is ThrowExpression) return;
      if (expr is CascadeExpression) return;

      if (expr is SimpleIdentifier ||
          expr is Literal ||
          expr is BinaryExpression ||
          expr is PropertyAccess ||
          expr is PrefixedIdentifier) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when an assignment is never used.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v3
///
/// Example of **bad** code:
/// ```dart
/// void foo() {
///   var x = 1;
///   x = 2;  // x is never read after this
/// }
/// ```
class AvoidUnusedAssignmentRule extends SaropaLintRule {
  const AvoidUnusedAssignmentRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_unused_assignment',
    problemMessage:
        '[avoid_unused_assignment] Variable is assigned a value that is never read before being overwritten or going out of scope. The assignment wastes computation, and the unused result often signals a logic error where the value was meant to be used in a subsequent expression or return statement. {v3}',
    correctionMessage:
        'Remove the assignment if the value is not needed, or use the variable in the intended expression. Check for missing return statements or conditional branches.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addBlock((Block node) {
      final Map<String, List<AstNode>> assignments = <String, List<AstNode>>{};
      final Set<String> usedVariables = <String>{};

      node.visitChildren(_AssignmentUsageVisitor(assignments, usedVariables));

      for (final MapEntry<String, List<AstNode>> entry in assignments.entries) {
        if (entry.value.length > 1) {
          for (int i = 0; i < entry.value.length - 1; i++) {
            reporter.atNode(entry.value[i], code);
          }
        }
      }
    });
  }
}

class _AssignmentUsageVisitor extends RecursiveAstVisitor<void> {
  _AssignmentUsageVisitor(this.assignments, this.usedVariables);

  final Map<String, List<AstNode>> assignments;
  final Set<String> usedVariables;

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    final Expression left = node.leftHandSide;
    if (left is SimpleIdentifier) {
      assignments.putIfAbsent(left.name, () => <AstNode>[]);
      assignments[left.name]!.add(node);
    }
    super.visitAssignmentExpression(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    final AstNode? parent = node.parent;
    if (parent is AssignmentExpression && parent.leftHandSide == node) {
      return;
    }
    usedVariables.add(node.name);
    super.visitSimpleIdentifier(node);
  }
}

/// Warns when an instance is created but never used.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// Skips known fire-and-forget constructors (e.g. `Future.delayed`,
/// `Timer`, `Timer.periodic`) whose side effects are the intended use.
///
/// Example of **bad** code:
/// ```dart
/// void foo() {
///   MyClass();  // Instance created but not used
/// }
/// ```
///
/// Example of **good** code (not flagged):
/// ```dart
/// void foo() {
///   Future.delayed(Duration(seconds: 1), () => print('done'));
///   Timer(Duration(seconds: 1), () => print('done'));
/// }
/// ```
class AvoidUnusedInstancesRule extends SaropaLintRule {
  const AvoidUnusedInstancesRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  /// Types whose constructors are intentionally used for side effects
  /// without needing to capture the returned instance.
  static const Set<String> _fireAndForgetTypes = <String>{
    'Future',
    'Timer',
  };

  static const LintCode _code = LintCode(
    name: 'avoid_unused_instances',
    problemMessage:
        '[avoid_unused_instances] Object instance created but never assigned to a variable or used in an expression. The constructor runs its side effects (if any) but the resulting object is immediately garbage-collected, wasting memory allocation and usually indicating a missing assignment. {v5}',
    correctionMessage:
        'Assign the instance to a variable for later use, pass it directly as an argument, or remove the creation entirely if the side effects are not needed.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addExpressionStatement((ExpressionStatement node) {
      final Expression expr = node.expression;
      if (expr is! InstanceCreationExpression) return;

      final String typeName = expr.constructorName.type.name2.lexeme;
      if (_fireAndForgetTypes.contains(typeName)) return;

      reporter.atNode(node, code);
    });
  }
}

/// Warns when a variable is null-checked but not used afterward.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v3
///
/// Example of **bad** code:
/// ```dart
/// if (x != null) {
///   print('exists');  // x is not used
/// }
/// ```
class AvoidUnusedAfterNullCheckRule extends SaropaLintRule {
  const AvoidUnusedAfterNullCheckRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_unused_after_null_check',
    problemMessage:
        '[avoid_unused_after_null_check] Variable is null-checked in a condition but never referenced inside the guarded block. The null check implies the variable is needed, so the missing reference likely indicates a logic error where the intended usage was accidentally omitted. {v3}',
    correctionMessage:
        'Reference the variable inside the guarded block where the null check applies, or remove the null check entirely if the variable is genuinely not needed.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addIfStatement((IfStatement node) {
      final Expression condition = node.expression;

      String? checkedVariable;
      if (condition is BinaryExpression) {
        if (condition.operator.type == TokenType.BANG_EQ) {
          if (condition.rightOperand is NullLiteral &&
              condition.leftOperand is SimpleIdentifier) {
            checkedVariable = (condition.leftOperand as SimpleIdentifier).name;
          }
          if (condition.leftOperand is NullLiteral &&
              condition.rightOperand is SimpleIdentifier) {
            checkedVariable = (condition.rightOperand as SimpleIdentifier).name;
          }
        }
      }

      if (checkedVariable == null) return;

      final bool isUsed =
          _containsIdentifier(node.thenStatement, checkedVariable);
      if (!isUsed) {
        reporter.atNode(condition, code);
      }
    });
  }

  bool _containsIdentifier(AstNode node, String name) {
    bool found = false;
    node.visitChildren(_IdentifierFinder(name, () => found = true));
    return found;
  }
}

class _IdentifierFinder extends RecursiveAstVisitor<void> {
  _IdentifierFinder(this.name, this.onFound);

  final String name;
  final void Function() onFound;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.name == name) onFound();
    super.visitSimpleIdentifier(node);
  }
}

/// Warns when using default/wildcard case with enums.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// Example of **bad** code:
/// ```dart
/// switch (status) {
///   case Status.active: ...
///   default: ...  // May hide unhandled enum values
/// }
/// ```
class AvoidWildcardCasesWithEnumsRule extends SaropaLintRule {
  const AvoidWildcardCasesWithEnumsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.high;

  static const LintCode _code = LintCode(
    name: 'avoid_wildcard_cases_with_enums',
    problemMessage:
        '[avoid_wildcard_cases_with_enums] Switch on an enum uses a default or wildcard case, suppressing exhaustiveness checking. When new enum values are added, the compiler will not flag this switch as incomplete, allowing the new case to silently fall into the default branch instead of being explicitly handled. {v5}',
    correctionMessage:
        'Remove the default/wildcard case and add explicit case clauses for every enum value so the compiler reports an error when new values are introduced.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSwitchStatement((SwitchStatement node) {
      final Expression expression = node.expression;
      final DartType? type = expression.staticType;
      if (type == null) return;

      final String typeName = type.getDisplayString();
      if (!_looksLikeEnumType(typeName)) return;

      for (final SwitchMember member in node.members) {
        if (member is SwitchDefault) {
          reporter.atNode(member, code);
        }
      }
    });
  }

  bool _looksLikeEnumType(String typeName) {
    if (typeName.isEmpty) return false;
    final String clean = typeName.replaceAll('?', '');
    if (clean == 'int' ||
        clean == 'String' ||
        clean == 'bool' ||
        clean == 'double' ||
        clean == 'Object' ||
        clean == 'dynamic') {
      return false;
    }
    return clean[0] == clean[0].toUpperCase() && !clean.contains('<');
  }
}

/// Warns when a function always returns the same value.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// Example of **bad** code:
/// ```dart
/// int getValue(bool condition) {
///   if (condition) return 42;
///   return 42;  // Always returns 42
/// }
/// ```
class FunctionAlwaysReturnsSameValueRule extends SaropaLintRule {
  const FunctionAlwaysReturnsSameValueRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'function_always_returns_same_value',
    problemMessage:
        '[function_always_returns_same_value] Function returns the same value on every code path regardless of input. The function body adds complexity without varying the output, suggesting the logic branches are incomplete or the function can be replaced by a constant. {v5}',
    correctionMessage:
        'Replace the function with a constant or static field if the value is truly fixed, or add the missing branches that return different values based on input.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
      _checkFunctionBody(node.functionExpression.body, node.name, reporter);
    });

    context.registry.addMethodDeclaration((MethodDeclaration node) {
      _checkFunctionBody(node.body, node.name, reporter);
    });
  }

  void _checkFunctionBody(
      FunctionBody body, Token nameToken, SaropaDiagnosticReporter reporter) {
    if (body is! BlockFunctionBody) return;

    final List<ReturnStatement> returns = <ReturnStatement>[];
    body.block.visitChildren(_ReturnCollector(returns));

    if (returns.length < 2) return;

    String? firstValue;
    bool allSame = true;

    for (final ReturnStatement ret in returns) {
      final Expression? expr = ret.expression;
      if (expr == null) {
        allSame = false;
        break;
      }

      final String value = expr.toSource();
      firstValue ??= value;

      if (value != firstValue) {
        allSame = false;
        break;
      }
    }

    if (allSame && firstValue != null) {
      reporter.atToken(nameToken, code);
    }
  }
}

/// Warns when the same condition appears in nested if statements.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Example of **bad** code:
/// ```dart
/// if (x > 0) {
///   if (x > 0) {  // Same condition
///     ...
///   }
/// }
/// ```
class NoEqualNestedConditionsRule extends SaropaLintRule {
  const NoEqualNestedConditionsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'no_equal_nested_conditions',
    problemMessage:
        '[no_equal_nested_conditions] Inner condition is identical to an enclosing outer condition. The nested check is always true at that point because the outer condition already guarantees it, making the inner branch redundant dead logic that adds nesting depth without any behavioral effect. {v4}',
    correctionMessage:
        'Remove the redundant nested condition and keep only the code inside it, since the outer condition already provides the same guarantee.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addIfStatement((IfStatement node) {
      final String outerCondition = node.expression.toSource();
      node.thenStatement.visitChildren(
          _NestedConditionChecker(outerCondition, reporter, _code));
    });
  }
}

class _NestedConditionChecker extends RecursiveAstVisitor<void> {
  _NestedConditionChecker(this.outerCondition, this.reporter, this.code);

  final String outerCondition;
  final SaropaDiagnosticReporter reporter;
  final LintCode code;

  @override
  void visitIfStatement(IfStatement node) {
    final String innerCondition = node.expression.toSource();
    if (innerCondition == outerCondition) {
      reporter.atNode(node.expression, code);
    }
    super.visitIfStatement(node);
  }
}

/// Warns when switch cases have identical bodies.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Example of **bad** code:
/// ```dart
/// switch (x) {
///   case 1: return 'a';
///   case 2: return 'a';  // Same as case 1
/// }
/// ```
class NoEqualSwitchCaseRule extends SaropaLintRule {
  const NoEqualSwitchCaseRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'no_equal_switch_case',
    problemMessage:
        '[no_equal_switch_case] Multiple switch cases contain identical body code. Duplicated case logic increases maintenance cost because changes must be applied to every copy, and missed updates cause inconsistent behavior across cases that are meant to be equivalent. {v4}',
    correctionMessage:
        'Combine the cases using comma-separated patterns (case a, b:) or extract the shared logic into a helper method referenced by each case.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSwitchStatement((SwitchStatement node) {
      final List<String> caseBodies = <String>[];
      final List<SwitchMember> members = <SwitchMember>[];

      for (final SwitchMember member in node.members) {
        if (member is SwitchCase && member.statements.isNotEmpty) {
          final String body =
              member.statements.map((Statement s) => s.toSource()).join();
          caseBodies.add(body);
          members.add(member);
        }
      }

      final Set<String> seen = <String>{};
      for (int i = 0; i < caseBodies.length; i++) {
        if (seen.contains(caseBodies[i])) {
          reporter.atNode(members[i], code);
        }
        seen.add(caseBodies[i]);
      }
    });
  }
}

/// Warns when isEmpty/isNotEmpty is used after where().
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// Example of **bad** code:
/// ```dart
/// list.where((e) => e > 5).isEmpty;
/// ```
///
/// Example of **good** code:
/// ```dart
/// !list.any((e) => e > 5);
/// ```
class PreferAnyOrEveryRule extends SaropaLintRule {
  const PreferAnyOrEveryRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_any_or_every',
    problemMessage:
        '[prefer_any_or_every] Collection filtered with where() only to check isEmpty/isNotEmpty. The where() call creates an intermediate lazy iterable and allocates a closure, while any() and every() short-circuit on the first matching element without creating intermediate objects. {v5}',
    correctionMessage:
        'Replace where(predicate).isEmpty with !any(predicate), and where(predicate).isNotEmpty with any(predicate) for clearer intent and better performance.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addPropertyAccess((PropertyAccess node) {
      final String propertyName = node.propertyName.name;
      if (propertyName != 'isEmpty' && propertyName != 'isNotEmpty') return;

      final Expression? target = node.target;
      if (target is MethodInvocation && target.methodName.name == 'where') {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when index-based for loop can be replaced with for-in.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// **Stylistic rule (opt-in only).** No performance or correctness benefit.
///
/// Example of **bad** code:
/// ```dart
/// for (var i = 0; i < list.length; i++) {
///   print(list[i]);
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// for (final item in list) {
///   print(item);
/// }
/// ```
class PreferForInRule extends SaropaLintRule {
  const PreferForInRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_for_in',
    problemMessage:
        '[prefer_for_in] Using for-in loops instead of index-based for loops is a stylistic preference. Both have equivalent performance for most Dart collections. Enable via the stylistic tier. {v4}',
    correctionMessage:
        'Replace the index-based loop with a for-in loop (for (final item in list)) to iterate directly over elements without managing an index variable.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addForStatement((ForStatement node) {
      final ForLoopParts parts = node.forLoopParts;
      if (parts is! ForPartsWithDeclarations) return;

      final NodeList<VariableDeclaration> variables = parts.variables.variables;
      if (variables.length != 1) return;

      final VariableDeclaration indexVar = variables.first;
      final Expression? initializer = indexVar.initializer;
      if (initializer is! IntegerLiteral || initializer.value != 0) return;

      final String indexName = indexVar.name.lexeme;

      final Expression? condition = parts.condition;
      if (condition is! BinaryExpression) return;
      if (condition.operator.type != TokenType.LT) return;

      final NodeList<Expression> updaters = parts.updaters;
      if (updaters.length != 1) return;

      final Expression updater = updaters.first;
      bool isSimpleIncrement = false;
      if (updater is PostfixExpression &&
          updater.operand is SimpleIdentifier &&
          (updater.operand as SimpleIdentifier).name == indexName) {
        isSimpleIncrement = true;
      }
      if (updater is PrefixExpression &&
          updater.operand is SimpleIdentifier &&
          (updater.operand as SimpleIdentifier).name == indexName) {
        isSimpleIncrement = true;
      }

      if (isSimpleIncrement) {
        reporter.atToken(node.forKeyword, code);
      }
    });
  }
}

/// Warns when duplicate patterns appear in pattern matching.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Example of **bad** code:
/// ```dart
/// switch (value) {
///   case (int x, int y) when x > 0:
///   case (int x, int y) when x > 0:  // Duplicate pattern
/// }
/// ```
class AvoidDuplicatePatternsRule extends SaropaLintRule {
  const AvoidDuplicatePatternsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_duplicate_patterns',
    problemMessage:
        '[avoid_duplicate_patterns] Same pattern appears multiple times in a switch or if-case chain. Duplicate patterns mean the second occurrence is unreachable dead code because the first match always wins, indicating a copy-paste error or incomplete refactoring. {v4}',
    correctionMessage:
        'Remove the duplicate pattern clause, or if different handling is intended, adjust the pattern to be distinct so both branches are reachable.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSwitchExpression((SwitchExpression node) {
      final Set<String> seenPatterns = <String>{};
      for (final SwitchExpressionCase caseClause in node.cases) {
        final String patternSource = caseClause.guardedPattern.toSource();
        if (seenPatterns.contains(patternSource)) {
          reporter.atNode(caseClause.guardedPattern, code);
        } else {
          seenPatterns.add(patternSource);
        }
      }
    });

    context.registry.addSwitchStatement((SwitchStatement node) {
      final Set<String> seenPatterns = <String>{};
      for (final SwitchMember member in node.members) {
        if (member is SwitchPatternCase) {
          final String patternSource = member.guardedPattern.toSource();
          if (seenPatterns.contains(patternSource)) {
            reporter.atNode(member.guardedPattern, code);
          } else {
            seenPatterns.add(patternSource);
          }
        }
      }
    });
  }
}

/// Warns when an extension type contains another extension type.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v3
///
/// Example of **bad** code:
/// ```dart
/// extension type Inner(int value) {}
/// extension type Outer(Inner inner) {}  // Nested extension type
/// ```
class AvoidNestedExtensionTypesRule extends SaropaLintRule {
  const AvoidNestedExtensionTypesRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_nested_extension_types',
    problemMessage:
        '[avoid_nested_extension_types] Extension type wraps another extension type, creating multiple layers of zero-cost abstraction. Each layer adds indirection to the representation type, making the code harder to reason about and increasing the chance of applying the wrong extension methods to the underlying value. {v3}',
    correctionMessage:
        'Use the underlying representation type directly in the outer extension type to flatten the abstraction and reduce confusion about which methods are available.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addExtensionTypeDeclaration((ExtensionTypeDeclaration node) {
      final RepresentationDeclaration representation = node.representation;

      final DartType? fieldType = representation.fieldType.type;
      if (fieldType == null) return;

      // Check if the field type is itself an extension type
      if (fieldType.element is ExtensionTypeElement) {
        reporter.atNode(representation.fieldType, code);
      }
    });
  }
}

/// Warns when slow collection methods are used.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// Methods like `sync*` generators for simple collections can be slow.
///
/// Example of **bad** code:
/// ```dart
/// Iterable<int> getItems() sync* {
///   yield 1;
///   yield 2;
/// }
/// ```
class AvoidSlowCollectionMethodsRule extends SaropaLintRule {
  const AvoidSlowCollectionMethodsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_slow_collection_methods',
    problemMessage:
        '[avoid_slow_collection_methods] sync* generator used for a simple collection that yields a small, fixed number of elements. Generator functions have overhead from creating state machines and lazy iterables that exceeds the cost of building a plain list for small collections. {v5}',
    correctionMessage:
        'Return a List literal directly (e.g. [a, b, c]) for small fixed collections. Reserve sync* generators for large or computed sequences where lazy evaluation provides a real benefit.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
      _checkForSyncStar(node.functionExpression.body, node.name, reporter);
    });

    context.registry.addMethodDeclaration((MethodDeclaration node) {
      _checkForSyncStar(node.body, node.name, reporter);
    });
  }

  void _checkForSyncStar(
      FunctionBody body, Token nameToken, SaropaDiagnosticReporter reporter) {
    if (body.keyword?.lexeme != 'sync') return;
    if (body.star == null) return;

    // Count yield statements
    int yieldCount = 0;
    body.visitChildren(_YieldCounter((int count) => yieldCount = count));

    // Warn if only a few yields (could be a simple list)
    if (yieldCount > 0 && yieldCount <= 5) {
      reporter.atToken(nameToken, code);
    }
  }
}

class _YieldCounter extends RecursiveAstVisitor<void> {
  _YieldCounter(this.onCount);

  final void Function(int) onCount;
  int _count = 0;

  @override
  void visitYieldStatement(YieldStatement node) {
    _count++;
    onCount(_count);
    super.visitYieldStatement(node);
  }
}

/// Warns when a class field is never assigned a value.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Example of **bad** code:
/// ```dart
/// class Foo {
///   String? name;  // Never assigned
///   void bar() {
///     print(name);  // Always null
///   }
/// }
/// ```
class AvoidUnassignedFieldsRule extends SaropaLintRule {
  const AvoidUnassignedFieldsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_unassigned_fields',
    problemMessage:
        '[avoid_unassigned_fields] Field declared without an initializer and no constructor or method assigns it a value. Reading this field returns the default value (null for nullable types), which may cause unexpected NullPointerExceptions or logic errors if the caller expects a meaningful value. {v4}',
    correctionMessage:
        'Add an initializer at the declaration site, assign the field in the constructor, or mark it as late if initialization is deferred to a lifecycle method.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final Set<String> assignedFields = <String>{};
      final Map<String, Token> nullableFields = <String, Token>{};

      // Collect nullable fields without initializers
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          for (final VariableDeclaration variable in member.fields.variables) {
            final DartType? type = variable.declaredElement?.type;
            if (type != null &&
                type.nullabilitySuffix == NullabilitySuffix.question) {
              if (variable.initializer == null) {
                nullableFields[variable.name.lexeme] = variable.name;
              }
            }
          }
        }
      }

      // Check constructors for assignments
      for (final ClassMember member in node.members) {
        if (member is ConstructorDeclaration) {
          for (final ConstructorInitializer init in member.initializers) {
            if (init is ConstructorFieldInitializer) {
              assignedFields.add(init.fieldName.name);
            }
          }
          for (final FormalParameter param in member.parameters.parameters) {
            if (param is FieldFormalParameter) {
              assignedFields.add(param.name.lexeme);
            }
          }
        }
      }

      // Check method bodies for assignments
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration) {
          member.body.visitChildren(_FieldAssignmentVisitor(assignedFields));
        }
        if (member is ConstructorDeclaration &&
            member.body is BlockFunctionBody) {
          member.body.visitChildren(_FieldAssignmentVisitor(assignedFields));
        }
      }

      // Report unassigned fields
      for (final MapEntry<String, Token> entry in nullableFields.entries) {
        if (!assignedFields.contains(entry.key)) {
          reporter.atToken(entry.value, code);
        }
      }
    });
  }
}

class _FieldAssignmentVisitor extends RecursiveAstVisitor<void> {
  _FieldAssignmentVisitor(this.assignedFields);

  final Set<String> assignedFields;

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    final Expression left = node.leftHandSide;
    if (left is SimpleIdentifier) {
      assignedFields.add(left.name);
    }
    if (left is PrefixedIdentifier && left.prefix.name == 'this') {
      assignedFields.add(left.identifier.name);
    }
    if (left is PropertyAccess) {
      final Expression? target = left.target;
      if (target is ThisExpression) {
        assignedFields.add(left.propertyName.name);
      }
    }
    super.visitAssignmentExpression(node);
  }
}

/// Warns when a late field is never assigned a value.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Example of **bad** code:
/// ```dart
/// class Foo {
///   late String name;  // Never assigned - will throw at runtime
/// }
/// ```
class AvoidUnassignedLateFieldsRule extends SaropaLintRule {
  const AvoidUnassignedLateFieldsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_unassigned_late_fields',
    problemMessage:
        '[avoid_unassigned_late_fields] Late field has no assignment in any constructor, initializer, or lifecycle method. Accessing an unassigned late field throws a LateInitializationError at runtime, crashing the app at a point that the compiler cannot check statically. {v4}',
    correctionMessage:
        'Assign the field in the constructor, an initializer list, or a lifecycle method such as initState(). If initialization is conditional, use a nullable type instead of late.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final Set<String> assignedFields = <String>{};
      final Map<String, Token> lateFields = <String, Token>{};

      // Collect late fields without initializers
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration && member.fields.isLate) {
          for (final VariableDeclaration variable in member.fields.variables) {
            if (variable.initializer == null) {
              lateFields[variable.name.lexeme] = variable.name;
            }
          }
        }
      }

      if (lateFields.isEmpty) return;

      // Check constructors and methods for assignments
      for (final ClassMember member in node.members) {
        if (member is ConstructorDeclaration) {
          for (final ConstructorInitializer init in member.initializers) {
            if (init is ConstructorFieldInitializer) {
              assignedFields.add(init.fieldName.name);
            }
          }
          member.body.visitChildren(_FieldAssignmentVisitor(assignedFields));
        }
        if (member is MethodDeclaration) {
          member.body.visitChildren(_FieldAssignmentVisitor(assignedFields));
        }
      }

      // Report unassigned late fields
      for (final MapEntry<String, Token> entry in lateFields.entries) {
        if (!assignedFields.contains(entry.key)) {
          reporter.atToken(entry.value, code);
        }
      }
    });
  }
}

/// Warns when late is used but field is assigned in constructor.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// Example of **bad** code:
/// ```dart
/// class Foo {
///   late final String name;
///   Foo(this.name);  // late is unnecessary
/// }
/// ```
class AvoidUnnecessaryLateFieldsRule extends SaropaLintRule {
  const AvoidUnnecessaryLateFieldsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_unnecessary_late_fields',
    problemMessage:
        '[avoid_unnecessary_late_fields] Field marked as late but already assigned in the constructor or initializer list. The late keyword is redundant here and misleads readers into thinking initialization is deferred, while also disabling the compile-time guarantee that the field is always initialized. {v5}',
    correctionMessage:
        'Remove the late keyword since the field is already assigned during construction. This restores compile-time initialization checking and clarifies the intent.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final Map<String, FieldDeclaration> lateFields =
          <String, FieldDeclaration>{};

      // Collect late fields
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration && member.fields.isLate) {
          for (final VariableDeclaration variable in member.fields.variables) {
            lateFields[variable.name.lexeme] = member;
          }
        }
      }

      if (lateFields.isEmpty) return;

      // Check all constructors
      bool allConstructorsAssign(String fieldName) {
        int constructorCount = 0;
        int assignmentCount = 0;

        for (final ClassMember member in node.members) {
          if (member is ConstructorDeclaration) {
            constructorCount++;
            bool assigned = false;

            // Check field formal parameters
            for (final FormalParameter param in member.parameters.parameters) {
              if (param is FieldFormalParameter &&
                  param.name.lexeme == fieldName) {
                assigned = true;
                break;
              }
            }

            // Check initializers
            if (!assigned) {
              for (final ConstructorInitializer init in member.initializers) {
                if (init is ConstructorFieldInitializer &&
                    init.fieldName.name == fieldName) {
                  assigned = true;
                  break;
                }
              }
            }

            if (assigned) assignmentCount++;
          }
        }

        return constructorCount > 0 && constructorCount == assignmentCount;
      }

      // Report unnecessary late fields
      for (final MapEntry<String, FieldDeclaration> entry
          in lateFields.entries) {
        if (allConstructorsAssign(entry.key)) {
          reporter.atNode(entry.value, code);
        }
      }
    });
  }
}

/// Warns when a nullable field is always non-null.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Example of **bad** code:
/// ```dart
/// class Foo {
///   String? name;  // Always assigned non-null value
///   Foo(String n) : name = n;
/// }
/// ```
class AvoidUnnecessaryNullableFieldsRule extends SaropaLintRule {
  const AvoidUnnecessaryNullableFieldsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_unnecessary_nullable_fields',
    problemMessage:
        '[avoid_unnecessary_nullable_fields] Nullable field is always assigned a non-null value across all constructors and assignment sites. The unnecessary nullable type forces every read site to handle null even though it can never occur, adding redundant null checks and obscuring the actual data flow. {v4}',
    correctionMessage:
        'Change the field type to non-nullable and remove the ? suffix. Add null checks only if a future code path genuinely needs to store null.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final Map<String, Token> nullableFields = <String, Token>{};
      final Set<String> assignedNullFields = <String>{};
      final Set<String> constructorInitializedFields = <String>{};

      // Collect nullable fields
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          for (final VariableDeclaration variable in member.fields.variables) {
            final DartType? type = variable.declaredElement?.type;
            if (type != null &&
                type.nullabilitySuffix == NullabilitySuffix.question) {
              // Skip if has initializer that's null
              final Expression? init = variable.initializer;
              if (init == null) {
                nullableFields[variable.name.lexeme] = variable.name;
              } else if (init is! NullLiteral) {
                nullableFields[variable.name.lexeme] = variable.name;
              }
            }
          }
        }
      }

      if (nullableFields.isEmpty) return;

      // Check constructors
      for (final ClassMember member in node.members) {
        if (member is ConstructorDeclaration) {
          for (final FormalParameter param in member.parameters.parameters) {
            if (param is FieldFormalParameter) {
              constructorInitializedFields.add(param.name.lexeme);
            }
          }
          for (final ConstructorInitializer init in member.initializers) {
            if (init is ConstructorFieldInitializer) {
              constructorInitializedFields.add(init.fieldName.name);
              if (init.expression is NullLiteral) {
                assignedNullFields.add(init.fieldName.name);
              }
            }
          }
        }
      }

      // Check methods for null assignments
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration) {
          member.body.visitChildren(_NullAssignmentChecker(assignedNullFields));
        }
      }

      // Report fields that are always non-null
      for (final MapEntry<String, Token> entry in nullableFields.entries) {
        if (constructorInitializedFields.contains(entry.key) &&
            !assignedNullFields.contains(entry.key)) {
          reporter.atToken(entry.value, code);
        }
      }
    });
  }
}

class _NullAssignmentChecker extends RecursiveAstVisitor<void> {
  _NullAssignmentChecker(this.assignedNullFields);

  final Set<String> assignedNullFields;

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    if (node.rightHandSide is NullLiteral) {
      final Expression left = node.leftHandSide;
      if (left is SimpleIdentifier) {
        assignedNullFields.add(left.name);
      }
      if (left is PrefixedIdentifier && left.prefix.name == 'this') {
        assignedNullFields.add(left.identifier.name);
      }
    }
    super.visitAssignmentExpression(node);
  }
}

/// Warns when a pattern doesn't affect type narrowing.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// Example of **bad** code:
/// ```dart
/// void foo(int x) {
///   if (x case int y) {  // Pattern doesn't narrow type
///     print(y);
///   }
/// }
/// ```
class AvoidUnnecessaryPatternsRule extends SaropaLintRule {
  const AvoidUnnecessaryPatternsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.high;

  static const LintCode _code = LintCode(
    name: 'avoid_unnecessary_patterns',
    problemMessage:
        '[avoid_unnecessary_patterns] Pattern matching syntax used where it does not narrow types or destructure values. The pattern adds syntactic complexity without any type-safety benefit, making the code harder to read compared to a plain variable declaration or assignment. {v5}',
    correctionMessage:
        'Replace the pattern with a simple variable declaration or assignment. Use pattern matching only when it provides destructuring or type narrowing.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addIfStatement((IfStatement node) {
      final CaseClause? caseClause = node.caseClause;
      if (caseClause == null) return;

      final GuardedPattern guardedPattern = caseClause.guardedPattern;
      final DartPattern pattern = guardedPattern.pattern;

      // Check if pattern is just a type test on the same type
      if (pattern is DeclaredVariablePattern) {
        final DartType? patternType = pattern.type?.type;
        final DartType? expressionType = node.expression.staticType;

        if (patternType != null && expressionType != null) {
          if (patternType.getDisplayString() ==
              expressionType.getDisplayString()) {
            reporter.atNode(pattern, code);
          }
        }
      }
    });
  }
}

/// Warns when using default/wildcard case with sealed classes.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Example of **bad** code:
/// ```dart
/// sealed class Shape {}
/// switch (shape) {
///   case Circle(): ...
///   default: ...  // May hide unhandled subclasses
/// }
/// ```
class AvoidWildcardCasesWithSealedClassesRule extends SaropaLintRule {
  const AvoidWildcardCasesWithSealedClassesRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_wildcard_cases_with_sealed_classes',
    problemMessage:
        '[avoid_wildcard_cases_with_sealed_classes] Switch on a sealed class uses a default or wildcard case, suppressing exhaustiveness checking. When new subtypes are added to the sealed hierarchy, the compiler will not flag this switch as incomplete, allowing unhandled subtypes to silently fall through. {v4}',
    correctionMessage:
        'Remove the default/wildcard case and add explicit case clauses for every sealed subtype so the compiler reports an error when new subtypes are introduced.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSwitchStatement((SwitchStatement node) {
      final DartType? type = node.expression.staticType;
      if (type == null) return;

      final Element? element = type.element;
      if (element is! ClassElement) return;
      if (!element.isSealed) return;

      for (final SwitchMember member in node.members) {
        if (member is SwitchDefault) {
          reporter.atNode(member, code);
        }
      }
    });

    context.registry.addSwitchExpression((SwitchExpression node) {
      final DartType? type = node.expression.staticType;
      if (type == null) return;

      final Element? element = type.element;
      if (element is! ClassElement) return;
      if (!element.isSealed) return;

      for (final SwitchExpressionCase caseClause in node.cases) {
        final DartPattern pattern = caseClause.guardedPattern.pattern;
        if (pattern is WildcardPattern) {
          reporter.atNode(pattern, code);
        }
      }
    });
  }
}

/// Warns when switch expression cases have identical expressions.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Example of **bad** code:
/// ```dart
/// final result = switch (x) {
///   1 => 'one',
///   2 => 'one',  // Same as case 1
///   _ => 'other',
/// };
/// ```
class NoEqualSwitchExpressionCasesRule extends SaropaLintRule {
  const NoEqualSwitchExpressionCasesRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'no_equal_switch_expression_cases',
    problemMessage:
        '[no_equal_switch_expression_cases] Multiple switch expression cases produce identical result values. Duplicate results increase maintenance cost because changes must be applied to every copy, and they obscure whether the cases were truly intended to behave the same. {v4}',
    correctionMessage:
        'Combine the cases using comma-separated patterns (case a, b => result) or extract the shared value into a named constant.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSwitchExpression((SwitchExpression node) {
      final Map<String, SwitchExpressionCase> seenExpressions =
          <String, SwitchExpressionCase>{};

      for (final SwitchExpressionCase caseClause in node.cases) {
        final String exprSource = caseClause.expression.toSource();

        if (seenExpressions.containsKey(exprSource)) {
          reporter.atNode(caseClause.expression, code);
        } else {
          seenExpressions[exprSource] = caseClause;
        }
      }
    });
  }
}

/// Warns when a BytesBuilder should be used for byte operations.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// Example of **bad** code:
/// ```dart
/// final bytes = <int>[];
/// bytes.addAll([1, 2, 3]);
/// bytes.addAll([4, 5, 6]);
/// ```
class PreferBytesBuilderRule extends SaropaLintRule {
  const PreferBytesBuilderRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.high;

  static const LintCode _code = LintCode(
    name: 'prefer_bytes_builder',
    problemMessage:
        '[prefer_bytes_builder] List<int> with repeated addAll operations detected. Each addAll call may trigger memory reallocation and copying, causing O(n²) performance when building large byte arrays, resulting in slow processing and excessive memory churn. {v5}',
    correctionMessage:
        'Replace with BytesBuilder which preallocates memory efficiently and avoids repeated copying. Use BytesBuilder.add() or addByte() to accumulate bytes, then call toBytes() once at the end for O(n) performance.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'addAll') return;

      final Expression? target = node.target;
      if (target == null) return;

      final DartType? targetType = target.staticType;
      if (targetType == null) return;

      final String typeName = targetType.getDisplayString();
      if (typeName == 'List<int>' || typeName == 'Uint8List') {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when a ternary expression can be pushed into arguments.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// **Stylistic rule (opt-in only).** No performance or correctness benefit.
///
/// Example of **bad** code:
/// ```dart
/// condition ? foo(1, 2) : foo(1, 3);
/// ```
///
/// Example of **good** code:
/// ```dart
/// foo(1, condition ? 2 : 3);
/// ```
class PreferPushingConditionalExpressionsRule extends SaropaLintRule {
  const PreferPushingConditionalExpressionsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_pushing_conditional_expressions',
    problemMessage:
        '[prefer_pushing_conditional_expressions] Moving conditional logic into return expressions is a code shape preference. No performance or correctness difference between forms. Enable via the stylistic tier. {v4}',
    correctionMessage:
        'Move the conditional expression inside the single differing argument so the constructor or function call appears once with all shared arguments visible.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addConditionalExpression((ConditionalExpression node) {
      final Expression thenExpr = node.thenExpression;
      final Expression elseExpr = node.elseExpression;

      // Check if both branches are method calls to the same method
      if (thenExpr is MethodInvocation && elseExpr is MethodInvocation) {
        if (thenExpr.methodName.name == elseExpr.methodName.name) {
          final String? thenTarget = thenExpr.target?.toSource();
          final String? elseTarget = elseExpr.target?.toSource();

          if (thenTarget == elseTarget) {
            // Check if only one argument differs
            final List<Expression> thenArgs =
                thenExpr.argumentList.arguments.toList();
            final List<Expression> elseArgs =
                elseExpr.argumentList.arguments.toList();

            if (thenArgs.length == elseArgs.length && thenArgs.length >= 2) {
              int diffCount = 0;
              for (int i = 0; i < thenArgs.length; i++) {
                if (thenArgs[i].toSource() != elseArgs[i].toSource()) {
                  diffCount++;
                }
              }
              if (diffCount == 1) {
                reporter.atNode(node, code);
              }
            }
          }
        }
      }
    });
  }
}

/// Warns when `.new` constructor shorthand can be used.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Example of **bad** code:
/// ```dart
/// final items = list.map((e) => Item(e));
/// ```
///
/// Example of **good** code:
/// ```dart
/// final items = list.map(Item.new);
/// ```
class PreferShorthandsWithConstructorsRule extends SaropaLintRule {
  const PreferShorthandsWithConstructorsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_shorthands_with_constructors',
    problemMessage:
        '[prefer_shorthands_with_constructors] Lambda wraps a constructor call without adding any logic (e.g. (x) => MyClass(x)). The closure allocates an extra function object on each evaluation and obscures the simple delegation, making the code harder to read at a glance. {v4}',
    correctionMessage:
        'Replace the lambda with a constructor tear-off (ClassName.new) to eliminate the wrapper function and communicate the delegation intent directly.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFunctionExpression((FunctionExpression node) {
      final FunctionBody body = node.body;

      Expression? bodyExpr;
      if (body is ExpressionFunctionBody) {
        bodyExpr = body.expression;
      } else if (body is BlockFunctionBody) {
        final NodeList<Statement> statements = body.block.statements;
        if (statements.length == 1 && statements.first is ReturnStatement) {
          bodyExpr = (statements.first as ReturnStatement).expression;
        }
      }

      if (bodyExpr is! InstanceCreationExpression) return;

      final FormalParameterList? paramList = node.parameters;
      if (paramList == null) return;

      final List<FormalParameter> params = paramList.parameters.toList();
      if (params.length != 1) return;

      final String paramName = params.first.name?.lexeme ?? '';

      final ArgumentList args = bodyExpr.argumentList;
      if (args.arguments.length != 1) return;

      final Expression arg = args.arguments.first;
      if (arg is SimpleIdentifier && arg.name == paramName) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when enum shorthand can be used.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Example of **bad** code:
/// ```dart
/// final status = Status.values.where((e) => e == Status.active);
/// ```
class PreferShorthandsWithEnumsRule extends SaropaLintRule {
  const PreferShorthandsWithEnumsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_shorthands_with_enums',
    problemMessage:
        '[prefer_shorthands_with_enums] Enum accessed using verbose qualification (EnumType.enumValue) where shorthand (.enumValue) is available. This adds unnecessary repetition, makes code harder to read, and increases the chance of errors when refactoring enum names. {v4}',
    correctionMessage:
        'Use the shorthand enum syntax by omitting the enum type prefix. Within contexts that accept the enum type, write .enumValue instead of EnumType.enumValue for cleaner, more maintainable code.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      // Check for patterns like EnumType.values.where/firstWhere
      final Expression? target = node.target;
      if (target is! PropertyAccess) return;

      if (target.propertyName.name != 'values') return;

      final Expression? enumType = target.target;
      if (enumType == null) return;

      final DartType? type = enumType.staticType;
      if (type == null) return;

      // Check if it's an enum type access
      final Element? element = type.element;
      if (element is EnumElement) {
        final String methodName = node.methodName.name;
        if (methodName == 'where' ||
            methodName == 'firstWhere' ||
            methodName == 'singleWhere') {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when static field shorthand can be used.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Example of **bad** code:
/// ```dart
/// final color = Colors.values.firstWhere((c) => c == Colors.red);
/// ```
class PreferShorthandsWithStaticFieldsRule extends SaropaLintRule {
  const PreferShorthandsWithStaticFieldsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_shorthands_with_static_fields',
    problemMessage:
        '[prefer_shorthands_with_static_fields] Static field accessed through unnecessary collection search (firstWhere, where) when direct access is available. This wastes CPU cycles iterating through values and makes code less efficient and harder to understand. {v4}',
    correctionMessage:
        'Replace the collection search with direct static field access (e.g., Colors.red instead of Colors.values.firstWhere((c) => c == Colors.red)). Direct access is instant, clearer, and cannot fail.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'firstWhere' &&
          node.methodName.name != 'singleWhere') {
        return;
      }

      final Expression? target = node.target;
      if (target is! PropertyAccess) return;

      // Check for Class.staticList.firstWhere pattern
      final ArgumentList args = node.argumentList;
      if (args.arguments.isEmpty) return;

      final Expression firstArg = args.arguments.first;
      if (firstArg is! FunctionExpression) return;

      final FunctionBody body = firstArg.body;
      if (body is! ExpressionFunctionBody) return;

      final Expression bodyExpr = body.expression;
      if (bodyExpr is BinaryExpression &&
          bodyExpr.operator.type == TokenType.EQ_EQ) {
        // Check if comparing against a static field
        final Expression right = bodyExpr.rightOperand;
        if (right is PrefixedIdentifier || right is PropertyAccess) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when a parameter type doesn't match the accepted type annotation.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Example of **bad** code:
/// ```dart
/// void process(@Accept(String) int value) {} // Type mismatch
/// ```
class PassCorrectAcceptedTypeRule extends SaropaLintRule {
  const PassCorrectAcceptedTypeRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'pass_correct_accepted_type',
    problemMessage:
        '[pass_correct_accepted_type] Argument type does not match the parameter type declared by the @Accept annotation. Passing an incompatible type circumvents the annotation contract, which may cause runtime cast failures or incorrect behavior in the called function. {v4}',
    correctionMessage:
        'Change the argument to match the type declared in the @Accept annotation, or update the annotation if the accepted type has intentionally changed.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFormalParameter((FormalParameter node) {
      // Check for Accept-style annotations
      for (final Annotation annotation in node.metadata) {
        final String annotationName = annotation.name.name;
        if (annotationName == 'Accept' || annotationName == 'AcceptType') {
          final ArgumentList? args = annotation.arguments;
          if (args != null && args.arguments.isNotEmpty) {
            final Expression firstArg = args.arguments.first;
            if (firstArg is TypeLiteral) {
              // Get expected type from annotation
              final String expectedTypeName = firstArg.type.toSource();

              // Get actual parameter type
              final TypeAnnotation? paramType =
                  node is SimpleFormalParameter ? node.type : null;

              if (paramType != null) {
                final String actualTypeName = paramType.toSource();
                if (actualTypeName != expectedTypeName &&
                    !actualTypeName.contains(expectedTypeName)) {
                  reporter.atNode(node, code);
                }
              }
            }
          }
        }
      }
    });
  }
}

/// Warns when an optional argument is not passed but could improve clarity.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Detects method calls that are missing commonly-used optional boolean
/// arguments like `verbose`, `recursive`, `force`, etc.
///
/// Example of **bad** code:
/// ```dart
/// void process(String name, {bool verbose}) {}
/// process('test'); // Missing optional verbose arg
/// ```
class PassOptionalArgumentRule extends SaropaLintRule {
  const PassOptionalArgumentRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'pass_optional_argument',
    problemMessage:
        '[pass_optional_argument] Function call omits important optional parameter, relying on default value. Future readers must hunt for the function definition to understand the omitted behavior, making code harder to comprehend and maintain at the call site. {v4}',
    correctionMessage:
        'Explicitly pass the optional parameter with its intended value, even if it matches the default. This documents your intent at the call site and prevents confusion if the default changes, improving code clarity.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  // Common boolean parameter names that should be passed explicitly
  static const Set<String> _importantBoolParams = <String>{
    'verbose',
    'recursive',
    'force',
    'isRequired',
    'shouldValidate',
    'hasHeader',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
      // Find functions that have important optional boolean parameters
      final FormalParameterList? params = node.functionExpression.parameters;
      if (params == null) return;

      final Set<String> optionalBoolParams = <String>{};
      for (final FormalParameter param in params.parameters) {
        if (param.isNamed || param.isOptional) {
          final String? name = param.name?.lexeme;
          if (name != null && _importantBoolParams.contains(name)) {
            optionalBoolParams.add(name);
          }
        }
      }

      if (optionalBoolParams.isEmpty) return;

      // Store for later checking of call sites
      // This rule checks at declaration site for documentation purposes
      // A more complete implementation would track call sites
    });
  }
}

/// Warns when a file contains multiple top-level declarations.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v3
///
/// Example of **bad** code:
/// ```dart
/// // my_file.dart
/// class Foo {}
/// class Bar {} // Should be in separate file
/// ```
class PreferSingleDeclarationPerFileRule extends SaropaLintRule {
  const PreferSingleDeclarationPerFileRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_single_declaration_per_file',
    problemMessage:
        '[prefer_single_declaration_per_file] File contains multiple top-level class, enum, or extension declarations. Combining unrelated declarations in one file makes it harder to locate definitions, increases merge conflicts when multiple developers edit the same file, and breaks the convention of one-declaration-per-file. {v3}',
    correctionMessage:
        'Split each top-level declaration into its own file, named after the declaration (e.g. my_class.dart for MyClass), to improve discoverability and reduce merge conflicts.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCompilationUnit((CompilationUnit node) {
      // Count significant top-level declarations
      int classCount = 0;
      int enumCount = 0;
      int mixinCount = 0;
      ClassDeclaration? secondClass;

      for (final CompilationUnitMember member in node.declarations) {
        if (member is ClassDeclaration) {
          classCount++;
          if (classCount == 2) {
            secondClass = member;
          }
        } else if (member is EnumDeclaration) {
          enumCount++;
        } else if (member is MixinDeclaration) {
          mixinCount++;
        }
      }

      // Report if there are multiple major declarations
      final int majorDeclarations = classCount + enumCount + mixinCount;
      if (majorDeclarations > 1 && secondClass != null) {
        // Skip if it looks like a private helper class
        if (!secondClass.name.lexeme.startsWith('_')) {
          reporter.atNode(secondClass, code);
        }
      }
    });
  }
}

/// Warns when a switch statement could be converted to a switch expression.
///
/// Since: v2.7.0 | Updated: v4.13.0 | Rule version: v5
///
/// Example of **bad** code:
/// ```dart
/// String result;
/// switch (value) {
///   case 1: result = 'one'; break;
///   case 2: result = 'two'; break;
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// final result = switch (value) {
///   1 => 'one',
///   2 => 'two',
/// };
/// ```
class PreferSwitchExpressionRule extends SaropaLintRule {
  const PreferSwitchExpressionRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_switch_expression',
    problemMessage:
        '[prefer_switch_expression] Switch statement with only return/assignment detected. Using statement syntax for simple value mapping adds unnecessary boilerplate (break statements, case keywords) and makes the code more verbose and harder to scan. {v5}',
    correctionMessage:
        'Replace with a switch expression that directly produces the mapped value. Switch expressions are more concise, cannot forget break statements, and guarantee exhaustiveness checking, reducing bugs and improving readability.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSwitchStatement((SwitchStatement node) {
      // Check if all cases are simple assignments or returns
      bool allSimpleAssignments = true;
      String? targetVariable;
      bool allReturns = true;

      for (final SwitchMember member in node.members) {
        if (member is SwitchCase) {
          final List<Statement> statements = member.statements;
          if (statements.isEmpty) {
            allSimpleAssignments = false;
            allReturns = false;
            continue;
          }

          // Check first non-break statement
          for (final Statement stmt in statements) {
            if (stmt is BreakStatement) continue;

            if (stmt is ExpressionStatement) {
              final Expression expr = stmt.expression;
              if (expr is AssignmentExpression) {
                final Expression left = expr.leftHandSide;
                if (left is SimpleIdentifier) {
                  if (targetVariable == null) {
                    targetVariable = left.name;
                  } else if (targetVariable != left.name) {
                    allSimpleAssignments = false;
                  }
                } else {
                  allSimpleAssignments = false;
                }
              } else {
                allSimpleAssignments = false;
              }
              allReturns = false;
            } else if (stmt is ReturnStatement) {
              allSimpleAssignments = false;
            } else {
              allSimpleAssignments = false;
              allReturns = false;
            }
          }
        } else if (member is SwitchDefault) {
          // Default case - check same pattern
          for (final Statement stmt in member.statements) {
            if (stmt is! BreakStatement &&
                stmt is! ReturnStatement &&
                stmt is! ExpressionStatement) {
              allSimpleAssignments = false;
              allReturns = false;
            }
          }
        }
      }

      // Report if it's a good candidate for switch expression
      if ((allSimpleAssignments && targetVariable != null) || allReturns) {
        reporter.atToken(node.switchKeyword, code);
      }
    });
  }
}

/// Warns when if-else chains on enum values could use a switch.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Example of **bad** code:
/// ```dart
/// if (status == Status.active) {
///   // ...
/// } else if (status == Status.pending) {
///   // ...
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// switch (status) {
///   case Status.active: // ...
///   case Status.pending: // ...
/// }
/// ```
class PreferSwitchWithEnumsRule extends SaropaLintRule {
  const PreferSwitchWithEnumsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_switch_with_enums',
    problemMessage:
        '[prefer_switch_with_enums] Enum compared using if-else chain instead of switch statement. Without exhaustiveness checking, adding new enum values will not trigger compile errors in this code location, allowing silent bugs where new cases are unhandled. {v4}',
    correctionMessage:
        'Replace the if-else chain with a switch statement over the enum. The compiler will verify all enum values are handled and flag warnings when you add new enum cases, preventing missed implementations.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addIfStatement((IfStatement node) {
      // Only check if statements with else-if chains
      if (node.elseStatement == null) return;

      // Check if condition compares an enum
      final Expression condition = node.expression;
      if (condition is! BinaryExpression) return;
      if (condition.operator.type != TokenType.EQ_EQ) return;

      // Check if comparing against enum value
      final Expression left = condition.leftOperand;
      final Expression right = condition.rightOperand;

      bool isEnumComparison = false;
      SimpleIdentifier? enumVariable;

      if (_isEnumValue(right)) {
        if (left is SimpleIdentifier) {
          enumVariable = left;
          isEnumComparison = true;
        }
      } else if (_isEnumValue(left)) {
        if (right is SimpleIdentifier) {
          enumVariable = right;
          isEnumComparison = true;
        }
      }

      if (!isEnumComparison || enumVariable == null) return;

      // Count else-if branches comparing same variable
      int branchCount = 1;
      Statement? elseStmt = node.elseStatement;

      while (elseStmt is IfStatement) {
        final Expression elseCondition = elseStmt.expression;
        if (elseCondition is BinaryExpression &&
            elseCondition.operator.type == TokenType.EQ_EQ) {
          final Expression elseLeft = elseCondition.leftOperand;
          final Expression elseRight = elseCondition.rightOperand;

          if ((elseLeft is SimpleIdentifier &&
                  elseLeft.name == enumVariable.name) ||
              (elseRight is SimpleIdentifier &&
                  elseRight.name == enumVariable.name)) {
            branchCount++;
          }
        }
        elseStmt = elseStmt.elseStatement;
      }

      // Report if there are 3+ branches
      if (branchCount >= 3) {
        reporter.atToken(node.ifKeyword, code);
      }
    });
  }

  bool _isEnumValue(Expression expr) {
    if (expr is PrefixedIdentifier) {
      // Check if it looks like EnumType.value
      final String prefix = expr.prefix.name;
      if (prefix.isNotEmpty && prefix[0] == prefix[0].toUpperCase()) {
        return true;
      }
    } else if (expr is PropertyAccess) {
      final Expression? target = expr.target;
      if (target is SimpleIdentifier) {
        final String name = target.name;
        if (name.isNotEmpty && name[0] == name[0].toUpperCase()) {
          return true;
        }
      }
    }
    return false;
  }
}

/// Warns when if-else chains on sealed class could use exhaustive switch.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// Example of **bad** code:
/// ```dart
/// if (result is Success) {
///   // ...
/// } else if (result is Error) {
///   // ...
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// switch (result) {
///   case Success(): // ...
///   case Error(): // ...
/// }
/// ```
class PreferSwitchWithSealedClassesRule extends SaropaLintRule {
  const PreferSwitchWithSealedClassesRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_switch_with_sealed_classes',
    problemMessage:
        '[prefer_switch_with_sealed_classes] Sealed class handled with if-else or type checks instead of switch. Missing exhaustiveness verification allows unhandled subtypes to silently pass through, causing runtime errors or incorrect behavior when new subtypes are added. {v5}',
    correctionMessage:
        'Replace with a switch statement using pattern matching on the sealed class subtypes. The compiler enforces that all possible subtypes are handled, preventing bugs when the sealed class hierarchy grows.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addIfStatement((IfStatement node) {
      // Only check if statements with else-if chains
      if (node.elseStatement == null) return;

      // Check if condition is a type check
      final Expression condition = node.expression;
      if (condition is! IsExpression) return;

      final Expression target = condition.expression;
      if (target is! SimpleIdentifier) return;

      final String variableName = target.name;

      // Count type check branches
      int branchCount = 1;
      Statement? elseStmt = node.elseStatement;

      while (elseStmt is IfStatement) {
        final Expression elseCondition = elseStmt.expression;
        if (elseCondition is IsExpression) {
          final Expression elseTarget = elseCondition.expression;
          if (elseTarget is SimpleIdentifier &&
              elseTarget.name == variableName) {
            branchCount++;
          }
        }
        elseStmt = elseStmt.elseStatement;
      }

      // Report if there are 2+ type check branches
      if (branchCount >= 2) {
        reporter.atToken(node.ifKeyword, code);
      }
    });
  }
}

/// Warns when test assertions could use more specific matchers.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Example of **bad** code:
/// ```dart
/// expect(list.length, equals(0));
/// expect(string.contains('x'), isTrue);
/// ```
///
/// Example of **good** code:
/// ```dart
/// expect(list, isEmpty);
/// expect(string, contains('x'));
/// ```
class PreferTestMatchersRule extends SaropaLintRule {
  const PreferTestMatchersRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_test_matchers',
    problemMessage:
        '[prefer_test_matchers] Generic expect(value, equals(x)) or expect(value, isTrue) used where a more specific matcher exists. Specific matchers produce clearer failure messages that show the actual vs expected difference, reducing debugging time when tests fail. {v4}',
    correctionMessage:
        'Replace with the appropriate specific matcher (e.g. expect(list, contains(x)), expect(map, containsPair(k, v)), expect(fn, throwsA(isA<MyError>()))) for better diagnostics.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Only check test files
    final String path = resolver.source.fullName;
    if (!path.contains('test') && !path.endsWith('_test.dart')) return;

    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'expect') return;

      final List<Expression> args = node.argumentList.arguments.toList();
      if (args.length < 2) return;

      final Expression actual = args[0];
      final Expression matcher = args[1];

      // Check for list.length == 0 pattern
      if (actual is PropertyAccess && actual.propertyName.name == 'length') {
        if (matcher is MethodInvocation &&
            matcher.methodName.name == 'equals') {
          final List<Expression> matcherArgs =
              matcher.argumentList.arguments.toList();
          if (matcherArgs.isNotEmpty) {
            final Expression matcherArg = matcherArgs[0];
            if (matcherArg is IntegerLiteral && matcherArg.value == 0) {
              reporter.atNode(node, code);
              return;
            }
          }
        }
      }

      // Check for .contains() with isTrue/isFalse
      if (actual is MethodInvocation && actual.methodName.name == 'contains') {
        if (matcher is SimpleIdentifier) {
          if (matcher.name == 'isTrue' || matcher.name == 'isFalse') {
            reporter.atNode(node, code);
            return;
          }
        }
      }

      // Check for .isEmpty with isTrue/isFalse
      if (actual is PropertyAccess &&
          (actual.propertyName.name == 'isEmpty' ||
              actual.propertyName.name == 'isNotEmpty')) {
        if (matcher is SimpleIdentifier &&
            (matcher.name == 'isTrue' || matcher.name == 'isFalse')) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when `FutureOr<T>` could be unwrapped for cleaner handling.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Example of **bad** code:
/// ```dart
/// FutureOr<int> getValue() => 42;
/// void process() {
///   final value = getValue();
///   if (value is Future<int>) {
///     value.then((v) => print(v));
///   } else {
///     print(value);
///   }
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// Future<int> getValue() async => 42;
/// void process() async {
///   final value = await getValue();
///   print(value);
/// }
/// ```
class PreferUnwrappingFutureOrRule extends SaropaLintRule {
  const PreferUnwrappingFutureOrRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_unwrapping_future_or',
    problemMessage:
        '[prefer_unwrapping_future_or] FutureOr type detected requiring manual type checking and unwrapping. This forces runtime type inspection (is Future checks) and adds branching complexity, making the code harder to understand and more error-prone. {v4}',
    correctionMessage:
        'Convert the function to async and use await to unwrap values uniformly. Async/await eliminates the need for runtime type checking, produces cleaner control flow, and ensures consistent handling of both synchronous and asynchronous values.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addIfStatement((IfStatement node) {
      // Check for pattern: if (value is Future<T>)
      final Expression condition = node.expression;
      if (condition is! IsExpression) return;

      final TypeAnnotation type = condition.type;
      if (type is! NamedType) return;

      if (type.name.lexeme == 'Future') {
        // This is checking if something is a Future, likely FutureOr handling
        final Expression target = condition.expression;
        if (target is SimpleIdentifier) {
          reporter.atNode(node, code);
        }
      }
    });

    // Also check for FutureOr return types that could be simplified
    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
      final TypeAnnotation? returnType = node.returnType;
      if (returnType is NamedType && returnType.name.lexeme == 'FutureOr') {
        // Check if body is simple enough to just be async
        final FunctionBody body = node.functionExpression.body;
        if (body is BlockFunctionBody) {
          // Has block body - might benefit from being async
          bool hasAwait = false;
          body.accept(_AwaitFinderVisitor((bool found) => hasAwait = found));
          if (!hasAwait) {
            reporter.atNode(returnType, code);
          }
        }
      }
    });
  }
}

class _AwaitFinderVisitor extends RecursiveAstVisitor<void> {
  _AwaitFinderVisitor(this.onFound);
  final void Function(bool) onFound;

  @override
  void visitAwaitExpression(AwaitExpression node) {
    onFound(true);
  }
}

// =============================================================================
// HARD COMPLEXITY RULES
// =============================================================================

/// Warns when type arguments can be inferred and are redundant.
///
/// Since: v4.5.2 | Updated: v4.13.0 | Rule version: v3
///
/// Example of **bad** code:
/// ```dart
/// final list = <String>['a', 'b'];  // Type can be inferred
/// final map = Map<String, int>();   // Type can be inferred from usage
/// ```
///
/// Example of **good** code:
/// ```dart
/// final list = ['a', 'b'];  // Type inferred as List<String>
/// final map = <String, int>{};  // Explicit when needed
/// ```
///
/// Formerly: `avoid_inferrable_type_arguments`
class AvoidInferrableTypeArgumentsRule extends SaropaLintRule {
  const AvoidInferrableTypeArgumentsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.high;

  @override
  List<String> get configAliases =>
      const <String>['avoid_inferrable_type_arguments'];

  static const LintCode _code = LintCode(
    name: 'prefer_inferred_type_arguments',
    problemMessage:
        '[prefer_inferred_type_arguments] Explicit generic type arguments match what the compiler already infers from context. Redundant type parameters add visual noise without providing additional type safety, and they must be manually updated if the underlying types change. {v3}',
    correctionMessage:
        'Remove the explicit type arguments and let the compiler infer them. This reduces verbosity and keeps the code in sync with the actual types automatically.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addListLiteral((ListLiteral node) {
      final TypeArgumentList? typeArgs = node.typeArguments;
      if (typeArgs == null) return;
      if (node.elements.isEmpty) return;

      // Check if all elements are the same type as the declared type
      final String declaredType = typeArgs.arguments.first.toSource();
      bool allMatch = true;

      for (final CollectionElement element in node.elements) {
        if (element is Expression) {
          final DartType? elementType = element.staticType;
          if (elementType == null) {
            allMatch = false;
            break;
          }
          final String elementTypeName = elementType.getDisplayString();
          if (elementTypeName != declaredType &&
              !elementTypeName.startsWith(declaredType)) {
            allMatch = false;
            break;
          }
        }
      }

      if (allMatch && node.elements.isNotEmpty) {
        reporter.atNode(typeArgs, code);
      }
    });

    context.registry.addSetOrMapLiteral((SetOrMapLiteral node) {
      final TypeArgumentList? typeArgs = node.typeArguments;
      if (typeArgs == null) return;
      if (node.elements.isEmpty) return;

      // For non-empty literals with type args, the types can often be inferred
      reporter.atNode(typeArgs, code);
    });
  }
}

/// Warns when an empty collection default value is passed explicitly.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// This is a conservative rule that only flags clearly redundant patterns:
/// - Empty list literals: `[]` or `const []`
/// - Empty map literals: `{}` or `const {}`
///
/// Example of **bad** code:
/// ```dart
/// void foo({List<int> items = const []}) {}
/// foo(items: const []);  // Passing default value explicitly
/// ```
///
/// Example of **good** code:
/// ```dart
/// void foo({List<int> items = const []}) {}
/// foo();  // Omit argument when using default
/// ```
class AvoidPassingDefaultValuesRule extends SaropaLintRule {
  const AvoidPassingDefaultValuesRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_passing_default_values',
    problemMessage:
        '[avoid_passing_default_values] Argument explicitly passes a value that matches the parameter default (e.g. empty list, false, 0). Passing the default adds noise to the call site without changing behavior, and if the library updates its default, this call site will not benefit from the change. {v4}',
    correctionMessage:
        'Omit the argument to use the default value. This keeps call sites concise and automatically picks up any default changes from the callee.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      _checkArguments(node.argumentList, reporter);
    });

    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      _checkArguments(node.argumentList, reporter);
    });
  }

  void _checkArguments(
      ArgumentList argList, SaropaDiagnosticReporter reporter) {
    for (final Expression arg in argList.arguments) {
      if (arg is! NamedExpression) continue;

      final Expression value = arg.expression;

      // Only flag empty collection literals - these are almost always defaults
      if (_isEmptyCollectionLiteral(value)) {
        reporter.atNode(arg, code);
      }
    }
  }

  bool _isEmptyCollectionLiteral(Expression expr) {
    // Check for empty list literal
    if (expr is ListLiteral && expr.elements.isEmpty) {
      return true;
    }
    // Check for empty set/map literal
    if (expr is SetOrMapLiteral && expr.elements.isEmpty) {
      return true;
    }
    return false;
  }
}

/// Warns when an extension method shadows a class method.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v3
///
/// Example of **bad** code:
/// ```dart
/// extension StringExt on String {
///   int get length => 0;  // Shadows String.length
/// }
/// ```
class AvoidShadowedExtensionMethodsRule extends SaropaLintRule {
  const AvoidShadowedExtensionMethodsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_shadowed_extension_methods',
    problemMessage:
        '[avoid_shadowed_extension_methods] Extension method has the same name as an instance method on the target class. The instance method always takes precedence, so the extension method is never called through normal dispatch, making it dead code that misleads developers. {v3}',
    correctionMessage:
        'Rename the extension method to a unique name, or remove it if the instance method already provides the needed behavior.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addExtensionDeclaration((ExtensionDeclaration node) {
      final ExtensionOnClause? onClause = node.onClause;
      if (onClause == null) return;

      final TypeAnnotation extendedType = onClause.extendedType;
      final DartType? type = extendedType.type;
      if (type == null) return;

      final Element? typeElement = type.element;
      if (typeElement is! InterfaceElement) return;

      // Get all method names from the extended type
      final Set<String> classMethods = <String>{};
      for (final MethodElement method in typeElement.methods) {
        final String? name = method.name;
        if (name != null) classMethods.add(name);
      }

      // Check extension members
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration) {
          final String methodName = member.name.lexeme;
          if (classMethods.contains(methodName)) {
            reporter.atToken(member.name, code);
          }
        }
      }
    });
  }
}

/// Warns when a late local variable is initialized immediately.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// Example of **bad** code:
/// ```dart
/// void foo() {
///   late final x = compute();  // late is unnecessary
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// void foo() {
///   final x = compute();  // No late needed
/// }
/// ```
class AvoidUnnecessaryLocalLateRule extends SaropaLintRule {
  const AvoidUnnecessaryLocalLateRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_unnecessary_local_late',
    problemMessage:
        '[avoid_unnecessary_local_late] Local variable declared as late but assigned a value on the same line. The late keyword is designed for deferred initialization, so using it on an immediately initialized variable is misleading and disables the compile-time check that ensures the variable is assigned. {v5}',
    correctionMessage:
        'Remove the late keyword and keep the immediate initializer. Use final or var to declare the variable with full compile-time initialization safety.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addVariableDeclarationStatement((VariableDeclarationStatement node) {
      final VariableDeclarationList variables = node.variables;
      if (!variables.isLate) return;

      for (final VariableDeclaration variable in variables.variables) {
        if (variable.initializer != null) {
          // Variable has an initializer, late is unnecessary
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when an overriding method specifies default values that look suspicious.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v3
///
/// This rule flags overriding methods that specify non-standard default values,
/// which may indicate they differ from the parent class definition.
///
/// Example of **bad** code:
/// ```dart
/// class Parent {
///   void foo({int x = 0}) {}
/// }
/// class Child extends Parent {
///   @override
///   void foo({int x = 42}) {}  // Non-zero default is suspicious
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// class Parent {
///   void foo({int x = 0}) {}
/// }
/// class Child extends Parent {
///   @override
///   void foo({int x = 0}) {}  // Matches parent
/// }
/// ```
class MatchBaseClassDefaultValueRule extends SaropaLintRule {
  const MatchBaseClassDefaultValueRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'match_base_class_default_value',
    problemMessage:
        '[match_base_class_default_value] Overridden method parameter has a different default value than the parent class. Callers using the parent type see the parent default, while callers using the subtype see the override default, creating inconsistent behavior depending on the variable type. {v3}',
    correctionMessage:
        'Match the parent class default value exactly, or remove the default to inherit it. If a different default is intentional, document why the override diverges.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration classNode) {
      // Get parent class
      final ExtendsClause? extendsClause = classNode.extendsClause;
      if (extendsClause == null) return;

      // Check each method in the class
      for (final ClassMember member in classNode.members) {
        if (member is! MethodDeclaration) continue;

        // Check if it's an override
        bool isOverride = false;
        for (final Annotation annotation in member.metadata) {
          if (annotation.name.name == 'override') {
            isOverride = true;
            break;
          }
        }
        if (!isOverride) continue;

        final FormalParameterList? params = member.parameters;
        if (params == null) continue;

        // Check parameters with default values
        for (final FormalParameter param in params.parameters) {
          if (param is! DefaultFormalParameter) continue;

          final Expression? defaultValue = param.defaultValue;
          if (defaultValue == null) continue;

          // Flag non-standard defaults that are likely to differ from parent
          if (_isNonStandardDefault(defaultValue)) {
            reporter.atNode(defaultValue, code);
          }
        }
      }
    });
  }

  bool _isNonStandardDefault(Expression expr) {
    // Standard defaults that are typically safe: null, false, 0, '', [], {}
    if (expr is NullLiteral) return false;
    if (expr is BooleanLiteral && !expr.value) return false;
    if (expr is IntegerLiteral && expr.value == 0) return false;
    if (expr is DoubleLiteral && expr.value == 0.0) return false;
    if (expr is SimpleStringLiteral && expr.value.isEmpty) return false;
    if (expr is ListLiteral && expr.elements.isEmpty) return false;
    if (expr is SetOrMapLiteral && expr.elements.isEmpty) return false;

    // Non-zero integers, non-empty strings, true booleans are suspicious
    if (expr is IntegerLiteral && expr.value != 0) return true;
    if (expr is BooleanLiteral && expr.value) return true;
    if (expr is SimpleStringLiteral && expr.value.isNotEmpty) return true;

    return false;
  }
}

/// Warns when a variable could be declared closer to its usage.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v7
///
/// Alias: move_variable_closer_to_usage
///
/// Example of **bad** code:
/// ```dart
/// void foo() {
///   final x = 1;
///   // ... 20 lines of code not using x ...
///   print(x);
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// void foo() {
///   // ... 20 lines of code ...
///   final x = 1;
///   print(x);
/// }
/// ```
class MoveVariableCloserToUsageRule extends SaropaLintRule {
  const MoveVariableCloserToUsageRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'move_variable_closer_to_its_usage',
    problemMessage:
        '[move_variable_closer_to_its_usage] Variable declared far from its first use, with many unrelated statements in between. This forces readers to hold the variable in memory while reading irrelevant code, reducing comprehension and increasing the risk of accidental reuse or shadowing. {v7}',
    correctionMessage:
        'Move the variable declaration to just before its first usage. This narrows the scope, improves readability, and makes the data flow easier to follow.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const int _minLineDistance = 10;

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addBlock((Block node) {
      final Map<String, int> declarationLines = <String, int>{};
      final Map<String, int> firstUsageLines = <String, int>{};
      final Map<String, VariableDeclaration> declarations =
          <String, VariableDeclaration>{};

      // First pass: collect declarations
      for (final Statement statement in node.statements) {
        if (statement is VariableDeclarationStatement) {
          for (final VariableDeclaration variable
              in statement.variables.variables) {
            final String name = variable.name.lexeme;
            declarationLines[name] =
                resolver.lineInfo.getLocation(variable.offset).lineNumber;
            declarations[name] = variable;
          }
        }
      }

      // Second pass: find first usage of each variable
      node.visitChildren(
        _FirstUsageVisitor(
            declarationLines.keys.toSet(), firstUsageLines, resolver),
      );

      // Check distances
      for (final String name in declarationLines.keys) {
        final int declLine = declarationLines[name]!;
        final int? useLine = firstUsageLines[name];

        if (useLine != null && useLine - declLine > _minLineDistance) {
          final VariableDeclaration? decl = declarations[name];
          if (decl != null) {
            reporter.atToken(decl.name, code);
          }
        }
      }
    });
  }
}

class _FirstUsageVisitor extends RecursiveAstVisitor<void> {
  _FirstUsageVisitor(this.variableNames, this.firstUsageLines, this.resolver);

  final Set<String> variableNames;
  final Map<String, int> firstUsageLines;
  final CustomLintResolver resolver;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    final String name = node.name;
    if (variableNames.contains(name) && !firstUsageLines.containsKey(name)) {
      // Skip if this is the declaration itself
      if (node.parent is VariableDeclaration &&
          (node.parent as VariableDeclaration).name == node.token) {
        return;
      }
      firstUsageLines[name] =
          resolver.lineInfo.getLocation(node.offset).lineNumber;
    }
    super.visitSimpleIdentifier(node);
  }
}

/// Warns when a variable could be moved outside a loop.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Alias: move_variable_outside_iteration
///
/// Example of **bad** code:
/// ```dart
/// for (int i = 0; i < 10; i++) {
///   final regex = RegExp(r'\d+');  // Created every iteration
///   print(regex.hasMatch('$i'));
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// final regex = RegExp(r'\d+');
/// for (int i = 0; i < 10; i++) {
///   print(regex.hasMatch('$i'));
/// }
/// ```
class MoveVariableOutsideIterationRule extends SaropaLintRule {
  const MoveVariableOutsideIterationRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'move_variable_outside_iteration',
    problemMessage:
        '[move_variable_outside_iteration] Variable declared and assigned inside a loop body produces the same value on every iteration. Recreating the same object or computing the same expression repeatedly wastes CPU cycles and puts unnecessary pressure on the garbage collector. {v4}',
    correctionMessage:
        'Move the variable declaration above the loop so it is computed once and reused on each iteration, reducing allocation overhead and improving clarity.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    void checkLoopBody(Statement body) {
      if (body is! Block) return;

      for (final Statement statement in body.statements) {
        if (statement is VariableDeclarationStatement) {
          for (final VariableDeclaration variable
              in statement.variables.variables) {
            final Expression? initializer = variable.initializer;
            if (initializer == null) continue;

            // Check if initializer is a constant expression or only uses
            // values available outside the loop
            if (_isLoopInvariant(initializer)) {
              reporter.atToken(variable.name, code);
            }
          }
        }
      }
    }

    context.registry.addForStatement((ForStatement node) {
      checkLoopBody(node.body);
    });

    context.registry.addWhileStatement((WhileStatement node) {
      checkLoopBody(node.body);
    });

    context.registry.addDoStatement((DoStatement node) {
      checkLoopBody(node.body);
    });
  }

  bool _isLoopInvariant(Expression expr) {
    // Check for common loop-invariant patterns
    if (expr is InstanceCreationExpression) {
      // Constructor calls with only literal arguments
      for (final Expression arg in expr.argumentList.arguments) {
        if (!_isConstant(arg)) return false;
      }
      return true;
    }

    if (expr is MethodInvocation) {
      // Static method calls with constant args
      final Expression? target = expr.target;
      if (target is SimpleIdentifier) {
        final String name = target.name;
        // Check if it's a type name (static call)
        if (name.isNotEmpty && name[0] == name[0].toUpperCase()) {
          for (final Expression arg in expr.argumentList.arguments) {
            if (!_isConstant(arg)) return false;
          }
          return true;
        }
      }
    }

    return false;
  }

  bool _isConstant(Expression expr) {
    if (expr is Literal) return true;
    if (expr is NamedExpression) return _isConstant(expr.expression);
    return false;
  }
}

/// Warns when a class overrides == but not the parent's ==.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Example of **bad** code:
/// ```dart
/// class Parent {
///   @override
///   bool operator ==(Object other) => other is Parent;
/// }
/// class Child extends Parent {
///   @override
///   bool operator ==(Object other) =>
///       other is Child;  // Doesn't call super or check Parent equality
/// }
/// ```
class PreferOverridingParentEqualityRule extends SaropaLintRule {
  const PreferOverridingParentEqualityRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_overriding_parent_equality',
    problemMessage:
        '[prefer_overriding_parent_equality] Subclass overrides == without incorporating the parent class equality check. If the parent class compares fields that the subclass ignores, two objects may be considered equal even though their parent fields differ, breaking the transitivity contract of ==. {v4}',
    correctionMessage:
        'Call super == other as part of the equality check, or explicitly compare all parent fields alongside the subclass fields to ensure consistent equality behavior.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if class has an == operator
      MethodDeclaration? equalityOperator;
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration &&
            member.name.lexeme == '==' &&
            member.isOperator) {
          equalityOperator = member;
          break;
        }
      }

      if (equalityOperator == null) return;

      // Check if parent class has == operator
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final NamedType superType = extendsClause.superclass;
      final DartType? superDartType = superType.type;
      if (superDartType == null) return;

      final Element? superElement = superDartType.element;
      if (superElement is! InterfaceElement) return;

      // Check if parent has custom == (not just Object.==)
      bool parentHasCustomEquals = false;
      for (final MethodElement method in superElement.methods) {
        if (method.name == '==' && !method.isAbstract) {
          // Check if it's from Object or a custom implementation
          final enclosing = (method as Element).enclosingElement;
          final String? enclosingName =
              enclosing is InterfaceElement ? enclosing.name : null;
          if (enclosingName != null && enclosingName != 'Object') {
            parentHasCustomEquals = true;
            break;
          }
        }
      }

      if (!parentHasCustomEquals) return;

      // Check if the child's == calls super.==
      bool callsSuper = false;
      equalityOperator.body
          .visitChildren(_SuperEqualityChecker(() => callsSuper = true));

      if (!callsSuper) {
        reporter.atToken(equalityOperator.name, code);
      }
    });
  }
}

class _SuperEqualityChecker extends RecursiveAstVisitor<void> {
  _SuperEqualityChecker(this.onSuperFound);

  final void Function() onSuperFound;

  @override
  void visitBinaryExpression(BinaryExpression node) {
    if (node.operator.lexeme == '==') {
      if (node.leftOperand is SuperExpression ||
          node.rightOperand is SuperExpression) {
        onSuperFound();
      }
    }
    super.visitBinaryExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.target is SuperExpression) {
      onSuperFound();
    }
    super.visitMethodInvocation(node);
  }
}

/// Warns when more specific switch cases should come before general ones.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Example of **bad** code:
/// ```dart
/// switch (value) {
///   case int _: print('int');
///   case int x when x > 0: print('positive');  // Unreachable
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// switch (value) {
///   case int x when x > 0: print('positive');
///   case int _: print('other int');
/// }
/// ```
class PreferSpecificCasesFirstRule extends SaropaLintRule {
  const PreferSpecificCasesFirstRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_specific_cases_first',
    problemMessage:
        '[prefer_specific_cases_first] General switch case appears before a more specific case. In Dart, the first matching case wins, so a broad pattern placed early shadows narrower patterns below it, making those specific cases unreachable dead code. {v4}',
    correctionMessage:
        'Reorder the cases so more specific patterns appear first and general catch-all patterns appear last, ensuring every case is reachable.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  // Cached regex for performance
  static final RegExp _typePattern = RegExp(r'^(\w+)');

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSwitchExpression((SwitchExpression node) {
      _checkCaseOrder(
        node.cases.map((SwitchExpressionCase c) => c.guardedPattern).toList(),
        reporter,
      );
    });

    context.registry.addSwitchStatement((SwitchStatement node) {
      final List<GuardedPattern> patterns = <GuardedPattern>[];
      for (final SwitchMember member in node.members) {
        if (member is SwitchPatternCase) {
          patterns.add(member.guardedPattern);
        }
      }
      _checkCaseOrder(patterns, reporter);
    });
  }

  void _checkCaseOrder(
      List<GuardedPattern> patterns, SaropaDiagnosticReporter reporter) {
    for (int i = 0; i < patterns.length - 1; i++) {
      final GuardedPattern current = patterns[i];
      final GuardedPattern next = patterns[i + 1];

      // Check if current is a general pattern and next is more specific
      final bool currentHasGuard = current.whenClause != null;
      final bool nextHasGuard = next.whenClause != null;

      // If current has no guard but next has a guard with same base pattern,
      // the order might be wrong
      if (!currentHasGuard && nextHasGuard) {
        final String currentPattern = current.pattern.toSource();
        final String nextPattern = next.pattern.toSource();

        // Simple heuristic: same type pattern but one has a guard
        if (_sameBaseType(currentPattern, nextPattern)) {
          reporter.atNode(next, code);
        }
      }
    }
  }

  bool _sameBaseType(String pattern1, String pattern2) {
    // Extract base type from patterns like "int _" or "int x"
    final RegExpMatch? match1 = _typePattern.firstMatch(pattern1);
    final RegExpMatch? match2 = _typePattern.firstMatch(pattern2);

    if (match1 != null && match2 != null) {
      return match1.group(1) == match2.group(1);
    }
    return false;
  }
}

/// Warns when a property is accessed after destructuring provides it.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// Example of **bad** code:
/// ```dart
/// final (x, y) = point;
/// print(point.x);  // Already have x from destructuring
/// ```
///
/// Example of **good** code:
/// ```dart
/// final (x, y) = point;
/// print(x);  // Use destructured variable
/// ```
class UseExistingDestructuringRule extends SaropaLintRule {
  const UseExistingDestructuringRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'use_existing_destructuring',
    problemMessage:
        '[use_existing_destructuring] Property accessed through the original object despite an existing destructured variable that already holds the same value. The redundant access obscures the data flow and ignores the destructuring that was set up to simplify property access. {v5}',
    correctionMessage:
        'Replace the property access with the destructured variable name. This communicates that the value was already extracted and avoids redundant lookups.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addBlock((Block node) {
      final Map<String, Set<String>> destructuredVars = <String, Set<String>>{};

      for (final Statement statement in node.statements) {
        // Find pattern variable declarations
        if (statement is PatternVariableDeclarationStatement) {
          final PatternVariableDeclaration decl = statement.declaration;
          final Expression initializer = decl.expression;
          final DartPattern pattern = decl.pattern;

          if (initializer is SimpleIdentifier) {
            final String sourceName = initializer.name;
            final Set<String> fields = <String>{};

            // Extract field names from pattern
            pattern.visitChildren(_PatternFieldCollector(fields));

            if (fields.isNotEmpty) {
              destructuredVars[sourceName] = fields;
            }
          }
        }

        // Check for property accesses on destructured sources
        statement.visitChildren(
          _DestructuredPropertyAccessChecker(destructuredVars, reporter, _code),
        );
      }
    });
  }
}

class _PatternFieldCollector extends RecursiveAstVisitor<void> {
  _PatternFieldCollector(this.fields);

  final Set<String> fields;

  @override
  void visitDeclaredVariablePattern(DeclaredVariablePattern node) {
    fields.add(node.name.lexeme);
    super.visitDeclaredVariablePattern(node);
  }

  @override
  void visitPatternField(PatternField node) {
    final PatternFieldName? name = node.name;
    if (name != null && name.name != null) {
      fields.add(name.name!.lexeme);
    }
    super.visitPatternField(node);
  }
}

class _DestructuredPropertyAccessChecker extends RecursiveAstVisitor<void> {
  _DestructuredPropertyAccessChecker(
      this.destructuredVars, this.reporter, this.code);

  final Map<String, Set<String>> destructuredVars;
  final SaropaDiagnosticReporter reporter;
  final LintCode code;

  @override
  void visitPropertyAccess(PropertyAccess node) {
    final Expression? target = node.target;
    if (target is SimpleIdentifier) {
      final Set<String>? fields = destructuredVars[target.name];
      if (fields != null && fields.contains(node.propertyName.name)) {
        reporter.atNode(node, code);
      }
    }
    super.visitPropertyAccess(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    final Set<String>? fields = destructuredVars[node.prefix.name];
    if (fields != null && fields.contains(node.identifier.name)) {
      reporter.atNode(node, code);
    }
    super.visitPrefixedIdentifier(node);
  }
}

/// Warns when a new variable is created that duplicates an existing one.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Example of **bad** code:
/// ```dart
/// final name = user.name;
/// final userName = user.name;  // Redundant
/// print('$name, $userName');
/// ```
///
/// Example of **good** code:
/// ```dart
/// final name = user.name;
/// print('$name, $name');
/// ```
class UseExistingVariableRule extends SaropaLintRule {
  const UseExistingVariableRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'use_existing_variable',
    problemMessage:
        '[use_existing_variable] New variable created with the same value as an existing in-scope variable. The duplicate adds an unnecessary name to the scope, increases cognitive load, and risks divergence if one copy is later modified while the other is not. {v4}',
    correctionMessage:
        'Reference the existing variable directly instead of creating a new one. If a different name is needed for clarity, consider renaming the original.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addBlock((Block node) {
      final Map<String, Token> expressionToVariable = <String, Token>{};

      for (final Statement statement in node.statements) {
        if (statement is VariableDeclarationStatement) {
          for (final VariableDeclaration variable
              in statement.variables.variables) {
            final Expression? initializer = variable.initializer;
            if (initializer == null) continue;

            // Skip literals and simple values
            if (initializer is Literal) continue;
            if (initializer is SimpleIdentifier) continue;

            final String exprSource = initializer.toSource();

            if (expressionToVariable.containsKey(exprSource)) {
              // This expression was already assigned to another variable
              reporter.atToken(variable.name, code);
            } else {
              expressionToVariable[exprSource] = variable.name;
            }
          }
        }
      }
    });
  }
}

/// Warns when the same string literal appears 3 or more times in a file.
///
/// Since: v4.13.0 | Rule version: v1
///
/// Duplicate string literals are candidates for extraction to constants,
/// which improves maintainability and reduces the risk of typos.
///
/// This rule triggers at 3+ occurrences (Professional tier).
/// See also: `avoid_duplicate_string_literals_pair` for 2+ occurrences.
///
/// **Excluded strings:**
/// - Strings shorter than 4 characters
/// - Package/dart import prefixes
/// - URLs (http://, https://)
/// - Interpolation-only strings
///
/// **BAD:**
/// ```dart
/// void process() {
///   print('Loading...');
///   showMessage('Loading...');
///   log('Loading...');
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// const kLoadingMessage = 'Loading...';
///
/// void process() {
///   print(kLoadingMessage);
///   showMessage(kLoadingMessage);
///   log(kLoadingMessage);
/// }
/// ```
class AvoidDuplicateStringLiteralsRule extends SaropaLintRule {
  const AvoidDuplicateStringLiteralsRule() : super(code: _code);

  /// Style/consistency issue. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_duplicate_string_literals',
    problemMessage:
        '[avoid_duplicate_string_literals] String literal appears 3+ times in this file. Consider extracting '
        'to a constant. {v1}',
    correctionMessage:
        'Extract this string to a named constant for maintainability.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Minimum occurrences to trigger this rule
  static const int _minOccurrences = 3;

  /// Minimum string length to consider (shorter strings are often intentional)
  static const int _minLength = 4;

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Track occurrences and report when threshold is reached.
    // Note: Map state is per-file since runWithReporter is called per-file.
    final Map<String, List<AstNode>> stringOccurrences =
        <String, List<AstNode>>{};

    context.registry.addSimpleStringLiteral((SimpleStringLiteral node) {
      final String value = node.value;

      // Skip short strings
      if (value.length < _minLength) return;

      // Skip excluded patterns
      if (_shouldSkipString(value)) return;

      final List<AstNode> occurrences =
          stringOccurrences.putIfAbsent(value, () => <AstNode>[]);
      occurrences.add(node);

      // Report when we hit the threshold (report the current node)
      // and when we exceed it (each subsequent occurrence)
      if (occurrences.length >= _minOccurrences) {
        reporter.atNode(node, code);
      }
    });
  }

  bool _shouldSkipString(String value) {
    // Skip import-like strings
    if (value.startsWith('package:') || value.startsWith('dart:')) {
      return true;
    }

    // Skip URLs
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return true;
    }

    // Skip interpolation-only strings (e.g., '$foo')
    if (value.startsWith(r'$') && !value.contains(' ')) {
      return true;
    }

    // Skip file paths that look like asset paths
    if (value.startsWith('assets/') || value.startsWith('images/')) {
      return true;
    }

    return false;
  }
}

/// Warns when the same string literal appears 2 or more times in a file.
///
/// Since: v4.13.0 | Rule version: v1
///
/// This is a stricter version of `avoid_duplicate_string_literals` that
/// triggers at just 2 occurrences (Comprehensive tier).
///
/// Duplicate string literals are candidates for extraction to constants,
/// which improves maintainability and reduces the risk of typos.
///
/// **Excluded strings:**
/// - Strings shorter than 4 characters
/// - Package/dart import prefixes
/// - URLs (http://, https://)
/// - Interpolation-only strings
///
/// **BAD:**
/// ```dart
/// void process() {
///   print('Processing data...');
///   log('Processing data...');
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// const kProcessingMessage = 'Processing data...';
///
/// void process() {
///   print(kProcessingMessage);
///   log(kProcessingMessage);
/// }
/// ```
class AvoidDuplicateStringLiteralsPairRule extends SaropaLintRule {
  const AvoidDuplicateStringLiteralsPairRule() : super(code: _code);

  /// Style/consistency issue. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_duplicate_string_literals_pair',
    problemMessage:
        '[avoid_duplicate_string_literals_pair] String literal appears 2+ times in this file. Consider extracting '
        'to a constant. {v1}',
    correctionMessage:
        'Extract this string to a named constant for maintainability.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Minimum occurrences to trigger this rule
  static const int _minOccurrences = 2;

  /// Minimum string length to consider
  static const int _minLength = 4;

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Track occurrences and report when threshold is reached.
    // Note: Map state is per-file since runWithReporter is called per-file.
    final Map<String, List<AstNode>> stringOccurrences =
        <String, List<AstNode>>{};

    context.registry.addSimpleStringLiteral((SimpleStringLiteral node) {
      final String value = node.value;

      // Skip short strings
      if (value.length < _minLength) return;

      // Skip excluded patterns
      if (_shouldSkipString(value)) return;

      final List<AstNode> occurrences =
          stringOccurrences.putIfAbsent(value, () => <AstNode>[]);
      occurrences.add(node);

      // Report when we hit the threshold (report the current node)
      // and when we exceed it (each subsequent occurrence)
      if (occurrences.length >= _minOccurrences) {
        reporter.atNode(node, code);
      }
    });
  }

  bool _shouldSkipString(String value) {
    // Skip import-like strings
    if (value.startsWith('package:') || value.startsWith('dart:')) {
      return true;
    }

    // Skip URLs
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return true;
    }

    // Skip interpolation-only strings (e.g., '$foo')
    if (value.startsWith(r'$') && !value.contains(' ')) {
      return true;
    }

    // Skip file paths that look like asset paths
    if (value.startsWith('assets/') || value.startsWith('images/')) {
      return true;
    }

    return false;
  }
}

/// Suggests using typedefs for callback function types.
///
/// Since: v2.0.0 | Updated: v4.13.0 | Rule version: v2
///
/// Inline function types are harder to read and reuse.
///
/// **BAD:**
/// ```dart
/// void doAsync(void Function(String error) onError) {}
/// ```
///
/// **GOOD:**
/// ```dart
/// typedef ErrorCallback = void Function(String error);
/// void doAsync(ErrorCallback onError) {}
/// ```
class PreferTypedefsForCallbacksRule extends SaropaLintRule {
  const PreferTypedefsForCallbacksRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_typedefs_for_callbacks',
    problemMessage:
        '[prefer_typedefs_for_callbacks] Inline function type could be a typedef. Inline function types are harder to read and reuse. Suggests using typedefs for callback function types. {v2}',
    correctionMessage:
        'Create a named typedef for this callback signature and reference it by name, improving readability and allowing reuse across multiple parameters.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFormalParameterList((FormalParameterList node) {
      for (final FormalParameter param in node.parameters) {
        if (param is SimpleFormalParameter) {
          final TypeAnnotation? type = param.type;
          if (type is GenericFunctionType) {
            reporter.atNode(type, code);
          }
        }
      }
    });
  }
}

/// Suggests using redirecting constructors for super calls.
///
/// Since: v2.0.0 | Updated: v4.13.0 | Rule version: v2
///
/// Redirecting constructors are cleaner than calling super directly.
///
/// **BAD:**
/// ```dart
/// class Child extends Parent {
///   Child(String name) : super(name);
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class Child extends Parent {
///   Child(super.name);
/// }
/// ```
class PreferRedirectingSuperclassConstructorRule extends SaropaLintRule {
  const PreferRedirectingSuperclassConstructorRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_redirecting_superclass_constructor',
    problemMessage:
        '[prefer_redirecting_superclass_constructor] Constructor forwards parameters to super() without modification, which can be simplified with Dart 3 super parameters. {v2}',
    correctionMessage:
        'Replace the explicit super(paramName) call with super.paramName in the parameter list to reduce boilerplate and keep the forwarding relationship visible in the signature.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addConstructorDeclaration((ConstructorDeclaration node) {
      final NodeList<ConstructorInitializer> initializers = node.initializers;
      if (initializers.isEmpty) return;

      for (final ConstructorInitializer init in initializers) {
        if (init is SuperConstructorInvocation) {
          // Check if super call has simple parameter forwarding
          final ArgumentList args = init.argumentList;
          for (final Expression arg in args.arguments) {
            if (arg is SimpleIdentifier) {
              // Check if the identifier matches a constructor parameter
              final FormalParameterList? params = node.parameters;
              if (params != null) {
                for (final FormalParameter param in params.parameters) {
                  if (param.name?.lexeme == arg.name) {
                    reporter.atNode(init, code);
                    return;
                  }
                }
              }
            }
          }
        }
      }
    });
  }
}

/// Warns when buildWhen callback is empty or always returns true.
///
/// Since: v2.0.0 | Updated: v4.13.0 | Rule version: v2
///
/// Empty buildWhen defeats the purpose of BlocBuilder optimization.
///
/// **BAD:**
/// ```dart
/// BlocBuilder<MyBloc, MyState>(
///   buildWhen: (previous, current) => true, // Always rebuilds
///   builder: (context, state) => Text('$state'),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// BlocBuilder<MyBloc, MyState>(
///   buildWhen: (previous, current) => previous.value != current.value,
///   builder: (context, state) => Text('${state.value}'),
/// )
/// ```
class AvoidEmptyBuildWhenRule extends SaropaLintRule {
  const AvoidEmptyBuildWhenRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_empty_build_when',
    problemMessage:
        '[avoid_empty_build_when] buildWhen callback always returns true, which is the default behavior. The callback adds code without filtering any rebuilds, defeating the purpose of the optimization that buildWhen provides in BlocBuilder and BlocListener. {v2}',
    correctionMessage:
        'Add a meaningful state comparison that returns false for states that do not require a rebuild, or remove buildWhen entirely to use the default behavior.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String? typeName = node.constructorName.type.element?.name;
      if (typeName != 'BlocBuilder' && typeName != 'BlocConsumer') return;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'buildWhen') {
          final Expression expr = arg.expression;
          if (expr is FunctionExpression) {
            final FunctionBody body = expr.body;
            // Check for => true
            if (body is ExpressionFunctionBody) {
              final Expression returnExpr = body.expression;
              if (returnExpr is BooleanLiteral && returnExpr.value) {
                reporter.atNode(arg, code);
              }
            }
            // Check for { return true; }
            else if (body is BlockFunctionBody) {
              final List<Statement> statements = body.block.statements;
              if (statements.length == 1 &&
                  statements.first is ReturnStatement) {
                final Expression? returnExpr =
                    (statements.first as ReturnStatement).expression;
                if (returnExpr is BooleanLiteral && returnExpr.value) {
                  reporter.atNode(arg, code);
                }
              }
            }
          }
        }
      }
    });
  }
}

/// Suggests using 'use' prefix for custom hooks.
///
/// Since: v2.0.0 | Updated: v4.13.0 | Rule version: v2
///
/// **Stylistic rule (opt-in only).** No performance or correctness benefit.
///
/// Flutter Hooks convention requires hooks to start with 'use'.
///
/// **BAD:**
/// ```dart
/// T myHook<T>() => useHook(); // Missing use prefix
/// ```
///
/// **GOOD:**
/// ```dart
/// T useMyHook<T>() => useHook();
/// ```
class PreferUsePrefixRule extends SaropaLintRule {
  const PreferUsePrefixRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_use_prefix',
    problemMessage:
        '[prefer_use_prefix] Prefixing Flutter Hooks function names with use is a naming convention. The prefix does not affect hook behavior or performance. Enable via the stylistic tier. {v2}',
    correctionMessage:
        'Rename the function to start with "use" (e.g. useMyHook) following the hooks convention, so it is recognizable as a hook and subject to hook linting rules.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _hookMethods = <String>{
    'useState',
    'useEffect',
    'useMemoized',
    'useCallback',
    'useRef',
    'useContext',
    'useValueListenable',
    'useAnimation',
    'useAnimationController',
    'useFuture',
    'useStream',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
      final String name = node.name.lexeme;

      // Skip if already has hook prefix (use + PascalCase)
      if (_isHookFunction(name)) return;

      // Check if body calls hook methods
      bool usesHooks = false;
      node.functionExpression.body.visitChildren(_HookCallVisitor(
        hookMethods: _hookMethods,
        onHookFound: () => usesHooks = true,
      ));

      if (usesHooks) {
        reporter.atNode(node, code);
      }
    });
  }
}

class _HookCallVisitor extends RecursiveAstVisitor<void> {
  _HookCallVisitor({required this.hookMethods, required this.onHookFound});

  final Set<String> hookMethods;
  final void Function() onHookFound;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final String methodName = node.methodName.name;
    // Check known hooks or any use + PascalCase pattern
    if (hookMethods.contains(methodName) || _isHookFunction(methodName)) {
      onHookFound();
    }
    super.visitMethodInvocation(node);
  }
}

/// Warns when a late mutable variable could be late final.
///
/// Since: v2.3.7 | Updated: v4.13.0 | Rule version: v3
///
/// When a late variable is only assigned once, it should be declared as
/// `late final` to prevent accidental reassignment and signal intent.
///
/// **BAD:**
/// ```dart
/// class MyService {
///   late Database _db; // Mutable, but only set once
///
///   void init() {
///     _db = Database.open();
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyService {
///   late final Database _db;
///
///   void init() {
///     _db = Database.open();
///   }
/// }
/// ```
class PreferLateFinalRule extends SaropaLintRule {
  const PreferLateFinalRule() : super(code: _code);

  /// Code quality improvement - prevents accidental mutation.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_late_final',
    problemMessage:
        '[prefer_late_final] Late variable is never reassigned after its initial assignment, so it can be declared as late final for stronger immutability guarantees. {v3}',
    correctionMessage:
        'Change late to late final so that any accidental reassignment is caught at compile time, preventing unintended state mutations.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Find late non-final fields
      final List<_LateFinalFieldInfo> lateFields = <_LateFinalFieldInfo>[];

      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          final VariableDeclarationList fields = member.fields;
          if (fields.lateKeyword != null && !fields.isFinal) {
            for (final VariableDeclaration variable in fields.variables) {
              lateFields.add(_LateFinalFieldInfo(
                name: variable.name.lexeme,
                declaration: variable,
                field: member,
              ));
            }
          }
        }
      }

      if (lateFields.isEmpty) return;

      // Count assignments to each late field
      // Include inline initializers as the first assignment
      final Map<String, int> assignmentCounts = <String, int>{};
      for (final _LateFinalFieldInfo field in lateFields) {
        // If field has inline initializer, count starts at 1
        final bool hasInitializer = field.declaration.initializer != null;
        assignmentCounts[field.name] = hasInitializer ? 1 : 0;
      }

      // Track which methods assign to which fields, so we can check
      // if those methods are called from multiple sites
      final Map<String, Set<String>> methodFieldAssignments =
          <String, Set<String>>{};

      // Visit all methods to count assignments
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration) {
          final _LateFinalAssignmentCounterVisitor visitor =
              _LateFinalAssignmentCounterVisitor(assignmentCounts);
          member.body.visitChildren(visitor);

          if (visitor.assignedFields.isNotEmpty) {
            methodFieldAssignments[member.name.lexeme] = visitor.assignedFields;
          }
        }
        if (member is ConstructorDeclaration) {
          if (member.body is BlockFunctionBody) {
            member.body.visitChildren(
              _LateFinalAssignmentCounterVisitor(assignmentCounts),
            );
          }
          // Count initializer list assignments
          for (final ConstructorInitializer initializer
              in member.initializers) {
            if (initializer is ConstructorFieldInitializer) {
              final String fieldName = initializer.fieldName.name;
              if (assignmentCounts.containsKey(fieldName)) {
                assignmentCounts[fieldName] = assignmentCounts[fieldName]! + 1;
              }
            }
          }
        }
      }

      // Adjust counts for methods called from multiple sites.
      // A single assignment in a method called N times means the field
      // is effectively assigned N times at runtime.
      _adjustForMethodCallSites(
        node,
        methodFieldAssignments,
        assignmentCounts,
      );

      // Report fields that are assigned exactly once
      // Skip never-assigned fields (count == 0) - those are bugs, not candidates
      for (final _LateFinalFieldInfo field in lateFields) {
        final int count = assignmentCounts[field.name]!;
        if (count == 1) {
          reporter.atNode(field.declaration, code);
        }
      }
    });
  }

  /// Counts how many times each assigning method is called within the class.
  /// If a method that assigns to a late field is called from N > 1 sites,
  /// adds (N - 1) to the field's assignment count since the AST visitor
  /// already counted the assignment node once.
  static void _adjustForMethodCallSites(
    ClassDeclaration node,
    Map<String, Set<String>> methodFieldAssignments,
    Map<String, int> assignmentCounts,
  ) {
    if (methodFieldAssignments.isEmpty) return;

    final Map<String, int> methodCallCounts = <String, int>{
      for (final String name in methodFieldAssignments.keys) name: 0,
    };

    final _LateFinalMethodCallCounterVisitor callVisitor =
        _LateFinalMethodCallCounterVisitor(methodCallCounts);

    for (final ClassMember member in node.members) {
      if (member is MethodDeclaration) {
        member.body.visitChildren(callVisitor);
      }
      if (member is ConstructorDeclaration &&
          member.body is BlockFunctionBody) {
        member.body.visitChildren(callVisitor);
      }
    }

    for (final MapEntry<String, Set<String>> entry
        in methodFieldAssignments.entries) {
      final int callCount = methodCallCounts[entry.key] ?? 0;
      if (callCount > 1) {
        for (final String fieldName in entry.value) {
          assignmentCounts[fieldName] =
              assignmentCounts[fieldName]! + (callCount - 1);
        }
      }
    }
  }
}

class _LateFinalFieldInfo {
  const _LateFinalFieldInfo({
    required this.name,
    required this.declaration,
    required this.field,
  });

  final String name;
  final VariableDeclaration declaration;
  final FieldDeclaration field;
}

class _LateFinalAssignmentCounterVisitor extends RecursiveAstVisitor<void> {
  _LateFinalAssignmentCounterVisitor(this.counts);

  final Map<String, int> counts;

  /// Fields that were assigned in the visited scope.
  final Set<String> assignedFields = <String>{};

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    final Expression left = node.leftHandSide;
    String? fieldName;

    if (left is SimpleIdentifier) {
      fieldName = left.name;
    } else if (left is PrefixedIdentifier) {
      // this._field or _prefix._field
      if (left.prefix.name == 'this') {
        fieldName = left.identifier.name;
      }
    } else if (left is PropertyAccess) {
      final Expression? target = left.target;
      if (target is ThisExpression) {
        fieldName = left.propertyName.name;
      }
    }

    if (fieldName != null && counts.containsKey(fieldName)) {
      counts[fieldName] = counts[fieldName]! + 1;
      assignedFields.add(fieldName);
    }

    super.visitAssignmentExpression(node);
  }
}

/// Counts calls to specific methods within a class body.
///
/// Used by [PreferLateFinalRule] to detect when a method that assigns
/// to a late field is called from multiple sites, making the field
/// effectively reassigned at runtime.
class _LateFinalMethodCallCounterVisitor extends RecursiveAstVisitor<void> {
  _LateFinalMethodCallCounterVisitor(this.counts);

  final Map<String, int> counts;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final String methodName = node.methodName.name;
    if (counts.containsKey(methodName)) {
      final Expression? target = node.target;
      // Only count calls on this instance (implicit or explicit this)
      if (target == null || target is ThisExpression) {
        counts[methodName] = counts[methodName]! + 1;
      }
    }

    super.visitMethodInvocation(node);
  }
}

/// Returns true if the declaration is `late final` with all variables having
/// inline initializers. Such fields use lazy evaluation and cannot throw
/// [LateInitializationError] — the initializer runs on first access.
bool _allVariablesHaveInitializers(VariableDeclarationList fields) {
  if (!fields.isFinal) return false;
  return fields.variables.every(
    (VariableDeclaration v) => v.initializer != null,
  );
}

/// Warns when late is used for a value that could simply be nullable.
///
/// Since: v2.3.7 | Updated: v4.13.0 | Rule version: v4
///
/// Using `late` for optional values that might not be initialized is risky.
/// A nullable type with null checks is safer and more explicit.
///
/// Exempts `late final` fields with inline initializers, where `late`
/// provides lazy evaluation rather than deferred assignment.
///
/// **BAD:**
/// ```dart
/// class UserProfile {
///   late String? avatarUrl; // late for nullable is redundant
///   late User user; // Might never be set - crash risk
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class UserProfile {
///   String? avatarUrl; // Simply nullable
///   User? user; // Null-safe access
///   late final Stream<bool>? stream = _init(); // OK: lazy evaluation
/// }
/// ```
class AvoidLateForNullableRule extends SaropaLintRule {
  const AvoidLateForNullableRule() : super(code: _code);

  /// Crash path - accessing before assignment throws LateInitializationError.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_late_for_nullable',
    problemMessage:
        '[avoid_late_for_nullable] Nullable type declared with late keyword. Since the type already accepts null, the late keyword adds no initialization safety and instead introduces a hidden crash path: accessing the variable before assignment throws LateInitializationError rather than returning null. {v4}',
    correctionMessage:
        'Remove the late keyword and rely on the nullable type (T?) with null checks. The variable will default to null until explicitly assigned, which is safer and more predictable.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFieldDeclaration((FieldDeclaration node) {
      final VariableDeclarationList fields = node.fields;
      if (fields.lateKeyword == null) return;

      // Exempt: late final with inline initializer — late provides lazy
      // evaluation, not deferred assignment. No LateInitializationError risk.
      if (_allVariablesHaveInitializers(fields)) return;

      // Check if type is nullable
      final TypeAnnotation? typeAnnotation = fields.type;
      if (typeAnnotation == null) return;

      // Check outer type nullability via AST question token
      if (isOuterTypeNullable(typeAnnotation)) {
        reporter.atNode(node, code);
      }
    });

    context.registry.addVariableDeclarationStatement((node) {
      final VariableDeclarationList variables = node.variables;
      if (variables.lateKeyword == null) return;

      // Exempt: late final with inline initializer
      if (_allVariablesHaveInitializers(variables)) return;

      final TypeAnnotation? typeAnnotation = variables.type;
      if (typeAnnotation == null) return;

      // Check outer type nullability via AST question token
      if (isOuterTypeNullable(typeAnnotation)) {
        for (final VariableDeclaration variable in variables.variables) {
          reporter.atNode(variable, code);
        }
      }
    });
  }
}

/// Checks if a method name follows the Flutter hooks naming convention.
///
/// Flutter hooks use the pattern `use` + PascalCase identifier:
/// - `useState`, `useEffect`, `useCallback` ✓
/// - `userDOB`, `usefulHelper`, `username` ✗
bool _isHookFunction(String name) {
  // Must start with 'use' and have at least one more character
  if (!name.startsWith('use')) return false;
  if (name.length < 4) return false;

  // The character after 'use' must be uppercase (PascalCase convention)
  // This distinguishes useState from userDOB
  final charAfterUse = name[3];
  return charAfterUse == charAfterUse.toUpperCase() &&
      charAfterUse != charAfterUse.toLowerCase();
}

/// Warns when enum value could use Dart 3 dot shorthand.
///
/// Since: v2.1.0 | Updated: v4.13.0 | Rule version: v2
///
/// Dart 3 allows `.value` syntax when enum type can be inferred.
/// This makes code more concise without losing clarity.
///
/// **BAD:**
/// ```dart
/// TextAlign align = TextAlign.center;
/// ```
///
/// **GOOD:**
/// ```dart
/// TextAlign align = .center;
/// ```
///
/// **Note:** This is a stylistic preference. Some teams prefer explicit
/// enum names for clarity.
class PreferDotShorthandRule extends SaropaLintRule {
  const PreferDotShorthandRule() : super(code: _code);

  /// Code style preference.
  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_dot_shorthand',
    problemMessage:
        '[prefer_dot_shorthand] Fully qualified enum reference detected where the type is already known from context. Use dot shorthand (.value) available in Dart 3 to reduce verbosity while preserving type safety. {v2}',
    correctionMessage:
        'Replace the fully qualified EnumType.value with .value where the type is already known from context, reducing verbosity while keeping the code type-safe.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addPrefixedIdentifier((node) {
      // Check if prefix is an enum type accessing a value
      final prefix = node.prefix;

      // Get the static type of the prefix
      final prefixType = prefix.staticType;
      if (prefixType == null) {
        return;
      }

      // Check if it's an enum
      final element = prefixType.element;
      if (element is! EnumElement) {
        return;
      }

      // Check if this is in an assignment or argument where type is known
      final parent = node.parent;
      if (parent is VariableDeclaration) {
        final declaredType = parent.parent;
        if (declaredType is VariableDeclarationList &&
            declaredType.type != null) {
          // Type is explicit, shorthand could be used
          reporter.atNode(node, code);
        }
      } else if (parent is NamedExpression) {
        // In named parameter, type is known from function signature
        reporter.atNode(node, code);
      } else if (parent is AssignmentExpression &&
          parent.rightHandSide == node) {
        // Assignment to typed variable
        reporter.atNode(node, code);
      }
    });
  }
}

// =============================================================================
// ROADMAP_NEXT: Phase 2 - Core Code Quality Rules
// =============================================================================

/// Warns when comparing boolean expressions to boolean literals.
///
/// Since: v2.5.0 | Updated: v4.13.0 | Rule version: v3
///
/// **Stylistic rule (opt-in only).** No performance or correctness benefit.
///
/// Alias: boolean_literal_compare, unnecessary_bool_compare, redundant_bool_literal
///
/// Comparing a boolean expression to `true` or `false` is redundant and
/// makes code harder to read. Use the expression directly or negate it.
///
/// **BAD:**
/// ```dart
/// if (isEnabled == true) { }
/// if (isEnabled == false) { }
/// if (true == isEnabled) { }
/// if (isEnabled != false) { }
/// ```
///
/// **GOOD:**
/// ```dart
/// if (isEnabled) { }
/// if (!isEnabled) { }
/// ```
///
/// **Quick fix available:** Simplifies to direct boolean expression.
class NoBooleanLiteralCompareRule extends SaropaLintRule {
  const NoBooleanLiteralCompareRule() : super(code: _code);

  /// Code style improvement.
  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'no_boolean_literal_compare',
    problemMessage:
        '[no_boolean_literal_compare] Comparing a boolean to true/false literally (x == true) instead of using the value directly (x) is a stylistic choice with no correctness or performance impact. Enable via the stylistic tier. {v3}',
    correctionMessage:
        'Use the boolean expression directly: write x instead of x == true, and !x instead of x == false. '
        '!x instead of x == false.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addBinaryExpression((BinaryExpression node) {
      // Only check == and != operators
      final operatorType = node.operator.type;
      if (operatorType != TokenType.EQ_EQ &&
          operatorType != TokenType.BANG_EQ) {
        return;
      }

      final left = node.leftOperand;
      final right = node.rightOperand;

      // Check if either operand is a boolean literal
      final leftIsBoolLiteral = left is BooleanLiteral;
      final rightIsBoolLiteral = right is BooleanLiteral;

      if (!leftIsBoolLiteral && !rightIsBoolLiteral) {
        return;
      }

      // Check if the other operand is a boolean type (to avoid false positives
      // on nullable booleans where == true is intentional)
      final Expression otherOperand = leftIsBoolLiteral ? right : left;
      final otherType = otherOperand.staticType;

      // Only flag if the other operand is non-nullable bool
      if (otherType != null && otherType.isDartCoreBool) {
        // Check nullability - allow == true/false for nullable bools
        if (otherType.nullabilitySuffix == NullabilitySuffix.none) {
          reporter.atNode(node, code);
        }
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_SimplifyBooleanComparisonFix()];
}

/// Quick fix: Simplifies boolean literal comparisons.
class _SimplifyBooleanComparisonFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addBinaryExpression((BinaryExpression node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final operatorType = node.operator.type;
      final left = node.leftOperand;
      final right = node.rightOperand;

      final leftIsBoolLiteral = left is BooleanLiteral;
      final rightIsBoolLiteral = right is BooleanLiteral;

      if (!leftIsBoolLiteral && !rightIsBoolLiteral) return;

      final BooleanLiteral boolLiteral =
          leftIsBoolLiteral ? left : right as BooleanLiteral;
      final Expression otherExpr = leftIsBoolLiteral ? right : left;

      // Determine the replacement
      String replacement;
      final bool comparingToTrue = boolLiteral.value;
      final bool isEquality = operatorType == TokenType.EQ_EQ;

      // Truth table:
      // x == true  -> x
      // x == false -> !x
      // x != true  -> !x
      // x != false -> x
      final bool needsNegation = comparingToTrue != isEquality;

      if (needsNegation) {
        // Check if we need parentheses
        final exprSource = otherExpr.toSource();
        if (_needsParentheses(otherExpr)) {
          replacement = '!($exprSource)';
        } else {
          replacement = '!$exprSource';
        }
      } else {
        replacement = otherExpr.toSource();
      }

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Simplify to: $replacement',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(node.sourceRange, replacement);
      });
    });
  }

  /// Check if expression needs parentheses when negated.
  bool _needsParentheses(Expression expr) {
    return expr is BinaryExpression ||
        expr is ConditionalExpression ||
        expr is AsExpression ||
        expr is IsExpression;
  }
}

// =============================================================================
// prefer_returning_conditional_expressions
// =============================================================================

/// Return conditional expressions directly instead of if/else blocks.
///
/// Since: v2.6.0 | Updated: v4.13.0 | Rule version: v2
///
/// **Stylistic rule (opt-in only).** No performance or correctness benefit.
///
/// When an if/else block simply returns different values, use a ternary
/// expression or direct return for cleaner, more readable code.
///
/// **BAD:**
/// ```dart
/// if (condition) {
///   return true;
/// } else {
///   return false;
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// return condition;
/// // or
/// return condition ? valueA : valueB;
/// ```
///
/// **Quick fix available:** Transforms if/else to ternary expression.
class PreferReturningConditionalExpressionsRule extends SaropaLintRule {
  const PreferReturningConditionalExpressionsRule() : super(code: _code);

  /// Code quality improvement. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_returning_conditional_expressions',
    problemMessage:
        '[prefer_returning_conditional_expressions] Returning a ternary expression instead of if-else is a stylistic preference. Both compile to the same code with no performance difference. Enable via the stylistic tier. {v2}',
    correctionMessage:
        'Collapse to return condition ? valueA : valueB; for value returns, or return condition; when directly returning a boolean expression.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addIfStatement((IfStatement node) {
      // Must have else branch
      final Statement? elseStatement = node.elseStatement;
      if (elseStatement == null) return;

      // Check if then branch is single return
      final Statement thenStatement = node.thenStatement;
      final ReturnStatement? thenReturn = _getSingleReturn(thenStatement);
      if (thenReturn == null) return;

      // Check if else branch is single return (not else-if)
      if (elseStatement is IfStatement) return;
      final ReturnStatement? elseReturn = _getSingleReturn(elseStatement);
      if (elseReturn == null) return;

      // Both branches are single returns - report
      reporter.atNode(node, code);
    });
  }

  /// Extract single return statement from a block or bare statement.
  ReturnStatement? _getSingleReturn(Statement statement) {
    if (statement is ReturnStatement) return statement;
    if (statement is Block) {
      final statements = statement.statements;
      if (statements.length == 1 && statements.first is ReturnStatement) {
        return statements.first as ReturnStatement;
      }
    }
    return null;
  }

  @override
  List<Fix> getFixes() => <Fix>[_PreferReturningConditionalExpressionsFix()];
}

class _PreferReturningConditionalExpressionsFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addIfStatement((IfStatement node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final Statement? elseStatement = node.elseStatement;
      if (elseStatement == null) return;

      final ReturnStatement? thenReturn = _getSingleReturn(node.thenStatement);
      final ReturnStatement? elseReturn = _getSingleReturn(elseStatement);
      if (thenReturn == null || elseReturn == null) return;

      final Expression? thenValue = thenReturn.expression;
      final Expression? elseValue = elseReturn.expression;
      if (thenValue == null || elseValue == null) return;

      final String condition = node.expression.toSource();
      final String thenSource = thenValue.toSource();
      final String elseSource = elseValue.toSource();

      String replacement;

      // Check for boolean literal returns
      if (thenValue is BooleanLiteral && elseValue is BooleanLiteral) {
        if (thenValue.value && !elseValue.value) {
          // return true else return false -> return condition
          replacement = 'return $condition;';
        } else if (!thenValue.value && elseValue.value) {
          // return false else return true -> return !condition
          replacement = 'return !($condition);';
        } else {
          // Both same value - just use ternary
          replacement = 'return $condition ? $thenSource : $elseSource;';
        }
      } else {
        // General case: use ternary
        replacement = 'return $condition ? $thenSource : $elseSource;';
      }

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Convert to conditional expression',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(node.sourceRange, replacement);
      });
    });
  }

  ReturnStatement? _getSingleReturn(Statement statement) {
    if (statement is ReturnStatement) return statement;
    if (statement is Block) {
      final statements = statement.statements;
      if (statements.length == 1 && statements.first is ReturnStatement) {
        return statements.first as ReturnStatement;
      }
    }
    return null;
  }
}

/// Warns when `// ignore:` or `// ignore_for_file:` has a trailing `//`
///
/// Since: v4.9.5 | Updated: v4.13.0 | Rule version: v2
///
/// comment after the rule names.
///
/// The `custom_lint_builder` framework parses everything after the colon as
/// rule names (splitting on commas and trimming). A trailing comment causes
/// the last rule name to include the comment text, so the framework's
/// `codes.contains('rule_name')` check silently fails.
///
/// **BAD:**
/// ```dart
/// // ignore_for_file: my_rule // reason why we ignore
/// // ignore: my_rule // no web support needed
/// ```
///
/// **GOOD:**
/// ```dart
/// // reason why we ignore
/// // ignore_for_file: my_rule
/// // no web support needed
/// // ignore: my_rule
/// ```
class AvoidIgnoreTrailingCommentRule extends SaropaLintRule {
  const AvoidIgnoreTrailingCommentRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_ignore_trailing_comment',
    problemMessage: '[avoid_ignore_trailing_comment] '
        'Trailing comment breaks ignore suppression. {v2}',
    correctionMessage:
        'Move the comment to the line above the ignore directive.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCompilationUnit((CompilationUnit unit) {
      Token? token = unit.beginToken;

      while (token != null && !token.isEof) {
        Token? comment = token.precedingComments;
        while (comment != null) {
          if (_hasTrailingComment(comment.lexeme)) {
            reporter.atOffset(
              offset: comment.offset,
              length: comment.length,
              errorCode: code,
            );
          }
          comment = comment.next;
        }
        token = token.next;
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_MoveTrailingCommentFix()];

  static bool _hasTrailingComment(String lexeme) {
    return IgnoreUtils.trailingCommentOnIgnore.hasMatch(lexeme);
  }

  /// Splits a comment like `// ignore: rule // reason` or
  /// `// ignore: rule - reason` into the directive and trailing parts.
  ///
  /// The trailing part is always normalized to a `// ` comment.
  /// Returns `null` if no trailing comment or separator is found.
  static ({String directive, String trailing})? splitParts(String lexeme) {
    final colonIndex = lexeme.indexOf(':');
    if (colonIndex < 0) return null;

    final afterColon = lexeme.substring(colonIndex + 1);

    // Check for trailing // comment first (higher priority)
    final trailingSlashIndex = afterColon.indexOf('//');
    if (trailingSlashIndex >= 0) {
      final directive =
          lexeme.substring(0, colonIndex + 1 + trailingSlashIndex).trimRight();
      final trailing = afterColon.substring(trailingSlashIndex).trim();
      return (directive: directive, trailing: trailing);
    }

    // Check for trailing - separator (space-hyphen-space)
    final dashMatch = RegExp(r'\s+-\s+').firstMatch(afterColon);
    if (dashMatch != null) {
      final directive =
          lexeme.substring(0, colonIndex + 1 + dashMatch.start).trimRight();
      final text = afterColon.substring(dashMatch.end).trim();
      if (text.isEmpty) return null;
      return (directive: directive, trailing: '// $text');
    }

    return null;
  }
}

class _MoveTrailingCommentFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addCompilationUnit((CompilationUnit unit) {
      Token? token = unit.beginToken;

      while (token != null && !token.isEof) {
        Token? comment = token.precedingComments;
        while (comment != null) {
          if (comment.offset == analysisError.offset) {
            _applyFix(comment, analysisError, reporter);
            return;
          }
          comment = comment.next;
        }
        token = token.next;
      }
    });
  }

  void _applyFix(
    Token comment,
    AnalysisError error,
    ChangeReporter reporter,
  ) {
    final parts = AvoidIgnoreTrailingCommentRule.splitParts(
      comment.lexeme,
    );
    if (parts == null) return;

    final replacement = '${parts.trailing}\n${parts.directive}';

    final changeBuilder = reporter.createChangeBuilder(
      message: 'Move comment above directive',
      priority: 80,
    );

    changeBuilder.addDartFileEdit((builder) {
      builder.addSimpleReplacement(error.sourceRange, replacement);
    });
  }
}

// =============================================================================
// Missing Interpolation Rules
// =============================================================================

/// Warns when string concatenation with + is used where string interpolation
///
/// Since: v4.12.0 | Updated: v4.13.0 | Rule version: v2
///
/// would be clearer.
///
/// String interpolation is more readable, less error-prone, and performs
/// better than concatenation with the + operator. Concatenation also makes
/// it easy to forget spaces between segments.
///
/// **BAD:**
/// ```dart
/// final greeting = 'Hello, ' + name + '!';
/// final path = baseUrl + '/api/' + endpoint;
/// ```
///
/// **GOOD:**
/// ```dart
/// final greeting = 'Hello, $name!';
/// final path = '$baseUrl/api/$endpoint';
/// ```
class AvoidMissingInterpolationRule extends SaropaLintRule {
  const AvoidMissingInterpolationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_missing_interpolation',
    problemMessage:
        '[avoid_missing_interpolation] String concatenation using the + operator combines a string literal with a variable or expression. String interpolation (\$variable or \${expression}) is the idiomatic Dart approach that is more readable, less error-prone (no accidental space omission between segments), and avoids creating intermediate String objects for each + operation, improving both clarity and performance in concatenation-heavy code paths.',
    correctionMessage:
        'Replace string concatenation with string interpolation using \$variable or \${expression} syntax for cleaner, more idiomatic Dart code.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addBinaryExpression((BinaryExpression node) {
      if (node.operator.type != TokenType.PLUS) return;

      final leftType = node.leftOperand.staticType;
      final rightType = node.rightOperand.staticType;

      // At least one side must be a String
      final bool leftIsString = leftType?.isDartCoreString ?? false;
      final bool rightIsString = rightType?.isDartCoreString ?? false;
      if (!leftIsString && !rightIsString) return;

      // At least one side must be a string literal
      final bool leftIsLiteral = node.leftOperand is StringLiteral;
      final bool rightIsLiteral = node.rightOperand is StringLiteral;
      if (!leftIsLiteral && !rightIsLiteral) return;

      // Skip if this is a child of another + expression (report only root)
      final AstNode? parent = node.parent;
      if (parent is BinaryExpression &&
          parent.operator.type == TokenType.PLUS) {
        final parentLeftType = parent.leftOperand.staticType;
        final parentRightType = parent.rightOperand.staticType;
        if ((parentLeftType?.isDartCoreString ?? false) ||
            (parentRightType?.isDartCoreString ?? false)) {
          return;
        }
      }

      reporter.atNode(node, code);
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_UseStringInterpolationFix()];
}

class _UseStringInterpolationFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addBinaryExpression((BinaryExpression node) {
      if (!analysisError.sourceRange.intersects(node.sourceRange)) return;
      if (node.operator.type != TokenType.PLUS) return;

      final changeBuilder = reporter.createChangeBuilder(
        message: 'Convert to string interpolation',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '/* TODO: use string interpolation instead of + concatenation */ ',
        );
      });
    });
  }
}
