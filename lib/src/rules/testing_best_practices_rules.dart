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
    if (!path.contains('_test.dart') &&
        !path.contains('/test/') &&
        !path.contains(r'\test\')) return;

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
    if (!path.contains('_test.dart') &&
        !path.contains('/test/') &&
        !path.contains(r'\test\')) return;

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
    if (!path.contains('_test.dart') &&
        !path.contains('/test/') &&
        !path.contains(r'\test\')) return;

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
    if (!path.contains('_test.dart') &&
        !path.contains('/test/') &&
        !path.contains(r'\test\')) return;

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
    if (!path.contains('_test.dart') &&
        !path.contains('/test/') &&
        !path.contains(r'\test\')) return;

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
    if (!path.contains('_test.dart') &&
        !path.contains('/test/') &&
        !path.contains(r'\test\')) return;

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
    if (!path.contains('_test.dart') &&
        !path.contains('/test/') &&
        !path.contains(r'\test\')) return;

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
    if (!path.contains('_test.dart') &&
        !path.contains('/test/') &&
        !path.contains(r'\test\')) return;

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

// ============================================================================
// NEW TESTING RULES FROM ROADMAP
// ============================================================================

/// Warns when sleep() or blocking delays are used in tests.
///
/// Real delays make tests slow and flaky. Use fake timers instead.
///
/// **BAD:**
/// ```dart
/// test('should timeout', () async {
///   await Future.delayed(Duration(seconds: 2));
///   expect(result, isTrue);
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// test('should timeout', () {
///   fakeAsync((async) {
///     async.elapse(Duration(seconds: 2));
///     expect(result, isTrue);
///   });
/// });
/// ```
class AvoidTestSleepRule extends SaropaLintRule {
  const AvoidTestSleepRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_test_sleep',
    problemMessage: 'Avoid using sleep() or real delays in tests.',
    correctionMessage: 'Use fakeAsync and async.elapse() for time-based tests.',
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
    if (!path.contains('_test.dart') &&
        !path.contains('/test/') &&
        !path.contains(r'\test\')) return;

    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check for sleep() calls
      if (methodName == 'sleep') {
        reporter.atNode(node, code);
        return;
      }

      // Check for Future.delayed with actual duration
      if (methodName == 'delayed') {
        final Expression? target = node.target;
        if (target is SimpleIdentifier && target.name == 'Future') {
          // Check if inside fakeAsync - that's okay
          AstNode? current = node.parent;
          while (current != null) {
            if (current is MethodInvocation) {
              final String parentMethod = current.methodName.name;
              if (parentMethod == 'fakeAsync') {
                return; // Inside fakeAsync, so it's okay
              }
            }
            current = current.parent;
          }
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Suggests find.byKey() over find.text() for interactive widgets.
///
/// - **find.text()** is appropriate for verifying displayed content.
/// - **find.byKey()** is preferred for tapping/interacting with widgets
///   because it's stable when text changes (e.g., i18n, A/B testing).
///
/// This rule warns only when find.text() is used with tester.tap() or similar
/// interactions, not for content verification.
///
/// **OK for content verification:**
/// ```dart
/// expect(find.text('Welcome, John'), findsOneWidget);
/// ```
///
/// **Prefer keys for interactions:**
/// ```dart
/// // BAD - fragile if button text changes
/// await tester.tap(find.text('Submit'));
///
/// // GOOD - stable widget identification
/// await tester.tap(find.byKey(Key('submit_button')));
/// ```
class AvoidFindByTextRule extends SaropaLintRule {
  const AvoidFindByTextRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_find_by_text',
    problemMessage:
        'Prefer find.byKey() for widget interactions instead of find.text().',
    correctionMessage:
        'Add a Key to the widget and use find.byKey() for tap/drag operations.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Interaction methods where find.text() is fragile
  static const Set<String> _interactionMethods = <String>{
    'tap',
    'longPress',
    'drag',
    'dragFrom',
    'dragUntilVisible',
    'fling',
    'scroll',
    'scrollUntilVisible',
    'enterText',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Only check test files
    final String path = resolver.source.fullName;
    if (!path.contains('_test.dart') &&
        !path.contains('/test/') &&
        !path.contains(r'\test\')) return;

    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Only warn if this is an interaction method
      if (!_interactionMethods.contains(methodName)) return;

      // Check if any argument uses find.text()
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is MethodInvocation) {
          if (arg.methodName.name == 'text') {
            final Expression? target = arg.target;
            if (target is SimpleIdentifier && target.name == 'find') {
              reporter.atNode(arg, code);
            }
          }
        }
      }
    });
  }
}

/// Warns when widgets in tests don't have keys for findability.
///
/// Without keys, tests rely on fragile methods like find.text().
///
/// **BAD:**
/// ```dart
/// testWidgets('shows button', (tester) async {
///   await tester.pumpWidget(
///     ElevatedButton(onPressed: () {}, child: Text('Click')),
///   );
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// testWidgets('shows button', (tester) async {
///   await tester.pumpWidget(
///     ElevatedButton(
///       key: Key('submit_button'),
///       onPressed: () {},
///       child: Text('Click'),
///     ),
///   );
/// });
/// ```
class RequireTestKeysRule extends SaropaLintRule {
  const RequireTestKeysRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_test_keys',
    problemMessage: 'Widget in test should have a Key for findability.',
    correctionMessage: 'Add key: Key("descriptive_name") to the widget.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _interactiveWidgets = <String>{
    'ElevatedButton',
    'TextButton',
    'OutlinedButton',
    'IconButton',
    'FloatingActionButton',
    'TextField',
    'TextFormField',
    'Checkbox',
    'Radio',
    'Switch',
    'Slider',
    'DropdownButton',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Only check test files
    final String path = resolver.source.fullName;
    if (!path.contains('_test.dart') &&
        !path.contains('/test/') &&
        !path.contains(r'\test\')) return;

    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (!_interactiveWidgets.contains(typeName)) return;

      // Check if key is provided
      bool hasKey = false;
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'key') {
          hasKey = true;
          break;
        }
      }

      if (!hasKey) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

// ============================================================================
// BATCH 3 - MORE TESTING RULES FROM ROADMAP
// ============================================================================

/// Warns when tests don't follow the Arrange-Act-Assert pattern.
///
/// AAA pattern makes tests more readable and maintainable.
///
/// **BAD:**
/// ```dart
/// test('should process order', () {
///   final order = Order();
///   order.addItem(item);
///   expect(order.total, 100);
///   order.checkout();
///   expect(order.status, OrderStatus.completed);
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// test('should process order', () {
///   // Arrange
///   final order = Order();
///   order.addItem(item);
///
///   // Act
///   order.checkout();
///
///   // Assert
///   expect(order.status, OrderStatus.completed);
/// });
/// ```
class RequireArrangeActAssertRule extends SaropaLintRule {
  const RequireArrangeActAssertRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_arrange_act_assert',
    problemMessage: 'Test should follow Arrange-Act-Assert pattern.',
    correctionMessage:
        'Add // Arrange, // Act, // Assert comments to structure the test.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String path = resolver.source.fullName;
    if (!path.contains('_test.dart') &&
        !path.contains('/test/') &&
        !path.contains(r'\test\')) return;

    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (methodName != 'test' && methodName != 'testWidgets') return;

      final ArgumentList args = node.argumentList;
      if (args.arguments.length < 2) return;

      final Expression? bodyArg = args.arguments[1];
      if (bodyArg == null) return;

      final String bodySource = bodyArg.toSource();

      // Check for AAA comments (case-insensitive)
      final bool hasArrange = bodySource.toLowerCase().contains('// arrange') ||
          bodySource.toLowerCase().contains('//arrange');
      final bool hasAct = bodySource.toLowerCase().contains('// act') ||
          bodySource.toLowerCase().contains('//act');
      final bool hasAssert = bodySource.toLowerCase().contains('// assert') ||
          bodySource.toLowerCase().contains('//assert');

      // Only warn for longer tests that would benefit from structure
      final int lineCount = '\n'.allMatches(bodySource).length;
      if (lineCount > 5 && !hasArrange && !hasAct && !hasAssert) {
        reporter.atNode(node.methodName, code);
      }
    });
  }
}

/// Warns when Navigator is used in tests without mocking.
///
/// Real navigation in tests can cause issues and makes tests harder to verify.
///
/// **BAD:**
/// ```dart
/// testWidgets('navigates to details', (tester) async {
///   await tester.tap(find.byType(ListTile));
///   await tester.pumpAndSettle();
///   // Can't verify navigation happened!
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// testWidgets('navigates to details', (tester) async {
///   final mockNavigator = MockNavigatorObserver();
///   await tester.pumpWidget(
///     MaterialApp(
///       navigatorObservers: [mockNavigator],
///       home: MyWidget(),
///     ),
///   );
///   await tester.tap(find.byType(ListTile));
///   verify(mockNavigator.didPush(any, any));
/// });
/// ```
class PreferMockNavigatorRule extends SaropaLintRule {
  const PreferMockNavigatorRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_mock_navigator',
    problemMessage: 'Navigator usage in test should be mocked for verification.',
    correctionMessage: 'Use MockNavigatorObserver to verify navigation.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String path = resolver.source.fullName;
    if (!path.contains('_test.dart') &&
        !path.contains('/test/') &&
        !path.contains(r'\test\')) return;

    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check for Navigator.push, Navigator.pop, etc.
      if (methodName == 'push' ||
          methodName == 'pushNamed' ||
          methodName == 'pop' ||
          methodName == 'pushReplacement') {
        final Expression? target = node.target;
        if (target is SimpleIdentifier && target.name == 'Navigator') {
          reporter.atNode(node, code);
        }
        // Also check Navigator.of(context).push
        if (target is MethodInvocation && target.methodName.name == 'of') {
          final Expression? navTarget = target.target;
          if (navTarget is SimpleIdentifier && navTarget.name == 'Navigator') {
            reporter.atNode(node, code);
          }
        }
      }
    });
  }
}

/// Warns when Timer is used in widget tests without fakeAsync.
///
/// Real timers make tests slow and flaky.
///
/// **BAD:**
/// ```dart
/// testWidgets('shows loading', (tester) async {
///   Timer(Duration(seconds: 1), () => completer.complete());
///   await tester.pump(Duration(seconds: 2));
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// testWidgets('shows loading', (tester) async {
///   await tester.runAsync(() async {
///     // Use fakeAsync for timer-based code
///   });
/// });
/// ```
class AvoidRealTimerInWidgetTestRule extends SaropaLintRule {
  const AvoidRealTimerInWidgetTestRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_real_timer_in_widget_test',
    problemMessage: 'Avoid using Timer in widget tests.',
    correctionMessage: 'Use fakeAsync or tester.runAsync for timer-based tests.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String path = resolver.source.fullName;
    if (!path.contains('_test.dart') &&
        !path.contains('/test/') &&
        !path.contains(r'\test\')) return;

    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName == 'Timer') {
        // Check if inside fakeAsync
        AstNode? current = node.parent;
        while (current != null) {
          if (current is MethodInvocation) {
            final String parentMethod = current.methodName.name;
            if (parentMethod == 'fakeAsync' || parentMethod == 'runAsync') {
              return; // Inside fakeAsync, so it's okay
            }
          }
          current = current.parent;
        }
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when mocks are created but not verified.
///
/// Creating mocks without verification means the test doesn't check behavior.
///
/// **BAD:**
/// ```dart
/// test('should call api', () {
///   final mockApi = MockApi();
///   when(mockApi.fetch()).thenAnswer((_) async => data);
///   service.loadData();
///   // Missing verify!
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// test('should call api', () {
///   final mockApi = MockApi();
///   when(mockApi.fetch()).thenAnswer((_) async => data);
///   service.loadData();
///   verify(mockApi.fetch()).called(1);
/// });
/// ```
class RequireMockVerificationRule extends SaropaLintRule {
  const RequireMockVerificationRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_mock_verification',
    problemMessage: 'Mock is stubbed but never verified.',
    correctionMessage: 'Add verify() call to check mock interactions.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String path = resolver.source.fullName;
    if (!path.contains('_test.dart') &&
        !path.contains('/test/') &&
        !path.contains(r'\test\')) return;

    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check for when() calls (mockito stubbing)
      if (methodName == 'when') {
        // Look for verify in the same test
        AstNode? current = node.parent;
        while (current != null) {
          if (current is MethodInvocation) {
            final String parentName = current.methodName.name;
            if (parentName == 'test' || parentName == 'testWidgets') {
              // Found the test - check if it has verify
              final String testSource = current.toSource();
              if (!testSource.contains('verify(') &&
                  !testSource.contains('verifyNever(') &&
                  !testSource.contains('verifyInOrder(')) {
                reporter.atNode(node, code);
              }
              return;
            }
          }
          current = current.parent;
        }
      }
    });
  }
}

/// Warns when expect uses equality instead of matchers.
///
/// Matchers provide better error messages and more expressive tests.
///
/// **BAD:**
/// ```dart
/// expect(list.length, 3);
/// expect(value, true);
/// expect(result, null);
/// ```
///
/// **GOOD:**
/// ```dart
/// expect(list, hasLength(3));
/// expect(value, isTrue);
/// expect(result, isNull);
/// ```
class PreferMatcherOverEqualsRule extends SaropaLintRule {
  const PreferMatcherOverEqualsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_matcher_over_equals',
    problemMessage: 'Use matchers instead of direct equality for better messages.',
    correctionMessage:
        'Replace with isTrue, isFalse, isNull, hasLength(), etc.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String path = resolver.source.fullName;
    if (!path.contains('_test.dart') &&
        !path.contains('/test/') &&
        !path.contains(r'\test\')) return;

    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (methodName != 'expect') return;

      final ArgumentList args = node.argumentList;
      if (args.arguments.length < 2) return;

      final Expression matcher = args.arguments[1];

      // Check for literal booleans
      if (matcher is BooleanLiteral) {
        reporter.atNode(matcher, code);
        return;
      }

      // Check for null literal
      if (matcher is NullLiteral) {
        reporter.atNode(matcher, code);
        return;
      }

      // Check for .length comparisons
      final Expression actual = args.arguments.first;
      if (actual is PrefixedIdentifier && actual.identifier.name == 'length') {
        reporter.atNode(node, code);
      }
      if (actual is PropertyAccess &&
          actual.propertyName.name == 'length') {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when widget tests don't wrap with MaterialApp/Scaffold.
///
/// Most widgets need MaterialApp ancestor for theming and localization.
///
/// **BAD:**
/// ```dart
/// testWidgets('shows button', (tester) async {
///   await tester.pumpWidget(MyButton());
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// testWidgets('shows button', (tester) async {
///   await tester.pumpWidget(
///     MaterialApp(home: Scaffold(body: MyButton())),
///   );
/// });
/// ```
class PreferTestWrapperRule extends SaropaLintRule {
  const PreferTestWrapperRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_test_wrapper',
    problemMessage: 'Widget test should wrap with MaterialApp/CupertinoApp.',
    correctionMessage:
        'Wrap the widget with MaterialApp(home: Scaffold(body: ...)).',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String path = resolver.source.fullName;
    if (!path.contains('_test.dart') &&
        !path.contains('/test/') &&
        !path.contains(r'\test\')) return;

    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (methodName != 'pumpWidget') return;

      final ArgumentList args = node.argumentList;
      if (args.arguments.isEmpty) return;

      final Expression widget = args.arguments.first;
      final String widgetSource = widget.toSource();

      // Check if wrapped with MaterialApp or CupertinoApp
      if (!widgetSource.contains('MaterialApp') &&
          !widgetSource.contains('CupertinoApp') &&
          !widgetSource.contains('WidgetsApp')) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when widget tests don't test multiple screen sizes.
///
/// Responsive apps should be tested at different screen sizes.
///
/// **BAD:**
/// ```dart
/// testWidgets('shows layout', (tester) async {
///   await tester.pumpWidget(MyResponsiveWidget());
///   // Only tests default size
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// testWidgets('shows layout on phone', (tester) async {
///   tester.binding.window.physicalSizeTestValue = Size(400, 800);
///   await tester.pumpWidget(MyResponsiveWidget());
/// });
///
/// testWidgets('shows layout on tablet', (tester) async {
///   tester.binding.window.physicalSizeTestValue = Size(800, 1200);
///   await tester.pumpWidget(MyResponsiveWidget());
/// });
/// ```
class RequireScreenSizeTestsRule extends SaropaLintRule {
  const RequireScreenSizeTestsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_screen_size_tests',
    problemMessage: 'Consider testing at multiple screen sizes.',
    correctionMessage:
        'Use tester.binding.window.physicalSizeTestValue to test responsive layouts.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String path = resolver.source.fullName;
    if (!path.contains('_test.dart') &&
        !path.contains('/test/') &&
        !path.contains(r'\test\')) return;

    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (methodName != 'testWidgets') return;

      final ArgumentList args = node.argumentList;
      if (args.arguments.length < 2) return;

      // Get the test name
      final Expression? nameArg = args.arguments.first;
      if (nameArg is! StringLiteral) return;
      final String? testName = nameArg.stringValue?.toLowerCase();
      if (testName == null) return;

      // Check if test name suggests responsive behavior
      if (testName.contains('responsive') ||
          testName.contains('layout') ||
          testName.contains('adaptive')) {
        // Check if test sets screen size
        final String bodySource = args.arguments[1].toSource();
        if (!bodySource.contains('physicalSizeTestValue') &&
            !bodySource.contains('devicePixelRatio')) {
          reporter.atNode(node.methodName, code);
        }
      }
    });
  }
}

/// Warns when test setUp uses mutable shared state.
///
/// Shared mutable state can cause test pollution.
///
/// **BAD:**
/// ```dart
/// List<Item> items = [];
///
/// setUp(() {
///   items.add(Item());  // Accumulates across tests!
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// late List<Item> items;
///
/// setUp(() {
///   items = [Item()];  // Fresh list each test
/// });
/// ```
class AvoidStatefulTestSetupRule extends SaropaLintRule {
  const AvoidStatefulTestSetupRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_stateful_test_setup',
    problemMessage: 'setUp should not mutate shared state.',
    correctionMessage: 'Reassign variables instead of mutating them in setUp.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String path = resolver.source.fullName;
    if (!path.contains('_test.dart') &&
        !path.contains('/test/') &&
        !path.contains(r'\test\')) return;

    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (methodName != 'setUp' && methodName != 'setUpAll') return;

      final ArgumentList args = node.argumentList;
      if (args.arguments.isEmpty) return;

      final String bodySource = args.arguments.first.toSource();

      // Check for mutation methods
      if (bodySource.contains('.add(') ||
          bodySource.contains('.addAll(') ||
          bodySource.contains('.remove(') ||
          bodySource.contains('.clear(') ||
          bodySource.contains('++') ||
          bodySource.contains('--')) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when real HTTP client is used in tests.
///
/// Real network calls make tests slow and flaky.
///
/// **BAD:**
/// ```dart
/// test('fetches data', () async {
///   final client = http.Client();
///   final response = await client.get(Uri.parse('https://api.example.com'));
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// test('fetches data', () async {
///   final client = MockClient((request) async => Response('{}', 200));
///   final response = await client.get(Uri.parse('https://api.example.com'));
/// });
/// ```
class PreferMockHttpRule extends SaropaLintRule {
  const PreferMockHttpRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_mock_http',
    problemMessage: 'Use mock HTTP client in tests instead of real network calls.',
    correctionMessage: 'Replace http.Client() with MockClient.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String path = resolver.source.fullName;
    if (!path.contains('_test.dart') &&
        !path.contains('/test/') &&
        !path.contains(r'\test\')) return;

    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String typeName = node.constructorName.type.name.lexeme;

      // Check for http.Client(), HttpClient(), or Dio()
      if (typeName == 'Client' ||
          typeName == 'HttpClient' ||
          typeName == 'Dio') {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when visual widgets should have golden tests.
///
/// Golden tests catch visual regressions automatically.
///
/// **BAD:**
/// ```dart
/// testWidgets('shows custom button', (tester) async {
///   await tester.pumpWidget(MaterialApp(home: CustomButton()));
///   expect(find.byType(CustomButton), findsOneWidget);
///   // No visual verification!
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// testWidgets('shows custom button', (tester) async {
///   await tester.pumpWidget(MaterialApp(home: CustomButton()));
///   await expectLater(
///     find.byType(CustomButton),
///     matchesGoldenFile('goldens/custom_button.png'),
///   );
/// });
/// ```
class RequireGoldenTestRule extends SaropaLintRule {
  const RequireGoldenTestRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_golden_test',
    problemMessage: 'Consider adding golden test for visual verification.',
    correctionMessage: 'Add matchesGoldenFile() for visual regression testing.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String path = resolver.source.fullName;
    if (!path.contains('_test.dart') &&
        !path.contains('/test/') &&
        !path.contains(r'\test\')) return;

    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (methodName != 'testWidgets') return;

      final ArgumentList args = node.argumentList;
      if (args.arguments.isEmpty) return;

      // Get the test name
      final Expression? nameArg = args.arguments.first;
      if (nameArg is! StringLiteral) return;
      final String? testName = nameArg.stringValue?.toLowerCase();
      if (testName == null) return;

      // Check if test name suggests visual testing
      if (testName.contains('ui') ||
          testName.contains('visual') ||
          testName.contains('render') ||
          testName.contains('display') ||
          testName.contains('appearance')) {
        // Check if test has golden assertion
        if (args.arguments.length >= 2) {
          final String bodySource = args.arguments[1].toSource();
          if (!bodySource.contains('matchesGoldenFile') &&
              !bodySource.contains('goldenFileComparator')) {
            reporter.atNode(node.methodName, code);
          }
        }
      }
    });
  }
}

/// Warns when tests contain patterns that cause flakiness.
///
/// Flaky tests fail intermittently, eroding confidence in the test suite.
/// This rule detects common causes of test flakiness.
///
/// **Detected flaky patterns:**
/// - `Random()` without seed (non-deterministic)
/// - `DateTime.now()` (time-dependent)
/// - Hardcoded delays (`Future.delayed` with arbitrary duration)
/// - Real network calls without mocking
/// - File system operations without mocking
///
/// **BAD:**
/// ```dart
/// test('flaky test', () {
///   final random = Random(); // Different results each run
///   final now = DateTime.now(); // Time-dependent
///   await Future.delayed(Duration(milliseconds: 100)); // Arbitrary delay
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// test('deterministic test', () {
///   final random = Random(42); // Seeded for reproducibility
///   final clock = FakeClock(); // Mockable time
///   await tester.pump(Duration(milliseconds: 100)); // Use tester.pump
/// });
/// ```
class AvoidFlakyTestsRule extends SaropaLintRule {
  const AvoidFlakyTestsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_flaky_tests',
    problemMessage: 'Test contains patterns that may cause flakiness.',
    correctionMessage:
        'Use seeded Random, mock time sources, use tester.pump() instead of '
        'Future.delayed, and mock network/file system access.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Patterns that indicate flaky test code.
  ///
  /// These patterns typically cause non-deterministic test behavior:
  /// - Time-dependent: DateTime.now() varies between runs
  /// - Non-deterministic: Random() without seed produces different results
  /// - External dependencies: File/Directory/Network access can fail
  static const Set<String> _flakyPatterns = <String>{
    'DateTime.now()',
    'Random()', // Without seed
    'File(',
    'Directory(',
    'HttpClient(',
    'http.get(',
    'http.post(',
    'dio.get(',
    'dio.post(',
    'Process.run(',
    'Platform.environment',
  };

  /// Patterns that indicate safe mocking or deterministic usage.
  ///
  /// When these patterns are present, we assume the test is properly mocked.
  static const Set<String> _safePatterns = <String>{
    'Mock',
    'mock',
    'Fake',
    'fake',
    'fakeAsync',
    'FakeClock',
    'MockClient',
    'clock.',
    'withClock',
    'TestWidgetsFlutterBinding',
  };

  /// Regex to detect seeded Random (any numeric seed is acceptable)
  static final RegExp _seededRandomPattern = RegExp(r'Random\(\s*\d');

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Only check test files (handle both Unix / and Windows \ paths)
    final String path = resolver.source.fullName;
    final bool isTestFile = path.contains('_test.dart') ||
        path.contains('/test/') ||
        path.contains(r'\test\');
    if (!isTestFile) return;

    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Only check test() and testWidgets() functions
      if (methodName != 'test' && methodName != 'testWidgets') return;

      final ArgumentList args = node.argumentList;
      if (args.arguments.length < 2) return;

      // Get the test body
      final Expression bodyArg = args.arguments[1];
      final String bodySource = bodyArg.toSource();

      // Skip if test has safe patterns (mocking in place)
      for (final String safePattern in _safePatterns) {
        if (bodySource.contains(safePattern)) {
          return; // Test appears to use mocking
        }
      }

      // Skip if Random is seeded (deterministic)
      if (bodySource.contains('Random(') &&
          _seededRandomPattern.hasMatch(bodySource)) {
        // Has seeded Random, check other patterns
        final bool hasOtherFlaky = _flakyPatterns
            .where((p) => p != 'Random()')
            .any((p) => bodySource.contains(p));
        if (!hasOtherFlaky) return;
      }

      // Check for flaky patterns
      for (final String flakyPattern in _flakyPatterns) {
        if (bodySource.contains(flakyPattern)) {
          // Special case: Random() is only flaky if not seeded
          if (flakyPattern == 'Random()' &&
              _seededRandomPattern.hasMatch(bodySource)) {
            continue;
          }
          reporter.atNode(node.methodName, code);
          return; // Report once per test
        }
      }

      // Check for Future.delayed without pump (common flaky pattern)
      if (bodySource.contains('Future.delayed') &&
          !bodySource.contains('pump') &&
          !bodySource.contains('fakeAsync')) {
        reporter.atNode(node.methodName, code);
      }
    });
  }
}
