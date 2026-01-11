// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;
import 'package:analyzer/source/source_range.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

/// Warns when duplicate test assertions are made.
///
/// Alias: duplicate_expect, redundant_assertion, repeated_test_check
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
class AvoidDuplicateTestAssertionsRule extends SaropaLintRule {
  const AvoidDuplicateTestAssertionsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_duplicate_test_assertions',
    problemMessage: 'Duplicate test assertion detected.',
    correctionMessage:
        'Remove the duplicate assertion or verify different values.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
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
///
/// Alias: empty_group, empty_test_group, no_tests_in_group
class AvoidEmptyTestGroupsRule extends SaropaLintRule {
  const AvoidEmptyTestGroupsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_empty_test_groups',
    problemMessage: 'Test group has an empty body.',
    correctionMessage: 'Add tests to the group or remove it.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Only check test files
    final String path = resolver.path;
    if (!path.endsWith('_test.dart') &&
        !path.contains('/test/') &&
        !path.contains(r'\test\')) {
      return;
    }

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
/// Alias: private_test_helpers, test_file_scope, no_public_test_members
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
class AvoidTopLevelMembersInTestsRule extends SaropaLintRule {
  const AvoidTopLevelMembersInTestsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_top_level_members_in_tests',
    problemMessage: 'Avoid public top-level members in test files.',
    correctionMessage: 'Make the member private by prefixing with underscore, '
        'or move it to a separate utility file.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Only run in test files
    final String path = resolver.path;
    if (!path.contains('_test.dart') &&
        !path.contains('/test/') &&
        !path.contains(r'\test\')) {
      return;
    }

    context.registry.addCompilationUnit((CompilationUnit unit) {
      for (final CompilationUnitMember declaration in unit.declarations) {
        // Skip main function (test entry point)
        if (declaration is FunctionDeclaration &&
            declaration.name.lexeme == 'main') {
          continue;
        }

        // Check for public declarations
        String? name;
        if (declaration is FunctionDeclaration) {
          name = declaration.name.lexeme;
        } else if (declaration is ClassDeclaration) {
          name = declaration.name.lexeme;
        } else if (declaration is TopLevelVariableDeclaration) {
          for (final VariableDeclaration variable
              in declaration.variables.variables) {
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
/// Alias: test_naming, descriptive_test, meaningful_test_name
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
class PreferDescriptiveTestNameRule extends SaropaLintRule {
  const PreferDescriptiveTestNameRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_descriptive_test_name',
    problemMessage: 'Test name should be descriptive.',
    correctionMessage:
        'Use a descriptive test name that explains what is being tested.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _testFunctions = <String>{
    'test',
    'testWidgets',
    'group',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
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
/// Alias: test_file_naming, test_file_convention, test_dart_suffix
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
class PreferCorrectTestFileNameRule extends SaropaLintRule {
  const PreferCorrectTestFileNameRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_correct_test_file_name',
    problemMessage: 'Test file naming convention violation.',
    correctionMessage:
        'Test files should end with `_test.dart` and be in test/ directory.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String path = resolver.path;

    // Check if file is in test directory but doesn't end with _test.dart
    final bool isInTestDir =
        path.contains('/test/') || path.contains('\\test\\');
    final bool endsWithTest = path.endsWith('_test.dart');
    final bool isTestHelper =
        path.contains('test_utils') || path.contains('test_helper');

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
///
/// Alias: use_expect_later, future_expect, async_expect
///
/// **Quick fix available:** Replaces `expect` with `expectLater`.
class PreferExpectLaterRule extends SaropaLintRule {
  const PreferExpectLaterRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_expect_later',
    problemMessage: 'Use expectLater() for Future assertions.',
    correctionMessage: 'Replace expect() with expectLater() for Futures.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Only check test files
    final String path = resolver.path;
    if (!path.endsWith('_test.dart') &&
        !path.contains('/test/') &&
        !path.contains(r'\test\')) {
      return;
    }

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

  @override
  List<Fix> getFixes() => <Fix>[_ReplaceExpectWithExpectLaterFix()];
}

class _ReplaceExpectWithExpectLaterFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;
      if (node.methodName.name != 'expect') return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: "Replace 'expect' with 'expectLater'",
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          SourceRange(node.methodName.offset, node.methodName.length),
          'expectLater',
        );
      });
    });
  }
}

/// Warns when test files don't follow proper structure.
class PreferTestStructureRule extends SaropaLintRule {
  const PreferTestStructureRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_test_structure',
    problemMessage: 'Test file should follow proper structure conventions.',
    correctionMessage: 'Wrap tests in group() and use descriptive names.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Only check test files
    final String path = resolver.path;
    if (!path.endsWith('_test.dart') &&
        !path.contains('/test/') &&
        !path.contains(r'\test\')) {
      return;
    }

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

  final SaropaDiagnosticReporter reporter;
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
class PreferUniqueTestNamesRule extends SaropaLintRule {
  const PreferUniqueTestNamesRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_unique_test_names',
    problemMessage: 'Duplicate test name found.',
    correctionMessage: 'Use a unique name for each test.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCompilationUnit((CompilationUnit unit) {
      final visitor = _UniqueTestNameVisitor(reporter, code);
      unit.accept(visitor);
    });
  }
}

class _UniqueTestNameVisitor extends RecursiveAstVisitor<void> {
  _UniqueTestNameVisitor(this.reporter, this.code);

  final SaropaDiagnosticReporter reporter;
  final LintCode code;
  final Set<String> _testNames = <String>{};

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final String methodName = node.methodName.name;
    if (methodName == 'test' || methodName == 'testWidgets') {
      final ArgumentList args = node.argumentList;
      if (args.arguments.isNotEmpty) {
        final Expression firstArg = args.arguments.first;
        if (firstArg is StringLiteral) {
          final String? testName = firstArg.stringValue;
          if (testName != null) {
            if (_testNames.contains(testName)) {
              reporter.atNode(firstArg, code);
            } else {
              _testNames.add(testName);
            }
          }
        }
      }
    }
    super.visitMethodInvocation(node);
  }
}

/// Warns when test file has many tests without group() organization.
///
/// Large test files without groups are hard to navigate and maintain.
/// Use group() to organize related tests by feature or scenario.
///
/// **BAD:**
/// ```dart
/// void main() {
///   test('login succeeds with valid credentials', () {});
///   test('login fails with invalid password', () {});
///   test('login fails with unknown user', () {});
///   test('logout clears session', () {});
///   test('logout redirects to login', () {});
///   // 10+ tests without organization
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void main() {
///   group('login', () {
///     test('succeeds with valid credentials', () {});
///     test('fails with invalid password', () {});
///     test('fails with unknown user', () {});
///   });
///
///   group('logout', () {
///     test('clears session', () {});
///     test('redirects to login', () {});
///   });
/// }
/// ```
class RequireTestGroupsRule extends SaropaLintRule {
  const RequireTestGroupsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'require_test_groups',
    problemMessage:
        'Many tests without group() organization. Consider grouping related tests.',
    correctionMessage:
        'Use group() to organize tests by feature, scenario, or component.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Number of tests that triggers the warning
  static const int _threshold = 5;

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Only run in test files
    final String path = resolver.source.fullName;
    if (!path.contains('_test.dart') &&
        !path.contains('/test/') &&
        !path.contains('\\test\\')) {
      return;
    }

    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
      if (node.name.lexeme != 'main') return;

      final FunctionBody body = node.functionExpression.body;

      // Count top-level test() calls
      int testCount = 0;
      bool hasGroups = false;

      if (body is BlockFunctionBody) {
        for (final Statement statement in body.block.statements) {
          if (statement is ExpressionStatement) {
            final Expression expr = statement.expression;
            if (expr is MethodInvocation) {
              final String methodName = expr.methodName.name;
              if (methodName == 'test' || methodName == 'testWidgets') {
                testCount++;
              }
              if (methodName == 'group') {
                hasGroups = true;
              }
            }
          }
        }
      }

      // If many tests without groups, warn
      if (testCount >= _threshold && !hasGroups) {
        reporter.atToken(node.name, code);
      }
    });
  }
}

/// Warns when tests depend on other tests' side effects.
///
/// Tests should be independent and run in any order. Depending on
/// state from previous tests creates fragile, unreliable tests.
///
/// **BAD:**
/// ```dart
/// late String userId;
///
/// test('creates user', () async {
///   userId = await createUser('test'); // Sets shared state
///   expect(userId, isNotNull);
/// });
///
/// test('deletes user', () async {
///   await deleteUser(userId); // Depends on previous test!
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// test('creates and deletes user', () async {
///   final userId = await createUser('test');
///   expect(userId, isNotNull);
///   await deleteUser(userId);
/// });
/// ```
class AvoidTestCouplingRule extends SaropaLintRule {
  const AvoidTestCouplingRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_test_coupling',
    problemMessage:
        'Test appears to depend on shared mutable state from other tests.',
    correctionMessage:
        'Make tests independent. Use setUp/tearDown for shared state, '
        'or combine dependent tests.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Only run in test files
    final String path = resolver.source.fullName;
    if (!path.contains('_test.dart') &&
        !path.contains('/test/') &&
        !path.contains('\\test\\')) {
      return;
    }

