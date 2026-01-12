// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Testing best practices lint rules for Flutter/Dart applications.
///
/// These rules help enforce testing standards and catch common
/// testing anti-patterns.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

/// Warns when test has no assertions.
///
/// Alias: test_needs_assertion, no_assertion_test
///
/// Tests without assertions don't actually verify anything. This rule uses
/// simple string matching on the test body source code for fast detection.
///
/// ## Related Rules
///
/// - **`missing_test_assertion`** (Essential tier): A more sophisticated
///   alternative that uses AST analysis and recognizes user-defined helper
///   functions containing assertions. Use `missing_test_assertion` if you
///   have custom assertion helpers like `expectValid()` or `verifyResult()`.
///
/// ## Detection Approach
///
/// This rule uses string matching to check if the test body contains any
/// calls to known assertion methods. This is faster but less accurate than
/// AST-based analysis - it won't recognize custom assertion helpers.
///
/// ## When to Use Each Rule
///
/// - Use **this rule** (`require_test_assertions`) for simple codebases
///   without custom assertion helpers, or when you want faster analysis.
/// - Use **`missing_test_assertion`** when you have helper functions that
///   wrap assertions, as it will recognize them as valid assertions.
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

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.test};

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
        !path.contains(r'\test\')) {
      return;
    }

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

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.test};

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
        !path.contains(r'\test\')) {
      return;
    }

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
/// Alias: avoid_real_dependencies
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

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.test};

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
        !path.contains(r'\test\')) {
      return;
    }

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

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.test};

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
        !path.contains(r'\test\')) {
      return;
    }

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

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.test};

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
        !path.contains(r'\test\')) {
      return;
    }

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

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.test};

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
        !path.contains(r'\test\')) {
      return;
    }

    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (methodName != 'testWidgets') return;

      final ArgumentList args = node.argumentList;
      if (args.arguments.length < 2) return;

      final Expression? bodyArg =
          args.arguments.length >= 2 ? args.arguments[1] : null;

      if (bodyArg == null) return;

      final String bodySource = bodyArg.toSource();

      // Check for interactions without pumps - track ALL occurrences
      if (_hasInteractionWithoutPump(bodySource)) {
        reporter.atNode(node.methodName, code);
      }
    });
  }

  /// Check if any interaction is followed by expect without an intervening pump.
  /// Tracks all occurrences to avoid false positives from multiple interactions.
  bool _hasInteractionWithoutPump(String bodySource) {
    // Find all interaction positions
    final List<int> interactionPositions = <int>[];
    for (final String interaction in _interactionMethods) {
      final String pattern = 'tester.$interaction';
      int index = 0;
      while ((index = bodySource.indexOf(pattern, index)) != -1) {
        interactionPositions.add(index);
        index += pattern.length;
      }
    }

    if (interactionPositions.isEmpty) return false;

    // Sort positions to process in order
    interactionPositions.sort();

    // For each interaction, check if there's an expect before a pump
    for (int i = 0; i < interactionPositions.length; i++) {
      final int interactionPos = interactionPositions[i];

      // Determine end of search range (next interaction or end of string)
      final int searchEnd = (i + 1 < interactionPositions.length)
          ? interactionPositions[i + 1]
          : bodySource.length;

      final String segment = bodySource.substring(interactionPos, searchEnd);

      // Find first expect and first pump in this segment
      final int expectIndex = segment.indexOf('expect(');
      final int pumpIndex = segment.indexOf('pump');

      // Problem: expect before pump (or no pump at all before expect)
      if (expectIndex != -1 && (pumpIndex == -1 || pumpIndex > expectIndex)) {
        return true;
      }
    }

    return false;
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

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.test};

  static const LintCode _code = LintCode(
    name: 'avoid_production_config_in_tests',
    problemMessage: 'Test may be using production configuration.',
    correctionMessage: 'Use test-specific or mocked configuration.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  // cspell:ignore firebaseio
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
        !path.contains(r'\test\')) {
      return;
    }

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

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.test};

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
        !path.contains(r'\test\')) {
      return;
    }

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

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.test};

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
        !path.contains(r'\test\')) {
      return;
    }

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

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.test};

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
        !path.contains(r'\test\')) {
      return;
    }

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

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.test};

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
        !path.contains(r'\test\')) {
      return;
    }

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

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.test};

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
        !path.contains(r'\test\')) {
      return;
    }

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

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.test};

  static const LintCode _code = LintCode(
    name: 'prefer_mock_navigator',
    problemMessage:
        'Navigator usage in test should be mocked for verification.',
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
        !path.contains(r'\test\')) {
      return;
    }

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

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.test};

  static const LintCode _code = LintCode(
    name: 'avoid_real_timer_in_widget_test',
    problemMessage: 'Avoid using Timer in widget tests.',
    correctionMessage:
        'Use fakeAsync or tester.runAsync for timer-based tests.',
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
        !path.contains(r'\test\')) {
      return;
    }

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

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.test};

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
        !path.contains(r'\test\')) {
      return;
    }

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

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.test};

  static const LintCode _code = LintCode(
    name: 'prefer_matcher_over_equals',
    problemMessage:
        'Use matchers instead of direct equality for better messages.',
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
        !path.contains(r'\test\')) {
      return;
    }

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
      if (actual is PropertyAccess && actual.propertyName.name == 'length') {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when widget tests don't wrap with MaterialApp/Scaffold.
///
/// Most widgets need MaterialApp ancestor for theming and localization.
///
/// **Note:** This rule ignores teardown patterns where simple widgets like
/// `SizedBox`, `Container`, or `Placeholder` are pumped to unmount the
/// widget tree before disposal.
///
/// **Quick fix available:** Wraps the widget with `MaterialApp(home: ...)`.
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
///
/// // Teardown pattern (OK - not flagged):
/// testWidgets('with controller', (tester) async {
///   await tester.pumpWidget(MaterialApp(home: MyWidget()));
///   // ... test ...
///   await tester.pumpWidget(const SizedBox()); // Teardown
///   controller.dispose();
/// });
/// ```
class PreferTestWrapperRule extends SaropaLintRule {
  const PreferTestWrapperRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.test};

  static const LintCode _code = LintCode(
    name: 'prefer_test_wrapper',
    problemMessage: 'Widget test should wrap with MaterialApp/CupertinoApp.',
    correctionMessage:
        'Wrap the widget with MaterialApp(home: Scaffold(body: ...)).',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Simple widgets commonly used for teardown/cleanup in tests.
  static const Set<String> _teardownWidgets = <String>{
    'SizedBox',
    'Container',
    'Placeholder',
    'SizedBox.shrink',
    'SizedBox.expand',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String path = resolver.source.fullName;
    if (!path.contains('_test.dart') &&
        !path.contains('/test/') &&
        !path.contains(r'\test\')) {
      return;
    }

    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (methodName != 'pumpWidget') return;

      final ArgumentList args = node.argumentList;
      if (args.arguments.isEmpty) return;

      final Expression widget = args.arguments.first;
      final String widgetSource = widget.toSource();

      // Skip teardown patterns - simple widgets used to unmount before disposal
      if (_isTeardownWidget(widget)) return;

      // Check if wrapped with MaterialApp or CupertinoApp
      if (!widgetSource.contains('MaterialApp') &&
          !widgetSource.contains('CupertinoApp') &&
          !widgetSource.contains('WidgetsApp')) {
        reporter.atNode(node, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_WrapWithMaterialAppFix()];

  /// Check if this is a simple widget used for teardown/cleanup.
  bool _isTeardownWidget(Expression widget) {
    if (widget is InstanceCreationExpression) {
      final String typeName = widget.constructorName.type.name.lexeme;
      final String? constructorName = widget.constructorName.name?.name;

      // Check for SizedBox(), Container(), Placeholder()
      if (_teardownWidgets.contains(typeName)) return true;

      // Check for SizedBox.shrink(), SizedBox.expand()
      if (constructorName != null) {
        final String fullName = '$typeName.$constructorName';
        if (_teardownWidgets.contains(fullName)) return true;
      }

      // Check if it's an empty/simple widget (no complex children)
      // A teardown widget typically has no arguments or only simple ones
      final args = widget.argumentList.arguments;
      if (args.isEmpty) return true;

      // If only has simple args like width/height, it's likely teardown
      if (typeName == 'SizedBox' || typeName == 'Container') {
        final bool hasOnlySimpleArgs = args.every((arg) {
          if (arg is NamedExpression) {
            final name = arg.name.label.name;
            return name == 'width' ||
                name == 'height' ||
                name == 'key' ||
                name == 'color';
          }
          return false;
        });
        if (hasOnlySimpleArgs) return true;
      }
    }
    return false;
  }
}

/// Quick fix that wraps a widget with MaterialApp(home: ...).
class _WrapWithMaterialAppFix extends DartFix {
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
      if (node.methodName.name != 'pumpWidget') return;

      final ArgumentList args = node.argumentList;
      if (args.arguments.isEmpty) return;

      final Expression widget = args.arguments.first;
      final String widgetSource = widget.toSource();

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Wrap with MaterialApp',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          widget.sourceRange,
          'MaterialApp(home: $widgetSource)',
        );
      });
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

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.test};

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
        !path.contains(r'\test\')) {
      return;
    }

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

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.test};

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
        !path.contains(r'\test\')) {
      return;
    }

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

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.test};

  static const LintCode _code = LintCode(
    name: 'prefer_mock_http',
    problemMessage:
        'Use mock HTTP client in tests instead of real network calls.',
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
        !path.contains(r'\test\')) {
      return;
    }

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
        !path.contains(r'\test\')) {
      return;
    }

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

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.test};

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

