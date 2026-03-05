// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../../saropa_lint_rule.dart';
import '../../fixes/class_constructor/prefer_const_string_list_fix.dart';
import '../../fixes/class_constructor/prefer_declaring_const_constructor_fix.dart';
import '../../fixes/class_constructor/prefer_final_class_fix.dart';

/// Warns when a class declares a call() method.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// Example of **bad** code:
/// ```dart
/// class MyClass {
///   void call() { }
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// class MyClass {
///   void execute() { }
/// }
/// ```
class AvoidDeclaringCallMethodRule extends SaropaLintRule {
  AvoidDeclaringCallMethodRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_declaring_call_method',
    '[avoid_declaring_call_method] call() method makes class callable but hides intent. Code reads ambiguously. A class declares a call() method. {v5}',
    correctionMessage:
        'Use descriptive method name: execute(), invoke(), or run() instead. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme == 'call') {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when a generic type parameter shadows a top-level declaration.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// This can cause confusion when the generic type parameter has the same name
/// as a class, typedef, or other top-level declaration.
///
/// Example of **bad** code:
/// ```dart
/// class String {} // top-level
/// class Container<String> {} // shadows top-level String
/// ```
///
/// Example of **good** code:
/// ```dart
/// class Container<T> {} // clear generic parameter
/// ```
class AvoidGenericsShadowingRule extends SaropaLintRule {
  AvoidGenericsShadowingRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_generics_shadowing',
    '[avoid_generics_shadowing] Generic type parameter shadows a top-level declaration. This class design reduces clarity and can lead to incorrect object initialization. {v4}',
    correctionMessage:
        'Rename the generic parameter to avoid shadowing. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _commonTypes = <String>{
    'Object',
    'String',
    'int',
    'double',
    'num',
    'bool',
    'List',
    'Map',
    'Set',
    'Iterable',
    'Future',
    'Stream',
    'Function',
    'Type',
    'Symbol',
    'Null',
    'Never',
    'dynamic',
    'void',
    'Widget',
    'State',
    'BuildContext',
    'Key',
    'Color',
    'Size',
    'Offset',
    'Rect',
    'Duration',
    'DateTime',
    'Uri',
    'Exception',
    'Error',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addTypeParameterList((TypeParameterList node) {
      for (final TypeParameter param in node.typeParameters) {
        final String name = param.name.lexeme;
        if (_commonTypes.contains(name)) {
          reporter.atNode(param);
        }
      }
    });
  }
}

/// Warns when a copyWith method is missing fields.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// All non-final fields should be included in copyWith for complete copying.
///
/// Example of **bad** code:
/// ```dart
/// class User {
///   final String name;
///   final int age;
///   User copyWith({String? name}) => User(name ?? this.name, age);
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// class User {
///   final String name;
///   final int age;
///   User copyWith({String? name, int? age}) =>
///       User(name ?? this.name, age ?? this.age);
/// }
/// ```
class AvoidIncompleteCopyWithRule extends SaropaLintRule {
  AvoidIncompleteCopyWithRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_incomplete_copy_with',
    '[avoid_incomplete_copy_with] copyWith() is missing fields. Copied objects will lose data for those fields. All non-final fields must be included in copyWith for complete copying. {v4}',
    correctionMessage:
        'Add missing fields as nullable parameters: copyWith({String? name, int? age}). Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      final body = node.body;
      if (body is! BlockClassBody) return;
      // Collect all instance fields
      final Set<String> fieldNames = <String>{};
      for (final ClassMember member in body.members) {
        if (member is FieldDeclaration && !member.isStatic) {
          for (final VariableDeclaration variable in member.fields.variables) {
            fieldNames.add(variable.name.lexeme);
          }
        }
      }

      if (fieldNames.isEmpty) return;

      // Find copyWith method
      for (final ClassMember member in body.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'copyWith') {
          final FormalParameterList? params = member.parameters;
          if (params == null) continue;

          // Get parameter names
          final Set<String> paramNames = <String>{};
          for (final FormalParameter param in params.parameters) {
            final String? name = param.name?.lexeme;
            if (name != null) {
              paramNames.add(name);
            }
          }

          // Check if any fields are missing
          final Set<String> missingFields = fieldNames.difference(paramNames);
          if (missingFields.isNotEmpty) {
            reporter.atNode(member);
          }
        }
      }
    });
  }
}

/// Warns when constructor body contains logic.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Constructor bodies with logic can be harder to understand.
/// Prefer using initializer lists or factory constructors.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// class User {
///   String name;
///   User(String input) {
///     name = input.trim();
///   }
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// class User {
///   final String name;
///   User(String input) : name = input.trim();
/// }
/// ```
class AvoidNonEmptyConstructorBodiesRule extends SaropaLintRule {
  AvoidNonEmptyConstructorBodiesRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_non_empty_constructor_bodies',
    '[avoid_non_empty_constructor_bodies] Constructor body has logic. Final fields cannot be set in body, only initializers. Constructor bodies with logic can be harder to understand. Prefer using initializer lists or factory constructors. {v4}',
    correctionMessage:
        'Move logic to initializer list: MyClass(input) : name = input.trim();. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addConstructorDeclaration((ConstructorDeclaration node) {
      final FunctionBody body = node.body;

      // Skip empty or expression bodies
      if (body is EmptyFunctionBody) return;
      if (body is ExpressionFunctionBody) {
        // Expression body in constructor is usually a redirect
        return;
      }

      if (body is BlockFunctionBody) {
        final Block block = body.block;
        // Allow empty blocks
        if (block.statements.isEmpty) return;

        // Check if it's just assert statements (allowed)
        bool hasOnlyAsserts = true;
        for (final Statement stmt in block.statements) {
          if (stmt is! AssertStatement) {
            hasOnlyAsserts = false;
            break;
          }
        }
        if (hasOnlyAsserts) return;

        final Token? nameToken = node.name;
        if (nameToken != null) {
          reporter.atToken(nameToken);
        } else {
          reporter.atNode(node.returnType, code);
        }
      }
    });
  }
}

/// Warns when a variable or parameter shadows another declaration from an
///
/// Since: v4.1.3 | Updated: v4.13.0 | Rule version: v3
///
/// outer scope.
///
/// Shadowing occurs when a nested scope declares a variable with the same name
/// as one in an enclosing scope. This can lead to confusion about which
/// variable is being referenced and is a common source of subtle bugs.
///
/// **Note:** Variables with the same name in sibling closures (not nested) are
/// NOT shadowing - they are independent scopes. For example, multiple `test()`
/// callbacks in a `group()` can each declare their own `list` variable.
///
/// **BAD:**
/// ```dart
/// int value = 10;
/// void process(int value) {  // Shadows outer 'value'
///   print(value);
/// }
///
/// void outer() {
///   final list = [1, 2, 3];
///   void inner() {
///     final list = [];  // Shadows outer 'list'
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// int globalValue = 10;
/// void process(int localValue) {
///   print(localValue);
/// }
///
/// // Sibling closures - NOT shadowing (independent scopes)
/// group('tests', () {
///   test('A', () { final list = [1]; });  // Scope A
///   test('B', () { final list = [2]; });  // Scope B - OK, not nested
/// });
/// ```
class AvoidShadowingRule extends SaropaLintRule {
  AvoidShadowingRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  /// Alias: avoid_shadowing
  static const LintCode _code = LintCode(
    'avoid_variable_shadowing',
    '[avoid_variable_shadowing] Declaration shadows a declaration from an outer scope. Shadowing occurs when a nested scope declares a variable with the same name as one in an enclosing scope. This can lead to confusion about which variable is being referenced and is a common source of subtle bugs. {v3}',
    correctionMessage:
        'Rename the variable to avoid confusion. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addFunctionDeclaration((FunctionDeclaration node) {
      final String functionName = node.name.lexeme;
      final _ShadowingChecker checker = _ShadowingChecker(
        reporter,
        code,
        <String>{functionName},
      );

      // Collect parameter names
      final FormalParameterList? params = node.functionExpression.parameters;
      if (params != null) {
        for (final FormalParameter param in params.parameters) {
          final String? name = param.name?.lexeme;
          if (name != null) {
            checker.outerNames.add(name);
          }
        }
      }

      node.functionExpression.body.accept(checker);
    });

    context.addMethodDeclaration((MethodDeclaration node) {
      final String methodName = node.name.lexeme;
      final _ShadowingChecker checker = _ShadowingChecker(
        reporter,
        code,
        <String>{methodName},
      );

      // Collect parameter names
      final FormalParameterList? params = node.parameters;
      if (params != null) {
        for (final FormalParameter param in params.parameters) {
          final String? name = param.name?.lexeme;
          if (name != null) {
            checker.outerNames.add(name);
          }
        }
      }

      node.body.accept(checker);
    });
  }
}

