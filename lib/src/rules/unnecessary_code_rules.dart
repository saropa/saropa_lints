// ignore_for_file: depend_on_referenced_packages, deprecated_member_use, always_specify_types, todo

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import '../saropa_lint_rule.dart';
import '../fixes/unnecessary_code/comment_out_empty_spread_fix.dart';
import '../fixes/unnecessary_code/comment_out_unnecessary_constructor_fix.dart';
import '../fixes/unnecessary_code/remove_extends_object_fix.dart';
import '../fixes/unnecessary_code/use_is_empty_or_is_not_empty_fix.dart';
import '../fixes/unnecessary_code/remove_unnecessary_call_fix.dart';
import '../fixes/unnecessary_code/remove_unnecessary_super_fix.dart';

/// Warns when an empty spread is used.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
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
  AvoidEmptySpreadRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  List<SaropaFixGenerator> get fixGenerators => [
        ({required CorrectionProducerContext context}) =>
            CommentOutEmptySpreadFix(context: context),
      ];

  static const LintCode _code = LintCode(
    'avoid_empty_spread',
    '[avoid_empty_spread] Empty spread operator (...[] or ...{}) adds nothing to your collection and may confuse readers. This is often a leftover from refactoring or copy-paste and serves no purpose. {v4}',
    correctionMessage:
        'Remove the empty spread from your collection literal. Only use spreads when they add elements. Clean up any unnecessary or misleading spread operators for clarity.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addSpreadElement((SpreadElement node) {
      final Expression expression = node.expression;
      if (expression is ListLiteral && expression.elements.isEmpty) {
        reporter.atNode(node);
      } else if (expression is SetOrMapLiteral && expression.elements.isEmpty) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when unnecessary block braces are used.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
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
  AvoidUnnecessaryBlockRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  static const LintCode _code = LintCode(
    'avoid_unnecessary_block',
    '[avoid_unnecessary_block] Unnecessary nested code blocks add clutter and reduce readability. They rarely serve a purpose and are often left from copy-paste or refactoring. {v4}',
    correctionMessage:
        'Remove extra braces from nested blocks that do not introduce a new scope. Only use additional blocks when needed for variable scope or clarity.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addBlock((Block node) {
      for (final Statement statement in node.statements) {
        if (statement is Block) {
          // A block directly inside another block is unnecessary
          // unless it's for scoping (which we can't easily detect)
          reporter.atNode(statement);
        }
      }
    });
  }
}

/// Warns when `.call()` is used explicitly on a callable.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
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
  AvoidUnnecessaryCallRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_unnecessary_call',
    '[avoid_unnecessary_call] Using .call() on a function or callable is redundant. Dart automatically calls .call() when you use (). {v4}',
    correctionMessage:
        'Replace fn.call() with fn(). Use the () operator for clarity and idiomatic Dart.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
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
  List<SaropaFixGenerator> get fixGenerators => [
        ({required CorrectionProducerContext context}) =>
            RemoveUnnecessaryCallFix(context: context),
      ];
}

/// Warns when a class has an empty constructor (no parameters, no body, no initializers).
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
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
  AvoidUnnecessaryConstructorRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  List<SaropaFixGenerator> get fixGenerators => [
        ({required CorrectionProducerContext context}) =>
            CommentOutUnnecessaryConstructorFix(context: context),
      ];

  static const LintCode _code = LintCode(
    'avoid_unnecessary_constructor',
    '[avoid_unnecessary_constructor] Empty constructors are redundant—Dart provides a default constructor automatically. Leaving them in adds noise and may confuse readers. {v5}',
    correctionMessage:
        'Remove empty constructors with no parameters, initializers, or body. Let Dart provide the default constructor.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addConstructorDeclaration((ConstructorDeclaration node) {
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
      reporter.atNode(node);
    });
  }
}

