// ignore_for_file: depend_on_referenced_packages, deprecated_member_use, always_specify_types, todo

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart' show AnalysisError, DiagnosticSeverity;
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Warns when an empty spread is used.
///
/// Example of **bad** code:
/// ```dart
/// final list = [1, 2, ...[], 3];
/// ```
///
/// Example of **good** code:
/// ```dart
/// final list = [1, 2, 3];
/// ```
class AvoidEmptySpreadRule extends DartLintRule {
  const AvoidEmptySpreadRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_empty_spread',
    problemMessage: 'Empty spread has no effect.',
    correctionMessage: 'Remove the empty spread expression.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSpreadElement((SpreadElement node) {
      final Expression expression = node.expression;
      if (expression is ListLiteral && expression.elements.isEmpty) {
        reporter.atNode(node, code);
      } else if (expression is SetOrMapLiteral && expression.elements.isEmpty) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when unnecessary block braces are used.
///
/// A block inside another block that doesn't introduce scope
/// is unnecessary.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// void foo() {
///   {
///     print('hello');
///   }
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// void foo() {
///   print('hello');
/// }
/// ```
class AvoidUnnecessaryBlockRule extends DartLintRule {
  const AvoidUnnecessaryBlockRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_unnecessary_block',
    problemMessage: 'Unnecessary nested block.',
    correctionMessage: 'Remove the extra braces.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addBlock((Block node) {
      for (final Statement statement in node.statements) {
        if (statement is Block) {
          // A block directly inside another block is unnecessary
          // unless it's for scoping (which we can't easily detect)
          reporter.atNode(statement, code);
        }
      }
    });
  }
}

/// Warns when `.call()` is used explicitly on a callable.
///
/// The `.call()` method is invoked implicitly when using `()`.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// final fn = () => print('hello');
/// fn.call(); // Explicit .call()
/// ```
///
/// #### GOOD:
/// ```dart
/// final fn = () => print('hello');
/// fn(); // Implicit call
/// ```
class AvoidUnnecessaryCallRule extends DartLintRule {
  const AvoidUnnecessaryCallRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_unnecessary_call',
    problemMessage: 'Unnecessary explicit .call() invocation.',
    correctionMessage: 'Use implicit call with () instead.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name == 'call') {
        // Check if it's likely a function call
        final Expression? target = node.target;
        if (target != null) {
          reporter.atNode(node.methodName, code);
        }
      }
    });
  }
}

/// Warns when a class has an empty constructor (no parameters, no body, no initializers).
///
/// Empty constructors are redundant as Dart provides a default constructor.
///
/// Example of **bad** code:
/// ```dart
/// class MyClass {
///   MyClass();  // Unnecessary
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// class MyClass {
///   // No constructor needed, Dart provides default
/// }
/// ```
class AvoidUnnecessaryConstructorRule extends DartLintRule {
  const AvoidUnnecessaryConstructorRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_unnecessary_constructor',
    problemMessage: 'Unnecessary constructor. Dart provides a default constructor.',
    correctionMessage: 'Remove the empty constructor.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addConstructorDeclaration((ConstructorDeclaration node) {
      // Only check unnamed constructors
      if (node.name != null) return;

      // Check if it has parameters
      if (node.parameters.parameters.isNotEmpty) return;

      // Check if it has initializers
      if (node.initializers.isNotEmpty) return;

      // Check if it has a body with statements
      final FunctionBody body = node.body;
      if (body is BlockFunctionBody && body.block.statements.isNotEmpty) return;

      // Check if it's not a redirecting constructor
      if (node.redirectedConstructor != null) return;

      // Check if it has a const modifier (const constructors are often needed)
      if (node.constKeyword != null) return;

      // Check if it has a factory modifier
      if (node.factoryKeyword != null) return;

      // This is an empty constructor
      reporter.atNode(node, code);
    });
  }
}

/// Warns when enum arguments match the default and can be omitted.
///
/// Some enum constructors have default values that don't need to be specified.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// enum Status {
///   active(true),
///   inactive(false); // false is the default
///   const Status([this.isEnabled = false]);
///   final bool isEnabled;
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// enum Status {
///   active(true),
///   inactive; // Uses default
///   const Status([this.isEnabled = false]);
///   final bool isEnabled;
/// }
/// ```
class AvoidUnnecessaryEnumArgumentsRule extends DartLintRule {
  const AvoidUnnecessaryEnumArgumentsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_unnecessary_enum_arguments',
    problemMessage: 'Enum argument matches default value and can be omitted.',
    correctionMessage: 'Remove the argument to use the default value.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addEnumConstantDeclaration((EnumConstantDeclaration node) {
      final ArgumentList? args = node.arguments?.argumentList;
      if (args == null || args.arguments.isEmpty) return;

