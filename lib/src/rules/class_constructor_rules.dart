// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

/// Warns when a class declares a call() method.
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
  const AvoidDeclaringCallMethodRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_declaring_call_method',
    problemMessage:
        '[avoid_declaring_call_method] call() method makes class callable but hides intent. Code reads ambiguously. A class declares a call() method.',
    correctionMessage:
        'Use descriptive method name: execute(), invoke(), or run() instead. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme == 'call') {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when a generic type parameter shadows a top-level declaration.
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
  const AvoidGenericsShadowingRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_generics_shadowing',
    problemMessage:
        '[avoid_generics_shadowing] Generic type parameter shadows a top-level declaration. This class design reduces clarity and can lead to incorrect object initialization.',
    correctionMessage:
        'Rename the generic parameter to avoid shadowing. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
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
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addTypeParameterList((TypeParameterList node) {
      for (final TypeParameter param in node.typeParameters) {
        final String name = param.name.lexeme;
        if (_commonTypes.contains(name)) {
          reporter.atNode(param, code);
        }
      }
    });
  }
}

/// Warns when a copyWith method is missing fields.
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
  const AvoidIncompleteCopyWithRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_incomplete_copy_with',
    problemMessage:
        '[avoid_incomplete_copy_with] copyWith() is missing fields. Copied objects will lose data for those fields. All non-final fields must be included in copyWith for complete copying.',
    correctionMessage:
        'Add missing fields as nullable parameters: copyWith({String? name, int? age}). Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Collect all instance fields
      final Set<String> fieldNames = <String>{};
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration && !member.isStatic) {
          for (final VariableDeclaration variable in member.fields.variables) {
            fieldNames.add(variable.name.lexeme);
          }
        }
      }

      if (fieldNames.isEmpty) return;

      // Find copyWith method
      for (final ClassMember member in node.members) {
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
            reporter.atNode(member, code);
          }
        }
      }
    });
  }
}

/// Warns when constructor body contains logic.
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
  const AvoidNonEmptyConstructorBodiesRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_non_empty_constructor_bodies',
    problemMessage:
        '[avoid_non_empty_constructor_bodies] Constructor body has logic. Final fields cannot be set in body, only initializers. Constructor bodies with logic can be harder to understand. Prefer using initializer lists or factory constructors.',
    correctionMessage:
        'Move logic to initializer list: MyClass(input) : name = input.trim();. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addConstructorDeclaration((ConstructorDeclaration node) {
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
          reporter.atToken(nameToken, code);
        } else {
          reporter.atNode(node.returnType, code);
        }
      }
    });
  }
}

/// Warns when a variable or parameter shadows another declaration from an
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
  const AvoidShadowingRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  /// Alias: avoid_shadowing
  static const LintCode _code = LintCode(
    name: 'avoid_variable_shadowing',
    problemMessage:
        '[avoid_variable_shadowing] Declaration shadows a declaration from an outer scope. Shadowing occurs when a nested scope declares a variable with the same name as one in an enclosing scope. This can lead to confusion about which variable is being referenced and is a common source of subtle bugs.',
    correctionMessage:
        'Rename the variable to avoid confusion. Verify the change works correctly with existing tests and add coverage for the new behavior.',
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
      final _ShadowingChecker checker =
          _ShadowingChecker(reporter, code, <String>{functionName});

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

    context.registry.addMethodDeclaration((MethodDeclaration node) {
      final String methodName = node.name.lexeme;
      final _ShadowingChecker checker =
          _ShadowingChecker(reporter, code, <String>{methodName});

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
      reporter.atNode(node, code);
    } else {
      outerNames.add(name);
    }
    super.visitVariableDeclaration(node);
  }

  @override
  void visitDeclaredIdentifier(DeclaredIdentifier node) {
    final String name = node.name.lexeme;
    if (outerNames.contains(name)) {
      reporter.atNode(node, code);
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
  const PreferConstStringListRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_const_string_list',
    problemMessage:
        '[prefer_const_string_list] This <String>[...] list contains only string literals '
        'and could be const.',
    correctionMessage: 'Add const before the list literal or use a const '
        'variable declaration.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addListLiteral((ListLiteral node) {
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

      final bool allStringLiterals =
          elements.every((CollectionElement element) {
        if (element is SimpleStringLiteral) {
          return true;
        }
        if (element is AdjacentStrings) {
          // Adjacent string literals like 'hello' 'world'
          return element.strings
              .every((StringLiteral s) => s is SimpleStringLiteral);
        }
        return false;
      });

      if (allStringLiterals) {
        reporter.atNode(node, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_PreferConstStringListFix()];

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
class PreferDeclaringConstConstructorRule extends SaropaLintRule {
  const PreferDeclaringConstConstructorRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_declaring_const_constructor',
    problemMessage:
        '[prefer_declaring_const_constructor] Class could have a const constructor. A class could have a const constructor but doesn\'t. This class design reduces clarity and can lead to incorrect object initialization.',
    correctionMessage:
        'Add const keyword to constructor. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if all instance fields are final
      bool allFieldsFinal = true;
      bool hasFields = false;

      for (final ClassMember member in node.members) {
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

      for (final ClassMember member in node.members) {
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
        for (final ClassMember member in node.members) {
          if (member is ConstructorDeclaration &&
              member.constKeyword == null &&
              member.factoryKeyword == null) {
            reporter.atToken(member.name ?? node.name, code);
            break;
          }
        }
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_PreferDeclaringConstConstructorFix()];
}

/// Warns when extension type representation fields are public.
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
  const PreferPrivateExtensionTypeFieldRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_private_extension_type_field',
    problemMessage:
        '[prefer_private_extension_type_field] Extension type representation field must be private. Extension type fields must be private for encapsulation.',
    correctionMessage:
        'Use a private field with underscore prefix. Verify the change works correctly with existing tests and add coverage for the new behavior.',
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
      final Token fieldName = representation.fieldName;

      if (!fieldName.lexeme.startsWith('_')) {
        reporter.atToken(fieldName, code);
      }
    });
  }
}

/// Warns when super lifecycle methods are called in wrong order.
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
  const ProperSuperCallsRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'proper_super_calls',
    problemMessage:
        '[proper_super_calls] Super lifecycle method called in wrong order. In State classes, super.initState() must be called first, and super.dispose() must be called last.',
    correctionMessage:
        'super.initState() must be first; super.dispose() must be last. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
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
  const AvoidUnmarkedPublicClassRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_unmarked_public_class',
    problemMessage:
        '[avoid_unmarked_public_class] Public class lacks an explicit class modifier. Dart 3.0 introduced class modifiers (base, final, interface, sealed). For API stability, public classes should declare their inheritance intent.',
    correctionMessage:
        'Add base, final, interface, or sealed modifier (Dart 3.0+). Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final String className = node.name.lexeme;

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

      reporter.atToken(node.name, code);
    });
  }
}

