// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

// ============================================================================
// STYLISTIC WHITESPACE & CONSTRUCTOR/PARAMETER RULES
// ============================================================================
//
// These rules are NOT included in any tier by default. They represent team
// preferences for whitespace and constructor patterns.
// ============================================================================

// =============================================================================
// WHITESPACE RULES
// =============================================================================

/// Warns when there is no blank line before the final return statement.
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of blank line before return:**
/// - Visual separation of return value
/// - Easier to spot function output
/// - More readable
///
/// **Cons (why some teams don't require it):**
/// - Extra whitespace
/// - Unnecessary for short functions
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// int calculate(int a, int b) {
///   final sum = a + b;
///   final product = a * b;
///   return sum + product;
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// int calculate(int a, int b) {
///   final sum = a + b;
///   final product = a * b;
///
///   return sum + product;
/// }
/// ```
class PreferBlankLineBeforeReturnRule extends SaropaLintRule {
  const PreferBlankLineBeforeReturnRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  static const LintCode _code = LintCode(
    name: 'prefer_blank_line_before_return',
    problemMessage: 'Add a blank line before the return statement.',
    correctionMessage: 'A blank line before return improves readability.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addBlock((node) {
      final statements = node.statements;
      if (statements.length < 2) return;

      final lastStmt = statements.last;
      if (lastStmt is! ReturnStatement) return;

      final secondLastStmt = statements[statements.length - 2];

      // Get line numbers
      final lastLine = resolver.lineInfo.getLocation(lastStmt.offset).lineNumber;
      final prevLine =
          resolver.lineInfo.getLocation(secondLastStmt.end).lineNumber;

      // Should have at least one blank line between them
      if (lastLine - prevLine < 2) {
        reporter.atNode(lastStmt, code);
      }
    });
  }
}

/// Warns when there IS a blank line before return (opposite rule).
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of no blank line:**
/// - Compact code
/// - Less vertical scrolling
/// - Simpler style
///
/// **Cons (why some teams prefer blank line):**
/// - Less visual separation
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// int calculate(int a, int b) {
///   final sum = a + b;
///
///   return sum;
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// int calculate(int a, int b) {
///   final sum = a + b;
///   return sum;
/// }
/// ```
class PreferNoBlankLineBeforeReturnRule extends SaropaLintRule {
  const PreferNoBlankLineBeforeReturnRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  static const LintCode _code = LintCode(
    name: 'prefer_no_blank_line_before_return',
    problemMessage: 'Remove the blank line before the return statement.',
    correctionMessage: 'Keep code compact without unnecessary blank lines.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addBlock((node) {
      final statements = node.statements;
      if (statements.length < 2) return;

      final lastStmt = statements.last;
      if (lastStmt is! ReturnStatement) return;

      final secondLastStmt = statements[statements.length - 2];

      final lastLine = resolver.lineInfo.getLocation(lastStmt.offset).lineNumber;
      final prevLine =
          resolver.lineInfo.getLocation(secondLastStmt.end).lineNumber;

      // Flag if there's a blank line
      if (lastLine - prevLine >= 2) {
        reporter.atNode(lastStmt, code);
      }
    });
  }
}

/// Warns when there is no blank line after variable declarations.
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of blank line after declarations:**
/// - Visual grouping of declarations
/// - Clear separation from logic
///
/// **Cons (why some teams don't require it):**
/// - Extra whitespace
/// - May be overkill for single declarations
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// void process() {
///   final a = 1;
///   final b = 2;
///   print(a + b);
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// void process() {
///   final a = 1;
///   final b = 2;
///
///   print(a + b);
/// }
/// ```
class PreferBlankLineAfterDeclarationsRule extends SaropaLintRule {
  const PreferBlankLineAfterDeclarationsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  static const LintCode _code = LintCode(
    name: 'prefer_blank_line_after_declarations',
    problemMessage: 'Add a blank line after variable declarations.',
    correctionMessage: 'Separate declarations from logic with a blank line.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addBlock((node) {
      final statements = node.statements;
      if (statements.length < 2) return;

      for (int i = 0; i < statements.length - 1; i++) {
        final current = statements[i];
        final next = statements[i + 1];

        // Check if current is a variable declaration and next is not
        if (current is VariableDeclarationStatement &&
            next is! VariableDeclarationStatement) {
          final currentLine =
              resolver.lineInfo.getLocation(current.end).lineNumber;
          final nextLine = resolver.lineInfo.getLocation(next.offset).lineNumber;

          if (nextLine - currentLine < 2) {
            reporter.atNode(current, code);
          }
        }
      }
    });
  }
}

