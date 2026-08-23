# Issue Report Guide: Rename and Feature Request Support

`bugs/BUG_REPORT_GUIDE.md` covered only bug reports (false positives, false negatives, crashes, wrong fixes, performance). Feature requests and new-rule proposals had no dedicated process or template, leaving contributors to file them ad hoc or omit the required attribution/reproduction structure.

## Changes Made

### File 1: `bugs/BUG_REPORT_GUIDE.md` → `bugs/ISSUE_REPORT_GUIDE.md`

Renamed via `git mv` to reflect the broadened scope.

### File 2: `bugs/ISSUE_REPORT_GUIDE.md` (content)

- Title and intro updated to cover bugs and feature requests.
- File naming table extended with four new patterns: `proposal_rule_name.md` (new rule), `proposal_fix_rule_name_description.md` (quick fix request), `proposal_infra_description.md` (tooling/infra), `proposal_tier_rule_name_description.md` (tier change).
- New **Feature Request Template** section added, mirroring the existing Bug Report Template structure (Summary, Motivation, Detection/Behavior with bad/good examples, Proposed Tier, Edge Cases, Alternatives Considered, Decision, Implementation Notes, Commits).
- New **Feature Request Categories** section added (New Rule Proposal, Quick Fix Request, Tier Change, Tooling/Infrastructure Request) with evaluation criteria for each, placed alongside the existing Bug Categories section.
- Lifecycle section split into two diagrams: bugs keep `Open → Investigating → Fix Ready → Closed`; feature requests get `Open → Accepted → In Progress → Closed` with a `Declined` branch.
- History archival, linking, and policy-note sections updated to reference proposals alongside bugs.

### File 3: `scripts/modules/_rule_metrics.py` (line 748)

**Before:**
```python
"BUG_REPORT_GUIDE.MD",
```

**After:**
```python
"ISSUE_REPORT_GUIDE.MD",
```

`_ROOT_MD_EXCLUDED_FROM_UNSOLVED` excludes process-documentation filenames from the root-level unsolved-bug count; the constant needed to track the rename or the guide file itself would start being miscounted as an unsolved issue.

## Tests Added

None — no test references `BUG_REPORT_GUIDE`/`ISSUE_REPORT_GUIDE` or the `_ROOT_MD_EXCLUDED_FROM_UNSOLVED` constant (confirmed by grep against `test/`).

## Verification

- `grep -rn "BUG_REPORT_GUIDE" .` — remaining matches are all inside `plans/history/` (archived, left as historical record) and `CHANGELOG_ARCHIVE.md` (immutable archive); no live code or doc references the old name.

## Finish Report (2026-08-23)

### Hardened reflection items

