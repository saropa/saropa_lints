# Task: `prefer_batch_requests`

## Summary
- **Rule Name**: `prefer_batch_requests`
- **Tier**: Professional
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md §1.3 Performance Rules — Network Performance
- **GitHub Issue**: [#16](https://github.com/saropa/saropa_lints/issues/16)
- **Priority**: 🐙 Has active GitHub issue

## Problem Statement

Making multiple small HTTP requests in a `for` loop (N+1 query problem at the network layer) incurs per-request overhead: DNS lookup (cached), TCP handshake, TLS handshake, HTTP headers, and server processing overhead. For N=10 requests, this could be 500ms instead of 50ms if batched. Many APIs support batch endpoints (e.g., Firebase Firestore `getAll`, GraphQL with multiple operations, REST APIs with comma-separated IDs).

Common anti-pattern:
```dart
// Fetching user details for each ID separately
for (final id in userIds) {
  final user = await api.getUser(id);  // 10 separate requests
}
```

## Description (from ROADMAP)

> Multiple small requests have more overhead than one batched request. Combine related queries when the API supports it.

## Trigger Conditions

### Phase 1 — await inside for loop calling same API method

1. `for` loop (for-in or standard for) containing an `await` expression
2. The awaited expression is a method call on the same receiver as the previous iteration
3. The method call pattern suggests data fetching (method name contains `get`, `fetch`, `load`, `read`, `query`)

### Phase 2 — Future.wait with many similar futures

Detect `Future.wait([...])` where all futures in the list are calls to the same method with different arguments — suggest a single batch call instead.

## Implementation Approach

### AST Visitor Pattern

```dart
context.registry.addForStatement((node) {
  if (!_hasAwaitInBody(node)) return;
  final awaitedCalls = _findAwaitedMethodCalls(node.body);
  if (awaitedCalls.length < 2) return;  // Only 1 call, not a pattern
  // Check if all calls use the same method name
  final methodNames = awaitedCalls.map((c) => c.methodName.name).toSet();
  if (methodNames.length == 1 && _looksLikeDataFetch(methodNames.first)) {
    reporter.atNode(node, code);
  }
});
```

`_hasAwaitInBody`: check if the loop body contains any `AwaitExpression`.
`_looksLikeDataFetch`: check if method name starts/contains `get`, `fetch`, `load`, `read`, `query`, `find`.

### Handling `forEach`
```dart
context.registry.addMethodInvocation((node) {
  if (node.methodName.name != 'forEach') return;
  final arg = node.argumentList.arguments.first;
  if (arg is! FunctionExpression) return;
  if (!_hasAwaitInBody(arg.body)) return;  // async forEach is already bad
  // Detect awaited fetch calls inside forEach
});
```

## Code Examples

### Bad (Should trigger)
```dart
// N separate requests in a loop
Future<List<User>> loadUsers(List<String> ids) async {
  final users = <User>[];
  for (final id in ids) {
    final user = await apiClient.getUser(id);  // ← trigger
    users.add(user);
  }
  return users;
}

// Future.wait version (multiple requests, not batched)
Future<List<User>> loadUsers(List<String> ids) async {
  return Future.wait(
    ids.map((id) => apiClient.getUser(id)),  // ← trigger if same method
  );
}
```

### Good (Should NOT trigger)
```dart
// Single batch request ✓
Future<List<User>> loadUsers(List<String> ids) async {
  return apiClient.getUsers(ids);  // batch endpoint
}

// Single item — not a loop ✓
final user = await apiClient.getUser(userId);

// Different operations per iteration ✓
for (final item in items) {
  await processItem(item);  // processing, not fetching
}
```

## Edge Cases & False Positives

| Scenario | Expected Behavior | Notes |
|---|---|---|
| Loop fetching from different APIs | **Suppress** — different APIs can't be batched | Check if receiver is the same object |
| Loop with 1 iteration guaranteed | **Suppress** — not a pattern issue | Hard to detect statically |
| `await` inside loop but method is `POST`/`create` (not fetch) | **Suppress** — writes often can't be batched | Method name heuristic |
| Pagination loop (deliberate sequential pages) | **False positive** — pagination MUST be sequential | Hard to distinguish from N+1; may need to suppress `page` parameter pattern |
| `await Future.delayed(...)` inside loop | **Suppress** — delay, not a data fetch | |
| Firebase Firestore `collection.get()` in loop | **Trigger** — clearly N+1 | |
| Loop over 2 items | **Suppress or lower severity** — 2 requests is barely overhead | Configurable minimum threshold (default 3+) |
| Recursive fetch (parent→children recursion) | **Suppress** — recursive fetching is often unavoidable | Hard to detect the recursion pattern |
| Test file | **Suppress** | |
| Loop inside `compute()` (isolate) | **Note** — network calls from isolates have different semantics | |

## Unit Tests

### Violations
1. `for` loop with `await apiClient.getUser(id)` → 1 lint
2. `Future.wait(ids.map((id) => api.get(id)))` → 1 lint
3. Async `forEach` with `await apiClient.fetchItem(id)` → 1 lint

### Non-Violations
1. Single `await api.get(id)` outside a loop → no lint
2. Loop with different method calls per iteration → no lint
3. `for` loop with `await Future.delayed(...)` → no lint
4. Test file → no lint
5. Loop with only 1 item in the collection (if detectable) → no lint

## Quick Fix

No automated quick fix — the batch endpoint API is application-specific.

```
correctionMessage: 'Consider using a batch endpoint (e.g., getUsers(ids)) instead of individual requests in a loop to reduce network overhead.'
```

## Notes & Issues

1. **HIGH false positive risk** — any loop with an async call will be flagged, including legitimate sequential workflows (pagination, rate-limited APIs, etc.). The rule needs careful heuristics.
2. **ROADMAP duplicate**: This rule appears TWICE in the table. Both rows should be deleted.
3. **GitHub Issue #16** — check for additional context and edge cases discussed by users.
4. **"Same method" heuristic**: Using the same method name across iterations is a proxy for "same API endpoint", but it's imprecise. Two different objects could share the same method name.
5. **`Future.wait` pattern**: This is actually BETTER than sequential await (parallel requests), so flagging it needs justification — only flag if a BATCH endpoint is known to exist. Without knowing the API, we can't know if batching is possible. Phase 1 should likely skip the `Future.wait` case.
6. **Pagination**: A common legitimate pattern is `while (hasMorePages) { await fetchPage(cursor); }` — this MUST be sequential and should not be flagged. The cursor variable makes it detectable.
