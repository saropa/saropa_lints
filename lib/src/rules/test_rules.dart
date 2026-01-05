// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Warns when duplicate test assertions are made.
///
/// Example of **bad** code:
/// ```dart
/// test('example', () {
///   expect(value, equals(1));
///   expect(value, equals(1));  // Duplicate
/// });
/// ```
///
/// Example of **good** code:
/// ```dart
/// test('example', () {
///   expect(value, equals(1));
///   expect(otherValue, equals(2));
/// });
/// ```
class AvoidDuplicateTestAssertionsRule extends DartLintRule {
  const AvoidDuplicateTestAssertionsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_duplicate_test_assertions',
    problemMessage: 'Duplicate test assertion detected.',
    correctionMessage: 'Remove the duplicate assertion or verify different values.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addBlock((Block node) {
      final List<String> seenAssertions = <String>[];

      for (final Statement stmt in node.statements) {
        if (stmt is ExpressionStatement) {
          final Expression expr = stmt.expression;
          if (expr is MethodInvocation && expr.methodName.name == 'expect') {
            final String assertionStr = expr.toString();
            if (seenAssertions.contains(assertionStr)) {
              reporter.atNode(expr, code);
            } else {
              seenAssertions.add(assertionStr);
            }
          }
        }
      }
    });
  }
}

/// Warns when a test group() has an empty body.
class AvoidEmptyTestGroupsRule extends DartLintRule {
  const AvoidEmptyTestGroupsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_empty_test_groups',
    problemMessage: 'Test group has an empty body.',
    correctionMessage: 'Add tests to the group or remove it.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    // Only check test files
    if (!resolver.path.endsWith('_test.dart')) return;

    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'group') return;

      final ArgumentList args = node.argumentList;
      if (args.arguments.length < 2) return;

      // Second argument should be the callback function
      final Expression callback = args.arguments[1];
      if (callback is! FunctionExpression) return;

      final FunctionBody body = callback.body;
      if (body is BlockFunctionBody) {
        if (body.block.statements.isEmpty) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when public top-level members are declared in test files.
///
/// Test files should only contain test cases and test setup code.
/// Public top-level functions, classes, or variables can be accidentally
/// imported elsewhere.
///
/// Example of **bad** code:
/// ```dart
/// // In my_test.dart
/// String helperFunction() => 'test';  // Public helper
/// ```
///
/// Example of **good** code:
/// ```dart
/// // In my_test.dart
/// String _helperFunction() => 'test';  // Private helper
/// ```
class AvoidTopLevelMembersInTestsRule extends DartLintRule {
  const AvoidTopLevelMembersInTestsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_top_level_members_in_tests',
    problemMessage: 'Avoid public top-level members in test files.',
    correctionMessage: 'Make the member private by prefixing with underscore, '
        'or move it to a separate utility file.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    // Only run in test files
    final String path = resolver.path;
    if (!path.contains('_test.dart') && !path.contains('/test/')) {
      return;
    }

    context.registry.addCompilationUnit((CompilationUnit unit) {
      for (final CompilationUnitMember declaration in unit.declarations) {
        // Skip main function (test entry point)
        if (declaration is FunctionDeclaration && declaration.name.lexeme == 'main') {
          continue;
        }

        // Check for public declarations
        String? name;
        if (declaration is FunctionDeclaration) {
          name = declaration.name.lexeme;
        } else if (declaration is ClassDeclaration) {
          name = declaration.name.lexeme;
        } else if (declaration is TopLevelVariableDeclaration) {
          for (final VariableDeclaration variable in declaration.variables.variables) {
            final String varName = variable.name.lexeme;
            if (!varName.startsWith('_')) {
              reporter.atNode(variable, code);
            }
          }
          continue;
        } else if (declaration is EnumDeclaration) {
          name = declaration.name.lexeme;
        } else if (declaration is MixinDeclaration) {
          name = declaration.name.lexeme;
        } else if (declaration is ExtensionDeclaration) {
          name = declaration.name?.lexeme;
        } else if (declaration is TypeAlias) {
          name = declaration.name.lexeme;
        }

        if (name != null && !name.startsWith('_')) {
          reporter.atNode(declaration, code);
        }
      }
    });
  }
}