/// Warns when there IS a blank line after declarations (opposite rule).
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of no blank line:**
/// - Compact code
/// - Declarations are close to usage
///
/// **Cons (why some teams prefer blank line):**
/// - Less visual separation
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// void process() {
///   final a = 1;
///
///   print(a);
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// void process() {
///   final a = 1;
///   print(a);
/// }
/// ```
class PreferCompactDeclarationsRule extends SaropaLintRule {
  const PreferCompactDeclarationsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  static const LintCode _code = LintCode(
    name: 'prefer_compact_declarations',
    problemMessage: 'Remove blank line after variable declarations.',
    correctionMessage: 'Keep declarations close to their usage.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addBlock((node) {
      final statements = node.statements;
      if (statements.length < 2) return;

      for (int i = 0; i < statements.length - 1; i++) {
        final current = statements[i];
        final next = statements[i + 1];

        if (current is VariableDeclarationStatement &&
            next is! VariableDeclarationStatement) {
          final currentLine =
              resolver.lineInfo.getLocation(current.end).lineNumber;
          final nextLine = resolver.lineInfo.getLocation(next.offset).lineNumber;

          if (nextLine - currentLine >= 2) {
            reporter.atNode(current, code);
          }
        }
      }
    });
  }
}

/// Warns when there are no blank lines between class members.
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of blank lines between members:**
/// - Clear separation of methods
/// - Easier to navigate
/// - More readable
///
/// **Cons (why some teams prefer compact):**
/// - More vertical scrolling
/// - Compact classes are easier to overview
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// class MyClass {
///   void method1() {}
///   void method2() {}
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// class MyClass {
///   void method1() {}
///
///   void method2() {}
/// }
/// ```
class PreferBlankLinesBetweenMembersRule extends SaropaLintRule {
  const PreferBlankLinesBetweenMembersRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  static const LintCode _code = LintCode(
    name: 'prefer_blank_lines_between_members',
    problemMessage: 'Add a blank line between class members.',
    correctionMessage: 'Blank lines between members improve readability.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((node) {
      final members = node.members;
      if (members.length < 2) return;

      for (int i = 0; i < members.length - 1; i++) {
        final current = members[i];
        final next = members[i + 1];

        // Skip field declarations - they can be grouped
        if (current is FieldDeclaration && next is FieldDeclaration) continue;

        final currentLine =
            resolver.lineInfo.getLocation(current.end).lineNumber;
        final nextLine = resolver.lineInfo.getLocation(next.offset).lineNumber;

        if (nextLine - currentLine < 2) {
          reporter.atNode(next, code);
        }
      }
    });
  }
}

/// Warns when there ARE blank lines between members (opposite rule).
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of compact members:**
/// - Less vertical scrolling
/// - Easier to see whole class
///
/// **Cons (why some teams prefer blank lines):**
/// - Harder to distinguish members
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// class MyClass {
///   void method1() {}
///
///   void method2() {}
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// class MyClass {
///   void method1() {}
///   void method2() {}
/// }
/// ```
class PreferCompactClassMembersRule extends SaropaLintRule {
  const PreferCompactClassMembersRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  static const LintCode _code = LintCode(
    name: 'prefer_compact_class_members',
    problemMessage: 'Remove blank lines between class members.',
    correctionMessage: 'Compact members make classes easier to overview.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((node) {
      final members = node.members;
      if (members.length < 2) return;

      for (int i = 0; i < members.length - 1; i++) {
        final current = members[i];
        final next = members[i + 1];

        final currentLine =
            resolver.lineInfo.getLocation(current.end).lineNumber;
        final nextLine = resolver.lineInfo.getLocation(next.offset).lineNumber;

        if (nextLine - currentLine >= 2) {
          reporter.atNode(next, code);
        }
      }
    });
  }
}

