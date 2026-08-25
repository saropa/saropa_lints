// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// webview_flutter pre-v4 migration lint rules.
///
/// This file ships exactly ONE rule: `avoid_pre_v4_webview_widget`.
///
/// The original plan included five additional correctness/security rules for
/// v4 usage patterns, but all five were DROPPED during 2026-06-11 validation:
///   - webview_flutter_unrestricted_js   → duplicate of avoid_webview_javascript_enabled
///                                         + prefer_webview_javascript_disabled
///                                         (security_network_input_rules.dart)
///   - webview_flutter_missing_navigation_delegate → duplicate of
///                                         require_webview_navigation_delegate
///                                         (widget_patterns_require_rules.dart:1944)
///   - webview_flutter_cleartext_load_request → duplicate of require_https_only /
///                                         checkHttpUrls (same localhost exemptions)
///   - webview_flutter_javascript_channel_no_origin_comment → comment-presence
///                                         check too weak; guard needed
///   - webview_flutter_wildcard_post_message → postWebMessage lives in
///                                         platform-specific packages, not the
///                                         cross-platform surface; not detectable
///
/// The migration rule is gated to `webview_flutter < 4.0.0` via the
/// `webview_flutter_4` rule-pack dependency gate (pre-upgrade readiness
/// archetype). Saropa Contacts ships ^4.13.1 — already migrated; this rule
/// serves users still on v3.x.
library;

import 'package:analyzer/dart/ast/ast.dart';

import '../../import_utils.dart';
import '../../saropa_lint_rule.dart';

// =============================================================================
// avoid_pre_v4_webview_widget
// =============================================================================

/// Flags use of the removed `WebView` widget in a file importing
/// `package:webview_flutter`.
///
/// Since: v4.17.0 | Rule version: v1
///
/// `WebView` (the monolithic widget from webview_flutter v3.x) was removed in
/// v4.0.0. Code still constructing `WebView(...)` will not compile after the
/// upgrade. The v4 replacement is a two-part pattern: create a
/// `WebViewController` (configure it with `loadRequest`, `setJavaScriptMode`,
/// `setNavigationDelegate`, etc.) and pass it to `WebViewWidget(controller: ...)`.
/// The controller-extraction rewrite is structural and cannot be automated; the
/// rule is report-only.
///
/// Detection is import-gated on `package:webview_flutter/` and matches the
/// constructor-name token `WebView` exactly — `WebViewWidget` is NOT matched,
/// so v4 code is never flagged.
///
/// **BAD:**
/// ```dart
/// import 'package:webview_flutter/webview_flutter.dart';
///
/// class MyPage extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     // LINT: avoid_pre_v4_webview_widget
///     return WebView(initialUrl: 'https://flutter.dev');
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// import 'package:webview_flutter/webview_flutter.dart';
///
/// class MyPage extends StatefulWidget { /* ... */ }
///
/// class _MyPageState extends State<MyPage> {
///   late final WebViewController _controller;
///
///   @override
///   void initState() {
///     super.initState();
///     _controller = WebViewController()
///       ..loadRequest(Uri.parse('https://flutter.dev'));
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return WebViewWidget(controller: _controller);
///   }
/// }
/// ```
///
/// See the [v4 migration guide](https://pub.dev/packages/webview_flutter/changelog).
class AvoidPreV4WebviewWidgetRule extends SaropaLintRule {
  AvoidPreV4WebviewWidgetRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  // The 'WebView' constructor name — only matched when it is NOT 'WebViewWidget'
  // or any other class. The import gate ensures this name collision (e.g., a
  // project-local WebView class) does not produce false positives outside files
  // that import webview_flutter.
  static const Set<String> _requiredPatterns = <String>{'WebView'};

  @override
  Set<String>? get requiredPatterns => _requiredPatterns;

  static const LintCode _code = LintCode(
    'avoid_pre_v4_webview_widget',
    '[avoid_pre_v4_webview_widget] The WebView widget was removed in webview_flutter 4.0.0. '
        'Code constructing WebView(...) will not compile after upgrading from v3.x to v4.x. '
        'The v4 replacement is a two-step pattern: (1) create a WebViewController and '
        'configure it (loadRequest, setJavaScriptMode, setNavigationDelegate, etc.), then '
        '(2) render WebViewWidget(controller: controller). This structural change cannot be '
        'automated — see https://pub.dev/packages/webview_flutter/changelog for the v4 '
        'migration guide. Gate: webview_flutter < 4.0.0 (pre-upgrade readiness). {v1}',
    correctionMessage:
        'Replace WebView(...) with WebViewController + WebViewWidget(controller: ...). '
        'Create the controller, call loadRequest() on it, then pass it to WebViewWidget.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      // Import gate: only flag files that import webview_flutter, preventing
      // false positives from unrelated WebView classes in non-webview projects.
      if (!fileImportsPackage(node, PackageImports.webviewFlutter)) return;

      // Match the constructor's named type exactly. 'WebView' is the removed
      // widget; 'WebViewWidget' is the v4 replacement and must NOT be flagged.
      // Syntactic name matching (not resolved element) keeps this rule working
      // under the scan CLI, which does not always resolve elements.
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'WebView') return;

      reporter.atNode(node);
    });
  }
}