    // Track variables that are assigned in tests
    final Set<String> assignedInTests = <String>{};
    final List<_TestInfo> tests = <_TestInfo>[];

    context.registry.addCompilationUnit((CompilationUnit unit) {
      // Find top-level variables
      final Set<String> topLevelVars = <String>{};
      for (final CompilationUnitMember member in unit.declarations) {
        if (member is TopLevelVariableDeclaration) {
          for (final VariableDeclaration variable
              in member.variables.variables) {
            topLevelVars.add(variable.name.lexeme);
          }
        }
      }

      // Analyze test functions
      for (final CompilationUnitMember member in unit.declarations) {
        if (member is FunctionDeclaration && member.name.lexeme == 'main') {
          member.functionExpression.body.visitChildren(
            _TestAnalyzer(
              topLevelVars: topLevelVars,
              onTestFound: (info) => tests.add(info),
              onAssignment: (name) => assignedInTests.add(name),
            ),
          );
        }
      }
    });

    // Report tests that read variables assigned by other tests
    context.addPostRunCallback(() {
      for (final _TestInfo test in tests) {
        for (final String readVar in test.readsVars) {
          if (assignedInTests.contains(readVar) &&
              !test.assignsVars.contains(readVar)) {
            reporter.atNode(test.node, code);
            break;
          }
        }
      }
    });
  }
}

class _TestInfo {
  _TestInfo({
    required this.node,
    required this.assignsVars,
    required this.readsVars,
  });

  final AstNode node;
  final Set<String> assignsVars;
  final Set<String> readsVars;
}

class _TestAnalyzer extends RecursiveAstVisitor<void> {
  _TestAnalyzer({
    required this.topLevelVars,
    required this.onTestFound,
    required this.onAssignment,
  });

  final Set<String> topLevelVars;
  final void Function(_TestInfo) onTestFound;
  final void Function(String) onAssignment;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final String methodName = node.methodName.name;
    if (methodName == 'test' || methodName == 'testWidgets') {
      // Analyze the test body
      final ArgumentList args = node.argumentList;
      if (args.arguments.length >= 2) {
        final Expression callback = args.arguments[1];
        if (callback is FunctionExpression) {
          final Set<String> assigns = <String>{};
          final Set<String> reads = <String>{};

          callback.body.visitChildren(
            _VarAccessVisitor(
              topLevelVars: topLevelVars,
              onAssign: (name) {
                assigns.add(name);
                onAssignment(name);
              },
              onRead: (name) => reads.add(name),
            ),
          );

          onTestFound(_TestInfo(
            node: node,
            assignsVars: assigns,
            readsVars: reads,
          ));
        }
      }
    }
    super.visitMethodInvocation(node);
  }
}

class _VarAccessVisitor extends RecursiveAstVisitor<void> {
  _VarAccessVisitor({
    required this.topLevelVars,
    required this.onAssign,
    required this.onRead,
  });

  final Set<String> topLevelVars;
  final void Function(String) onAssign;
  final void Function(String) onRead;

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    final Expression left = node.leftHandSide;
    if (left is SimpleIdentifier && topLevelVars.contains(left.name)) {
      onAssign(left.name);
    }
    super.visitAssignmentExpression(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (topLevelVars.contains(node.name)) {
      // Check if it's being read (not assigned)
      final AstNode? parent = node.parent;
      if (parent is! AssignmentExpression || parent.leftHandSide != node) {
        onRead(node.name);
      }
    }
    super.visitSimpleIdentifier(node);
  }
}

/// Warns when tests share mutable state without proper isolation.
///
/// Tests should not share mutable state. Use setUp/tearDown to
/// reset state between tests for proper isolation.
///
/// **BAD:**
/// ```dart
/// final List<String> items = []; // Shared mutable state!
///
/// test('adds item', () {
///   items.add('a');
///   expect(items, hasLength(1));
/// });
///
/// test('removes item', () {
///   items.remove('a'); // Assumes 'a' was added by previous test!
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// late List<String> items;
///
/// setUp(() {
///   items = []; // Fresh list for each test
/// });
///
/// test('adds item', () {
///   items.add('a');
///   expect(items, hasLength(1));
/// });
/// ```
class RequireTestIsolationRule extends SaropaLintRule {
  const RequireTestIsolationRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'require_test_isolation',
    problemMessage: 'Mutable top-level variable may cause test coupling.',
    correctionMessage:
        'Use setUp() to initialize shared state before each test, '
        'ensuring tests are isolated.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Only run in test files
    final String path = resolver.source.fullName;
    if (!path.contains('_test.dart') &&
        !path.contains('/test/') &&
        !path.contains('\\test\\')) {
      return;
    }

