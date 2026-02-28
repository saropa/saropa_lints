# Task: `require_connectivity_timeout`

## Summary
- **Rule Name**: `require_connectivity_timeout`
- **Tier**: Essential
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §5.15 connectivity_plus Rules

## Problem Statement

Network requests without timeouts can hang indefinitely. Even when `connectivity_plus` reports a connection, the actual request can:
1. Never complete (captive portal intercepts the request)
2. Take minutes on a slow 2G connection
3. Be stuck waiting for a server that is down but not refusing connections

Without a timeout, the app:
- Hangs the UI (if awaited on the main thread)
- Consumes resources indefinitely
- Never shows an error message
- Creates a poor user experience

```dart
// BUG: no timeout — can hang forever
final response = await http.get(Uri.parse(url)); // ← no timeout
```

Every network request should have an explicit timeout. Even if connectivity is detected, the timeout ensures the request fails gracefully.

## Description (from ROADMAP)

> Always set timeout on network requests. Connectivity status can be misleading.

## Trigger Conditions

1. `http.get/post/put/delete/patch` without a timeout header or timeout wrapper
2. `Dio` instance `get/post` calls where `options.receiveTimeout` and `sendTimeout` are not set
3. `http.Client` calls without a `timeout` wrapper (`Future.timeout()` or `client.connectionTimeout`)

**Note**: This rule overlaps with general network rules and may be better placed in a "Network Hygiene" category than connectivity_plus-specific. The association with connectivity_plus is because the pattern often arises when developers over-rely on connectivity status checks.

## Implementation Approach

### For `http` package
```dart
context.registry.addMethodInvocation((node) {
  if (!_isHttpNetworkCall(node)) return; // http.get, http.post, etc.
  // Check if wrapped in Future.timeout()
  if (_isWrappedInTimeout(node)) return;
  // Check if http.Client with connectionTimeout set
  if (_hasTimeoutViaClient(node)) return;
  reporter.atNode(node, code);
});
```

### For `Dio`
```dart
context.registry.addInstanceCreationExpression((node) {
  if (!_isDioInstantiation(node)) return;
  // Check if BaseOptions includes receiveTimeout/sendTimeout/connectTimeout
  if (_dioOptionsHaveTimeout(node)) return;
  reporter.atNode(node, code);
});
```

## Code Examples

### Bad (Should trigger)
```dart
// http package without timeout
final response = await http.get(Uri.parse('https://api.example.com/data')); // ← trigger

// Dio without timeout
final dio = Dio(); // ← trigger: no timeout in BaseOptions
final response = await dio.get('/users');

// http.Client without timeout
final client = http.Client();
final response = await client.get(Uri.parse(url)); // ← trigger
```

### Good (Should NOT trigger)
```dart
// http with Future.timeout()
final response = await http.get(Uri.parse(url))
    .timeout(const Duration(seconds: 30));

// Dio with BaseOptions timeouts
final dio = Dio(BaseOptions(
  connectTimeout: const Duration(seconds: 10),
  receiveTimeout: const Duration(seconds: 30),
  sendTimeout: const Duration(seconds: 30),
));

// http.Client with timeout
final client = http.Client();
final response = await client.get(Uri.parse(url))
    .timeout(const Duration(seconds: 30));
```

## Edge Cases & False Positives

| Scenario | Expected Behavior | Notes |
|---|---|---|
| Global Dio interceptor that adds timeout | **Complex** — may need cross-file analysis | |
| `http.get` in test file | **Suppress** | Tests should use mocks anyway |
| `Future.timeout()` wrapping the full async chain | **Suppress** | |
| Already has `timeout:` named parameter (if http adds it) | **Suppress** | |
| Retry packages that handle timeout internally | **Complex** | |
| Generated code | **Suppress** | |

## Unit Tests

### Violations
1. `await http.get(url)` without timeout → 1 lint
2. `Dio()` without timeout in options → 1 lint

### Non-Violations
1. `await http.get(url).timeout(...)` → no lint
2. `Dio(BaseOptions(connectTimeout: ...))` → no lint

## Quick Fix

Offer "Add `.timeout(const Duration(seconds: 30))`":
```dart
// Before
final response = await http.get(Uri.parse(url));

// After
final response = await http.get(Uri.parse(url))
    .timeout(const Duration(seconds: 30));
```

## Notes & Issues

1. **Package detection**: Fire only if `ProjectContext.usesPackage('http')` or `ProjectContext.usesPackage('dio')`.
2. **Relationship to connectivity_plus**: This rule is in the connectivity_plus section because timeout is essential when connectivity status is unreliable. However, it applies to ALL network requests, not just those guarded by connectivity checks. Consider whether this belongs in a broader network hygiene section.
3. **Dio global config**: Many apps configure Dio in a singleton with timeouts set at the DI level. Detecting this requires cross-file analysis. Phase 1 should only fire on `Dio()` instantiation without options — a very conservative check.
4. **Retrofit/Chopper**: If using code-generated clients (Retrofit, Chopper), timeouts are set at the client level. Phase 1 ignores these.
5. **Recommended timeout values**: 10-15s connect, 30s receive. These are reasonable defaults for mobile networks.
