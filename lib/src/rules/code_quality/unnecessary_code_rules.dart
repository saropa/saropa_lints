// ignore_for_file: depend_on_referenced_packages, deprecated_member_use, always_specify_types, todo

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import '../../saropa_lint_rule.dart';
import '../../fixes/unnecessary_code/comment_out_empty_spread_fix.dart';
import '../../fixes/unnecessary_code/comment_out_unnecessary_constructor_fix.dart';
import '../../fixes/unnecessary_code/invert_unnecessary_negation_fix.dart';
import '../../fixes/unnecessary_code/remove_extends_object_fix.dart';
import '../../fixes/unnecessary_code/use_is_empty_or_is_not_empty_fix.dart';
import '../../fixes/unnecessary_code/remove_unnecessary_call_fix.dart';
import '../../fixes/unnecessary_code/no_empty_string_prefer_is_empty_fix.dart';
import '../../fixes/unnecessary_code/remove_unnecessary_block_fix.dart';
import '../../fixes/unnecessary_code/remove_unnecessary_enum_argument_fix.dart';
import '../../fixes/unnecessary_code/remove_unnecessary_enum_prefix_fix.dart';
import '../../fixes/unnecessary_code/remove_unnecessary_getter_fix.dart';
import '../../fixes/unnecessary_code/no_empty_block_fix.dart';
import '../../fixes/unnecessary_code/remove_unnecessary_super_fix.dart';
import '../../fixes/unnecessary_code/replace_null_aware_spread_fix.dart';
import '../../fixes/unnecessary_code/reuse_assigned_local_fix.dart';

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
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'maintainability'};

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

/// Warns when null-aware spread (...?) is used for collections that cannot be null.
///
/// **Bad:**
/// ```dart
/// final List<int> list = [1, 2];
/// final combined = [0, ...?list];  // list is never null
/// ```
///
/// **Good:**
/// ```dart
/// final combined = [0, ...list];
/// ```
class AvoidUnnecessaryNullAwareElementsRule extends SaropaLintRule {
  AvoidUnnecessaryNullAwareElementsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'maintainability'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_unnecessary_null_aware_elements',
    '[avoid_unnecessary_null_aware_elements] Null-aware spread (...?) is unnecessary when the collection is never null. Use ... instead.',
    correctionMessage: 'Replace ...? with ... if the collection is non-null.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addSpreadElement((SpreadElement node) {
      if (!node.isNullAware) return;
      reporter.atNode(node);
    });
  }

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        ReplaceNullAwareSpreadFix(context: context),
  ];
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
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'maintainability'};

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

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        RemoveUnnecessaryBlockFix(context: context),
  ];
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
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'maintainability'};

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
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'maintainability'};

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
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'maintainability'};

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

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        RemoveUnnecessaryEnumArgumentFix(context: context),
  ];
}

