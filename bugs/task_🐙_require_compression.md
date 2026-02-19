# Task: `require_compression`

## Summary
- **Rule Name**: `require_compression`
- **Tier**: Comprehensive
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md §1.3 Performance Rules — Network Performance
- **GitHub Issue**: [#15](https://github.com/saropa/saropa_lints/issues/15)
- **Priority**: 🐙 Has active GitHub issue

## Problem Statement

HTTP/HTTPS responses containing JSON, HTML, or text can be compressed with gzip/deflate/brotli, reducing payload size by 60–80%. Most modern HTTP servers support content encoding, and Dart's `http` and `dio` clients accept compressed responses by default (the OS handles decompression transparently). However, many Flutter developers do not set the `Accept-Encoding: gzip` request header when using lower-level HTTP clients, missing significant bandwidth and latency savings.

This is particularly impactful on mobile where 4G/5G bandwidth is still limited in many regions, and on metered connections.

## Description (from ROADMAP)

> Large JSON/text responses should use gzip compression. Reduces bandwidth 60-80% for typical API responses.

## Trigger Conditions

### Phase 1 — Missing Accept-Encoding header in manual HTTP calls
1. `http.get(...)` / `http.post(...)` calls (from `package:http`) without `headers: {'Accept-Encoding': 'gzip'}`
2. `Dio` requests without `options.headers['Accept-Encoding']` or `DioMixin.options.headers`

### Phase 2 — Dio without compression middleware
Detect `Dio()` creation or `DioMixin` subclass without a compression interceptor or explicit `Accept-Encoding` in default headers.

**Note**: Most HTTP stacks add `Accept-Encoding: gzip` automatically. This rule may have HIGH false positive rate if the underlying platform already handles it. **CRITICAL: Verify this before implementing** — if `dart:io` `HttpClient` adds it automatically, the rule is largely redundant.

## Implementation Approach

### Package Detection
Only fire if:
- Project uses `http` (`ProjectContext.usesPackage('http')`) OR
- Project uses `dio` (`ProjectContext.usesPackage('dio')`)

### AST Visitor Pattern

```dart
context.registry.addMethodInvocation((node) {
  if (!_isHttpGetOrPost(node)) return;
  if (_hasAcceptEncodingHeader(node)) return;
  reporter.atNode(node, code);
});
```

`_isHttpGetOrPost`: detect `http.get(...)`, `http.post(...)`, `client.get(...)` etc.

`_hasAcceptEncodingHeader`: look for `headers` named argument containing `'Accept-Encoding'` key.

### Checking Dio Default Headers

```dart
context.registry.addInstanceCreationExpression((node) {
  if (!_isDioConstruction(node)) return;
  // Check if there's a BaseOptions being passed with Accept-Encoding
  // OR if the Dio instance is later configured with .options.headers
  // This is Phase 2 — very hard to track statically
});
```

## Code Examples

### Bad (Should trigger)
```dart
// Missing Accept-Encoding header
final response = await http.get(
  Uri.parse('https://api.example.com/large-data'),
);

// Dio without compression
final dio = Dio();
final response = await dio.get('/large-data');
```

### Good (Should NOT trigger)
```dart
// Explicit Accept-Encoding ✓
final response = await http.get(
  Uri.parse('https://api.example.com/large-data'),
  headers: {'Accept-Encoding': 'gzip'},
);

// Using dio with default compression in BaseOptions ✓
final dio = Dio(BaseOptions(
  headers: {'Accept-Encoding': 'gzip, deflate'},
));

// Using package that handles compression automatically ✓
// (e.g., retrofit_dart, chopper)
```

## Edge Cases & False Positives

| Scenario | Expected Behaviour | Notes |
|---|---|---|
| `dart:io` `HttpClient` (low-level) | **Check separately** — may not auto-add Accept-Encoding | Different API surface |
| `http.Client` subclass that adds headers in `send()` | **False positive** — can't detect middleware statically | Very common pattern |
| Small requests (e.g., health check ping) | **Suppress** — compression overhead not worth it for small payloads | Can't know payload size statically |
| WebSocket connections | **Suppress** — WebSocket has its own compression via `permessage-deflate` | Different protocol |
| Image/binary downloads | **Suppress** — binary data doesn't benefit from gzip | Check URL pattern or content-type hints in code |
| Test file | **Suppress** | `ProjectContext.isTestFile` |
| `http.MultipartRequest` (file upload) | **Suppress** — uploading, not downloading | |
| Server-sent events (SSE) | **Note** — different from regular HTTP response | |
| `dio` with `CompressionInterceptor` or similar | **Suppress** | Hard to detect statically |

## Unit Tests

### Violations
1. `http.get(url)` without headers in a project using `package:http` → 1 lint
2. `http.post(url, body: ...)` without headers → 1 lint

### Non-Violations
1. `http.get(url, headers: {'Accept-Encoding': 'gzip'})` → no lint
2. Test file → no lint
3. Project doesn't use `http` or `dio` → no lint
4. `http.get` for a local file URL (starts with `file://`) → no lint

## Quick Fix

Offer "Add `Accept-Encoding: gzip` header":
```dart
// Before:
await http.get(Uri.parse(url));

// After:
await http.get(Uri.parse(url), headers: {'Accept-Encoding': 'gzip'});
```

## Notes & Issues

1. **CRITICAL: Verify automatic compression** — `dart:io`'s `HttpClient` and `package:http`'s `Client` may automatically send `Accept-Encoding: gzip` on all requests. If so, this rule would produce mostly false positives and should be moved to ROADMAP_DEFERRED or dropped.
2. **ROADMAP duplicate**: This rule appears TWICE in the table. Both rows should be deleted when implementing.
3. **GitHub Issue #15** — check the issue for discussion about whether auto-compression is already handled.
4. **The 60-80% bandwidth saving claim** is accurate for typical JSON APIs but overstated for already-compressed content (JPEG, PNG, binary formats).
5. **Chopper and Retrofit** already add compression headers by default. The rule should suppress when these packages are in use.
6. **Priority**: Given the high false positive risk and possible redundancy, this rule should be thoroughly researched (check `dart:io` source) before implementing.
