# Task: `avoid_webview_local_storage_access`

## Summary
- **Rule Name**: `avoid_webview_local_storage_access`
- **Tier**: Professional
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §5.30 WebView Security Rules

## Problem Statement

WebView's local storage is shared with the page's origin and can be accessed by JavaScript running in the WebView. If `WebViewController` is configured with unrestricted settings:

1. **Cross-site scripting (XSS)**: Malicious JS injected via the web content can read all localStorage data
2. **Data exfiltration**: If sensitive data (tokens, user info) is stored in localStorage by the web content, any injected script can steal it
3. **Insecure by default**: `webview_flutter` enables local storage by default on Android

The security best practices:
- Disable local storage when not needed: `javascriptMode: JavascriptMode.disabled` or restrict access
- Do NOT store sensitive data in WebView localStorage
- Enable `clearLocalStorage()` on WebView teardown for sensitive apps

```dart
// BAD: Unrestricted WebView with JavaScript enabled
WebView(
  javascriptMode: JavascriptMode.unrestricted, // ← JS enabled
  // No local storage restrictions
  // ← Any script running in the WebView has full localStorage access
)
```

## Description (from ROADMAP)

> Limit WebView local storage access. Detect unrestricted storage settings.

## Trigger Conditions

1. `WebView` or `WebViewController` created with `javascriptMode: JavascriptMode.unrestricted` AND no `clearLocalStorageOnNavigationFinished` or similar restriction
2. `WebView` loading a URL that is not from the app's own domain (third-party content) with JavaScript enabled

**Phase 1 (Conservative)**: Flag `WebView` with `javascriptMode: JavascriptMode.unrestricted` when loading external URLs (not localhost/app domain).

## Implementation Approach

```dart
context.registry.addInstanceCreationExpression((node) {
  if (!_isWebViewWidget(node)) return;
  if (!_hasUnrestrictedJavascript(node)) return;
  if (!_loadsExternalUrl(node)) return; // check initialUrl argument
  reporter.atNode(node, code);
});
```

`_isWebViewWidget`: check constructor is `WebView` or `InAppWebView`.
`_hasUnrestrictedJavascript`: check `javascriptMode: JavascriptMode.unrestricted` named argument.
`_loadsExternalUrl`: check `initialUrl` is a string that starts with `http://` or `https://` (not `file://` or `localhost`).

## Code Examples

### Bad (Should trigger)
```dart
WebView(
  initialUrl: 'https://external-site.com',  // external content
  javascriptMode: JavascriptMode.unrestricted, // ← trigger: JS enabled on external URL
  // No localStorage restrictions
)
```

### Good (Should NOT trigger)
```dart
// Restricted JavaScript
WebView(
  initialUrl: 'https://external-site.com',
  javascriptMode: JavascriptMode.disabled, // ← no JS = no localStorage access
)

// Internal content (app's own domain)
WebView(
  initialUrl: 'https://myapp.com/terms', // ← own domain, trusted content
  javascriptMode: JavascriptMode.unrestricted, // may be acceptable
)

// New WebViewController API (flutter_webview package)
final controller = WebViewController()
  ..setJavaScriptMode(JavaScriptMode.unrestricted)
  ..clearCache() // ← clears storage on each use
  ..loadRequest(Uri.parse('https://external-site.com'));
```

## Edge Cases & False Positives

| Scenario | Expected Behavior | Notes |
|---|---|---|
| Own domain URL | **Suppress** — trusted content | |
| `file://` local HTML | **Suppress** — no remote scripts | |
| WebView for OAuth flow (trusted auth provider) | **Complex** — JS needed | Consider suppress for known auth domains |
| Test files | **Suppress** | |
| Generated code | **Suppress** | |

## Unit Tests

### Violations
1. `WebView(initialUrl: 'https://external.com', javascriptMode: unrestricted)` → 1 lint

### Non-Violations
1. `WebView(initialUrl: 'https://external.com', javascriptMode: JavascriptMode.disabled)` → no lint
2. `WebView(initialUrl: 'file:///assets/page.html', ...)` → no lint

## Quick Fix

Offer "Disable JavaScript" or "Add localStorage cleanup":
```dart
// Before
WebView(
  initialUrl: url,
  javascriptMode: JavascriptMode.unrestricted,
)

// After: Disable JS if not needed
WebView(
  initialUrl: url,
  javascriptMode: JavascriptMode.disabled,
)
```

## Notes & Issues

1. **webview_flutter-only**: Only fire if `ProjectContext.usesPackage('webview_flutter')` or `ProjectContext.usesPackage('flutter_inappwebview')`.
2. **OWASP**: Maps to **M2: Insecure Data Storage** and **M9: Reverse Engineering**.
3. **New WebViewController API**: The newer `webview_flutter` API uses `WebViewController` class instead of `WebView` widget. Both should be detected.
4. **flutter_inappwebview**: A popular alternative WebView package. Detection should cover both.
5. **URL string analysis**: Detecting "external" vs "own domain" URLs statically is unreliable (URL may come from a variable). Phase 1 should only flag string literals.
