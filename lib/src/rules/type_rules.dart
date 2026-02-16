// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';

import '../saropa_lint_rule.dart';

/// Warns when casting to an extension type.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// Extension types are compile-time only; casting to them can be misleading
/// as the runtime type doesn't change.
///
/// Example of **bad** code:
/// ```dart
/// extension type UserId(int id) implements int {}
/// final userId = 42 as UserId;  // Misleading cast
/// ```
///
/// Example of **good** code:
/// ```dart
/// extension type UserId(int id) implements int {}
/// final userId = UserId(42);  // Proper construction
/// ```
///
/// **Quick fix available:** Adds a comment to flag for manual review.
class AvoidCastingToExtensionTypeRule extends SaropaLintRule {
  AvoidCastingToExtensionTypeRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_casting_to_extension_type',
    '[avoid_casting_to_extension_type] Cast to extension type bypasses the constructor invariants and type safety guarantees. '
        'Extension types are erased at runtime, so the cast always succeeds regardless of whether the value satisfies the extension type constraints, silently producing an invalid wrapper. {v5}',
    correctionMessage:
        'Use the extension type constructor (e.g., UserId(42)) instead of casting (42 as UserId). '
        'The constructor enforces any validation logic defined in the extension type and makes the type conversion explicit and self-documenting at the call site.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addAsExpression((AsExpression node) {
      // Check if target type is an extension type
      final TypeAnnotation typeAnnotation = node.type;

      // Extension types show as their representation type in staticType
      // but the annotation is a NamedType pointing to the extension
      if (typeAnnotation is NamedType) {
        final Element? element = typeAnnotation.element;
        if (element != null && element.toString().contains('extension type')) {
          reporter.atNode(node);
        }
      }
    });
  }
}

/// Warns when using collection methods with unrelated types.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// Using `contains`, `indexOf`, `remove`, etc. with a type that can never
/// match the collection's element type is likely a bug.
///
/// Example of **bad** code:
/// ```dart
/// List<String> items = ['a', 'b'];
/// items.contains(42);  // int can never be in List<String>
/// ```
///
/// Example of **good** code:
/// ```dart
/// List<String> items = ['a', 'b'];
/// items.contains('a');  // Correct type
/// ```
///
/// **Quick fix available:** Adds a comment to flag for manual review.
class AvoidCollectionMethodsWithUnrelatedTypesRule extends SaropaLintRule {
  AvoidCollectionMethodsWithUnrelatedTypesRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.high;

  static const LintCode _code = LintCode(
    'avoid_collection_methods_with_unrelated_types',
    '[avoid_collection_methods_with_unrelated_types] Collection method called with unrelated type. Using contains, indexOf, remove, etc. with a type that can never match the collection\'s element type is likely a bug. {v5}',
    correctionMessage:
        'The argument type cannot match any element in the collection. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _collectionMethods = <String>{
    'contains',
    'indexOf',
    'lastIndexOf',
    'remove',
    'lookup',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (!_collectionMethods.contains(methodName)) return;

      final Expression? target = node.realTarget;
      if (target == null) return;

      final DartType? targetType = target.staticType;
      if (targetType == null) return;

      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isEmpty) return;

      final DartType? argType = args.first.staticType;
      if (argType == null) return;

      // Get the element type of the collection
      String? elementTypeName;
      final String targetTypeStr = targetType.getDisplayString();

      if (targetTypeStr.startsWith('List<')) {
        elementTypeName = _extractGenericType(targetTypeStr);
      } else if (targetTypeStr.startsWith('Set<')) {
        elementTypeName = _extractGenericType(targetTypeStr);
      } else if (targetTypeStr.startsWith('Iterable<')) {
        elementTypeName = _extractGenericType(targetTypeStr);
      }

      if (elementTypeName == null) return;

      final String argTypeName = argType.getDisplayString();

      // Check if types are definitely unrelated
      if (_areUnrelatedTypes(elementTypeName, argTypeName)) {
        reporter.atNode(args.first, code);
      }
    });
  }

  String? _extractGenericType(String typeStr) {
    final int start = typeStr.indexOf('<');
    final int end = typeStr.lastIndexOf('>');
    if (start != -1 && end != -1 && end > start) {
      return typeStr.substring(start + 1, end);
    }
    return null;
  }

  bool _areUnrelatedTypes(String type1, String type2) {
    // Skip dynamic/Object comparisons
    if (type1 == 'dynamic' ||
        type2 == 'dynamic' ||
        type1 == 'Object' ||
        type2 == 'Object') {
      return false;
    }

    // Check obvious mismatches between primitive types
    const Map<String, Set<String>> typeGroups = <String, Set<String>>{
      'numeric': <String>{'int', 'double', 'num'},
      'string': <String>{'String'},
      'bool': <String>{'bool'},
    };

    String? group1;
    String? group2;
    for (final MapEntry<String, Set<String>> entry in typeGroups.entries) {
      if (entry.value.contains(type1)) group1 = entry.key;
      if (entry.value.contains(type2)) group2 = entry.key;
    }

    // If both are in known groups and different groups, they're unrelated
    if (group1 != null && group2 != null && group1 != group2) {
      return true;
    }

    return false;
  }
}

/// Warns when dynamic type is used.
///
/// Since: v4.1.3 | Updated: v4.13.0 | Rule version: v3
///
/// Using dynamic bypasses the type system and can lead to runtime errors.
/// Prefer using specific types or generics.
class AvoidDynamicRule extends SaropaLintRule {
  AvoidDynamicRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_dynamic_type',
    "[avoid_dynamic_type] 'dynamic' type disables static type checking, hiding errors until runtime. "
        "Method calls on dynamic values are never verified by the compiler, so typos, missing methods, and wrong argument types only surface as NoSuchMethodError crashes in production. {v3}",
    correctionMessage:
        "Replace 'dynamic' with a specific type, Object (for truly unknown values with explicit casts), or a generic type parameter. "
        'If the actual type varies, use a sealed class hierarchy or union type to keep the compiler involved in checking correctness.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addNamedType((NamedType node) {
      if (node.name.lexeme == 'dynamic') {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when extension type doesn't implement Object and is implicitly nullable.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Extension types that don't implement Object can be implicitly nullable,
/// which may lead to unexpected behavior.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// extension type UserId(int id) { } // Implicitly nullable
/// ```
///
/// #### GOOD:
/// ```dart
/// extension type UserId(int id) implements Object { }
/// ```
///
/// **Quick fix available:** Adds a comment to flag for manual review.
class AvoidImplicitlyNullableExtensionTypesRule extends SaropaLintRule {
  AvoidImplicitlyNullableExtensionTypesRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_implicitly_nullable_extension_types',
    '[avoid_implicitly_nullable_extension_types] Extension type is implicitly nullable. Extension types that don\'t implement Object can be implicitly nullable, which may lead to unexpected behavior. {v4}',
    correctionMessage:
        'Add "implements Object" to make it non-nullable. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addExtensionTypeDeclaration((ExtensionTypeDeclaration node) {
      final ImplementsClause? implementsClause = node.implementsClause;

      // Check if it implements Object
      bool implementsObject = false;
      if (implementsClause != null) {
        for (final NamedType type in implementsClause.interfaces) {
          if (type.name.lexeme == 'Object') {
            implementsObject = true;
            break;
          }
        }
      }

      if (!implementsObject) {
        reporter.atToken(node.name, code);
      }
    });
  }
}