/// Warns when WebView lacks SSL error handling callback.
///
/// Since: v2.2.0 | Updated: v4.13.0 | Rule version: v4
///
/// Alias: webview_ssl_handler, require_ssl_error_callback
///
/// Without SSL error handling, WebView may silently fail on certificate issues
/// or allow insecure connections without user awareness.
///
/// **Note:** This rule supports both the legacy WebView constructor pattern
/// and the modern webview_flutter 4.0+ NavigationDelegate pattern.
///
/// **BAD (Legacy):**
/// ```dart
/// WebView(
///   initialUrl: 'https://example.com',
/// )
/// ```
///
/// **GOOD (Legacy):**
/// ```dart
/// WebView(
///   initialUrl: 'https://example.com',
///   onSslError: (controller, error) {
///     // Handle SSL error appropriately
///   },
/// )
/// ```
///
/// **BAD (Modern webview_flutter 4.0+):**
/// ```dart
/// NavigationDelegate()
/// ```
///
/// **GOOD (Modern webview_flutter 4.0+):**
/// ```dart
/// NavigationDelegate(
///   onSslAuthError: (SslAuthError error) async {
///     // Handle SSL certificate error - call error.cancel() or error.proceed()
///     await error.cancel();
///   },
/// )
/// ```
class RequireWebviewSslErrorHandlingRule extends SaropaLintRule {
  RequireWebviewSslErrorHandlingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.error;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_webview_ssl_error_handling',
    '[require_webview_ssl_error_handling] If your WebView does not handle SSL certificate errors, it may silently accept invalid or malicious certificates, exposing users to man-in-the-middle attacks. Users may unknowingly submit sensitive information (such as passwords or payment details) to attackers, resulting in account compromise, data theft, or financial loss. Proper SSL error handling is essential for secure in-app browsing. {v4}',
    correctionMessage:
        'Implement an onSslAuthError callback in your WebView’s NavigationDelegate to detect and handle certificate errors. Warn users about invalid certificates, block navigation to untrusted sites, and log incidents for further review. Test your WebView implementation with both valid and invalid certificates to ensure robust SSL error handling.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;

      // Check for legacy WebView/InAppWebView constructors
      if (typeName == 'WebView' || typeName == 'InAppWebView') {
        final bool hasOnSslError = node.argumentList.arguments.any((arg) {
          if (arg is NamedExpression) {
            final String name = arg.name.label.name;
            return name == 'onSslError' ||
                name == 'onReceivedServerTrustAuthRequest';
          }
          return false;
        });

        if (!hasOnSslError) {
          reporter.atNode(node);
        }
        return;
      }

      // Check for modern webview_flutter 4.0+ NavigationDelegate pattern
      // Note: The correct callback is `onSslAuthError` (not `onSslError` which doesn't exist).
      // `onHttpAuthRequest` is for HTTP Basic/Digest auth (401 challenges), NOT SSL errors.
      // See: https://pub.dev/documentation/webview_flutter/latest/webview_flutter/NavigationDelegate-class.html
      if (typeName == 'NavigationDelegate') {
        final bool hasOnSslError = node.argumentList.arguments.any((arg) {
          if (arg is NamedExpression) {
            final String name = arg.name.label.name;
            return name == 'onSslAuthError';
          }
          return false;
        });

        if (!hasOnSslError) {
          reporter.atNode(node);
        }
      }
    });
  }
}

/// Warns when WebView has file access enabled.
///
/// Since: v2.2.0 | Updated: v4.13.0 | Rule version: v3
///
/// Alias: webview_no_file_access, disable_webview_file_access
///
/// Enabling file access in WebView is a security risk as malicious web content
/// could potentially access local files on the device.
///
/// **BAD:**
/// ```dart
/// WebViewController()
///   ..setJavaScriptMode(JavaScriptMode.unrestricted)
///   ..allowFileAccess(true);
/// ```
///
/// **GOOD:**
/// ```dart
/// WebViewController()
///   ..setJavaScriptMode(JavaScriptMode.unrestricted);
/// // File access disabled by default
/// ```
class AvoidWebviewFileAccessRule extends SaropaLintRule {
  AvoidWebviewFileAccessRule() : super(code: _code);

  // WARNING severity with high impact - security concern but not crash-causing
  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_webview_file_access',
    '[avoid_webview_file_access] WebView file access enabled (allowFileAccess: true) lets malicious web content read local files including user data, cached credentials, and app configuration, then exfiltrate them to attacker-controlled servers without user consent or visible indication. {v3}',
    correctionMessage:
        'Remove allowFileAccess: true or explicitly set it to false. If file access is required, restrict it to specific directories and validate all file paths.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check for allowFileAccess method call
      if (methodName == 'allowFileAccess' ||
          methodName == 'setAllowFileAccess') {
        final ArgumentList args = node.argumentList;
        if (args.arguments.isNotEmpty) {
          final String argValue = args.arguments.first.toSource();
          if (argValue == 'true') {
            reporter.atNode(node);
          }
        }
      }
    });

    // Also check named parameters
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (!RegExp(r'\b(WebView|Settings)\b').hasMatch(typeName)) {
        return;
      }

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          if (name == 'allowFileAccess' ||
              name == 'allowFileAccessFromFileURLs') {
            final String value = arg.expression.toSource();
            if (value == 'true') {
              reporter.atNode(arg);
            }
          }
        }
      }
    });
  }
}
