# README SEO Rewrite and Doc Restructure

The root README.md had grown to 1,598 lines — a wall of reference docs that buried the value proposition, duplicated content already in sub-documents, and had SEO keywords bolted on at the bottom instead of woven naturally into headings and body text.

## Finish Report (2026-09-05)

### Changes

**README.md** rewritten from 1,598 lines to ~430:
- First paragraph rewritten as a keyword-rich meta description (GitHub and pub.dev surface this).
- H2 headings reworded to match search terms ("What Standard Linters Miss", "Alternative Package Coverage", "OWASP Security Mapping").
- Comparison table moved from line 446 to near the top — SEO-critical for "flutter_lints vs" queries.
- New "Alternative Package Coverage" section added: table of 9 largest alternatives with HAVE percentages, aggregate 75% coverage stat, links to all 46 migration guides.
- All reference material (settings tables, CLI flags, baseline config, platform/package config, troubleshooting, FAQ) moved to sub-docs with inline links.
- Keywords woven naturally throughout instead of a dump at the bottom.
- The "About This Project" duplicate section and raw hashtag/keyword block at the bottom removed.

**New sub-documents created:**
- `doc/guides/extension.md` — VS Code extension reference (settings, commands, views, API).
- `doc/guides/configuration.md` — tiers, platforms, packages, baseline, file skipping, runtime tier cap.
- `doc/faq.md` — FAQ extracted from README.

**Existing documents updated:**
- `doc/troubleshooting.md` — merged all README troubleshooting content (v7 retracted, new-user guide, IDE fixes, OOM, native crashes).
- `doc/guides/migration_guides/README.md` — added aggregate coverage stat (~75%, 1,258/1,670 rules); removed link to deleted GAP_ANALYSIS.md.

**Deleted:**
- `plans/GAP_ANALYSIS.md` (1,429 lines) — per-package detail sections were redundant with migration guides. Gap themes (the only unique content) were not preserved; the migration guides README now carries the aggregate coverage stat.

### Verification

- All 26 files linked from the new README verified to exist on disk.
- No Dart or TypeScript code changed — docs-only scope.