/// Warns when interpolating a nullable value in a string.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// **Quick fix available:** Adds a comment to flag for manual review.
class AvoidNullableInterpolationRule extends SaropaLintRule {
  AvoidNullableInterpolationRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_nullable_interpolation',
    "[avoid_nullable_interpolation] Nullable value in string interpolation produces the literal text 'null' instead of a meaningful fallback. "
        "Users may see 'Hello null' or 'Order #null' in the UI, which looks like a bug and erodes trust in the application quality and data integrity. {v5}",
    correctionMessage:
        "Add a null check before interpolation, or use the null-coalescing operator (??) to provide a sensible default (e.g., '\${name ?? \"Guest\"}'). "
        'For complex formatting, consider a helper method that handles null values with appropriate placeholder text.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInterpolationExpression((InterpolationExpression node) {
      final Expression expr = node.expression;
      final DartType? type = expr.staticType;
      if (type == null) return;

      if (type.nullabilitySuffix == NullabilitySuffix.question) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when nullable parameters have default values that could be non-null.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// If a parameter has a default value, it doesn't need to be nullable.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// void foo({String? name = 'default'}) { }
/// ```
///
/// #### GOOD:
/// ```dart
/// void foo({String name = 'default'}) { }
/// ```
///
/// **Quick fix available:** Adds a comment to flag for manual review.
class AvoidNullableParametersWithDefaultValuesRule extends SaropaLintRule {
  AvoidNullableParametersWithDefaultValuesRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_nullable_parameters_with_default_values',
    '[avoid_nullable_parameters_with_default_values] Parameter with default value must not be nullable. If a parameter has a default value, it doesn\'t need to be nullable. Quick fix available: Adds a comment to flag for manual review. {v5}',
    correctionMessage:
        'Remove the ? from the type since it has a non-null default. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addDefaultFormalParameter((DefaultFormalParameter node) {
      final Expression? defaultValue = node.defaultValue;
      if (defaultValue == null) return;

      // Skip if default value is null
      if (defaultValue is NullLiteral) return;

      // Check if the parameter type is nullable
      final NormalFormalParameter parameter = node.parameter;
      TypeAnnotation? typeAnnotation;

      if (parameter is SimpleFormalParameter) {
        typeAnnotation = parameter.type;
      }

      if (typeAnnotation is NamedType && typeAnnotation.question != null) {
        reporter.atNode(typeAnnotation);
      }
    });
  }
}

/// Warns when calling `.toString()` on a nullable value without null check.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Example of **bad** code:
/// ```dart
/// String? name;
/// print(name.toString());  // Could be 'null' string
/// ```
///
/// Example of **good** code:
/// ```dart
/// String? name;
/// print(name ?? 'default');
/// // or
/// if (name != null) print(name);
/// ```
class AvoidNullableToStringRule extends SaropaLintRule {
  AvoidNullableToStringRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_nullable_tostring',
    '[avoid_nullable_tostring] Calling toString() on a nullable value. Calling .toString() on a nullable value without null check. This type usage can cause unexpected runtime behavior or weaken static analysis effectiveness. {v4}',
    correctionMessage:
        'Check for null first or provide a default value. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'toString') return;

      // Skip null-safe calls: x?.toString() is the proper way to handle nullable
      if (node.isNullAware) return;

      final Expression? target = node.target;
      if (target == null) return;

      // Skip if target is a simple identifier - flow analysis likely handles it
      // (e.g., inside `if (x != null) { x.toString(); }`)
      if (target is SimpleIdentifier) return;

      final DartType? targetType = target.staticType;
      if (targetType == null) return;

      // Check if target is nullable
      if (targetType.nullabilitySuffix == NullabilitySuffix.question) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when the null assertion operator (!) is used unsafely.
///
/// Since: v1.1.18 | Updated: v4.13.0 | Rule version: v7
///
/// The bang operator can cause runtime crashes when the value is unexpectedly null.
/// Use null-safe alternatives instead:
/// - `variable ?? defaultValue` - provide a default
/// - `if (variable != null) { ... }` - null check first
/// - `variable?.property` - optional chaining
///
/// **Safe patterns that are NOT flagged:**
/// - Ternary with null check: `x == null ? null : x!` or `x != null ? x! : null`
/// - Inside if-block with null check: `if (x != null) { use(x!); }`
/// - After `.isNotNullOrEmpty` check: `if (x.isNotNullOrEmpty) { use(x!); }`
/// - Short-circuit `||`: `x == null || x!.length > 0` (x! won't execute if null)
/// - Short-circuit `||`: `x.isListNullOrEmpty || x!.length < 2`
/// - Short-circuit `&&`: `x != null && x!.doSomething()`
///
/// Example of **bad** code:
/// ```dart
/// final String name = user.name!; // Crashes if name is null
/// ```
///
/// Example of **good** code:
/// ```dart
/// final String name = user.name ?? 'Unknown';
/// // or
/// if (user.name != null) {
///   final String name = user.name;
/// }
/// // or (safe, not flagged)
/// onTap: callback == null ? null : () => callback!(),
/// ```
class AvoidNullAssertionRule extends SaropaLintRule {
  AvoidNullAssertionRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_null_assertion',
    '[avoid_null_assertion] Null assertion operator (!) throws a runtime exception if the value is null, crashing the app without a meaningful error message. '
        'The resulting _CastError provides no context about which value was null or why, making production crashes difficult to diagnose from error reports alone. {v7}',
    correctionMessage:
        'Use null-safe alternatives: ?? for default values (e.g., name ?? \'Unknown\'), if-null checks for conditional logic, or ?. for optional chaining. '
        'When null is truly impossible, add an assert with a descriptive message or use a guard clause that throws a custom exception.',
    severity: DiagnosticSeverity.INFO,
  );

  /// Extension names that return `true` when value is NOT null/empty/zero.
  /// Used for `&&` short-circuit: `x.isNotEmpty && x!.foo`
  /// Used for if-blocks: `if (x.isNotEmpty) x!`
  static const Set<String> _truthyNullCheckNames = <String>{
    'isNotNullOrEmpty',
    'isNotNullOrBlank',
    'isNeitherNullNorEmpty',
    'isNotEmpty',
    'isNotListNullOrEmpty',
    'isNotNullOrZero',
    'isPositive',
  };

