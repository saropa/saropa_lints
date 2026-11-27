# BUG: infra — CHANGELOG has no backlink to saropa.com

**Status: Closed** (completed work archived here; remaining steps are tracked in `d:\src\saropa.com\bugs\20261126_saropa_lints_changelog_pages_needed.md`)

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-11-26
Rule: n/a (documentation and packaging)
File: `CHANGELOG.md`, `extension/CHANGELOG.md`, `pubspec.yaml`, `extension/package.json`
Severity: Low

---

## Summary

The changelog and package metadata of saropa_lints (the Dart package and the VS Code extension) carry no link to saropa.com. saropa.com will publish each tool's full changelog as web pages at `https://saropa.com/developers/<slug>/changelog/` (current major) and `https://saropa.com/developers/<slug>/changelog/<N>.x/` (older majors), with per-release anchors such as `#v9-8-3`. The same text also lives on GitHub, pub.dev and the VS Code Marketplace, and those sites do not allow a canonical pointing elsewhere. With no link back, every mirror copy competes with the saropa.com page instead of pointing at it, so Google has no signal that saropa.com is the original. Background: `D:\src\saropa.com\plans\PLAN_DEVELOPER_CHANGELOGS.md`, section "Being treated as the original source".

---

## Attribution Evidence

```bash
grep -rn "saropa.com/developers" CHANGELOG.md extension/CHANGELOG.md pubspec.yaml extension/package.json
grep -n "^homepage" pubspec.yaml
grep -n '"homepage"' extension/package.json
ls changelog/
```

Findings on 2026-11-26: no `saropa.com/developers` match in any of the four files. `pubspec.yaml` homepage is `https://pub.dev/packages/saropa_lints`. `extension/package.json` homepage is `https://github.com/saropa/saropa_lints#readme`. `changelog/` holds `0.x.md` through `17.x.md`; `CHANGELOG_ARCHIVE.md` is an index of those files. The `CHANGELOG.md` header banner links only to `https://saropa.com` (the home page). Root and extension changelogs differ.

---

## Blocked on

Do not ship any saropa.com link until that URL returns HTTP 200. The pages are not live yet as of 2026-11-26. Check before merging:

```bash
curl -sI https://saropa.com/developers/saropa-lints/changelog/
curl -sI https://saropa.com/developers/saropa-lints/changelog/17.x/
curl -sI https://saropa.com/developers/saropa-lints-vscode/changelog/
curl -sI https://saropa.com/developers/saropa-lints/
```

Every URL must answer `HTTP/... 200`. A 404 means the link is not shippable.

---

## Fix

### a. Header line

Add one line to `CHANGELOG.md` (slug `saropa-lints`) and `extension/CHANGELOG.md` (slug `saropa-lints-vscode`; this file differs from the root copy, so it is edited separately) directly under the title/intro, above the first version heading and outside the HTML maintenance comment:

> Full release history: <https://saropa.com/developers/saropa-lints/changelog/>

Two pages exist. The package changelog (`CHANGELOG.md`) links to `https://saropa.com/developers/saropa-lints/changelog/`. The extension changelog (`extension/CHANGELOG.md`) links to `https://saropa.com/developers/saropa-lints-vscode/changelog/`.

### b. Per-release link

The release-overview convention currently ends each release's opening line with `[log](https://github.com/saropa/saropa_lints/blob/vX.Y.Z/CHANGELOG.md)`. Add a second link after it to `https://saropa.com/developers/<slug>/changelog/#vX-Y-Z`, for example `[log](https://github.com/saropa/saropa_lints/blob/v1.2.3/CHANGELOG.md) · [saropa.com](https://saropa.com/developers/<slug>/changelog/#v1-2-3)`. Apply the same rule in `extension/CHANGELOG.md` with slug `saropa-lints-vscode`. Note: line 59 of `CHANGELOG.md` builds its tag links against `github.com/saropa/saropa-lints` (hyphen) while the repo folder is `saropa_lints`; confirm the repo path the generator uses before copying the pattern.

Anchor rule: take the version, replace every dot with a hyphen, prefix `v` (`9.8.3` becomes `#v9-8-3`). Releases moved into `changelog/N.x.md` use `/changelog/N.x/#vX-Y-Z` (for example `/changelog/16.x/#v16-3-0`); releases still in `CHANGELOG.md` use `/changelog/#vX-Y-Z`. Archive-file entries need the saropa.com link only if the archive files are kept (see step d).