/// Warns when a test has multiple assertions testing different behaviors.
///
/// Tests with multiple assertions are harder to debug - you only see the
/// first failure. One logical assertion per test clarifies what broke.
///
/// **BAD:**
/// ```dart
/// test('user operations', () {
///   expect(user.name, 'John');
///   expect(user.age, 30);
///   expect(user.isAdmin, false);
///   expect(user.email, 'john@example.com');
///   expect(user.createdAt, isNotNull);
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// test('user has correct name', () {
///   expect(user.name, 'John');
/// });
///
/// test('user has correct age', () {
///   expect(user.age, 30);
/// });
/// // Or group related assertions:
/// test('user is not admin by default', () {
///   expect(user.isAdmin, false);
///   expect(user.permissions, isEmpty); // Related assertion
/// });
/// ```
class PreferSingleAssertionRule extends SaropaLintRule {
  const PreferSingleAssertionRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.test};

  static const LintCode _code = LintCode(
    name: 'prefer_single_assertion',
    problemMessage:
        'Test has many assertions. Consider splitting into focused tests.',
    correctionMessage:
        'One logical assertion per test makes failures easier to debug.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Threshold for number of expect() calls before warning
  static const int _maxAssertions = 5;

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String path = resolver.source.fullName;
    if (!path.contains('_test.dart') &&
        !path.contains('/test/') &&
        !path.contains(r'\test\')) {
      return;
    }

    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (methodName != 'test' && methodName != 'testWidgets') return;

      final ArgumentList args = node.argumentList;
      if (args.arguments.length < 2) return;

      final String bodySource = args.arguments[1].toSource();

      // Count expect() calls
      final RegExp expectPattern = RegExp(r'\bexpect\s*\(');
      final int expectCount = expectPattern.allMatches(bodySource).length;

      if (expectCount > _maxAssertions) {
        reporter.atNode(node.methodName, code);
      }
    });
  }
}