/// Warns when enum arguments match the default and can be omitted.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
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
  AvoidUnnecessaryEnumArgumentsRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_unnecessary_enum_arguments',
    '[avoid_unnecessary_enum_arguments] Providing an argument to an enum constructor that matches the default value is unnecessary and can make the code harder to read. It may also mislead readers into thinking the value is intentionally different from the default. {v4}',
    correctionMessage:
        'Remove arguments from enum constructors when they match the default value. This makes your code more concise and avoids confusion about the intent of the value.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addEnumConstantDeclaration((EnumConstantDeclaration node) {
      final ArgumentList? args = node.arguments?.argumentList;
      if (args == null || args.arguments.isEmpty) return;

      // Check for common default value patterns
      for (final Expression arg in args.arguments) {
        if (arg is BooleanLiteral && !arg.value) {
          // false is often a default
          reporter.atNode(arg);
        } else if (arg is IntegerLiteral && arg.value == 0) {
          // 0 is often a default
          reporter.atNode(arg);
        } else if (arg is NullLiteral) {
          // null arguments are usually unnecessary
          reporter.atNode(arg);
        }
      }
    });
  }
}

/// Warns when using enum name prefix inside the enum declaration.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
class AvoidUnnecessaryEnumPrefixRule extends SaropaLintRule {
  AvoidUnnecessaryEnumPrefixRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_unnecessary_enum_prefix',
    '[avoid_unnecessary_enum_prefix] Using the enum type name as a prefix when referencing enum values inside the enum declaration is redundant. Dart allows you to reference enum values directly within the enum, and including the prefix adds unnecessary verbosity. {v4}',
    correctionMessage:
        'Remove the enum type name prefix when referencing enum values inside the enum declaration. Use the value name directly for clarity and conciseness.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addEnumDeclaration((EnumDeclaration node) {
      final String enumName = node.name.lexeme;

      // Visit all expressions inside the enum
      node.accept(_EnumPrefixVisitor(enumName, reporter, code));
    });
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
      reporter.atNode(node);
    }
    super.visitPrefixedIdentifier(node);
  }
}

/// Warns when a class explicitly extends Object.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
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
  AvoidUnnecessaryExtendsRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  List<SaropaFixGenerator> get fixGenerators => [
        ({required CorrectionProducerContext context}) =>
            RemoveExtendsObjectFix(context: context),
      ];

  static const LintCode _code = LintCode(
    'avoid_unnecessary_extends',
    '[avoid_unnecessary_extends] All Dart classes implicitly extend Object, so explicitly writing extends Object is unnecessary and adds clutter to your class declaration. This can confuse readers and is never required. {v4}',
    correctionMessage:
        'Remove the extends Object clause from your class declaration. Dart will automatically inherit from Object, so this is always implied.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superclass = extendsClause.superclass.name.lexeme;
      if (superclass == 'Object') {
        reporter.atNode(extendsClause);
      }
    });
  }
}

/// Warns when a getter just returns a final field without any logic.
///
/// Since: v1.8.2 | Updated: v4.13.0 | Rule version: v6
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
  AvoidUnnecessaryGetterRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_unnecessary_getter',
    '[avoid_unnecessary_getter] Getter just returns a final field without additional logic. This unnecessary code increases cognitive load without providing functional benefit. {v6}',
    correctionMessage:
        'Prefer making the field public or adding meaningful logic. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
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
                  reporter.atNode(member);
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
                    reporter.atNode(member);
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
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// **Quick fix available:** Replaces with `.isEmpty` or `.isNotEmpty`.
class AvoidUnnecessaryLengthCheckRule extends SaropaLintRule {
  AvoidUnnecessaryLengthCheckRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  List<SaropaFixGenerator> get fixGenerators => [
        ({required CorrectionProducerContext context}) =>
            UseIsEmptyOrIsNotEmptyFix(context: context),
      ];