class _ShadowingChecker extends RecursiveAstVisitor<void> {
  _ShadowingChecker(this.reporter, this.code, this.outerNames);

  final SaropaDiagnosticReporter reporter;
  final LintCode code;
  final Set<String> outerNames;

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    final String name = node.name.lexeme;
    if (outerNames.contains(name)) {
      reporter.atNode(node);
    } else {
      outerNames.add(name);
    }
    super.visitVariableDeclaration(node);
  }

  @override
  void visitDeclaredIdentifier(DeclaredIdentifier node) {
    final String name = node.name.lexeme;
    if (outerNames.contains(name)) {
      reporter.atNode(node);
    } else {
      outerNames.add(name);
    }
    super.visitDeclaredIdentifier(node);
  }

  @override
  void visitFunctionDeclarationStatement(FunctionDeclarationStatement node) {
    final String name = node.functionDeclaration.name.lexeme;
    if (outerNames.contains(name)) {
      reporter.atNode(node.functionDeclaration, code);
    } else {
      outerNames.add(name);
    }
    super.visitFunctionDeclarationStatement(node);
  }

  @override
  void visitForStatement(ForStatement node) {
    // For-loop variables are scoped to the loop body. After the loop
    // exits, they no longer exist. Save/restore so sequential loops
    // reusing the same variable name are not treated as shadowing.
    final Set<String> savedNames = Set<String>.from(outerNames);
    super.visitForStatement(node);
    outerNames
      ..clear()
      ..addAll(savedNames);
  }

  @override
  void visitWhileStatement(WhileStatement node) {
    final Set<String> savedNames = Set<String>.from(outerNames);
    super.visitWhileStatement(node);
    outerNames
      ..clear()
      ..addAll(savedNames);
  }

  @override
  void visitDoStatement(DoStatement node) {
    final Set<String> savedNames = Set<String>.from(outerNames);
    super.visitDoStatement(node);
    outerNames
      ..clear()
      ..addAll(savedNames);
  }

  @override
  void visitBlock(Block node) {
    // For blocks that are direct children of if/else/switch/try,
    // variables declared inside should not leak to siblings.
    final AstNode? parent = node.parent;
    final bool isScopedBlock =
        parent is IfStatement ||
        parent is SwitchCase ||
        parent is SwitchDefault ||
        parent is TryStatement ||
        parent is CatchClause;

    if (isScopedBlock) {
      final Set<String> savedNames = Set<String>.from(outerNames);
      super.visitBlock(node);
      outerNames
        ..clear()
        ..addAll(savedNames);
    } else {
      super.visitBlock(node);
    }
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    // When entering a closure, create a snapshot of outer names.
    // Variables declared in this closure should not leak to sibling closures.
    final Set<String> savedOuterNames = Set<String>.from(outerNames);

    // Collect parameter names for this closure
    final FormalParameterList? params = node.parameters;
    if (params != null) {
      for (final FormalParameter param in params.parameters) {
        final String? name = param.name?.lexeme;
        if (name != null) {
          outerNames.add(name);
        }
      }
    }

    // Visit the body
    node.body.accept(this);

    // Restore outer names - variables from this closure don't affect siblings
    outerNames
      ..clear()
      ..addAll(savedOuterNames);
  }
}

/// Warns when a `<String>[...]` list literal with only string literals
///
/// Since: v4.9.0 | Updated: v4.13.0 | Rule version: v3
///
/// is not marked as `const`.
///
/// Using `const` for immutable string lists improves performance by
/// allowing compile-time constant folding and reducing memory allocations.
///
/// Example of **bad** code:
/// ```dart
/// final List<String> countries = <String>['US', 'CA', 'MX'];
/// ```
///
/// Example of **good** code:
/// ```dart
/// const List<String> countries = <String>['US', 'CA', 'MX'];
/// // or
/// final List<String> countries = const <String>['US', 'CA', 'MX'];
/// ```
class PreferConstStringListRule extends SaropaLintRule {
  PreferConstStringListRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        PreferConstStringListFix(context: context),
  ];

  static const LintCode _code = LintCode(
    'prefer_const_string_list',
    '[prefer_const_string_list] This <String>[...] list contains only string literals '
        'and could be const. {v3}',
    correctionMessage:
        'Add const before the list literal or use a const '
        'variable declaration.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addListLiteral((ListLiteral node) {
      // Skip if already const
      if (node.constKeyword != null) {
        return;
      }

      // Check if this list is in a const context (inherited constness)
      if (_isInConstContext(node)) {
        return;
      }

      // Check if the list has a <String> type argument
      final TypeArgumentList? typeArgs = node.typeArguments;
      if (typeArgs == null || typeArgs.arguments.length != 1) {
        return;
      }

      final String typeName = typeArgs.arguments.first.toSource();
      if (typeName != 'String') {
        return;
      }

      // Check if all elements are simple string literals
      final List<CollectionElement> elements = node.elements;
      if (elements.isEmpty) {
        return; // Empty lists are handled by other rules
      }

      final bool allStringLiterals = elements.every((
        CollectionElement element,
      ) {
        if (element is SimpleStringLiteral) {
          return true;
        }
        if (element is AdjacentStrings) {
          // Adjacent string literals like 'hello' 'world'
          return element.strings.every(
            (StringLiteral s) => s is SimpleStringLiteral,
          );
        }
        return false;
      });

      if (allStringLiterals) {
        reporter.atNode(node);
      }
    });
  }

  /// Check if a node is within a const context (const declaration,
  /// const constructor, enum body, etc.)
  bool _isInConstContext(AstNode node) {
    AstNode? current = node.parent;

    while (current != null) {
      // Inside a const variable declaration
      if (current is VariableDeclarationList && current.isConst) {
        return true;
      }

      // Inside a const constructor call
      if (current is InstanceCreationExpression && current.isConst) {
        return true;
      }

      // Inside an enum declaration (enum values are implicitly const)
      if (current is EnumDeclaration) {
        return true;
      }

      // Inside a const annotation
      if (current is Annotation) {
        return true;
      }

      // Inside another const collection literal
      if (current is ListLiteral && current.constKeyword != null) {
        return true;
      }
      if (current is SetOrMapLiteral && current.constKeyword != null) {
        return true;
      }

      current = current.parent;
    }

    return false;
  }
}