/// Warns when find.byType() is used without a specific type.
///
/// Using generic finders like find.byType(Text) matches many widgets and
/// makes tests fragile. Use more specific finders.
///
/// **BAD:**
/// ```dart
/// expect(find.byType(Text), findsWidgets); // Matches ALL Text widgets
/// expect(find.byType(Container), findsOneWidget); // Too generic
/// await tester.tap(find.byType(IconButton)); // Which IconButton?
/// ```
///
/// **GOOD:**
/// ```dart
/// expect(find.text('Welcome'), findsOneWidget); // Specific text
/// expect(find.byKey(Key('submit_button')), findsOneWidget); // By key
/// await tester.tap(find.byIcon(Icons.add)); // Specific icon
/// expect(find.byType(MyCustomWidget), findsOneWidget); // Custom widget OK
/// ```
class AvoidFindAllRule extends SaropaLintRule {
  const AvoidFindAllRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.test};

  static const LintCode _code = LintCode(
    name: 'avoid_find_all',
    problemMessage:
        'Generic finder (Text, Container, etc.) matches many widgets. Use specific finder.',
    correctionMessage:
        'Use find.text(), find.byKey(), find.byIcon(), or find your custom widget type.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Generic Flutter widget types that are too broad for reliable testing
  static const Set<String> _genericTypes = <String>{
    'Text',
    'Container',
    'SizedBox',
    'Padding',
    'Center',
    'Column',
    'Row',
    'Expanded',
    'Flexible',
    'Scaffold',
    'AppBar',
    'Icon',
    'IconButton',
    'TextButton',
    'ElevatedButton',
    'Card',
    'ListTile',
    'CircularProgressIndicator',
    'LinearProgressIndicator',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String path = resolver.source.fullName;
    if (!path.contains('_test.dart') &&
        !path.contains('/test/') &&
        !path.contains(r'\test\')) {
      return;
    }

    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (methodName != 'byType') return;

      // Check if target is 'find'
      final Expression? target = node.target;
      if (target is! SimpleIdentifier || target.name != 'find') return;

      // Check the type argument
      final ArgumentList args = node.argumentList;
      if (args.arguments.isEmpty) return;

      final Expression typeArg = args.arguments.first;
      final String typeSource = typeArg.toSource();

      if (_genericTypes.contains(typeSource)) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when integration tests don't initialize the test binding.
///
/// Integration tests need IntegrationTestWidgetsFlutterBinding.ensureInitialized()
/// in main(). Without it, tests hang or crash on device.
///
/// **BAD:**
/// ```dart
/// // integration_test/app_test.dart
/// void main() {
///   testWidgets('app launches', (tester) async {
///     // Hangs on device without binding!
///   });
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// // integration_test/app_test.dart
/// void main() {
///   IntegrationTestWidgetsFlutterBinding.ensureInitialized();
///
///   testWidgets('app launches', (tester) async {
///     // Works correctly
///   });
/// }
/// ```
class RequireIntegrationTestSetupRule extends SaropaLintRule {
  const RequireIntegrationTestSetupRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.test};

  static const LintCode _code = LintCode(
    name: 'require_integration_test_setup',
    problemMessage:
        'Integration test missing IntegrationTestWidgetsFlutterBinding.ensureInitialized().',
    correctionMessage:
        'Add IntegrationTestWidgetsFlutterBinding.ensureInitialized() at start of main().',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String path = resolver.source.fullName;

    // Only check files in integration_test directory
    if (!path.contains('integration_test') &&
        !path.contains(r'integration_test\')) {
      return;
    }

    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
      if (node.name.lexeme != 'main') return;

      final String bodySource = node.functionExpression.body.toSource();

      // Check for the complete binding initialization pattern
      if (!bodySource.contains('IntegrationTestWidgetsFlutterBinding')) {
        reporter.atToken(node.name, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddIntegrationTestBindingFix()];
}

class _AddIntegrationTestBindingFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;
      if (node.name.lexeme != 'main') return;

      final FunctionBody body = node.functionExpression.body;
      if (body is! BlockFunctionBody) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add IntegrationTestWidgetsFlutterBinding.ensureInitialized()',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          body.block.leftBracket.end,
          '\n  IntegrationTestWidgetsFlutterBinding.ensureInitialized();\n',
        );
      });
    });
  }
}

