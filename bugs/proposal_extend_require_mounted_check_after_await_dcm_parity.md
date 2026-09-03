# PROPOSAL: Extend `require_mounted_check_after_await` to General Async State-Update Atomicity

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `require_mounted_check_after_await`

---

## Summary

Extend `require_mounted_check_after_await` to also flag async operations that update shared/external state (not just Flutter's `State.mounted`/`setState`) without an atomicity guard after an `await` — for example, a service class mutating a shared field, a singleton's cache, or a stream controller after an `await`, without checking a cancellation/disposal flag first — matching DCM's `require-atomic-async-updates`, which is broader than Flutter widget lifecycle.

**Closes gap:** DCM `require-atomic-async-updates` (dcm.dev) — currently PARTIAL via saropa's `require_mounted_check_after_await`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "DCM proper" PARTIAL matches table.

---

## Motivation

`lib/src/rules/core/async_rules.dart:4291-4340` implements `RequireMountedCheckAfterAwaitRule`. Its gate is hard-coded to Flutter's `State<T>` class and the `setState` method name:

```dart
context.addMethodDeclaration((MethodDeclaration node) {
  if (!node.body.isAsynchronous) return;

  final classDecl = node.thisOrAncestorOfType<ClassDeclaration>();
  if (classDecl == null) return;

  final extendsClause = classDecl.extendsClause;
  if (extendsClause == null) return;

  final superclass = extendsClause.superclass;
  if (superclass.name.lexeme != 'State') return;
  if (superclass.typeArguments == null) return;

  node.body.visitChildren(_MountedCheckVisitor(reporter, code));
});
```

with `_MountedCheckVisitor` looking specifically for `setState(...)` calls after an `AwaitExpression` without an intervening `if (...mounted...)` guard. The underlying race condition — code resumes after an `await`, and by then some other execution path has already changed the world out from under it, so the resumed code corrupts state by writing stale data on top of newer data — is not unique to Flutter widgets. The same hazard exists in: a repository class that awaits a network call then unconditionally overwrites a shared in-memory cache (a second, faster request that started later could finish first and get clobbered by the first request's stale write); a service that awaits then mutates a instance field used by other pending operations; a controller (`StreamController`, `ChangeNotifier` outside `State`) that adds/notifies after an await without checking whether it was `close()`d/disposed in the interim. DCM's `require-atomic-async-updates` targets this whole class, using `mounted` only as Flutter's specific instance of a general "check the guard before writing after resuming" pattern.

## Detection / Behavior

### Should flag (bad code)

```dart
class UserRepository {
  User? _cachedUser;
  bool _disposed = false;

  Future<void> refresh() async {
    final user = await _api.fetchUser();
    // No guard against a stale/out-of-order write or `_disposed` check —
    // a later refresh() call that started after this one could finish
    // first, and this write silently clobbers the newer data. LINT
    _cachedUser = user;
  }
}
```

### Should pass (good code)

```dart
class UserRepository {
  User? _cachedUser;
  bool _disposed = false;
  int _requestId = 0;

  Future<void> refresh() async {
    final int requestId = ++_requestId;
    final user = await _api.fetchUser();
    // OK — guarded: only the most recent request may write, and disposal
    // is checked before mutating shared state.
    if (_disposed || requestId != _requestId) return;
    _cachedUser = user;
  }
}
```

## Proposed Tier

Tier: Essential

Justification: keep parity with the existing rule's tier — `require_mounted_check_after_await` is in `essentialRules` (`lib/src/tiers.dart` line 505), reflecting `LintImpact.error` severity for a real race-condition bug class. The general async-atomicity case carries the same production-bug severity (silent data corruption from out-of-order writes), so it should surface at the same tier rather than being demoted to an opt-in check.

## Edge Cases

1. **What counts as "shared/external state"** — must be scoped conservatively to avoid false positives on purely-local state: instance fields of the enclosing class (`this.foo = ...` or bare `foo = ...` resolving to a field), not local variables, are the primary target — mirroring how the `State.mounted` case only cares about `setState` (a field/widget-tree mutation), not local reassignment.
2. **What counts as a "guard"** — the existing rule's `_mountedInCondition` regex (`\bmounted\b`) is a textual heuristic scoped to one identifier; the general version needs a configurable/heuristic notion of a guard check (`if (_disposed) return;`, `if (token != _currentToken) return;`, `if (!_isActive) return;`) rather than hard-coding a single field name — likely detect "an `IfStatement` immediately following the last `await` in the method, whose condition references a boolean/int field of the enclosing class, followed by an early return/continue" as the guard shape, without asserting the guard is semantically correct (that's undecidable statically) — only that *some* guard shape exists.
3. **Fire-and-forget corrections (`unawaited(...)`)** — an async method's caller not awaiting it does not exempt the method's own body from the atomicity concern; the check operates purely within the async method's own body, unaffected by caller awaiting style.
4. **Idempotent/last-write-wins-is-fine mutations** — a method that only ever reads a value and rewrites the identical value, or state where staleness is provably harmless (e.g. a monotonically increasing counter using `max()`), cannot be distinguished by AST alone; accept this as a documented false-positive class requiring `// ignore:` with justification, same policy as any other heuristic rule in this codebase.
5. **Single in-flight caller by construction** (e.g. a method only ever called once from `main()`, or gated by a mutex/lock library before the `await`) — should ideally not flag if a lock/mutex acquisition wraps the whole method, but detecting that requires recognizing common locking APis (`synchronized`, `pool.withResource`, etc.); treat as a known future refinement, not a blocking requirement for v1.
6. **Overlap with `require_mounted_check_after_await`'s existing Flutter `State` case** — the general rule must not double-report when the async method is *also* inside a `State<T>` class doing `setState` after await; keep the existing `State`/`setState` path exactly as-is (unchanged rule id and message) and only add the general field-mutation path for classes that are NOT `State<T>`, to avoid two diagnostics on the same line.

## Alternatives Considered

- **New standalone rule** (`require_atomic_async_state_updates`) for the general case, leaving Flutter's `State.mounted` rule untouched — a strong alternative given how different the "guard" detection heuristic is (arbitrary field names vs. the single hard-coded `mounted` identifier) from the existing implementation. This proposal frames it as an extension per the batch's Related-rules convention and DCM's single `require-atomic-async-updates` rule id, but implementers should feel free to ship it as a sibling rule sharing the `_didSeeAwait`-style visitor infrastructure if reusing `_MountedCheckVisitor` directly proves awkward for the non-`mounted` guard shapes.
- **Full happens-before/data-race static analysis** — the theoretically correct approach but far beyond AST-level linting; out of scope. The heuristic (await → unconditional field write → no preceding guard `if`) is the same class of best-effort static check the existing `mounted` rule already uses, applied to a broader target set.

---

## Decision

---

## Implementation Notes

Add a second registration inside (or alongside) `RequireMountedCheckAfterAwaitRule.runWithReporter` in `lib/src/rules/core/async_rules.dart`: for async methods NOT inside a `State<T>` class, walk the body with a generalized visitor (parallel to `_MountedCheckVisitor`) that flags an assignment to an instance field (`this.x = ...` or unqualified field write resolving to a `FieldElement` of the enclosing class) occurring after an `AwaitExpression` with no preceding `IfStatement` guard-and-early-return referencing a field of the class.

---

## Commits