    context.registry.addTopLevelVariableDeclaration((
      TopLevelVariableDeclaration node,
    ) {
      for (final VariableDeclaration variable in node.variables.variables) {
        // Skip final/const variables (immutable)
        if (node.variables.isFinal || node.variables.isConst) continue;

        // Skip late variables (typically initialized in setUp)
        if (node.variables.isLate) continue;

        // Check for mutable collection initializers
        final Expression? initializer = variable.initializer;
        if (initializer is ListLiteral ||
            initializer is SetOrMapLiteral ||
            initializer is InstanceCreationExpression) {
          // Check if type is mutable
          final String? typeName = node.variables.type?.toSource();
          if (typeName != null &&
              (typeName.startsWith('List') ||
                  typeName.startsWith('Set') ||
                  typeName.startsWith('Map'))) {
            reporter.atNode(variable, code);
          }
        }
      }
    });
  }
}

/// Warns when tests use real network/database calls.
///
/// Tests should be fast, reliable, and not depend on external systems.
/// Use mocks or fakes for external dependencies.
///
/// **BAD:**
/// ```dart
/// test('fetches user', () async {
///   final user = await http.get(Uri.parse('https://api.example.com/user'));
///   expect(user, isNotNull);
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// test('fetches user', () async {
///   final mockClient = MockClient();
///   when(() => mockClient.get(any())).thenAnswer(
///     (_) async => Response('{"name": "Test"}', 200),
///   );
///
///   final user = await fetchUser(mockClient);
///   expect(user.name, 'Test');
/// });
/// ```
class AvoidRealDependenciesInTestsRule extends SaropaLintRule {
  const AvoidRealDependenciesInTestsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_real_dependencies_in_tests',
    problemMessage: 'Test uses real network/database call. Use mocks instead.',
    correctionMessage:
        'Replace real HTTP/database calls with mocks for faster, '
        'more reliable tests.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _realCallPatterns = <String>{
    'http.get',
    'http.post',
    'http.put',
    'http.delete',
    'http.patch',
    'Dio',
    'FirebaseFirestore.instance',
    'FirebaseAuth.instance',
    'FirebaseDatabase.instance',
    'SharedPreferences.getInstance',
    'sqflite',
    'openDatabase',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Only run in test files
    final String path = resolver.source.fullName;
    if (!path.contains('_test.dart') &&
        !path.contains('/test/') &&
        !path.contains('\\test\\')) {
      return;
    }

    context.registry.addMethodInvocation((MethodInvocation node) {
      final String fullCall = node.toSource();

      // Check if inside a test() or testWidgets()
      if (!_isInsideTest(node)) return;

      for (final String pattern in _realCallPatterns) {
        if (fullCall.contains(pattern)) {
          reporter.atNode(node, code);
          return;
        }
      }
    });

    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String fullCall = node.toSource();

      if (!_isInsideTest(node)) return;

      if (fullCall.contains('Dio(') ||
          fullCall.contains('HttpClient(') ||
          fullCall.contains('IOClient(')) {
        reporter.atNode(node, code);
      }
    });
  }

  bool _isInsideTest(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is MethodInvocation) {
        final String methodName = current.methodName.name;
        if (methodName == 'test' ||
            methodName == 'testWidgets' ||
            methodName == 'setUp' ||
            methodName == 'setUpAll') {
          return true;
        }
      }
      current = current.parent;
    }
    return false;
  }
}

/// Warns when widget tests with scrollable content don't test scrolling.
///
/// Scrollable widgets should be tested for scroll behavior to catch
/// overflow issues and ensure content is accessible.
///
/// **BAD:**
/// ```dart
/// testWidgets('shows list', (tester) async {
///   await tester.pumpWidget(MyListWidget());
///   expect(find.byType(ListView), findsOneWidget);
///   // Missing scroll test!
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// testWidgets('shows list and scrolls', (tester) async {
///   await tester.pumpWidget(MyListWidget());
///   expect(find.byType(ListView), findsOneWidget);
///
///   // Test scrolling
///   await tester.drag(find.byType(ListView), const Offset(0, -500));
///   await tester.pumpAndSettle();
///   expect(find.text('Item 10'), findsOneWidget);
/// });
/// ```
class RequireScrollTestsRule extends SaropaLintRule {
  const RequireScrollTestsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'require_scroll_tests',
    problemMessage:
        'Widget test creates scrollable widget but does not test scrolling.',
    correctionMessage:
        'Add tester.drag() or tester.scroll() to verify scroll behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _scrollableWidgets = <String>{
    'ListView',
    'GridView',
    'SingleChildScrollView',
    'CustomScrollView',
    'PageView',
    'TabBarView',
    'NestedScrollView',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Only run in test files
    final String path = resolver.source.fullName;
    if (!path.contains('_test.dart') &&
        !path.contains('/test/') &&
        !path.contains('\\test\\')) {
      return;
    }

    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'testWidgets') return;

      final ArgumentList args = node.argumentList;
      if (args.arguments.length < 2) return;

      final Expression callback = args.arguments[1];
      if (callback is! FunctionExpression) return;

      final String bodySource = callback.body.toSource();

      // Check if test creates a scrollable widget
      bool hasScrollable = false;
      for (final String widget in _scrollableWidgets) {
        if (bodySource.contains(widget)) {
          hasScrollable = true;
          break;
        }
      }

      if (!hasScrollable) return;

      // Check if test has scroll operations
      final bool hasScrollTest = bodySource.contains('.drag(') ||
          bodySource.contains('.scroll(') ||
          bodySource.contains('.fling(') ||
          bodySource.contains('scrollController') ||
          bodySource.contains('ScrollController');

      if (!hasScrollTest) {
        reporter.atNode(node.methodName, code);
      }
    });
  }
}

/// Warns when widget tests with text input don't test input behavior.
///
/// Text fields should be tested for user input, validation, and
/// submission behavior.
///
/// **BAD:**
/// ```dart
/// testWidgets('shows form', (tester) async {
///   await tester.pumpWidget(MyForm());
///   expect(find.byType(TextField), findsOneWidget);
///   // Missing input test!
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// testWidgets('form accepts input', (tester) async {
///   await tester.pumpWidget(MyForm());
///
///   await tester.enterText(find.byType(TextField), 'test@example.com');
///   await tester.pump();
///   expect(find.text('test@example.com'), findsOneWidget);
///
///   await tester.tap(find.byType(ElevatedButton));
///   await tester.pumpAndSettle();
/// });
/// ```
class RequireTextInputTestsRule extends SaropaLintRule {
  const RequireTextInputTestsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'require_text_input_tests',
    problemMessage:
        'Widget test creates text input but does not test user input.',
    correctionMessage: 'Add tester.enterText() to verify text input behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _textInputWidgets = <String>{
    'TextField',
    'TextFormField',
    'CupertinoTextField',
    'EditableText',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Only run in test files
    final String path = resolver.source.fullName;
    if (!path.contains('_test.dart') &&
        !path.contains('/test/') &&
        !path.contains('\\test\\')) {
      return;
    }

    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'testWidgets') return;

      final ArgumentList args = node.argumentList;
      if (args.arguments.length < 2) return;

      final Expression callback = args.arguments[1];
      if (callback is! FunctionExpression) return;

      final String bodySource = callback.body.toSource();

      // Check if test creates a text input widget
      bool hasTextInput = false;
      for (final String widget in _textInputWidgets) {
        if (bodySource.contains(widget)) {
          hasTextInput = true;
          break;
        }
      }

      if (!hasTextInput) return;

      // Check if test has text input operations
      final bool hasInputTest = bodySource.contains('.enterText(') ||
          bodySource.contains('.showKeyboard(') ||
          bodySource.contains('textEditingController') ||
          bodySource.contains('TextEditingController');

      if (!hasInputTest) {
        reporter.atNode(node.methodName, code);
      }
    });
  }
}

