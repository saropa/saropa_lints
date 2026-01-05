// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

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
class AvoidDeclaringCallMethodRule extends DartLintRule {
  const AvoidDeclaringCallMethodRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_declaring_call_method',
    problemMessage: 'Avoid declaring a call() method.',
    correctionMessage: 'Use a more descriptive method name like execute() or invoke().',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
class AvoidGenericsShadowingRule extends DartLintRule {
  const AvoidGenericsShadowingRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_generics_shadowing',
    problemMessage: 'Generic type parameter shadows a top-level declaration.',
    correctionMessage: 'Rename the generic parameter to avoid shadowing.',
    errorSeverity: DiagnosticSeverity.WARNING,
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
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
class AvoidIncompleteCopyWithRule extends DartLintRule {
  const AvoidIncompleteCopyWithRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_incomplete_copy_with',
    problemMessage: 'copyWith method may be missing fields.',
    correctionMessage: 'Ensure all class fields are included in copyWith.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
class AvoidNonEmptyConstructorBodiesRule extends DartLintRule {
  const AvoidNonEmptyConstructorBodiesRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_non_empty_constructor_bodies',
    problemMessage: 'Constructor body contains logic.',
    correctionMessage: 'Use initializer list or factory constructor.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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

/// Warns when a declaration shadows another declaration in an outer scope.
///
/// Shadowing can lead to confusion and bugs.
///
/// Example of **bad** code:
/// ```dart
/// int value = 10;
/// void process(int value) {  // Shadows outer 'value'
///   print(value);
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// int globalValue = 10;
/// void process(int localValue) {
///   print(localValue);
/// }
/// ```
class AvoidShadowingRule extends DartLintRule {
  const AvoidShadowingRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_shadowing',
    problemMessage: 'Declaration shadows a declaration from an outer scope.',
    correctionMessage: 'Rename the variable to avoid confusion.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
      final String functionName = node.name.lexeme;
      final _ShadowingChecker checker = _ShadowingChecker(reporter, code, <String>{functionName});

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
      final _ShadowingChecker checker = _ShadowingChecker(reporter, code, <String>{methodName});

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

  final DiagnosticReporter reporter;
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
class PreferConstStringListRule extends DartLintRule {
  const PreferConstStringListRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_const_string_list',
    problemMessage: 'This <String>[...] list contains only string literals '
        'and could be const.',
    correctionMessage: 'Add const before the list literal or use a const '
        'variable declaration.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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

      final bool allStringLiterals = elements.every((CollectionElement element) {
        if (element is SimpleStringLiteral) {
          return true;
        }
        if (element is AdjacentStrings) {
          // Adjacent string literals like 'hello' 'world'
          return element.strings.every((StringLiteral s) => s is SimpleStringLiteral);
        }
        return false;
      });

      if (allStringLiterals) {
        reporter.atNode(node, code);
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
class PreferDeclaringConstConstructorRule extends DartLintRule {
  const PreferDeclaringConstConstructorRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_declaring_const_constructor',
    problemMessage: 'Class could have a const constructor.',
    correctionMessage: 'Add const keyword to constructor.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
class PreferPrivateExtensionTypeFieldRule extends DartLintRule {
  const PreferPrivateExtensionTypeFieldRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_private_extension_type_field',
    problemMessage: 'Extension type representation field should be private.',
    correctionMessage: 'Use a private field with underscore prefix.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addExtensionTypeDeclaration((ExtensionTypeDeclaration node) {
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
class ProperSuperCallsRule extends DartLintRule {
  const ProperSuperCallsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'proper_super_calls',
    problemMessage: 'Super lifecycle method called in wrong order.',
    correctionMessage: 'super.initState() should be first; super.dispose() should be last.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
            if (target is SuperExpression && expr.methodName.name == methodName) {
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
