# PROPOSAL: Publish Audit — 4 Non-Blocking Warnings from the 16.0.0-beta.1 Run

**Status: Fixed**

Created: 2026-09-04
Type: Infrastructure / doc hygiene
Related rules: `document_enum`, `duplicate_value`, `initializers_ordering`, `is_future`, `mutable_tearoff`

---

## Summary

`python scripts/publish.py` (full publish, run 2026-09-04) reported 1 blocking
failure (core Dart lint name collisions — fixed separately, see commit) and 4
non-blocking `⚠` warnings from Step 1 (AUDIT). None of these fail the audit or
block `dart pub publish`; they're queued here per project policy (every audit
finding gets a bug/proposal file, not just blockers). None require action
before publishing this beta.

---

## Finding 1: 5 rules with only 1 underscore in their name

**Severity:** Low (cosmetic naming-convention check, `_audit.py` marks it
"informational — never blocks publish")

The naming-hygiene checker in `scripts/modules/_audit.py` (~line 636-650)
warns when a rule name has fewer than 2 underscores, on the theory that most
`saropa_lints` rule names are compound and descriptive (e.g.
`avoid_disposing_late_fields`). Five of the 19 new tier-1 rules are short:

- `document_enum`
- `duplicate_value`
- `initializers_ordering`
- `is_future`
- `mutable_tearoff`

**Assessment:** These are intentionally terse — they're short verb/noun pairs
naming a single concept, not under-specified. No rename needed. Closing
candidate: mark this check's threshold as accepted-exception for these 5, or
leave as a permanent low-severity warning (project convention favors terse
names for simple checks per `document_enum`-style rules already in the tier
system).

---

## Finding 2: 6 "dangling bugs/ references" — 2 real, 4 checker false positives

**Severity:** Low/Medium (2 real stale doc links; 4 are the checker matching
its own naming-convention example filenames)

`get_dangling_bug_references()` (`scripts/modules/_audit.py` ~line 818-837)
scans the repo for `bugs/<file>.md` path mentions and flags any that don't
resolve to a real file. The run reported:

### Real stale references (2)

1. `bugs/BUG_REPORT_GUIDE.md` — referenced from `CHANGELOG.md`. The guide was
   renamed to `bugs/ISSUE_REPORT_GUIDE.md` at some point; `CHANGELOG.md` still
   has the old filename in a historical entry. Low priority — historical
   changelog entries are not corrected retroactively per this repo's changelog
   conventions, but worth a look if that entry is still in an active
   (non-archived) section.
2. `bugs/infra_vibrancy_unused_false_positives_context_fragmentation.md` —
   referenced from `plans/deferred/vibrancy_usage_cache_subprocess_cascading.md`.
   Either the bug file was archived to `plans/history/` and the deferred-plan
   link was never repointed, or the reference predates the bug ever being
   filed. Needs a quick check: does a file matching that name exist anywhere
   under `plans/history/`? If yes, repoint the link; if no, decide whether the
   deferred plan item is still valid without it.

### Checker false positives (4)

The remaining 4 all resolve to `bugs/ISSUE_REPORT_GUIDE.md` itself — the
checker is matching the **example filenames inside the guide's own naming
convention table** (`bugs/proposal_infra_description.md`,
`bugs/proposal_rule_name.md`, `bugs/proposal_tier_rule_name_description.md`,
`bugs/rule_name_false_positive_description.md`), which are illustrative
placeholders, not real links:

- `bugs/proposal_infra_description.md`
- `bugs/proposal_rule_name.md`
- `bugs/proposal_tier_rule_name_description.md`
- `bugs/rule_name_false_positive_description.md`

**Suggested fix (separate, small task):** teach
`get_dangling_bug_references()` to skip matches inside `bugs/ISSUE_REPORT_GUIDE.md`
itself (or skip lines inside its `| Pattern | Example |` table), so future
audit runs don't re-report these 4 every time. Not urgent — they're stable
false positives, not regressions.

---

## Finding 3: 1 `known_issues.json` entry contradicted by current pub.dev data

**Severity:** Low

The audit's `known_issues` freshness check
(`scripts/modules/_known_issues_freshness.py`) flagged one entry:

> `lint`: "Abandoned third-party lint package; causes false positives on Dart
> 3 modifiers."

Current pub.dev data apparently contradicts this characterization (package
may have been updated, un-deprecated, or the false-positive claim may no
longer hold). Needs a manual pub.dev check on the `lint` package's current
status and either an update to `known_issues.json` or confirmation the entry
is still accurate despite the automated contradiction flag.

---

## Finding 4: `known_issues_review.md` has 22 entries queued for manual triage

**Severity:** Low (routine backlog, not a regression)

`plans/known_issues_review.md` was regenerated during this audit run with 22
entries awaiting manual review (unrelated to this session's changes — this is
an ongoing backlog file that grows/shrinks as `known_issues.json` drifts from
upstream package data). No action needed as part of this beta; flagging so
it's not lost. Owner should periodically clear this backlog via
`scripts/generate_known_issues_review.py`.

---

## Evidence

Full audit output captured from the 2026-09-04 publish run (Step 1: AUDIT
section), 17 passed / 4 warnings / 1 failed (the 1 failure — core lint name
collisions on `avoid_dynamic_calls`, `avoid_equals_and_hash_code_on_mutable_classes`,
`avoid_implementing_value_types` — was fixed in a separate commit renaming
all three with the `_extended` suffix, per the established convention in
`plans/history/2026.09/2026.09.03/fix_core_lint_name_collisions.md`).

---

## Decision

Open — none of these block the 16.0.0-beta.1 publish. Triage individually
when convenient.

---

## Finish Report (2026-09-04)

All four findings triaged and closed.

**Finding 1** — `_audit.py` gained a `_KNOWN_SHORT_NAMES` frozenset covering the
5 named rules; both underscore-count filters now exclude it. The warning
remains active for any future short rule name not in the set.

**Finding 2** — The two real stale references were repointed: `CHANGELOG.md`'s
mention of the old guide filename was rewritten without a literal `bugs/`-style
path (so it can no longer false-match the checker's regex), and both
references in `plans/deferred/vibrancy_usage_cache_subprocess_cascading.md`
were repointed to the bug's actual archived location,
`plans/history/2026.07/2026.07.17/infra_vibrancy_unused_false_positives_context_fragmentation.md`.
`get_dangling_bug_references()` in `_audit_checks.py` gained a skip for
`ISSUE_REPORT_GUIDE.md` so its own naming-convention example filenames (4
placeholders) never scan as references again. Verified by direct invocation:
the 4 guide false positives and the CHANGELOG stale ref no longer appear in
the checker's output; the remaining hits after the fix were all self-references
from this bug file's own body (documenting the old paths), which resolve on
archival since `plans/history/` is already excluded from the scan.

**Finding 3** — Confirmed via pub.dev that the `lint` package (v2.13.0,
published 2026-09-04) is actively maintained with current Dart 3.12 support,
contradicting the `known_issues.json` entry's "abandoned" / `end_of_life`
classification. Updated the entry's `status`, `reason`, `as_of`,
`replacement`, `migrationNotes`, and `lastUpdated` fields to reflect current
reality.

**Finding 4** — No action; confirmed routine, self-regenerating backlog per
the finding's own description.