  /// Extension names that return `true` when value IS null/empty/zero/negative.
  /// Used for `||` short-circuit: `x.isEmpty || x!.foo`
  /// Used for inverted if-blocks: `if (x.isZeroOrNegative) { } else { x! }`
  static const Set<String> _falsyNullCheckNames = <String>{
    'isListNullOrEmpty',
    'isNullOrEmpty',
    'isNullOrBlank',
    'isEmpty',
    'isNullOrZero',
    'isZeroOrNegative',
    'isNegativeOrZero',
    'isNegative',
  };

  /// All recognized null-check extension names.
  static const Set<String> _nullCheckNames = <String>{
    ..._truthyNullCheckNames,
    ..._falsyNullCheckNames,
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addPostfixExpression((PostfixExpression node) {
      // Check if this is a null assertion (!)
      if (node.operator.lexeme != '!') return;

      // Check if this is a safe pattern
      if (_isInSafeTernary(node)) return;
      if (_isInSafeIfBlock(node)) return;
      if (_isInShortCircuitSafe(node)) return;
      if (_isAfterNullCoalescingAssignment(node)) return;

      reporter.atNode(node);
    });
  }

  /// Checks if the null assertion is safe because it follows a ??= assignment.
  ///
  /// Safe pattern:
  /// ```dart
  /// x ??= defaultValue;
  /// x!.doSomething();  // Safe - x is guaranteed non-null after ??=
  /// ```
  bool _isAfterNullCoalescingAssignment(PostfixExpression node) {
    final String assertedExpr = _getBaseExpression(node.operand);

    // Find the enclosing block or function body
    AstNode? current = node.parent;
    Block? enclosingBlock;
    while (current != null) {
      if (current is Block) {
        enclosingBlock = current;
        break;
      }
      if (current is FunctionBody) break;
      current = current.parent;
    }

    if (enclosingBlock == null) return false;

    // Find the statement containing the node
    Statement? nodeStatement;
    for (final Statement stmt in enclosingBlock.statements) {
      if (_containsNode(stmt, node)) {
        nodeStatement = stmt;
        break;
      }
    }

    if (nodeStatement == null) return false;

    // Look for ??= assignment before the node's statement
    for (final Statement stmt in enclosingBlock.statements) {
      // Stop when we reach the statement containing the node
      if (stmt == nodeStatement) break;

      // Check for ??= assignment
      if (stmt is ExpressionStatement) {
        final Expression expr = stmt.expression;
        if (expr is AssignmentExpression && expr.operator.lexeme == '??=') {
          final String assignedExpr = _getBaseExpression(expr.leftHandSide);
          if (assignedExpr == assertedExpr) {
            return true;
          }
        }
      }
    }

    return false;
  }

  /// Checks if the null assertion is inside a ternary that guards against null.
  ///
  /// Safe patterns:
  /// - `x == null ? null : x!`
  /// - `x == null ? defaultValue : x!`
  /// - `x != null ? x! : null`
  /// - `x != null ? x! : defaultValue`
  /// - `callback == null ? null : () => callback!(args)`
  bool _isInSafeTernary(PostfixExpression node) {
    // Walk up to find enclosing ConditionalExpression
    AstNode? current = node.parent;
    while (current != null) {
      if (current is ConditionalExpression) {
        final Expression condition = current.condition;

        // Get the expression being null-asserted (without the !)
        final String assertedExpr = _getBaseExpression(node.operand);

        // Check for `x == null ? ... : x!` pattern
        if (condition is BinaryExpression) {
          final String? checkedExpr = _getNullCheckedExpression(condition);
          if (checkedExpr != null && checkedExpr == assertedExpr) {
            // Verify the ! is on the correct branch
            if (condition.operator.lexeme == '==' &&
                _containsNode(current.elseExpression, node)) {
              return true;
            }
            if (condition.operator.lexeme == '!=' &&
                _containsNode(current.thenExpression, node)) {
              return true;
            }
          }
        }

        // Don't traverse further up for ternaries
        break;
      }
      current = current.parent;
    }
    return false;
  }