/// Warns when Future.delayed is used with hardcoded duration in tests.
///
/// Hardcoded delays are flaky - too short and tests fail intermittently,
/// too long and tests waste time. Use pumpAndSettle() or wait for conditions.
///
/// **BAD:**
/// ```dart
/// testWidgets('shows loading', (tester) async {
///   await tester.pumpWidget(MyApp());
///   await Future.delayed(Duration(seconds: 2)); // Flaky!
///   expect(find.byType(LoadingIndicator), findsNothing);
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// testWidgets('shows loading', (tester) async {
///   await tester.pumpWidget(MyApp());
///   await tester.pumpAndSettle(); // Waits for animations
///   expect(find.byType(LoadingIndicator), findsNothing);
/// });
/// // Or wait for specific condition:
/// await tester.pumpUntil(() => find.byType(LoadingIndicator).evaluate().isEmpty);
/// ```
class AvoidHardcodedDelaysRule extends SaropaLintRule {
  const AvoidHardcodedDelaysRule() : super(code: _code);

  /// Hardcoded delays cause flaky tests on slower machines.
  /// Tests may fail intermittently in CI environments.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.test};

  static const LintCode _code = LintCode(
    name: 'avoid_hardcoded_delays',
    problemMessage:
        'Hardcoded delay in test is flaky. Use pumpAndSettle() instead.',
    correctionMessage:
        'Replace Future.delayed with tester.pumpAndSettle() or condition-based waiting.',
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
        !path.contains(r'\test\')) {
      return;
    }

    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'delayed') return;

      final Expression? target = node.target;
      if (target is! SimpleIdentifier) return;
      if (target.name != 'Future') return;

