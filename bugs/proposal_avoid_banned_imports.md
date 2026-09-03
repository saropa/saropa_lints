# PROPOSAL: Config-Driven Banned Import Statements

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `banned_identifier_usage` (sibling config-driven ban mechanism for identifier references); `avoid_banned_exports` (sibling proposal for the export-side directive)

---

## Summary

Add a config-driven rule that flags `import` directives whose target library URI matches a project-configured ban list, letting a team block specific packages, internal modules, or deprecated libraries from being imported anywhere (or anywhere outside an allowlisted set of files).

**Closes gap:** DCM `avoid-banned-imports` (dcm.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "DCM proper" TRUE GAPS section.

---

## Motivation

Large Dart/Flutter codebases frequently need to ban specific imports project-wide: a deprecated internal utility module scheduled for deletion, a third-party package the team has decided to migrate away from (e.g. banning `intl` in favor of an in-house localization layer, or banning `dart:io` in code meant to run on web), or a package with a known security issue pending an upgrade. Today the only saropa_lints mechanism anywhere close to this is `banned_identifier_usage`, which matches `SimpleIdentifier` nodes — it has no visibility into `ImportDirective` nodes at all, so a team cannot express "ban importing package X" without banning every identifier that happens to share a name with something in that package, which is both imprecise and produces the diagnostic on the wrong line.

This is also the single most independently-repeated gap theme in the competitive audit (`plans/GAP_ANALYSIS.md` Gap Theme 2): at least six competitor packages (many_lints, import_lint, team_guard, clean_architecture_kit, architecture_lints, subpackage_lint) each independently built some form of configurable import-banning mechanism, because it is a near-universal need in team-governed codebases. This proposal scopes the smallest, most directly comparable piece — DCM's flat `avoid-banned-imports` ban list — rather than the much larger generic N-layer architecture-boundary engine several of those competitors also built (tracked separately, out of scope here).

---

## Detection / Behavior

Config-driven via a new `banned_imports` key in `analysis_options_custom.yaml`, matching the entry shape of the existing `banned_usage_config.dart` (`pattern`, optional `reason`, optional `allowedFiles`). The rule visits `ImportDirective` nodes via `context.addImportDirective`, resolves `node.uri.stringValue`, and matches it against the configured patterns (exact string, package-prefix, or glob).

### Should flag (bad code)

```dart
// analysis_options_custom.yaml:
// banned_imports:
//   - pattern: "package:intl/intl.dart"
//     reason: "Use lib/src/l10n/l10n.dart instead of the intl package directly."

import 'package:intl/intl.dart'; // LINT — banned import
```

### Should pass (good code)

```dart
import '../l10n/l10n.dart'; // OK — the approved in-house wrapper
```

---

## Proposed Tier

Tier: Comprehensive
Justification: empty-by-default config surface — produces zero diagnostics for any project that has not opted in, consistent with the tier placement of the sibling `banned_identifier_usage` rule and the other `avoid_banned_*` proposals in this batch.

---

## Edge Cases

1. **`allowedFiles` for a migration boundary** — a banned import used only inside the designated wrapper file that re-exports the safe alternative (e.g. `lib/src/l10n/l10n.dart` itself legitimately imports `package:intl/intl.dart`) must not self-flag; reuse the same `allowedFiles` glob mechanism as `banned_identifier_usage` so one config parsing path serves all the ban-list rules in this family.
2. **`import ... as prefix` and `deferred` imports** — the rule must match on the URI, not the prefix or any usage of the prefix, so `import 'package:intl/intl.dart' as fmt;` is caught by the same pattern regardless of the alias chosen; matching an aliased usage site (like `banned_identifier_usage` would attempt) is explicitly out of scope here since the directive itself is the violation.
3. **Relative vs. package URI equivalence** — a pattern written as `package:my_app/src/legacy/old_api.dart` should also match the same file imported via a relative path (`../legacy/old_api.dart`) from within the same package, otherwise the ban is trivially bypassed by switching import styles; resolving both to a canonical form (or documenting relative-import bans as a known limitation of v1) needs to be decided during implementation.

---

## Alternatives Considered

- **Building the full generic N-layer architecture-boundary engine** (as `architecture_lints`, `clean_architecture_kit`, and `import_lint` each did) — explicitly out of scope for this proposal. That is Gap Theme 2 in `plans/GAP_ANALYSIS.md`, a materially larger feature (a project-defined component graph with layer rules), and deserves its own proposal and design discussion rather than being bundled into a flat DCM-equivalent ban list.
- **Reusing `banned_identifier_usage`'s identifier-matching for import URIs by treating the URI string as a banned "identifier"** — rejected: `ImportDirective.uri` is a `StringLiteral`, not a `SimpleIdentifier`, so it is invisible to that rule's `addSimpleIdentifier` registry today, and conflating "banned identifier text" with "banned import path" would produce a confusing single rule that reports on two structurally unrelated node kinds.

---

## Decision

---

## Implementation Notes

---

## Commits
