# PROPOSAL: Flag `package:` Imports Reaching Into Your Own Package's `src/`

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `prefer_relative_imports_enforced` (broader, general same-package `package:` import check), `avoid_src_import_from_other_subpackage` (separate proposal — cross-package `/src/` boundary, not filed yet)

---

## Summary

Add `avoid_src_import_from_same_package` to flag an import of `package:foo/src/...` written from *inside* package `foo` itself, when a relative import (`../bar.dart`, `./bar.dart`) would resolve to the exact same file. Using the absolute `package:` form to reach your own package's internals is unnecessary indirection — it couples the import statement to the package's name (breaks on rename) and is inconsistent with the relative-import convention Dart tooling expects for intra-package references.

**Closes gap:** `subpackage_lint` `avoid_src_import_from_same_package` (pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` / `doc/guides/migration_guides/migration_from_subpackage_lint.md`.

---

## Motivation

Dart/Flutter style guides and `flutter analyze`'s own `always_use_package_imports`-adjacent guidance (and its opposite, `prefer_relative_imports`) agree on one thing regardless of which side a project picks: an import that stays *inside the same package* should use one consistent form, and reaching into `src/` via the fully-qualified `package:` URI when the file is a few directories away is needless friction. It hardcodes the package name into a file that will still compile fine after a package rename only if every such import is hunted down and edited — a relative import needs no such edit. `saropa_lints` already has `prefer_relative_imports_enforced` for general same-package `package:` imports; this proposal is a narrower, `src/`-only variant matching `subpackage_lint`'s scope for teams that only want the `src/`-boundary check, not a package-wide relative-import mandate.

---

## Detection / Behavior

Flag an `ImportDirective` whose URI is `package:<name>/src/...` where `<name>` matches the *current* library's own package (as declared in its `pubspec.yaml`), when the target file is reachable via a relative path.

### Should flag (bad code)

```dart
// File: lib/src/widgets/my_button.dart in package `my_app`
import 'package:my_app/src/utils/color_utils.dart'; // LINT — same package, use a relative import
```

### Should pass (good code)

```dart
// File: lib/src/widgets/my_button.dart in package `my_app`
import '../utils/color_utils.dart'; // OK — relative import within the same package

// Importing another package's public API stays package:-qualified, which is correct.
import 'package:flutter/material.dart'; // OK — different package, package: import is appropriate
```

---

## Proposed Tier

Tier: Recommended
Justification: Import-style consistency is a common team convention, cheap to auto-fix, and low-risk — matches the tier of sibling import-hygiene rules such as `prefer_relative_imports_enforced`.

---

## Edge Cases

1. **`package:foo/src/...` imported from a *different* package `bar`** — should pass; this is the legitimate cross-package `src/` reach that `avoid_src_import_from_other_subpackage` (a separate, more serious proposal) targets, not this rule.
2. **Import of the package's own public barrel file, `package:foo/foo.dart`** — should pass; this rule only targets `src/`-prefixed URIs, not the public entry point.
3. **A file inside `bin/` or `test/` importing its own package's `src/` file via `package:`** — should still flag; the same relative-import alternative exists regardless of which top-level directory the importing file lives in.
4. **A monorepo where two path-dependency packages share a workspace but are still logically separate packages** — should pass for imports between them (different package names), consistent with edge case 1.

---

## Alternatives Considered

- **Merge into `prefer_relative_imports_enforced` as a stricter mode instead of a new rule** — rejected for parity purposes; `subpackage_lint` ships this as a distinct, `src/`-scoped rule and users migrating specifically want a like-for-like mapping they can point their existing suppressions at.
- **Auto-fix that rewrites the import to its relative equivalent** — worth pursuing as a quick fix once the rule lands; computing the relative path between the two files is mechanical (same approach `prefer_relative_imports_enforced`'s fixer likely already uses, if it has one) and should be checked for reuse before writing a second implementation.

---

## Decision

---

## Implementation Notes

Companion rule `avoid_src_import_from_other_subpackage` covers the cross-package case and is a **separate, more serious proposal** (it is a real encapsulation violation, not just a style preference) — do not conflate the two in one rule; they have different severities and different fix strategies. Check `lib/src/rules/architecture/structure_rules.dart` (home of `prefer_relative_imports_enforced`, if that is where it lives — confirm at implementation time) for reusable "resolve this package's own name from `pubspec.yaml`" and "compute relative path between two files" helpers before writing new ones.

---

## Commits