  /// Checks if the null assertion is inside an if-block that guards against null.
  ///
  /// Safe patterns:
  /// - `if (x != null) { ... x! ... }`
  /// - `if (x == null) return; ... x! ...`
  /// - `if (x.isNotNullOrEmpty) { ... x! ... }`
  /// - `if (x.isNotEmpty) { ... x! ... }` (for String?)
  /// - `[if (x != null) x!]` (collection if elements)
  /// - `if (x?.length == 1) { x!.first }` (null-propagating comparison)
  /// - `if (x!.length == 1) { x!.first }` (prior assertion implies non-null)
  /// - `if (a && x != null) { x! }` (compound && with null check)
  /// - `if (a || x == null) return; x!` (compound || with early return)
  /// - `if (snapshot.hasData) { snapshot.data! }` (Flutter async builder pattern)
  /// - `if (!(x == null)) { x! }` (negated null check)
  bool _isInSafeIfBlock(PostfixExpression node) {
    final String assertedExpr = _getBaseExpression(node.operand);

    // Walk up to find enclosing if statements or if elements
    AstNode? current = node.parent;
    while (current != null) {
      if (current is IfStatement) {
        final Expression condition = current.expression;

        // Check for negated condition: `if (!(x == null)) { x! }`
        if (condition is PrefixExpression && condition.operator.lexeme == '!') {
          final Expression inner = condition.operand;
          // `if (!(x == null))` is equivalent to `if (x != null)`
          if (inner is ParenthesizedExpression) {
            final Expression innerExpr = inner.expression;
            if (innerExpr is BinaryExpression) {
              final String? checkedExpr = _getNullCheckedExpression(innerExpr);
              if (checkedExpr != null && checkedExpr == assertedExpr) {
                // `if (!(x == null)) { x! }` - safe in then branch
                if (innerExpr.operator.lexeme == '==' &&
                    _isInThenBranch(current, node)) {
                  return true;
                }
                // `if (!(x != null)) return; x!` - safe after early return
                if (innerExpr.operator.lexeme == '!=' &&
                    _isAfterEarlyReturn(current, node)) {
                  return true;
                }
              }
            }
          }
        }

        // Check for `if (x != null)` pattern
        if (condition is BinaryExpression) {
          final String? checkedExpr = _getNullCheckedExpression(condition);
          if (checkedExpr != null && checkedExpr == assertedExpr) {
            // `if (x != null) { x! }` - safe in then branch
            if (condition.operator.lexeme == '!=' &&
                _isInThenBranch(current, node)) {
              return true;
            }
            // `if (x == null) return; x!` - safe after the if
            if (condition.operator.lexeme == '==' &&
                _isAfterEarlyReturn(current, node)) {
              return true;
            }
          }

          // Check for compound && conditions: `if (a && x != null) { x! }`
          if (condition.operator.lexeme == '&&') {
            if (_containsNonNullCheckFor(condition, assertedExpr) &&
                _isInThenBranch(current, node)) {
              return true;
            }
          }

          // Check for compound || conditions with early return:
          // `if (a || x == null) return; x!`
          if (condition.operator.lexeme == '||') {
            if (_containsNullCheckFor(condition, assertedExpr) &&
                _isAfterEarlyReturn(current, node)) {
              return true;
            }
          }

          // Check for `if (x?.prop == value)` or `if (x!.prop == value)` patterns
          // If condition uses x?. or x!. and compares to non-null, x! in body is safe
          if (_isNullPropagatingGuard(condition, assertedExpr) &&
              _isInThenBranch(current, node)) {
            return true;
          }
        }

        // Check for truthy/falsy null-check extension methods
        // Truthy (isNotEmpty): safe in then branch
        // Falsy (isEmpty): safe in else branch
        final String? methodName = _getExtensionMethodName(condition);
        if (methodName != null) {
          final String? target = _getExtensionMethodTarget(condition);
          if (target == assertedExpr) {
            // Truthy check: `if (x.isNotEmpty) { x! }` - safe in then branch
            if (_truthyNullCheckNames.contains(methodName) &&
                _isInThenBranch(current, node)) {
              return true;
            }
            // Falsy check: `if (x.isEmpty) { } else { x! }` - safe in else branch
            if (_falsyNullCheckNames.contains(methodName) &&
                _isInElseBranch(current, node)) {
              return true;
            }
          }
        }

        // Check for Flutter async builder patterns:
        // `if (snapshot.hasData) { snapshot.data! }`
        // `if (!snapshot.hasData || snapshot.data == null) return; snapshot.data!`
        if (_isFlutterAsyncGuard(condition, assertedExpr, current, node)) {
          return true;
        }
      }

      // Handle while loops: `while (x != null) { x! }`
      if (current is WhileStatement) {
        final Expression condition = current.condition;
        if (_isNonNullGuardCondition(condition, assertedExpr) &&
            _containsNode(current.body, node)) {
          return true;
        }
      }

      // Handle do-while loops: `do { x! } while (x != null)` is NOT safe
      // (body executes before condition check)

      // Handle for loops: `for (; x != null; ) { x! }`
      if (current is ForStatement) {
        final ForLoopParts forLoopParts = current.forLoopParts;
        Expression? condition;
        if (forLoopParts is ForParts) {
          condition = forLoopParts.condition;
        }
        if (condition != null &&
            _isNonNullGuardCondition(condition, assertedExpr) &&
            _containsNode(current.body, node)) {
          return true;
        }
      }

      // Handle IfElement in collection literals: [if (x != null) x!]
      if (current is IfElement) {
        final Expression condition = current.expression;

        // Check for `if (x != null) x!` pattern in collection
        if (condition is BinaryExpression) {
          final String? checkedExpr = _getNullCheckedExpression(condition);
          if (checkedExpr != null && checkedExpr == assertedExpr) {
            // `if (x != null) x!` - safe in then element
            if (condition.operator.lexeme == '!=' &&
                _containsNode(current.thenElement, node)) {
              return true;
            }
            // `if (x == null) ... else x!` - safe in else element
            final CollectionElement? elseElement = current.elseElement;
            if (condition.operator.lexeme == '==' &&
                elseElement != null &&
                _containsNode(elseElement, node)) {
              return true;
            }
          }
        }

        // Check for truthy/falsy null-check extension methods in collection
        final String? methodName = _getExtensionMethodName(condition);
        if (methodName != null) {
          final String? target = _getExtensionMethodTarget(condition);
          if (target == assertedExpr) {
            // Truthy check: `[if (x.isNotEmpty) x!]` - safe in then element
            if (_truthyNullCheckNames.contains(methodName) &&
                _containsNode(current.thenElement, node)) {
              return true;
            }
            // Falsy check: `[if (x.isEmpty) fallback else x!]` - safe in else
            final CollectionElement? elseElement = current.elseElement;
            if (_falsyNullCheckNames.contains(methodName) &&
                elseElement != null &&
                _containsNode(elseElement, node)) {
              return true;
            }
          }
        }
      }

      current = current.parent;
    }
    return false;
  }

  /// Gets the base expression string (for comparison).
  /// For `widget.callback`, returns `widget.callback`.
  /// For `list?.first`, returns `list`.
  String _getBaseExpression(Expression expr) {
    // Remove any trailing ?. chains for comparison
    final String source = expr.toSource();
    // Normalize by removing trailing ?
    return source.replaceAll('?', '');
  }

  /// Extracts the expression being null-checked from a binary expression.
  /// Returns null if not a null check pattern.
  String? _getNullCheckedExpression(BinaryExpression expr) {
    final String op = expr.operator.lexeme;
    if (op != '==' && op != '!=') return null;

    final Expression left = expr.leftOperand;
    final Expression right = expr.rightOperand;

    if (right is NullLiteral) {
      return _getBaseExpression(left);
    }
    if (left is NullLiteral) {
      return _getBaseExpression(right);
    }
    return null;
  }

  /// Checks if condition uses null-propagating access on the asserted expression.
  ///
  /// Safe patterns:
  /// - `if (x?.length == 1) { x!.first }` - if x is null, condition is false
  /// - `if (x!.length == 1) { x!.first }` - if we got here, x! succeeded
  /// - `if (x?.prop != null) { x!.prop }` - explicit non-null comparison
  ///
  /// The key insight: if `x?.something == nonNullValue` is true, x cannot be null.
  /// Similarly, if `x!.something` didn't throw, x was not null.
  bool _isNullPropagatingGuard(
    BinaryExpression condition,
    String assertedExpr,
  ) {
    final Expression left = condition.leftOperand;
    final Expression right = condition.rightOperand;
    final String op = condition.operator.lexeme;

    // We need: left uses x?. or x!., and right is non-null, and op is == or !=
    // For ==: if comparing to non-null value, x must be non-null for it to be true
    // For !=: if comparing to null and result is true, x is non-null

    // Check if left operand starts with our expression using ?. or !.
    final String? guardedExpr = _extractNullAwareTarget(left);
    if (guardedExpr == null || guardedExpr != assertedExpr) {
      return false;
    }

    // For `x?.prop == nonNullValue` - if true, x is not null
    if (op == '==' && right is! NullLiteral) {
      return true;
    }

    // For `x?.prop != null` - if true, x is not null
    if (op == '!=' && right is NullLiteral) {
      return true;
    }

    // For numeric comparisons like `x?.length > 0`
    if ((op == '>' || op == '>=' || op == '<' || op == '<=') &&
        right is IntegerLiteral) {
      return true;
    }

    return false;
  }

