// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Testing best practices lint rules for Flutter/Dart applications.
///
/// These rules help enforce testing standards and catch common
/// testing anti-patterns.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Warns when test has no assertions.
///
/// Tests without assertions don't actually verify anything.
///
/// **BAD:**
/// ```dart
/// test('should process order', () {
///   final order = Order(items: [item1, item2]);
///   processOrder(order);
///   // No assertion!
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// test('should process order', () {
///   final order = Order(items: [item1, item2]);
///   processOrder(order);
///   expect(order.status, OrderStatus.processed);
/// });
/// ```
class RequireTestAssertionsRule extends DartLintRule {
  const RequireTestAssertionsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_test_assertions',
    problemMessage: 'Test has no assertions.',
    correctionMessage: 'Add expect(), verify(), or other assertions.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _assertionMethods = <String>{
    'expect',
    'verify',
    'verifyNever',
    'verifyInOrder',
    'expectLater',
    'expectAsync',
    'check',
    'assert',
    'fail',
    'throwsA',
  };

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    // Only check test files
    final String path = resolver.source.fullName;
    if (!path.contains('_test.dart') && !path.contains('/test/')) return;

    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check for test() or testWidgets() calls
      if (methodName != 'test' && methodName != 'testWidgets') return;

      final ArgumentList args = node.argumentList;
      if (args.arguments.length < 2) return;

      // Get the test body (second argument, usually a function)
      final Expression? bodyArg = args.arguments.length >= 2 ? args.arguments[1] : null;

      if (bodyArg == null) return;

      final String bodySource = bodyArg.toSource();

      // Check if any assertion methods are called
      bool hasAssertion = false;
      for (final String assertion in _assertionMethods) {
        if (bodySource.contains('$assertion(')) {
          hasAssertion = true;
          break;
        }
      }

      if (!hasAssertion) {
        reporter.atNode(node.methodName, code);
      }
    });
  }
}

/// Warns when test description is too vague.
///
/// Test names should clearly describe what is being tested.
///
/// **BAD:**
/// ```dart
/// test('test 1', () { ... });
/// test('works', () { ... });
/// test('should work', () { ... });
/// ```
///
/// **GOOD:**
/// ```dart
/// test('should return user when valid ID is provided', () { ... });
/// test('throws ArgumentError when email is invalid', () { ... });
/// ```
class AvoidVagueTestDescriptionsRule extends DartLintRule {
  const AvoidVagueTestDescriptionsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_vague_test_descriptions',
    problemMessage: 'Test description is too vague.',
    correctionMessage: 'Use descriptive names like "should [action] when [condition]".',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _vaguePatterns = <String>{
    'test 1',
    'test 2',
    'test1',
    'test2',
    'works',
    'should work',
    'it works',
    'basic test',
    'simple test',
    'todo',
    'fix later',
  };

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    // Only check test files
    final String path = resolver.source.fullName;
    if (!path.contains('_test.dart') && !path.contains('/test/')) return;

    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (methodName != 'test' && methodName != 'testWidgets' && methodName != 'group') {
        return;
      }

      final ArgumentList args = node.argumentList;
      if (args.arguments.isEmpty) return;

      final Expression firstArg = args.arguments.first;
      if (firstArg is! StringLiteral) return;

      final String? description = firstArg.stringValue?.toLowerCase();
      if (description == null) return;

      // Check for vague patterns
      for (final String pattern in _vaguePatterns) {
        if (description == pattern || description.startsWith(pattern)) {
          reporter.atNode(firstArg, code);
          return;
        }
      }

      // Check for too short descriptions
      if (description.length < 10) {
        reporter.atNode(firstArg, code);
      }
    });
  }
}

