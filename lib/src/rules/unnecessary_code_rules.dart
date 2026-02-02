// ignore_for_file: depend_on_referenced_packages, deprecated_member_use, always_specify_types, todo

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;
import 'package:analyzer/source/source_range.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

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
///
/// **Quick fix available:** Comments out the empty spread.
class AvoidEmptySpreadRule extends SaropaLintRule {
  const AvoidEmptySpreadRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_empty_spread',
    problemMessage:
        '[avoid_empty_spread] Empty spread operator (...[] or ...{}) adds nothing to your collection and may confuse readers. This is often a leftover from refactoring or copy-paste and serves no purpose.',
    correctionMessage:
        'Remove the empty spread from your collection literal. Only use spreads when they add elements. Clean up any unnecessary or misleading spread operators for clarity.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
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

  @override
  List<Fix> getFixes() => <Fix>[_CommentOutEmptySpreadFix()];
}

class _CommentOutEmptySpreadFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addSpreadElement((SpreadElement node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Comment out empty spread',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          SourceRange(node.offset, node.length),
          '/* ${node.toSource()} */',
        );
      });
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
class AvoidUnnecessaryBlockRule extends SaropaLintRule {
  const AvoidUnnecessaryBlockRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  static const LintCode _code = LintCode(
    name: 'avoid_unnecessary_block',
    problemMessage:
        '[avoid_unnecessary_block] Unnecessary nested code blocks add clutter and reduce readability. They rarely serve a purpose and are often left from copy-paste or refactoring.',
    correctionMessage:
        'Remove extra braces from nested blocks that do not introduce a new scope. Only use additional blocks when needed for variable scope or clarity.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
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
///
/// **Quick fix available:** Replaces `target.call(args)` with `target(args)`.
class AvoidUnnecessaryCallRule extends SaropaLintRule {
  const AvoidUnnecessaryCallRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_unnecessary_call',
    problemMessage:
        '[avoid_unnecessary_call] Using .call() on a function or callable is redundant. Dart automatically calls .call() when you use ().',
    correctionMessage:
        'Replace fn.call() with fn(). Use the () operator for clarity and idiomatic Dart.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
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

  @override
  List<Fix> getFixes() => <Fix>[_RemoveUnnecessaryCallFix()];
}

class _RemoveUnnecessaryCallFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'call') return;
      if (!node.methodName.sourceRange.intersects(analysisError.sourceRange)) {
        return;
      }

      final Expression? target = node.target;
      if (target == null) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Remove .call()',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        // Replace "target.call(args)" with "target(args)"
        final String targetSource = target.toSource();
        final String argsSource = node.argumentList.toSource();
        builder.addSimpleReplacement(
          SourceRange(node.offset, node.length),
          '$targetSource$argsSource',
        );
      });
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
///
/// **Quick fix available:** Comments out the unnecessary constructor.
class AvoidUnnecessaryConstructorRule extends SaropaLintRule {
  const AvoidUnnecessaryConstructorRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_unnecessary_constructor',
    problemMessage:
        '[avoid_unnecessary_constructor] Empty constructors are redundant—Dart provides a default constructor automatically. Leaving them in adds noise and may confuse readers.',
    correctionMessage:
        'Remove empty constructors with no parameters, initializers, or body. Let Dart provide the default constructor.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
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

  @override
  List<Fix> getFixes() => <Fix>[_CommentOutUnnecessaryConstructorFix()];
}

class _CommentOutUnnecessaryConstructorFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addConstructorDeclaration((ConstructorDeclaration node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Comment out unnecessary constructor',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          SourceRange(node.offset, node.length),
          '// ${node.toSource()}',
        );
      });
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
class AvoidUnnecessaryEnumArgumentsRule extends SaropaLintRule {
  const AvoidUnnecessaryEnumArgumentsRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_unnecessary_enum_arguments',
    problemMessage:
        '[avoid_unnecessary_enum_arguments] Providing an argument to an enum constructor that matches the default value is unnecessary and can make the code harder to read. It may also mislead readers into thinking the value is intentionally different from the default.',
    correctionMessage:
        'Remove arguments from enum constructors when they match the default value. This makes your code more concise and avoids confusion about the intent of the value.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
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
class AvoidUnnecessaryEnumPrefixRule extends SaropaLintRule {
  const AvoidUnnecessaryEnumPrefixRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_unnecessary_enum_prefix',
    problemMessage:
        '[avoid_unnecessary_enum_prefix] Using the enum type name as a prefix when referencing enum values inside the enum declaration is redundant. Dart allows you to reference enum values directly within the enum, and including the prefix adds unnecessary verbosity.',
    correctionMessage:
        'Remove the enum type name prefix when referencing enum values inside the enum declaration. Use the value name directly for clarity and conciseness.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
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
  final SaropaDiagnosticReporter reporter;
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
///
/// **Quick fix available:** Removes the `extends Object` clause.
class AvoidUnnecessaryExtendsRule extends SaropaLintRule {
  const AvoidUnnecessaryExtendsRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_unnecessary_extends',
    problemMessage:
        '[avoid_unnecessary_extends] All Dart classes implicitly extend Object, so explicitly writing extends Object is unnecessary and adds clutter to your class declaration. This can confuse readers and is never required.',
    correctionMessage:
        'Remove the extends Object clause from your class declaration. Dart will automatically inherit from Object, so this is always implied.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
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