/// Warns when test names don't follow the expected format.
///
/// Test names should be descriptive and follow conventions.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// test('test1', () { });
/// test('Test', () { });
/// ```
///
/// #### GOOD:
/// ```dart
/// test('should return true when input is valid', () { });
/// test('returns empty list for null input', () { });
/// ```
class FormatTestNameRule extends DartLintRule {
  const FormatTestNameRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_descriptive_test_name',
    problemMessage: 'Test name should be descriptive.',
    correctionMessage: 'Use a descriptive test name that explains what is being tested.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _testFunctions = <String>{
    'test',
    'testWidgets',
    'group',
  };

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (!_testFunctions.contains(methodName)) return;

      final ArgumentList args = node.argumentList;
      if (args.arguments.isEmpty) return;

      final Expression firstArg = args.arguments.first;
      if (firstArg is! StringLiteral) return;

      final String? testName = firstArg.stringValue;
      if (testName == null) return;

      // Check for poor test names
      if (_isPoorTestName(testName)) {
        reporter.atNode(firstArg, code);
      }
    });
  }

  bool _isPoorTestName(String name) {
    // Too short
    if (name.length < 5) return true;

    // Just a number or test + number
    if (RegExp(r'^test\d*$', caseSensitive: false).hasMatch(name)) return true;

    // Single word that's not descriptive
    if (!name.contains(' ') && name.length < 15) return true;

    return false;
  }
}

/// Warns when a test file doesn't follow naming conventions.
///
/// Test files should end with `_test.dart` and be located in the `test/`
/// directory.
///
/// Example of **bad** code:
/// ```
/// test/my_tests.dart  // Should be my_test.dart
/// lib/widget_test.dart  // Should be in test/ directory
/// ```
///
/// Example of **good** code:
/// ```
/// test/widget_test.dart
/// test/unit/my_class_test.dart
/// ```
class PreferCorrectTestFileNameRule extends DartLintRule {
  const PreferCorrectTestFileNameRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_correct_test_file_name',
    problemMessage: 'Test file naming convention violation.',
    correctionMessage: 'Test files should end with `_test.dart` and be in test/ directory.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    final String path = resolver.path;

    // Check if file is in test directory but doesn't end with _test.dart
    final bool isInTestDir = path.contains('/test/') || path.contains('\\test\\');
    final bool endsWithTest = path.endsWith('_test.dart');
    final bool isTestHelper = path.contains('test_utils') || path.contains('test_helper');

    if (isInTestDir && !endsWithTest && !isTestHelper) {
      // Only warn if file contains test() or testWidgets() calls
      context.registry.addCompilationUnit((CompilationUnit unit) {
        bool hasTests = false;
        unit.visitChildren(
          _TestCallFinder(() {
            hasTests = true;
          }),
        );

        if (hasTests) {
          // Report at the library/part directive or first declaration
          if (unit.declarations.isNotEmpty) {
            reporter.atNode(unit.declarations.first, code);
          }
        }
      });
    }
  }
}

class _TestCallFinder extends RecursiveAstVisitor<void> {
  _TestCallFinder(this.onFound);
  final void Function() onFound;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final String name = node.methodName.name;
    if (name == 'test' || name == 'testWidgets' || name == 'group') {
      onFound();
    }
    super.visitMethodInvocation(node);
  }
}

/// Warns when expect() is used with a Future instead of expectLater().
class PreferExpectLaterRule extends DartLintRule {
  const PreferExpectLaterRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_expect_later',
    problemMessage: 'Use expectLater() for Future assertions.',
    correctionMessage: 'Replace expect() with expectLater() for Futures.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    // Only check test files
    if (!resolver.path.endsWith('_test.dart')) return;

    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'expect') return;

      final ArgumentList args = node.argumentList;
      if (args.arguments.isEmpty) return;

      final Expression firstArg = args.arguments.first;
      final DartType? type = firstArg.staticType;
      if (type == null) return;

      final String typeName = type.getDisplayString();
      if (typeName.startsWith('Future')) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when test files don't follow proper structure.
class PreferTestStructureRule extends DartLintRule {
  const PreferTestStructureRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_test_structure',
    problemMessage: 'Test file should follow proper structure conventions.',
    correctionMessage: 'Wrap tests in group() and use descriptive names.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    // Only check test files
    if (!resolver.path.endsWith('_test.dart')) return;

