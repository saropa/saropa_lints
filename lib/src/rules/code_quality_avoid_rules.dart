// ignore_for_file: depend_on_referenced_packages, deprecated_member_use, always_specify_types

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import '../analyzer_metadata_compat_utils.dart';
import '../banned_usage_config.dart' as banned_usage_config;
import '../fixes/code_quality/avoid_substring_todo_fix.dart';
import '../fixes/code_quality/delete_unknown_pragma_fix.dart';
import '../fixes/code_quality/prefix_unused_parameter_fix.dart';
import '../fixes/code_quality/remove_inferrable_type_arguments_fix.dart';
import '../fixes/code_quality/remove_redundant_pragma_inline_fix.dart';
import '../fixes/code_quality/remove_unnecessary_override_fix.dart';
import '../fixes/code_quality/remove_unnecessary_statement_fix.dart';
import '../fixes/code_quality/replace_weak_crypto_fix.dart';
import '../saropa_lint_rule.dart';

class AvoidAdjacentStringsRule extends SaropaLintRule {
  AvoidAdjacentStringsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_adjacent_strings',
    '[avoid_adjacent_strings] Adjacent string literals detected without an explicit concatenation operator. Dart implicitly joins adjacent strings, which can mask accidental line breaks or missing commas in list literals, leading to silently merged values that are difficult to debug. {v4}',
    correctionMessage:
        'Combine into a single string literal, use the + operator for explicit concatenation, or use string interpolation to make the intent clear.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addAdjacentStrings((AdjacentStrings node) {
      reporter.atNode(node);
    });
  }
}

