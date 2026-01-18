// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

// =============================================================================
// v4.1.7 Rules - Testing Best Practices
// =============================================================================

/// Warns when dialog tests don't handle special testing requirements.
///
/// Dialogs require special handling: tap to open, find within dialog
/// context, test dismiss behavior. Don't forget barrier dismiss tests.
///
/// **BAD:**
/// ```dart
/// testWidgets('shows dialog', (tester) async {
///   await tester.pumpWidget(MyApp());
///   await tester.tap(find.byType(ElevatedButton));
///   // Missing pump for dialog animation!
///   expect(find.text('Dialog Title'), findsOneWidget);
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// testWidgets('shows dialog', (tester) async {
///   await tester.pumpWidget(MyApp());
///   await tester.tap(find.byType(ElevatedButton));
///   await tester.pumpAndSettle(); // Wait for dialog animation
///   expect(find.text('Dialog Title'), findsOneWidget);
///
///   // Test barrier dismiss
///   await tester.tapAt(Offset.zero);
///   await tester.pumpAndSettle();
/// });
/// ```
class RequireDialogTestsRule extends SaropaLintRule {
  const RequireDialogTestsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.test};

  static const LintCode _code = LintCode(
    name: 'require_dialog_tests',
    problemMessage:
        '[require_dialog_tests] Dialog test may be incomplete. Ensure pumpAndSettle after showing dialog.',
    correctionMessage:
        'Add pumpAndSettle() after showing dialog to wait for animations.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      // Check for showDialog calls in tests
      if (node.methodName.name != 'showDialog' &&
          !node.methodName.name.contains('Dialog')) {
        return;
      }

      // Check if inside a test function
      if (!_isInsideTest(node)) return;

      // Look for pumpAndSettle after the dialog
      final AstNode? block = _findContainingBlock(node);
      if (block == null) return;

      final String blockSource = block.toSource();
      final int dialogIndex = blockSource.indexOf(node.toSource());

      // Check if pumpAndSettle comes after showDialog
      final String afterDialog = blockSource.substring(dialogIndex);
      if (!afterDialog.contains('pumpAndSettle')) {
        reporter.atNode(node, code);
      }
    });
  }

  bool _isInsideTest(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is MethodInvocation) {
        final String name = current.methodName.name;
        if (name == 'testWidgets' || name == 'test' || name == 'testGoldens') {
          return true;
        }
      }
      current = current.parent;
    }
    return false;
  }

  AstNode? _findContainingBlock(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is Block) return current;
      current = current.parent;
    }
    return null;
  }
}

/// Warns when platform channels are used without fakes in tests.
///
/// Platform channels (camera, GPS, storage) need fakes in tests.
/// Use `TestDefaultBinaryMessengerBinding` to mock platform responses.
///
/// **BAD:**
/// ```dart
/// testWidgets('camera test', (tester) async {
///   await tester.pumpWidget(CameraWidget());
///   // Platform channel will fail in test!
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// testWidgets('camera test', (tester) async {
///   TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
///       .setMockMethodCallHandler(channel, (call) async => mockResponse);
///   await tester.pumpWidget(CameraWidget());
/// });
/// ```
class PreferFakePlatformRule extends SaropaLintRule {
  const PreferFakePlatformRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.test};

  static const LintCode _code = LintCode(
    name: 'prefer_fake_platform',
    problemMessage:
        '[prefer_fake_platform] Platform-dependent widget in test without mock.',
    correctionMessage:
        'Use TestDefaultBinaryMessengerBinding to mock platform channel responses.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _platformWidgets = {
    'CameraPreview',
    'Camera',
    'ImagePicker',
    'FilePicker',
    'LocationWidget',
    'MapView',
    'GoogleMap',
    'WebView',
    'InAppWebView',
    'VideoPlayer',
    'AudioPlayer',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final String constructorName = node.constructorName.type.name2.lexeme;

      if (!_platformWidgets.contains(constructorName)) return;

      // Check if inside a test
      if (!_isInsideTest(node)) return;

      // Check if there's mock setup in the test
      final AstNode? testBlock = _findTestBlock(node);
      if (testBlock == null) return;

      final String testSource = testBlock.toSource();
      if (!testSource.contains('setMockMethodCallHandler') &&
          !testSource.contains('TestDefaultBinaryMessengerBinding') &&
          !testSource.contains('MockPlatform') &&
          !testSource.contains('FakePlatform')) {
        reporter.atNode(node, code);
      }
    });
  }

  bool _isInsideTest(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is MethodInvocation) {
        final String name = current.methodName.name;
        if (name == 'testWidgets' || name == 'test') {
          return true;
        }
      }
      current = current.parent;
    }
    return false;
  }

  AstNode? _findTestBlock(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is FunctionExpression) {
        final AstNode? parent = current.parent;
        if (parent is ArgumentList) {
          final AstNode? invocation = parent.parent;
          if (invocation is MethodInvocation) {
            final String name = invocation.methodName.name;
            if (name == 'testWidgets' || name == 'test') {
              return current.body;
            }
          }
        }
      }
      current = current.parent;
    }
    return null;
  }
}

/// Warns when complex tests lack documentation.
///
/// `[HEURISTIC]` - Detects long tests without comments.
///
/// Complex integration tests with unusual setup or assertions need
/// comments explaining the test scenario and why it matters.
///
/// **BAD:**
/// ```dart
/// testWidgets('complex scenario', (tester) async {
///   await tester.pumpWidget(App());
///   await tester.tap(find.byKey(Key('step1')));
///   await tester.pump(Duration(seconds: 2));
///   await tester.drag(find.byType(ListView), Offset(0, -500));
///   // ... 20 more lines of setup without explanation
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// // Tests the checkout flow when user has expired promo code.
/// // This scenario caused bug #1234 in production.
/// testWidgets('checkout with expired promo', (tester) async {
///   // Setup: User with expired promo code
///   await tester.pumpWidget(App(user: userWithExpiredPromo));
///
///   // Act: Try to apply the expired code
///   await tester.tap(find.byKey(Key('apply_promo')));
///   // ...
/// });
/// ```
class RequireTestDocumentationRule extends SaropaLintRule {
  const RequireTestDocumentationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.test};

  static const LintCode _code = LintCode(
    name: 'require_test_documentation',
    problemMessage:
        '[require_test_documentation] Complex test lacks documentation.',
    correctionMessage:
        'Add comments explaining the test scenario and why it matters.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const int _complexTestThreshold = 15; // lines

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (methodName != 'testWidgets' && methodName != 'test') return;

      // Get the test body
      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.length < 2) return;

      final Expression? testBody = args.length >= 2 ? args[1] : null;
      if (testBody is! FunctionExpression) return;

      final FunctionBody body = testBody.body;
      final String bodySource = body.toSource();

      // Count lines (approximate)
      final int lineCount = bodySource.split('\n').length;

      if (lineCount > _complexTestThreshold) {
        // Check for comments
        final bool hasComments = bodySource.contains('//') ||
            bodySource.contains('/*') ||
            bodySource.contains('///');

        if (!hasComments) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}
