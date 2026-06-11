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