      // Check for common default value patterns
      for (final Expression arg in args.arguments) {
        if (arg is BooleanLiteral && !arg.value) {
          // false is often a default
          reporter.atNode(arg, code);
        } else if (arg is IntegerLiteral && arg.value == 0) {
          // 0 is often a default
          reporter.atNode(arg, code);
        } else if (arg is NullLiteral) {
          // null arguments are usually unnecessary
          reporter.atNode(arg, code);
        }
      }
    });
  }
}

/// Warns when using enum name prefix inside the enum declaration.
class AvoidUnnecessaryEnumPrefixRule extends DartLintRule {
  const AvoidUnnecessaryEnumPrefixRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_unnecessary_enum_prefix',
    problemMessage: 'Unnecessary enum name prefix inside enum declaration.',
    correctionMessage: 'Remove the enum name prefix when referencing values.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addEnumDeclaration((EnumDeclaration node) {
      final String enumName = node.name.lexeme;

      // Visit all expressions inside the enum
      node.accept(_EnumPrefixVisitor(enumName, reporter, code));
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_RemoveEnumPrefixFix()];
}

class _RemoveEnumPrefixFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addEnumDeclaration((EnumDeclaration node) {
      final String enumName = node.name.lexeme;

      node.accept(
        _EnumPrefixFixVisitor(
          enumName: enumName,
          reporter: reporter,
          analysisError: analysisError,
        ),
      );
    });
  }
}

class _EnumPrefixFixVisitor extends RecursiveAstVisitor<void> {
  _EnumPrefixFixVisitor({
    required this.enumName,
    required this.reporter,
    required this.analysisError,
  });

  final String enumName;
  final ChangeReporter reporter;
  final AnalysisError analysisError;

  void _applyFix(PrefixedIdentifier node) {
    final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
      message: 'Remove enum prefix',
      priority: 1,
    );

    changeBuilder.addDartFileEdit((builder) {
      // Replace "EnumName.value" with just "value"
      builder.addSimpleReplacement(
        SourceRange(node.offset, node.length),
        node.identifier.name,
      );
    });
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (node.prefix.name == enumName &&
        analysisError.offset == node.offset &&
        analysisError.length == node.length) {
      _applyFix(node);
    }
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitConstantPattern(ConstantPattern node) {
    final Expression expr = node.expression;
    if (expr is PrefixedIdentifier &&
        expr.prefix.name == enumName &&
        analysisError.offset == expr.offset &&
        analysisError.length == expr.length) {
      _applyFix(expr);
    }
    super.visitConstantPattern(node);
  }
}

class _EnumPrefixVisitor extends RecursiveAstVisitor<void> {
  _EnumPrefixVisitor(this.enumName, this.reporter, this.code);

  final String enumName;
  final DiagnosticReporter reporter;
  final LintCode code;

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (node.prefix.name == enumName) {
      reporter.atNode(node, code);
    }
    super.visitPrefixedIdentifier(node);
  }
}

/// Warns when a class explicitly extends Object.
///
/// All classes implicitly extend Object, so explicit extends is unnecessary.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// class MyClass extends Object { }
/// ```
///
/// #### GOOD:
/// ```dart
/// class MyClass { }
/// ```
class AvoidUnnecessaryExtendsRule extends DartLintRule {
  const AvoidUnnecessaryExtendsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_unnecessary_extends',
    problemMessage: 'Unnecessary extends Object.',
    correctionMessage: 'Remove the extends clause.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superclass = extendsClause.superclass.name.lexeme;
      if (superclass == 'Object') {
        reporter.atNode(extendsClause, code);
      }
    });
  }
}