/// Warns when a class could have a const constructor but doesn't.
///
/// Since: v4.9.0 | Updated: v4.13.0 | Rule version: v5
class PreferDeclaringConstConstructorRule extends SaropaLintRule {
  PreferDeclaringConstConstructorRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        PreferDeclaringConstConstructorFix(context: context),
  ];

  @override
  List<String> get configAliases => const <String>[
    'prefer_const_constructor_declarations',
  ];

  static const LintCode _code = LintCode(
    'prefer_declaring_const_constructor',
    '[prefer_declaring_const_constructor] Class could have a const constructor. A class could have a const constructor but doesn\'t. This class design reduces clarity and can lead to incorrect object initialization. {v5}',
    correctionMessage:
        'Add const keyword to constructor. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      final body = node.body;
      if (body is! BlockClassBody) return;
      // Check if all instance fields are final
      bool allFieldsFinal = true;
      bool hasFields = false;

      for (final ClassMember member in body.members) {
        if (member is FieldDeclaration && !member.isStatic) {
          hasFields = true;
          if (!member.fields.isFinal && !member.fields.isConst) {
            allFieldsFinal = false;
            break;
          }
        }
      }

      if (!allFieldsFinal) return;

      // Check if there's already a const constructor
      bool hasConstConstructor = false;
      bool hasNonConstConstructor = false;

      for (final ClassMember member in body.members) {
        if (member is ConstructorDeclaration) {
          if (member.constKeyword != null) {
            hasConstConstructor = true;
          } else if (member.factoryKeyword == null) {
            // Non-factory, non-const constructor
            hasNonConstConstructor = true;
          }
        }
      }

      // Only warn if there's no const constructor and there is a non-const one
      // or if there are final fields but no explicit constructor
      if (!hasConstConstructor && (hasNonConstConstructor || hasFields)) {
        // Find the non-const constructor to report on
        for (final ClassMember member in body.members) {
          if (member is ConstructorDeclaration &&
              member.constKeyword == null &&
              member.factoryKeyword == null) {
            reporter.atToken(member.name ?? node.namePart.typeName, code);
            break;
          }
        }
      }
    });
  }
}

/// Suggests non-const constructor when const is not required (stylistic opposite).
///
/// Stylistic: some teams prefer non-const constructors for consistency or debugging.
class PreferNonConstConstructorsRule extends SaropaLintRule {
  PreferNonConstConstructorsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_non_const_constructors',
    '[prefer_non_const_constructors] Prefer non-const constructor when const is not required (stylistic preference).',
    correctionMessage: 'Consider removing the const keyword.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addConstructorDeclaration((ConstructorDeclaration node) {
      if (node.constKeyword == null) return;
      reporter.atNode(node);
    });
  }
}

/// Prefer factory constructor over static method that returns an instance of the same class.
///
/// **Bad:**
/// ```dart
/// class C {
///   static C create() => C();
/// }
/// ```
///
/// **Good:**
/// ```dart
/// class C {
///   factory C.create() => C();
/// }
/// ```
class PreferFactoryConstructorRule extends SaropaLintRule {
  PreferFactoryConstructorRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_factory_constructor',
    '[prefer_factory_constructor] Prefer factory constructor over static method that returns an instance of the same class.',
    correctionMessage: 'Convert the static method to a factory constructor.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      if (!node.isStatic) return;
      final body = node.body;
      if (body is! ExpressionFunctionBody) return;
      final Expression? expr = body.expression;
      if (expr is! InstanceCreationExpression) return;
      final AstNode? parent = node.parent;
      if (parent is! ClassDeclaration) return;
      final String className = parent.name.lexeme;
      final String createdName = expr.constructorName.type.name.lexeme;
      if (createdName != className) return;
      reporter.atNode(node);
    });
  }
}

/// Warns when extension type representation fields are public.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Extension type fields should be private for encapsulation.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// extension type UserId(String value) implements String { }
/// ```
///
/// #### GOOD:
/// ```dart
/// extension type UserId._(String _value) implements String {
///   factory UserId(String value) => UserId._(value);
/// }
/// ```
class PreferPrivateExtensionTypeFieldRule extends SaropaLintRule {
  PreferPrivateExtensionTypeFieldRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_private_extension_type_field',
    '[prefer_private_extension_type_field] Extension type representation field must be private. Extension type fields must be private for encapsulation. {v4}',
    correctionMessage:
        'Use a private field with underscore prefix. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addExtensionTypeDeclaration((ExtensionTypeDeclaration node) {
      final RepresentationDeclaration representation = node.representation;
      final Token fieldName = representation.fieldName;

      if (!fieldName.lexeme.startsWith('_')) {
        reporter.atToken(fieldName);
      }
    });
  }
}

/// Warns when an extension type exposes the representation under a different name.
///
/// Since: v4.13.0 | Rule version: v1
///
/// **Purpose for developers:** In Dart extension types, the representation is
/// the single field declared in the primary constructor (e.g. `int _id` in
/// `extension type UserId(int _id)`). That field is exposed as an implicit
/// getter with the same name. This rule flags explicit getters in the extension
/// type body that return the same type as the representation but use a
/// different name (e.g. `int get value => _id`), which "renames" the
/// representation and can confuse readers. Detection compares return type
/// source to representation type source; no string heuristics. Methods with
/// parameters are ignored (only parameterless getters are considered).
///
/// **BAD:**
/// ```dart
/// extension type UserId(int _id) {
///   int get value => _id;  // Renames representation getter
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// extension type UserId(int id) {
///   // Use representation name directly
/// }
/// ```
class AvoidRenamingRepresentationGettersRule extends SaropaLintRule {
  AvoidRenamingRepresentationGettersRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_renaming_representation_getters',
    '[avoid_renaming_representation_getters] Extension type should not expose '
        'the representation via a getter with a different name. {v1}',
    correctionMessage:
        'Use the representation name directly or keep a single public getter name matching the representation.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addExtensionTypeDeclaration((ExtensionTypeDeclaration node) {
      final body = node.body;
      if (body is! BlockClassBody) return;
      final RepresentationDeclaration representation = node.representation;
      final String repFieldName = representation.fieldName.lexeme;
      final String repTypeSource = representation.fieldType
          .toSource()
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      for (final ClassMember m in body.members) {
        if (m is! MethodDeclaration) continue;
        // Getters have no parameters
        if (m.parameters != null && m.parameters!.parameters.isNotEmpty) {
          continue;
        }
        final String getterName = m.name.lexeme;
        if (getterName == repFieldName) continue;

        final TypeAnnotation? returnType = m.returnType;
        if (returnType == null) continue;
        final String returnTypeSource = returnType
            .toSource()
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        if (returnTypeSource != repTypeSource) continue;

        reporter.atToken(m.name, code);
      }
    });
  }
}

/// Warns when super lifecycle methods are called in wrong order.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// In State classes, super.initState() should be called first,
/// and super.dispose() should be called last.
///
/// Example of **bad** code:
/// ```dart
/// @override
/// void initState() {
///   _controller = TextEditingController();
///   super.initState();  // Should be first!
/// }
///
/// @override
/// void dispose() {
///   super.dispose();  // Should be last!
///   _controller.dispose();
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// @override
/// void initState() {
///   super.initState();
///   _controller = TextEditingController();
/// }
///
/// @override
/// void dispose() {
///   _controller.dispose();
///   super.dispose();
/// }
/// ```
class ProperSuperCallsRule extends SaropaLintRule {
  ProperSuperCallsRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'proper_super_calls',
    '[proper_super_calls] Super lifecycle method called in wrong order. In State classes, super.initState() must be called first, and super.dispose() must be called last. {v5}',
    correctionMessage:
        'super.initState() must be first; super.dispose() must be last. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      final String methodName = node.name.lexeme;