/// Warns when accessing enum values by index (`EnumName.values[i]`).
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
class AvoidEnumValuesByIndexRule extends SaropaLintRule {
  AvoidEnumValuesByIndexRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_enum_values_by_index',
    '[avoid_enum_values_by_index] Enum value accessed by numeric index on the .values list. If enum members are reordered or new values are inserted, the index silently resolves to the wrong constant, causing incorrect behavior that the compiler cannot catch. {v4}',
    correctionMessage:
        'Use EnumName.values.byName() for string-based lookup, or switch on specific enum values to get compile-time exhaustiveness checking.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addIndexExpression((IndexExpression node) {
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
          reporter.atNode(node);
        }
      } else if (enumTarget is PrefixedIdentifier) {
        final String name = enumTarget.identifier.name;
        if (name.isNotEmpty &&
            name[0] == name[0].toUpperCase() &&
            !name.startsWith('_')) {
          reporter.atNode(node);
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
  AvoidIncorrectUriRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_incorrect_uri',
    '[avoid_incorrect_uri] URI string appears to be malformed or contains invalid characters. Malformed URIs cause runtime exceptions when parsed by Uri.parse(), leading to unhandled errors in network requests, routing logic, or deep link handling. {v4}',
    correctionMessage:
        'Verify the URI syntax matches RFC 3986, ensure special characters are percent-encoded, and test with Uri.parse() to confirm validity.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
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
        reporter.atNode(firstArg);
      }
    });

    context.addInstanceCreationExpression((InstanceCreationExpression node) {
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
  AvoidLateKeywordRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_late_keyword',
    "[avoid_late_keyword] Field declared with the 'late' keyword defers initialization checking to runtime. If the field is accessed before assignment, Dart throws a LateInitializationError that crashes the app, bypassing the null safety guarantees the type system provides at compile time. {v7}",
    correctionMessage:
        'Use a nullable type with a null check, provide a default value, or initialize the field in the constructor to keep initialization errors visible at compile time.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addVariableDeclaration((VariableDeclaration node) {
      final AstNode? parent = node.parent;
      if (parent is VariableDeclarationList && parent.lateKeyword != null) {
        reporter.atNode(node);
      }
    });

    context.addFieldDeclaration((FieldDeclaration node) {
      if (node.fields.lateKeyword != null) {
        reporter.atNode(node);
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
  AvoidMissedCallsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_missed_calls',
    '[avoid_missed_calls] Function reference passed without parentheses where a call was likely intended. Without the () invocation, the function is not executed and the reference is silently discarded, meaning the intended side effect or return value is lost. {v5}',
    correctionMessage:
        'Add parentheses () to invoke the function, or if the reference is intentional, assign it to a variable with an explicit function type.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
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
          reporter.atNode(firstArg);
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
  AvoidMisusedSetLiteralsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.high;

  static const LintCode _code = LintCode(
    'avoid_misused_set_literals',
    '[avoid_misused_set_literals] Set literal may be misused. '
        'Empty `{}` without type annotation creates a Map, not a Set. {v2}',
    correctionMessage:
        'Add explicit type annotation: `<Type>{}` for Set '
        'or `<K, V>{}` for Map.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addSetOrMapLiteral((SetOrMapLiteral node) {
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
        reporter.atNode(node);
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
  AvoidPassingSelfAsArgumentRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_passing_self_as_argument',
    '[avoid_passing_self_as_argument] Object passed as an argument to its own method, creating a self-referential call. This pattern often indicates a logic error and can lead to infinite recursion, stack overflow, or unexpected mutation of the object state during method execution. {v4}',
    correctionMessage:
        'Extract the shared logic into a separate method, pass a different object, or restructure the call to eliminate the self-reference.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final Expression? target = node.target;
      if (target == null) return;

      // Skip literals - they are values, not object references that could
      // cause circular reference issues (e.g., 0.isBetween(0, 10) is fine)
      if (target is Literal) return;

      final String targetSource = target.toSource();

      // Check if any argument matches the target
      for (final Expression arg in node.argumentList.arguments) {
        final Expression actualArg = arg is NamedExpression
            ? arg.expression
            : arg;
        if (actualArg.toSource() == targetSource) {
          reporter.atNode(actualArg);
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
  AvoidRecursiveCallsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_recursive_calls',
    '[avoid_recursive_calls] Function contains a direct recursive call to itself. Without a guaranteed base case or depth limit, unbounded recursion exhausts the call stack and crashes the application with a StackOverflowError, which cannot be caught in Dart. {v5}',
    correctionMessage:
        'Verify a terminating base case exists for all input paths, or convert the recursion to an iterative approach using a loop or explicit stack.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addFunctionDeclaration((FunctionDeclaration node) {
      final String functionName = node.name.lexeme;
      final FunctionBody body = node.functionExpression.body;

      _checkBodyForRecursion(body, functionName, reporter);
    });

    context.addMethodDeclaration((MethodDeclaration node) {
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
    final _RecursiveCallVisitor visitor = _RecursiveCallVisitor(
      functionName,
      reporter,
      code,
    );
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
      reporter.atNode(node);
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    final Expression function = node.function;
    if (function is SimpleIdentifier && function.name == functionName) {
      reporter.atNode(node);
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
  AvoidRecursiveToStringRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_recursive_tostring',
    '[avoid_recursive_tostring] toString() method references itself through \$this or this.toString(), creating infinite recursion. The runtime repeatedly invokes toString() until the call stack overflows, crashing the application with an unrecoverable StackOverflowError. {v5}',
    correctionMessage:
        'Reference individual fields directly (e.g. \$name, \$id) instead of \$this, or build the string using a StringBuffer to control the representation explicitly.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme != 'toString') return;
      if (node.returnType?.toSource() != 'String') {
        // Check if it could still be toString override
        final DartType? returnType = node.returnType?.type;
        if (returnType != null && !returnType.isDartCoreString) return;
      }

      final FunctionBody body = node.body;
      final _ToStringRecursionVisitor visitor = _ToStringRecursionVisitor(
        reporter,
        code,
      );
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
      reporter.atNode(node);
    }
    super.visitInterpolationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // Check for this.toString() or toString() on this
    if (node.methodName.name == 'toString') {
      final Expression? target = node.realTarget;
      if (target == null || target is ThisExpression) {
        reporter.atNode(node);
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
  AvoidReferencingDiscardedVariablesRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_referencing_discarded_variables',
    '[avoid_referencing_discarded_variables] Variable prefixed with underscore is referenced after declaration. The underscore prefix signals that the value is intentionally discarded, so reading it later contradicts the naming convention and confuses developers who expect underscore-prefixed variables to be unused. {v5}',
    correctionMessage:
        'Rename the variable without the underscore prefix if it is actually used, or remove the reference if the variable should remain discarded.',
    severity: DiagnosticSeverity.WARNING,
  );

  // Cached regex for performance
  static final RegExp _discardedVarPattern = RegExp(r'^_[a-z]');

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addSimpleIdentifier((SimpleIdentifier node) {
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

        reporter.atNode(node);
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
  AvoidRedundantPragmaInlineRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_redundant_pragma_inline',
    '[avoid_redundant_pragma_inline] Pragma inline annotation applied to a trivial method that the compiler already inlines automatically. Redundant annotations add noise to the codebase, and overusing pragma inline can prevent the compiler from making better optimization decisions. {v5}',
    correctionMessage:
        'Remove the @pragma(vm:prefer-inline) annotation from simple getters, setters, and one-line methods that the compiler inlines by default.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
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
          reporter.atNode(pragmaAnnotation);
        }
      }
    });
  }

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        RemoveRedundantPragmaInlineFix(context: context),
  ];
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
  AvoidSubstringRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_string_substring',
    '[avoid_string_substring] substring() throws RangeError if start or end indices are out of bounds, causing runtime crashes when input lengths vary. '
        'This is especially dangerous with user input, API responses, or dynamically sized strings where the length cannot be guaranteed at compile time. {v3}',
    correctionMessage:
        'Check string length before calling substring(), or use safer alternatives such as split(), replaceRange(), or pattern matching. '
        'For optional extraction, consider an extension method that returns null for invalid ranges instead of throwing.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name == 'substring') {
        final DartType? targetType = node.realTarget?.staticType;
        if (targetType != null && targetType.isDartCoreString) {
          reporter.atNode(node);
        }
      }
    });
  }

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        AvoidSubstringTodoFix(context: context),
  ];
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
  AvoidUnknownPragmaRule() : super(code: _code);

  static const LintCode _code = LintCode(
    'avoid_unknown_pragma',
    '[avoid_unknown_pragma] Unrecognized pragma annotation detected. Unknown pragmas are silently ignored by the Dart compiler, which means the intended optimization or behavior hint has no effect and may mislead developers into thinking the code is optimized when it is not. {v3}',
    correctionMessage:
        'Use a recognized pragma value such as vm:prefer-inline, vm:never-inline, or dart2js:tryInline, or remove the annotation entirely.',
    severity: DiagnosticSeverity.WARNING,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addAnnotation((Annotation node) {
      if (node.name.name != 'pragma') return;

      final ArgumentList? args = node.arguments;
      if (args == null || args.arguments.isEmpty) return;

      final Expression firstArg = args.arguments.first;
      if (firstArg is! SimpleStringLiteral) return;

      final String pragmaValue = firstArg.value;
      if (!_knownPragmas.contains(pragmaValue)) {
        reporter.atNode(node);
      }
    });
  }

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        DeleteUnknownPragmaFix(context: context),
  ];
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
  AvoidUnusedParametersRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_unused_parameters',
    '[avoid_unused_parameters] Function parameter is declared but never referenced in the function body. Unused parameters add cognitive overhead for callers who must provide a value that has no effect, and they mask API design issues — either remove the parameter or complete the implementation that was supposed to use it. {v6}',
    correctionMessage:
        'Remove the parameter from the function signature, or prefix it with an underscore to indicate it is intentionally unused for interface conformance.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addFunctionDeclaration((FunctionDeclaration node) {
      _checkParameters(
        node.functionExpression.parameters,
        node.functionExpression.body,
        reporter,
      );
    });

    context.addMethodDeclaration((MethodDeclaration node) {
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

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        PrefixUnusedParameterFix(context: context),
  ];
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
  AvoidWeakCryptographicAlgorithmsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_weak_cryptographic_algorithms',
    '[avoid_weak_cryptographic_algorithms] Weak or deprecated cryptographic algorithm detected (e.g. MD5, SHA-1). These algorithms have known collision vulnerabilities that allow attackers to forge hashes, compromising data integrity verification, password storage, and digital signature validation. {v5}',
    correctionMessage:
        'Replace with a stronger algorithm such as SHA-256, SHA-512, or bcrypt for password hashing. Use the crypto or pointycastle package for secure implementations.',
    severity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _weakAlgorithms = <String>{
    'md5',
    'sha1',
    'MD5',
    'SHA1',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addSimpleIdentifier((SimpleIdentifier node) {
      if (_weakAlgorithms.contains(node.name)) {
        reporter.atNode(node);
      }
    });
  }

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        ReplaceWeakCryptoFix(context: context),
  ];
}

