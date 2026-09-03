# PROPOSAL: Flag Cross-Package `package:foo/src/...` Imports

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_src_import_from_same_package` (companion gap, same source package — flags a same-package absolute `package:` import into its own `src/`; this proposal is the cross-package case, see Edge Cases for the distinction)

---

## Summary

Add `avoid_src_import_from_other_subpackage` to flag an import of `package:foo/src/...` from code that lives in a *different* package/subpackage than `foo` — i.e. reaching across a package boundary into another package's private `src/` implementation directory instead of importing its public barrel file. In a monorepo of tightly related packages (or any multi-package workspace), `src/` is a private-implementation convention: it is not enforced by the language, so nothing except code review stops one package from silently depending on another's internals.

**Closes gap:** subpackage_lint `avoid_src_import_from_other_subpackage` (github.com/dumazy/subpackage_lint). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` `subpackage_lint` section: "`avoid_src_import_from_other_subpackage` — import reaches into another subpackage's `/src/` instead of its public barrel."

---

## Motivation

Dart's `src/` directory convention (files under `lib/src/`) signals "this is a package's private implementation, not part of its public API," but the language has no enforcement mechanism — any package can `import 'package:foo/src/some_internal.dart';` and the analyzer will not complain, even though `foo`'s maintainers never promised that file's contents, name, or location would stay stable. In a monorepo with several interdependent Saropa packages (`saropa_lints`, `saropa_dart_utils`, `contacts`, etc.) this is an easy trap: an author working across two packages in the same IDE session reaches for the file they can see instead of the exported barrel, and the resulting dependency silently breaks the next time the internal file is renamed or moved during a routine refactor — with no compile error signaling the breakage was even possible, only a failed build in the *other* package.

---

## Detection / Behavior

### Should flag (bad code)

```dart
// In package `contacts`, file lib/services/contact_importer.dart:
import 'package:saropa_dart_utils/src/string/string_normalizer.dart'; // LINT — reaches into saropa_dart_utils's private src/ from a different package

void normalize(String input) => StringNormalizer.clean(input);
```

### Should pass (good code)

```dart
// In package `contacts`, file lib/services/contact_importer.dart:
import 'package:saropa_dart_utils/saropa_dart_utils.dart'; // OK — public barrel export

void normalize(String input) => StringNormalizer.clean(input);
```

---

## Proposed Tier

Tier: Recommended
Justification: This is an architecture-boundary correctness issue (fragile, unversioned coupling to another package's internals) rather than a style preference, but it only matters to multi-package/monorepo projects — single-package apps never trigger it. Recommended balances "important when applicable" against "silent no-op for the common single-package case," rather than Essential which implies universal applicability.

---

## Edge Cases

1. **Import of `package:foo/src/...` from *within* package `foo` itself** — should pass; this is intra-package `src/` access, which is the intended, legitimate use of the convention. This case belongs to the companion rule `avoid_src_import_from_same_package` (flagging the narrower style issue of using an absolute `package:` import instead of a relative one within the same package), not this rule.
2. **Import of a package's public barrel file that happens to live in a path containing `/src/`** (unusual but possible if a project's public API entry point is misplaced) — should flag conservatively based on path structure (`/src/` segment present) regardless of whether the file is "meant" to be public; a `src/`-pathed file should not be a package's advertised public API, so flagging pushes toward the correct fix (move the barrel out of `src/`).
3. **Determining "is this a different package" without a monorepo manifest** — needs discussion: detection requires comparing the importing file's own package name (from its `pubspec.yaml`/`package_config.json`) against the imported URI's package segment; for a single standalone package with no local monorepo siblings, this rule is a permanent no-op, which is expected and acceptable (see Proposed Tier).
4. **Local `path:` dependency in `pubspec.yaml` pointing at a sibling package that has since published its own barrel** — should still flag if the import targets `src/`, regardless of whether the dependency is declared via `path:` or a version constraint; the boundary violation is about the import path, not the dependency-resolution mechanism.
5. **Third-party pub.dev packages' `src/` imports** (e.g. `package:some_external_pkg/src/internal.dart`) — should flag equally; this is the most common real-world instance of the underlying problem (depending on an external package's unversioned internals) and is squarely in scope, not just intra-monorepo Saropa packages.

---

## Alternatives Considered

- **One combined rule covering both same-package and cross-package `src/` misuse** — rejected; subpackage_lint ships these as two separate named rules (`avoid_src_import_from_other_subpackage` and `avoid_src_import_from_same_package`) with different severities in practice (cross-package is a real architectural risk; same-package is a minor style/consistency issue about relative vs. absolute imports), and `plans/GAP_ANALYSIS.md` tracks them as two distinct gaps — splitting keeps parity with the source package's naming and lets a project opt into the more important cross-package check without also taking on the noisier same-package style rule.
- **Enforce via `analysis_options.yaml`'s built-in `implicit-dynamic`/import-visibility mechanisms instead of a custom lint** — Dart's analyzer has no first-class "package-private src/ boundary" enforcement mechanism today (unlike, say, Java's module system), so a custom lint is the only available implementation path.

---

## Decision

---

## Implementation Notes

Candidate home: new file `lib/src/rules/architecture/subpackage_boundary_rules.dart` (no existing file targets cross-package import boundaries; `lib/src/rules/architecture/structure_rules.dart` has adjacent architecture-boundary concerns but not this specific check). Detection: for each `ImportDirective`, parse the URI — if it matches `package:<name>/src/...` and `<name>` differs from the current library's own declared package name (resolve via `context` / the analysis session's package config, not string-matching the file path), report. Needs access to the current file's own package identity, which other architecture rules in this codebase likely already resolve — check `ProjectContext` before reimplementing.

---

## Commits