/// Warns when a concrete class could be marked `final`.
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
  const PreferFinalClassRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_final_class',
    problemMessage:
        '[prefer_final_class] Prefer marking this class as final. Dart 3.0 introduced the final modifier to prevent subclassing. Classes that are not designed for extension must be marked final.',
    correctionMessage:
        'Add final modifier if this class is not designed for extension (Dart 3.0+). Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final String className = node.name.lexeme;

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

      for (final ClassMember member in node.members) {
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
        reporter.atToken(node.name, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_PreferFinalClassFix()];
}

/// Warns when an abstract class with only abstract members could be `interface`.
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
  const PreferInterfaceClassRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_interface_class',
    problemMessage:
        '[prefer_interface_class] Abstract class with only abstract members could be interface. Dart 3.0 introduced the interface modifier for pure contracts. Abstract classes with no implementation should use interface class.',
    correctionMessage:
        'Use interface class for pure contracts (Dart 3.0+). Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
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
      if (node.name.lexeme.startsWith('_')) return;

      // Check if all members are abstract (no concrete implementations)
      bool hasConcreteImplementation = false;

      for (final ClassMember member in node.members) {
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
      if (!hasConcreteImplementation && node.members.isNotEmpty) {
        reporter.atToken(node.name, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_PreferInterfaceClassFix()];
}

/// Warns when an abstract class with implementation could be `base`.
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
  const PreferBaseClassRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_base_class',
    problemMessage:
        '[prefer_base_class] Abstract class with shared implementation could be base. Dart 3.0 introduced the base modifier for classes meant to be extended but not implemented directly.',
    correctionMessage:
        'Use abstract base class to prevent direct implementation (Dart 3.0+). Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
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
      if (node.name.lexeme.startsWith('_')) return;

      // Check if class has both abstract and concrete members
      bool hasAbstractMember = false;
      bool hasConcreteImplementation = false;

      for (final ClassMember member in node.members) {
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
        reporter.atToken(node.name, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_PreferBaseClassFix()];
}

// =============================================================================
// QUICK FIXES
// =============================================================================

class _PreferConstStringListFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addListLiteral((ListLiteral node) {
      if (!analysisError.sourceRange.intersects(node.sourceRange)) return;

      final changeBuilder = reporter.createChangeBuilder(
        message: 'Add const keyword',
        priority: 80,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(node.offset, 'const ');
      });
    });
  }
}

class _PreferDeclaringConstConstructorFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addConstructorDeclaration((ConstructorDeclaration node) {
      if (!analysisError.sourceRange.intersects(node.sourceRange)) return;

      final changeBuilder = reporter.createChangeBuilder(
        message: 'Add const keyword',
        priority: 80,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(node.offset, 'const ');
      });
    });
  }
}

class _PreferFinalClassFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      if (!analysisError.sourceRange.intersects(node.sourceRange)) return;

      final changeBuilder = reporter.createChangeBuilder(
        message: 'Add final modifier',
        priority: 80,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(node.classKeyword.offset, 'final ');
      });
    });
  }
}

class _PreferInterfaceClassFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      if (!analysisError.sourceRange.intersects(node.sourceRange)) return;

      final changeBuilder = reporter.createChangeBuilder(
        message: 'Add interface modifier',
        priority: 80,
      );

      changeBuilder.addDartFileEdit((builder) {
        // Insert before 'abstract' keyword if present, else before 'class'
        final insertOffset =
            node.abstractKeyword?.offset ?? node.classKeyword.offset;
        builder.addSimpleInsertion(insertOffset, 'interface ');
      });
    });
  }
}

class _PreferBaseClassFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      if (!analysisError.sourceRange.intersects(node.sourceRange)) return;

      final changeBuilder = reporter.createChangeBuilder(
        message: 'Add base modifier',
        priority: 80,
      );

      changeBuilder.addDartFileEdit((builder) {
        // Insert before 'abstract' keyword if present, else before 'class'
        final insertOffset =
            node.abstractKeyword?.offset ?? node.classKeyword.offset;
        builder.addSimpleInsertion(insertOffset, 'base ');
      });
    });
  }
}