/// Warns when a function returns a value that should have @useResult.
///
/// Since: v4.9.5 | Updated: v4.13.0 | Rule version: v5
class MissingUseResultAnnotationRule extends SaropaLintRule {
  MissingUseResultAnnotationRule() : super(code: _code);

  static const LintCode _code = LintCode(
    'missing_use_result_annotation',
    '[missing_use_result_annotation] Function returns a value without @useResult annotation. Callers may accidentally ignore the return value, leading to missed error handling, lost data transformations, or incorrectly assuming the function has side effects when it does not. {v5}',
    correctionMessage:
        'Add @useResult annotation above the function declaration to signal that the returned value must be used. Include a reason parameter explaining what happens if the value is ignored.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
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
  NoObjectDeclarationRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'no_object_declaration',
    '[no_object_declaration] Member declared with type Object, which erases all type information. Accessing any property or method requires an unsafe downcast, bypassing compile-time type checking and risking runtime cast errors that could have been prevented with a more specific type. {v4}',
    correctionMessage:
        'Replace Object with the most specific type that applies, use generics to preserve type information, or use a sealed class hierarchy for known subtypes.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addFieldDeclaration((FieldDeclaration node) {
      final TypeAnnotation? type = node.fields.type;
      if (type is NamedType && type.name.lexeme == 'Object') {
        reporter.atNode(type);
      }
    });

    context.addMethodDeclaration((MethodDeclaration node) {
      final TypeAnnotation? returnType = node.returnType;
      if (returnType is NamedType && returnType.name.lexeme == 'Object') {
        reporter.atNode(returnType);
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
class AvoidAlwaysNullParametersRule extends SaropaLintRule {
  AvoidAlwaysNullParametersRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_always_null_parameters',
    '[avoid_always_null_parameters] Parameter is explicitly passed as null at every call site. Passing null as a constant argument adds noise, makes the call site harder to read, and defeats the purpose of optional parameters, which default to null when omitted. {v4}',
    correctionMessage:
        'Omit the parameter entirely and let the default value apply, or if null has semantic meaning, document why it is passed explicitly.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Check each method invocation for null arguments
    context.addMethodInvocation((MethodInvocation node) {
      for (final Expression arg in node.argumentList.arguments) {
        // Only check named parameters passed as explicit null
        if (arg is NamedExpression && arg.expression is NullLiteral) {
          reporter.atNode(arg);
        }
      }
    });

    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      for (final Expression arg in node.argumentList.arguments) {
        // Only check named parameters passed as explicit null
        if (arg is NamedExpression && arg.expression is NullLiteral) {
          reporter.atNode(arg);
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
  AvoidAssigningToStaticFieldRule() : super(code: _code);

  static const LintCode _code = LintCode(
    'avoid_assigning_to_static_field',
    '[avoid_assigning_to_static_field] Instance method modifies a static field, coupling instance behavior to global state. This makes the class unpredictable because any instance can silently alter shared state, causing race conditions in concurrent code and making tests unreliable. {v3}',
    correctionMessage:
        'Move the assignment to a static method if the modification is class-level, or convert the static field to an instance field if the state should be per-instance.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration classNode) {
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
      _StaticFieldAssignmentVisitor(staticFields, reporter, _code),
    );
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
      reporter.atNode(node);
    }
    super.visitAssignmentExpression(node);
  }

  @override
  void visitPostfixExpression(PostfixExpression node) {
    final Expression operand = node.operand;
    if (operand is SimpleIdentifier && staticFields.contains(operand.name)) {
      reporter.atNode(node);
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
      reporter.atNode(node);
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
  AvoidAsyncCallInSyncFunctionRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.high;

  static const LintCode _code = LintCode(
    'avoid_async_call_in_sync_function',
    '[avoid_async_call_in_sync_function] Async function called inside a synchronous function without handling the returned Future. The Future is silently discarded, so any errors thrown by the async operation are swallowed and any result is lost, making failures invisible. {v5}',
    correctionMessage:
        'Mark the enclosing function as async and await the call, chain with .then()/.catchError() for explicit handling, or wrap with unawaited() to document the intentional fire-and-forget.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (_shouldReport(node)) {
        reporter.atNode(node);
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
class AvoidContradictoryExpressionsRule extends SaropaLintRule {
  AvoidContradictoryExpressionsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    'avoid_contradictory_expressions',
    '[avoid_contradictory_expressions] Contradictory conditions detected where two expressions cannot both be true simultaneously. This creates unreachable code paths that silently skip intended logic, indicating a logic error that may cause incorrect behavior or missed edge cases. {v3}',
    correctionMessage:
        'Review the boolean logic to ensure conditions are compatible, remove the contradictory branch, or correct the expression to reflect the intended behavior.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addBinaryExpression((BinaryExpression node) {
      if (node.operator.type != TokenType.AMPERSAND_AMPERSAND) return;

      // Check for x == null && x.something
      final Expression left = node.leftOperand;
      final Expression right = node.rightOperand;

      if (_isNullCheck(left, true)) {
        final String? varName = _getNullCheckedVariable(left);
        if (varName != null && _usesVariable(right, varName)) {
          reporter.atNode(node);
        }
      }

      // Check for opposite comparisons like x > 5 && x < 3
      if (left is BinaryExpression && right is BinaryExpression) {
        if (_areOppositeComparisons(left, right)) {
          reporter.atNode(node);
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
  AvoidIdenticalExceptionHandlingBlocksRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  static const LintCode _code = LintCode(
    'avoid_identical_exception_handling_blocks',
    '[avoid_identical_exception_handling_blocks] Multiple catch blocks contain identical handling code. Duplicated exception handling increases maintenance burden because changes must be applied to every copy, and missed updates lead to inconsistent error recovery behavior. {v5}',
    correctionMessage:
        'Combine the exception types into a single catch clause (e.g. on FormatException, IOException catch (e)) or extract the shared handling into a helper method.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addTryStatement((TryStatement node) {
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
class AvoidMissingCompleterStackTraceRule extends SaropaLintRule {
  AvoidMissingCompleterStackTraceRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_missing_completer_stack_trace',
    '[avoid_missing_completer_stack_trace] Completer.completeError() called without passing the stack trace as the second argument. Without the original stack trace, error reports show only the completeError() call site instead of the actual failure origin, making debugging asynchronous errors significantly harder. {v4}',
    correctionMessage:
        'Pass the stack trace as the second argument to completeError(error, stackTrace) to preserve the full async error chain for debugging.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'completeError') return;

      // Check argument count
      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.length < 2) {
        reporter.atNode(node);
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
class AvoidSimilarNamesRule extends SaropaLintRule {
  AvoidSimilarNamesRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_similar_names',
    '[avoid_similar_names] Variable name differs from another in-scope variable by only one or two characters. Near-identical names increase the risk of accidentally using the wrong variable, producing subtle bugs that pass code review because the names look correct at a glance. {v4}',
    correctionMessage:
        'Rename one or both variables to be more distinct, using descriptive names that clearly convey their different purposes (e.g. userInput vs validatedInput).',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addBlock((Block node) {
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
    final String normalizedA = a
        .replaceAll('1', 'l')
        .replaceAll('0', 'O')
        .toLowerCase();
    final String normalizedB = b
        .replaceAll('1', 'l')
        .replaceAll('0', 'O')
        .toLowerCase();

    if (normalizedA == normalizedB && a != b) return true;

    // Check edit distance for short names
    if (a.length <= 5 && b.length <= 5) {
      // Single-character names always have edit distance 1 from each
      // other, which is not meaningful. Confusable chars (1/l, 0/O)
      // are already caught by the normalization check above.
      if (a.length == 1 && b.length == 1) return false;
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
class AvoidAccessingCollectionsByConstantIndexRule extends SaropaLintRule {
  AvoidAccessingCollectionsByConstantIndexRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_accessing_collections_by_constant_index',
    '[avoid_accessing_collections_by_constant_index] Collection accessed by a constant index inside a loop body. This retrieves the same element on every iteration, which is wasteful and usually indicates a logic error where the loop variable was intended as the index instead. {v5}',
    correctionMessage:
        'Replace the constant index with the loop variable, or extract the element into a local variable before the loop to make the single-access intent explicit.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addForStatement((ForStatement node) {
      node.body.visitChildren(_ConstantIndexVisitor(reporter, _code));
    });

    context.addWhileStatement((WhileStatement node) {
      node.body.visitChildren(_ConstantIndexVisitor(reporter, _code));
    });

    context.addDoStatement((DoStatement node) {
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
      reporter.atNode(node);
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
  AvoidDefaultToStringRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_default_tostring',
    '[avoid_default_tostring] Class relies on default toString() implementation which returns unhelpful output like "Instance of \'ClassName\'". During debugging, logging, or error messages, developers see meaningless object identifiers instead of the actual state values needed to diagnose issues. {v5}',
    correctionMessage:
        'Override toString() to return a string representation of the object\'s key fields and current state. Format as "ClassName(field1: value1, field2: value2)" for easy inspection during debugging.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
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
  AvoidDuplicateConstantValuesRule() : super(code: _code);

  static const LintCode _code = LintCode(
    'avoid_duplicate_constant_values',
    '[avoid_duplicate_constant_values] Multiple constants share the same value in this scope. Duplicate constant definitions increase maintenance cost because changes must be applied to every copy, and inconsistent updates lead to subtle logic errors when the values diverge. {v3}',
    correctionMessage:
        'Consolidate duplicates into a single named constant and reference it from all usage sites to ensure changes propagate consistently.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addCompilationUnit((CompilationUnit unit) {
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
  AvoidDuplicateInitializersRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_duplicate_initializers',
    '[avoid_duplicate_initializers] Same initialization expression appears in multiple initializer list entries. Duplicate expressions waste computation, increase the risk of inconsistent updates when one copy is changed but others are missed, and obscure the intended initialization logic. {v4}',
    correctionMessage:
        'Extract the shared expression into a local variable or factory method and reference it from each initializer to keep the logic in a single place.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addConstructorDeclaration((ConstructorDeclaration node) {
      final NodeList<ConstructorInitializer> initializers = node.initializers;
      if (initializers.length < 2) return;

      final Set<String> seenExpressions = <String>{};

      for (final ConstructorInitializer init in initializers) {
        if (init is ConstructorFieldInitializer) {
          final String exprSource = init.expression.toSource();
          if (init.expression is Literal) continue;
          if (init.expression is SimpleIdentifier) continue;

          if (seenExpressions.contains(exprSource)) {
            reporter.atNode(init);
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
  AvoidUnnecessaryOverridesRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_unnecessary_overrides',
    '[avoid_unnecessary_overrides] Method override only delegates to super without adding any logic. Unnecessary overrides clutter the class, obscure the inheritance chain, and add a maintenance burden because developers must inspect each override to confirm it does nothing beyond the parent implementation. {v4}',
    correctionMessage:
        'Remove the override entirely so the parent class implementation is used directly. Add the override back only when custom behavior is actually needed.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
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
            reporter.atNode(node);
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
                reporter.atNode(node);
              }
            }
          }
        }
      }
    });
  }

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        RemoveUnnecessaryOverrideFix(context: context),
  ];
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
  AvoidUnnecessaryStatementsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_unnecessary_statements',
    '[avoid_unnecessary_statements] Statement produces a value or expression result that is never used and has no side effects. Dead statements clutter the code, mislead readers into thinking meaningful work is being done, and may indicate a missing assignment or function call. {v4}',
    correctionMessage:
        'Remove the statement if it is truly unused, assign the result to a variable, or call the intended method to produce the expected side effect.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addExpressionStatement((ExpressionStatement node) {
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
        reporter.atNode(node);
      }
    });
  }

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        RemoveUnnecessaryStatementFix(context: context),
  ];
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
class AvoidNestedExtensionTypesRule extends SaropaLintRule {
  AvoidNestedExtensionTypesRule() : super(code: _code);

  static const LintCode _code = LintCode(
    'avoid_nested_extension_types',
    '[avoid_nested_extension_types] Extension type wraps another extension type, creating multiple layers of zero-cost abstraction. Each layer adds indirection to the representation type, making the code harder to reason about and increasing the chance of applying the wrong extension methods to the underlying value. {v3}',
    correctionMessage:
        'Use the underlying representation type directly in the outer extension type to flatten the abstraction and reduce confusion about which methods are available.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addExtensionTypeDeclaration((ExtensionTypeDeclaration node) {
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
  AvoidSlowCollectionMethodsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_slow_collection_methods',
    '[avoid_slow_collection_methods] sync* generator used for a simple collection that yields a small, fixed number of elements. Generator functions have overhead from creating state machines and lazy iterables that exceeds the cost of building a plain list for small collections. {v5}',
    correctionMessage:
        'Return a List literal directly (e.g. [a, b, c]) for small fixed collections. Reserve sync* generators for large or computed sequences where lazy evaluation provides a real benefit.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addFunctionDeclaration((FunctionDeclaration node) {
      _checkForSyncStar(node.functionExpression.body, node.name, reporter);
    });

    context.addMethodDeclaration((MethodDeclaration node) {
      _checkForSyncStar(node.body, node.name, reporter);
    });
  }

  void _checkForSyncStar(
    FunctionBody body,
    Token nameToken,
    SaropaDiagnosticReporter reporter,
  ) {
    if (body.keyword?.lexeme != 'sync') return;
    if (body.star == null) return;

    // Count yield statements
    int yieldCount = 0;
    body.visitChildren(_YieldCounter((int count) => yieldCount = count));

    // Warn if only a few yields (could be a simple list)
    if (yieldCount > 0 && yieldCount <= 5) {
      reporter.atToken(nameToken);
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
class AvoidInferrableTypeArgumentsRule extends SaropaLintRule {
  AvoidInferrableTypeArgumentsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.high;

  @override
  String get exampleBad => "final list = <String>['a', 'b'];";

  @override
  String get exampleGood => "final list = ['a', 'b'];";

  @override
  List<String> get configAliases => const <String>[
    'avoid_inferrable_type_arguments',
  ];

  static const LintCode _code = LintCode(
    'prefer_inferred_type_arguments',
    '[prefer_inferred_type_arguments] Explicit generic type arguments match what the compiler already infers from context. Redundant type parameters add visual noise without providing additional type safety, and they must be manually updated if the underlying types change. {v3}',
    correctionMessage:
        'Remove the explicit type arguments and let the compiler infer them. This reduces verbosity and keeps the code in sync with the actual types automatically.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addListLiteral((ListLiteral node) {
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
        reporter.atNode(typeArgs);
      }
    });

    context.addSetOrMapLiteral((SetOrMapLiteral node) {
      final TypeArgumentList? typeArgs = node.typeArguments;
      if (typeArgs == null) return;
      if (node.elements.isEmpty) return;

      // For non-empty literals with type args, the types can often be inferred
      reporter.atNode(typeArgs);
    });
  }

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        RemoveInferrableTypeArgumentsFix(context: context),
  ];
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
  AvoidPassingDefaultValuesRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_passing_default_values',
    '[avoid_passing_default_values] Argument explicitly passes a value that matches the parameter default (e.g. empty list, false, 0). Passing the default adds noise to the call site without changing behavior, and if the library updates its default, this call site will not benefit from the change. {v4}',
    correctionMessage:
        'Omit the argument to use the default value. This keeps call sites concise and automatically picks up any default changes from the callee.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      _checkArguments(node.argumentList, reporter);
    });

    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      _checkArguments(node.argumentList, reporter);
    });
  }

  void _checkArguments(
    ArgumentList argList,
    SaropaDiagnosticReporter reporter,
  ) {
    for (final Expression arg in argList.arguments) {
      if (arg is! NamedExpression) continue;

      final Expression value = arg.expression;

      // Only flag empty collection literals - these are almost always defaults
      if (_isEmptyCollectionLiteral(value)) {
        reporter.atNode(arg);
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
  AvoidShadowedExtensionMethodsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    'avoid_shadowed_extension_methods',
    '[avoid_shadowed_extension_methods] Extension method has the same name as an instance method on the target class. The instance method always takes precedence, so the extension method is never called through normal dispatch, making it dead code that misleads developers. {v3}',
    correctionMessage:
        'Rename the extension method to a unique name, or remove it if the instance method already provides the needed behavior.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addExtensionDeclaration((ExtensionDeclaration node) {
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
///
/// **Exempt:** Domain-inherent literals (`'true'`, `'false'`, `'null'`,
/// `'none'`) are self-documenting and are not flagged.
class AvoidDuplicateStringLiteralsRule extends SaropaLintRule {
  AvoidDuplicateStringLiteralsRule() : super(code: _code);

  /// Style/consistency issue. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_duplicate_string_literals',
    '[avoid_duplicate_string_literals] String literal appears 3+ times in this file. Consider extracting '
        'to a constant. {v1}',
    correctionMessage:
        'Extract this string to a named constant for maintainability.',
    severity: DiagnosticSeverity.INFO,
  );

  /// Minimum occurrences to trigger this rule
  static const int _minOccurrences = 3;

  /// Minimum string length to consider (shorter strings are often intentional)
  static const int _minLength = 4;

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Track occurrences and report when threshold is reached.
    // Note: Map state is per-file since runWithReporter is called per-file.
    final Map<String, List<AstNode>> stringOccurrences =
        <String, List<AstNode>>{};

    context.addSimpleStringLiteral((SimpleStringLiteral node) {
      final String value = node.value;

      // Skip short strings
      if (value.length < _minLength) return;

      // Skip excluded patterns
      if (_shouldSkipString(value)) return;

      final List<AstNode> occurrences = stringOccurrences.putIfAbsent(
        value,
        () => <AstNode>[],
      );
      occurrences.add(node);

      // Report when we hit the threshold (report the current node)
      // and when we exceed it (each subsequent occurrence)
      if (occurrences.length >= _minOccurrences) {
        reporter.atNode(node);
      }
    });
  }

  bool _shouldSkipString(String value) {
    if (_isDomainInherentLiteral(value)) return true;

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

  /// Self-documenting literals that gain nothing from extraction to a
  /// named constant. These are domain vocabulary (bool parsing, sentinels)
  /// where the literal IS the documentation.
  ///
  /// Only includes strings >= [_minLength] chars (shorter ones are already
  /// filtered before reaching this check).
  static bool _isDomainInherentLiteral(String value) =>
      _domainLiterals.contains(value);

  static const Set<String> _domainLiterals = <String>{
    'true', 'false', 'null', 'none', // Language/sentinel literals as strings
  };
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
  AvoidDuplicateStringLiteralsPairRule() : super(code: _code);

  /// Style/consistency issue. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_duplicate_string_literals_pair',
    '[avoid_duplicate_string_literals_pair] String literal appears 2+ times in this file. Consider extracting '
        'to a constant. {v1}',
    correctionMessage:
        'Extract this string to a named constant for maintainability.',
    severity: DiagnosticSeverity.INFO,
  );

  /// Minimum occurrences to trigger this rule
  static const int _minOccurrences = 2;

  /// Minimum string length to consider
  static const int _minLength = 4;

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Track occurrences and report when threshold is reached.
    // Note: Map state is per-file since runWithReporter is called per-file.
    final Map<String, List<AstNode>> stringOccurrences =
        <String, List<AstNode>>{};

    context.addSimpleStringLiteral((SimpleStringLiteral node) {
      final String value = node.value;

      // Skip short strings
      if (value.length < _minLength) return;

      // Skip excluded patterns
      if (_shouldSkipString(value)) return;

      final List<AstNode> occurrences = stringOccurrences.putIfAbsent(
        value,
        () => <AstNode>[],
      );
      occurrences.add(node);

      // Report when we hit the threshold (report the current node)
      // and when we exceed it (each subsequent occurrence)
      if (occurrences.length >= _minOccurrences) {
        reporter.atNode(node);
      }
    });
  }

  bool _shouldSkipString(String value) {
    if (AvoidDuplicateStringLiteralsRule._isDomainInherentLiteral(value)) {
      return true;
    }

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

/// Don't build expensive strings for logs that won't print.
///
/// Flags [MethodInvocation] where method name is `log` and the first argument
/// is a [StringInterpolation]. No level guard detection (single-file only).
/// Heuristic: any `log(...)` with interpolated first arg may be expensive.
///
/// **Bad:**
/// ```dart
/// log('User $id did $action');  // Always evaluates interpolation
/// ```
///
/// **Good:**
/// ```dart
/// if (Logger.level <= Level.FINE) log('User $id did $action');
/// // or use a logging API that accepts a closure: log(() => 'User $id');
/// ```
class AvoidExpensiveLogStringConstructionRule extends SaropaLintRule {
  AvoidExpensiveLogStringConstructionRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_expensive_log_string_construction',
    '[avoid_expensive_log_string_construction] Log call uses string interpolation; the string is built even when the log level would not print it. Add a level guard or use a lazy message. {v1}',
    correctionMessage:
        'Guard the log call with a level check or use a logging API that accepts a closure for the message.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'log') return;

      final List<Expression> args = node.argumentList.arguments;
      if (args.isEmpty) return;

      final Expression first = args.first;
      if (first is! StringInterpolation) return;

      reporter.atNode(node);
    });
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
class AvoidEmptyBuildWhenRule extends SaropaLintRule {
  AvoidEmptyBuildWhenRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_empty_build_when',
    '[avoid_empty_build_when] buildWhen callback always returns true, which is the default behavior. The callback adds code without filtering any rebuilds, defeating the purpose of the optimization that buildWhen provides in BlocBuilder and BlocListener. {v2}',
    correctionMessage:
        'Add a meaningful state comparison that returns false for states that do not require a rebuild, or remove buildWhen entirely to use the default behavior.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
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
                reporter.atNode(arg);
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
                  reporter.atNode(arg);
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
class AvoidMissingInterpolationRule extends SaropaLintRule {
  AvoidMissingInterpolationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_missing_interpolation',
    '[avoid_missing_interpolation] String concatenation using the + operator combines a string literal with a variable or expression. String interpolation (\$variable or \${expression}) is the idiomatic Dart approach that is more readable, less error-prone (no accidental space omission between segments), and avoids creating intermediate String objects for each + operation, improving both clarity and performance in concatenation-heavy code paths.',
    correctionMessage:
        'Replace string concatenation with string interpolation using \$variable or \${expression} syntax for cleaner, more idiomatic Dart code.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addBinaryExpression((BinaryExpression node) {
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

      reporter.atNode(node);
    });
  }
}