/// Warns when a getter just returns a final field without any logic.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// class MyClass {
///   final int _value;
///   int get value => _value;  // Unnecessary getter
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// class MyClass {
///   final int value;  // Just make the field public
/// }
///
/// class MyClass {
///   final int _value;
///   int get value => _value * 2;  // Getter with logic
/// }
/// ```
class AvoidUnnecessaryGetterRule extends DartLintRule {
  const AvoidUnnecessaryGetterRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_unnecessary_getter',
    problemMessage: 'Getter just returns a final field without additional logic.',
    correctionMessage: 'Consider making the field public or adding meaningful logic.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Collect all final private fields
      final Set<String> finalPrivateFields = <String>{};
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          final VariableDeclarationList fields = member.fields;
          if (fields.isFinal) {
            for (final VariableDeclaration variable in fields.variables) {
              final String name = variable.name.lexeme;
              if (name.startsWith('_')) {
                finalPrivateFields.add(name);
              }
            }
          }
        }
      }

      if (finalPrivateFields.isEmpty) return;

      // Check getters
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration && member.isGetter) {
          final FunctionBody body = member.body;

          // Check arrow function body: get x => _x;
          if (body is ExpressionFunctionBody) {
            final Expression expr = body.expression;
            if (expr is SimpleIdentifier) {
              final String fieldName = expr.name;
              if (finalPrivateFields.contains(fieldName)) {
                // Check if getter name matches field without underscore
                final String getterName = member.name.lexeme;
                if (fieldName == '_$getterName') {
                  reporter.atNode(member, code);
                }
              }
            }
          }

          // Check block body: get x { return _x; }
          if (body is BlockFunctionBody) {
            final NodeList<Statement> statements = body.block.statements;
            if (statements.length == 1 && statements.first is ReturnStatement) {
              final ReturnStatement returnStmt = statements.first as ReturnStatement;
              final Expression? expr = returnStmt.expression;
              if (expr is SimpleIdentifier) {
                final String fieldName = expr.name;
                if (finalPrivateFields.contains(fieldName)) {
                  final String getterName = member.name.lexeme;
                  if (fieldName == '_$getterName') {
                    reporter.atNode(member, code);
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

/// Warns when length > 0 or length != 0 can be replaced with isNotEmpty.
class AvoidUnnecessaryLengthCheckRule extends DartLintRule {
  const AvoidUnnecessaryLengthCheckRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_unnecessary_length_check',
    problemMessage: 'Use isNotEmpty instead of length comparison.',
    correctionMessage: 'Replace with .isNotEmpty or .isEmpty.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addBinaryExpression((BinaryExpression node) {
      final String op = node.operator.lexeme;

      // Check for: length > 0, length != 0, length >= 1
      // And: 0 < length, 0 != length, 1 <= length
      // And: length == 0, length < 1, 0 == length
      PropertyAccess? lengthAccess;
      bool isNotEmptyPattern = false;
      bool isEmptyPattern = false;

      if (_isLengthAccess(node.leftOperand)) {
        lengthAccess = node.leftOperand as PropertyAccess;
        final Expression right = node.rightOperand;
        if (right is IntegerLiteral) {
          final int? value = right.value;
          if (value == 0) {
            if (op == '>' || op == '!=') isNotEmptyPattern = true;
            if (op == '==' || op == '<=') isEmptyPattern = true;
          } else if (value == 1) {
            if (op == '>=') isNotEmptyPattern = true;
            if (op == '<') isEmptyPattern = true;
          }
        }
      } else if (_isLengthAccess(node.rightOperand)) {
        lengthAccess = node.rightOperand as PropertyAccess;
        final Expression left = node.leftOperand;
        if (left is IntegerLiteral) {
          final int? value = left.value;
          if (value == 0) {
            if (op == '<' || op == '!=') isNotEmptyPattern = true;
            if (op == '==' || op == '>=') isEmptyPattern = true;
          } else if (value == 1) {
            if (op == '<=') isNotEmptyPattern = true;
            if (op == '>') isEmptyPattern = true;
          }
        }
      }

      if (lengthAccess != null && (isNotEmptyPattern || isEmptyPattern)) {
        reporter.atNode(node, code);
      }
    });
  }

  bool _isLengthAccess(Expression expr) {
    if (expr is PropertyAccess) {
      return expr.propertyName.name == 'length';
    }
    return false;
  }
}

/// Warns when negation can be simplified.
///
/// Double negations and negated comparisons can often be simplified
/// for better readability.
///
/// Example of **bad** code:
/// ```dart
/// if (!!value) { ... }  // Double negation
/// if (!(a == b)) { ... }  // Use !=
/// if (!(a > b)) { ... }  // Use <=
/// ```
///
/// Example of **good** code:
/// ```dart
/// if (value) { ... }
/// if (a != b) { ... }
/// if (a <= b) { ... }
/// ```
class AvoidUnnecessaryNegationsRule extends DartLintRule {
  const AvoidUnnecessaryNegationsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_unnecessary_negations',
    problemMessage: 'Unnecessary negation can be simplified.',
    correctionMessage: 'Simplify by using the opposite operator or removing double negation.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addPrefixExpression((PrefixExpression node) {
      if (node.operator.type != TokenType.BANG) return;

      final Expression operand = node.operand;

      // Check for double negation: !!x
      if (operand is PrefixExpression && operand.operator.type == TokenType.BANG) {
        reporter.atNode(node, code);
        return;
      }

      // Check for negated parenthesized comparison
      if (operand is ParenthesizedExpression) {
        final Expression inner = operand.expression;
        if (inner is BinaryExpression) {
          final TokenType op = inner.operator.type;
          // These can all be inverted
          if (op == TokenType.EQ_EQ ||
              op == TokenType.BANG_EQ ||
              op == TokenType.LT ||
              op == TokenType.GT ||
              op == TokenType.LT_EQ ||
              op == TokenType.GT_EQ) {
            reporter.atNode(node, code);
          }
        }
      }
    });
  }
}

