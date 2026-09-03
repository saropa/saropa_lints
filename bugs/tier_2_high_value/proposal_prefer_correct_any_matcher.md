# PROPOSAL: Flag Incorrect Use of Mockito/Mocktail's `any` Matcher

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `pass_mock_object`

---

## Summary

Add `prefer_correct_any_matcher` to flag two common `any`/`any<T>` matcher mistakes in `mockito`/`mocktail` stubs and verifications: mixing a plain literal argument with `any()` in the same call (which is disallowed by both packages — once one argument uses a matcher, every argument on that call must), and using the untyped `any` where the parameter's static type requires the generic form `any<T>()`.

**Closes gap:** `dart_code_metrics_presets` `prefer-correct-any-matcher` (pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

Both `mockito` and `mocktail` throw at test-run time — not at analysis time — when a stub mixes literal arguments with `any()`/`any<T>()` matchers in the same call, because the mocking library can't tell whether the literal is meant as an exact-match constraint or was simply forgotten as a matcher. Catching this misuse statically turns a confusing runtime `ArgumentError` (often reported far from its real cause) into an immediate, in-editor diagnostic.

---

## Detection / Behavior

### Should flag (bad code)

```dart
when(() => repo.updateUser('1', any())).thenAnswer((_) async {}); // LINT — mixes literal '1' with any()
```

### Should pass (good code)

```dart
when(() => repo.updateUser(any(), any())).thenAnswer((_) async {}); // OK — all arguments use matchers
```

---

## Proposed Tier

Tier: Professional
Justification: catches a real runtime test failure at analysis time; requires `mockito`/`mocktail` as a dependency, so scoped below Essential/Recommended which apply dependency-free.

---

## Edge Cases

1. **All arguments are literals, no `any()` present** — should pass; matcher-mixing only applies once at least one argument uses a matcher.
2. **Named arguments where only some use `any()`/`anyNamed()`** — should flag under the same rule, since mocking libraries apply the same all-or-nothing constraint to named arguments too.
3. **`captureAny()`/`captureAny<T>()` used alongside `any()`** — should pass; capture matchers are matchers too and are exempt from the literal-mixing constraint the same way `any()` is.
4. **A parameter typed as a generic that resolves to `dynamic` at the call site** — needs discussion; the untyped `any` may be acceptable there since there's no more specific type to require.

---

## Alternatives Considered

- **Only detect the literal-mixing case, skip the untyped-vs-typed `any` check** — rejected; both are documented as the same upstream rule and both cause real runtime failures worth catching together.

---

## Decision

---

## Implementation Notes

---

## Commits