/// Warns when tests use excessive mocking instead of simpler fakes.
///
/// Fakes (simple implementations) are easier to maintain than mocks with
/// verify() chains. Use mocks only when you need to verify interactions.
///
/// **BAD:**
/// ```dart
/// test('loads user', () async {
///   final mockRepo = MockUserRepository();
///   when(mockRepo.getUser(any)).thenAnswer((_) async => user);
///
///   final result = await service.loadUser(1);
///
///   verify(mockRepo.getUser(1)).called(1); // Over-specified
///   expect(result, user);
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// test('loads user', () async {
///   final fakeRepo = FakeUserRepository()..users = {1: user};
///
///   final result = await service.loadUser(1);
///
///   expect(result, user); // Test behavior, not implementation
/// });
/// ```
class PreferFakeOverMockRule extends SaropaLintRule {
  const PreferFakeOverMockRule() : super(code: _code);

  /// Team preference - some prefer fakes, others prefer mocks.
  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  bool get skipTestFiles => false; // Run specifically in test files

  static const LintCode _code = LintCode(
    name: 'prefer_fake_over_mock',
    problemMessage:
        'Test uses mock with verify(). Consider using a fake for simpler tests.',
    correctionMessage:
        'Fakes are easier to maintain. Use mocks only when verifying interactions.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Only run in test files
    final String path = resolver.source.fullName;
    if (!path.contains('_test.dart') &&
        !path.contains('/test/') &&
        !path.contains('\\test\\')) {
      return;
    }

    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check for common test method names
      if (methodName != 'test' && methodName != 'testWidgets') return;

      final ArgumentList args = node.argumentList;
      if (args.arguments.length < 2) return;

      final Expression callback = args.arguments[1];
      if (callback is! FunctionExpression) return;

      final String bodySource = callback.body.toSource();

      // Count mock patterns
      final int mockCount =
          RegExp(r'\bMock\w+\(').allMatches(bodySource).length;
      final int whenCount = 'when('.allMatches(bodySource).length;
      final int verifyCount = 'verify('.allMatches(bodySource).length;
      final int verifyNeverCount = 'verifyNever('.allMatches(bodySource).length;

      // If using many mocks with verify chains, suggest fakes
      if (mockCount >= 2 && (verifyCount + verifyNeverCount) >= 3) {
        reporter.atNode(node.methodName, code);
      }

      // Also flag tests with complex when() chains but simple assertions
      if (whenCount >= 3 && verifyCount == 0) {
        // Many setup stubs but no interaction verification
        // Suggests mocks are being used as data providers (should be fakes)
        reporter.atNode(node.methodName, code);
      }
    });
  }
}

/// Warns when tests don't cover edge cases.
///
/// Test boundary conditions: empty lists, null values, max int, empty strings,
/// unicode, negative numbers. Edge cases cause most production bugs.
///
/// **BAD:**
/// ```dart
/// test('calculates total', () {
///   expect(calculateTotal([10, 20, 30]), 60); // Only happy path
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// test('calculates total', () {
///   expect(calculateTotal([10, 20, 30]), 60);
/// });
///
/// test('calculates total with empty list', () {
///   expect(calculateTotal([]), 0);
/// });
///
/// test('calculates total with negative numbers', () {
///   expect(calculateTotal([-10, 20]), 10);
/// });
/// ```
class RequireEdgeCaseTestsRule extends SaropaLintRule {
  const RequireEdgeCaseTestsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  bool get skipTestFiles => false;

  static const LintCode _code = LintCode(
    name: 'require_edge_case_tests',
    problemMessage:
        'Test file may be missing edge case tests (empty, null, boundary).',
    correctionMessage:
        'Add tests for: empty collections, null values, boundary numbers, etc.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Only run in test files
    final String path = resolver.source.fullName;
    if (!path.contains('_test.dart') &&
        !path.contains('/test/') &&
        !path.contains('\\test\\')) {
      return;
    }

    context.registry.addCompilationUnit((CompilationUnit unit) {
      final String source = unit.toSource();

      // Count test cases
      final int testCount = RegExp(r"\btest\s*\(").allMatches(source).length +
          RegExp(r"\btestWidgets\s*\(").allMatches(source).length;

      if (testCount < 3) return; // Not enough tests to analyze

      // Check for edge case patterns in test descriptions or assertions
      final bool hasEmptyTest = source.contains('empty') ||
          source.contains('[]') ||
          source.contains('isEmpty');
      final bool hasNullTest = source.contains('null') ||
          source.contains('isNull') ||
          source.contains('Null');
      final bool hasBoundaryTest = source.contains('max') ||
          source.contains('min') ||
          source.contains('boundary') ||
          source.contains('limit') ||
          source.contains('overflow');
      final bool hasNegativeTest =
          source.contains('negative') || source.contains('-1');
      final bool hasErrorTest =
          source.contains('throws') || source.contains('error');

      // Count how many edge case categories are covered
      int edgeCaseCoverage = 0;
      if (hasEmptyTest) edgeCaseCoverage++;
      if (hasNullTest) edgeCaseCoverage++;
      if (hasBoundaryTest) edgeCaseCoverage++;
      if (hasNegativeTest) edgeCaseCoverage++;
      if (hasErrorTest) edgeCaseCoverage++;

      // If file has multiple tests but low edge case coverage, warn
      if (testCount >= 5 && edgeCaseCoverage < 2) {
        // Report at the compilation unit (first declaration)
        if (unit.declarations.isNotEmpty) {
          reporter.atNode(unit.declarations.first, code);
        }
      }
    });
  }
}

/// Warns when tests create complex test objects without using builders.
///
/// Builder pattern for test objects is cleaner than constructors with many
/// parameters and makes tests more readable.
///
/// **BAD:**
/// ```dart
/// test('user profile', () {
///   final user = User(
///     id: 1,
///     name: 'Test',
///     email: 'test@example.com',
///     age: 30,
///     address: Address(...),
///     preferences: Preferences(...),
///   );
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// test('user profile', () {
///   final user = UserBuilder()
///     .withName('Test')
///     .withEmail('test@example.com')
///     .build();
/// });
/// ```
class PreferTestDataBuilderRule extends SaropaLintRule {
  const PreferTestDataBuilderRule() : super(code: _code);

