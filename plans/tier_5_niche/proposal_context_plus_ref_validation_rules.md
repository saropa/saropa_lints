# PROPOSAL: Validate `context_plus` `Ref` Declaration Location and Generic Type

**Status: Open**

Created: 2026-09-02
Type: New rule (2 rules)
Related rules: none

---

## Summary

Add two rules for the `context_plus` package's `Ref<T>`/`context.use()` API:

- `wrong_ref_declaration` — flag a `Ref<T>` instance declared anywhere other than top-level `final`/`static final` (e.g. as a local variable, an instance field, or a `late` variable) — `context_plus`'s `Ref` is designed to be a single module-level singleton handle, and any other placement breaks its lifecycle contract.
- `wrong_ref_type` — flag a `Ref<T>` whose generic type argument `T` doesn't match the return type of the `context.use()` call(s) that resolve it, a type mismatch the package's own API can't catch at compile time because `use()` is populated dynamically by provider registration.

**Closes gap:** `context_plus_lint` `wrong_ref_declaration` and `wrong_ref_type` (2 of its 4 rules; the other 2 — `context_use_unique_key`, `context_ref_reassignment` — are out of scope for this proposal). Implementing this proposal as specified fully closes these two competitive gaps — see `plans/GAP_ANALYSIS.md` "Niche third-party package APIs" section, `context_plus_lint` entry.

---

## Motivation

`context_plus` is a real dependency-injection-via-BuildContext package with its own compile-time-unchecked invariants (`Ref` must be a stable top-level singleton; the generic type must line up with what's actually registered) — invariants its own upstream lint package (`context_plus_lint`) exists specifically to enforce, confirming these are known, real footguns for the library's users, not hypothetical. saropa has zero `context_plus`-specific coverage today.

---

## Detection / Behavior

### `wrong_ref_declaration`

#### Should flag (bad code)

```dart
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ref = Ref<UserRepository>(); // LINT — Ref declared as a local variable, not top-level/static final
    final repo = context.use(ref);
    return Text(repo.currentUserId);
  }
}
```

#### Should pass (good code)

```dart
final userRepositoryRef = Ref<UserRepository>(); // OK — top-level final

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final repo = context.use(userRepositoryRef);
    return Text(repo.currentUserId);
  }
}
```

### `wrong_ref_type`

#### Should flag (bad code)

```dart
final userRepositoryRef = Ref<UserRepository>();

// Elsewhere, registered as a different type than declared:
context.provide(AuthService()); // provider is AuthService
final service = context.use(userRepositoryRef); // LINT — Ref<UserRepository> used where AuthService is registered
```

#### Should pass (good code)

```dart
final authServiceRef = Ref<AuthService>();
context.provide(AuthService());
final service = context.use(authServiceRef); // OK — types line up
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Package-specific rules (`context_plus` dependency required) — appropriate for Comprehensive per the package-specific-rule convention.

---

## Edge Cases

1. **`wrong_ref_declaration`: `Ref<T>` declared as a `static final` field inside a class (not top-level)** — should pass; `static final` matches the package's singleton-lifecycle requirement equally well as top-level.
2. **`wrong_ref_declaration`: `Ref<T>` declared top-level but with `var`/no `final`** — should flag; mutability defeats the singleton-handle guarantee even at top-level scope.
3. **`wrong_ref_type`: `context.provide()` call site not resolvable within the same file (registered in a different module)** — should discuss; cross-file type resolution may be needed for full accuracy — v1 can scope to single-file/same-widget-tree resolution and document the limitation.
4. **`wrong_ref_type`: `Ref<T>` where `T` is itself a generic/abstract interface type, and `context.provide()` registers a concrete subtype** — should pass; subtype registration against an interface-typed `Ref` is the intended usage pattern, not a mismatch.

---

## Alternatives Considered

- **Split into two separate proposal files** — rejected per task instructions; both rules share the same package dependency, detection infrastructure (locating `Ref<T>` declarations and `context.use()`/`context.provide()` call sites), and tier placement, so one combined proposal avoids duplicating that shared context.

---

## Decision

---

## Implementation Notes

---

## Commits