  static const LintCode _code = LintCode(
    'avoid_unnecessary_length_check',
    '[avoid_unnecessary_length_check] Use isNotEmpty instead of length comparison. Quick fix available: Replaces with .isEmpty or .isNotEmpty. {v4}',
    correctionMessage:
        'Replace with .isNotEmpty or .isEmpty. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addBinaryExpression((BinaryExpression node) {
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
        reporter.atNode(node);
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
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
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
  AvoidUnnecessaryNegationsRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_unnecessary_negations',
    '[avoid_unnecessary_negations] Unnecessary negation can be simplified. This unnecessary code increases cognitive load without providing functional benefit. {v5}',
    correctionMessage:
        'Simplify by using the opposite operator or removing double negation. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addPrefixExpression((PrefixExpression node) {
      if (node.operator.type != TokenType.BANG) return;

      final Expression operand = node.operand;

      // Check for double negation: !!x
      if (operand is PrefixExpression &&
          operand.operator.type == TokenType.BANG) {
        reporter.atNode(node);
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
            reporter.atNode(node);
          }
        }
      }
    });
  }
}

/// Warns when super call is unnecessary in constructor.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
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
  AvoidUnnecessarySuperRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  List<SaropaFixGenerator> get fixGenerators => [
        ({required CorrectionProducerContext context}) =>
            RemoveUnnecessarySuperFix(context: context),
      ];

  static const LintCode _code = LintCode(
    'avoid_unnecessary_super',
    '[avoid_unnecessary_super] Unnecessary super() call with no arguments. Super call is unnecessary in constructor. This unnecessary code increases cognitive load without providing functional benefit. {v4}',
    correctionMessage:
        'Remove the super() call - it is implicit. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addConstructorDeclaration((ConstructorDeclaration node) {
      for (final ConstructorInitializer initializer in node.initializers) {
        if (initializer is SuperConstructorInvocation) {
          // Check if super() has no arguments and no name
          if (initializer.constructorName == null &&
              initializer.argumentList.arguments.isEmpty) {
            reporter.atNode(initializer);
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
class NoEmptyBlockRule extends SaropaLintRule {
  NoEmptyBlockRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  static const String _name = 'no_empty_block';

  static const LintCode _code = LintCode(
    _name,
    '[no_empty_block] An empty code block (i.e., {}) does not perform any action and may indicate incomplete code, a forgotten implementation, or a placeholder left by mistake. Empty blocks can confuse maintainers and may hide bugs or unfinished features.',
    correctionMessage:
        'Add meaningful implementation or a comment inside the block to clarify its purpose. If the block is intentionally left empty, use `// ignore: $_name` to suppress the lint and document why the block is empty.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addBlock((Block node) {
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
        if (_hasIgnoreCommentOnLine(context, node)) {
          return;
        }

        // Hyphenated ignore comments handled automatically by SaropaLintRule
        reporter.atNode(node);
      }
    });
  }

  /// Checks if there's an ignore comment for this rule on the same line as the node.
  bool _hasIgnoreCommentOnLine(SaropaContext context, AstNode node) {
    try {
      final String content = context.fileContent;
      final List<String> lines = content.split('\n');

      // Check the line where the block ends (the } character)
      final int blockEndLine = context.lineInfo
          .getLocation(node.end - 1)
          .lineNumber;
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
        final int stmtEndLine = context.lineInfo
            .getLocation(statement.end - 1)
            .lineNumber;
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
}

/// Warns when an empty string literal is used.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v6
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
  NoEmptyStringRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'no_empty_string',
    '[no_empty_string] Using empty string literals ("") in your code can be ambiguous and may indicate a missing value or a placeholder. Relying on empty strings for logic can lead to subtle bugs and makes intent unclear to readers. {v6}',
    correctionMessage:
        'Instead of using empty string literals directly, use .isEmpty or .isNotEmpty for string comparisons. This makes your intent explicit and your code more robust.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addSimpleStringLiteral((SimpleStringLiteral node) {
      if (node.value.isEmpty) {
        reporter.atNode(node);
      }
    });
  }
}