Update the maintenance-comment instructions (or the header note, where no maintenance comment exists) AND the tooling and its tests:

- `scripts/modules/_version_changelog.py`
- `scripts/modules/tests/test_changelog_overview.py`
- `scripts/changelog/split_changelog_archive.py`
- `scripts/changelog/compact_changelog_archive.py`
- `scripts/hooks/changelog_guard.py`

### c. Package metadata

- `pubspec.yaml` line 16: `homepage: https://pub.dev/packages/saropa_lints` becomes `homepage: https://saropa.com/developers/saropa-lints/` (this product page is already live).
- `extension/package.json` line 12: `"homepage": "https://github.com/saropa/saropa_lints#readme"` becomes `"homepage": "https://saropa.com/developers/saropa-lints/"`.
- Keep `repository:` / `issue_tracker:` (pubspec) and `repository` / `bugs` (package.json) as they are.

### d. Optional, owner decision: archives live only on saropa.com

Replace the archive files (`changelog/0.x.md` through `17.x.md`, and the `CHANGELOG_ARCHIVE.md` index) with one line linking to the saropa.com archive pages (`https://saropa.com/developers/saropa-lints/changelog/<N>.x/`). That leaves saropa.com the only full copy of older releases.

Cost: no in-repo search of old releases, and the archive tooling (`split_changelog_archive.py`, `compact_changelog_archive.py`, and the guard in `changelog_guard.py`) and `grep -r <term> changelog/` stops working, so the tooling has to change. Owner decision; not part of the minimum fix.

---

## Resolution so far (2026-11-26) — partial, stays open

Done:

- Step c: `pubspec.yaml` and `extension/package.json` `homepage` now point to `https://saropa.com/developers/saropa-lints/` (HTTP 200, self-canonical). CHANGELOG entry added under 17.10.0.
- The maintenance-comment `current main` link in `CHANGELOG.md` used `saropa/saropa-lints` (HTTP 404); now `saropa/saropa_lints` (HTTP 200). The tooling already uses the underscore form.

Not done, blocked on saropa.com (outside this repo):

- Steps a and b. HTTP 404 on 2026-11-26 for `/developers/saropa-lints/changelog/`, `/developers/saropa-lints/changelog/17.x/`, `/developers/saropa-lints-vscode/changelog/` and `/developers/saropa-lints-vscode/`.

Correction to steps a and b:

- `extension/CHANGELOG.md` cannot be edited separately. It is gitignored (`.gitignore` line 70) and `copy_changelog_to_extension` in `scripts/modules/_extension_publish.py` overwrites it with the root `CHANGELOG.md` at publish time. A local copy that differs from root is only stale.

Needs an owner decision before steps a and b:

- Either both listings use the `saropa-lints` changelog URLs (one file, no tooling change to the copy), or `copy_changelog_to_extension` rewrites the slug to `saropa-lints-vscode` while copying. Proposed: one slug, `saropa-lints`.
- Step d (archives only on saropa.com) remains optional and untouched.

---

## Acceptance

- The header link and the per-release links resolve (HTTP 200).
- The `pubspec.yaml` homepage shows on pub.dev and the `extension/package.json` homepage shows on the Marketplace after the next publish.
- The tooling tests pass: `scripts/modules/tests/test_changelog_overview.py` plus any test touching the archive scripts.

## Finish Report (2026-11-26)

The bug stays open. `https://saropa.com/developers/saropa-lints/changelog/` returned HTTP 404 on re-check.

| Remaining item | Blocker |
|---|---|
| a. Header changelog link | The saropa.com changelog page must return HTTP 200; owner decision on one slug versus rewriting it for the extension copy |
| b. Per-release link, maintenance comment, tooling and tests | Same two blockers |
| d. Archives only on saropa.com (optional) | Owner decision; archive pages must be live |
| Acceptance: homepage visible on pub.dev and Marketplace | The next publish |

The other three URLs listed under "Blocked on" were not re-checked.

Open items moved to `plans/history/2026.11/2026.11.26/infra_changelog_saropa_com_links_waiting_on_pages.md` (since archived); they are tracked in `d:\src\saropa.com\bugs\20261126_saropa_lints_changelog_pages_needed.md`.
