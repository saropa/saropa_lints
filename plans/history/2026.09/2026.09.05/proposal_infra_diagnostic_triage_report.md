# PROPOSAL: Diagnostic triage report — auto-categorize by location, severity, and suggested action

**Status: Fixed**

Created: 2026-09-05
Type: Tooling / Infrastructure
Related rules: N/A (infrastructure, not a rule)

---

## Summary

Add a `scan` output mode (or post-processing script) that auto-triages
diagnostics into a prioritized fix queue, categorized by file location
(`lib/` vs `dependency_overrides/` vs `test/`), severity, and suggested action
(fix vs suppress). Reduces manual triage time for bulk lint sweeps from
~30 minutes to seconds.

---

## Motivation

Bulk lint sweeps in the contacts app regularly produce 80–140 diagnostics across
30+ files. Each sweep currently requires manual triage to decide:

- **Which diagnostics are in app code vs forked third-party code** —
  `dependency_overrides/` files should almost always be suppressed, not fixed.
- **Which diagnostics are in dev/debug code** — `_dev/`, `debug/`, `_developer/`
  files often warrant suppression, not refactoring.
- **Which diagnostics share a pattern** — 20 `require_yield_after_db_write` sites
  are one mechanical fix, not 20 separate decisions.
- **Which are severity-8 (error) vs severity-4 (warning)** — errors should be
  fixed first.

Three consecutive sweeps (2026-09-04 part 1, 2026-09-05 parts 2 and 3) all
required this same manual categorization step before any code changes.

---

## Detection / Behavior

### Input

The existing `dart run saropa_lints scan . --format json` output, or a
VS Code Problems export (`current_issues.json`).

### Output

A structured triage report grouping diagnostics into action buckets:

```
## Priority 1: Errors in app code (fix)
- run_command_location.dart:150 — avoid_context_across_async (sev 8)
- run_command_user_type.dart:73 — avoid_context_across_async (sev 8)

## Priority 2: Warnings in app code — same rule, mechanical fix
- [22 sites] require_yield_after_db_write — add yieldToUI() after DB write

## Priority 3: Warnings in app code — individual triage
- shared_avatar_overlay.dart:193 — require_rtl_layout_support
- country_list_screen.dart:116 — avoid_public_members_in_states

## Priority 4: Warnings in dev/debug code (likely suppress)
- sql_sentinel.dart — 6 diagnostics (dev tool)
- flow_map_navigator_observer.dart — 5 diagnostics (dev tool)

## Priority 5: Warnings in forked code (suppress)
- arb_translate/message_parser.dart — 40 diagnostics
- font_awesome_flutter/fa_icon.dart — 1 diagnostic
```

### Categorization rules

- `dependency_overrides/**` → "forked code, suppress"
- `*/_dev/**`, `*/debug/**`, `*/_developer/**` → "dev/debug code, likely suppress"
- Severity 8 → "error, fix first"
- 5+ diagnostics from the same rule → "bulk mechanical fix"
- Everything else → "individual triage"

---

## Proposed Tier

N/A — infrastructure, not a rule.

---

## Edge Cases

1. **Mixed-location rules** — a rule firing in both `lib/` and
   `dependency_overrides/` should appear in both buckets.
2. **False positives** — the triage report suggests action, not mandates it.
   Each bucket still needs human review.
3. **Custom location patterns** — projects may have different
   "suppress-by-default" directories. Could be configurable.

---

## Alternatives Considered

- **Manual triage in chat** — current approach, works but costs ~30 min per sweep
  and requires an experienced operator.
- **IDE grouping** — VS Code Problems panel can group by file but not by
  "fix vs suppress" heuristic.

---

## Decision

Accepted — implemented as a standalone Python script (`scripts/triage_scan.py`)
that post-processes `--format json` output. No changes to the Dart analyzer
plugin.

---

## Implementation Notes

Could be a new `--format triage` output mode for `dart run saropa_lints scan`,
or a standalone Python script that post-processes `--format json` output. The
Python approach is simpler and doesn't require changes to the analyzer plugin.

---

## Commits

<!-- Add commit hashes as implementation lands -->
