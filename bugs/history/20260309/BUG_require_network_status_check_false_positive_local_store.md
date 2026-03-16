# Bug: `require_network_status_check` false positive on local in-memory store lookups

**Status:** Fixed (v3)
**Rule:** `require_network_status_check`
**Severity:** False positive — flags method that performs no network calls
**Plugin version:** saropa_lints

## Problem

The rule flagged server-side HTTP handler methods that only performed local in-memory store lookups (e.g., `_sessionStore.get(sessionId)`), not outbound network calls.

Two root causes:

1. **Overly broad regex patterns** — `\.get\s*\(` and `\.post\s*\(` matched ANY `.get(`/`.post(` call, including `Map.get()`, `SharedPreferences.get()`, etc.
2. **No server-side handler exclusion** — methods with `HttpResponse`/`HttpRequest` parameters ARE the endpoint, not outbound callers, but were still flagged.

## Fix

1. Replaced broad `.get(`/`.post(` patterns with specific HTTP client patterns (`http.get`, `dio.get(`, `client.get(`, etc.).
2. Added `_isServerHandler()` check that skips methods with server-side parameter types (`HttpRequest`, `HttpResponse`, `Request`, `RequestContext`).
3. Removed `\bfetchData\b` pattern (method name, not a network call).
4. Bumped rule version to v3.
