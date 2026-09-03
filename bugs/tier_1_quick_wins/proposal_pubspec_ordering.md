# PROPOSAL: Flag Non-Canonical Key/Dependency Ordering in pubspec.yaml

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Add `pubspec_ordering` to flag a `pubspec.yaml` whose top-level keys are not in canonical order (`name`, `description`, `publish_to`, `version`, `environment`, `dependencies`, `dev_dependencies`, `flutter`, etc.) or whose `dependencies:`/`dev_dependencies:` entries are not alphabetized within their block. This is a YAML-file-level check, not a Dart-AST check, and is unusual for saropa_lints, whose rule engine is built primarily around Dart source analysis.

**Closes gap:** flutter_skill_lints `pubspec_ordering` (github.com/sgaabdu4/flutter_skill_lints). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

`pubspec.yaml` accumulates entries over a project's lifetime with no enforced order — new dependencies get appended wherever a contributor happens to place them, `dev_dependencies` sometimes ends up above `dependencies`, and packages within a block end up in whatever order they were added rather than alphabetically. This has no functional effect on the build, but it makes diffs noisy (an unrelated PR that adds one dependency touches unrelated lines because the "right" insertion point is ambiguous without a canonical order) and makes manually auditing the dependency list slower than it needs to be. flutter_skill_lints ships this as a small, mechanical hygiene check; it is cheap to implement and has zero false-positive risk once the canonical order is fixed.

---

## Detection / Behavior

Parse `pubspec.yaml` as YAML (not Dart source) and check:
1. Top-level keys appear in the canonical order: `name`, `description`, `publish_to`, `version`, `environment`, `dependencies`, `dev_dependencies`, `flutter`, followed by any other keys in their existing relative order (keys not in the canonical list are not reordered relative to each other, only checked against the fixed set's position).
2. Within `dependencies:` and within `dev_dependencies:`, package entries are alphabetized by key (case-insensitive), except that SDK-sourced entries (`flutter`, `flutter_test` under `sdk: flutter`) may be pinned to the top of their block per common convention — document this as a configurable exception.

### Should flag (bad code)

```yaml
name: my_app
dev_dependencies:      # LINT — dev_dependencies appears before dependencies (wrong top-level order)
  flutter_test:
    sdk: flutter
version: 1.0.0          # LINT — version appears after dev_dependencies instead of before dependencies
dependencies:
  http: ^1.0.0
  cupertino_icons: ^1.0.0  # LINT — not alphabetized; "cupertino_icons" should precede "http"
```

### Should pass (good code)

```yaml
name: my_app
description: An app.
version: 1.0.0
environment:
  sdk: ^3.5.0
dependencies:
  cupertino_icons: ^1.0.0
  http: ^1.0.0
dev_dependencies:
  flutter_test:
    sdk: flutter
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Purely cosmetic/hygiene — no correctness impact — but genuinely useful for reducing diff noise in larger teams. Not a Dart-AST rule, so it sits outside saropa_lints' core analyzer-plugin hot path regardless of tier; Comprehensive matches other low-urgency hygiene rules.

---

## Edge Cases

1. **`pubspec.yaml` with only `name` and `dependencies:` (minimal package)** — should pass if the two keys that exist are in canonical relative order.
2. **A key not in the canonical list at all** (e.g. a custom `saropa_lints:` config block, or `flutter_intl:`) — should not be flagged for its own position beyond "does not disrupt the canonical keys' relative order"; document exactly how unknown keys interact with the ordering check to avoid false positives on legitimate custom top-level keys.
3. **Git-style conflict markers or comments interspersed between entries** — should not crash the YAML parser; skip files that fail to parse cleanly rather than reporting spurious violations.
4. **Path/git dependencies with nested maps** (`http: {path: ../http}`) — alphabetization should sort by the top-level package key only, ignoring the nested value shape.
5. **`dependency_overrides:` block** — should apply the same alphabetization check as `dependencies:`/`dev_dependencies:`, positioned after `dev_dependencies` and before `flutter` in canonical order.
6. **melos/monorepo-managed `pubspec.yaml` with tool-injected keys** — should be excludable via the standard saropa_lints file-exclusion configuration if the injected keys create unavoidable false positives.

---

## Alternatives Considered

- **Implement via a Dart-AST-adjacent trick (parse pubspec.yaml as a String constant somewhere)** — rejected; there is no legitimate way to shoehorn a YAML-structural check into the Dart AST visitor pipeline saropa_lints rules normally run on. This rule needs its own YAML-file-level check surface, distinct from `DartLintRule`/`SaropaLintRule`'s AST-node visitors.
- **Skip alphabetization within blocks, only check top-level key order** — considered as a smaller first cut, but rejected because the alphabetization check is the more commonly-cited value of this class of rule (top-level key order rarely drifts once set, but individual dependency entries drift constantly as packages are added over time).

---

## Decision

---

## Implementation Notes

This is architecturally unusual for saropa_lints: confirmed via `Grep` across `lib/src/` that there is currently no dedicated pubspec.yaml-parsing utility in the codebase (only Dart-AST-facing rule infrastructure exists). Implementing this rule requires either (a) a new YAML-aware rule surface that runs independently of the Dart analyzer-plugin visitor pipeline (e.g. a file-content check hooked in alongside the existing `analysis_options.yaml`-adjacent config-reading code, if any), or (b) treating it as a `bin/`-level standalone check (similar to `project_health`/`scan` CLI tools) rather than an in-editor squiggle rule, since pubspec.yaml changes are infrequent and don't need live-analyzer feedback. Recommend prototyping option (b) first — a CLI check run at CI/pre-commit time — before committing to wiring a YAML-file rule type into the live analyzer-plugin pipeline, given no existing precedent for non-Dart-AST rules in this codebase.

---

## Commits