      // Only check initState and dispose
      if (methodName != 'initState' && methodName != 'dispose') return;

      // Check if in a State class
      final AstNode? parent = node.parent;
      if (parent is! ClassDeclaration) return;

      final ExtendsClause? extendsClause = parent.extendsClause;
      if (extendsClause == null) return;
      if (extendsClause.superclass.element?.name != 'State') return;

      final FunctionBody body = node.body;
      if (body is! BlockFunctionBody) return;

      final List<Statement> statements = body.block.statements;
      if (statements.isEmpty) return;

      // Find super call position
      int? superCallIndex;
      for (int i = 0; i < statements.length; i++) {
        final Statement stmt = statements[i];
        if (stmt is ExpressionStatement) {
          final Expression expr = stmt.expression;
          if (expr is MethodInvocation) {
            final Expression? target = expr.target;
            if (target is SuperExpression &&
                expr.methodName.name == methodName) {
              superCallIndex = i;
              break;
            }
          }
        }
      }

      if (superCallIndex == null) return;

      // For initState, super should be first
      if (methodName == 'initState' && superCallIndex != 0) {
        reporter.atNode(statements[superCallIndex], code);
      }

      // For dispose, super should be last
      if (methodName == 'dispose' && superCallIndex != statements.length - 1) {
        reporter.atNode(statements[superCallIndex], code);
      }
    });
  }
}

/// Warns when a public class lacks an explicit class modifier.
///
/// Since: v1.3.0 | Updated: v4.13.0 | Rule version: v3
///
/// Dart 3.0 introduced class modifiers (base, final, interface, sealed).
/// For API stability, public classes should declare their inheritance intent.
///
/// Example of **bad** code:
/// ```dart
/// class MyService { }  // Can be extended/implemented anywhere
/// ```
///
/// Example of **good** code:
/// ```dart
/// final class MyService { }  // Cannot be extended
/// base class MyService { }   // Can only be extended, not implemented
/// interface class MyService { }  // Can only be implemented
/// sealed class MyService { }  // Restricted to this library
/// ```
class AvoidUnmarkedPublicClassRule extends SaropaLintRule {
  AvoidUnmarkedPublicClassRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_unmarked_public_class',
    '[avoid_unmarked_public_class] Public class lacks an explicit class modifier. Dart 3.0 introduced class modifiers (base, final, interface, sealed). For API stability, public classes should declare their inheritance intent. {v3}',
    correctionMessage:
        'Add base, final, interface, or sealed modifier (Dart 3.0+). Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      final body = node.body;
      if (body is! BlockClassBody) return;
      final String className = node.namePart.typeName.lexeme;

      // Skip private classes
      if (className.startsWith('_')) return;

      // Check for class modifiers
      final bool hasBase = node.baseKeyword != null;
      final bool hasFinal = node.finalKeyword != null;
      final bool hasInterface = node.interfaceKeyword != null;
      final bool hasSealed = node.sealedKeyword != null;
      final bool hasMixin = node.mixinKeyword != null;
      final bool isAbstract = node.abstractKeyword != null;

      // Skip if it already has a modifier (including abstract which implies intent)
      if (hasBase || hasFinal || hasInterface || hasSealed || hasMixin) {
        return;
      }

      // Abstract classes are somewhat explicit about intent, but could still
      // benefit from base/interface/sealed. We'll skip them to reduce noise.
      if (isAbstract) return;

      // Skip classes with only private constructors — they already prevent
      // external instantiation and extension, making a modifier redundant.
      final List<ConstructorDeclaration> constructors = body.members
          .whereType<ConstructorDeclaration>()
          .toList();
      if (constructors.isNotEmpty &&
          constructors.every(
            (ConstructorDeclaration c) =>
                c.name != null && c.name!.lexeme.startsWith('_'),
          )) {
        return;
      }

      reporter.atToken(node.namePart.typeName, code);
    });
  }
}

/// Warns when a concrete class could be marked `final`.
///
/// Since: v1.3.0 | Updated: v4.13.0 | Rule version: v4
///
/// Dart 3.0 introduced the `final` modifier to prevent subclassing.
/// Classes that are not designed for extension should be marked `final`.
///
/// Example of **bad** code:
/// ```dart
/// class ApiService { }  // Can be extended anywhere
/// ```
///
/// Example of **good** code:
/// ```dart
/// final class ApiService { }  // Cannot be extended
/// ```
class PreferFinalClassRule extends SaropaLintRule {
  PreferFinalClassRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        PreferFinalClassFix(context: context),
  ];

  static const LintCode _code = LintCode(
    'prefer_final_class',
    '[prefer_final_class] Prefer marking this class as final. Dart 3.0 introduced the final modifier to prevent subclassing. Classes that are not designed for extension must be marked final. {v4}',
    correctionMessage:
        'Add final modifier if this class is not designed for extension (Dart 3.0+). Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      final body = node.body;
      if (body is! BlockClassBody) return;
      final String className = node.namePart.typeName.lexeme;

      // Skip private classes
      if (className.startsWith('_')) return;

      // Skip if abstract - abstract classes need different modifiers
      if (node.abstractKeyword != null) return;

      // Skip if already has a modifier
      if (node.baseKeyword != null ||
          node.finalKeyword != null ||
          node.interfaceKeyword != null ||
          node.sealedKeyword != null ||
          node.mixinKeyword != null) {
        return;
      }

      // Heuristic: Classes with only private constructors are good candidates
      bool hasPublicConstructor = false;
      bool hasAnyConstructor = false;

      for (final ClassMember member in body.members) {
        if (member is ConstructorDeclaration) {
          hasAnyConstructor = true;
          final Token? nameToken = member.name;
          final bool isPrivate =
              nameToken != null && nameToken.lexeme.startsWith('_');
          if (!isPrivate && member.factoryKeyword == null) {
            hasPublicConstructor = true;
          }
        }
      }

      // If no constructors defined, there's an implicit public constructor
      if (!hasAnyConstructor) {
        hasPublicConstructor = true;
      }

      // Only suggest final for classes with private-only constructors
      // or classes that look like utility/service classes
      if (!hasPublicConstructor) {
        reporter.atToken(node.namePart.typeName, code);
      }
    });
  }
}

/// Warns when an abstract class with only abstract members could be `interface`.
///
/// Since: v1.3.0 | Updated: v4.13.0 | Rule version: v4
///
/// Dart 3.0 introduced the `interface` modifier for pure contracts.
/// Abstract classes with no implementation should use `interface class`.
///
/// Example of **bad** code:
/// ```dart
/// abstract class Repository {
///   Future<User> getUser(String id);
///   Future<void> saveUser(User user);
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// interface class Repository {
///   Future<User> getUser(String id);
///   Future<void> saveUser(User user);
/// }
/// ```
class PreferInterfaceClassRule extends SaropaLintRule {
  PreferInterfaceClassRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_interface_class',
    '[prefer_interface_class] Abstract class with only abstract members could be interface. Dart 3.0 introduced the interface modifier for pure contracts. Abstract classes with no implementation should use interface class. {v4}',
    correctionMessage:
        'Use interface class for pure contracts (Dart 3.0+). Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      final body = node.body;
      if (body is! BlockClassBody) return;
      // Must be abstract
      if (node.abstractKeyword == null) return;

      // Skip if already has a modifier
      if (node.baseKeyword != null ||
          node.finalKeyword != null ||
          node.interfaceKeyword != null ||
          node.sealedKeyword != null ||
          node.mixinKeyword != null) {
        return;
      }

      // Skip private classes
      if (node.namePart.typeName.lexeme.startsWith('_')) return;

