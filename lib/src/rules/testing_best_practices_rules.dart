// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Testing best practices lint rules for Flutter/Dart applications.
///
/// These rules help enforce testing standards and catch common
/// testing anti-patterns.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

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
class RequireTestAssertionsRule extends SaropaLintRule {
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
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
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
      final Expression? bodyArg =
          args.arguments.length >= 2 ? args.arguments[1] : null;

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
class AvoidVagueTestDescriptionsRule extends SaropaLintRule {
  const AvoidVagueTestDescriptionsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_vague_test_descriptions',
    problemMessage: 'Test description is too vague.',
    correctionMessage:
        'Use descriptive names like "should [action] when [condition]".',
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
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Only check test files
    final String path = resolver.source.fullName;
    if (!path.contains('_test.dart') && !path.contains('/test/')) return;

    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (methodName != 'test' &&
          methodName != 'testWidgets' &&
          methodName != 'group') {
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

      // Only flag very short descriptions (< 5 chars) as those are always vague
      // Don't flag moderately short names like "bug fix" which may be intentional
      if (description.length < 5) {
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
class AvoidRealNetworkCallsInTestsRule extends SaropaLintRule {
  const AvoidRealNetworkCallsInTestsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_real_network_calls_in_tests',
    problemMessage: 'Test may be making real network calls.',
    correctionMessage: 'Mock HTTP clients and other external dependencies.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Network patterns that indicate real HTTP calls.
  /// Removed Uri.parse/Uri.https/Uri.http as these are just URL construction,
  /// not actual network calls.
  static const Set<String> _networkPatterns = <String>{
    'HttpClient(',
    'http.get(',
    'http.post(',
    'http.put(',
    'http.delete(',
    'Dio(',
    'dio.get(',
    'dio.post(',
    'dio.put(',
    'dio.delete(',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
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

      final Expression? bodyArg =
          args.arguments.length >= 2 ? args.arguments[1] : null;

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
class AvoidHardcodedTestDelaysRule extends SaropaLintRule {
  const AvoidHardcodedTestDelaysRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_hardcoded_test_delays',
    problemMessage:
        'Test has hardcoded delay which makes tests slow and flaky.',
    correctionMessage:
        'Use pumpAndSettle(), stream matchers, or fake timers instead.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
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
class RequireTestSetupTeardownRule extends SaropaLintRule {
  const RequireTestSetupTeardownRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_test_setup_teardown',
    problemMessage: 'Test file lacks setUp/tearDown for shared resources.',
    correctionMessage:
        'Add setUp() and tearDown() to initialize and clean up test state.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
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
      final int testCount = 'test('.allMatches(bodySource).length +
          'testWidgets('.allMatches(bodySource).length;

      // If multiple tests, check for setUp
      if (testCount > 2) {
        if (!bodySource.contains('setUp(') &&
            !bodySource.contains('setUpAll(')) {
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
class RequirePumpAfterInteractionRule extends SaropaLintRule {
  const RequirePumpAfterInteractionRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_pump_after_interaction',
    problemMessage:
        'Widget test may need pump() or pumpAndSettle() after interaction.',
    correctionMessage:
        'Call pump() or pumpAndSettle() after tap(), drag(), or other interactions.',
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
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
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

      final Expression? bodyArg =
          args.arguments.length >= 2 ? args.arguments[1] : null;

      if (bodyArg == null) return;

      final String bodySource = bodyArg.toSource();

      // Check for interactions without pumps
      for (final String interaction in _interactionMethods) {
        if (bodySource.contains('tester.$interaction')) {
          // Check if pump follows (simple heuristic)
          final int interactionIndex =
              bodySource.indexOf('tester.$interaction');
          final String afterInteraction =
              bodySource.substring(interactionIndex);

          // Look for expect before pump
          final int expectIndex = afterInteraction.indexOf('expect(');
          final int pumpIndex = afterInteraction.indexOf('pump');

          if (expectIndex != -1 &&
              (pumpIndex == -1 || pumpIndex > expectIndex)) {
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
class AvoidProductionConfigInTestsRule extends SaropaLintRule {
  const AvoidProductionConfigInTestsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_production_config_in_tests',
    problemMessage: 'Test may be using production configuration.',
    correctionMessage: 'Use test-specific or mocked configuration.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Production URL patterns. Should be specific enough to avoid false positives
  /// when tests are validating URL formats or rejection logic.
  static const Set<String> _productionPatterns = <String>{
    'production',
    'prod.', // prod. prefix like prod.api.example.com
    '.prod.', // .prod. in the middle
    'amazonaws.com',
    'firebaseio.com',
    'supabase.co',
    'googleapis.com',
    // Note: 'api.com' and 'api.io' removed as they cause false positives
    // in tests that validate URL rejection logic
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
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

/// Suggests using pumpAndSettle() after user interactions in widget tests.
///
/// After tap(), drag(), or other interactions, using pumpAndSettle() ensures
/// all animations complete before assertions. Using pump() alone may miss
/// animations or scheduled frames.
///
/// Note: This rule only triggers when pump() follows an interaction method.
/// Using pump() with explicit duration for frame-by-frame control is valid.
///
/// **BAD:**
/// ```dart
/// testWidgets('should animate', (tester) async {
///   await tester.pumpWidget(AnimatedWidget());
///   await tester.tap(find.byType(Button));
///   await tester.pump(); // May not wait for animation
///   expect(find.text('Done'), findsOneWidget);
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// testWidgets('should animate', (tester) async {
///   await tester.pumpWidget(AnimatedWidget());
///   await tester.tap(find.byType(Button));
///   await tester.pumpAndSettle(); // Waits for animations
///   expect(find.text('Done'), findsOneWidget);
/// });
/// ```
class PreferPumpAndSettleRule extends SaropaLintRule {
  const PreferPumpAndSettleRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_pump_and_settle',
    problemMessage:
        'Consider using pumpAndSettle() after interactions to wait for animations.',
    correctionMessage:
        'Use pumpAndSettle() after tap/drag/etc. to ensure animations complete.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _interactionMethods = <String>{
    'tap',
    'longPress',
    'drag',
    'dragFrom',
    'dragUntilVisible',
    'fling',
    'flingFrom',
    'enterText',
    'sendKeyEvent',
    'sendKeyDownEvent',
    'sendKeyUpEvent',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Only check test files
    final String path = resolver.source.fullName;
    if (!path.contains('_test.dart') && !path.contains('/test/')) return;

    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check for tester.pump() calls (not pumpWidget or pumpAndSettle)
      if (methodName == 'pump') {
        final Expression? target = node.target;
        if (target is SimpleIdentifier && target.name == 'tester') {
          // Skip if pump has arguments (explicit duration = intentional)
          if (node.argumentList.arguments.isNotEmpty) return;

          // Check if there's an interaction method nearby in the same test
          // Look at the parent function body
          AstNode? current = node.parent;
          while (current != null) {
            if (current is FunctionExpression || current is FunctionBody) {
              final String bodySource = current.toSource();

              // Check if any interaction method appears in this test
              for (final String interaction in _interactionMethods) {
                final pattern = 'tester.$interaction(';
                final interactionIndex = bodySource.indexOf(pattern);
                if (interactionIndex != -1) {
                  // Found an interaction - this pump() may need to be pumpAndSettle
                  reporter.atNode(node, code);
                  return;
                }
              }
              break;
            }
            current = current.parent;
          }
        }
      }
    });
  }
}
