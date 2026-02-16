// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// URL Launcher lint rules for Flutter applications.
///
/// These rules help ensure proper URL launching with pre-checks, fallbacks,
/// and proper test handling on simulators.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../import_utils.dart';
import '../../saropa_lint_rule.dart';

// =============================================================================
// require_url_launcher_can_launch_check
// =============================================================================

/// Warns when launchUrl is called without canLaunchUrl check.
///
/// Since: v4.2.0 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: can_launch_check, url_launcher_check
///
/// Check canLaunchUrl before launchUrl for better error messages. Without this
/// check, launchUrl may fail silently or throw cryptic platform exceptions.
///
/// **BAD:**
/// ```dart
/// await launchUrl(Uri.parse('https://example.com'));
/// await launchUrl(Uri.parse('tel:+1234567890'));
/// ```
///
/// **GOOD:**
/// ```dart
/// final uri = Uri.parse('https://example.com');
/// if (await canLaunchUrl(uri)) {
///   await launchUrl(uri);
/// } else {
///   showError('Could not open link');
/// }
/// ```
class RequireUrlLauncherCanLaunchCheckRule extends SaropaLintRule {
  const RequireUrlLauncherCanLaunchCheckRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_url_launcher_can_launch_check',
    problemMessage:
        '[require_url_launcher_can_launch_check] launchUrl called without canLaunchUrl check. May fail silently on unsupported schemes, confusing users and breaking expected flows. Check canLaunchUrl before launchUrl to improve error messages. Without this check, launchUrl may fail silently or throw cryptic platform exceptions. {v2}',
    correctionMessage:
        'Check canLaunchUrl(uri) before calling launchUrl(uri). Example: if (await canLaunchUrl(uri)) { launchUrl(uri); } else { showError("Could not open link"); }',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check for launchUrl or launch calls
      if (methodName != 'launchUrl' && methodName != 'launch') return;

      // Check if canLaunchUrl is called in the same function
      AstNode? functionBody;
      AstNode? current = node.parent;

      while (current != null) {
        if (current is FunctionBody) {
          functionBody = current;
          break;
        }
        current = current.parent;
      }

      if (functionBody == null) return;

      final String bodySource = functionBody.toSource();

      // Check for canLaunchUrl check
      if (bodySource.contains('canLaunchUrl') ||
          bodySource.contains('canLaunch')) {
        return; // Has the check
      }

      reporter.atNode(node, code);
    });
  }
}

// =============================================================================
// avoid_url_launcher_simulator_tests
// =============================================================================

/// Warns when URL launcher tests may fail on simulator/emulator.
///
/// Since: v4.2.0 | Updated: v4.14.5 | Rule version: v3
///
/// Alias: url_launcher_test, simulator_url_test
///
/// URL schemes like tel:, mailto:, sms: fail on iOS Simulator and Android
/// Emulator because there's no handler app. Skip or mock these tests.
///
/// Only fires when the file imports `url_launcher` AND the test body contains
/// both a problematic scheme string and a launcher API call (`launchUrl`,
/// `canLaunchUrl`, etc.). Pure string/URI tests that happen to use scheme
/// strings are not flagged. Only matches `test()` / `testWidgets()` calls,
/// not `group()`.
///
/// **BAD:**
/// ```dart
/// // File imports url_launcher
/// testWidgets('can make phone call', (tester) async {
///   await launchUrl(Uri.parse('tel:+1234567890'));
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// testWidgets('can make phone call', (tester) async {
///   when(mockUrlLauncher.canLaunch(any)).thenAnswer((_) async => true);
///   await tester.tap(find.byKey(Key('call_button')));
///   verify(mockUrlLauncher.launch('tel:+1234567890'));
/// }, skip: Platform.environment.containsKey('FLUTTER_TEST'));
/// ```
///
/// **Also GOOD** (no url_launcher usage — pure string logic):
/// ```dart
/// test('rejects mailto URLs', () {
///   expect(parseHttpUrl('mailto:test@example.com'), isNull);
/// });
/// ```
class AvoidUrlLauncherSimulatorTestsRule extends SaropaLintRule {
  const AvoidUrlLauncherSimulatorTestsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.test};

  static const LintCode _code = LintCode(
    name: 'avoid_url_launcher_simulator_tests',
    problemMessage:
        '[avoid_url_launcher_simulator_tests] URL launcher test with tel:/mailto:/sms:/facetime:/maps: scheme may fail on simulator. These schemes are not supported in emulators and will cause test failures. {v3}',
    correctionMessage:
        'Mock url_launcher in tests or add skip condition for simulator. Example: skip: !Platform.isAndroid or use a mockUrlLauncher.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _problematicSchemes = <String>{
    'tel:',
    'mailto:',
    'sms:',
    'facetime:',
    'maps:',
  };

  /// Evidence that url_launcher APIs are actually being used.
  static const List<String> _launcherIndicators = <String>[
    'launchUrl',
    'canLaunchUrl',
    'launch(',
    'canLaunch(',
    'url_launcher',
  ];

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Only check test files
    final String filePath = resolver.source.fullName.toLowerCase();
    if (!filePath.contains('_test.dart') && !filePath.contains('/test/')) {
      return;
    }

    context.registry.addMethodInvocation((MethodInvocation node) {
      // Only match individual test calls, not group() which is too coarse
      final String methodName = node.methodName.name;
      if (methodName != 'test' && methodName != 'testWidgets') {
        return;
      }

      // Skip if url_launcher is not imported in this file
      if (!fileImportsPackage(node, PackageImports.urlLauncher)) {
        return;
      }

      // Check the test body for problematic schemes
      final NodeList<Expression> args = node.argumentList.arguments;
      for (final Expression arg in args) {
        if (arg is! FunctionExpression) continue;

        final String bodySource = arg.body.toSource();

        // Must contain a problematic scheme string
        final bool hasScheme = _problematicSchemes.any(
          (scheme) =>
              bodySource.contains("'$scheme") ||
              bodySource.contains('"$scheme'),
        );
        if (!hasScheme) continue;

        // Must also contain launcher API usage
        final bool hasLauncherUsage =
            _launcherIndicators.any(bodySource.contains);
        if (!hasLauncherUsage) continue;

        // Check if there's mocking or skip
        if (bodySource.contains('mock') ||
            bodySource.contains('Mock') ||
            bodySource.contains('when(') ||
            node.toSource().contains('skip:')) {
          return;
        }

        reporter.atNode(node, code);
        return;
      }
    });
  }
}