      // Check if all members are abstract (no concrete implementations)
      bool hasConcreteImplementation = false;

      for (final ClassMember member in body.members) {
        if (member is MethodDeclaration) {
          // Check if method has a body (concrete implementation)
          if (member.body is! EmptyFunctionBody) {
            hasConcreteImplementation = true;
            break;
          }
        } else if (member is FieldDeclaration) {
          // Fields with initializers are concrete
          for (final VariableDeclaration variable in member.fields.variables) {
            if (variable.initializer != null) {
              hasConcreteImplementation = true;
              break;
            }
          }
          if (hasConcreteImplementation) break;
        } else if (member is ConstructorDeclaration) {
          // Constructors with bodies are concrete
          if (member.body is! EmptyFunctionBody) {
            hasConcreteImplementation = true;
            break;
          }
        }
      }

      // Only suggest interface if there's no concrete implementation
      if (!hasConcreteImplementation && body.members.isNotEmpty) {
        reporter.atToken(node.namePart.typeName, code);
      }
    });
  }
}

/// Warns when an abstract class with implementation could be `base`.
///
/// Since: v1.3.0 | Updated: v4.13.0 | Rule version: v4
///
/// Dart 3.0 introduced the `base` modifier for classes meant to be
/// extended but not implemented directly.
///
/// Example of **bad** code:
/// ```dart
/// abstract class BaseRepository {
///   final Database db;
///   BaseRepository(this.db);
///
///   Future<void> close() => db.close();
///   Future<T> get<T>(String id);  // Abstract
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// abstract base class BaseRepository {
///   final Database db;
///   BaseRepository(this.db);
///
///   Future<void> close() => db.close();
///   Future<T> get<T>(String id);  // Abstract
/// }
/// ```
class PreferBaseClassRule extends SaropaLintRule {
  PreferBaseClassRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_base_class',
    '[prefer_base_class] Abstract class with shared implementation could be base. Dart 3.0 introduced the base modifier for classes meant to be extended but not implemented directly. {v4}',
    correctionMessage:
        'Use abstract base class to prevent direct implementation (Dart 3.0+). Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      final body = node.body;
      if (body is! BlockClassBody) return;
      // Must be abstract
      if (node.abstractKeyword == null) return;

      // Skip if already has a modifier
      if (node.baseKeyword != null ||
          node.finalKeyword != null ||
          node.interfaceKeyword != null ||
          node.sealedKeyword != null ||
          node.mixinKeyword != null) {
        return;
      }

      // Skip private classes
      if (node.namePart.typeName.lexeme.startsWith('_')) return;

      // Check if class has both abstract and concrete members
      bool hasAbstractMember = false;
      bool hasConcreteImplementation = false;

      for (final ClassMember member in body.members) {
        if (member is MethodDeclaration) {
          if (member.body is EmptyFunctionBody) {
            hasAbstractMember = true;
          } else {
            hasConcreteImplementation = true;
          }
        } else if (member is FieldDeclaration) {
          // Non-static fields count as concrete
          if (!member.isStatic) {
            hasConcreteImplementation = true;
          }
        } else if (member is ConstructorDeclaration) {
          // Having a constructor with initializers is concrete
          if (member.initializers.isNotEmpty ||
              member.body is! EmptyFunctionBody) {
            hasConcreteImplementation = true;
          }
        }
      }

      // Suggest base for abstract classes with shared implementation
      // that also have abstract members (mixed abstraction)
      if (hasAbstractMember && hasConcreteImplementation) {
        reporter.atToken(node.namePart.typeName, code);
      }
    });
  }
}

// =============================================================================
// avoid_accessing_other_classes_private_members
// =============================================================================

/// Warns when code accesses another class's private members in the same file.
///
/// Since: v5.1.0 | Rule version: v1
///
/// In Dart, `_private` members are private to the **library** (file), not
/// to the class. A class `Foo` in `foo.dart` can access `Bar._secret` if
/// `Bar` is also defined in `foo.dart`. This violates encapsulation and
/// creates maintenance debt — when classes are later split into separate
/// files, these accesses break.
///
/// **BAD:**
/// ```dart
/// class Foo {
///   final int _secret = 42;
/// }
///
/// class Bar {
///   void peek(Foo foo) {
///     print(foo._secret); // Cross-class private access
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class Foo {
///   final int _secret = 42;
///   int get secret => _secret; // Expose via public API
/// }
///
/// class Bar {
///   void peek(Foo foo) {
///     print(foo.secret); // Uses public API
///   }
/// }
/// ```
class AvoidAccessingOtherClassesPrivateMembersRule extends SaropaLintRule {
  AvoidAccessingOtherClassesPrivateMembersRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  bool get requiresClassDeclaration => true;

  static const LintCode _code = LintCode(
    'avoid_accessing_other_classes_private_members',
    '[avoid_accessing_other_classes_private_members] Accessing a private '
        'member of another class in the same file. In Dart, underscore-prefixed '
        'members are private to the library (file), not to the class. This '
        'means classes in the same file can reach into each other\'s internal '
        'state — but this violates encapsulation and creates maintenance debt. '
        'When the code is later refactored (classes split into different '
        'files), these accesses break. {v1}',
    correctionMessage:
        'Add a public method or property to expose the needed functionality '
        'instead of accessing private members directly.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addPrefixedIdentifier((PrefixedIdentifier node) {
      // Only care about _private identifiers
      final String memberName = node.identifier.name;
      if (!memberName.startsWith('_')) return;

      // Find the enclosing class
      final ClassDeclaration? enclosingClass = _findEnclosingClass(node);
      if (enclosingClass == null) return;

      // Check if the prefix resolves to a different type
      final String prefixName = node.prefix.name;

      // Skip `this._field` and bare `_field` (same-class access)
      if (prefixName == 'this' || prefixName == 'super') return;

      // Check if prefix is a parameter, local variable, or field whose
      // type name differs from the enclosing class name.
      final String enclosingClassName = enclosingClass.name.lexeme;

      // Use staticType to determine the prefix's type
      final String? prefixType = node.prefix.staticType?.getDisplayString();
      if (prefixType == null) return;

      // Extract the base type name (strip generics and nullability)
      final String baseType = _extractBaseTypeName(prefixType);

      // Same class → fine
      if (baseType == enclosingClassName) return;

      // Skip if the member has a @visibleForTesting annotation
      // (handled at declaration site, not here)

      reporter.atNode(node, code);
    });
  }

  /// Finds the nearest enclosing [ClassDeclaration] for [node].
  static ClassDeclaration? _findEnclosingClass(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is ClassDeclaration) return current;
      current = current.parent;
    }
    return null;
  }

  /// Extracts the base type name from a display string.
  ///
  /// `List<int>` → `List`, `String?` → `String`, `MyClass` → `MyClass`.
  static String _extractBaseTypeName(String displayString) {
    // Remove trailing `?` for nullable types
    String name = displayString;
    if (name.endsWith('?')) {
      name = name.substring(0, name.length - 1);
    }
    // Remove generic parameters
    final int genericStart = name.indexOf('<');
    if (genericStart > 0) {
      name = name.substring(0, genericStart);
    }
    return name.trim();
  }
}

/// Warns when a constructor parameter is not stored in a field or used.
///
/// Since: v5.1.0 | Rule version: v1
///
/// Constructor parameters that are neither assigned to a field (`this.x`),
/// forwarded via `super.x`, used in the initializer list, nor referenced
/// in the constructor body are dead code.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// class Greeter {
///   final String name;
///   Greeter(this.name, int unused); // ← unused is never stored
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// class Greeter {
///   final String name;
///   Greeter(this.name);
/// }
/// ```
class AvoidUnusedConstructorParametersRule extends SaropaLintRule {
  AvoidUnusedConstructorParametersRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  bool get requiresClassDeclaration => true;

