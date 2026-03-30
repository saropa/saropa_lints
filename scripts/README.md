# Publish Scripts

## Overview

`publish.py` is the single entry point for the saropa_lints release workflow.
It drives both the Dart package (pub.dev) and VS Code extension (Marketplace + Open VSX)
through an interactive, step-by-step pipeline.

## Usage

```bash
python scripts/publish.py
```

No flags. Prompts for one of six modes:

| # | Mode | What it does |
|---|------|--------------|
| 1 | Full publish | Audit, format, analyze, test, version, release, extension |
| 2 | Audit only | Tier integrity, DX checks — no publish |
| 3 | Fix doc comments | Auto-fix angle brackets and doc references |
| 4 | Skip audit | Full publish minus the audit step |
| 5 | Analyze only | Run `dart analyze`, write log, exit |
| 6 | Extension only | Package .vsix, optionally publish to stores |

## Architecture

```
publish.py                      <- thin entry point (~200 lines)
  |
  +-- modules/_publish_workflow.py   <- pipeline orchestration
  |     |
  |     +-- modules/_publish_steps.py    <- step implementations (format, test, analyze, docs)
  |     +-- modules/_git_ops.py          <- git commit, tag, push, GitHub release
  |     +-- modules/_version_changelog.py <- version prompt, sync, changelog management
  |     +-- modules/_extension_publish.py <- extension build, publish, store verification
  |     +-- modules/_rule_metrics.py     <- rule/category counts, badges, coverage
  |     +-- modules/_pubdev_lint.py      <- pub.dev doc-comment lint fixes
  |     +-- modules/_timing.py           <- step timer and summary
  |
  +-- modules/_audit.py             <- pre-publish audit orchestrator
  |     +-- modules/_audit_checks.py     <- individual audit checks
  |     +-- modules/_audit_dx.py         <- DX message quality checks
  |     +-- modules/_tier_integrity.py   <- tier assignment validation
  |     +-- modules/_us_spelling.py      <- American English spelling check
  |     +-- modules/_roadmap_implemented.py <- roadmap status validation
  |     +-- modules/_duplicated_messages.py <- duplicate message detection
  |
  +-- modules/_utils.py             <- colors, exit codes, output, run_command
```

## Module Responsibilities

| Module | Purpose |
|--------|---------|
| `publish.py` | Entry point: mode selection, setup, delegates to workflow |
| `_publish_workflow.py` | Pipeline orchestration: wires steps together with timing |
| `_publish_steps.py` | Low-level steps: prerequisites, format, analyze, test, docs, validation |
| `_git_ops.py` | Git operations: commit, push, tag, GitHub release |
| `_version_changelog.py` | Version prompting (cross-platform), semver parsing, changelog sync |
| `_extension_publish.py` | Extension: compile, package .vsix, publish, store verification |
| `_rule_metrics.py` | Rule/category counts, test coverage, roadmap summary, badge sync |
| `_pubdev_lint.py` | Detect and auto-fix pub.dev doc-comment lint issues |
| `_timing.py` | Step timing tracker with summary table |
| `_audit.py` | Pre-publish audit orchestrator |
| `_audit_checks.py` | Individual audit checks (prefix, message length, etc.) |
| `_audit_dx.py` | Developer experience message quality validation |
| `_tier_integrity.py` | Verify all rules are assigned to tiers |
| `_us_spelling.py` | American English spelling enforcement |
| `_roadmap_implemented.py` | Verify roadmap status matches implementation |
| `_duplicated_messages.py` | Detect duplicate lint messages |
| `_utils.py` | Shared utilities: colors, exit codes, output helpers, run_command |

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Prerequisites failed |
| 2 | Working tree check failed |
| 3 | Tests failed |
| 4 | Analysis failed |
| 5 | Changelog validation failed |
| 6 | Pre-publish validation failed |
| 7 | Publish failed |
| 8 | Git operations failed |
| 9 | GitHub release failed |
| 10 | User canceled |
| 11 | Audit failed |

## Standalone Scripts

Scripts in this directory that can run independently:

| Script | Purpose |
|--------|---------|
| `apply_security_metadata_cwe_hotspots.py` | Bulk security metadata application |
| `bulk_rule_metadata.py` | Bulk metadata operations |
| `export_saropa_rules_for_gap.py` | Export rules for external tools |
| `list_rules_without_fixes.py` | Query rules lacking quick fixes |

Historical scripts in `scripts/historical/` are not part of the build.

## Troubleshooting

**GitHub release fails with "Bad credentials":**

If `GITHUB_TOKEN` is set (even if invalid), it overrides `gh auth login`. Fix:
```powershell
$env:GITHUB_TOKEN = ""        # PowerShell
```
```bash
unset GITHUB_TOKEN             # Bash
```
Then verify: `gh auth status`