// =============================================================================
// prefer_url_launcher_fallback
// =============================================================================

/// Warns when URL launcher is used without a fallback for unsupported schemes.
///
/// Since: v4.2.0 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: url_launcher_fallback, handle_launch_failure
///
/// Provide fallback for unsupported schemes. Not all devices support all URL
/// schemes. Show a helpful error or copy to clipboard as fallback.
///
/// **BAD:**
/// ```dart
/// onTap: () => launchUrl(Uri.parse('mailto:support@example.com'))
/// ```
///
/// **GOOD:**
/// ```dart
/// onTap: () async {
///   final uri = Uri.parse('mailto:support@example.com');
///   if (await canLaunchUrl(uri)) {
///     await launchUrl(uri);
///   } else {
///     // Fallback: copy email to clipboard
///     await Clipboard.setData(ClipboardData(text: 'support@example.com'));
///     showSnackBar('Email copied to clipboard');
///   }
/// }
/// ```
class PreferUrlLauncherFallbackRule extends SaropaLintRule {
  const PreferUrlLauncherFallbackRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_url_launcher_fallback',
    problemMessage:
        '[prefer_url_launcher_fallback] launchUrl called without a fallback. If the scheme is unsupported, the user gets no feedback and cannot complete the action. This leads to user frustration and failed actions. {v2}',
    correctionMessage:
        'Provide a fallback action (copy to clipboard, show dialog) when launch fails. Example: if (!await launchUrl(uri)) { showDialog(context: context, builder: (_) => Text("Could not open link")); }',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Schemes that commonly need fallbacks
  static const Set<String> _schemesNeedingFallback = <String>{
    'mailto:',
    'tel:',
    'sms:',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check for launchUrl calls
      if (methodName != 'launchUrl' && methodName != 'launch') return;

      // Check if this is a scheme that commonly needs fallback
      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isEmpty) return;

      final String argSource = args.first.toSource();
      bool needsFallbackScheme = false;

      for (final String scheme in _schemesNeedingFallback) {
        if (argSource.contains("'$scheme") || argSource.contains('"$scheme')) {
          needsFallbackScheme = true;
          break;
        }
      }

      if (!needsFallbackScheme) return;

      // Check for fallback handling
      AstNode? functionBody;
      AstNode? current = node.parent;

      while (current != null) {
        if (current is FunctionBody) {
          functionBody = current;
          break;
        }
        current = current.parent;
      }

      if (functionBody == null) return;

      final String bodySource = functionBody.toSource();

      // Check for fallback patterns
      if (bodySource.contains('else') ||
          bodySource.contains('catch') ||
          bodySource.contains('Clipboard') ||
          bodySource.contains('showSnackBar') ||
          bodySource.contains('showDialog') ||
          bodySource.contains('showError') ||
          bodySource.contains('ScaffoldMessenger') ||
          bodySource.contains('onError') ||
          bodySource.contains('catchError')) {
        return; // Has fallback handling
      }

      reporter.atNode(node, code);
    });
  }
}