    context.registry.addCompilationUnit((CompilationUnit node) {
      bool hasMainFunction = false;

      for (final CompilationUnitMember member in node.declarations) {
        if (member is FunctionDeclaration) {
          if (member.name.lexeme == 'main') {
            hasMainFunction = true;
          }
        }
      }

      if (!hasMainFunction) {
        reporter.atNode(node, code);
        return;
      }

      // Check for test() calls not wrapped in group()
      node.accept(
        _TestStructureVisitor(reporter, code, (_) {}),
      );
    });
  }
}

class _TestStructureVisitor extends RecursiveAstVisitor<void> {
  _TestStructureVisitor(this.reporter, this.code, this.onTopLevelTestFound);

  final ErrorReporter reporter;
  final LintCode code;
  final void Function(bool) onTopLevelTestFound;
  int _groupDepth = 0;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final String name = node.methodName.name;

    if (name == 'group') {
      _groupDepth++;
      super.visitMethodInvocation(node);
      _groupDepth--;
    } else if (name == 'test' || name == 'testWidgets') {
      if (_groupDepth == 0) {
        // Test not wrapped in group - this is acceptable but could warn
        onTopLevelTestFound(true);
      }
      super.visitMethodInvocation(node);
    } else {
      super.visitMethodInvocation(node);
    }
  }
}

/// Warns when test names are duplicated within a test file.
///
/// Each test should have a unique name.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// test('returns true', () { });
/// test('returns true', () { }); // Duplicate!
/// ```
///
/// #### GOOD:
/// ```dart
/// test('returns true for valid input', () { });
/// test('returns true for empty input', () { });
/// ```
class PreferUniqueTestNamesRule extends DartLintRule {
  const PreferUniqueTestNamesRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_unique_test_names',
    problemMessage: 'Duplicate test name found.',
    correctionMessage: 'Use a unique name for each test.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    final Set<String> testNames = <String>{};
    final List<(StringLiteral, String)> duplicates = <(StringLiteral, String)>[];

    context.registry.addCompilationUnit((CompilationUnit unit) {
      testNames.clear();
      duplicates.clear();
    });

    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (methodName != 'test' && methodName != 'testWidgets') return;

      final ArgumentList args = node.argumentList;
      if (args.arguments.isEmpty) return;

      final Expression firstArg = args.arguments.first;
      if (firstArg is! StringLiteral) return;

      final String? testName = firstArg.stringValue;
      if (testName == null) return;

      if (testNames.contains(testName)) {
        reporter.atNode(firstArg, code);
      } else {
        testNames.add(testName);
      }
    });
  }
}

/// Warns when a test body doesn't contain any assertions.
///
/// Example of **bad** code:
/// ```dart
/// test('example', () {
///   final value = getValue();
///   // No assertion!
/// });
/// ```
///
/// Example of **good** code:
/// ```dart
/// test('example', () {
///   final value = getValue();
///   expect(value, equals(42));
/// });
/// ```
class MissingTestAssertionRule extends DartLintRule {
  const MissingTestAssertionRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'missing_test_assertion',
    problemMessage: 'Test body has no assertions.',
    correctionMessage: 'Add expect(), verify(), or other assertion calls.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _assertionMethods = <String>{
    'expect',
    'expectLater',
    'verify',
    'verifyNever',
    'verifyInOrder',
    'verifyNoMoreInteractions',
    'fail',
    'throwsA',
    'throwsAssertionError',
    'throwsArgumentError',
    'throwsException',
    'throwsStateError',
  };

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    // Only check test files
    if (!resolver.path.endsWith('_test.dart')) return;

    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (methodName != 'test' && methodName != 'testWidgets') return;

      final ArgumentList args = node.argumentList;
      if (args.arguments.length < 2) return;

      // Second argument should be the callback function
      final Expression callback = args.arguments[1];
      if (callback is! FunctionExpression) return;

      final FunctionBody body = callback.body;

      // Check if body contains any assertion calls
      final bool hasAssertion = _containsAssertion(body);
      if (!hasAssertion) {
        reporter.atNode(node, code);
      }
    });
  }

  bool _containsAssertion(FunctionBody body) {
    bool found = false;
    body.visitChildren(
      _AssertionFinder((String _) {
        found = true;
      }),
    );
    return found;
  }
}

class _AssertionFinder extends RecursiveAstVisitor<void> {
  _AssertionFinder(this.onFound);

  final void Function(String) onFound;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (MissingTestAssertionRule._assertionMethods.contains(node.methodName.name)) {
      onFound(node.methodName.name);
    }
    super.visitMethodInvocation(node);
  }
}
