# BUG: infra - CHANGELOG links to saropa.com not yet added

**Status: Open**

Created: 2026-11-26
Full description and completed steps: `plans/history/2026.11/2026.11.26/infra_docs_changelog_no_backlink_to_saropa_com.md`

Do not ship a saropa.com link until the URL returns HTTP 200. `https://saropa.com/developers/saropa-lints/changelog/` returned HTTP 404 on 2026-11-26.

| Open item | Blocker |
|---|---|
| a. Header line in `CHANGELOG.md`: `Full release history: <https://saropa.com/developers/saropa-lints/changelog/>` | Page must return HTTP 200; owner decision on one slug versus rewriting it in the extension copy (`copy_changelog_to_extension`). Proposed: one slug, `saropa-lints` |
| b. Per-release link (`/changelog/#vX-Y-Z`, archives `/changelog/N.x/#vX-Y-Z`), maintenance comment, `scripts/modules/_version_changelog.py`, `scripts/modules/tests/test_changelog_overview.py`, `scripts/changelog/split_changelog_archive.py`, `scripts/changelog/compact_changelog_archive.py`, `scripts/hooks/changelog_guard.py` | Same two blockers |
| d. Optional: archives only on saropa.com | Owner decision; archive pages must be live |
| Acceptance: new `homepage` visible on pub.dev and the Marketplace | The next publish |