  @override
  List<Fix> getFixes() => <Fix>[_RemoveExtendsObjectFix()];
}

class _RemoveExtendsObjectFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;
      if (!extendsClause.sourceRange.intersects(analysisError.sourceRange)) {
        return;
      }

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Remove extends Object',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        // Find the end of the previous element (type parameters or class name)
        final int previousEnd = node.typeParameters?.end ?? node.name.end;
        // Delete from end of previous element to end of extends clause
        builder.addDeletion(
          SourceRange(previousEnd, extendsClause.end - previousEnd),
        );
      });
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
class AvoidUnnecessaryGetterRule extends SaropaLintRule {
  const AvoidUnnecessaryGetterRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_unnecessary_getter',
    problemMessage:
        '[avoid_unnecessary_getter] Getter just returns a final field without additional logic.',
    correctionMessage:
        'Consider making the field public or adding meaningful logic.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
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
              final ReturnStatement returnStmt =
                  statements.first as ReturnStatement;
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
///
/// **Quick fix available:** Replaces with `.isEmpty` or `.isNotEmpty`.
class AvoidUnnecessaryLengthCheckRule extends SaropaLintRule {
  const AvoidUnnecessaryLengthCheckRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_unnecessary_length_check',
    problemMessage:
        '[avoid_unnecessary_length_check] Use isNotEmpty instead of length comparison.',
    correctionMessage: 'Replace with .isNotEmpty or .isEmpty.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
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

  @override
  List<Fix> getFixes() => <Fix>[_UseIsEmptyOrIsNotEmptyFix()];
}

class _UseIsEmptyOrIsNotEmptyFix extends DartFix {
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

      final String op = node.operator.lexeme;
      PropertyAccess? lengthAccess;
      String replacement = '';

      if (_isLengthAccess(node.leftOperand)) {
        lengthAccess = node.leftOperand as PropertyAccess;
        final Expression right = node.rightOperand;
        if (right is IntegerLiteral) {
          final int? value = right.value;
          if (value == 0) {
            if (op == '>' || op == '!=') {
              replacement = '${lengthAccess.target!.toSource()}.isNotEmpty';
            } else if (op == '==' || op == '<=') {
              replacement = '${lengthAccess.target!.toSource()}.isEmpty';
            }
          } else if (value == 1) {
            if (op == '>=') {
              replacement = '${lengthAccess.target!.toSource()}.isNotEmpty';
            } else if (op == '<') {
              replacement = '${lengthAccess.target!.toSource()}.isEmpty';
            }
          }
        }
      } else if (_isLengthAccess(node.rightOperand)) {
        lengthAccess = node.rightOperand as PropertyAccess;
        final Expression left = node.leftOperand;
        if (left is IntegerLiteral) {
          final int? value = left.value;
          if (value == 0) {
            if (op == '<' || op == '!=') {
              replacement = '${lengthAccess.target!.toSource()}.isNotEmpty';
            } else if (op == '==' || op == '>=') {
              replacement = '${lengthAccess.target!.toSource()}.isEmpty';
            }
          } else if (value == 1) {
            if (op == '<=') {
              replacement = '${lengthAccess.target!.toSource()}.isNotEmpty';
            } else if (op == '>') {
              replacement = '${lengthAccess.target!.toSource()}.isEmpty';
            }
          }
        }
      }

      if (replacement.isEmpty) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: replacement.contains('isNotEmpty')
            ? 'Use .isNotEmpty'
            : 'Use .isEmpty',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          SourceRange(node.offset, node.length),
          replacement,
        );
      });
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
class AvoidUnnecessaryNegationsRule extends SaropaLintRule {
  const AvoidUnnecessaryNegationsRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_unnecessary_negations',
    problemMessage:
        '[avoid_unnecessary_negations] Unnecessary negation can be simplified.',
    correctionMessage:
        'Simplify by using the opposite operator or removing double negation.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addPrefixExpression((PrefixExpression node) {
      if (node.operator.type != TokenType.BANG) return;

      final Expression operand = node.operand;