  /// Extracts the base expression from a null-aware or force-unwrap chain.
  ///
  /// For `widget.items?.length`, returns `widget.items`
  /// For `widget.items!.length`, returns `widget.items`
  /// For `x?.foo?.bar`, returns `x`
  String? _extractNullAwareTarget(Expression expr) {
    if (expr is PropertyAccess) {
      // e.g., widget.items?.length or widget.items!.length
      final Expression? target = expr.target;
      if (target == null) return null;

      // Check if this is a null-aware or force-unwrap access
      if (expr.operator.type == TokenType.QUESTION_PERIOD) {
        // x?.prop - return the target
        return _getBaseExpression(target);
      }
      // Regular property access - check if target is null-aware
      if (target is PostfixExpression && target.operator.lexeme == '!') {
        // x!.prop - return x
        return _getBaseExpression(target.operand);
      }
      // Recurse to find nested null-aware access
      return _extractNullAwareTarget(target);
    }

    if (expr is MethodInvocation) {
      // e.g., widget.items?.map(...)
      final Expression? target = expr.target;
      if (target == null) return null;

      if (expr.operator?.type == TokenType.QUESTION_PERIOD) {
        return _getBaseExpression(target);
      }
      if (target is PostfixExpression && target.operator.lexeme == '!') {
        return _getBaseExpression(target.operand);
      }
      return _extractNullAwareTarget(target);
    }

    if (expr is IndexExpression) {
      // e.g., x?[0]
      final Expression? target = expr.target;
      if (target == null) return null;

      if (expr.question != null) {
        return _getBaseExpression(target);
      }
      if (target is PostfixExpression && target.operator.lexeme == '!') {
        return _getBaseExpression(target.operand);
      }
      return _extractNullAwareTarget(target);
    }

    if (expr is PrefixedIdentifier) {
      // e.g., widget.items (simple property access, no ?.)
      // This doesn't have null-aware operator, but we might have
      // cases like `items!.length` where items is a simple identifier
      return null;
    }

    return null;
  }

  /// Checks if an AST node contains another node by traversing the tree.
  bool _containsNode(AstNode container, AstNode target) {
    if (container == target) return true;
    final _NodeContainsFinder finder = _NodeContainsFinder(target);
    container.visitChildren(finder);
    return finder.found;
  }

  /// Checks if the node is in the then-branch of an if statement.
  bool _isInThenBranch(IfStatement ifStmt, AstNode node) {
    return _containsNode(ifStmt.thenStatement, node);
  }

  /// Checks if the node is in the else-branch of an if statement.
  bool _isInElseBranch(IfStatement ifStmt, AstNode node) {
    final Statement? elseStmt = ifStmt.elseStatement;
    if (elseStmt == null) return false;
    return _containsNode(elseStmt, node);
  }

  /// Extracts the extension method/property name from a condition expression.
  /// Returns the method/property name for MethodInvocation, PrefixedIdentifier,
  /// or PropertyAccess.
  String? _getExtensionMethodName(Expression condition) {
    if (condition is MethodInvocation) {
      return condition.methodName.name;
    }
    if (condition is PrefixedIdentifier) {
      return condition.identifier.name;
    }
    if (condition is PropertyAccess) {
      return condition.propertyName.name;
    }
    return null;
  }

  /// Extracts the target expression from an extension method call.
  /// Returns the base expression string that the method is called on.
  String? _getExtensionMethodTarget(Expression condition) {
    if (condition is MethodInvocation) {
      final Expression? target = condition.target;
      if (target == null) return null;
      return _getBaseExpression(target);
    }
    if (condition is PrefixedIdentifier) {
      return _getBaseExpression(condition.prefix);
    }
    if (condition is PropertyAccess) {
      final Expression? target = condition.target;
      if (target == null) return null;
      return _getBaseExpression(target);
    }
    return null;
  }

  /// Checks if the node comes after an early return in the if statement.
  bool _isAfterEarlyReturn(IfStatement ifStmt, AstNode node) {
    final Statement thenStmt = ifStmt.thenStatement;

    // Check if then branch is an early exit (return, throw, break, continue)
    bool isEarlyExit = false;
    if (thenStmt is ReturnStatement) {
      isEarlyExit = true;
    } else if (thenStmt is ExpressionStatement &&
        thenStmt.expression is ThrowExpression) {
      isEarlyExit = true;
    } else if (thenStmt is Block && thenStmt.statements.isNotEmpty) {
      final Statement lastStmt = thenStmt.statements.last;
      if (lastStmt is ReturnStatement) {
        isEarlyExit = true;
      } else if (lastStmt is ExpressionStatement &&
          lastStmt.expression is ThrowExpression) {
        isEarlyExit = true;
      }
    }

    if (!isEarlyExit) return false;

    // The node should NOT be in the then branch
    return !_containsNode(ifStmt.thenStatement, node);
  }

  /// Recursively checks if a compound && condition contains a non-null check
  /// for the given expression.
  ///
  /// Handles: `if (a && x != null) { x! }` or `if (a && b && x != null) { x! }`
  bool _containsNonNullCheckFor(Expression condition, String assertedExpr) {
    if (condition is BinaryExpression) {
      final String op = condition.operator.lexeme;

      // Direct non-null check: `x != null`
      if (op == '!=') {
        final String? checkedExpr = _getNullCheckedExpression(condition);
        if (checkedExpr == assertedExpr) {
          return true;
        }
      }

      // Recurse into && operands
      if (op == '&&') {
        return _containsNonNullCheckFor(condition.leftOperand, assertedExpr) ||
            _containsNonNullCheckFor(condition.rightOperand, assertedExpr);
      }
    }

    // Check for truthy extension methods: `x.isNotEmpty && ...`
    final String? methodName = _getExtensionMethodName(condition);
    if (methodName != null && _truthyNullCheckNames.contains(methodName)) {
      final String? target = _getExtensionMethodTarget(condition);
      if (target == assertedExpr) {
        return true;
      }
    }

    return false;
  }

  /// Recursively checks if a compound || condition contains a null check
  /// for the given expression.
  ///
  /// Handles: `if (a || x == null) return; x!` or `if (a || b || x == null) return; x!`
  bool _containsNullCheckFor(Expression condition, String assertedExpr) {
    if (condition is BinaryExpression) {
      final String op = condition.operator.lexeme;

      // Direct null check: `x == null`
      if (op == '==') {
        final String? checkedExpr = _getNullCheckedExpression(condition);
        if (checkedExpr == assertedExpr) {
          return true;
        }
      }

      // Recurse into || operands
      if (op == '||') {
        return _containsNullCheckFor(condition.leftOperand, assertedExpr) ||
            _containsNullCheckFor(condition.rightOperand, assertedExpr);
      }
    }

    // Check for negated truthy check: `!x.isNotEmpty` (equivalent to x.isEmpty)
    if (condition is PrefixExpression && condition.operator.lexeme == '!') {
      final Expression inner = condition.operand;
      final String? methodName = _getExtensionMethodName(inner);
      if (methodName != null && _truthyNullCheckNames.contains(methodName)) {
        final String? target = _getExtensionMethodTarget(inner);
        if (target == assertedExpr) {
          return true;
        }
      }
    }

    // Check for falsy extension methods: `x.isEmpty || ...`
    final String? methodName = _getExtensionMethodName(condition);
    if (methodName != null && _falsyNullCheckNames.contains(methodName)) {
      final String? target = _getExtensionMethodTarget(condition);
      if (target == assertedExpr) {
        return true;
      }
    }

    return false;
  }