  static const LintCode _code = LintCode(
    'avoid_unused_constructor_parameters',
    '[avoid_unused_constructor_parameters] A constructor parameter that is '
        'not assigned to any field, forwarded to a super constructor, or '
        'referenced in the constructor body is dead code. It adds to the '
        'public API surface without serving any purpose and confuses callers '
        'who pass values that are silently discarded. {v1}',
    correctionMessage:
        'Remove the unused parameter or assign it to a field using '
        '"this.paramName" syntax.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addConstructorDeclaration((ConstructorDeclaration node) {
      // Skip redirecting constructors (factory Foo(int x) = _Foo)
      if (node.redirectedConstructor != null) return;

      final FormalParameterList? params = node.parameters;
      if (params == null) return;

      // Collect body source for reference checking
      final String bodySource = node.body.toSource();

      // Collect initializer list source
      final String initSource = node.initializers
          .map((ConstructorInitializer i) => i.toSource())
          .join(' ');

      for (final FormalParameter param in params.parameters) {
        // this.field and super.field are always "used"
        if (param is FieldFormalParameter) continue;
        if (param is SuperFormalParameter) continue;

        // Get the actual parameter (unwrap DefaultFormalParameter)
        final FormalParameter actual = param is DefaultFormalParameter
            ? param.parameter
            : param;
        if (actual is FieldFormalParameter) continue;
        if (actual is SuperFormalParameter) continue;

        final String? name = _paramName(actual);
        if (name == null || name.startsWith('_')) continue;

        // Check if referenced in initializer list or body
        final RegExp ref = RegExp('\\b${RegExp.escape(name)}\\b');
        if (ref.hasMatch(initSource)) continue;
        if (bodySource != ';' && ref.hasMatch(bodySource)) continue;

        reporter.atNode(param);
      }
    });
  }

  static String? _paramName(FormalParameter param) {
    if (param is SimpleFormalParameter) return param.name?.lexeme;
    if (param is FunctionTypedFormalParameter) return param.name.lexeme;
    return null;
  }
}

/// Warns when a class with a const constructor has instance fields with inline initializers that should be in the initializer list.
///
/// **Bad:**
/// ```dart
/// class ApiClient {
///   const ApiClient({required this.baseUrl});
///   final String baseUrl;
///   final Duration timeout = Duration(seconds: 30);
/// }
/// ```
///
/// **Good:**
/// ```dart
/// class ApiClient {
///   const ApiClient({required this.baseUrl}) : timeout = const Duration(seconds: 30);
///   final String baseUrl;
///   final Duration timeout;
/// }
/// ```
class AvoidFieldInitializersInConstClassesRule extends SaropaLintRule {
  AvoidFieldInitializersInConstClassesRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_field_initializers_in_const_classes',
    '[avoid_field_initializers_in_const_classes] Const class has a field with an inline initializer. Prefer moving it to the constructor initializer list for clarity.',
    correctionMessage:
        'Move the field initializer to the const constructor initializer list.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      final body = node.body;
      if (body is! BlockClassBody) return;
      bool hasConstConstructor = false;
      for (final ClassMember m in body.members) {
        if (m is ConstructorDeclaration &&
            m.constKeyword != null &&
            (m.factoryKeyword == null || m.factoryKeyword!.length == 0)) {
          hasConstConstructor = true;
          break;
        }
      }
      if (!hasConstConstructor) return;
      for (final ClassMember m in body.members) {
        if (m is! FieldDeclaration || m.isStatic) continue;
        for (final VariableDeclaration v in m.fields.variables) {
          final Expression? init = v.initializer;
          if (init == null) continue;
          if (_isSimpleLiteralOrConst(init)) continue;
          reporter.atNode(m);
          return;
        }
      }
    });
  }

  static bool _isSimpleLiteralOrConst(Expression e) {
    if (e is NullLiteral ||
        e is BooleanLiteral ||
        e is IntegerLiteral ||
        e is DoubleLiteral ||
        e is SimpleStringLiteral) {
      return true;
    }
    if (e is InstanceCreationExpression && e.isConst) {
      return true;
    }
    return false;
  }
}

/// Warns when a `late` non-final field is accessed without an initialization
/// check when it may be set outside the constructor or initState.
///
/// **Category:** Class & constructor (late initialization safety).
/// **Since:** v4.14.0 | **Rule version:** v1
///
/// `late` variables throw [LateInitializationError] if read before assignment.
/// When a field is set in methods like `initialize()` or `setToken()` but
/// read in other methods like `getHeaders()`, call order is uncertain and
/// can cause runtime crashes. This rule uses a heuristic: it flags any read
/// in a non-constructor, non-initState method when the field is assigned in
/// any other such method. It does not perform full control-flow analysis.
///
/// **Bad:**
/// ```dart
/// class AuthService {
///   late String _token;
///   void setToken(String token) { _token = token; }
///   Map<String, String> getHeaders() {
///     return {'Authorization': 'Bearer $_token'}; // May crash
///   }
/// }
/// ```
///
/// **Good:**
/// ```dart
/// class AuthService {
///   String? _token;
///   Map<String, String> getHeaders() {
///     final token = _token;
///     if (token == null) return {};
///     return {'Authorization': 'Bearer $token'};
///   }
/// }
/// ```
class RequireLateAccessCheckRule extends SaropaLintRule {
  RequireLateAccessCheckRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<String>? get requiredPatterns => {'late '};

  static const LintCode _code = LintCode(
    'require_late_access_check',
    '[require_late_access_check] late field may be read before initialization. '
        'When a late non-final field is set in a method other than the '
        'constructor or initState, access in other methods can throw '
        'LateInitializationError if call order is wrong. {v1}',
    correctionMessage:
        'Use a nullable type (e.g. String?) and check before use, or add an '
        'initialization guard (e.g. if (!_initialized) throw StateError(...)) '
        'before reading the late field.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addFieldDeclaration((FieldDeclaration node) {
      if (!node.fields.isLate || node.fields.isFinal) return;
      final parent = node.parent;
      if (parent is! ClassDeclaration) return;

      final fieldNames = <String>{};
      for (final v in node.fields.variables) {
        fieldNames.add(v.name.lexeme);
      }

      final hasNonConstructorAssignment = _hasNonConstructorAssignment(
        parent,
        fieldNames,
      );
      if (!hasNonConstructorAssignment) return;

      final unsafeReads = _findUncheckedAccesses(parent, fieldNames);
      for (final read in unsafeReads) {
        reporter.atNode(read);
      }
    });
  }

  static bool _hasNonConstructorAssignment(
    ClassDeclaration classDecl,
    Set<String> fieldNames,
  ) {
    final body = classDecl.body;
    if (body is! BlockClassBody) return false;
    for (final member in body.members) {
      if (member is! MethodDeclaration) continue;
      final name = member.name.lexeme;
      if (_isConstructorOrInitState(name)) continue;
      if (_methodAssignsToFields(member, fieldNames)) return true;
    }
    return false;
  }

  static bool _isConstructorOrInitState(String methodName) {
    return methodName == 'initState' || methodName.isEmpty;
  }

  static bool _methodAssignsToFields(
    MethodDeclaration method,
    Set<String> fieldNames,
  ) {
    var assigns = false;
    method.visitChildren(_AssignmentFinder(fieldNames, (() => assigns = true)));
    return assigns;
  }

  static List<SimpleIdentifier> _findUncheckedAccesses(
    ClassDeclaration classDecl,
    Set<String> fieldNames,
  ) {
    final body = classDecl.body;
    if (body is! BlockClassBody) return <SimpleIdentifier>[];
    final reads = <SimpleIdentifier>[];
    for (final member in body.members) {
      if (member is! MethodDeclaration) continue;
      if (_isConstructorOrInitState(member.name.lexeme)) continue;
      member.visitChildren(_ReadFinder(fieldNames, reads));
    }
    return reads;
  }
}

