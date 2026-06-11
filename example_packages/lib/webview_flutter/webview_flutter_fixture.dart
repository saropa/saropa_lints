// ignore_for_file: unused_local_variable, unused_element, unused_import

/// Fixture for webview_flutter migration lint rules.
///
/// BAD examples are marked with `// LINT: <rule_code>`.
/// GOOD examples must NOT trigger any of the rules.
///
/// Mock stubs replace the real webview_flutter types so the fixture compiles
/// without the package present in this test environment.
/// The rule is import-gated on `package:webview_flutter/`; the import below
/// satisfies the gate. Stubs provide only enough API surface for the fixture
/// to parse — no behavior is needed.
library;

import 'package:webview_flutter/webview_flutter.dart';

// =============================================================================
// Mock stubs — replace real webview_flutter types for fixture compilation.
// Remove if example_packages adds webview_flutter to its pubspec.
// =============================================================================

// NOTE: These stubs are provided so the fixture compiles without the real
// package. They supply only the constructor signatures referenced below.

// =============================================================================
// avoid_pre_v4_webview_widget — removed WebView widget (v3.x era)
// =============================================================================

/// BAD: constructing the removed v3 WebView widget — must trigger
/// avoid_pre_v4_webview_widget.
Widget badWebViewWidget() {
  // LINT: avoid_pre_v4_webview_widget
  return WebView(
    initialUrl: 'https://flutter.dev',
  );
}

/// BAD: named constructor form still matches the type name 'WebView'.
Widget badWebViewWidgetNamed() {
  // LINT: avoid_pre_v4_webview_widget
  return WebView(
    initialUrl: 'https://example.com',
    javascriptMode: JavascriptMode.unrestricted,
  );
}

/// GOOD: v4 pattern — WebViewController + WebViewWidget.
/// Must NOT trigger avoid_pre_v4_webview_widget.
Widget goodWebViewWidget() {
  final controller = WebViewController()
    ..loadRequest(Uri.parse('https://flutter.dev'));
  // OK: WebViewWidget is the v4 replacement; must NOT be flagged.
  return WebViewWidget(controller: controller);
}

/// GOOD: constructing WebViewController alone — no WebView widget.
/// Must NOT trigger avoid_pre_v4_webview_widget.
WebViewController goodControllerOnly() {
  return WebViewController()
    ..loadRequest(Uri.parse('https://flutter.dev'));
}
