# PROPOSAL: Flag Riverpod Providers That Watch a Scoped Provider Without Declaring `dependencies`

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `provider_dependencies` (proposed separately — that rule checks for a *mismatch* between a provider's declared `dependencies:` list and what it actually references via `ref.watch`/`ref.read`; THIS rule instead flags providers that watch a known-scoped provider while declaring NO `dependencies:` list at all, so there is nothing for a mismatch check to compare against in the first place. The two rules are complementary: this one catches the "forgot to declare anything," the other catches the "declared the wrong thing.")

---

## Summary

Add `scoped_providers_should_specify_dependencies` to flag a `@riverpod` provider that reads another provider known to be scoped (i.e. overridden per-`ProviderScope`, itself carrying a `dependencies:` declaration) via `ref.watch`/`ref.read`, while declaring no `dependencies:` list of its own. Without a `dependencies:` chain, Riverpod cannot determine that this provider needs re-scoping when its upstream dependency is overridden — `ProviderScope(overrides: [...])` silently fails to propagate the override to this provider, and it keeps reading the un-overridden root-scope instance.

**Closes gap:** riverpod_lint `scoped_providers_should_specify_dependencies`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

**Package dependency note:** this rule fires only in projects using `package:riverpod`/`package:flutter_riverpod` with the `@riverpod` code-generation annotation and provider scoping (`ProviderScope(overrides: [...])`). It has no meaning outside Riverpod's scoping model.

Riverpod's `dependencies:` parameter on a `@riverpod` provider exists specifically to make scoping correct: when provider `B` depends on provider `A`, and `A` is scoped (overridden inside a nested `ProviderScope`), `B` must declare `dependencies: [A]` so Riverpod knows to re-create `B` within that same scope rather than reusing a root-scope instance created before the override existed. Miss the declaration, and the bug is silent and easy to miss in review: the app compiles, the override appears to be wired up correctly at the `ProviderScope` call site, and `B` simply keeps reading the ORIGINAL (un-overridden) value of `A` forever, because Riverpod has no way to know `B` needs to live inside the same scope. This is a classic "test passes, feature silently broken in one specific nested-scope scenario" bug class — exactly the kind of thing a static rule can catch immediately at author-time by checking whether a provider's `ref.watch`/`ref.read` calls reference anything itself marked as scoped.

---

## Detection / Behavior

Flag a `@riverpod` (or `@Riverpod()`) annotated provider function/class that:

1. Contains a `ref.watch(someProvider)` or `ref.read(someProvider)` call where `someProvider` is itself a `@riverpod` provider carrying a non-empty `dependencies:` argument in its own annotation (i.e. `someProvider` is transitively/directly "scoped"), AND
2. The provider under analysis does NOT itself declare a `dependencies:` argument in its own `@Riverpod(dependencies: [...])` annotation.

### Should flag (bad code)

```dart
// The "leaf" scoped provider — explicitly re-scoped per ProviderScope.
@Riverpod(dependencies: [])
class ActiveTenant extends _$ActiveTenant {
  @override
  Tenant build() => defaultTenant;
}

// LINT — reads activeTenantProvider (which IS scoped) but declares no
// dependencies:, so Riverpod won't know to re-scope this provider when
// ActiveTenant is overridden in a nested ProviderScope.
@riverpod
class TenantSettings extends _$TenantSettings {
  @override
  Settings build() {
    final tenant = ref.watch(activeTenantProvider);
    return loadSettingsFor(tenant);
  }
}
```

### Should pass (good code)

```dart
@Riverpod(dependencies: [])
class ActiveTenant extends _$ActiveTenant {
  @override
  Tenant build() => defaultTenant;
}

// OK — declares dependencies: [ActiveTenant], so Riverpod re-creates
// TenantSettings within the same scope whenever ActiveTenant is overridden.
@Riverpod(dependencies: [ActiveTenant])
class TenantSettings extends _$TenantSettings {
  @override
  Settings build() {
    final tenant = ref.watch(activeTenantProvider);
    return loadSettingsFor(tenant);
  }
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Applies only to Riverpod projects using scoped providers (`dependencies:`), a specific pattern within a specific state-management package. Not Essential/Recommended, where projects not using Riverpod scoping would never trigger it; valuable to teams that DO use scoped providers, where the failure mode is silent and hard to debug.

---

## Edge Cases

1. **A provider watching a NON-scoped provider (no `dependencies:` on the upstream provider at all)** — should pass; the rule only fires when the upstream provider is itself scoped, since an un-scoped provider has no re-scoping requirement to propagate.
2. **A provider that already declares SOME `dependencies:` but is missing one specific scoped upstream reference** — this is the mismatch case; should be caught by the companion rule `provider_dependencies`, not this one, to keep the two rules' responsibilities distinct (this rule: zero declarations at all vs. a scoped read; that rule: declared list vs. actual reads).
3. **Transitive scoping** (provider `C` watches `B`, which watches scoped `A`; `B` correctly declares `dependencies: [A]`, but `C` declares nothing) — should flag; `B` being scoped (by virtue of watching scoped `A` — inferred from `B`'s non-empty `dependencies:`) means `C` also needs to declare `dependencies: [B]` to propagate correctly.
4. **`ref.watch`/`ref.read` inside a widget (`ConsumerWidget`/`Consumer`), not inside a provider** — should pass; `dependencies:` is a provider-to-provider declaration and does not apply to widget-level reads.
5. **Provider using the legacy (non-code-generation) `Provider((ref) => ...)` syntax with manual `dependencies:` argument** — should apply the same check if the legacy API's `dependencies:` parameter is used; scope the initial implementation to `@riverpod` codegen syntax first (matching the package's current recommended API) and note legacy-syntax support as a possible follow-up.

---

## Alternatives Considered

- **Merge into a single rule with `provider_dependencies`** — rejected; "no declaration at all" and "wrong/incomplete declaration" are different failure signatures with different correction messages (add a `dependencies:` list vs. fix an existing one), and riverpod_lint itself ships them as separate rules.
- **Flag any provider that watches ANY other provider without declaring `dependencies:`** (not just scoped ones) — rejected; `dependencies:` is only meaningful/required for providers that are actually scoped somewhere in the app. Requiring it universally would force every provider chain in the app to declare dependencies regardless of whether scoping is ever used, which is excessive noise for apps using Riverpod's default unscoped model.

---

## Decision

---

## Implementation Notes

---

## Commits
