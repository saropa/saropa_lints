# PROPOSAL: Require Package Imports to Go Through the Public Barrel File

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_banned_imports`

---

## Summary

Add `only_barrel_import` to flag an import of an internal implementation file (typically anything under a package's `lib/src/` directory) from outside that package, requiring consumers to import the package's barrel file (`package:foo/foo.dart`) instead.

**Closes gap:** `dart_code_linter` `only_barrel_import` (pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

The `lib/src/` convention exists to mark implementation detail that a package's own barrel file curates into a stable public surface — importing `lib/src/*` directly bypasses that curation and couples external code to internals that can be renamed, split, or removed without a semver-major bump. This is the same discipline `avoid_banned_imports`-style rules enforce, specialized to the very common `lib/src/` package-boundary case.

---

## Detection / Behavior

### Should flag (bad code)

```dart
import 'package:some_package/src/internal_helper.dart'; // LINT — bypasses the package's barrel file
```

### Should pass (good code)

```dart
import 'package:some_package/some_package.dart'; // OK — imports through the public barrel file
```

---

## Proposed Tier

Tier: Professional
Justification: a genuine API-boundary discipline rule with cross-package maintenance value, but only actionable for packages that actually maintain a curated barrel — placed above Essential/Recommended to avoid false positives on packages without one.

---

## Edge Cases

1. **Import from within the same package (`lib/src/a.dart` importing `lib/src/b.dart`)** — should pass; the barrel requirement applies only to imports crossing a package boundary.
2. **Package with no barrel file at `lib/<package_name>.dart` at all** — needs discussion; the rule has no valid alternative to suggest and may need to skip such packages entirely.
3. **Relative import of a sibling `src/` file inside the same package** — should pass; only `package:` imports crossing into another package's `src/` are in scope.
4. **A dev-only tool package explicitly designed to be imported via `src/` (documented exception)** — needs discussion; may require a project-level allowlist for intentionally-exposed `src/` packages.

---

## Alternatives Considered

- **Enforce via `lib/src/` file visibility instead of a lint (Dart language feature)** — not available; Dart has no built-in package-private visibility below the library level, which is exactly why this convention-based lint is needed.

---

## Decision

---

## Implementation Notes

---

## Commits