class _AssignmentFinder extends RecursiveAstVisitor<void> {
  _AssignmentFinder(this._fieldNames, this._onAssign);

  final Set<String> _fieldNames;
  final void Function() _onAssign;

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    final left = node.leftHandSide;
    if (left is SimpleIdentifier && _fieldNames.contains(left.name)) {
      _onAssign();
    }
    super.visitAssignmentExpression(node);
  }
}

class _ReadFinder extends RecursiveAstVisitor<void> {
  _ReadFinder(this._fieldNames, this._reads);

  final Set<String> _fieldNames;
  final List<SimpleIdentifier> _reads;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (_fieldNames.contains(node.name)) _reads.add(node);
    super.visitSimpleIdentifier(node);
  }
}

/// Warns when assert() in a constructor body could be moved to the initializer list.
///
/// Initializer list asserts run before the body and work in const constructors.
///
/// Since: v6.0.8 | Rule version: v1
///
/// **Bad:**
/// ```dart
/// Radius(this.value) {
///   assert(value >= 0, 'Radius must be non-negative');
/// }
/// ```
///
/// **Good:**
/// ```dart
/// Radius(this.value) : assert(value >= 0, 'Radius must be non-negative');
/// ```
class PreferAssertsInInitializerListsRule extends SaropaLintRule {
  PreferAssertsInInitializerListsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_asserts_in_initializer_lists',
    '[prefer_asserts_in_initializer_lists] assert() in constructor body could be moved to the initializer list. Initializer list asserts run at construction time and work in const constructors.',
    correctionMessage:
        'Move the assert to the constructor initializer list (after the parameter list, before the body).',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addConstructorDeclaration((ConstructorDeclaration node) {
      if (node.factoryKeyword != null) return;
      final bool isRedirecting = node.initializers.any(
        (ConstructorInitializer i) => i is RedirectingConstructorInvocation,
      );
      if (isRedirecting) return;

      final FunctionBody body = node.body;
      if (body is! BlockFunctionBody) return;

      final List<Statement> statements = body.block.statements;
      final Set<String> paramNames = _constructorParamNames(node);

      for (final Statement stmt in statements) {
        if (stmt is! AssertStatement) break;
        if (!_assertConditionSafeForInitializerList(
          stmt.condition,
          paramNames,
        )) {
          continue;
        }
        reporter.atNode(stmt);
      }
    });
  }

  static Set<String> _constructorParamNames(ConstructorDeclaration node) {
    final Set<String> names = <String>{};
    for (final FormalParameter p in node.parameters.parameters) {
      final FormalParameter inner = p is DefaultFormalParameter
          ? p.parameter
          : p;
      if (inner is FieldFormalParameter && inner.name.lexeme.isNotEmpty) {
        names.add(inner.name.lexeme);
      } else if (inner is SimpleFormalParameter) {
        final name = inner.name;
        if (name != null) names.add(name.lexeme);
      }
    }
    return names;
  }

  static bool _assertConditionSafeForInitializerList(
    Expression condition,
    Set<String> paramNames,
  ) {
    bool safe = true;
    condition.visitChildren(
      _AssertConditionVisitor(paramNames, () => safe = false),
    );
    return safe;
  }
}

class _AssertConditionVisitor extends RecursiveAstVisitor<void> {
  _AssertConditionVisitor(this._paramNames, this._onUnsafe);

  final Set<String> _paramNames;
  final void Function() _onUnsafe;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // Only instance calls on this are unsafe in initializer list.
    if (node.target is ThisExpression) {
      _onUnsafe();
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    final Expression? target = node.target;
    if (target is ThisExpression) {
      if (!_paramNames.contains(node.propertyName.name)) {
        _onUnsafe();
      }
    }
    super.visitPropertyAccess(node);
  }
}

/// Warns when an @immutable class (e.g. StatelessWidget) has no const constructor.
///
/// Immutable classes with only final fields should expose a const constructor
/// so call sites can use const and reduce allocations.
///
/// **Bad:**
/// ```dart
/// @immutable
/// class Config {
///   Config({required this.url});
///   final String url;
/// }
/// ```
///
/// **Good:**
/// ```dart
/// @immutable
/// class Config {
///   const Config({required this.url});
///   final String url;
/// }
/// ```
class PreferConstConstructorsInImmutablesRule extends SaropaLintRule {
  PreferConstConstructorsInImmutablesRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_const_constructors_in_immutables',
    '[prefer_const_constructors_in_immutables] @immutable class has no const constructor. Add a const constructor so call sites can use const and reduce allocations.',
    correctionMessage:
        'Add the const keyword to the constructor. Ensure all field initializers are const-capable.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      final body = node.body;
      if (body is! BlockClassBody) return;
      if (!_isImmutableClass(node)) return;

      bool allFinal = true;
      bool hasGenerativeConstructor = false;
      bool hasConstConstructor = false;

      for (final ClassMember m in body.members) {
        if (m is FieldDeclaration && !m.isStatic) {
          if (!m.fields.isFinal || m.fields.isLate) allFinal = false;
        } else if (m is ConstructorDeclaration) {
          if (m.factoryKeyword == null) {
            hasGenerativeConstructor = true;
            if (m.constKeyword != null) hasConstConstructor = true;
          }
        }
      }

      if (!allFinal || !hasGenerativeConstructor || hasConstConstructor) return;

      reporter.atNode(node);
    });
  }

  static bool _isImmutableClass(ClassDeclaration node) {
    for (final Annotation a in node.metadata) {
      final String name = a.name.name;
      if (name == 'immutable') return true;
    }
    final ExtendsClause? ext = node.extendsClause;
    if (ext != null) {
      final String sup = ext.superclass.name.lexeme;
      if (sup == 'StatelessWidget' ||
          sup == 'StatefulWidget' ||
          sup == 'Widget') {
        return true;
      }
    }
    return false;
  }
}

/// Prefer declaring constructors as const when the class has only final fields.
///
/// Since: (roadmap task_prefer_const_constructor_declarations)
///
/// When all instance fields are final and the class has a generative
/// constructor, adding `const` enables const instances and compile-time
/// evaluation. This rule applies to plain classes; @immutable and Widget
/// subclasses are covered by [PreferConstConstructorsInImmutablesRule].
///
/// **Bad:**
/// ```dart
/// class Config {
///   final String url;
///   Config(this.url);
/// }
/// ```
///
/// **Good:**
/// ```dart
/// class Config {
///   final String url;
///   const Config(this.url);
/// }
/// ```
class PreferConstConstructorDeclarationsRule extends SaropaLintRule {
  PreferConstConstructorDeclarationsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_const_constructor_declarations',
    '[prefer_const_constructor_declarations] Constructor could be const. '
        'Class has only final fields; add const to the constructor declaration.',
    correctionMessage:
        'Add the const keyword to the constructor. Ensure all initializers are const-capable.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      final body = node.body;
      if (body is! BlockClassBody) return;
      if (_isImmutableOrWidget(node)) return;

      bool allFinal = true;
      ConstructorDeclaration? nonConstGenConstructor;

