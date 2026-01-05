// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Warns when casting to an extension type.
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
class AvoidCastingToExtensionTypeRule extends DartLintRule {
  const AvoidCastingToExtensionTypeRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_casting_to_extension_type',
    problemMessage: 'Avoid casting to extension types.',
    correctionMessage: 'Use the extension type constructor instead of casting.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addAsExpression((AsExpression node) {
      // Check if target type is an extension type
      final TypeAnnotation typeAnnotation = node.type;

      // Extension types show as their representation type in staticType
      // but the annotation is a NamedType pointing to the extension
      if (typeAnnotation is NamedType) {
        final Element? element = typeAnnotation.element;
        if (element != null && element.toString().contains('extension type')) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when using collection methods with unrelated types.
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
class AvoidCollectionMethodsWithUnrelatedTypesRule extends DartLintRule {
  const AvoidCollectionMethodsWithUnrelatedTypesRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_collection_methods_with_unrelated_types',
    problemMessage: 'Collection method called with unrelated type.',
    correctionMessage: 'The argument type cannot match any element in the collection.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _collectionMethods = <String>{
    'contains',
    'indexOf',
    'lastIndexOf',
    'remove',
    'lookup',
  };

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
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
    if (type1 == 'dynamic' || type2 == 'dynamic' || type1 == 'Object' || type2 == 'Object') {
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
/// Using dynamic bypasses the type system and can lead to runtime errors.
/// Prefer using specific types or generics.
class AvoidDynamicRule extends DartLintRule {
  const AvoidDynamicRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_dynamic',
    problemMessage: "Avoid using 'dynamic' type.",
    correctionMessage: 'Use a specific type, Object, or a generic type instead.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addNamedType((NamedType node) {
      if (node.name.lexeme == 'dynamic') {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when extension type doesn't implement Object and is implicitly nullable.
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
class AvoidImplicitlyNullableExtensionTypesRule extends DartLintRule {
  const AvoidImplicitlyNullableExtensionTypesRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_implicitly_nullable_extension_types',
    problemMessage: 'Extension type is implicitly nullable.',
    correctionMessage: 'Add "implements Object" to make it non-nullable.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addExtensionTypeDeclaration((ExtensionTypeDeclaration node) {
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
class AvoidNullableInterpolationRule extends DartLintRule {
  const AvoidNullableInterpolationRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_nullable_interpolation',
    problemMessage: 'Avoid interpolating nullable values.',
    correctionMessage: 'Add null check or use ?? to provide default value.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInterpolationExpression((InterpolationExpression node) {
      final Expression expr = node.expression;
      final DartType? type = expr.staticType;
      if (type == null) return;

      if (type.nullabilitySuffix == NullabilitySuffix.question) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when nullable parameters have default values that could be non-null.
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
class AvoidNullableParametersWithDefaultValuesRule extends DartLintRule {
  const AvoidNullableParametersWithDefaultValuesRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_nullable_parameters_with_default_values',
    problemMessage: 'Parameter with default value should not be nullable.',
    correctionMessage: 'Remove the ? from the type since it has a non-null default.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addDefaultFormalParameter((DefaultFormalParameter node) {
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
        reporter.atNode(typeAnnotation, code);
      }
    });
  }
}

/// Warns when calling `.toString()` on a nullable value without null check.
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
class AvoidNullableToStringRule extends DartLintRule {
  const AvoidNullableToStringRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_nullable_tostring',
    problemMessage: 'Calling toString() on a nullable value.',
    correctionMessage: 'Check for null first or provide a default value.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
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
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when the null assertion operator (!) is used.
///
/// The bang operator can cause runtime crashes when the value is unexpectedly null.
/// Use null-safe alternatives instead:
/// - `variable ?? defaultValue` - provide a default
/// - `if (variable != null) { ... }` - null check first
/// - `variable?.property` - optional chaining
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
/// ```
class AvoidNullAssertionRule extends DartLintRule {
  const AvoidNullAssertionRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_null_assertion',
    problemMessage: 'Avoid using the null assertion operator (!). '
        'It can cause runtime crashes if the value is null.',
    correctionMessage: 'Use null-safe alternatives: ?? for defaults, '
        'if-null checks, or ?. for optional chaining.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addPostfixExpression((PostfixExpression node) {
      // Check if this is a null assertion (!)
      if (node.operator.lexeme == '!') {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when a type assertion (is check) is unnecessary.
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
class AvoidUnnecessaryTypeAssertionsRule extends DartLintRule {
  const AvoidUnnecessaryTypeAssertionsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_unnecessary_type_assertions',
    problemMessage: 'Unnecessary type assertion. '
        'The expression is already known to be of this type.',
    correctionMessage: 'Remove the redundant type check.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addIsExpression((IsExpression node) {
      final DartType? expressionType = node.expression.staticType;
      final DartType? testedType = node.type.type;

      if (expressionType == null || testedType == null) return;

      // If the expression is already a subtype of the tested type,
      // the check is always true (unless negated)
      if (!node.notOperator.toString().contains('!')) {
        // Positive is check - check if types are exactly equal
        // (simplified check without TypeSystem)
        if (expressionType == testedType) {
          reporter.atNode(node, code);
        }
        // Also check by name for common cases
        final String exprTypeName = expressionType.getDisplayString();
        final String testedTypeName = testedType.getDisplayString();
        if (exprTypeName == testedTypeName &&
            !testedType.isDartCoreObject &&
            testedTypeName != 'dynamic') {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when a type cast (as) is unnecessary.
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
class AvoidUnnecessaryTypeCastsRule extends DartLintRule {
  const AvoidUnnecessaryTypeCastsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_unnecessary_type_casts',
    problemMessage: 'Unnecessary type cast. '
        'The expression is already of this type.',
    correctionMessage: 'Remove the redundant cast.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addAsExpression((AsExpression node) {
      final DartType? expressionType = node.expression.staticType;
      final DartType? castType = node.type.type;

      if (expressionType == null || castType == null) return;

      // If the expression type equals the cast type, the cast is redundant
      if (expressionType == castType) {
        reporter.atNode(node, code);
        return;
      }

      // Also check by display name for common cases
      final String exprTypeName = expressionType.getDisplayString();
      final String castTypeName = castType.getDisplayString();
      if (exprTypeName == castTypeName && !castType.isDartCoreObject && castTypeName != 'dynamic') {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when an 'is' type check can never be true.
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
class AvoidUnrelatedTypeAssertionsRule extends DartLintRule {
  const AvoidUnrelatedTypeAssertionsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_unrelated_type_assertions',
    problemMessage: 'Type assertion can never be true. '
        'The types are unrelated.',
    correctionMessage: 'Remove the impossible type check or fix the types.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addIsExpression((IsExpression node) {
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
        reporter.atNode(node, code);
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
class PreferCorrectTypeNameRule extends DartLintRule {
  const PreferCorrectTypeNameRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_correct_type_name',
    problemMessage: 'Type name should be UpperCamelCase.',
    correctionMessage: 'Rename to use UpperCamelCase convention.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    void checkName(Token nameToken) {
      final String name = nameToken.lexeme;
      if (name.isEmpty) return;

      // Skip private types (checked elsewhere)
      if (name.startsWith('_')) {
        final String publicPart = name.substring(1);
        if (publicPart.isNotEmpty && !_isUpperCamelCase(publicPart)) {
          reporter.atToken(nameToken, code);
        }
        return;
      }

      if (!_isUpperCamelCase(name)) {
        reporter.atToken(nameToken, code);
      }
    }

    context.registry.addClassDeclaration((ClassDeclaration node) {
      checkName(node.name);
    });

    context.registry.addMixinDeclaration((MixinDeclaration node) {
      checkName(node.name);
    });

    context.registry.addEnumDeclaration((EnumDeclaration node) {
      checkName(node.name);
    });

    context.registry.addExtensionTypeDeclaration((ExtensionTypeDeclaration node) {
      checkName(node.name);
    });

    context.registry.addGenericTypeAlias((GenericTypeAlias node) {
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
class PreferExplicitFunctionTypeRule extends DartLintRule {
  const PreferExplicitFunctionTypeRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_explicit_function_type',
    problemMessage: 'Use explicit function type instead of bare "Function".',
    correctionMessage: 'Specify the function signature (e.g., void Function()).',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addNamedType((NamedType node) {
      final String name = node.name.lexeme;
      if (name == 'Function') {
        // Check if it's the bare Function type (no type arguments)
        if (node.typeArguments == null) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when `var` is used instead of explicit type.
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
class PreferTypeOverVarRule extends DartLintRule {
  const PreferTypeOverVarRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_type_over_var',
    problemMessage: 'Prefer explicit type annotation over var.',
    correctionMessage: 'Replace var with the explicit type.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addVariableDeclarationList((VariableDeclarationList node) {
      // Check if using var (no type annotation and not final/const)
      if (node.type == null && node.keyword?.lexeme == 'var') {
        reporter.atNode(node, code);
      }
    });
  }
}