/// Warns when there are blank lines at the start/end of blocks.
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of no blank lines inside blocks:**
/// - Compact code
/// - No wasted vertical space
///
/// **Cons (why some teams allow it):**
/// - May want visual separation
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// void process() {
///
///   print('hello');
///
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// void process() {
///   print('hello');
/// }
/// ```
class PreferNoBlankLineInsideBlocksRule extends SaropaLintRule {
  const PreferNoBlankLineInsideBlocksRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  static const LintCode _code = LintCode(
    name: 'prefer_no_blank_line_inside_blocks',
    problemMessage: 'Remove blank line at start/end of block.',
    correctionMessage: 'Blocks should not have leading/trailing blank lines.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addBlock((node) {
      if (node.statements.isEmpty) return;

      // Check for blank line at start
      final openBraceLine =
          resolver.lineInfo.getLocation(node.leftBracket.offset).lineNumber;
      final firstStmtLine =
          resolver.lineInfo.getLocation(node.statements.first.offset).lineNumber;

      if (firstStmtLine - openBraceLine > 1) {
        reporter.atNode(node.statements.first, code);
      }

      // Check for blank line at end
      final lastStmtLine =
          resolver.lineInfo.getLocation(node.statements.last.end).lineNumber;
      final closeBraceLine =
          resolver.lineInfo.getLocation(node.rightBracket.offset).lineNumber;

      if (closeBraceLine - lastStmtLine > 1) {
        reporter.atNode(node.statements.last, code);
      }
    });
  }
}

/// Warns when there are more than one consecutive blank lines.
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of single blank lines:**
/// - Consistent spacing
/// - No excessive whitespace
///
/// **Cons (why some teams allow multiple):**
/// - May want stronger visual separation
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// void method1() {}
///
///
/// void method2() {}
/// ```
///
/// #### GOOD:
/// ```dart
/// void method1() {}
///
/// void method2() {}
/// ```
class PreferSingleBlankLineMaxRule extends SaropaLintRule {
  const PreferSingleBlankLineMaxRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  static const LintCode _code = LintCode(
    name: 'prefer_single_blank_line_max',
    problemMessage: 'Use at most one consecutive blank line.',
    correctionMessage: 'Multiple blank lines waste vertical space.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCompilationUnit((node) {
      final declarations = node.declarations;
      if (declarations.length < 2) return;

      for (int i = 0; i < declarations.length - 1; i++) {
        final current = declarations[i];
        final next = declarations[i + 1];

        final currentLine =
            resolver.lineInfo.getLocation(current.end).lineNumber;
        final nextLine = resolver.lineInfo.getLocation(next.offset).lineNumber;

        // More than 2 lines difference means 2+ blank lines
        if (nextLine - currentLine > 2) {
          reporter.atNode(next, code);
        }
      }
    });
  }
}

// =============================================================================
// CONSTRUCTOR & PARAMETER RULES
// =============================================================================