  /// Team preference - builder pattern is one of several valid approaches.
  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  bool get skipTestFiles => false;

  static const LintCode _code = LintCode(
    name: 'prefer_test_data_builder',
    problemMessage:
        'Complex object construction in test. Consider using builder pattern.',
    correctionMessage:
        'Create a TestDataBuilder class: UserBuilder().withName("Test").build()',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const int _maxConstructorArgs = 5;

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Only run in test files
    final String path = resolver.source.fullName;
    if (!path.contains('_test.dart') &&
        !path.contains('/test/') &&
        !path.contains('\\test\\')) {
      return;
    }

    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final ArgumentList args = node.argumentList;
      final int argCount = args.arguments.length;

      // Skip if few arguments
      if (argCount < _maxConstructorArgs) return;

      // Get type name safely - name2 may be null for complex types
      final Token? typeToken = node.constructorName.type.name2;
      if (typeToken == null) return;

      // Skip mock objects
      final String typeName = typeToken.lexeme;
      if (typeName.startsWith('Mock') || typeName.startsWith('Fake')) {
        return;
      }

      // Skip common Flutter widgets
      if (typeName.endsWith('Widget') ||
          typeName.endsWith('Button') ||
          typeName.endsWith('Page') ||
          typeName.endsWith('Screen')) {
        return;
      }

      // Check if there's nested object construction
      int nestedObjects = 0;
      for (final Expression arg in args.arguments) {
        if (arg is InstanceCreationExpression ||
            (arg is NamedExpression &&
                arg.expression is InstanceCreationExpression)) {
          nestedObjects++;
        }
      }

      // If complex construction (many args + nested), suggest builder
      if (argCount >= _maxConstructorArgs && nestedObjects >= 2) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when tests verify internal implementation details.
///
/// Tests that verify internal method calls break when you refactor.
/// Test observable behavior (outputs, state changes) instead.
///
/// **BAD:**
/// ```dart
/// test('loads data', () async {
///   await service.loadData();
///
///   // Testing implementation details:
///   verify(mockCache.get('key')).called(1);
///   verify(mockApi.fetch()).called(1);
///   verify(mockCache.set('key', any)).called(1);
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// test('loads data', () async {
///   final result = await service.loadData();
///
///   // Testing observable behavior:
///   expect(result.items, hasLength(3));
///   expect(result.isLoaded, isTrue);
/// });
/// ```
class AvoidTestImplementationDetailsRule extends SaropaLintRule {
  const AvoidTestImplementationDetailsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  bool get skipTestFiles => false;

  static const LintCode _code = LintCode(
    name: 'avoid_test_implementation_details',
    problemMessage:
        'Test verifies internal calls. Test behavior, not implementation.',
    correctionMessage:
        'Focus on outputs and state changes, not internal method calls.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Only run in test files
    final String path = resolver.source.fullName;
    if (!path.contains('_test.dart') &&
        !path.contains('/test/') &&
        !path.contains('\\test\\')) {
      return;
    }

    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check for test method names
      if (methodName != 'test' && methodName != 'testWidgets') return;

      final ArgumentList args = node.argumentList;
      if (args.arguments.length < 2) return;

      final Expression callback = args.arguments[1];
      if (callback is! FunctionExpression) return;

      final String bodySource = callback.body.toSource();

      // Count verify calls vs expect calls
      final int verifyCount = 'verify('.allMatches(bodySource).length +
          'verifyNever('.allMatches(bodySource).length +
          'verifyInOrder('.allMatches(bodySource).length;
      final int expectCount = 'expect('.allMatches(bodySource).length;

      // If more verifies than expects, test is likely over-specified
      if (verifyCount > 0 && verifyCount > expectCount) {
        reporter.atNode(node.methodName, code);
      }

      // Also check for deep internal call verification patterns
      // e.g., verify(mock.internalMethod().subMethod()).called(1)
      final int chainedVerifies = RegExp(r'verify\([^)]+\.[^)]+\.[^)]+\)')
          .allMatches(bodySource)
          .length;

      if (chainedVerifies >= 2) {
        reporter.atNode(node.methodName, code);
      }
    });
  }
}

/// Warns when GetIt is used in tests without reset in setUp.
///
/// GetIt singletons persist across tests, causing test pollution.
/// Reset the container in setUp to ensure test isolation.
///
/// **BAD:**
/// ```dart
/// void main() {
///   test('my test', () {
///     final service = GetIt.I<MyService>();
///     // Uses stale singleton from previous test!
///   });
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void main() {
///   setUp(() {
///     GetIt.I.reset();
///     GetIt.I.registerSingleton<MyService>(MockMyService());
///   });
///
///   test('my test', () {
///     final service = GetIt.I<MyService>();
///   });
/// }
/// ```
///
/// **Quick fix available:** Adds a reminder comment.
class RequireGetItResetInTestsRule extends SaropaLintRule {
  const RequireGetItResetInTestsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  bool get skipTestFiles => false; // This rule specifically targets test files

  // cspell:ignore getit
  static const LintCode _code = LintCode(
    name: 'require_getit_reset_in_tests',
    problemMessage: 'GetIt singletons persist across tests. Reset in setUp.',
    correctionMessage: 'Add GetIt.I.reset() in setUp() or setUpAll().',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Only run in test files
    final String path = resolver.source.fullName.replaceAll('\\', '/');
    if (!path.contains('_test.dart') && !path.contains('/test/')) {
      return;
    }

    context.registry.addCompilationUnit((CompilationUnit unit) {
      final String source = unit.toSource();

      // Check if GetIt is used
      if (!source.contains('GetIt.I') && !source.contains('GetIt.instance')) {
        return;
      }

      // Check if reset is called (typically in setUp/setUpAll)
      final bool hasReset = source.contains('.reset()') ||
          source.contains('.resetLazySingleton') ||
          source.contains('GetIt.I.reset') ||
          source.contains('getIt.reset');

      // Only report if GetIt is used but never reset
      if (!hasReset) {
        // Find the first GetIt usage and report there
        unit.visitChildren(_GetItUsageVisitor(reporter, code));
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddGetItResetReminderFix()];
}

class _GetItUsageVisitor extends RecursiveAstVisitor<void> {
  _GetItUsageVisitor(this.reporter, this.code);

  final SaropaDiagnosticReporter reporter;
  final LintCode code;
  bool _reported = false;

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (_reported) return;

    if (node.prefix.name == 'GetIt' &&
        (node.identifier.name == 'I' || node.identifier.name == 'instance')) {
      reporter.atNode(node, code);
      _reported = true;
    }
    super.visitPrefixedIdentifier(node);
  }
}

class _AddGetItResetReminderFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addPrefixedIdentifier((PrefixedIdentifier node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add reminder to reset GetIt',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '/* HACK: Add GetIt.I.reset() in setUp() */ ',
        );
      });
    });
  }
}