// =============================================================================
// avoid_ignoring_return_values
// =============================================================================

/// Warns when a function's return value is ignored.
///
/// Since: v4.15.0 | Rule version: v1
///
/// Ignoring a return value often means the result of a computation or an
/// error check is silently discarded. This can hide bugs where an important
/// result (e.g., a Future, a boolean success flag, or a parsed value) is
/// not being used.
///
/// **BAD:**
/// ```dart
/// void example() {
///   list.map((e) => e * 2); // Return value ignored
///   int.parse('42');        // Parsed value discarded
/// }
/// ```
///
/// **Exempt:** Map mutation methods (`update`, `putIfAbsent`, `updateAll`) and
/// property setter assignments (e.g. `obj.value = x`) are not flagged when
/// used for their in-place side effect.
///
/// **GOOD:**
/// ```dart
/// void example() {
///   final doubled = list.map((e) => e * 2).toList();
///   final value = int.parse('42');
/// }
/// ```
class AvoidIgnoringReturnValuesRule extends SaropaLintRule {
  AvoidIgnoringReturnValuesRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_ignoring_return_values',
    '[avoid_ignoring_return_values] Return value of this invocation is '
        'ignored. Discarding return values can hide bugs where an important '
        'result (a Future, a boolean success flag, or a parsed value) is '
        'silently lost. Assign the result to a variable or remove the call '
        'if it is truly unnecessary. {v1}',
    correctionMessage:
        'Assign the return value to a variable, or use it in an expression.',
    severity: DiagnosticSeverity.INFO,
  );

  /// Methods whose return values are commonly and safely ignored.
  static const Set<String> _safeToIgnore = <String>{
    'print',
    'debugPrint',
    'debugPrintStack',
    'log',
    'setState',
    'add',
    'addAll',
    'addEntries',
    'remove',
    'removeAt',
    'removeLast',
    'removeWhere',
    'retainWhere',
    'clear',
    'insert',
    'insertAll',
    'sort',
    'shuffle',
    'fillRange',
    'setAll',
    'setRange',
    'replaceRange',
    // Map mutation methods — return value is a convenience, primary purpose
    // is the in-place mutation of the map.
    'update',
    'putIfAbsent',
    'updateAll',
    'addPostFrameCallback',
    'addPersistentFrameCallback',
    'scheduleMicrotask',
    'runZoned',
    'close',
    'dispose',
    'cancel',
    'write',
    'writeln',
    'writeAll',
    'writeCharCode',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addExpressionStatement((ExpressionStatement node) {
      final Expression expression = node.expression;

      // Property setter assignments (e.g. obj.prop = value) have no
      // meaningful return value — skip them unconditionally.
      if (expression is AssignmentExpression) return;

      // Only check method invocations and function invocations
      if (expression is! MethodInvocation &&
          expression is! FunctionExpressionInvocation) {
        return;
      }

      // Get method name and return type
      String? methodName;
      DartType? returnType;

      if (expression is MethodInvocation) {
        methodName = expression.methodName.name;
        returnType = expression.staticType;
      } else if (expression is FunctionExpressionInvocation) {
        returnType = expression.staticType;
      }

      // Skip methods that are safe to ignore
      if (methodName != null && _safeToIgnore.contains(methodName)) return;

      // Skip cascade targets (they return the cascade target)
      if (expression is MethodInvocation && expression.isCascaded) return;

      // Skip void, dynamic, and Null return types
      if (returnType == null || returnType is VoidType) return;
      if (returnType is DynamicType) return;
      if (returnType.isDartCoreNull) return;

      // Skip Future<void>
      if (returnType.isDartAsyncFuture) {
        final InterfaceType futureType = returnType as InterfaceType;
        if (futureType.typeArguments.isNotEmpty) {
          final DartType typeArg = futureType.typeArguments.first;
          if (typeArg is VoidType) return;
        }
      }

      reporter.atNode(expression);
    });
  }
}