  /// Checks if condition is a non-null guard for the given expression.
  ///
  /// Returns true for:
  /// - `x != null`
  /// - `x.isNotEmpty`
  /// - `a && x != null`
  bool _isNonNullGuardCondition(Expression condition, String assertedExpr) {
    if (condition is BinaryExpression) {
      final String op = condition.operator.lexeme;

      // Direct non-null check
      if (op == '!=') {
        final String? checkedExpr = _getNullCheckedExpression(condition);
        if (checkedExpr == assertedExpr) {
          return true;
        }
      }

      // Compound condition
      if (op == '&&') {
        return _containsNonNullCheckFor(condition, assertedExpr);
      }
    }

    // Truthy extension methods
    final String? methodName = _getExtensionMethodName(condition);
    if (methodName != null && _truthyNullCheckNames.contains(methodName)) {
      final String? target = _getExtensionMethodTarget(condition);
      if (target == assertedExpr) {
        return true;
      }
    }

    return false;
  }

  /// Checks for Flutter async builder patterns where a property check guards
  /// a related nullable property.
  ///
  /// Patterns:
  /// - `if (snapshot.hasData) { snapshot.data! }` - hasData implies data != null
  /// - `if (snapshot.hasError) { snapshot.error! }` - hasError implies error != null
  /// - `if (!snapshot.hasData) return; snapshot.data!` - negated early return
  /// - `if (!snapshot.hasData || snapshot.data == null) return; snapshot.data!`
  bool _isFlutterAsyncGuard(
    Expression condition,
    String assertedExpr,
    IfStatement ifStmt,
    AstNode node,
  ) {
    // Map of "hasX" properties to their corresponding nullable properties
    const Map<String, String> hasPropertyMap = <String, String>{
      'hasData': 'data',
      'hasError': 'error',
      'hasValue': 'value',
    };

    // Extract the property being asserted (e.g., "data" from "snapshot.data")
    final int lastDot = assertedExpr.lastIndexOf('.');
    if (lastDot == -1) return false;

    final String targetBase = assertedExpr.substring(0, lastDot);
    final String assertedProp = assertedExpr.substring(lastDot + 1);

    // Find which "has" property would guard this
    String? guardProperty;
    for (final MapEntry<String, String> entry in hasPropertyMap.entries) {
      if (entry.value == assertedProp) {
        guardProperty = entry.key;
        break;
      }
    }
    if (guardProperty == null) return false;

    // Check for `if (snapshot.hasData) { snapshot.data! }`
    final String? methodName = _getExtensionMethodName(condition);
    final String? condTarget = _getExtensionMethodTarget(condition);

    if (methodName == guardProperty && condTarget == targetBase) {
      if (_isInThenBranch(ifStmt, node)) {
        return true;
      }
    }

    // Check for negated pattern: `if (!snapshot.hasData) return; snapshot.data!`
    if (condition is PrefixExpression && condition.operator.lexeme == '!') {
      final Expression inner = condition.operand;
      final String? innerMethod = _getExtensionMethodName(inner);
      final String? innerTarget = _getExtensionMethodTarget(inner);

      if (innerMethod == guardProperty && innerTarget == targetBase) {
        if (_isAfterEarlyReturn(ifStmt, node)) {
          return true;
        }
      }
    }

    // Check for compound || with negated hasData and explicit null check:
    // `if (!snapshot.hasData || snapshot.data == null) return;`
    if (condition is BinaryExpression && condition.operator.lexeme == '||') {
      // Check if either operand guards the property
      if (_containsNullCheckFor(condition, assertedExpr) &&
          _isAfterEarlyReturn(ifStmt, node)) {
        return true;
      }

      // Also check for negated hasData in the || chain
      if (_containsNegatedHasCheck(condition, targetBase, guardProperty) &&
          _isAfterEarlyReturn(ifStmt, node)) {
        return true;
      }
    }

    return false;
  }

  /// Checks if an || chain contains a negated "has" property check.
  ///
  /// E.g., `!snapshot.hasData` in `!snapshot.hasData || snapshot.data == null`
  bool _containsNegatedHasCheck(
    Expression condition,
    String targetBase,
    String guardProperty,
  ) {
    if (condition is PrefixExpression && condition.operator.lexeme == '!') {
      final Expression inner = condition.operand;
      final String? innerMethod = _getExtensionMethodName(inner);
      final String? innerTarget = _getExtensionMethodTarget(inner);

      if (innerMethod == guardProperty && innerTarget == targetBase) {
        return true;
      }
    }

    if (condition is BinaryExpression && condition.operator.lexeme == '||') {
      return _containsNegatedHasCheck(
            condition.leftOperand,
            targetBase,
            guardProperty,
          ) ||
          _containsNegatedHasCheck(
            condition.rightOperand,
            targetBase,
            guardProperty,
          );
    }

    return false;
  }

  /// Checks if the null assertion is safe due to short-circuit evaluation.
  ///
  /// Safe patterns:
  /// - `x == null || x!.length` - if x is null, right side won't execute
  /// - `x.isListNullOrEmpty || x!.length` - same short-circuit logic
  /// - `x != null && x!.length` - if x is null, right side won't execute
  /// - Ternary conditions: `(x == null || x!.length > 0) ? a : b`
  bool _isInShortCircuitSafe(PostfixExpression node) {
    final String assertedExpr = _getBaseExpression(node.operand);

    // Walk up to find enclosing binary expression with || or &&
    AstNode? current = node.parent;
    while (current != null) {
      if (current is BinaryExpression) {
        final String op = current.operator.lexeme;

        if (op == '||') {
          // For ||, check if left side is a null check and node is on right
          if (_isNullCheckOnLeft(current.leftOperand, assertedExpr) &&
              _containsNode(current.rightOperand, node)) {
            return true;
          }
        } else if (op == '&&') {
          // For &&, check if left side is a non-null check and node is on right
          if (_isNonNullCheckOnLeft(current.leftOperand, assertedExpr) &&
              _containsNode(current.rightOperand, node)) {
            return true;
          }
        }
      }
      current = current.parent;
    }
    return false;
  }