/// Warns when using enum name prefix inside the enum declaration.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
class AvoidUnnecessaryEnumPrefixRule extends SaropaLintRule {
  AvoidUnnecessaryEnumPrefixRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'maintainability'};

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
      final String enumName = node.nameToken.lexeme;

      // Visit all expressions inside the enum
      node.accept(_EnumPrefixVisitor(enumName, reporter, code));
    });
  }

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        RemoveUnnecessaryEnumPrefixFix(context: context),
  ];
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
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'maintainability'};

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
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'maintainability'};

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
      for (final ClassMember member in node.bodyMembers) {
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
      for (final ClassMember member in node.bodyMembers) {
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
            if (statements.length == 1) {
              final Statement firstStmt = statements.first;
              if (firstStmt is ReturnStatement) {
                final Expression? expr = firstStmt.expression;
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
      }
    });
  }

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        RemoveUnnecessaryGetterFix(context: context),
  ];
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
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'maintainability'};

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

      final Expression leftOp = node.leftOperand;
      if (_isLengthAccess(leftOp) && leftOp is PropertyAccess) {
        lengthAccess = leftOp;
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
      } else {
        final Expression rightOp = node.rightOperand;
        if (_isLengthAccess(rightOp) && rightOp is PropertyAccess) {
          lengthAccess = rightOp;
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
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'maintainability'};

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

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        InvertUnnecessaryNegationFix(context: context),
  ];
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
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'maintainability'};

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
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'maintainability'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  static const String _name = 'no_empty_block';

  /// String literal required here so scripts/modules/_rule_metrics.py can
  /// parse the rule name for fixture coverage (LintCode first argument).
  static const LintCode _code = LintCode(
    'no_empty_block', // keep in sync with _name for ignore comments
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

        // Ignore checks are handled centrally by SaropaDiagnosticReporter.
        reporter.atNode(node);
      }
    });
  }

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        NoEmptyBlockFix(context: context),
  ];
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
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'maintainability'};

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
      if (node.value.isNotEmpty) return;

      // Only flag empty strings in equality comparisons where
      // .isEmpty / .isNotEmpty is a viable alternative.
      // Skip: return '', ?? '', default params, replaceAll args, etc.
      final AstNode? parent = node.parent;
      if (parent is! BinaryExpression) return;

      final TokenType op = parent.operator.type;
      if (op != TokenType.EQ_EQ && op != TokenType.BANG_EQ) return;

      reporter.atNode(node);
    });
  }

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        NoEmptyStringPreferIsEmptyFix(context: context),
  ];
}

/// Warns when a local already holds a value but the identical expression is
/// recomputed instead of reusing the local.
///
/// Since: v13.11.14 | Rule version: v1
///
/// A local variable is assigned a pure-read expression (a member chain, an
/// index access, or a deterministic call), then that **same expression is
/// re-evaluated verbatim** later in the same block instead of reusing the
/// local. The value was already computed and named; recomputing it wastes work
/// and lets the two copies silently drift apart if one is later edited.
///
/// This is the complement of `prefer_cached_getter`, which fires when a value
/// is read repeatedly and *no* local caches it (its fix is "create a local").
/// Here the local already exists, so the fix is "reuse it" — giving this rule a
/// near-zero false-positive surface.
///
/// **BAD:**
/// ```dart
/// final host = contact.websites?.firstOrNull?.host;
/// if (host == null) return null;
/// return Label(text: contact.websites?.firstOrNull?.host); // recomputed
/// ```
///
/// **GOOD:**
/// ```dart
/// final host = contact.websites?.firstOrNull?.host;
/// if (host == null) return null;
/// return Label(text: host);
/// ```
///
/// **Quick fix available:** Replaces the recomputed expression with the local.
class PreferReusingAssignedLocalRule extends SaropaLintRule {
  PreferReusingAssignedLocalRule() : super(code: _code);

