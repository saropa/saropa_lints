# PROPOSAL: Config-Driven Banned Export Statements

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `banned_identifier_usage` (sibling config-driven ban mechanism, different AST surface — `export` directives instead of identifier references)

---

## Summary

Add a config-driven rule that flags `export` directives whose target library URI matches a project-configured ban list, so a team can prevent specific internal or unstable libraries from being re-exported through a package's public API surface.

**Closes gap:** DCM `avoid-banned-exports` (dcm.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "DCM proper" TRUE GAPS section.

---

## Motivation

A library's `export` statements define its public API surface. A single unreviewed `export 'src/internal/experimental_api.dart';` in a barrel file can accidentally leak an internal, unstable, or intentionally-private implementation file to every downstream consumer of the package — and because `export` is a compile-time directive rather than a runtime call, this kind of leak is invisible to normal code review unless a reviewer specifically re-checks every barrel file on every PR.

DCM (dcm.dev) ships `avoid-banned-exports` for exactly this: a project lists banned export path patterns (e.g. `src/internal/**`, specific third-party re-exports a team doesn't want part of their public contract) and the rule flags any `export` directive matching one. saropa_lints has no equivalent — `banned_identifier_usage` only matches `SimpleIdentifier` nodes and never visits `ExportDirective`/`UriBasedDirective` nodes at all, so a banned-exports config entry would silently do nothing today.

---

## Detection / Behavior

Config-driven via a new `banned_exports` key in `analysis_options_custom.yaml`, following the same entry shape (`pattern`, optional `reason`, optional `allowedFiles`) as the existing `banned_usage_config.dart` entries. The rule visits `ExportDirective` nodes via `context.addExportDirective`, resolves the directive's URI string (`node.uri.stringValue`), and matches it against the configured glob/prefix patterns.

### Should flag (bad code)

```dart
// analysis_options_custom.yaml:
// banned_exports:
//   - pattern: "src/internal/**"
//     reason: "Internal implementation files must not be part of the public API."

// lib/my_package.dart
export 'src/internal/experimental_cache.dart'; // LINT — matches src/internal/** pattern
export 'src/public_api.dart'; // OK
```

### Should pass (good code)

```dart
// lib/my_package.dart
export 'src/public_api.dart'; // OK — not in the ban list
export 'src/models/user.dart' hide InternalUserField; // OK — combinator already narrows the surface
```

---

## Proposed Tier

Tier: Comprehensive
Justification: empty-by-default config surface with zero signal until a team configures a ban list, matching the reasoning for `avoid_banned_annotations` and the existing `banned_identifier_usage`. Not appropriate for a lower tier since it produces zero diagnostics for any project that hasn't opted in.

---

## Edge Cases

1. **`show`/`hide` combinators on an export that already narrows the leaked surface** — should the rule still flag the directive if the export URI matches but a `hide` combinator excludes the specific banned symbol? For v1, match on URI only (matching DCM's behavior) and treat combinator-aware exclusion as a documented limitation — file-level export bans are the common case and combinator-aware filtering adds meaningful complexity for a narrow benefit.
2. **`allowedFiles` overrides for a migration window** — a banned export pattern used inside a designated legacy barrel file (e.g. `lib/legacy.dart`) during a staged deprecation should not report, reusing the same `allowedFiles` glob mechanism as `banned_identifier_usage` and the sibling `avoid_banned_imports`/`avoid_banned_annotations` proposals so all four config-driven ban rules share one parsing/matching utility.
3. **Conditional exports (`export 'x.dart' if (dart.library.io) 'y.dart';`)** — the rule should check both the primary URI and each `Configuration`'s URI, since a banned library could be leaked only under a specific platform condition and a check that only inspects the primary URI would miss it.

---

## Alternatives Considered

- **A single generic `banned_directives` rule covering both `import` and `export`** — rejected in favor of separate `avoid_banned_imports`/`avoid_banned_exports` rules (matching DCM's own split) because import bans and export bans answer different questions (what a file may depend on, vs. what a library exposes) and teams frequently want one enabled without the other — e.g. banning specific third-party imports project-wide while only banning internal-path exports from public barrel files.
- **Path-based static analysis outside the analyzer plugin (e.g. a standalone script scanning barrel files)** — rejected because it would run outside the IDE feedback loop and CI gate that all other saropa_lints rules share; a `custom_lint`/analyzer-plugin rule surfaces the violation at edit time, not just at a separate CI step.

---

## Decision

---

## Implementation Notes

---

## Commits