// =============================================================================
// avoid_deprecated_usage
// =============================================================================

/// Warns when using deprecated APIs from other packages (WARNING severity).
///
/// Dart's built-in `deprecated_member_use` is INFO and often suppressed; this
/// rule provides a WARNING-level signal visible in CI. Same-package usage is
/// ignored by default so migrations can call their own deprecated APIs.
/// Generated files (`.g.dart`, `.freezed.dart`) are skipped.
///
/// **Trigger:** MethodInvocation, PropertyAccess, or InstanceCreationExpression
/// that resolves to an element (or constructor's class) with `@Deprecated` or
/// `@deprecated` from a different package.
///
/// **BAD:**
/// ```dart
/// final text = someWidget.textTheme.headline1; // deprecated in Material3
/// ```
///
/// **GOOD:**
/// ```dart
/// final text = someWidget.textTheme.displayLarge;
/// ```
///
/// **Heuristic:** Same-package is inferred from element.library.uri vs
/// current project package name. No config yet (ignore_own_package Phase 2).
class AvoidDeprecatedUsageRule extends SaropaLintRule {
  AvoidDeprecatedUsageRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_deprecated_usage',
    '[avoid_deprecated_usage] Using a deprecated API from another package. '
        'Migrate to the replacement API. No migration guidance provided.',
    correctionMessage:
        'Replace with the non-deprecated API. Check the @Deprecated message for migration guidance.',
    severity: DiagnosticSeverity.WARNING,
  );

  static bool _isDeprecated(Element? element) {
    if (element == null) return false;
    try {
      if (hasDeprecatedFlag(element)) return true;

      final meta = (element as dynamic).metadata;
      for (final ann in readElementAnnotationsFromMetadata(meta)) {
        if (ann.isDeprecated) return true;
      }
      if (element is ConstructorElement) {
        final enclosing = element.enclosingElement;
        if (hasDeprecatedFlag(enclosing)) return true;

        final enclosingMeta = (enclosing as dynamic).metadata;
        for (final ann in readElementAnnotationsFromMetadata(enclosingMeta)) {
          if (ann.isDeprecated) return true;
        }
      }
    } on Object {
      return false;
    }
    return false;
  }

  static bool _isSamePackage(Element? element, String filePath) {
    if (element == null) return true;
    final uri = element.library?.uri.toString() ?? '';
    if (!uri.startsWith('package:')) return true;
    final rest = uri.substring(8);
    final slash = rest.indexOf('/');
    final elementPackage = slash >= 0 ? rest.substring(0, slash) : rest;
    final root = ProjectContext.findProjectRoot(filePath);
    if (root == null) return true;
    final currentPackage = ProjectContext.getPackageName(root);
    return elementPackage == currentPackage;
  }

  static bool _isGeneratedFile(String path) {
    return path.endsWith('.g.dart') ||
        path.endsWith('.freezed.dart') ||
        path.endsWith('.gen.dart');
  }

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    final path = context.filePath;
    if (_isGeneratedFile(path)) return;

    void checkElement(Element? element, AstNode node) {
      try {
        if (element == null) return;
        if (!_isDeprecated(element)) return;
        if (_isSamePackage(element, path)) return;
        reporter.atNode(node);
      } on Object {
        // Plugin must not crash on any element API throw (e.g. metadata).
      }
    }

    // Support both analyzer APIs: .element (analyzer 9+) and .staticElement (older).
    Element? elementFromIdentifier(dynamic id) {
      if (id == null) return null;
      try {
        final e = id.element;
        if (e is Element) return e;
      } on Object {}
      try {
        final s = id.staticElement;
        if (s is Element) return s;
      } on Object {}
      return null;
    }

    context.addMethodInvocation((MethodInvocation node) {
      checkElement(elementFromIdentifier(node.methodName), node);
    });
    context.addPropertyAccess((PropertyAccess node) {
      checkElement(elementFromIdentifier(node.propertyName), node);
    });
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      checkElement(elementFromIdentifier(node.constructorName), node);
    });
  }
}