  /// Minor cleanup. Large counts acceptable; each is a local, safe fix.
  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'maintainability', 'dart-core'};

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_reusing_assigned_local',
    '[prefer_reusing_assigned_local] A local variable already holds the result '
        'of this expression, but the identical expression is recomputed here '
        'instead of reusing that local. Recomputing wastes work and risks the '
        'two copies drifting apart if one is later edited. {v2}',
    correctionMessage:
        'Replace the recomputed expression with the existing local variable '
        'that already holds its value.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addBlock((Block block) {
      final List<Statement> statements = block.statements;
      // Need at least a declaration and one later statement to recompute in.
      if (statements.length < 2) return;

      // 1. Record the first pure-read local declaration per initializer source.
      //    Keying on source means a later identical declaration also resolves
      //    back to the original local.
      final Map<String, _AssignedLocal> firstDecls = <String, _AssignedLocal>{};
      for (final Statement statement in statements) {
        if (statement is! VariableDeclarationStatement) continue;
        for (final VariableDeclaration variable
            in statement.variables.variables) {
          final Expression? initializer = variable.initializer;
          if (initializer == null) continue;
          if (!_isReusableInitializer(initializer)) continue;
          firstDecls.putIfAbsent(
            initializer.toSource(),
            () => _AssignedLocal(
              name: variable.name.lexeme,
              initializer: initializer,
              referencedNames: _collectReferencedNames(initializer)
                ..add(variable.name.lexeme),
            ),
          );
        }
      }
      if (firstDecls.isEmpty) return;

      // 2. Walk the block once to collect every matching expression and every
      //    point at which a referenced identifier is mutated.
      final _BlockReuseScanner scanner = _BlockReuseScanner(
        firstDecls.keys.toSet(),
      );
      block.accept(scanner);

      for (final MapEntry<String, _AssignedLocal> entry in firstDecls.entries) {
        final _AssignedLocal local = entry.value;
        // The earliest offset at which the receiver/local may have changed.
        // Past this point the recompute is no longer guaranteed redundant.
        final int barrier = scanner.mutationBarrierFor(
          local.referencedNames,
          afterOffset: local.initializer.end,
        );

        for (final Expression reuse in scanner.occurrencesOf(entry.key)) {
          // Skip the declaration's own initializer and anything before it.
          if (reuse.offset <= local.initializer.offset) continue;
          // Skip recomputes after a mutation could have changed the value.
          if (reuse.offset >= barrier) continue;
          // Skip write targets (`obj.field = x`): a write is not a redundant
          // read, and rewriting it to the local would be wrong.
          if (_isWriteTarget(reuse)) continue;
          // Skip occurrences whose identifiers resolve to DIFFERENT elements
          // than the declaration's, even though the source text is identical.
          // A nested closure parameter (e.g. a `FutureBuilder` builder whose
          // `snapshot` shadows the outer `StreamBuilder` `snapshot`) produces
          // the same text against a different, differently-typed binding;
          // reusing the outer local there reads the wrong value or fails to
          // compile. Text equality alone cannot see the shadow — element
          // identity can.
          if (!_sameBindings(local.initializer, reuse)) continue;

          reporter.atNode(reuse);
        }
      }
    });
  }

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        ReuseAssignedLocalFix(context: context),
  ];

  /// Whether [expr] is a pure read whose result is safe to reuse from a local.
  ///
  /// Only member chains, index reads, and deterministic calls qualify. Anything
  /// non-deterministic, side-effecting, or identity-sensitive is rejected by
  /// [_InitializerPurityVisitor] so that legitimately-differing recomputes
  /// (e.g. `DateTime.now()`, `Random().nextInt(6)`) are never flagged.
  static bool _isReusableInitializer(Expression expr) {
    if (expr is! PropertyAccess &&
        expr is! PrefixedIdentifier &&
        expr is! IndexExpression &&
        expr is! MethodInvocation) {
      return false;
    }
    final _InitializerPurityVisitor visitor = _InitializerPurityVisitor();
    expr.accept(visitor);
    return visitor.isPure;
  }

  /// Whether [node] sits in a write position (assignment LHS or `++`/`--`).
  static bool _isWriteTarget(Expression node) {
    final AstNode? parent = node.parent;
    if (parent is AssignmentExpression && parent.leftHandSide == node) {
      return true;
    }
    if (parent is PostfixExpression && parent.operand == node) return true;
    if (parent is PrefixExpression && parent.operand == node) return true;
    return false;
  }

  /// Collects every simple-identifier name referenced anywhere in [expr].
  ///
  /// These are the names whose mutation between the declaration and a recompute
  /// would change the value, so any of them being written invalidates reuse.
  static Set<String> _collectReferencedNames(Expression expr) {
    final _IdentifierNameCollector collector = _IdentifierNameCollector();
    expr.accept(collector);
    return collector.names;
  }

  /// Whether [reuse] reads the SAME bindings as the declaration's [declInit].
  ///
  /// An occurrence is only matched to a declaration by source text, so a name
  /// re-bound in an inner scope (a closure parameter shadowing an outer local)
  /// can produce identical text against a different element. Because the two
  /// expressions are matched on `toSource()` equality, their AST shapes — and
  /// therefore their in-order identifier sequences — are identical, so we can
  /// compare resolved elements position-by-position.
  ///
  /// Conservative: a mismatch only counts when BOTH identifiers resolve to a
  /// non-null element and those elements differ. Unresolved identifiers
  /// (e.g. members read off a `dynamic` receiver) leave behavior unchanged.
  static bool _sameBindings(Expression declInit, Expression reuse) {
    final List<Element?> declElements =
        (_IdentifierElementCollector()..visitExpression(declInit)).elements;
    final List<Element?> reuseElements =
        (_IdentifierElementCollector()..visitExpression(reuse)).elements;
    // Identical source guarantees identical length; bail safely if it ever
    // diverges rather than risk an out-of-range read.
    if (declElements.length != reuseElements.length) return true;
    for (int i = 0; i < declElements.length; i++) {
      final Element? a = declElements[i];
      final Element? b = reuseElements[i];
      if (a == null || b == null) continue;
      if (!identical(a, b) && a != b) return false;
    }
    return true;
  }
}

