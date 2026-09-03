# PROPOSAL: Avoid Webview Local Storage Access

**Status: Open**

Created: 2026-09-02

## Summary

Flags a `WebView`/`WebViewController` configured with local storage (`domStorageEnabled`/DOM storage) and a JavaScript-to-Dart bridge (`addJavaScriptChannel`) both enabled while loading non-trusted (non-app-origin) content, exposing app-origin data and native bridge calls to that content.

## Existing Coverage

`lib/src/rules/packages/webview_flutter_rules.dart` has `AvoidWebviewFileAccessRule` (flags `allowFileAccess: true`) and `PreferWebviewSandboxRule` (flags a `WebView`/`WebViewWidget` with no file-access/domain restriction configured at all). Both are close but check a different axis — local *file* access and general sandboxing hygiene — not the combination of DOM/local storage plus an exposed JavaScript channel. This is a genuine extension: it targets the specific bridge-plus-storage exposure pattern, not file-system access.

## Motivation

`addJavaScriptChannel` exposes a Dart callback directly to any JavaScript running in the WebView; if the WebView also has local/DOM storage enabled and loads content that is not fully trusted (a third-party URL, user-supplied HTML, an ad/analytics SDK's embedded page), that content can read persisted local-storage data left by the app's own origin and can invoke the exposed bridge method with attacker-controlled arguments — turning an XSS-style content-injection bug into native code execution or data exfiltration from the host app.

## Detection / Behavior

Flags a `WebViewController`/`WebView` configuration where `addJavaScriptChannel` is called and DOM/local storage is enabled (`domStorageEnabled: true`, or `JavaScriptMode.unrestricted` without evidence of `loadRequest` being pinned to a single trusted origin), when the same controller can also `loadRequest`/`loadUrl` with a non-constant or externally-supplied URL.

```dart
// Bad:
final controller = WebViewController()
  ..setJavaScriptMode(JavaScriptMode.unrestricted)
  ..addJavaScriptChannel('Native', onMessageReceived: (msg) => handleBridge(msg.message))
  ..loadRequest(Uri.parse(userSuppliedUrl)); // LINT: JS bridge + storage exposed to a non-fixed, potentially untrusted origin

// Good:
final controller = WebViewController()
  ..setJavaScriptMode(JavaScriptMode.unrestricted)
  ..addJavaScriptChannel('Native', onMessageReceived: (msg) => handleBridge(msg.message))
  ..loadRequest(Uri.parse('https://trusted.example.com/embed')); // fixed, first-party origin only
```

## Security Mapping

OWASP Mobile M4: Insufficient Input/Output Validation (untrusted WebView content reaching a privileged native bridge) — cross-referenced with OWASP Mobile M9: Insecure Data Storage for the local-storage exposure component.

## Quick Fix

None — manual refactor required. Whether to pin the URL, remove the JS channel, or disable storage is an application-specific decision the rule cannot make safely.

## Alternatives Considered

Merging this into `PreferWebviewSandboxRule` was considered, since both flag under-restricted WebView configuration; kept separate because the trigger condition (JS bridge + storage + non-fixed URL) and the specific bridge-exposure risk it names are distinct enough to warrant a dedicated rule and message rather than broadening an existing INFO-level general sandboxing hint.