/// Warns when test uses real network calls.
///
/// Tests should mock external dependencies for reliability.
///
/// **BAD:**
/// ```dart
/// test('should fetch user', () async {
///   final client = HttpClient();
///   final user = await client.get('https://api.example.com/users/1');
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// test('should fetch user', () async {
///   final client = MockHttpClient();
///   when(client.get(any)).thenAnswer((_) async => mockUserResponse);
///   final user = await client.get('https://api.example.com/users/1');
/// });
/// ```
class AvoidRealNetworkCallsInTestsRule extends DartLintRule {
  const AvoidRealNetworkCallsInTestsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_real_network_calls_in_tests',
    problemMessage: 'Test may be making real network calls.',
    correctionMessage: 'Mock HTTP clients and other external dependencies.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _networkPatterns = <String>{
    'HttpClient(',
    'http.get(',
    'http.post(',
    'http.put(',
    'http.delete(',
    'Dio(',
    'dio.get(',
    'dio.post(',
    'Uri.parse(',
    'Uri.https(',
    'Uri.http(',
  };

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    // Only check test files
    final String path = resolver.source.fullName;
    if (!path.contains('_test.dart') && !path.contains('/test/')) return;

    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (methodName != 'test' && methodName != 'testWidgets') return;

      final ArgumentList args = node.argumentList;
      if (args.arguments.length < 2) return;

      final Expression? bodyArg = args.arguments.length >= 2 ? args.arguments[1] : null;

      if (bodyArg == null) return;

      final String bodySource = bodyArg.toSource();

      // Skip if using mocks
      if (bodySource.contains('Mock') || bodySource.contains('mock')) return;

      // Check for network patterns
      for (final String pattern in _networkPatterns) {
        if (bodySource.contains(pattern)) {
          reporter.atNode(node.methodName, code);
          return;
        }
      }
    });
  }
}

/// Warns when test has hardcoded delays.
///
/// Tests with hardcoded delays are slow and flaky.
///
/// **BAD:**
/// ```dart
/// test('should update after delay', () async {
///   triggerUpdate();
///   await Future.delayed(Duration(seconds: 2));
///   expect(widget.updated, true);
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// test('should update after delay', () async {
///   await tester.pumpAndSettle();
///   // or
///   await expectLater(
///     stream,
///     emitsInOrder([...]),
///   );
/// });
/// ```
class AvoidHardcodedTestDelaysRule extends DartLintRule {
  const AvoidHardcodedTestDelaysRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_hardcoded_test_delays',
    problemMessage: 'Test has hardcoded delay which makes tests slow and flaky.',
    correctionMessage: 'Use pumpAndSettle(), stream matchers, or fake timers instead.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    // Only check test files
    final String path = resolver.source.fullName;
    if (!path.contains('_test.dart') && !path.contains('/test/')) return;

    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check for Future.delayed calls
      if (methodName == 'delayed') {
        final Expression? target = node.target;
        if (target is Identifier && target.name == 'Future') {
          reporter.atNode(node, code);
          return;
        }
      }

