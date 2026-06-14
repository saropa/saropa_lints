# Shared infra: `saropa-vscode-i18n`

**Created:** 2026-06-14
**Status:** Won't Do — rejected (see `plans/SAROPA_SUITE_INTEGRATION.md` shared-infra section and
drift_advisor `plans/67-saropa-suite-integration.md` §7). Closed + archived 2026-06-14.

## Resolution: WON'T DO (2026-06-14)

Extraction rejected as over-engineering. A shared i18n runtime + translation toolkit package for three
in-house consumers costs more in versioning, pinning surface, lockstep releases, and an
untested-shared-toolkit maintenance burden than the duplication it removes, with no user-facing
benefit. The duplication is accepted as a known trade-off; if a shared bug recurs, a single path-dep
module or a sync script is preferred over a new published unit. drift_advisor's Plan 67 §7 rejected the
same architecture the same day, and an independent review flagged the same submodule
consumption-surface and missing shared-package test story as the unaddressed costs. The original task
plan is retained below as the record of what was considered.
**Parent:** the "Shared infrastructure" section of `plans/SAROPA_SUITE_INTEGRATION.md` (and the identical
Section 7 in the two sibling docs). This doc is the detailed extraction plan for the i18n package.

## What it is

A reusable VS Code extension localization toolkit: a tiny runtime that resolves `l10n('namespace.key')`
against bundled per-locale JSON, plus the Python build tooling that audits coverage and (separately
authorized) regenerates translated catalogs via an NLLB-then-Google fallback. Three Saropa extensions
each grew their own copy of this; this package is the one copy they share.

## Why extract (the convergence evidence)

All three TypeScript extensions independently built the same pieces:

- A runtime `l10n()` lookup over `locales/<lang>.json` with `{token}` interpolation and an
  intentional-empty-string distinction. In this repo: `extension/src/i18n/runtime.ts`.
- A manifest-string pipeline (`package.nls.json` + `%key%` + a verify step). Here:
  `extension/scripts/verify-manifest-nls-keys.mjs`, `extension/scripts/i18n/migrate_manifest_nls.py`.
- Machine-translation tooling with an ASCII-sentinel do-not-translate shield, strict integrity checks,
  a self-healing cache, real-coverage audits, day-bucketed report paths, and a publish coverage gate.
  Here: `extension/scripts/i18n/{generate_translations.py, generate_locales.py, audit_coverage.py,
  nllb_engine.py, mt_fallback.py, translator.py, tree_translate.py, dictionaries.py}`.
- A language-picker quick-pick and a coverage manifest (`locale_coverage.json`).

Lints is furthest along — **24 translated languages** (25 locale files incl. English) and the most
developed tooling — so it is the natural source of the extracted package. Drift Advisor and Log Capture
carry reduced copies that drift out of sync (a fix to the sentinel shield or the cache lands in one
repo and not the others).

## What gets extracted

1. **Runtime (TS):** `runtime.ts` (locale resolution, `l10n`, `format`), `languagePick.ts`, and the
   locale-JSON loading contract. Consumers keep their OWN `locales/*.json` catalogs (each tool owns its
   copy — see the canonical envelope rule: never ship translation keys across the boundary). The package
   ships the loader and the lookup, not the strings.
2. **Build tooling (Python):** the whole `scripts/i18n/` set — NLLB engine, Google fallback, sentinel
   shield, coverage audit, `--fail-on-missing` gate, manifest-NLS verify/migrate.
3. **Conventions:** the do-not-translate list (the Saropa brand never translates), the day-bucketed
   report-path convention, and the `--fail-on-missing` publish gate wiring.

## Non-goals

- **Not a shared catalog.** Each extension keeps its own `en.json` + translated locales. This package
  shares the machinery, never the copy.
- **Not a monorepo merge.** The three extensions stay independently publishable.
- **Does not change when translation runs.** Running the NLLB pipeline stays per-repo and separately
  authorized; extracting the tooling does not trigger a single translation job.

## Dependency mechanism (decision needed)

Recommendation: **git submodule** pinned per consumer repo, vendoring both the TS runtime and the
Python `scripts/i18n/` tree. Rationale: the TS side is bundled by each extension's esbuild step (no
runtime npm resolution needed — a submodule path import bundles fine), the Python side is invoked by
each repo's `publish.py` (a path on disk is all it needs), and a submodule gives an explicit pinned SHA
per repo so an upgrade is a deliberate, reviewable bump rather than a floating `git+https` dependency.

Alternatives considered:
- **Published npm + PyPI package** — cleanest semver story, but adds a publish step for internal-only
  code and splits the TS and Python halves across two registries.
- **npm `git+https` dependency** — no pin discipline; every install floats to the branch tip.
- **Copy-and-sync script** — what exists today by hand; rejected (it is the problem).

## Migration steps (per consumer, low design risk — code already converged)

1. Create the `saropa-vscode-i18n` repo; move Lints' `i18n/runtime.ts` + `languagePick.ts` +
   `scripts/i18n/` in as the seed; keep Lints' git history via `git mv` / subtree if practical.
2. Add it as a submodule to Lints first (the source of truth); repoint Lints' imports to the submodule
   path; confirm `npm run check-types`, the i18n tests, and the `--fail-on-missing` gate all pass.
3. Repeat for Drift Advisor, then Log Capture — diffing each repo's reduced copy against the shared
   one and discarding the stale fork.
4. Each repo's catalogs (`locales/*.json`, `package.nls*.json`) stay in that repo.

## Risks

- **ABI-locked Python deps.** The NLLB engine pins ctranslate2 / sentencepiece / numpy to one CPython
  release; the shared package must document the single interpreter requirement so a consumer does not
  reinstall and clobber it (the multi-project ABI-churn incident this guards against is already known).
- **esbuild bundling of a submodule path** — verify the extension bundle still resolves the runtime
  from the submodule before removing the in-repo copy.

## Related

- Parent: `plans/SAROPA_SUITE_INTEGRATION.md` (shared-infra section)
- Siblings: `plans/SHARED_INFRA_VSCODE_UI.md`, `plans/SHARED_INFRA_RELEASE_TOOLS.md`
- Project i18n rules: `.claude/rules/i18n.md`
