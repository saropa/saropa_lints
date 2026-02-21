# Task: `prefer_binary_format`

## Summary
- **Rule Name**: `prefer_binary_format`
- **Tier**: Comprehensive
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md §1.3 Performance Rules — Network Performance
- **GitHub Issue**: [#18](https://github.com/saropa/saropa_lints/issues/18)
- **Priority**: 🐙 Has active GitHub issue

## Problem Statement

JSON is a text format — it requires UTF-8 encoding/decoding on every serialization round-trip, is verbose (field names repeated in every object), and Dart's `jsonDecode` is single-threaded and blocks the UI isolate for large payloads. Protocol Buffers (protobuf) and MessagePack are binary formats that:

1. Encode field names as compact integer IDs → smaller payloads
2. Parse faster (binary scan vs. UTF-8 character parsing)
3. Have strongly-typed schemas (protobuf) → fewer runtime type errors

For high-frequency APIs (e.g., real-time position updates, chat messages, game state) or large payloads (product catalogs, feed data), binary formats reduce both bandwidth and CPU significantly.

## Description (from ROADMAP)

> Protocol Buffers or MessagePack are smaller and faster to parse than JSON. Consider for high-frequency or large-payload APIs.

## Trigger Conditions

### Phase 1 — High-frequency JSON decode
1. `jsonDecode(...)` called inside a `Timer.periodic` callback or stream handler
2. `jsonDecode(...)` called with no `compute()` wrapper for potentially large payloads

### Phase 2 — Large JSON response pattern
1. `json.decode(response.body)` where the response is known to be a list of many items (e.g., `List<T> items` with many fields)

**Note**: This rule is HIGHLY speculative. JSON is the correct choice for most apps. This rule should only trigger in clear high-frequency contexts, and even then it's only a suggestion. The INFO severity is appropriate — it should be easy to suppress.

## Implementation Approach

### Package Detection
If project already uses:
- `protobuf` / `flutter_protobuf` → suppress (already using binary)
- `messagepack` / `msgpack_dart` → suppress

### AST Visitor Pattern

```dart
context.registry.addMethodInvocation((node) {
  if (!_isJsonDecodeCall(node)) return;
  if (_isInsideHotPath(node)) {
    reporter.atNode(node, code);
  }
});
```

`_isJsonDecodeCall`: detect `jsonDecode(...)`, `json.decode(...)`, `JSON.decode(...)`.
`_isInsideHotPath`: walk parents for `Timer.periodic`, `StreamSubscription.onData`, `Stream.listen` callbacks.

## Code Examples

### Bad (Should trigger)
```dart
// jsonDecode in a frequent timer/stream — high CPU cost
_webSocket.stream.listen((message) {
  final data = jsonDecode(message as String);  // ← trigger: hot path
  _updateState(data);
});

// Timer.periodic with JSON parsing
Timer.periodic(Duration(milliseconds: 100), (timer) async {
  final response = await http.get(url);
  final data = jsonDecode(response.body);  // ← trigger: 10 parses/sec
  _handleUpdate(data);
});
```

### Good (Should NOT trigger)
```dart
// One-time JSON decode (app startup, user action) ✓
Future<Config> loadConfig() async {
  final response = await http.get(configUrl);
  return Config.fromJson(jsonDecode(response.body));  // fine
}

// Using compute() for large decode ✓
Future<List<Item>> loadItems() async {
  final response = await http.get(itemsUrl);
  return compute(
    (String body) => (jsonDecode(body) as List).map(Item.fromJson).toList(),
    response.body,
  );
}

// Already using protobuf ✓
final items = ItemList.fromBuffer(response.bodyBytes);
```

## Edge Cases & False Positives

| Scenario | Expected Behavior | Notes |
|---|---|---|
| Single-fire WebSocket message handler (not periodic) | **Suppress** — not high-frequency by default | Need to detect if the stream is high-frequency |
| JSON decode with `compute()` | **Suppress** — already offloading to isolate | Good pattern; check for `compute` wrapper |
| `jsonDecode` in test file | **Suppress** | `ProjectContext.isTestFile` |
| Small JSON payloads (e.g., `{"ok": true}`) | **Suppress** — trivial to parse | Can't know payload size statically |
| `jsonDecode` inside `FutureBuilder` | **Suppress** — one-time decode per build | FutureBuilder is not high-frequency |
| `json.decode` with named arg | **Detect both forms** | `jsonDecode(x)` and `json.decode(x)` |
| MessagePack already used in project | **Suppress** | `ProjectContext.usesPackage('messagepack')` |
| WebSocket binary frames (already binary) | **Suppress** — `Uint8List` messages don't need protobuf suggestion | Check argument type |
| gRPC project (proto already) | **Suppress** | `ProjectContext.usesPackage('grpc')` |

## Unit Tests

### Violations
1. `jsonDecode(message)` inside `stream.listen(...)` → 1 lint
2. `jsonDecode(response.body)` inside `Timer.periodic(...)` → 1 lint

### Non-Violations
1. `jsonDecode(str)` in one-shot async function → no lint
2. `jsonDecode` with `compute()` wrapper → no lint
3. Project uses `protobuf` package → no lint
4. Test file → no lint

## Quick Fix

No automated quick fix — migrating to binary format requires significant API and schema changes.

```
correctionMessage: 'For high-frequency or large API payloads, consider Protocol Buffers (package:protobuf) or MessagePack for better parse performance and smaller payloads.'
```

## Notes & Issues

1. **HIGH false positive risk and LOW signal value** — most apps use JSON and it's perfectly fine. The INFO severity is correct. Consider whether this rule belongs in Comprehensive or Pedantic tier given how rarely it's actionable.
2. **ROADMAP duplicate**: This rule appears TWICE. Both rows should be deleted.
3. **GitHub Issue #18** — check for additional context.
4. **WebSocket vs HTTP distinction**: WebSocket streams are genuinely high-frequency; HTTP endpoints called once per user action are not. The rule should distinguish between these.
5. **`compute()` is the better recommendation for most cases** — offloading `jsonDecode` to an isolate via `compute()` is a better short-term fix than switching to binary format. The correction message should mention this.
6. **Consider splitting into two rules**: (a) `prefer_compute_for_large_json` (more actionable) and (b) this one for the binary format suggestion.