      reporter.atNode(node, code);
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddPumpAndSettleTodoFix()];
}

class _AddPumpAndSettleTodoFix extends DartFix {
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
      if (node.methodName.name != 'delayed') return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add HACK: Replace with tester.pumpAndSettle()',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// HACK: Replace Future.delayed with await tester.pumpAndSettle()\n      ',
        );
      });
    });
  }
}

/// Warns when test files don't include error case tests.
///
/// Happy path tests are insufficient. Tests should verify that errors are
/// thrown for invalid input, network failures, and permission denials.
///
/// **BAD:**
/// ```dart
/// // user_service_test.dart
/// void main() {
///   test('login returns user', () async {
///     final user = await service.login('valid@email.com', 'password');
///     expect(user.name, isNotEmpty);
///   });
///   // No tests for invalid credentials, network errors, etc.
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void main() {
///   test('login returns user', () async {
///     final user = await service.login('valid@email.com', 'password');
///     expect(user.name, isNotEmpty);
///   });
///
///   test('login throws on invalid credentials', () async {
///     expect(
///       () => service.login('invalid@email.com', 'wrong'),
///       throwsA(isA<AuthException>()),
///     );
///   });
///
///   test('login throws on network error', () async {
///     mockNetwork.simulateError();
///     expect(() => service.login('a@b.com', 'p'), throwsA(isA<NetworkException>()));
///   });
/// }
/// ```
class RequireErrorCaseTestsRule extends SaropaLintRule {
  const RequireErrorCaseTestsRule() : super(code: _code);

  /// Tests without error cases miss important edge cases.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.test};

  static const LintCode _code = LintCode(
    name: 'require_error_case_tests',
    problemMessage:
        'Test file has no error case tests. Consider adding tests for exceptions.',
    correctionMessage:
        'Add tests using throwsA(), throwsException, or expect(..., isA<Exception>()).',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String path = resolver.source.fullName;

    // Only check test files
    if (!path.contains('_test.dart') &&
        !path.contains('/test/') &&
        !path.contains(r'\test\')) {
      return;
    }

    // Track whether this file has any error case assertions
    bool hasErrorCaseTest = false;
    FunctionDeclaration? mainFunction;

    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
      if (node.name.lexeme == 'main') {
        mainFunction = node;
      }
    });

    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check for error-related test patterns
      if (methodName == 'throwsA' ||
          methodName == 'throwsException' ||
          methodName == 'throwsArgumentError' ||
          methodName == 'throwsStateError' ||
          methodName == 'throwsFormatException' ||
          methodName == 'throwsUnsupportedError' ||
          methodName == 'throwsNoSuchMethodError' ||
          methodName == 'throwsRangeError') {
        hasErrorCaseTest = true;
        return;
      }

      // Check for expect with isA<*Exception>
      if (methodName == 'expect') {
        final String source = node.toSource();
        if (source.contains('isA<') && source.contains('Exception') ||
            source.contains('isA<') && source.contains('Error') ||
            source.contains('throwsA')) {
          hasErrorCaseTest = true;
          return;
        }
      }

      // Check for test names that suggest error testing
      if (methodName == 'test' || methodName == 'testWidgets') {
        final ArgumentList args = node.argumentList;
        if (args.arguments.isNotEmpty) {
          final String firstArg = args.arguments.first.toSource().toLowerCase();
          if (firstArg.contains('throw') ||
              firstArg.contains('error') ||
              firstArg.contains('fail') ||
              firstArg.contains('invalid') ||
              firstArg.contains('exception')) {
            hasErrorCaseTest = true;
          }
        }
      }
    });

    // Use a post-analysis callback to check if we found any error tests
    context.addPostRunCallback(() {
      if (!hasErrorCaseTest && mainFunction != null) {
        reporter.atToken(mainFunction!.name, code);
      }
    });
  }
}

// =============================================================================
// ROADMAP_NEXT: Phase 3 - Testing Best Practices
// =============================================================================

/// Warns when find.byType is used instead of find.byKey in widget tests.
///
/// Alias: find_by_key, widget_test_key, prefer_key_finder
///
/// Using find.byType can be fragile when widget structure changes.
/// Using find.byKey with ValueKey or Key is more reliable and explicit.
///
/// **BAD:**
/// ```dart
/// testWidgets('button test', (tester) async {
///   await tester.pumpWidget(MyApp());
///   final button = find.byType(ElevatedButton); // Fragile
///   await tester.tap(button);
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// testWidgets('button test', (tester) async {
///   await tester.pumpWidget(MyApp());
///   final button = find.byKey(const Key('submit_button'));
///   await tester.tap(button);
/// });
/// ```
class PreferTestFindByKeyRule extends SaropaLintRule {
  const PreferTestFindByKeyRule() : super(code: _code);

