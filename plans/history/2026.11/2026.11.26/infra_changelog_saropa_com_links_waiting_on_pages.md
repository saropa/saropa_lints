# BUG: infra - CHANGELOG links to saropa.com not yet added

**Status: Closed** (archived and handed off; links NOT added)

Created: 2026-11-26
Full description and completed steps: `plans/history/2026.11/2026.11.26/infra_docs_changelog_no_backlink_to_saropa_com.md`

Slug decision: the Dart package and the VS Code extension both link to `saropa-lints`. No slug rewrite in `copy_changelog_to_extension`.

Request filed for the pages: `d:\src\saropa.com\bugs\20261126_saropa_lints_changelog_pages_needed.md`

Do not ship a saropa.com link until the URL returns HTTP 200. `https://saropa.com/developers/saropa-lints/changelog/` returned HTTP 404 on 2026-11-26.

| Open item | Blocker |
|---|---|
| a. Header line in `CHANGELOG.md`: `Full release history: <https://saropa.com/developers/saropa-lints/changelog/>` | Page must return HTTP 200 |
| b. Per-release link (`/changelog/#vX-Y-Z`, archives `/changelog/N.x/#vX-Y-Z`), maintenance comment, `scripts/modules/_version_changelog.py`, `scripts/modules/tests/test_changelog_overview.py`, `scripts/changelog/split_changelog_archive.py`, `scripts/changelog/compact_changelog_archive.py`, `scripts/hooks/changelog_guard.py` | Same blocker |
| d. Optional: archives only on saropa.com | Owner decision; archive pages must be live |
| Acceptance: new `homepage` visible on pub.dev and the Marketplace | The next publish |

## Closing note (2026-11-26)

The owner decided to archive this report. The saropa.com changelog links have NOT been added to saropa_lints. All remaining work in the table above is tracked in `d:\src\saropa.com\bugs\20261126_saropa_lints_changelog_pages_needed.md`, section "Remaining saropa_lints-side work", to be done in saropa_lints once the pages return HTTP 200.
