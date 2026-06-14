# Shared infra: `saropa-release-tools`

**Created:** 2026-06-14
**Status:** Plan only — no code moved. Cross-repo extraction; needs sign-off on the dependency
mechanism (a blast-radius move) before any file leaves a repo.
**Parent:** the "Shared infrastructure" section of `plans/SAROPA_SUITE_INTEGRATION.md` (and the identical
Section 7 in the two sibling docs). This doc is the detailed extraction plan for the Python release tooling.

## What it is

A shared Python release toolkit for the three Saropa repos: the `publish.py` orchestrator and the
reusable gates it runs — the dependency-import check, the write-time American-English gate, the
changelog conventions enforcement, and the CI-mirroring analyze step. One toolkit so a fix to the
publish guard or the spelling gate lands once.

## Why extract (the convergence evidence)

All three repos converged on the same release machinery by hand:

- A `publish.py` orchestrator with retry/ignore/abort prompting and the never-run-NLLB publish guard.
  Here: `scripts/publish.py` plus `scripts/modules/` (`_publish_workflow.py`, `_publish_steps.py`,
  `_extension_publish.py`, `_git_ops.py`, `_retrigger_ci.py`, `_version_changelog.py`, `_timing.py`).
- A dependency-import publish gate that blocks a release when a used dependency is missing from the
  manifest. Here: `scripts/check_dependency_imports.py`, `scripts/modules/_analyze_pubspec.py`.
- A write-time American-English gate. Here: `scripts/modules/_us_spelling.py` (and the
  `scripts/hooks/` spelling guard).
- Changelog conventions: dateless headers, the `<details>Maintenance</details>` block, the
  `[log](tag-url)` per-section link, and the archive compaction. Here:
  `scripts/compact_changelog_archive.py`, `scripts/modules/_version_changelog.py`.
- A final CI gate that re-runs analysis (`--fatal-infos`) before tagging, mirroring CI exactly.

## What gets extracted

1. **Orchestrator core:** the `publish.py` workflow engine (step sequencing, retry/ignore/abort,
   timing, git ops, CI re-trigger) — the repo-agnostic parts of `scripts/modules/`.
2. **Gates:** dependency-import check, American-English spelling gate, changelog-convention
   enforcement + archive compaction, and the CI-mirroring analyze runner.
3. **Conventions as config:** the changelog format rules and the never-run-NLLB guard, parameterized
   so each repo supplies its own package name, manifest path, and analyze command.

## Non-goals

- **Not the repo-specific steps.** Rule-metric counts, tier integrity, and pub.dev-vs-Marketplace
  specifics that only apply to one repo stay in that repo (the toolkit calls out to repo-supplied
  hooks). Lints-only modules like `_tier_integrity.py`, `_rule_metrics.py`, `_roadmap_implemented.py`
  stay here.
- **Not a single shared CI config.** Each repo keeps its own GitHub Actions workflow; the toolkit
  provides the steps those workflows invoke.
- **Not a monorepo merge.**

## Dependency mechanism (decision needed)

Recommendation: **git submodule** vendored under each repo's `scripts/`, consistent with the two
TypeScript shared packages. Rationale: `publish.py` is invoked from a known path in each repo, the
toolkit imports are plain Python module paths (a submodule on disk needs no install step), and a pinned
SHA per repo makes a toolkit upgrade an explicit, reviewable bump. This matches the existing
`scripts/` + `scripts/modules/` layout, so consumers change an import root, not their whole structure.

Alternatives considered:
- **Published PyPI package** — cleanest versioning, but adds a publish/install step for internal-only
  tooling and a pinned-version bump per repo anyway.
- **`pip install git+https`** — needs a virtualenv per repo and floats unless pinned; heavier than a
  vendored submodule for scripts that just run from disk.
- **Copy-and-sync** — the status quo; rejected.

## Migration steps (per consumer)

1. Create `saropa-release-tools`; seed from Lints' `publish.py` orchestrator + the repo-agnostic
   `scripts/modules/` core + the three gates. Keep Lints-specific modules in Lints.
2. Add as a submodule to Lints first; repoint `publish.py` imports to the submodule; run a full
   audit-only publish dry run and confirm every gate fires identically (dependency-import, US-English,
   changelog conventions, CI-mirror analyze).
3. Repeat for Drift Advisor, then Log Capture, parameterizing each repo's package name / manifest /
   analyze command and discarding the forked copy.

## Risks

- **Hidden repo coupling.** A module assumed repo-agnostic may reference a Lints-only path or rule
  metric; the dry-run in step 2 must prove the gate is truly parameterized before the sibling repos
  adopt it.
- **The never-run-NLLB guard must survive extraction intact** — it is a safety guard, not boilerplate;
  verify it still blocks a translation run after the move.
- **Durable scripts stay Python.** The toolkit is Python by standard; do not introduce `.ps1`/`.sh`
  durable tooling during extraction.

## Related

- Parent: `plans/SAROPA_SUITE_INTEGRATION.md` (shared-infra section)
- Siblings: `plans/SHARED_INFRA_VSCODE_I18N.md`, `plans/SHARED_INFRA_VSCODE_UI.md`
