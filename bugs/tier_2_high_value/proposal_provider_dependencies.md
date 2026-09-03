# PROPOSAL: Flag Mismatch Between Declared and Actual Riverpod Provider Dependencies

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Add `provider_dependencies` to flag a mismatch between a Riverpod provider's *declared* dependency list (`@Riverpod(dependencies: [...])` on a code-generation provider, or a manual scoped-provider `dependencies:` list) and the providers it *actually references* via `ref.watch`/`ref.read` inside its build function — in both directions: a provider used in code but missing from the declared list, and a provider declared but never actually used.

**Closes gap:** riverpod_lint (github.com/rrousselGit/riverpod). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

Riverpod's `dependencies:` declaration exists to make provider *scoping* and *overriding* work correctly: when a `ProviderContainer` overrides a provider, Riverpod uses each provider's declared `dependencies` list to determine which downstream providers must be invalidated/rebuilt as part of that override's scope. If a provider's build function calls `ref.watch(otherProvider)` but `otherProvider` is missing from its `dependencies:` list, the override machinery does not know the two are linked — overriding `otherProvider` in a test or a scoped `ProviderScope` silently fails to propagate to the dependent provider, producing stale state that is exceptionally hard to debug because the *unscoped* app behaves correctly and only the *scoped* (e.g. test) context breaks. The inverse case — a provider listed in `dependencies:` but never actually referenced — is a smaller but still real problem: a stale declaration that widens the scoping/override surface unnecessarily and misleads readers about the provider's real dependency graph. This depends on the `riverpod`/`riverpod_generator` package's `@Riverpod(dependencies: [...])` annotation and `ref.watch`/`ref.read` API.

---

## Detection / Behavior

For a `@Riverpod(dependencies: [...])`-annotated provider (or a manually-scoped provider with an explicit `dependencies:` list), collect (a) the set of providers named in the `dependencies:` list and (b) the set of providers referenced via `ref.watch(...)`/`ref.read(...)` anywhere in the provider's build function body. Flag any provider present in one set but not the other.

### Should flag (bad code)

```dart
@Riverpod(dependencies: [userRepository]) // LINT — settingsRepositoryProvider is watched below but missing from dependencies:
Settings settings(SettingsRef ref) {
  final user = ref.watch(userRepositoryProvider); // declared correctly
  final settingsRepo = ref.watch(settingsRepositoryProvider); // used but NOT declared — override scoping will silently miss this
  return settingsRepo.load(user.id);
}
```

### Should pass (good code)

```dart
@Riverpod(dependencies: [userRepository, settingsRepository]) // OK — matches every provider actually watched below
Settings settings(SettingsRef ref) {
  final user = ref.watch(userRepositoryProvider);
  final settingsRepo = ref.watch(settingsRepositoryProvider);
  return settingsRepo.load(user.id);
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Depends on the `riverpod`/`riverpod_generator` package and specifically on projects using scoped/overridable providers with explicit `dependencies:` declarations — a subset of Riverpod usage (many projects never scope providers and thus never declare `dependencies:` at all). Niche/opt-in, not appropriate for Essential/Recommended.

---

## Edge Cases

1. **A provider with no `dependencies:` declared at all and no `ref.watch`/`ref.read` calls** — should pass; nothing to compare.
2. **A provider with no `dependencies:` declared but which DOES call `ref.watch` on other `@Riverpod`-annotated providers** — should flag the "missing from dependencies" direction; an omitted `dependencies:` list is equivalent to an empty declared set.
3. **`ref.watch`/`ref.read` on a provider that is not itself `@Riverpod`-annotated** (e.g. a plain `Provider` or a family provider argument) — should still count toward the "actually referenced" set if it participates in scoping; provider family arguments referencing the same family should be normalized to the family's base provider for comparison.
4. **Conditional `ref.watch` calls inside an `if`/`switch` branch** (dependency only used sometimes) — should still require declaration; Riverpod's scoping doesn't know which branch runs, so any `ref.watch` reachable inside the build function counts, regardless of branch.
5. **`ref.listen` calls (side-effect listening, not `watch`/`read`)** — should also count as a dependency reference, since listening establishes the same override-propagation need.
6. **Dependencies declared for providers referenced only inside a helper function called from `build()`, not inline** — should still be detected if the call graph is traceable within the same file; cross-file call graph tracing is out of scope for v1 — note as a known limitation in Implementation Notes.

---

## Alternatives Considered

- **Only flag the "used but not declared" direction (the higher-severity bug), skip the "declared but unused" direction** — rejected; both directions are genuinely useful and the source package (riverpod_lint) checks both — omitting the stale-declaration direction would under-deliver relative to the cited prior art.
- **Auto-fix that rewrites the `dependencies:` list to match actual usage** — worth pursuing as a follow-up quick fix once the rule ships; mechanically safe (adding/removing provider references from a list literal) — deferred to keep the initial rule scope focused on detection.

---

## Decision

---

## Implementation Notes

Cross-file call-graph tracing (dependency referenced only via a helper function, not inline in `build()`) is a known limitation for v1 — document this as a stated non-goal rather than silently under-detecting.

---

## Commits