      for (final ClassMember m in body.members) {
        if (m is FieldDeclaration && !m.isStatic) {
          if (!m.fields.isFinal || m.fields.isLate) allFinal = false;
        } else if (m is ConstructorDeclaration) {
          if (m.factoryKeyword == null) {
            if (m.constKeyword == null) {
              nonConstGenConstructor = m;
            }
          }
        }
      }

      if (!allFinal || nonConstGenConstructor == null) return;
      reporter.atNode(nonConstGenConstructor);
    });
  }

  static bool _isImmutableOrWidget(ClassDeclaration node) {
    for (final Annotation a in node.metadata) {
      if (a.name.name == 'immutable') return true;
    }
    final ExtendsClause? ext = node.extendsClause;
    if (ext != null) {
      final String sup = ext.superclass.name.lexeme;
      if (sup == 'StatelessWidget' ||
          sup == 'StatefulWidget' ||
          sup == 'Widget') {
        return true;
      }
    }
    return false;
  }
}

/// Warns when a class field is never reassigned and could be final.
///
/// Since: v6.0.8 | Rule version: v1
///
/// **Bad:**
/// ```dart
/// class User {
///   String name;
///   User(this.name);
/// }
/// ```
///
/// **Good:**
/// ```dart
/// class User {
///   final String name;
///   User(this.name);
/// }
/// ```
class PreferFinalFieldsRule extends SaropaLintRule {
  PreferFinalFieldsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_final_fields',
    '[prefer_final_fields] Field is never reassigned and could be final. Marking it final makes immutability explicit and enables compiler optimizations.',
    correctionMessage: 'Add the final modifier to the field declaration.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      final body = node.body;
      if (body is! BlockClassBody) return;
      final Set<String> mutableFieldNames = <String>{};
      final Map<String, FieldDeclaration> mutableFieldByName =
          <String, FieldDeclaration>{};

      for (final ClassMember m in body.members) {
        if (m is! FieldDeclaration || m.isStatic) continue;
        if (m.fields.isFinal || m.fields.isConst || m.fields.isLate) continue;
        for (final VariableDeclaration v in m.fields.variables) {
          final String name = v.name.lexeme;
          mutableFieldNames.add(name);
          mutableFieldByName[name] = m;
        }
      }

      if (mutableFieldNames.isEmpty) return;

      final Set<String> assigned = <String>{};
      for (final ClassMember m in body.members) {
        if (m is ConstructorDeclaration) continue;
        m.visitChildren(_AssignmentToFieldVisitor(mutableFieldNames, assigned));
      }

      for (final String name in mutableFieldNames) {
        if (!assigned.contains(name)) {
          final fieldNode = mutableFieldByName[name];
          if (fieldNode != null) reporter.atNode(fieldNode);
        }
      }
    });
  }
}

/// All instance fields should be final.
///
/// Flags [FieldDeclaration] that are not static and not final/const. Stricter
/// than [PreferFinalFieldsRule] (which only flags when never reassigned).
/// Single registry callback; no recursion.
///
/// **Bad:**
/// ```dart
/// class C {
///   int x = 0;
///   String name;
/// }
/// ```
///
/// **Good:**
/// ```dart
/// class C {
///   final int x = 0;
///   final String name;
///   C(this.name);
/// }
/// ```
class PreferFinalFieldsAlwaysRule extends SaropaLintRule {
  PreferFinalFieldsAlwaysRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_final_fields_always',
    '[prefer_final_fields_always] Instance field should be final for immutability and clarity. {v1}',
    correctionMessage: 'Add the final modifier to the field declaration.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addFieldDeclaration((FieldDeclaration node) {
      if (node.isStatic) return;
      if (node.fields.isFinal || node.fields.isConst) return;
      reporter.atNode(node);
    });
  }
}

class _AssignmentToFieldVisitor extends RecursiveAstVisitor<void> {
  _AssignmentToFieldVisitor(this._fieldNames, this._assigned);

  final Set<String> _fieldNames;
  final Set<String> _assigned;

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    final Expression left = node.leftHandSide;
    if (left is SimpleIdentifier && _fieldNames.contains(left.name)) {
      _assigned.add(left.name);
    } else if (left is PropertyAccess) {
      if (left.target is ThisExpression) {
        final String name = left.propertyName.name;
        if (_fieldNames.contains(name)) _assigned.add(name);
      }
    }
    super.visitAssignmentExpression(node);
  }

  @override
  void visitPrefixExpression(PrefixExpression node) {
    if (node.operator.type == TokenType.PLUS_PLUS ||
        node.operator.type == TokenType.MINUS_MINUS) {
      final Expression operand = node.operand;
      if (operand is SimpleIdentifier && _fieldNames.contains(operand.name)) {
        _assigned.add(operand.name);
      } else if (operand is PropertyAccess &&
          operand.target is ThisExpression &&
          _fieldNames.contains(operand.propertyName.name)) {
        _assigned.add(operand.propertyName.name);
      }
    }
    super.visitPrefixExpression(node);
  }

  @override
  void visitPostfixExpression(PostfixExpression node) {
    if (node.operator.type == TokenType.PLUS_PLUS ||
        node.operator.type == TokenType.MINUS_MINUS) {
      final Expression operand = node.operand;
      if (operand is SimpleIdentifier && _fieldNames.contains(operand.name)) {
        _assigned.add(operand.name);
      } else if (operand is PropertyAccess &&
          operand.target is ThisExpression &&
          _fieldNames.contains(operand.propertyName.name)) {
        _assigned.add(operand.propertyName.name);
      }
    }
    super.visitPostfixExpression(node);
  }
}

/// Warns when a base class references its subclasses directly.
///
/// Since: v4.13.0 | Rule version: v1
///
/// Base classes should not reference their subclasses (e.g. return types,
/// parameter types) to keep the hierarchy one-way and avoid circular coupling.
///
/// **Bad:**
/// ```dart
/// class Base { Sub create() => Sub(); }
/// class Sub extends Base {}
/// ```
///
/// **Good:**
/// ```dart
/// class Base { Base create() => Sub(); }
/// class Sub extends Base {}
/// ```
class AvoidReferencingSubclassesRule extends SaropaLintRule {
  AvoidReferencingSubclassesRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_referencing_subclasses',
    '[avoid_referencing_subclasses] Base class should not reference its subclasses directly. Referencing subclasses creates circular coupling and makes the hierarchy harder to evolve.',
    correctionMessage:
        'Use the base type (or an interface) instead of the subclass type in the base class.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addCompilationUnit((CompilationUnit unit) {
      final Map<String, Set<String>> baseToSubs = <String, Set<String>>{};
      for (final Declaration d in unit.declarations) {
        if (d is ClassDeclaration) {
          final base = d.extendsClause?.superclass.name.lexeme;
          if (base != null) {
            baseToSubs.putIfAbsent(base, () => <String>{}).add(d.name.lexeme);
          }
        }
      }
      for (final Declaration d in unit.declarations) {
        if (d is! ClassDeclaration) continue;
        final baseName = d.name.lexeme;
        final subs = baseToSubs[baseName];
        if (subs == null || subs.isEmpty) continue;
        d.visitChildren(_SubclassReferenceVisitor(subs, reporter, _code));
      }
    });
  }
}

class _SubclassReferenceVisitor extends RecursiveAstVisitor<void> {
  _SubclassReferenceVisitor(this._subclassNames, this._reporter, this._code);

  final Set<String> _subclassNames;
  final SaropaDiagnosticReporter _reporter;
  final LintCode _code;

  @override
  void visitNamedType(NamedType node) {
    if (_subclassNames.contains(node.name.lexeme)) {
      _reporter.atNode(node, _code);
    }
    super.visitNamedType(node);
  }
}

// =============================================================================
// QUICK FIXES
// =============================================================================
