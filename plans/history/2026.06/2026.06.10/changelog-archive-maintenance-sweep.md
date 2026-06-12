# CHANGELOG_ARCHIVE Maintenance-Section Sweep

All non-user-facing changelog entries are relocated into a collapsed `<details><summary>Maintenance</summary>` block within their release, using a `**Tooling**` bold subheading where a section had internal structure. This applies to `CHANGELOG_ARCHIVE.md` as well as the active changelog.

This task relocated non-user-facing entries (publish-script / CI / GitHub-Actions tooling, audit-script and DX-audit changes, test-fixture and test-mock additions, internal refactors / dead-code removal, ROADMAP / README / CONTRIBUTING doc housekeeping, and `### Administration` / `### Build Process` / `### Publishing` / `### Package Publishing Changes` / `### Documentation` / `### Tooling` / `### Tests Disabled` / `### Tier Set Maintenance` / `### Audit Script v2.0` style ad-hoc sections) out of the user-facing `### Added` / `### Changed` / `### Fixed` sections and into collapsed `<details><summary>Maintenance</summary>` blocks inside each affected release.

## Finish Report (2026-06-10)

### Scope
- **(C) docs only.** Exactly one file changed: `CHANGELOG_ARCHIVE.md` (plus a one-line Maintenance note added to `[Unreleased]` in `CHANGELOG.md`, and this history record). No Dart, analyzer plugin, tiers, example, or extension code touched.

### What was done
- `CHANGELOG.md` (the active changelog) was audited first and confirmed already disciplined — its maintenance content was already inside `<details>` blocks. No top-level misfiling found there.
- `CHANGELOG_ARCHIVE.md` was swept top-to-bottom. ~60 new `<details><summary>Maintenance</summary>` blocks were created (or existing maintenance bullets folded into them), bringing the file to 100 balanced Maintenance blocks total (the archive already carried disciplined Maintenance blocks for the 13.x releases the user moved in mid-task).
- Content was **relocated verbatim**, never reworded or deleted. Pre-existing typos, unclosed backticks, and emojis in archived entries were preserved (existing content, not altered). Empty section headers left behind by a move were removed; blank-line spacing before headers was repaired where a move had glued a bullet to a heading.
- Ad-hoc non-standard maintenance sections were converted to `<details>` Maintenance blocks; where a section had internal structure (e.g. `### Audit Script v2.0`, `### Quick Fix Policy Update`), its heading became a `**bold**` subheading inside the block, matching the format in the user's example.

### Releases swept (fully audited and corrected)
`[Unreleased]`/13.4.x→13.x (already clean), 12.8.3 → 12.3.1, 10.11.0 → 10.0.0, 9.10.0 → 9.0.0, 8.2.x → 8.0.0, 7.0.x, 6.2.x → 6.0.0, 5.0.3 → 5.0.0-beta.2 (beta.1 left intact as a foundational native-plugin-migration release where the internals are the story), 4.15.1 → 4.0.1. Every dedicated meta-section (`### Documentation`, `### Tooling`, `### Audit Script v2.0`, `### Tier Set / Assignment Audit`, `### Package Dependancies`, etc.) was converted through 3.3.0 / 3.0.x, plus 2.3.6.

### Deliberately LEFT top-level (judged user-facing, not maintenance)
- `### Build Process` in 5.0.3 and the residual `### Publishing` in 5.0.0-beta.13 — both contain only **init-walkthrough UX** bullets (the interactive `dart run saropa_lints:init` flow users see).
- `### Tier Assignment Audit` in 4.1.0 — tables of 181 rules now assigned to tiers (rules users gain), not a tooling note.
- `### Documentation` in 1.8.2 — announces new **user-facing guides** (migration_from_solid_lints.md, using_with_*.md).

### OUTSTANDING WORK (not yet complete)
The tail **2.3.5 → 0.1.0** still contains a residual set of **scattered single maintenance bullets** interleaved inside otherwise-user-facing `### Added` / `### Changed` / `### Fixed` sections — e.g. "Documentation: Fixed unresolved doc references", "Test fixtures: Fixed N unfulfilled_expect_lint errors", "example/analysis_options.yaml: enabled tested rules", ROADMAP cleanups, "GitHub Actions publish workflow", "dartdoc_options.yaml", and the publish-script / CI / test-fixture "Added" items in the foundational 1.x / 0.x releases. These were not yet moved. All dedicated maintenance *sections* in that range were already handled; what remains is loose per-bullet relocation. A follow-up pass should sweep 2.3.5 downward.

### Structural integrity (verified)
- `<details>` / `<summary>Maintenance</summary>` / `</details>` counts are balanced (100 / 100 / 100; one extra `<details>` token is a literal mention inside backticks in the [13.9.0] prose, not a tag).
- No bullet line glued directly to a `###` heading.
- No empty `###` sections left behind.
- No nested/unbalanced `<details>`.

### Files
- `CHANGELOG_ARCHIVE.md` — modified (the sweep).
- `CHANGELOG.md` — one-line Maintenance note added under `[Unreleased]`.
- `plans/history/2026.06/2026.06.10/changelog-archive-maintenance-sweep.md` — this report.
