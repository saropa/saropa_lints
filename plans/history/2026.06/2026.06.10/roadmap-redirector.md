# ROADMAP.md reduced to a redirector

**Trigger (user request, verbatim):** "is everything in the roadmap (\ROADMAP.md) covered by a plan in \plans\? change the roadmap to simply point the the plans folder on github. remove everything except for the redirector."

The roadmap had drifted out of sync with the `plans/` tree it was supposed to summarize, so the inline copy was replaced with a short pointer to the GitHub `plans/` folder.

## Finish Report (2026-06-10)

### Scope
(C) docs only. No Dart rules, analyzer plugin, tests, fixtures, or `analysis_options*.yaml` touched.

### Answer to the user's question (coverage)
No — `ROADMAP.md` and `plans/` were not in sync, in both directions:
- **ROADMAP content with no backing plan** (inline-only): Part 3 build backlog (the 25 cross-file/project-graph rule tables, #9–#25), the Part 2 "Platform Config Cross-Reference" pattern bucket, and the "Stylistic Rule Pairs and Overlaps" table.
- **ROADMAP links to plan files that no longer exist** (moved to `plans/history/` or deleted): `plans/discussion_056_suppression_tracking.md`, `plans/PROJECT_HEALTH_DASHBOARD_PLAN.md`, `plans/UX_GUIDELINES.md`, `plans/EXTENSION_LOCALIZATION_GUIDE.md`.

### Change made
- `ROADMAP.md`: replaced the entire file (256 lines) with a ~10-line redirector pointing at the GitHub `plans/`, `plans/deferred/`, and `plans/history/` folders, plus links to CHANGELOG and CONTRIBUTING.
- `CHANGELOG.md`: added a Maintenance `<details>` bullet under `[Unreleased]` recording the reduction (no end-user impact → Maintenance, not Added/Changed/Fixed).

### Tooling-coupling verification (why the gut is safe)
- The old `AUTO-SYNC` header named `sync_roadmap_header()`; that function no longer exists anywhere in `scripts/` (grep returned nothing). The header comment was already stale, so removing it loses nothing live.
- The only live consumer is `get_roadmap_summary()` / `_count_roadmap_rules_by_severity()` in `scripts/modules/_rule_metrics.py`, which parses ROADMAP tables for a remaining-rules display count. After the gut it counts 0 — display-only, no error, no publish gate.
- `_audit.py` / `_audit_checks.py` extract rule names from ROADMAP tables to flag "rule already implemented but still listed." With no tables, that audit finds 0 entries and passes trivially — it no longer catches that drift, but it does not error.

### Test audit (Section 4A)
- `grep ROADMAP test/` → one hit: `test/integrity/roadmap_15_rules_test.dart`. It reads the fixture `example/lib/roadmap_15_rules_fixture.dart`, never `ROADMAP.md`. Unaffected by this change. No test pins ROADMAP.md content.

### Known follow-up (NOT done — surfaced for permission)
Four ACTIVE in-repo links point at ROADMAP anchors the gut removed; they now degrade to the top of the redirector (GitHub resolves a missing anchor to the file top) rather than hard-404:
- `README.md:885` → `ROADMAP.md#cross-file-cli-improvements`
- `README.md:1443` → `ROADMAP.md#part-2-deferred-rules--technical-limitations`
- `LINKS.md:13` → `ROADMAP.md#part-2-deferred-rules--technical-limitations`
- `plans/deferred/plan_additional_rules_41_through_50.md:3` → `ROADMAP.md#additional-rules`

History/CHANGELOG_ARCHIVE references to ROADMAP anchors are historical and were left as-is.