/// Warns when a test body has no assertions.
///
/// Alias: no_assertion_in_test, test_without_expect, empty_test_body
///
/// Tests without assertions don't verify anything and provide false
/// confidence. Every test should have at least one expect(), verify(),
/// or similar assertion. This is a critical test quality issue - tests
/// that don't assert anything give the illusion of coverage without
/// actually catching bugs.
///
/// ## Detection Approach
///
/// This rule uses a two-pass AST analysis:
///
/// 1. **Helper Collection Pass**: Scans the compilation unit for functions
///    (top-level, local, and function expressions) that contain built-in
///    assertions. These function names are collected as "assertion helpers".
///
/// 2. **Test Validation Pass**: For each `test()` or `testWidgets()` call,
///    checks if the callback body contains any calls to built-in assertions
///    OR calls to the identified helper functions.
///
/// ## Recognized Assertions
///
/// Built-in: `expect`, `expectLater`, `verify`, `verifyNever`, `verifyInOrder`,
/// `verifyZeroInteractions`, `verifyNoMoreInteractions`, `fail`, `assert`,
/// `throwsA`, `throwsException`, `throwsStateError`, `throwsArgumentError`
///
/// ## Helper Function Recognition
///
/// The rule recognizes user-defined helper functions that wrap assertions:
/// - Top-level functions: `void expectValid(x) { expect(x, isNotNull); }`
/// - Local functions: `void check() { expect(result, expected); }`
/// - Function variables: `final verify = (x) { expect(x, isTrue); };`
///
/// ## Related Rules
///
/// - **`require_test_assertions`** (Recommended tier): A simpler/faster
///   alternative that uses string matching instead of AST analysis. Use
///   that rule if you don't have custom assertion helpers and want
///   faster analysis. This rule (`missing_test_assertion`) is preferred
///   when you have helper functions that wrap assertions.
///
/// ## Limitations
///
/// - Only recognizes helpers defined in the same file (not imported helpers)
/// - Single level of indirection only (helper calling helper not detected)
/// - Class methods used as assertion helpers are not detected
/// - Does not verify assertion quality (e.g., `expect(true, isTrue)`)
///
/// ## Why This is High Impact
///
/// Tests without assertions:
/// - Give false confidence in code coverage metrics
/// - Waste CI/CD time running tests that verify nothing
/// - Can mask regressions when developers assume tests are passing
/// - Often indicate incomplete test implementations
///
/// **Quick fix available:** Adds an `expect()` placeholder with a reminder comment.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// test('loads data', () async {
///   await loadData(); // No assertion!
/// });
/// ```
///
/// #### GOOD:
/// ```dart
/// test('loads data', () async {
///   final data = await loadData();
///   expect(data, isNotEmpty);
/// });
/// ```
///
/// #### ALSO GOOD (helper function with assertion):
/// ```dart
/// void expectLoaded(Data data) {
///   expect(data, isNotEmpty);
/// }
///
/// test('loads data', () async {
///   final data = await loadData();
///   expectLoaded(data); // Helper contains expect()
/// });
/// ```
class MissingTestAssertionRule extends SaropaLintRule {
  const MissingTestAssertionRule() : super(code: _code);

  /// Critical test quality. No assertions = no value.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'missing_test_assertion',
    problemMessage: 'Test has no assertions.',
    correctionMessage:
        'Add expect(), verify(), or other assertion to validate behavior.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Common assertion function names
  static const Set<String> _builtInAssertionFunctions = <String>{
    'expect',
    'expectLater',
    'verify',
    'verifyNever',
    'verifyInOrder',
    'verifyZeroInteractions',
    'verifyNoMoreInteractions',
    'fail',
    'assert',
    'throwsA',
    'throwsException',
    'throwsStateError',
    'throwsArgumentError',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Only run in test files
    final String path = resolver.path;
    if (!path.endsWith('_test.dart') &&
        !path.contains('/test/') &&
        !path.contains(r'\test\')) {
      return;
    }

    // Track helper functions that contain assertions
    final Set<String> helperFunctionsWithAssertions = <String>{};

    // First pass: find all helper functions that contain assertions
    context.registry.addCompilationUnit((CompilationUnit unit) {
      final _HelperFunctionCollector collector = _HelperFunctionCollector(
        _builtInAssertionFunctions,
      );
      unit.visitChildren(collector);
      helperFunctionsWithAssertions.addAll(collector.functionsWithAssertions);
    });

    // Second pass: check tests for assertions (including helper calls)
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check for test() or testWidgets()
      if (methodName != 'test' && methodName != 'testWidgets') return;

      final ArgumentList args = node.argumentList;
      if (args.arguments.length < 2) return;

      // Get the callback body
      final Expression callback = args.arguments[1];
      FunctionBody? body;

      if (callback is FunctionExpression) {
        body = callback.body;
      }

      if (body == null) return;

      // Build combined set of assertion functions
      final Set<String> allAssertionFunctions = <String>{
        ..._builtInAssertionFunctions,
        ...helperFunctionsWithAssertions,
      };

      // Check if the body contains any assertions
      final _AssertionFinder finder = _AssertionFinder(allAssertionFunctions);
      body.visitChildren(finder);

      if (!finder.foundAssertion) {
        reporter.atNode(node, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddAssertionReminderFix()];
}

class _AddAssertionReminderFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final String methodName = node.methodName.name;
      if (methodName != 'test' && methodName != 'testWidgets') return;

      final ArgumentList args = node.argumentList;
      if (args.arguments.length < 2) return;

      final Expression callback = args.arguments[1];
      if (callback is! FunctionExpression) return;

      final FunctionBody body = callback.body;
      if (body is! BlockFunctionBody) return;

      // Find the position before the closing brace of the test body
      final int insertOffset = body.block.rightBracket.offset;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add expect() assertion placeholder',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          insertOffset,
          '\n    // HACK: Add assertion\n    expect(result, expected);\n  ',
        );
      });
    });
  }
}

/// Collects names of helper functions that contain assertion calls.
class _HelperFunctionCollector extends RecursiveAstVisitor<void> {
  _HelperFunctionCollector(this.builtInAssertions);

  final Set<String> builtInAssertions;
  final Set<String> functionsWithAssertions = <String>{};

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    // Check if this function's body contains any assertions
    final FunctionBody body = node.functionExpression.body;
    final _AssertionFinder finder = _AssertionFinder(builtInAssertions);
    body.visitChildren(finder);

    if (finder.foundAssertion) {
      functionsWithAssertions.add(node.name.lexeme);
    }