      // Check for sleep calls
      if (methodName == 'sleep') {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when test file lacks setUp or tearDown.
///
/// Tests should properly set up and clean up resources.
///
/// **BAD:**
/// ```dart
/// void main() {
///   test('test 1', () { ... });
///   test('test 2', () { ... }); // May depend on test 1's state
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void main() {
///   late UserRepository repo;
///
///   setUp(() {
///     repo = UserRepository();
///   });
///
///   tearDown(() {
///     repo.dispose();
///   });
///
///   test('test 1', () { ... });
///   test('test 2', () { ... });
/// }
/// ```
class RequireTestSetupTeardownRule extends DartLintRule {
  const RequireTestSetupTeardownRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_test_setup_teardown',
    problemMessage: 'Test file lacks setUp/tearDown for shared resources.',
    correctionMessage: 'Add setUp() and tearDown() to initialize and clean up test state.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    // Only check test files
    final String path = resolver.source.fullName;
    if (!path.contains('_test.dart') && !path.contains('/test/')) return;

    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
      // Only check main function
      if (node.name.lexeme != 'main') return;

      final FunctionBody body = node.functionExpression.body;
      final String bodySource = body.toSource();

      // Count tests
      final int testCount =
          'test('.allMatches(bodySource).length + 'testWidgets('.allMatches(bodySource).length;

      // If multiple tests, check for setUp
      if (testCount > 2) {
        if (!bodySource.contains('setUp(') && !bodySource.contains('setUpAll(')) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when widget test doesn't pump the widget tree.
///
/// Widget tests need to pump to process the widget lifecycle.
///
/// **BAD:**
/// ```dart
/// testWidgets('should show text', (tester) async {
///   await tester.pumpWidget(MyWidget());
///   expect(find.text('Hello'), findsOneWidget);
///   // Missing pump after interaction
///   await tester.tap(find.byType(Button));
///   expect(find.text('Tapped'), findsOneWidget); // May fail
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// testWidgets('should show text', (tester) async {
///   await tester.pumpWidget(MyWidget());
///   expect(find.text('Hello'), findsOneWidget);
///   await tester.tap(find.byType(Button));
///   await tester.pump(); // Process the tap
///   expect(find.text('Tapped'), findsOneWidget);
/// });
/// ```
class RequirePumpAfterInteractionRule extends DartLintRule {
  const RequirePumpAfterInteractionRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_pump_after_interaction',
    problemMessage: 'Widget test may need pump() or pumpAndSettle() after interaction.',
    correctionMessage: 'Call pump() or pumpAndSettle() after tap(), drag(), or other interactions.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _interactionMethods = <String>{
    'tap(',
    'longPress(',
    'drag(',
    'fling(',
    'enterText(',
    'sendKeyEvent(',
  };

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    // Only check test files
    final String path = resolver.source.fullName;
    if (!path.contains('_test.dart') && !path.contains('/test/')) return;

    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (methodName != 'testWidgets') return;

      final ArgumentList args = node.argumentList;
      if (args.arguments.length < 2) return;

      final Expression? bodyArg = args.arguments.length >= 2 ? args.arguments[1] : null;

      if (bodyArg == null) return;

      final String bodySource = bodyArg.toSource();

      // Check for interactions without pumps
      for (final String interaction in _interactionMethods) {
        if (bodySource.contains('tester.$interaction')) {
          // Check if pump follows (simple heuristic)
          final int interactionIndex = bodySource.indexOf('tester.$interaction');
          final String afterInteraction = bodySource.substring(interactionIndex);

          // Look for expect before pump
          final int expectIndex = afterInteraction.indexOf('expect(');
          final int pumpIndex = afterInteraction.indexOf('pump');

          if (expectIndex != -1 && (pumpIndex == -1 || pumpIndex > expectIndex)) {
            reporter.atNode(node.methodName, code);
            return;
          }
        }
      }
    });
  }
}

/// Warns when test uses production configuration.
///
/// Tests should use test-specific configuration.
///
/// **BAD:**
/// ```dart
/// test('should connect', () async {
///   final api = Api(baseUrl: 'https://production.api.com');
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// test('should connect', () async {
///   final api = Api(baseUrl: 'http://localhost:8080');
///   // or use mock
/// });
/// ```
class AvoidProductionConfigInTestsRule extends DartLintRule {
  const AvoidProductionConfigInTestsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_production_config_in_tests',
    problemMessage: 'Test may be using production configuration.',
    correctionMessage: 'Use test-specific or mocked configuration.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _productionPatterns = <String>{
    'production',
    'prod.',
    '.prod',
    'api.com',
    'api.io',
    'amazonaws.com',
    'firebaseio.com',
    'supabase.co',
  };

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    // Only check test files
    final String path = resolver.source.fullName;
    if (!path.contains('_test.dart') && !path.contains('/test/')) return;

    context.registry.addSimpleStringLiteral((SimpleStringLiteral node) {
      final String value = node.value.toLowerCase();

      for (final String pattern in _productionPatterns) {
        if (value.contains(pattern)) {
          reporter.atNode(node, code);
          return;
        }
      }
    });
  }
}
