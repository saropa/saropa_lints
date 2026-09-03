# PROPOSAL: Flag Usage of fpdart APIs Removed in Later Package Versions

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_either_of_future`, `avoid_future_of_either`, `avoid_future_of_option`, `avoid_get_or_else_swallowing_failure`, `avoid_nested_do_notation`

**Package dependency:** `fpdart`. This rule only applies to projects using `package:fpdart` and should only run when fpdart is a declared dependency.

---

## Summary

Add `avoid_removed_fpdart_api` to flag calls to fpdart members/methods that were removed or renamed in a later major version of the package (tracked via a maintained mapping in the rule, e.g. old method names replaced by new ones across fpdart's breaking releases) — these calls typically still resolve today against an older pinned version, but silently become compile errors (or, worse, resolve to a same-named-but-different-behavior replacement) the moment the project's `fpdart` constraint is bumped.

**Closes gap:** many_lints `avoid_removed_fpdart_api` (fpdart family). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

fpdart, like many functional-programming ports, has gone through API renames and removals across major versions (e.g. constructor/method naming conventions changing between versions) as the package matured. A project pinned to an older constraint accumulates calls to those older names; when someone eventually bumps the version (often in an unrelated dependency-update PR), the compiler catches outright removals immediately, but a subtler danger is a call that still resolves — to a different member with a changed signature or behavior — producing a silent behavioral regression instead of a compile error. Flagging known-removed/renamed APIs proactively, ahead of the version bump, turns a future migration into a today problem the team controls.

---

## Detection / Behavior

Maintain a mapping of `{deprecated/removed member name → recommended replacement}` for fpdart's tracked breaking changes. Flag any method invocation or member access matching a name in that mapping, resolved via type-checking to confirm the receiver is genuinely an fpdart type (not a same-named member on an unrelated class).

### Should flag (bad code)

```dart
final result = Either<String, int>.of(5); // LINT — Either.of removed/renamed; use Either.right(5)
```

### Should pass (good code)

```dart
final result = Either<String, int>.right(5); // OK — current fpdart API
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Package-specific (fpdart) API-migration rule requiring a maintained version-mapping table; appropriate for a deep-review tier, matching the tier placement of saropa's other fpdart rules.

---

## Edge Cases

1. **Project is pinned to an fpdart version where the "removed" API is still the current, correct API (i.e. the removal hasn't happened yet in the pinned version)** — needs discussion; consider gating the rule's active mapping entries on the project's actual `fpdart` version constraint from `pubspec.yaml`, so the rule only flags names removed at-or-below the resolved version, avoiding false positives against still-current APIs on older constraints.
2. **A user-defined class or extension happens to share a flagged method name (e.g. a project's own `.of()` factory unrelated to fpdart)** — should pass; type resolution must confirm the receiver's static type is genuinely from `package:fpdart` before flagging.
3. **Deprecated fpdart API already marked `@Deprecated(...)` upstream (analyzer's own deprecation lint would already catch it)** — should pass to avoid duplicate reporting, or clearly differentiate messaging from the analyzer's built-in deprecation warning if both fire; prefer relying on the analyzer's own signal when an `@Deprecated` annotation already exists upstream, and reserve this rule for APIs removed outright (no deprecation warning ever shipped, straight removal).
4. **fpdart mapping table goes stale as new versions ship** — acknowledge as an ongoing maintenance cost; document that the mapping requires periodic updates tracked against fpdart's changelog, similar to how saropa tracks other third-party package API changes.

---

## Alternatives Considered

- **Rely solely on the Dart analyzer's built-in `@Deprecated` warnings** — rejected as the sole mechanism; it only catches APIs the fpdart maintainers bothered to mark `@Deprecated` before removal, not APIs removed outright without a deprecation cycle, and doesn't provide fpdart-specific replacement guidance in the correction message.

---

## Decision

---

## Implementation Notes

---

## Commits