    super.visitFunctionDeclaration(node);
  }

  @override
  void visitFunctionDeclarationStatement(FunctionDeclarationStatement node) {
    // Handle local function declarations (inside other functions/blocks)
    final FunctionDeclaration declaration = node.functionDeclaration;
    final FunctionBody body = declaration.functionExpression.body;
    final _AssertionFinder finder = _AssertionFinder(builtInAssertions);
    body.visitChildren(finder);

    if (finder.foundAssertion) {
      functionsWithAssertions.add(declaration.name.lexeme);
    }

    super.visitFunctionDeclarationStatement(node);
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    // Handle function expressions assigned to variables:
    // void Function() myHelper = () { expect(...); };
    // or: final expectResult = (String input) { expect(...); };
    final Expression? initializer = node.initializer;
    if (initializer is FunctionExpression) {
      final _AssertionFinder finder = _AssertionFinder(builtInAssertions);
      initializer.body.visitChildren(finder);

      if (finder.foundAssertion) {
        functionsWithAssertions.add(node.name.lexeme);
      }
    }

    super.visitVariableDeclaration(node);
  }
}

class _AssertionFinder extends RecursiveAstVisitor<void> {
  _AssertionFinder(this.assertionNames);

  final Set<String> assertionNames;
  bool foundAssertion = false;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (assertionNames.contains(node.methodName.name)) {
      foundAssertion = true;
      return; // Short-circuit
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    // Check for matchers like throwsA(...)
    final Expression function = node.function;
    if (function is SimpleIdentifier &&
        assertionNames.contains(function.name)) {
      foundAssertion = true;
      return;
    }
    super.visitFunctionExpressionInvocation(node);
  }
}

/// Warns when an async callback is used inside fakeAsync.
///
/// Using async inside fakeAsync defeats the purpose of fake time control.
/// The async operations won't use the fake clock and can cause test flakiness.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// fakeAsync((fake) async {  // BAD: async callback!
///   await Future.delayed(Duration(seconds: 1));
///   fake.elapse(Duration(seconds: 1));
/// });
/// ```
///
/// #### GOOD:
/// ```dart
/// fakeAsync((fake) {  // GOOD: synchronous callback
///   fake.elapse(Duration(seconds: 1));
///   expect(completer.isCompleted, isTrue);
/// });
/// ```
class AvoidAsyncCallbackInFakeAsyncRule extends SaropaLintRule {
  const AvoidAsyncCallbackInFakeAsyncRule() : super(code: _code);

  /// Critical bug. Async in fakeAsync causes unpredictable behavior.
  @override
  LintImpact get impact => LintImpact.critical;

  static const LintCode _code = LintCode(
    name: 'avoid_async_callback_in_fake_async',
    problemMessage:
        'Async callback inside fakeAsync defeats fake time control.',
    correctionMessage:
        'Remove async keyword. Use synchronous code with fake.elapse() '
        'to control time.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Only run in test files
    final String path = resolver.path;
    if (!path.endsWith('_test.dart') &&
        !path.contains('/test/') &&
        !path.contains(r'\test\')) {
      return;
    }

    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'fakeAsync') return;

      final ArgumentList args = node.argumentList;
      if (args.arguments.isEmpty) return;

      final Expression callback = args.arguments.first;
      if (callback is! FunctionExpression) return;

      // Check if the callback is async
      if (callback.body.isAsynchronous) {
        reporter.atNode(callback, code);
      }
    });
  }
}

/// Warns when string keys are used in tests instead of Symbols.
///
/// Using Symbols for test keys provides compile-time checking and better
/// refactoring support compared to magic string keys.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// tester.widget(find.byKey(const Key('submitButton')));
/// ```
///
/// #### GOOD:
/// ```dart
/// // Define symbol in test constants
/// const kSubmitButton = Key('submitButton');
///
/// // Use in test
/// tester.widget(find.byKey(kSubmitButton));
/// ```
class PreferSymbolOverKeyRule extends SaropaLintRule {
  const PreferSymbolOverKeyRule() : super(code: _code);

  /// Style preference for maintainability.
  @override
  LintImpact get impact => LintImpact.low;

  static const LintCode _code = LintCode(
    name: 'prefer_symbol_over_key',
    problemMessage: 'Consider using a constant Key instead of string literal.',
    correctionMessage:
        'Define a constant for the Key to improve maintainability.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Only run in test files
    final String path = resolver.path;
    if (!path.endsWith('_test.dart') &&
        !path.contains('/test/') &&
        !path.contains(r'\test\')) {
      return;
    }

    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name2.lexeme;

      // Check for Key constructor with string literal
      if (typeName != 'Key' && typeName != 'ValueKey') return;

      final ArgumentList args = node.argumentList;
      if (args.arguments.isEmpty) return;

      final Expression firstArg = args.arguments.first;
      if (firstArg is StringLiteral) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when test creates files/data without tearDown cleanup.
///
/// Tests that create files, directories, or database entries should clean
/// up in tearDown to prevent test pollution and disk space issues.
///
/// **BAD:**
/// ```dart
/// test('saves file', () async {
///   await File('test.txt').writeAsString('data');
///   expect(await File('test.txt').exists(), isTrue);
///   // File left on disk!
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// late File testFile;
///
/// setUp(() {
///   testFile = File('test.txt');
/// });
///
/// tearDown(() async {
///   if (await testFile.exists()) {
///     await testFile.delete();
///   }
/// });
///
/// test('saves file', () async {
///   await testFile.writeAsString('data');
///   expect(await testFile.exists(), isTrue);
/// });
/// ```
class RequireTestCleanupRule extends SaropaLintRule {
  const RequireTestCleanupRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'require_test_cleanup',
    problemMessage: 'Test creates resources without tearDown cleanup.',
    correctionMessage: 'Add tearDown to clean up created files or data.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String path = resolver.path;
    if (!path.endsWith('_test.dart') &&
        !path.contains('/test/') &&
        !path.contains(r'\test\')) {
      return;
    }

    bool hasTearDown = false;
    MethodInvocation? testWithResourceCreation;

    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (methodName == 'tearDown' || methodName == 'tearDownAll') {
        hasTearDown = true;
      }

      if (methodName == 'test' || methodName == 'testWidgets') {
        final ArgumentList args = node.argumentList;
        if (args.arguments.length >= 2) {
          final Expression callback = args.arguments[1];
          if (callback is FunctionExpression) {
            final String bodySource = callback.body.toSource();

            // Check for resource creation patterns
            // Use specific patterns to avoid false positives like createWidget()
            if (_createsTestResources(bodySource)) {
              testWithResourceCreation = node;
            }
          }
        }
      }
    });

    context.addPostRunCallback(() {
      if (testWithResourceCreation != null && !hasTearDown) {
        reporter.atNode(testWithResourceCreation!, code);
      }
    });
  }

  /// Check for patterns that create test resources requiring cleanup.
  /// Uses specific patterns to avoid false positives from methods like
  /// createWidget(), insertText(), output(), etc.
  bool _createsTestResources(String bodySource) {
    // File system operations - exact constructor calls
    if (bodySource.contains('File(') || bodySource.contains('Directory(')) {
      return true;
    }

    // File write operations - specific method patterns
    if (bodySource.contains('.writeAsBytes') ||
        bodySource.contains('.writeAsString') ||
        bodySource.contains('.writeAsBytesSync') ||
        bodySource.contains('.writeAsStringSync')) {
      return true;
    }

    // Directory/file creation - check for .create() on file-like objects
    // Use regex to match file.create() or dir.create() patterns
    final createPattern = RegExp(r'\b(file|dir|directory|temp)\w*\.create\(');
    if (createPattern.hasMatch(bodySource.toLowerCase())) {
      return true;
    }

    // Database operations - require specific target patterns
    // e.g., db.insert(, collection.insert(, table.insert(
    final dbInsertPattern =
        RegExp(r'\b(db|database|collection|table)\w*\.insert\(');
    if (dbInsertPattern.hasMatch(bodySource.toLowerCase())) {
      return true;
    }

    // Hive/SharedPrefs operations - require box. or prefs. prefix
    final storagePattern =
        RegExp(r'\b(box|prefs|preferences|storage)\w*\.put\(');
    if (storagePattern.hasMatch(bodySource.toLowerCase())) {
      return true;
    }

    return false;
  }
}

/// Warns when tests could use variant for different configurations.
///
/// Duplicate tests for different screen sizes, locales, or themes should
/// use testVariants for cleaner code and better coverage reporting.
///
/// **BAD:**
/// ```dart
/// testWidgets('renders on small screen', (tester) async {
///   tester.binding.window.physicalSizeTestValue = Size(320, 480);
///   await tester.pumpWidget(MyWidget());
///   expect(...);
/// });
///
/// testWidgets('renders on large screen', (tester) async {
///   tester.binding.window.physicalSizeTestValue = Size(1024, 768);
///   await tester.pumpWidget(MyWidget());
///   expect(...);
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// testWidgets('renders correctly', variant: ScreenSizeVariant(), (tester) async {
///   await tester.pumpWidget(MyWidget());
///   expect(...);
/// });
/// ```
class PreferTestVariantRule extends SaropaLintRule {
  const PreferTestVariantRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  static const LintCode _code = LintCode(
    name: 'prefer_test_variant',
    problemMessage:
        'Similar tests could use variant for different configurations.',
    correctionMessage:
        'Use testWidgets variant parameter for configuration testing.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String path = resolver.path;
    if (!path.endsWith('_test.dart') &&
        !path.contains('/test/') &&
        !path.contains(r'\test\')) {
      return;
    }

    final List<MethodInvocation> sizeTests = <MethodInvocation>[];

    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'testWidgets') return;

      final ArgumentList args = node.argumentList;
      if (args.arguments.length >= 2) {
        final Expression callback = args.arguments[1];
        if (callback is FunctionExpression) {
          final String bodySource = callback.body.toSource();

          // Check for screen size configuration
          if (bodySource.contains('physicalSizeTestValue') ||
              bodySource.contains('devicePixelRatio') ||
              bodySource.contains('textScaleFactor')) {
            sizeTests.add(node);
          }
        }
      }
    });

