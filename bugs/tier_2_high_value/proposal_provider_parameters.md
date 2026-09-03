# PROPOSAL: Flag Unstable Arguments Passed to Riverpod Family Providers

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Add `provider_parameters` to flag a call site (`ref.watch(myProvider(arg))`, `ref.read(myProvider(arg))`) where `arg` is an unstable expression — a literal closure created inline, a mutable object/collection without value-based `==`/`hashCode`, or a value freshly recomputed on every rebuild rather than a stable domain value. Riverpod family providers cache instances keyed by argument *value equality*; an unstable argument defeats that cache and can silently create a new provider instance (with its own state, its own async fetch, its own listener graph) on every single rebuild.

**Closes gap:** many_lints `provider_parameters` (also an adjacent concept in riverpod_lint). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

A Riverpod "family" provider — `@riverpod` functions/`Notifier`s that take an argument, invoked as `xxxProvider(someArg)` — is internally keyed in Riverpod's provider cache by the argument's `==`/`hashCode`. Passing a value that is unstable across rebuilds (a `() {}` closure literal built fresh each call, a `List`/`Map` without value equality, or any expression computed anew each build from ambient `context`/time/random state) means every rebuild produces a "different" cache key even when the logical argument hasn't changed. The practical symptom is invisible at first — the code still works — and then degrades badly under load: the provider's `build()` runs again on every rebuild (re-fetching data, re-running expensive computation), old provider instances are never reused so they pile up until disposed, and in pathological cases (argument changing on every frame) this produces unbounded provider-instance growth, sometimes described as "infinite provider creation." This is a `riverpod`/`flutter_riverpod` family-provider-specific concern.

---

## Detection / Behavior

Flag a family-provider invocation site `ref.watch(providerName(argExpr))` / `ref.read(providerName(argExpr))` (where `providerName` resolves to a generated/family provider) when `argExpr` is: (a) a closure literal (`() {}`, `(x) => x`) written inline at the call site; (b) a `late`/mutable local variable that is reassigned or recomputed inside the enclosing `build()`/widget-build method on every call rather than being a stable field/constant; or (c) an instance of a mutable collection type (`List`, `Map`, `Set`) constructed inline without a documented value-equality override.

### Should flag (bad code)

```dart
class ProductScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = ref.watch(
      productDetailsProvider(() => fetchFallback()), // LINT — inline closure literal; new identity every rebuild defeats family caching
    );
    return Text(product.name);
  }
}
```

### Should pass (good code)

```dart
class ProductScreen extends ConsumerWidget {
  final String productId; // stable, passed in once via widget construction

  const ProductScreen({required this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = ref.watch(productDetailsProvider(productId)); // OK — stable String argument, value-equal across rebuilds
    return Text(product.name);
  }
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Depends on `riverpod`/`flutter_riverpod` family-provider usage specifically — a common but not universal Riverpod pattern. Niche to Riverpod adopters, so not appropriate for Essential/Recommended; still valuable enough that it should sit above the rarely-touched Pedantic tier given the severity of the failure mode (unbounded provider growth) once it manifests.

---

## Edge Cases

1. **Argument is a `const` value or primitive literal** (`myProvider(42)`, `myProvider('fixed-id')`) — should pass; primitives and const values are inherently value-equal and stable.
2. **Argument is a class instance implementing `==`/`hashCode` by value** (e.g. an `Equatable` or `@immutable` data class with a `copyWith`-based structural type) — should pass; value equality is exactly what family caching needs, regardless of mutability of the class name.
3. **Argument is a `final` field on the enclosing widget, set once via the constructor** — should pass; stable across rebuilds by construction.
4. **Argument is a `Record` literal built inline from fields that are themselves stable** (e.g. `myProvider((userId: id, page: page))`) — should pass; Dart records have structural value equality by default, so this is stable even though it's constructed at each call site.
5. **Argument is a `DateTime.now()` or similar always-different runtime value** — should flag; this is definitionally different on every call regardless of type.
6. **Family provider argument is a tuple of a stable ID plus a callback** (mixed stable/unstable) — should flag on the callback component specifically; correction message should call out which part of a composite argument is unstable if determinable.

---

## Alternatives Considered

- **Only flag closures, skip mutable-collection-without-equality detection** — rejected as too narrow; unstable `List`/`Map` arguments are at least as common a cause of family-provider cache thrashing as inline closures (e.g. passing a filter list rebuilt each frame), and the source packages cover both.
- **Suggest wrapping the provider call in `useMemoized`/manual memoization instead of flagging the call site** — considered as a correction-message-only softening, but the underlying architectural fix (make the argument stable, or restructure to not need the family parameter to be unstable) is the more durable guidance; mention memoization as one *possible* fix in the correction message rather than the rule's primary framing.

---

## Decision

---

## Implementation Notes

Determining whether a class has value-based `==`/`hashCode` requires resolving the class's own equality implementation (override presence, `Equatable`/`freezed`/`@immutable` markers) — check `lib/src/` for existing "does this type have value equality" detection used by other saropa_lints equality-adjacent rules before writing new resolution logic.

---

## Commits