  /// Checks if the expression is a null check for the given variable.
  /// Returns true for: `x == null`, `x.isListNullOrEmpty`, `x.isNullOrEmpty`
  bool _isNullCheckOnLeft(Expression expr, String assertedExpr) {
    // Direct null check: `x == null`
    if (expr is BinaryExpression && expr.operator.lexeme == '==') {
      if (expr.rightOperand is NullLiteral) {
        return _getBaseExpression(expr.leftOperand) == assertedExpr;
      }
      if (expr.leftOperand is NullLiteral) {
        return _getBaseExpression(expr.rightOperand) == assertedExpr;
      }
    }

    // Extension method check: `x.isListNullOrEmpty`, `x.isNullOrEmpty`
    if (expr is MethodInvocation) {
      final String methodName = expr.methodName.name;
      if (_nullCheckNames.contains(methodName)) {
        final Expression? target = expr.target;
        if (target != null && _getBaseExpression(target) == assertedExpr) {
          return true;
        }
      }
    }

    // Property access: `x.isListNullOrEmpty`
    if (expr is PrefixedIdentifier) {
      final String propertyName = expr.identifier.name;
      if (_nullCheckNames.contains(propertyName)) {
        return _getBaseExpression(expr.prefix) == assertedExpr;
      }
    }

    if (expr is PropertyAccess) {
      final String propertyName = expr.propertyName.name;
      if (_nullCheckNames.contains(propertyName)) {
        final Expression? target = expr.target;
        if (target != null && _getBaseExpression(target) == assertedExpr) {
          return true;
        }
      }
    }

    // Recurse into nested || on the left side
    // e.g., `a == null || b == null || x == null || x!.foo`
    if (expr is BinaryExpression && expr.operator.lexeme == '||') {
      if (_isNullCheckOnLeft(expr.leftOperand, assertedExpr) ||
          _isNullCheckOnLeft(expr.rightOperand, assertedExpr)) {
        return true;
      }
    }

    return false;
  }

  /// Checks if the expression is a non-null check for the given variable.
  /// Returns true for: `x != null`, `x.isNotNullOrEmpty`
  bool _isNonNullCheckOnLeft(Expression expr, String assertedExpr) {
    // Direct non-null check: `x != null`
    if (expr is BinaryExpression && expr.operator.lexeme == '!=') {
      if (expr.rightOperand is NullLiteral) {
        return _getBaseExpression(expr.leftOperand) == assertedExpr;
      }
      if (expr.leftOperand is NullLiteral) {
        return _getBaseExpression(expr.rightOperand) == assertedExpr;
      }
    }

    // Extension method check: `x.isNotNullOrEmpty`
    if (expr is MethodInvocation) {
      final String methodName = expr.methodName.name;
      if (_truthyNullCheckNames.contains(methodName)) {
        final Expression? target = expr.target;
        if (target != null && _getBaseExpression(target) == assertedExpr) {
          return true;
        }
      }
    }

    // Property access: `x.isNotNullOrEmpty`
    if (expr is PrefixedIdentifier) {
      final String propertyName = expr.identifier.name;
      if (_truthyNullCheckNames.contains(propertyName)) {
        return _getBaseExpression(expr.prefix) == assertedExpr;
      }
    }

    if (expr is PropertyAccess) {
      final String propertyName = expr.propertyName.name;
      if (_truthyNullCheckNames.contains(propertyName)) {
        final Expression? target = expr.target;
        if (target != null && _getBaseExpression(target) == assertedExpr) {
          return true;
        }
      }
    }

    // Recurse into nested && on the left side
    if (expr is BinaryExpression && expr.operator.lexeme == '&&') {
      if (_isNonNullCheckOnLeft(expr.leftOperand, assertedExpr) ||
          _isNonNullCheckOnLeft(expr.rightOperand, assertedExpr)) {
        return true;
      }
    }

    return false;
  }
}

/// Quick fix to convert `x!.prop` to `x?.prop` in conditions.
///
/// This is useful when the null assertion is used in a condition that
/// would make the body safe anyway. For example:
/// ```dart
/// // Before:
/// if (widget.items!.length == 1) { widget.items!.first }
///
/// // After applying fix to condition:
/// if (widget.items?.length == 1) { widget.items!.first }
/// ```

/// Helper visitor to find if a target node exists within a container.
class _NodeContainsFinder extends GeneralizingAstVisitor<void> {
  _NodeContainsFinder(this.target);

  final AstNode target;
  bool found = false;

  @override
  void visitNode(AstNode node) {
    if (found) return;
    if (node == target) {
      found = true;
      return;
    }
    super.visitNode(node);
  }
}

/// Warns when a type assertion (is check) is unnecessary.
///
/// Since: v1.7.2 | Updated: v4.13.0 | Rule version: v2
///
/// Redundant `is` checks occur when the type is already known statically.
///
/// Example of **bad** code:
/// ```dart
/// final String x = 'hello';
/// if (x is String) { ... }  // Always true
/// ```
///
/// Example of **good** code:
/// ```dart
/// final Object x = getValue();
/// if (x is String) { ... }  // Useful check
/// ```
class AvoidUnnecessaryTypeAssertionsRule extends SaropaLintRule {
  AvoidUnnecessaryTypeAssertionsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.high;

  static const LintCode _code = LintCode(
    'avoid_unnecessary_type_assertions',
    '[avoid_unnecessary_type_assertions] Unnecessary type assertion. '
        'The expression is already known to be of this type. {v2}',
    correctionMessage: 'Remove the redundant type check.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addIsExpression((IsExpression node) {
      final DartType? expressionType = node.expression.staticType;
      final DartType? testedType = node.type.type;

      if (expressionType == null || testedType == null) return;

      // If the expression is already a subtype of the tested type,
      // the check is always true (unless negated)
      if (!node.notOperator.toString().contains('!')) {
        // Positive is check - check if types are exactly equal
        // (simplified check without TypeSystem)
        if (expressionType == testedType) {
          reporter.atNode(node);
        }
        // Also check by name for common cases
        final String exprTypeName = expressionType.getDisplayString();
        final String testedTypeName = testedType.getDisplayString();
        if (exprTypeName == testedTypeName &&
            !testedType.isDartCoreObject &&
            testedTypeName != 'dynamic') {
          reporter.atNode(node);
        }
      }
    });
  }
}

/// Warns when a type cast (as) is unnecessary.
///
/// Since: v1.7.2 | Updated: v4.13.0 | Rule version: v2
///
/// Redundant `as` casts occur when the expression is already of the target type.
///
/// Example of **bad** code:
/// ```dart
/// final String x = 'hello';
/// final y = x as String;  // Unnecessary cast
/// ```
///
/// Example of **good** code:
/// ```dart
/// final Object x = getValue();
/// final y = x as String;  // Necessary cast
/// ```
class AvoidUnnecessaryTypeCastsRule extends SaropaLintRule {
  AvoidUnnecessaryTypeCastsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.high;

