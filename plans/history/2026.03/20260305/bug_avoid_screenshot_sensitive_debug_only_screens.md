# Bug: avoid_screenshot_sensitive fires on debug-only / non-sensitive screens

**History summary:** Fixed. Rule no longer reports on debug/tooling screens (class names containing debug, viewer, webview, devtool, tooling) or on "fromsettings" navigation context. Fixture and tests added. Resolved in 7.0.0.

**Rule:** `avoid_screenshot_sensitive`  
**Status:** Fixed  
**Reporter:** saropa_drift_viewer package

---

## Summary

The rule reported "Financial and authentication screens should disable screenshots..." on a **debug-only** in-app WebView used for a development database viewer (Drift/SQLite debug UI, localhost, kDebugMode only). That screen is not financial or auth; flagging it was a false positive.

## Fix (implemented)

- **Debug/tooling exclusion:** Class names containing `debug`, `viewer`, `webview`, `devtool`, or `tooling` are no longer reported.
- **"settings" heuristic:** When the matched keyword is `settings`, names containing `fromsettings` (e.g. `_WebViewScreenFromSettings`) are excluded (navigation context, not settings UI).
- **Doc:** Rule DartDoc documents scope and heuristics; debug/tooling screens are out of scope.
- **Fixture:** `example_async/lib/security/avoid_screenshot_sensitive_fixture.dart` — one BAD (expect_lint), GOOD with FLAG_SECURE, and no-trigger cases (_DriftViewerWebViewScreen, _WebViewScreenFromSettings).
- **Tests:** security_rules_test (fixture count + GOOD class names); false_positive_fixes_test regression entry.

## References

- Rule: `lib/src/rules/security/security_network_input_rules.dart` — `AvoidScreenshotSensitiveRule`
- CHANGELOG: 7.0.0 Fixed — avoid_screenshot_sensitive