  /// Test quality improvement.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.test};

  static const LintCode _code = LintCode(
    name: 'prefer_test_find_by_key',
    problemMessage:
        'find.byType is fragile. Consider using find.byKey for reliable widget testing.',
    correctionMessage:
        'Add a Key to your widget and use find.byKey(Key(\'my_key\')) instead.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String path = resolver.path;

    // Only check test files
    if (!path.endsWith('_test.dart') &&
        !path.contains('/test/') &&
        !path.contains(r'\test\')) {
      return;
    }

    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'byType') return;

      final Expression? target = node.target;
      if (target is! SimpleIdentifier) return;
      if (target.name != 'find') return;

      reporter.atNode(node, code);
    });
  }
}

/// Warns when test setup code is duplicated instead of using setUp/tearDown.
///
/// Alias: setup_teardown, test_setup, dry_tests
///
/// Repeated setup code in tests violates DRY and makes maintenance harder.
/// Use setUp() and tearDown() for common test initialization.
///
/// **BAD:**
/// ```dart
/// test('test 1', () {
///   final controller = StreamController<int>();
///   final service = MyService(controller);
///   // test logic
///   controller.close();
/// });
///
/// test('test 2', () {
///   final controller = StreamController<int>();
///   final service = MyService(controller);
///   // test logic
///   controller.close();
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// late StreamController<int> controller;
/// late MyService service;
///
/// setUp(() {
///   controller = StreamController<int>();
///   service = MyService(controller);
/// });
///
/// tearDown(() {
///   controller.close();
/// });
///
/// test('test 1', () { /* test logic */ });
/// test('test 2', () { /* test logic */ });
/// ```
class PreferSetupTeardownRule extends SaropaLintRule {
  const PreferSetupTeardownRule() : super(code: _code);

  /// Test quality improvement.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.test};

  static const LintCode _code = LintCode(
    name: 'prefer_setup_teardown',
    problemMessage:
        'Duplicated test setup code. Consider using setUp()/tearDown().',
    correctionMessage:
        'Move common initialization to setUp() and cleanup to tearDown().',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String path = resolver.path;

    // Only check test files
    if (!path.endsWith('_test.dart') &&
        !path.contains('/test/') &&
        !path.contains(r'\test\')) {
      return;
    }

    context.registry.addCompilationUnit((CompilationUnit unit) {
      // Find all test() calls in the file
      final List<MethodInvocation> testCalls = [];
      unit.accept(_TestCallCollector(testCalls));

      if (testCalls.length < 2) return;

      // Extract the first statements from each test
      final Map<String, int> firstStatementCounts = <String, int>{};

      for (final testCall in testCalls) {
        final callback = _getTestCallback(testCall);
        if (callback == null) continue;

        final body = callback.body;
        if (body is! BlockFunctionBody) continue;

        final statements = body.block.statements;
        if (statements.isEmpty) continue;

        // Get first 1-2 statements as setup signature
        final setupSignature = statements
            .take(2)
            .map((s) => s.toSource().replaceAll(RegExp(r'\s+'), ' '))
            .join(';');

        firstStatementCounts[setupSignature] =
            (firstStatementCounts[setupSignature] ?? 0) + 1;
      }

      // If any setup pattern appears 3+ times, suggest setUp()
      for (final entry in firstStatementCounts.entries) {
        if (entry.value >= 3) {
          // Report on the first test with duplicated setup
          for (final testCall in testCalls) {
            final callback = _getTestCallback(testCall);
            if (callback == null) continue;

            final body = callback.body;
            if (body is! BlockFunctionBody) continue;

            final statements = body.block.statements;
            if (statements.isEmpty) continue;

            final setupSignature = statements
                .take(2)
                .map((s) => s.toSource().replaceAll(RegExp(r'\s+'), ' '))
                .join(';');

            if (setupSignature == entry.key) {
              reporter.atNode(testCall, code);
              break;
            }
          }
          break;
        }
      }
    });
  }

  FunctionExpression? _getTestCallback(MethodInvocation testCall) {
    final args = testCall.argumentList.arguments;
    if (args.length < 2) return null;

    final callback = args[1];
    if (callback is FunctionExpression) {
      return callback;
    }
    return null;
  }
}

class _TestCallCollector extends RecursiveAstVisitor<void> {
  _TestCallCollector(this.testCalls);

