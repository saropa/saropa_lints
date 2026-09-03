# Tier Folders and Cleanup

All 336 `bugs/proposal_*.md` files were sorted into 6 tier folders
(`tier_1_quick_wins`, `tier_2_high_value`, `tier_3_infrastructure`,
`tier_4_fpdart`, `tier_5_niche`, `declined`) matching the build order in
`plans/PLAN_gap_theme_priorities.md`. The initial tier_2 bucket was a
keyword-match fallback (150 files); a redistribution pass moved 76 to their
correct tiers, leaving 74 genuinely high-value proposals.

## Changes

- **336 proposal files** — `git mv` into tier subfolders under `bugs/`.
- **Migration guide links** — all `doc/guides/migration_guides/*.md` proposal
  references rewritten to tier-scoped paths; 16 pre-existing dead links repaired.
- **CHANGELOG.md** — proposal count corrected 298 → 336.
- **plans/PLAN_open_legacy_tasks.md** — open count 37 → 32; 5 legacy rules
  annotated as RESOLVED or NEEDS DECISION.
- **7 declined proposals** — internal `Status:` header flipped from Open to
  Declined to match their `bugs/declined/` folder placement.
- **`avoid_connectivity_ui_decisions`** — deliberately left `Status: Open` in
  `tier_1_quick_wins/`; its Existing Coverage section argues it is a genuine
  narrowing of `avoid_connectivity_equals_internet`, not a duplicate. Flagged as
  NEEDS DECISION in `PLAN_open_legacy_tasks.md`.

## Final counts

| Folder | Count |
|--------|-------|
| tier_1_quick_wins | 121 |
| tier_2_high_value | 74 |
| tier_3_infrastructure | 59 |
| tier_4_fpdart | 27 |
| tier_5_niche | 33 |
| declined | 22 |
| **Total** | **336** |

## Finish Report (2026-09-03)

Documentation-only session. No lint rules implemented, no Dart code changed, no
tests affected. All work landed in commits `6a3b7048` through `b611439d` on
`main`.

### Hardening pass

`plans/PLAN_gap_theme_priorities.md` was the last file with stale proposal
references. Fixed 9 bare filenames → tier-folder-qualified paths, corrected the
proposal count 298 → 336, and updated the glob `bugs/proposal_*.md` →
`bugs/*/proposal_*.md`. All 9 referenced proposals verified on disk. Separately
verified: all 5 RESOLVED annotations in `PLAN_open_legacy_tasks.md` point at
rules that exist in `lib/src/rules/` and are functionally equivalent to the
proposals they replace (confirmed by reading rule implementations and proposal
specs; one minor acknowledged gap: `avoid_large_objects_in_state` does not cover
`ui.Image`/`Picture` types, per the proposal's own known-limitations note).
Migration guide links: 422 references, 289 unique paths, 0 dead links. Glob
`bugs/*/proposal_*.md` is safe — only 6 tier subdirectories exist under `bugs/`.

Added a clarifying note to the plan header distinguishing per-theme gap counts
(~24/~50/~42) from per-folder file counts (121/74/59) to prevent confusion.
Assumption: `bugs/` will only contain tier subdirectories — creating a non-tier
subdirectory there would make the glob pattern inaccurate.
