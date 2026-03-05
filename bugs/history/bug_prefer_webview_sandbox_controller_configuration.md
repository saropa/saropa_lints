# Bug: prefer_webview_sandbox does not recognize controller-level sandbox configuration

**Rule:** `prefer_webview_sandbox`  
**Status:** Fixed (7.0.0)  
**Reporter:** saropa_drift_viewer package

---

## Summary

The rule reported at `WebViewWidget(controller: ...)` even when the same controller was configured in the same file (e.g. in initState) with `setAllowFileAccess(false)` and a restrictive `NavigationDelegate`. The rule only inspected the widget instantiation and did not consider controller-level configuration.

## Resolution

- **7.0.0:** Rule now collects, in a first pass over the compilation unit, every controller expression root that receives `setNavigationDelegate(...)` or `setAllowFileAccess(false)`. When visiting `WebViewWidget(controller: expr)` or `WebView(controller: expr)`, it normalizes `expr` to a root (e.g. `_controller`, `controller`) and skips reporting if that root is in the configured set. Cascade notation (e.g. `controller..setNavigationDelegate(...)`) and platform receiver patterns (`(controller.platform as AndroidWebViewController).setAllowFileAccess(false)`) are supported. Same-file configuration only; cross-file or factory-returned controllers are not traced. Added `requiredPatterns: {'WebView', 'WebViewWidget'}` for performance.