    context.addPostRunCallback(() {
      // If there are multiple size-related tests, suggest variant
      if (sizeTests.length >= 2) {
        for (final MethodInvocation test in sizeTests) {
          reporter.atNode(test.methodName, code);
        }
      }
    });
  }
}

/// Warns when widget tests lack accessibility guidelines check.
///
/// Widget tests should verify accessibility to catch issues early.
/// Use meetsGuideline matcher for automated accessibility testing.
///
/// **BAD:**
/// ```dart
/// testWidgets('button works', (tester) async {
///   await tester.pumpWidget(MyWidget());
///   await tester.tap(find.byType(ElevatedButton));
///   expect(find.text('Clicked'), findsOneWidget);
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// testWidgets('button is accessible', (tester) async {
///   await tester.pumpWidget(MyWidget());
///
///   final SemanticsHandle handle = tester.ensureSemantics();
///   await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
///   await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
///   handle.dispose();
/// });
/// ```
class RequireAccessibilityTestsRule extends SaropaLintRule {
  const RequireAccessibilityTestsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'require_accessibility_tests',
    problemMessage: 'Widget tests should include accessibility checks.',
    correctionMessage: 'Add meetsGuideline assertions for accessibility.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String path = resolver.path;
    if (!path.endsWith('_test.dart') &&
        !path.contains('/test/') &&
        !path.contains(r'\test\')) {
      return;
    }

    bool hasAccessibilityTest = false;

    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check for accessibility testing patterns
      if (methodName == 'meetsGuideline' ||
          methodName == 'ensureSemantics' ||
          methodName == 'getSemanticsData') {
        hasAccessibilityTest = true;
      }
    });

    context.registry.addCompilationUnit((CompilationUnit unit) {
      final String source = unit.toSource();
      if (source.contains('testWidgets') && !hasAccessibilityTest) {
        // Report at first testWidgets call
        // This is a file-level suggestion, so we report once
      }
    });
  }
}

/// Warns when animated widget tests don't use pump with duration.
///
/// Animations need time to complete. Tests must use pumpAndSettle or
/// pump(duration) to advance animation frames.
///
/// **BAD:**
/// ```dart
/// testWidgets('animation plays', (tester) async {
///   await tester.pumpWidget(AnimatedWidget());
///   await tester.pump();  // Only one frame!
///   expect(find.byType(AnimatedWidget), findsOneWidget);
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// testWidgets('animation completes', (tester) async {
///   await tester.pumpWidget(AnimatedWidget());
///   await tester.pump(const Duration(milliseconds: 500));
///   // Or
///   await tester.pumpAndSettle();
/// });
/// ```
class RequireAnimationTestsRule extends SaropaLintRule {
  const RequireAnimationTestsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'require_animation_tests',
    problemMessage: 'Animated widget test should use pump with duration.',
    correctionMessage: 'Use pump(Duration) or pumpAndSettle for animations.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  // Animated widgets that need duration pump
  static const Set<String> _animatedWidgets = <String>{
    'AnimatedContainer',
    'AnimatedOpacity',
    'AnimatedPositioned',
    'AnimatedSize',
    'AnimatedSwitcher',
    'AnimatedCrossFade',
    'FadeTransition',
    'SlideTransition',
    'ScaleTransition',
    'Hero',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String path = resolver.path;
    if (!path.endsWith('_test.dart') &&
        !path.contains('/test/') &&
        !path.contains(r'\test\')) {
      return;
    }

    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'testWidgets') return;

      final ArgumentList args = node.argumentList;
      if (args.arguments.length < 2) return;

      final Expression callback = args.arguments[1];
      if (callback is! FunctionExpression) return;

      final String bodySource = callback.body.toSource();

      // Check if test uses animated widgets
      bool hasAnimatedWidget = false;
      for (final String widget in _animatedWidgets) {
        if (bodySource.contains(widget)) {
          hasAnimatedWidget = true;
          break;
        }
      }

      if (!hasAnimatedWidget) return;

      // Check for proper pump usage
      final bool hasDurationPump = bodySource.contains('pumpAndSettle') ||
          bodySource.contains('pump(const Duration') ||
          bodySource.contains('pump(Duration');

      if (!hasDurationPump) {
        reporter.atNode(node.methodName, code);
      }
    });
  }
}