- **Archival path corrected.** The inherited "Moving to History" section documented `bugs/history/YYYYMMDD/` — a path that does not match actual archival practice (`plans/history/YYYY.MM/YYYYMMDD/`, per the `/finish` skill's LINTER VARIANT Section 6 and the precedent set by this very report). No `bugs/history/` directory has ever existed in the repo, meaning `_collect_bug_categories`'s GREEN "History" branch was dead code for root-level bug files. The guide now points at `plans/history/YYYY.MM/YYYYMMDD/` for both bug and proposal archival, matching the tooling that actually runs.
- **Tooling audited, not just the exclusion constant.** `_collect_bug_categories` (`scripts/modules/_rule_metrics.py`) was read in full to confirm how it parses root-level `bugs/*.md` files. Before this pass it counted every non-guide root `.md` file — bug or proposal — into one `"Unsolved"` (RED) bucket, so the two `proposal_*.md` files already present in `bugs/` were silently inflating the bug count.

### Unrequested feature implemented

`_collect_bug_categories` now splits root-level files by the `proposal_` filename prefix (the convention this guide documents) into two categories: `"Unsolved"` (RED, actual bugs) and `"Open Proposals"` (CYAN, feature requests). `_collect_bug_rows` labels proposal rows with an `"Issues -"` prefix instead of `"Bug Reports -"` so the roadmap display does not misread proposals as bugs.

### Tests Added

`scripts/modules/tests/test_rule_metrics.py`: new `BugCategorySplitTests` class, 4 tests using isolated `tempfile.TemporaryDirectory()` fixtures (not the live `bugs/` dir, to stay deterministic regardless of what's currently filed):
- `test_proposals_and_bugs_counted_separately` — mixed bug/proposal files split into correct counts.
- `test_guide_files_excluded_from_both_buckets` — `ISSUE_REPORT_GUIDE.md`/`FINISH_GUIDE.md` excluded from both buckets.
- `test_only_proposals_present_omits_unsolved_category` — no bugs present → no `"Unsolved"` category emitted.
- `test_only_bugs_present_omits_proposals_category` — no proposals present → no `"Open Proposals"` category emitted.

All 13 tests in `test_rule_metrics.py` pass (`python -m unittest scripts.modules.tests.test_rule_metrics`). Manually verified against the live `bugs/` directory: reports `Open Proposals 2`, no `Unsolved` entry (matches the two `proposal_*.md` files currently filed).

### Changelog

Not updated. This change has no pub.dev/Marketplace-visible impact (contributor-facing process docs and an internal roadmap-display script) — the project's Maintenance-entry convention requires only end-user-visible changes at the top level, and this qualifies for neither top-level nor Maintenance placement. `CHANGELOG.md` was also under concurrent unrelated edit (an `[Unreleased]` section added by other in-flight work) during this session, so it was left untouched to avoid collision.

## Finish Report (2026-08-23, round 2)

### Hardened reflection items (round 2)

- **CYAN collision audited.** Grepped `_rule_metrics.py` for every `Color.CYAN` and `"Unsolved"`/`"Open Proposals"` string-literal usage. CYAN is used independently in three other unrelated contexts (`MODERATE` severity label, a fixture-TODO count threshold, a generic default-color fallback) with no shared parsing — no collision with the new "Open Proposals" category.
- **Downstream consumers of `_collect_bug_categories` output checked.** Only two callers exist: `_collect_bug_rows` (this module) and, transitively, `display_roadmap_summary` via `_publish_workflow.py`'s `print_package_banner`. No README badge sync or other script parses the `_BugCategory` label strings by exact match outside this file.

### Unrequested feature implemented (with CLI docs)

Added a `--bugs-only` / `--proposals-only` filter, requested in the prior round's handoff reflection as "a filter flag for contributors who only care about one queue":

- `_collect_bug_rows(bugs_dir, *, only=None)` — `only="bugs"` drops the `"Open Proposals"` category; `only="proposals"` keeps only it.
- `display_roadmap_summary(project_dir, *, bugs_dir=None, issue_filter=None)` — new `issue_filter` param (`None` / `"bugs"` / `"proposals"`). When set, skips the roadmap-rule and fixture-TODO scan entirely (faster, focused output) and restricts `bugs_dir` rows via `_collect_bug_rows`'s `only=`. Raises `ValueError` on an unrecognized value. The footer line switches from `"Total remaining: N roadmap rules"` to `"Total: N bugs"` / `"Total: N proposals"` when filtered. Default behavior (`issue_filter=None`) is unchanged — `_publish_workflow.py`'s existing call site is untouched and was re-verified to produce identical output.
- New standalone CLI `scripts/roadmap_status.py` — argparse-based (matching `run_extension_local.py`'s style), wraps `display_roadmap_summary` so contributors can check outstanding work without the interactive `publish.py` menu. Flags: `--bugs-only`, `--proposals-only` (mutually exclusive, enforced via `p.error(...)`), `--version`. Calls `enable_ansi_support()` before printing — omitting it initially caused a `UnicodeEncodeError` on the Windows cp1252 console when printing the bar-chart glyphs; discovered and fixed during manual testing. Also avoided em-dashes in the module docstring (used as the argparse `epilog`) after confirming the same encoding issue crashes `--help` in the pre-existing sibling script `run_extension_local.py --help` on this console — a plain-ASCII docstring sidesteps it in the new file without touching shared infrastructure.

### CLI docs updated

`scripts/README.md`: added a "Check outstanding bugs/proposals without the full publish menu" section with usage examples and a link to `bugs/ISSUE_REPORT_GUIDE.md`'s naming convention, plus a new row in the "Scripts in this directory that can run independently" table.

### Tests Added (round 2)

`scripts/modules/tests/test_rule_metrics.py`:
- `BugCategorySplitTests.test_collect_bug_rows_bugs_only_excludes_proposals` / `test_collect_bug_rows_proposals_only_excludes_bugs` — verify the `only=` filter on `_collect_bug_rows`, including the `"Issues -"` vs `"Bug Reports -"` label prefix.
- `RoadmapSummaryIssueFilterTests.test_invalid_issue_filter_raises` — bad `issue_filter` value raises `ValueError`.
- `RoadmapSummaryIssueFilterTests.test_bugs_filter_without_bugs_dir_shows_no_items` — filtered mode with no `bugs_dir` produces an empty report rather than silently falling back to full output.

All 17 tests in `test_rule_metrics.py` pass; full suite (`python -m unittest discover -s scripts/modules/tests -t .`) — 138 tests, all pass. Manually verified `scripts/roadmap_status.py` (default, `--bugs-only`, `--proposals-only`, `--help`, and the mutual-exclusivity error) against the live `bugs/` directory.

### Changelog (round 2)

Added a Maintenance-block bullet pair to `CHANGELOG.md`'s `[Unreleased]` section for both rounds of this work (guide rename/split, `roadmap_status.py` CLI) — qualifies as "developer scripts" under the project's Maintenance convention. **Not committed**: `[Unreleased]` also carries two `### Added` bullets from unrelated concurrent in-flight work (new rules `prefer_primary_constructor` / `require_sdk_syntax_match`, whose implementation files are still untracked). Committing the whole file would pull in someone else's unfinished entry; a manual patch-split was judged too error-prone to do safely. The Maintenance bullets remain as an uncommitted, well-formed edit in the working tree, ready to land whenever that file's next legitimate commit happens.

## Commits

- `0a22d630` docs: rename bug report guide to issue report guide, add feature request support
- (pending — round 2 commit, see below)