  final List<MethodInvocation> testCalls;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final name = node.methodName.name;
    if (name == 'test' || name == 'testWidgets') {
      testCalls.add(node);
    }
    super.visitMethodInvocation(node);
  }
}

/// Warns when test descriptions don't follow conventions.
///
/// Alias: test_description, test_naming_convention, descriptive_test
///
/// Test descriptions should explain WHAT is being tested and WHAT the
/// expected behavior is. This helps with test maintenance and debugging.
///
/// **BAD:**
/// ```dart
/// test('test', () { });
/// test('works', () { });
/// test('UserService', () { });
/// ```
///
/// **GOOD:**
/// ```dart
/// test('should return empty list when no users exist', () { });
/// test('throws ArgumentError when input is null', () { });
/// test('UserService.getById returns user with matching id', () { });
/// ```
class RequireTestDescriptionConventionRule extends SaropaLintRule {
  const RequireTestDescriptionConventionRule() : super(code: _code);

  /// Test quality improvement.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.test};

  static const LintCode _code = LintCode(
    name: 'require_test_description_convention',
    problemMessage:
        'Test description should explain what is being tested and expected behavior.',
    correctionMessage:
        'Use format: "should [action] when [condition]" or "[Subject].[method] [expectation]".',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Words that indicate a good test description.
  static const Set<String> _goodDescriptionWords = <String>{
    'should',
    'returns',
    'throws',
    'when',
    'given',
    'expect',
    'creates',
    'updates',
    'deletes',
    'validates',
    'fails',
    'succeeds',
    'handles',
    'emits',
    'navigates',
    'renders',
    'displays',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final name = node.methodName.name;
      if (name != 'test' && name != 'testWidgets') return;

      final args = node.argumentList.arguments;
      if (args.isEmpty) return;

      final firstArg = args.first;
      if (firstArg is! StringLiteral) return;

      final description = firstArg.stringValue?.toLowerCase() ?? '';

      // Check if description has any good indicator words
      final hasGoodWord =
          _goodDescriptionWords.any((word) => description.contains(word));

      // Check minimum length (should be descriptive)
      final isTooShort = description.length < 15;

      // Check if it's just a class name or method name (single word, PascalCase)
      final isSingleWord =
          !description.contains(' ') && !description.contains('.');

      if (!hasGoodWord && (isTooShort || isSingleWord)) {
        reporter.atNode(firstArg, code);
      }
    });
  }
}

/// Warns when Bloc is tested without bloc_test package.
///
/// Alias: bloc_test, bloc_testing, use_bloc_test
///
/// The bloc_test package provides `blocTest()` which is specifically designed
/// for testing Blocs with better state and event assertions.
///
/// **BAD:**
/// ```dart
/// test('emits states', () async {
///   final bloc = MyBloc();
///   bloc.add(MyEvent());
///   await expectLater(
///     bloc.stream,
///     emitsInOrder([State1(), State2()]),
///   );
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// blocTest<MyBloc, MyState>(
///   'emits [State1, State2] when MyEvent is added',
///   build: () => MyBloc(),
///   act: (bloc) => bloc.add(MyEvent()),
///   expect: () => [State1(), State2()],
/// );
/// ```
class PreferBlocTestPackageRule extends SaropaLintRule {
  const PreferBlocTestPackageRule() : super(code: _code);

  /// Test quality improvement.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.test};