/// Warns when a function or constructor has positional bool parameters.
///
/// Named parameters make call sites readable: `login(rememberMe: true)` vs `login(true)`.
///
/// **Bad:**
/// ```dart
/// void setPermissions(bool canRead, bool canWrite) {}
/// ```
///
/// **Good:**
/// ```dart
/// void setPermissions({required bool canRead, required bool canWrite}) {}
/// ```
class AvoidPositionalBooleanParametersRule extends SaropaLintRule {
  AvoidPositionalBooleanParametersRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_positional_boolean_parameters',
    '[avoid_positional_boolean_parameters] Positional bool parameter makes call sites unreadable. Use named parameters for clarity.',
    correctionMessage:
        'Convert to a named parameter so call sites are self-documenting.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addFormalParameterList((FormalParameterList node) {
      final AstNode? parent = node.parent;
      if (parent is MethodDeclaration) {
        if (parent.isOperator || parent.isSetter) return;
        if (parent.metadata.any((a) => a.name.name == 'override')) return;
      } else if (parent is FunctionExpression) {
        return;
      } else if (parent is FunctionTypedFormalParameter) {
        return;
      }
      for (final FormalParameter p in node.parameters) {
        if (p is DefaultFormalParameter) {
          if (p.parameter is! SimpleFormalParameter) continue;
          if (!_isPositional(node, p)) continue;
          final SimpleFormalParameter sp = p.parameter as SimpleFormalParameter;
          if (_isBoolType(sp)) reporter.atNode(p);
        } else if (p is SimpleFormalParameter) {
          if (!_isPositional(node, p)) continue;
          if (_isBoolType(p)) reporter.atNode(p);
        }
      }
    });
  }

  bool _isPositional(FormalParameterList list, FormalParameter p) {
    return p.isNamed == false;
  }

  bool _isBoolType(SimpleFormalParameter p) {
    final TypeAnnotation? type = p.type;
    if (type is! NamedType) return false;
    final String name = type.name.lexeme;
    return name == 'bool';
  }
}

