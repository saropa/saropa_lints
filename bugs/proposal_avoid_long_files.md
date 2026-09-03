# PROPOSAL: Flag Files Exceeding a Configurable Line-Count Budget

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_long_functions` (existing, DCM-parity)

---

## Summary

Add `avoid_long_files` to flag any `.dart` file whose line count exceeds a configurable threshold (default 500 lines) — an oversized file is a strong signal that a class or a set of loosely-related top-level declarations has accumulated more responsibility than a single file, and future readability/reviewer editor should split it before it grows further.

**Closes gap:** many_lints `avoid_long_files` (configurable line-count budget). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

Line count is a crude but effective proxy for "this file has grown past what one person can hold in their head while reviewing a diff." Saropa already enforces per-function and per-parameter budgets (`avoid_long_functions`, `≤3 parameters`); a file-level budget closes the remaining gap at the next level up, catching files that stay under the function-length limit individually but accumulate dozens of small functions/classes into one unmanageable file.

---

## Detection / Behavior

Report once per file (not per-declaration) when total non-blank, non-comment-only line count exceeds the configured `max_lines` threshold (project-configurable via `analysis_options_custom.yaml`; default 500).

### Should flag (bad code)

```dart
// lib/src/services/mega_service.dart — 812 lines, 40 unrelated methods
// LINT reported once at file/library level: file exceeds max_lines (500)
```

### Should pass (good code)

```dart
// lib/src/services/user_service.dart — 180 lines, cohesive single responsibility
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Configurable threshold rule with legitimate project-by-project variance (generated-adjacent hand-written files, barrel files with many small classes); appropriate for opt-in deep-review rather than default-on, matching saropa's placement for other configurable-budget style rules.

---

## Edge Cases

1. **Barrel/export-only files (`all_rules.dart`-style, all lines are `export '...';`)** — should pass; export statements should not count toward the budget, or the rule should exclude files where >90% of lines are `export`/`import` directives.
2. **Files with a large embedded data table (e.g. a long `Map` of static configuration)** — needs discussion; document the recommended mitigation (move the data to a `.json`/`.yaml` asset or a dedicated `_data.dart` file) rather than special-casing large literals in the rule itself.
3. **Generated code (`.g.dart`, `.freezed.dart`)** — should pass; standard generated-file suppression applies.
4. **File just over the threshold by a handful of lines due to license header/DartDoc comments** — should pass if comment-only and blank lines are excluded from the count, as specified in Detection/Behavior.

---

## Alternatives Considered

- **Count total lines including comments/blank lines** — rejected; would over-penalize well-documented files (matching saropa's global CLAUDE.md rule to write dense comments) relative to under-documented ones, which is the wrong incentive.
- **Fixed, non-configurable threshold** — rejected; file-size tolerance varies meaningfully by project and file role (a rule-registry barrel file vs. a business-logic service), so the threshold must be project-configurable.

---

## Decision

---

## Implementation Notes

---

## Commits