/// Warns when super call is unnecessary in constructor.
///
/// Example of **bad** code:
/// ```dart
/// class Child extends Parent {
///   Child() : super();  // Unnecessary super()
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// class Child extends Parent {
///   Child();  // Implicit super()
/// }
/// ```
class AvoidUnnecessarySuperRule extends DartLintRule {
  const AvoidUnnecessarySuperRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_unnecessary_super',
    problemMessage: 'Unnecessary super() call with no arguments.',
    correctionMessage: 'Remove the super() call - it is implicit.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addConstructorDeclaration((ConstructorDeclaration node) {
      for (final ConstructorInitializer initializer in node.initializers) {
        if (initializer is SuperConstructorInvocation) {
          // Check if super() has no arguments and no name
          if (initializer.constructorName == null && initializer.argumentList.arguments.isEmpty) {
            reporter.atNode(initializer, code);
          }
        }
      }
    });
  }
}

/// Warns when an empty block is used.
///
/// Example of **bad** code:
/// ```dart
/// if (condition) { }
/// try { } catch (e) { }
/// ```
///
/// Example of **good** code:
/// ```dart
/// if (condition) {
///   // TODO: implement
/// }
/// ```
class NoEmptyBlockRule extends DartLintRule {
  const NoEmptyBlockRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'no_empty_block',
    problemMessage: 'Empty block detected.',
    correctionMessage: 'Add implementation or a comment explaining why it is empty.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addBlock((Block node) {
      if (node.statements.isEmpty) {
        // Skip if the block has a comment inside
        // We check by looking at the tokens between { and }
        final Token leftBracket = node.leftBracket;
        final Token rightBracket = node.rightBracket;

        // Check for comments between the brackets
        Token? current = leftBracket.next;
        while (current != null && current != rightBracket) {
          if (current.precedingComments != null) {
            return; // Has a comment, skip reporting
          }
          current = current.next;
        }

        // Skip constructor/method initializer lists and abstract methods
        final AstNode? parent = node.parent;
        if (parent is ConstructorDeclaration) return;
        if (parent is MethodDeclaration && parent.isAbstract) return;

        // Skip empty function bodies that are expression bodies
        if (parent is BlockFunctionBody) {
          final AstNode? grandparent = parent.parent;
          // Skip simple getters/setters that might need empty implementation
          if (grandparent is MethodDeclaration) {
            if (grandparent.isGetter || grandparent.isSetter) return;
          }
        }

        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when an empty string literal is used.
///
/// Example of **bad** code:
/// ```dart
/// if (value == '') { ... }
/// ```
///
/// Example of **good** code:
/// ```dart
/// if (value.isEmpty) { ... }
/// ```
class NoEmptyStringRule extends DartLintRule {
  const NoEmptyStringRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'no_empty_string',
    problemMessage: 'Avoid empty string literals.',
    correctionMessage: 'Use .isEmpty for comparisons.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSimpleStringLiteral((SimpleStringLiteral node) {
      if (node.value.isEmpty) {
        reporter.atNode(node, code);
      }
    });
  }
}
