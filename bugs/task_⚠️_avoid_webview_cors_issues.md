# Task: `avoid_webview_cors_issues`

## Summary
- **Rule Name**: `avoid_webview_cors_issues`
- **Tier**: Professional
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §5.30 WebView Security Rules

## Problem Statement

WebViews have platform-specific CORS (Cross-Origin Resource Sharing) limitations:

**Android WebView**:
- By default, cross-origin requests from `file://` URIs to `http/https` are blocked
- `setAllowFileAccessFromFileURLs(true)` opens a security hole (disabled by default in WebView)
- Some CORS headers that work in regular browsers may not work in WebView

**iOS WKWebView**:
- More restrictive than desktop Safari
- `file://` to `http://` requests are blocked completely
- Some fetch API behaviors differ

Common manifestations:
1. Loading a local HTML file that tries to fetch from an API — blocked by CORS
2. Embedding a third-party page that makes cross-origin requests — may fail
3. Using `XMLHttpRequest` or `fetch` in a WebView with CORS-restricted origins

The mistake:
```dart
// Enabling permissive file access to work around CORS
final controller = WebViewController()
  ..loadHtmlString(htmlContent)
  // Using a workaround that bypasses CORS security:
  // androidController.settings.allowUniversalAccessFromFileURLs = true ← SECURITY HOLE!
```

## Description (from ROADMAP)

> WebView has CORS limitations. Document CORS handling.

## Trigger Conditions

1. `allowUniversalAccessFromFileURLs: true` or similar in WebView settings — security-bypassing CORS workaround
2. `allowFileAccessFromFileURLs: true` — less severe but still a concern
3. Loading `file://` URIs in a WebView that also makes network requests (CORS will block these)

**Phase 1 (Security focus)**: Flag the dangerous `allowUniversalAccessFromFileURLs: true` setting.

## Implementation Approach

```dart
context.registry.addInstanceCreationExpression((node) {
  if (!_isAndroidWebViewSettings(node)) return;
  // Check for dangerous CORS bypass settings
  if (_hasUniversalFileAccess(node)) {
    reporter.atNode(node, code);
  }
});
```

`_isAndroidWebViewSettings`: check for `AndroidWebViewController.enableDebugging` or similar settings class.
`_hasUniversalFileAccess`: check for `allowUniversalAccessFromFileURLs: true` named argument.

## Code Examples

### Bad (Should trigger)
```dart
// Dangerous CORS bypass
final androidController = AndroidWebViewController.fromPlatformWebViewController(
  _webViewController!.platform,
);
await androidController.setMediaPlaybackRequiresUserGesture(false);
// ← trigger: allowUniversalAccessFromFileURLs is a CORS security bypass
```

```dart
// If accessible in WebView settings:
WebView(
  ...,
  // BUG: bypasses all CORS for file:// URLs
  onWebViewCreated: (controller) async {
    final androidController = controller.android;
    androidController?.enableDebugging(true);
    // Setting that bypasses CORS:
    // androidController?.setAllowUniversalAccessFromFileURLs(true); // ← DANGER
  },
)
```

### Good (Should NOT trigger)
```dart
// Proper CORS handling: use a local server or data URIs
final controller = WebViewController()
  ..loadHtmlString(htmlContent)  // ← use inline HTML, not file:// requests
  ..setJavaScriptMode(JavaScriptMode.unrestricted);

// Or: use https:// URLs (no CORS issues with proper server CORS headers)
final controller = WebViewController()
  ..loadRequest(Uri.parse('https://myapi.com/webview-content'));
```

## Edge Cases & False Positives

| Scenario | Expected Behaviour | Notes |
|---|---|---|
| WebView only loading HTTPS URLs (no file:// involved) | **Suppress** — CORS less likely to be an issue | |
| `loadHtmlString` with inline content (no external fetch) | **Suppress** — no cross-origin requests | |
| Test/mock WebView | **Suppress** | |
| Generated code | **Suppress** | |

## Unit Tests

### Violations
1. `allowUniversalAccessFromFileURLs: true` in WebView settings → 1 lint

### Non-Violations
1. Default WebView without CORS bypass settings → no lint
2. HTTPS URL loaded in WebView (no file:// involved) → no lint

## Quick Fix

No automated fix — CORS issues require architectural decisions:
1. Use `loadHtmlString` with all resources inline
2. Serve the web content from a local HTTP server
3. Configure proper CORS headers on the remote server
4. Use a custom URL scheme handled by the native layer

## Notes & Issues

1. **webview_flutter-only**: Only fire if `ProjectContext.usesPackage('webview_flutter')` or similar WebView package.
2. **OWASP**: Maps to **M2: Insecure Data Storage** and **M5: Insufficient Cryptography** — enabling CORS bypass weakens the same-origin policy.
3. **PRIMARY TARGET**: The rule description says "Document CORS handling" — this is primarily a documentation/awareness lint. The dangerous case to flag is `allowUniversalAccessFromFileURLs: true`.
4. **Platform-specific API**: CORS bypass settings are in Android-specific WebView APIs. iOS WKWebView doesn't have the same option. The lint should focus on Android-specific settings.
5. **The correct fix for file:// + API calls**: Use `flutter_inappwebview`'s `InAppLocalServer` feature (serves local files over HTTP) or embed all resources inline. This avoids CORS entirely.
6. **Documentation focus**: Since the correct CORS handling varies by scenario, a WARNING with a detailed `correctionMessage` pointing to documentation is more valuable than precise detection.