  static const LintCode _code = LintCode(
    name: 'prefer_bloc_test_package',
    problemMessage:
        'Consider using blocTest() from bloc_test package for Bloc testing.',
    correctionMessage:
        'Add bloc_test to dev_dependencies and use blocTest<Bloc, State>().',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String path = resolver.path;

    // Only check test files
    if (!path.endsWith('_test.dart') &&
        !path.contains('/test/') &&
        !path.contains(r'\test\')) {
      return;
    }

    context.registry.addMethodInvocation((MethodInvocation node) {
      // Check for test() containing bloc.add() pattern
      if (node.methodName.name != 'test' && node.methodName.name != 'group') {
        return;
      }

      final source = node.toSource();

      // Check for Bloc testing patterns without blocTest
      if ((source.contains('.add(') || source.contains('.emit(')) &&
          (source.contains('Bloc') || source.contains('Cubit')) &&
          !source.contains('blocTest')) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when mock verify() is not used to check method calls.
///
/// Alias: mock_verify, verify_mock_calls, mockito_verify
///
/// Using verify() ensures that expected method calls actually happened.
/// Without verification, tests may pass even when methods aren't called.
///
/// **BAD:**
/// ```dart
/// test('saves user', () async {
///   final mockRepo = MockUserRepository();
///   when(mockRepo.save(any)).thenAnswer((_) async => true);
///
///   final service = UserService(mockRepo);
///   await service.createUser(User());
///   // No verification that save was called!
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// test('saves user', () async {
///   final mockRepo = MockUserRepository();
///   when(mockRepo.save(any)).thenAnswer((_) async => true);
///
///   final service = UserService(mockRepo);
///   await service.createUser(User());
///
///   verify(mockRepo.save(any)).called(1);
/// });
/// ```
class PreferMockVerifyRule extends SaropaLintRule {
  const PreferMockVerifyRule() : super(code: _code);

  /// Test quality improvement.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.test};

  static const LintCode _code = LintCode(
    name: 'prefer_mock_verify',
    problemMessage:
        'Mock setup with when() but no verify(). Test may pass without calling mock.',
    correctionMessage:
        'Add verify(mock.method()).called(n) to ensure method was called.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String path = resolver.path;

    // Only check test files
    if (!path.endsWith('_test.dart') &&
        !path.contains('/test/') &&
        !path.contains(r'\test\')) {
      return;
    }

    context.registry.addMethodInvocation((MethodInvocation node) {
      // Find test() calls
      final name = node.methodName.name;
      if (name != 'test' && name != 'testWidgets') return;

      final source = node.toSource();

      // Check for when() setup without verify()
      if (source.contains('when(') &&
          (source.contains('.thenReturn') || source.contains('.thenAnswer')) &&
          !source.contains('verify(') &&
          !source.contains('verifyNever(') &&
          !source.contains('verifyInOrder(')) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when catch blocks don't log errors.
///
/// Alias: error_logging, catch_logging, log_exceptions
///
/// Errors caught without logging are hard to debug. At minimum, log the
/// error for debugging purposes.
///
/// **BAD:**
/// ```dart
/// try {
///   await api.fetchData();
/// } catch (e) {
///   // Silent failure - no logging!
///   return null;
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// try {
///   await api.fetchData();
/// } catch (e, stackTrace) {
///   log.error('Failed to fetch data', error: e, stackTrace: stackTrace);
///   return null;
/// }
/// ```
class RequireErrorLoggingRule extends SaropaLintRule {
  const RequireErrorLoggingRule() : super(code: _code);

  /// Error handling improvement.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.test};

  static const LintCode _code = LintCode(
    name: 'require_error_logging',
    problemMessage:
        'Caught error without logging. Silent failures are hard to debug.',
    correctionMessage:
        'Add logging: log.error(\'message\', error: e, stackTrace: s);',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Patterns that indicate error logging.
  static const Set<String> _loggingPatterns = <String>{
    'log.',
    'logger.',
    'print(',
    'debugPrint(',
    'Log.',
    'Logger.',
    'logging.',
    'crashlytics',
    'Crashlytics',
    'sentry',
    'Sentry',
    'FirebaseCrashlytics',
    'recordError',
    'reportError',
    'captureException',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCatchClause((CatchClause node) {
      final body = node.body;
      final String bodySource = body.toSource();

      // Check if the catch block has any logging
      final hasLogging = _loggingPatterns.any(
        (pattern) => bodySource.contains(pattern),
      );

      // Check if it's a rethrow (which is fine)
      final hasRethrow =
          bodySource.contains('rethrow') || bodySource.contains('throw ');

      // Check if it's intentionally ignoring specific errors
      final isIntentionalIgnore = bodySource.contains('// ignore') ||
          bodySource.contains('// expected') ||
          bodySource.contains('// intentional');

      // Check if body is empty or just returns
      final isMinimalBody = body.statements.isEmpty ||
          (body.statements.length == 1 && body.statements.first is ReturnStatement);

      if (!hasLogging && !hasRethrow && !isIntentionalIgnore && isMinimalBody) {
        reporter.atNode(node, code);
      }
    });
  }
}
