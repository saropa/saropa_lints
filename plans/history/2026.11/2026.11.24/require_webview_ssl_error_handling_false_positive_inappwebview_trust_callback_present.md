# BUG: `require_webview_ssl_error_handling` — flags InAppWebView that already sets onReceivedServerTrustAuthRequest

**Status: Open**

Created: 2026-11-23
Rule: `require_webview_ssl_error_handling`
File: `lib/src/rules/packages/webview_flutter_rules.dart` (line ~212, `RequireWebviewSslErrorHandlingRule`)
Severity: False positive
Rule version: v4

---

## Summary

The rule's source accepts `onSslError` or `onReceivedServerTrustAuthRequest` on `InAppWebView`, yet the diagnostic still fires on an `InAppWebView(...)` that passes `onReceivedServerTrustAuthRequest`. Expected: no diagnostic.

## Attribution Evidence

```bash
grep -rn "'require_webview_ssl_error_handling'" lib/src/rules/
# lib/src/rules/packages/webview_flutter_rules.dart:212
```

## Reproduction

saropa_lints 4.15.1, flutter_inappwebview 6.x:

```dart
InAppWebView(
  initialUrlRequest: URLRequest(url: WebUri('https://classroom.google.com')),
  onReceivedServerTrustAuthRequest: (c, challenge) async =>
      ServerTrustAuthResponse(action: ServerTrustAuthResponseAction.CANCEL),
)
```

Reported at the `InAppWebView` node (line of the constructor call). Message: `[require_webview_ssl_error_handling] If your WebView does not handle SSL certificate errors...`

## Expected

No diagnostic: the trust callback is present and cancels invalid certificates.

## Notes

The named-argument check may not match the analyzer's argument node type for this call (the rule tests `arg is NamedArgument`); verify against the analyzer version in use.

---

## Closed (2026-11-24)

Not reproducible on current source. RequireWebviewSslErrorHandlingRule already accepts onReceivedServerTrustAuthRequest for InAppWebView; the reporter's 4.15.1 predates it. Retest on the latest release.