/// Prefer named boolean parameters for functions with few parameters.
///
/// Flags positional bool parameters in functions with 1–3 parameters. Complements
/// avoid_positional_boolean_parameters; use one or the other. Excludes setters,
/// operators, and @override methods.
class BannedUsageRule extends SaropaLintRule {
  BannedUsageRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'banned_identifier_usage',
    '[banned_identifier_usage] Usage of this identifier is banned. See analysis_options_custom.yaml banned_usage for the configured reason.',
    correctionMessage:
        'Replace with an allowed alternative from your project config.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  List<String> get configAliases => const ['banned_usage'];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    final entries = banned_usage_config.bannedUsageEntries;
    if (entries.isEmpty) return;

    final filePath = context.filePath.replaceAll('\\', '/');

    context.addSimpleIdentifier((SimpleIdentifier node) {
      final name = node.name;
      for (final ban in entries) {
        if (!ban.matchesName(name)) continue;
        if (ban.allowedFiles != null) {
          final allowed = ban.allowedFiles!.any((p) {
            if (p.endsWith('*')) {
              final prefix = p.substring(0, p.length - 1);
              return filePath.contains(prefix) ||
                  filePath.endsWith(prefix.replaceAll('/', ''));
            }
            return filePath == p || filePath.endsWith(p);
          });
          if (allowed) return;
        }
        reporter.atNode(node);
        return;
      }
    });
  }
}