/// A local declaration whose initializer is a reusable pure read.
class _AssignedLocal {
  _AssignedLocal({
    required this.name,
    required this.initializer,
    required this.referencedNames,
  });

  final String name;
  final Expression initializer;
  final Set<String> referencedNames;
}

/// Rejects initializers whose value is non-deterministic, side-effecting, or
/// identity-sensitive, so reuse never changes program behavior.
class _InitializerPurityVisitor extends RecursiveAstVisitor<void> {
  bool isPure = true;

  /// Method/getter names whose result may differ between calls. A reference to
  /// any of these (as a call or a property) disqualifies the initializer.
  static const Set<String> _nonDeterministicNames = <String>{
    'now',
    'current',
    'random',
    'next',
    'nextInt',
    'nextDouble',
    'nextBool',
    'nextBytes',
    'uuid',
    'v1',
    'v4',
    'read',
    'readLine',
    'readAsString',
    'readAsStringSync',
    'readAsBytes',
    'readAsBytesSync',
    'elapsed',
    'elapsedMilliseconds',
    'elapsedMicroseconds',
    'elapsedTicks',
  };

  // Object allocation: reusing changes identity, which `identical()` and
  // mutation-after-construction can observe.
  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    isPure = false;
  }

  // Closures allocate a fresh function object each evaluation.
  @override
  void visitFunctionExpression(FunctionExpression node) {
    isPure = false;
  }

  // Side effects / async: value or effects need not repeat.
  @override
  void visitAwaitExpression(AwaitExpression node) {
    isPure = false;
  }

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    isPure = false;
  }

  @override
  void visitCascadeExpression(CascadeExpression node) {
    isPure = false;
  }

  @override
  void visitThrowExpression(ThrowExpression node) {
    isPure = false;
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (_nonDeterministicNames.contains(node.name)) isPure = false;
    super.visitSimpleIdentifier(node);
  }
}

/// Collects the names of all simple identifiers in an expression subtree.
class _IdentifierNameCollector extends RecursiveAstVisitor<void> {
  final Set<String> names = <String>{};

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    names.add(node.name);
    super.visitSimpleIdentifier(node);
  }
}

/// Collects the resolved element of every simple identifier in traversal order.
///
/// Used to compare two source-identical expressions binding-by-binding so a
/// shadowed name (same text, different element) is not treated as a recompute.
class _IdentifierElementCollector extends RecursiveAstVisitor<void> {
  final List<Element?> elements = <Element?>[];

  void visitExpression(Expression expr) => expr.accept(this);

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    elements.add(node.element);
    super.visitSimpleIdentifier(node);
  }
}