/// Warns when Dart 3 super parameters could be used.
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of super parameters:**
/// - Less boilerplate
/// - Cleaner constructor signatures
/// - Dart 3.0+ idiomatic
///
/// **Cons (why some teams prefer explicit):**
/// - More explicit about super calls
/// - Works in older Dart versions
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// class Child extends Parent {
///   Child({required String name}) : super(name: name);
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// class Child extends Parent {
///   Child({required super.name});
/// }
/// ```
class PreferSuperParametersRule extends SaropaLintRule {
  const PreferSuperParametersRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  static const LintCode _code = LintCode(
    name: 'prefer_super_parameters',
    problemMessage: 'Use super.parameter syntax instead of passing to super().',
    correctionMessage: 'Dart 3 super parameters reduce boilerplate.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addConstructorDeclaration((node) {
      // Check for super initializer
      for (final initializer in node.initializers) {
        if (initializer is SuperConstructorInvocation) {
          // Check if any arguments just pass through a parameter
          for (final arg in initializer.argumentList.arguments) {
            if (arg is NamedExpression) {
              final expr = arg.expression;
              if (expr is SimpleIdentifier) {
                // Check if this identifier matches a constructor parameter
                for (final param in node.parameters.parameters) {
                  final paramName = param.name?.lexeme;
                  if (paramName == expr.name &&
                      arg.name.label.name == paramName) {
                    reporter.atNode(arg, code);
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

/// Warns when initializing formals could be used.
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of initializing formals:**
/// - Less boilerplate
/// - Direct field initialization
/// - Cleaner constructor
///
/// **Cons (why some teams prefer explicit):**
/// - More explicit assignment
/// - Can add validation logic
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// class User {
///   final String name;
///   User(String name) : this.name = name;
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// class User {
///   final String name;
///   User(this.name);
/// }
/// ```
class PreferInitializingFormalsRule extends SaropaLintRule {
  const PreferInitializingFormalsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  static const LintCode _code = LintCode(
    name: 'prefer_initializing_formals',
    problemMessage: 'Use this.field syntax instead of initializer list.',
    correctionMessage: 'Initializing formals are more concise.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addConstructorDeclaration((node) {
      for (final initializer in node.initializers) {
        if (initializer is ConstructorFieldInitializer) {
          final value = initializer.expression;
          if (value is SimpleIdentifier) {
            // Check if the value matches a parameter name
            for (final param in node.parameters.parameters) {
              final paramName = param.name?.lexeme;
              if (paramName == value.name &&
                  initializer.fieldName.name == paramName) {
                reporter.atNode(initializer, code);
              }
            }
          }
        }
      }
    });
  }
}

/// Warns when constructor body assignment could use initializing formals (opposite).
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of body assignment:**
/// - Can add validation logic
/// - More explicit
/// - Flexible
///
/// **Cons (why some teams prefer initializing formals):**
/// - More verbose
/// - Field must not be final
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// class User {
///   final String name;
///   User(this.name);
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// class User {
///   final String name;
///   User(String name) : this.name = name;
/// }
/// ```
class PreferConstructorBodyAssignmentRule extends SaropaLintRule {
  const PreferConstructorBodyAssignmentRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  static const LintCode _code = LintCode(
    name: 'prefer_constructor_body_assignment',
    problemMessage: 'Use explicit initializer instead of this.field syntax.',
    correctionMessage: 'Explicit initializers allow for validation logic.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addConstructorDeclaration((node) {
      for (final param in node.parameters.parameters) {
        if (param is FieldFormalParameter) {
          reporter.atNode(param, code);
        }
      }
    });
  }
}

/// Warns when factory constructor could be used for validation.
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of factory for validation:**
/// - Can return null or different instance
/// - Clear that construction may fail
/// - Can cache instances
///
/// **Cons (why some teams prefer regular constructor):**
/// - Simpler API
/// - Assertions work for debug validation
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// class Email {
///   final String value;
///   Email(this.value) {
///     if (!value.contains('@')) throw ArgumentError('Invalid email');
///   }
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// class Email {
///   final String value;
///   Email._(this.value);
///
///   factory Email(String value) {
///     if (!value.contains('@')) throw ArgumentError('Invalid email');
///     return Email._(value);
///   }
/// }
/// ```
class PreferFactoryForValidationRule extends SaropaLintRule {
  const PreferFactoryForValidationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  static const LintCode _code = LintCode(
    name: 'prefer_factory_for_validation',
    problemMessage: 'Consider using factory constructor for validation logic.',
    correctionMessage: 'Factory constructors can handle validation failures.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addConstructorDeclaration((node) {
      // Skip factory constructors
      if (node.factoryKeyword != null) return;

      final body = node.body;
      if (body is! BlockFunctionBody) return;

      // Check if body contains throw or if validation
      for (final stmt in body.block.statements) {
        if (stmt is IfStatement) {
          final thenStmt = stmt.thenStatement;
          Statement? inner = thenStmt;
          if (inner is Block && inner.statements.isNotEmpty) {
            inner = inner.statements.first;
          }
          if (inner is ExpressionStatement &&
              inner.expression is ThrowExpression) {
            reporter.atNode(node, code);
            return;
          }
        } else if (stmt is ExpressionStatement &&
            stmt.expression is ThrowExpression) {
          reporter.atNode(node, code);
          return;
        }
      }
    });
  }
}

/// Warns when constructor assertion could be used instead of factory (opposite).
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of constructor assertion:**
/// - Simpler code
/// - Removed in release mode
/// - Standard Dart pattern
///
/// **Cons (why some teams prefer factory):**
/// - Assertions only run in debug
/// - Can't return null
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// class Positive {
///   final int value;
///   Positive._(this.value);
///   factory Positive(int value) {
///     if (value < 0) throw ArgumentError('Must be positive');
///     return Positive._(value);
///   }
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// class Positive {
///   final int value;
///   Positive(this.value) : assert(value >= 0, 'Must be positive');
/// }
/// ```
class PreferConstructorAssertionRule extends SaropaLintRule {
  const PreferConstructorAssertionRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  static const LintCode _code = LintCode(
    name: 'prefer_constructor_assertion',
    problemMessage: 'Consider using constructor assertion instead of factory.',
    correctionMessage: 'Constructor assertions are simpler for debug validation.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addConstructorDeclaration((node) {
      if (node.factoryKeyword == null) return;

      final body = node.body;
      if (body is! BlockFunctionBody) return;

      // Check if body is just validation + return
      final statements = body.block.statements;
      if (statements.length != 2) return;

      final first = statements.first;
      final second = statements.last;

      if (first is IfStatement && second is ReturnStatement) {
        final thenStmt = first.thenStatement;
        Statement? inner = thenStmt;
        if (inner is Block && inner.statements.length == 1) {
          inner = inner.statements.first;
        }
        if (inner is ExpressionStatement &&
            inner.expression is ThrowExpression) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when required parameters come after optional parameters.
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of required before optional:**
/// - Most important params first
/// - Clearer API
/// - Common convention
///
/// **Cons (why some teams prefer grouped by purpose):**
/// - Grouping by functionality may be clearer
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// void create({String? prefix, required String name, int? suffix});
/// ```
///
/// #### GOOD:
/// ```dart
/// void create({required String name, String? prefix, int? suffix});
/// ```
class PreferRequiredBeforeOptionalRule extends SaropaLintRule {
  const PreferRequiredBeforeOptionalRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  static const LintCode _code = LintCode(
    name: 'prefer_required_before_optional',
    problemMessage: 'Put required parameters before optional parameters.',
    correctionMessage: 'Required parameters should come first.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFormalParameterList((node) {
      bool seenOptional = false;

      for (final param in node.parameters) {
        final isRequired = param.isRequired;
        final isOptional = !isRequired;

        if (isOptional) {
          seenOptional = true;
        } else if (seenOptional && isRequired) {
          reporter.atNode(param, code);
        }
      }
    });
  }
}

/// Warns when parameters should be grouped by purpose (opposite).
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of grouping by purpose:**
/// - Related params together
/// - Clearer for complex APIs
///
/// **Cons (why some teams prefer required first):**
/// - Required params may be scattered
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// void create({required String name, String? prefix, required int id});
/// ```
///
/// #### GOOD:
/// ```dart
/// // Grouped by purpose: identity first, formatting second
/// void create({required String name, required int id, String? prefix});
/// ```
class PreferGroupedByPurposeRule extends SaropaLintRule {
  const PreferGroupedByPurposeRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  static const LintCode _code = LintCode(
    name: 'prefer_grouped_by_purpose',
    problemMessage: 'Group parameters by purpose rather than required/optional.',
    correctionMessage: 'Consider grouping related parameters together.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // This is a heuristic rule - it's hard to detect "purpose" statically
    // So we flag when required and optional alternate frequently
    context.registry.addFormalParameterList((node) {
      if (node.parameters.length < 4) return;

      int transitions = 0;
      bool? lastWasRequired;

      for (final param in node.parameters) {
        final isRequired = param.isRequired;
        if (lastWasRequired != null && lastWasRequired != isRequired) {
          transitions++;
        }
        lastWasRequired = isRequired;
      }

      // If there are many transitions, suggest grouping differently
      if (transitions >= 3) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when rethrow is not used to preserve stack trace.
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of rethrow:**
/// - Preserves original stack trace
/// - Cleaner syntax
/// - Idiomatic Dart
///
/// **Cons (why some teams use throw e):**
/// - Can modify exception before rethrowing
/// - More explicit
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// try {
///   doSomething();
/// } catch (e) {
///   log(e);
///   throw e;
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// try {
///   doSomething();
/// } catch (e) {
///   log(e);
///   rethrow;
/// }
/// ```
class PreferRethrowOverThrowERule extends SaropaLintRule {
  const PreferRethrowOverThrowERule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  static const LintCode _code = LintCode(
    name: 'prefer_rethrow_over_throw_e',
    problemMessage: 'Use rethrow instead of throw e to preserve stack trace.',
    correctionMessage: 'rethrow preserves the original stack trace.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCatchClause((node) {
      final exceptionParam = node.exceptionParameter?.name;
      if (exceptionParam == null) return;

      final body = node.body;
      for (final stmt in body.statements) {
        if (stmt is ExpressionStatement) {
          final expr = stmt.expression;
          if (expr is ThrowExpression) {
            final thrown = expr.expression;
            if (thrown is SimpleIdentifier &&
                thrown.name == exceptionParam.lexeme) {
              reporter.atNode(expr, code);
            }
          }
        }
      }
    });
  }
}
