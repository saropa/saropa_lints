// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;
import 'package:analyzer/source/source_range.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

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
class AvoidDuplicateTestAssertionsRule extends SaropaLintRule {
  const AvoidDuplicateTestAssertionsRule() : super(code: _code);

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
class AvoidEmptyTestGroupsRule extends SaropaLintRule {
  const AvoidEmptyTestGroupsRule() : super(code: _code);

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
/// **Quick fix available:** Replaces `expect` with `expectLater`.
class PreferExpectLaterRule extends SaropaLintRule {
  const PreferExpectLaterRule() : super(code: _code);

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
          for (final VariableDeclaration variable in member.variables.variables) {
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

  static const LintCode _code = LintCode(
    name: 'require_test_isolation',
    problemMessage:
        'Mutable top-level variable may cause test coupling.',
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

  static const LintCode _code = LintCode(
    name: 'avoid_real_dependencies_in_tests',
    problemMessage:
        'Test uses real network/database call. Use mocks instead.',
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

  static const LintCode _code = LintCode(
    name: 'require_text_input_tests',
    problemMessage:
        'Widget test creates text input but does not test user input.',
    correctionMessage:
        'Add tester.enterText() to verify text input behavior.',
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