  static const LintCode _code = LintCode(
    'avoid_unnecessary_type_casts',
    '[avoid_unnecessary_type_casts] Unnecessary type cast. '
        'The expression is already of this type. {v2}',
    correctionMessage: 'Remove the redundant cast.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addAsExpression((AsExpression node) {
      final DartType? expressionType = node.expression.staticType;
      final DartType? castType = node.type.type;

      if (expressionType == null || castType == null) return;

      // If the expression type equals the cast type, the cast is redundant
      if (expressionType == castType) {
        reporter.atNode(node);
        return;
      }

      // Also check by display name for common cases
      final String exprTypeName = expressionType.getDisplayString();
      final String castTypeName = castType.getDisplayString();
      if (exprTypeName == castTypeName &&
          !castType.isDartCoreObject &&
          castTypeName != 'dynamic') {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when an 'is' type check can never be true.
///
/// Since: v1.7.2 | Updated: v4.13.0 | Rule version: v2
///
/// This catches impossible type assertions where the expression type
/// and tested type have no relationship.
///
/// Example of **bad** code:
/// ```dart
/// int x = 5;
/// if (x is String) { ... }  // Always false
/// ```
///
/// Example of **good** code:
/// ```dart
/// Object x = getValue();
/// if (x is String) { ... }  // Could be true
/// ```
///
/// **Quick fix available:** Adds a comment to flag for manual review.
class AvoidUnrelatedTypeAssertionsRule extends SaropaLintRule {
  AvoidUnrelatedTypeAssertionsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.high;

  static const LintCode _code = LintCode(
    'avoid_unrelated_type_assertions',
    '[avoid_unrelated_type_assertions] Type assertion can never be true. '
        'The types are unrelated. {v2}',
    correctionMessage: 'Remove the impossible type check or fix the types.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addIsExpression((IsExpression node) {
      final DartType? expressionType = node.expression.staticType;
      final DartType? testedType = node.type.type;

      if (expressionType == null || testedType == null) return;

      // Skip if either is dynamic or Object (always possible)
      if (expressionType.isDartCoreObject || testedType.isDartCoreObject) {
        return;
      }
      final String exprStr = expressionType.getDisplayString();
      final String testedStr = testedType.getDisplayString();
      if (exprStr == 'dynamic' || testedStr == 'dynamic') {
        return;
      }

      // Check for unrelated primitive types
      final bool exprIsPrimitive = _isPrimitiveType(exprStr);
      final bool testedIsPrimitive = _isPrimitiveType(testedStr);

      if (exprIsPrimitive && testedIsPrimitive && exprStr != testedStr) {
        // Check for num relationships
        if ((exprStr == 'int' || exprStr == 'double') && testedStr == 'num') {
          return; // int/double is num
        }
        if (exprStr == 'num' && (testedStr == 'int' || testedStr == 'double')) {
          return; // num could be int/double
        }
        reporter.atNode(node);
      }
    });
  }

  bool _isPrimitiveType(String typeName) {
    return const <String>{
      'int',
      'double',
      'num',
      'String',
      'bool',
    }.contains(typeName);
  }
}

/// Warns when type names don't follow Dart conventions.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Type names should be UpperCamelCase.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// class my_class { }
/// typedef myCallback = void Function();
/// ```
///
/// #### GOOD:
/// ```dart
/// class MyClass { }
/// typedef MyCallback = void Function();
/// ```
///
/// **Quick fix available:** Adds a comment to flag for manual review.
class PreferCorrectTypeNameRule extends SaropaLintRule {
  PreferCorrectTypeNameRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_correct_type_name',
    '[prefer_correct_type_name] Type name is not UpperCamelCase. Nonstandard type names reduce code readability and break Dart conventions. Quick fix available: Adds a comment to flag for manual review. {v4}',
    correctionMessage:
        'Rename type to use UpperCamelCase. Example: MyType, UserProfile, HttpClient. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    void checkName(Token nameToken) {
      final String name = nameToken.lexeme;
      if (name.isEmpty) return;

      // Skip private types (checked elsewhere)
      if (name.startsWith('_')) {
        final String publicPart = name.substring(1);
        if (publicPart.isNotEmpty && !_isUpperCamelCase(publicPart)) {
          reporter.atToken(nameToken);
        }
        return;
      }

      if (!_isUpperCamelCase(name)) {
        reporter.atToken(nameToken);
      }
    }

    context.addClassDeclaration((ClassDeclaration node) {
      checkName(node.name);
    });

    context.addMixinDeclaration((MixinDeclaration node) {
      checkName(node.name);
    });

    context.addEnumDeclaration((EnumDeclaration node) {
      checkName(node.name);
    });

    context.addExtensionTypeDeclaration((ExtensionTypeDeclaration node) {
      checkName(node.name);
    });

    context.addGenericTypeAlias((GenericTypeAlias node) {
      checkName(node.name);
    });
  }

  bool _isUpperCamelCase(String name) {
    if (name.isEmpty) return false;

    // Must start with uppercase
    if (!name[0].toUpperCase().contains(name[0])) return false;

    // Should not contain underscores (except for private prefix)
    if (name.contains('_')) return false;

    // Should not be all uppercase (that's SCREAMING_CASE)
    if (name == name.toUpperCase() && name.length > 1) return false;

    return true;
  }
}

/// Warns when using bare 'Function' type instead of specific function type.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// The bare 'Function' type is too permissive and loses type information.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// void execute(Function callback) { ... }
/// Function? handler;
/// ```
///
/// #### GOOD:
/// ```dart
/// void execute(void Function() callback) { ... }
/// void Function(String)? handler;
/// ```
class PreferExplicitFunctionTypeRule extends SaropaLintRule {
  PreferExplicitFunctionTypeRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_explicit_function_type',
    '[prefer_explicit_function_type] Use explicit function type instead of bare "Function". The bare \'Function\' type is too permissive and loses type information. Using bare \'Function\' type instead of specific function type. {v5}',
    correctionMessage:
        'Specify the function signature (e.g., void Function()). Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addNamedType((NamedType node) {
      final String name = node.name.lexeme;
      if (name == 'Function') {
        // Check if it's the bare Function type (no type arguments)
        if (node.typeArguments == null) {
          reporter.atNode(node);
        }
      }
    });
  }
}

/// Warns when `var` is used instead of explicit type.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// **Stylistic rule (opt-in only).** Conflicts with prefer_var_over_explicit_type. No performance or correctness benefit.
///
/// Explicit types improve code readability and catch type errors earlier.
///
/// Example of **bad** code:
/// ```dart
/// var name = 'John';
/// var count = 42;
/// ```
///
/// Example of **good** code:
/// ```dart
/// String name = 'John';
/// int count = 42;
/// // or use final for immutable values
/// final String name = 'John';
/// ```
class PreferTypeOverVarRule extends SaropaLintRule {
  PreferTypeOverVarRule() : super(code: _code);

  /// Stylistic preference only. Conflicts with prefer_var_over_explicit_type.
  @override
  LintImpact get impact => LintImpact.opinionated;

  static const LintCode _code = LintCode(
    'prefer_type_over_var',
    '[prefer_type_over_var] Preferring explicit type annotations over var is a style choice. Both produce identical compiled code. Conflicts with prefer_var_over_explicit_type. Enable via the stylistic tier. {v4}',
    correctionMessage:
        'Replace var with the explicit type. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addVariableDeclarationList((VariableDeclarationList node) {
      // Check if using var (no type annotation and not final/const)
      if (node.type == null && node.keyword?.lexeme == 'var') {
        reporter.atNode(node);
      }
    });
  }
}
