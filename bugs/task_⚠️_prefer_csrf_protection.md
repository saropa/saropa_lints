# Task: `prefer_csrf_protection`

## Summary
- **Rule Name**: `prefer_csrf_protection`
- **Tier**: Professional
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §1.5 Security Rules — Input Validation & Injection
- **OWASP**: M3: Insecure Authentication / CSRF

## Problem Statement

Cross-Site Request Forgery (CSRF) allows malicious websites to trigger state-changing requests on behalf of authenticated users. In native mobile apps, CSRF is less common than in web apps because the app has its own HTTP client (not a browser cookie store). However, Flutter apps targeting web or using `webview_flutter` remain vulnerable to CSRF if they use session cookies without CSRF tokens.

State-changing HTTP requests (POST, PUT, DELETE, PATCH) should include a CSRF token in the request header or body when the API uses cookie-based authentication. Token-based auth (JWT in Authorization header) is inherently CSRF-resistant.

## Description (from ROADMAP)

> State-changing requests need CSRF tokens. Without protection, malicious sites can trigger actions on behalf of logged-in users.

## Trigger Conditions

### Phase 1 — Web/WebView projects using cookie auth
1. Project targets web (`flutter build web`) AND
2. Makes state-changing HTTP calls (POST/PUT/DELETE/PATCH) without CSRF token header

### Phase 2 — Cookie-based session detection
Detect `Cookie` header being set manually without corresponding `X-CSRF-Token` or `X-Requested-With` header in the same request.

**Note**: This rule only applies when the app uses cookie-based authentication. JWT in `Authorization: Bearer` header is CSRF-resistant. This is hard to determine statically.

## Implementation Approach

### Platform Detection
Only fire for web targets or when `webview_flutter` is used.

```dart
// Phase 1: Only trigger for web-aware projects
if (!ProjectContext.isFlutterProject) return;
if (!ProjectContext.usesPackage('webview_flutter') && !_targetsWeb) return;
```

### HTTP Method Detection

```dart
context.registry.addMethodInvocation((node) {
  if (!_isStateChangingHttpCall(node)) return;  // POST, PUT, DELETE, PATCH
  if (_hasCsrfToken(node)) return;
  if (_hasAuthorizationBearerHeader(node)) return;  // CSRF-resistant
  reporter.atNode(node, code);
});
```

`_isStateChangingHttpCall`: detect `http.post(...)`, `http.put(...)`, `http.delete(...)`, `http.patch(...)`, `dio.post(...)` etc.
`_hasCsrfToken`: check `headers` argument for keys containing `csrf`, `xsrf`, `x-csrf-token`, `x-xsrf-token`.
`_hasAuthorizationBearerHeader`: check `headers` for `Authorization: Bearer` pattern.

## Code Examples

### Bad (Should trigger)
```dart
// POST without CSRF token or Bearer auth (in a web-targeting app)
await http.post(
  Uri.parse('https://api.example.com/transfer'),
  headers: {'Cookie': sessionCookie},  // ← trigger: cookie auth without CSRF
  body: jsonEncode({'amount': 100, 'to': recipientId}),
);
```

### Good (Should NOT trigger)
```dart
// Using Bearer token — CSRF resistant ✓
await http.post(
  Uri.parse('https://api.example.com/transfer'),
  headers: {'Authorization': 'Bearer $jwtToken'},
  body: jsonEncode({'amount': 100, 'to': recipientId}),
);

// Including CSRF token ✓
await http.post(
  Uri.parse('https://api.example.com/transfer'),
  headers: {
    'Cookie': sessionCookie,
    'X-CSRF-Token': csrfToken,  // ← CSRF protection
  },
  body: jsonEncode({'amount': 100, 'to': recipientId}),
);
```

## Edge Cases & False Positives

| Scenario | Expected Behaviour | Notes |
|---|---|---|
| Mobile-only app (no web target) | **Suppress** — native apps are CSRF-resistant | Check build targets |
| GET request (not state-changing) | **Suppress** — GET is idempotent | Only flag POST/PUT/DELETE/PATCH |
| Using `Authorization: Bearer` | **Suppress** — JWT auth is CSRF-resistant | Check for Bearer header |
| API key in header | **Suppress** — API keys provide CSRF resistance | Check for `X-Api-Key` or similar |
| Internal API calls (localhost) | **Suppress** | Check if URL is localhost/127.0.0.1 |
| Test files | **Suppress** | `ProjectContext.isTestFile` |
| App using `Dio` interceptor that adds CSRF | **False positive** — interceptor adds it but we can't see it | Global interceptor patterns are hard to detect |
| Custom HTTP client wrapping csrf-safe client | **False positive** | Similar problem |

## Unit Tests

### Violations
1. `http.post(url, headers: {'Cookie': ...})` in web project without CSRF/Bearer → 1 lint
2. `http.put(url, headers: {'Cookie': ...})` without CSRF token → 1 lint

### Non-Violations
1. `http.post(url, headers: {'Authorization': 'Bearer ...'})` → no lint
2. `http.post(url, headers: {'X-CSRF-Token': ...})` → no lint
3. `http.get(url, ...)` (GET is safe) → no lint
4. Test file → no lint
5. Non-web project → no lint

## Quick Fix

No automated fix — CSRF token handling requires server-side coordination.

```
correctionMessage: 'State-changing requests with cookie authentication need a CSRF token header (X-CSRF-Token). Alternatively, use Authorization: Bearer with JWT for CSRF-resistant auth.'
```

## Notes & Issues

1. **Limited scope in mobile**: Native mobile apps (not web) are inherently CSRF-resistant because they don't share cookies with browsers. This rule has narrow applicability.
2. **Very high false positive risk** — detecting cookie-based auth vs JWT auth statically is difficult. The rule may fire on apps using API keys or other non-cookie auth.
3. **Consider ROADMAP_DEFERRED** — the detection is so heuristic-heavy that this might be better placed in the deferred roadmap. The Phase 1 approach (web projects + Cookie header + no CSRF/Bearer) is tractable but narrow.
4. **WebView CSRF**: If using `webview_flutter` and injecting JS that makes requests, those ARE potentially CSRF vulnerable. This is a more complex detection scenario.