/// Single-pass scan of a block recording (a) expressions whose source matches a
/// tracked local's initializer and (b) mutation points for any identifier.
class _BlockReuseScanner extends RecursiveAstVisitor<void> {
  _BlockReuseScanner(this._targetSources);

  final Set<String> _targetSources;
  final Map<String, List<Expression>> _occurrences =
      <String, List<Expression>>{};
  // (offset, mutatedRootName) for each in-block mutation, in visit order.
  final List<({int offset, String name})> _mutations =
      <({int offset, String name})>[];

  /// Method names that mutate their receiver. A call to one of these on an
  /// identifier referenced by a cached expression invalidates a later reuse.
  static const Set<String> _mutatingMethods = <String>{
    'add',
    'addAll',
    'addEntries',
    'remove',
    'removeAt',
    'removeLast',
    'removeWhere',
    'removeRange',
    'clear',
    'insert',
    'insertAll',
    'setAll',
    'setRange',
    'retainWhere',
    'fillRange',
    'sort',
    'shuffle',
    'putIfAbsent',
    'update',
    'updateAll',
    'write',
    'writeln',
    'writeAll',
  };

  List<Expression> occurrencesOf(String source) =>
      _occurrences[source] ?? const <Expression>[];

  /// Earliest mutation offset after [afterOffset] that touches any of [names],
  /// or a sentinel beyond any real offset when none exists.
  int mutationBarrierFor(Set<String> names, {required int afterOffset}) {
    int barrier = 1 << 30;
    for (final ({int offset, String name}) event in _mutations) {
      if (event.offset > afterOffset &&
          event.offset < barrier &&
          names.contains(event.name)) {
        barrier = event.offset;
      }
    }
    return barrier;
  }

  void _recordOccurrence(Expression node) {
    final String source = node.toSource();
    if (_targetSources.contains(source)) {
      _occurrences.putIfAbsent(source, () => <Expression>[]).add(node);
    }
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    _recordOccurrence(node);
    super.visitPropertyAccess(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    _recordOccurrence(node);
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitIndexExpression(IndexExpression node) {
    _recordOccurrence(node);
    super.visitIndexExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    _recordOccurrence(node);
    if (_mutatingMethods.contains(node.methodName.name)) {
      final String? root = _rootIdentifierName(node.target);
      if (root != null) {
        _mutations.add((offset: node.offset, name: root));
      }
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    final String? root = _rootIdentifierName(node.leftHandSide);
    if (root != null) {
      _mutations.add((offset: node.leftHandSide.offset, name: root));
    }
    super.visitAssignmentExpression(node);
  }

  @override
  void visitPostfixExpression(PostfixExpression node) {
    if (node.operator.type == TokenType.PLUS_PLUS ||
        node.operator.type == TokenType.MINUS_MINUS) {
      final String? root = _rootIdentifierName(node.operand);
      if (root != null) {
        _mutations.add((offset: node.operand.offset, name: root));
      }
    }
    super.visitPostfixExpression(node);
  }

  @override
  void visitPrefixExpression(PrefixExpression node) {
    if (node.operator.type == TokenType.PLUS_PLUS ||
        node.operator.type == TokenType.MINUS_MINUS) {
      final String? root = _rootIdentifierName(node.operand);
      if (root != null) {
        _mutations.add((offset: node.operand.offset, name: root));
      }
    }
    super.visitPrefixExpression(node);
  }
}

/// Returns the leftmost identifier name of a member/index/call chain, e.g.
/// `list` for `list.length`, `m` for `m[k]`, `Json` for `Json.decode(x)`.
String? _rootIdentifierName(Expression? expr) {
  Expression? current = expr;
  while (current != null) {
    if (current is SimpleIdentifier) return current.name;
    if (current is PrefixedIdentifier) return current.prefix.name;
    if (current is PropertyAccess) {
      current = current.target;
    } else if (current is IndexExpression) {
      current = current.target;
    } else if (current is MethodInvocation) {
      current = current.target;
    } else {
      return null;
    }
  }
  return null;
}