      // Check for double negation: !!x
      if (operand is PrefixExpression &&
          operand.operator.type == TokenType.BANG) {
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
///
/// **Quick fix available:** Removes the `super()` call.
class AvoidUnnecessarySuperRule extends SaropaLintRule {
  const AvoidUnnecessarySuperRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_unnecessary_super',
    problemMessage:
        '[avoid_unnecessary_super] Unnecessary super() call with no arguments.',
    correctionMessage: 'Remove the super() call - it is implicit.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addConstructorDeclaration((ConstructorDeclaration node) {
      for (final ConstructorInitializer initializer in node.initializers) {
        if (initializer is SuperConstructorInvocation) {
          // Check if super() has no arguments and no name
          if (initializer.constructorName == null &&
              initializer.argumentList.arguments.isEmpty) {
            reporter.atNode(initializer, code);
          }
        }
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_RemoveUnnecessarySuperFix()];
}

class _RemoveUnnecessarySuperFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addConstructorDeclaration((ConstructorDeclaration node) {
      for (int i = 0; i < node.initializers.length; i++) {
        final ConstructorInitializer initializer = node.initializers[i];
        if (initializer is SuperConstructorInvocation) {
          if (!initializer.sourceRange.intersects(analysisError.sourceRange)) {
            continue;
          }

          final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
            message: 'Remove super()',
            priority: 1,
          );

          changeBuilder.addDartFileEdit((builder) {
            if (node.initializers.length == 1) {
              // Remove colon and super()
              final int colonOffset = node.separator!.offset;
              builder.addDeletion(
                SourceRange(colonOffset, initializer.end - colonOffset),
              );
            } else if (i == 0) {
              // First initializer, remove it and following comma
              builder.addDeletion(
                SourceRange(
                  initializer.offset,
                  node.initializers[1].offset - initializer.offset,
                ),
              );
            } else {
              // Not first, remove preceding comma and super()
              builder.addDeletion(
                SourceRange(
                  node.initializers[i - 1].end,
                  initializer.end - node.initializers[i - 1].end,
                ),
              );
            }
          });
          return;
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
class NoEmptyBlockRule extends SaropaLintRule {
  const NoEmptyBlockRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  static const String _name = 'no_empty_block';

  static const LintCode _code = LintCode(
    name: _name,
    problemMessage:
        '[no_empty_block] An empty code block (i.e., {}) does not perform any action and may indicate incomplete code, a forgotten implementation, or a placeholder left by mistake. Empty blocks can confuse maintainers and may hide bugs or unfinished features.',
    correctionMessage:
        'Add meaningful implementation or a comment inside the block to clarify its purpose. If the block is intentionally left empty, use `// ignore: $_name` to suppress the lint and document why the block is empty.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
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

        // Also check if the right bracket has preceding comments
        // This catches: { /* comment */ } where no tokens exist between braces
        if (rightBracket.precedingComments != null) {
          return; // Has a comment before closing bracket
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

        // Check for ignore comment on the same line using source content
        if (_hasIgnoreCommentOnLine(resolver, node)) {
          return;
        }

        // Hyphenated ignore comments handled automatically by SaropaLintRule
        reporter.atNode(node, code);
      }
    });
  }

  /// Checks if there's an ignore comment for this rule on the same line as the node.
  bool _hasIgnoreCommentOnLine(CustomLintResolver resolver, AstNode node) {
    try {
      final String content = resolver.source.contents.data;
      final List<String> lines = content.split('\n');

      // Check the line where the block ends (the } character)
      final int blockEndLine =
          resolver.lineInfo.getLocation(node.end - 1).lineNumber;
      if (blockEndLine > 0 && blockEndLine <= lines.length) {
        final String line = lines[blockEndLine - 1];
        if (line.contains('// ignore: $_name') ||
            line.contains('// ignore: ${_name.replaceAll('_', '-')}')) {
          return true;
        }
      }

      // Also check the line where the containing statement ends
      AstNode? statement = node.parent;
      while (statement != null && statement is! ExpressionStatement) {
        if (statement is FunctionBody) break;
        statement = statement.parent;
      }
      if (statement is ExpressionStatement) {
        final int stmtEndLine =
            resolver.lineInfo.getLocation(statement.end - 1).lineNumber;
        if (stmtEndLine > 0 && stmtEndLine <= lines.length) {
          final String line = lines[stmtEndLine - 1];
          if (line.contains('// ignore: $_name') ||
              line.contains('// ignore: ${_name.replaceAll('_', '-')}')) {
            return true;
          }
        }
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddEmptyBlockCommentFix()];
}

class _AddEmptyBlockCommentFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addBlock((Block node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;
      if (node.statements.isNotEmpty) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add explanatory comment',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        // Insert comment after the opening brace with minimal indentation
        // The formatter will adjust indentation appropriately
        final int insertOffset = node.leftBracket.end;
        builder.addSimpleInsertion(
          insertOffset,
          '\n  // HACK: Intentionally empty - explain why\n',
        );
      });
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
class NoEmptyStringRule extends SaropaLintRule {
  const NoEmptyStringRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'no_empty_string',
    problemMessage:
        '[no_empty_string] Using empty string literals ("") in your code can be ambiguous and may indicate a missing value or a placeholder. Relying on empty strings for logic can lead to subtle bugs and makes intent unclear to readers.',
    correctionMessage:
        'Instead of using empty string literals directly, use .isEmpty or .isNotEmpty for string comparisons. This makes your intent explicit and your code more robust.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSimpleStringLiteral((SimpleStringLiteral node) {
      if (node.value.isEmpty) {
        reporter.atNode(node, code);
      }
    });
  }
}
