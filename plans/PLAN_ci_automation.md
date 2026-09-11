# CI automation for consumer projects — action, generator, and engine card

**Created:** 2026-09-11 · **Status:** decisions resolved, ready to start at WP1
**Question answered:** How do consumer projects get saropa_lints running on their GitHub PRs
automatically, and can that be toggled from the extension's existing Diagnostic Engines screen?

---

## Status at a glance

- **Layer 1 (analyzer plugin) already works and needs nothing.** A project that adopts
  `include: package:saropa_lints/tiers/<tier>.yaml` gets all rules enforced by any existing
  `dart analyze` step in its CI. No workflow changes, no new files. This covers the majority case
  and is not part of the work below.
- **Layer 2 (PR annotations) works but is copy-paste.** `audit --format sarif` +
  `github/codeql-action/upload-sarif` is documented at `doc/guides/cli.md:318` and functional.
  Every consumer hand-maintains ~25 lines of YAML that never updates when flags change.
- **Layer 3 (gate/baseline) works but is copy-paste.** `quality_gate` and `baseline` have real
  exit-code contracts. Same distribution problem.
- **Nothing is packaged.** No `action.yml` at repo root, so there is no `uses: saropa/saropa_lints@v16`.
- **The extension has a CI generator precedent, and it is stubbed.** See WP0.

The work below is about **distribution**, not capability. The CLI can already do all of this.

---

## Existing code this builds on (verified 2026-09-11)

| Path | What it gives us |
|---|---|
| `doc/guides/cli.md:318` | Working SARIF-on-PR workflow, the template to package |
| `doc/cross_file_ci_example.md` | Same for `cross_file`; exit-code contract documented |
| `bin/init.dart` | `--emit-composite-plugin-scaffold` — the precedent for emitting a file into a consumer project |
| `extension/src/vibrancy/services/ci-generator.ts` | 3-platform workflow generator + `getDefaultOutputPath` |
| `extension/src/vibrancy/extension-activation.ts:2209` | `generateCiConfig()` — quick-pick → generate → overwrite-confirm → `fs.writeFile` → open in editor |
| `extension/src/systemHealth/engineCardsHtml.ts` | `EngineStatus`, `buildEngineCard`, ON/OFF buttons, status pill |
| `extension/src/systemHealth/healthPanel.ts:21,:40` | `toggle` message variant + `_onToggle` emitter |
| `extension/src/extension.ts:1897` | `HealthPanel.onToggle` — per-engine ON/OFF branches |

---

## WP0 — Stubbed vibrancy CI generator (separate bug, not a prerequisite)

`extension/src/vibrancy/services/ci-generator.ts` generates a workflow that **does not enforce
anything**. Two defects:

1. The embedded Dart parses `pub outdated` output, prints the thresholds, and exits 0. The
   thresholds are interpolated into `print()` calls only — no comparison, no non-zero exit. The
   trailing comment says as much: *"For full vibrancy checks, use saropa_vibrancy_cli when available"*.
2. `dart run <<'DART_SCRIPT'` is not a valid invocation — `dart run` does not read a program from
   stdin. The heredoc pattern appears in all three generated platforms.

A team that generates this file believes their PRs are gated and they are not. This must be fixed
or the generator withdrawn before a second generator ships next to it, or we ship the same
silent-pass failure twice.

**Resolved (2026-09-11): track separately, do not block.** This is a pre-existing bug in a shipped
feature and is independent of the CI work below. It should be fixed (write a real threshold
comparison, invoke via a temp `.dart` file rather than a heredoc) or the command withdrawn until
`saropa_vibrancy_cli` exists — but on its own schedule, not as a gate on WP1-WP4.

---

## WP1 — Composite action at repo root

`action.yml` wrapping setup-dart + `pub get` + `audit` + SARIF upload.

```yaml
- uses: saropa/saropa_lints@v16
  with:
    tier: recommended        # default: read project analysis_options.yaml
    since: ${{ github.base_ref }}   # empty = full scan
    mode: annotate           # annotate | gate | both
    min-severity: warning
```

Why first: it collapses the generated workflow from ~25 lines to ~10, moves flag logic into a
place with tests, and means a flag change ships to consumers via a tag bump instead of a
documentation edit they never read.

**Resolved (2026-09-11): wrap `audit`.** Any project setting this up already has saropa_lints as a
dev dependency, which is what `audit` requires. `scan` (which lints projects that never adopted the
package) addresses org-wide scanning of unadopted repos — a different use case that can be added
later as a `command: scan` input rather than driving the initial design.

Caveat to document: SARIF upload requires `security-events: write`, and code scanning is free on
public repos but needs GitHub Advanced Security on private ones. The gate mode (exit code, no
upload) is the fallback and should be the documented default for private repos.

---

## WP2 — `init --emit-ci`

Writes `.github/workflows/saropa-lints.yml` calling the WP1 action. Mirrors the existing
`--emit-composite-plugin-scaffold` flag in `bin/init.dart`.

Emitted file carries a provenance header:

```yaml
# Generated by saropa_lints init --emit-ci
# managed-by: saropa_lints
```

The marker is what lets WP3 distinguish "we generated this and it is untouched" from "the user
has edited this", which is the difference between a safe regeneration and clobbering someone's work.

---

## WP3 — Engine card in the System Health panel

A fourth card in the Diagnostic Engines section. Contained, typed change:

- add `'ci'` to the `EngineStatus.key` union — `engineCardsHtml.ts:12`, `healthPanel.ts:21`, `healthPanel.ts:40`
- add `getCiStatus()` to `EngineStatusDeps`
- add an `else if (engine === 'ci')` branch beside the existing `lspServer` / `analyzer` branches at `extension.ts:1897`
- add `debug.engine.description.ci` + status values across the 24 `package.nls.*` files

No card layout changes. Field mapping:

| Field | CI meaning |
|---|---|
| `status` | last workflow run conclusion — success / failure / running / unknown |
| `ruleCount` | rule count for the tier the workflow runs |
| `scanProgress` | in-flight run progress |
| `pid` | n/a, omitted — card already handles absent PID |
| `rssBytes` | n/a, use `rssNote` — precedent set by the analyzer card |

`statusColorClass()` gives a green/red pill on last CI result for free. Surfacing "analyzer green
locally, CI red" next to the local engines is the card's actual value; no other screen shows it.

### The one genuine design issue: branch state vs effective state

The card reads the workflow file in the **current branch's working tree**. Effective CI state is
what is on the **default branch**. These diverge routinely:

- Developer on a feature branch toggles OFF → card says OFF → every PR is still gated by main's copy.
- Teammate turns it ON in main → your older branch has no file → card says OFF while CI is live.

The card is confidently wrong in both directions. This is a display-accuracy bug, not a governance
one — the toggle writes to the working tree, so the change is visible in the SCM view, reviewed in
the PR, and attributable via `git blame` like any other committed change.

**Fix:** label the card with the branch it reflects ("this branch"), and if live run status is
wired (below), show default-branch state as the authoritative value.

### OFF should write `if: false`, not delete

Not for safety — for edit preservation. A team that customised the generated workflow loses that
work on a delete/regenerate cycle. `if: false` is a one-line reversible diff that keeps their edits
intact. Deletion stays available as an explicit "Remove" action, distinct from the toggle.

### Live run status — resolved: not available by default

Traced 2026-09-11. The vibrancy GitHub path authenticates with an optional user-pasted PAT
(`saropaLints.packageVibrancy.githubToken`, `extension/package.json:1731`, read at
`config-service.ts:20`), defaulting to empty. It is a plain settings string, not a
`vscode.authentication` session, so there is no ambient sign-in to inherit and most users will have
no token set.

**Consequence for the card:** ON/OFF comes from the workflow file, which always works. The status
pill shows a real run conclusion only when a token happens to be configured, and otherwise reads
`unknown`. Do not derive a green pill from file presence — "a workflow file exists" is not "CI
passed", and conflating them is the same class of error as WP0's always-passing workflow.

A proper `vscode.authentication.getSession('github', ...)` flow would make live status reliable for
everyone, but that is its own piece of work and is not assumed here.

---

## WP4 — Dogfood in this repo

`.github/workflows/ci.yml:73` strips the `include:` and `plugins:` lines before analyzing, so this
repo's own PRs are checked by stock `dart analyze` only — not by its own 2332 rules. Presumably
deliberate (bootstrapping), but it means the audit + SARIF path gets no exercise on any PR.

Add a non-blocking `audit --format sarif` job using the WP1 action. This is also the only realistic
integration test for the action itself.

---

## Sequencing

```
WP1 (action) ──► WP2 (--emit-ci) ──► WP3 (engine card)
     └──────────► WP4 (dogfood / integration test)

WP0 (vibrancy generator bug) — tracked separately, blocks nothing
```

WP3 before WP1/WP2 means a switch wired to nothing, and template logic written twice.

## Decisions — all resolved 2026-09-11

1. **WP1 wraps `audit`.** Consumers setting this up already have the dependency; `scan` becomes an
   optional input later if org-wide scanning of unadopted repos is wanted.
2. **WP0 does not block.** The vibrancy generator bug is pre-existing and tracked on its own
   schedule; it no longer gates WP3.
3. **No live CI status by default.** Auth is an optional pasted PAT, so the card shows ON/OFF from
   the file and `unknown` status unless a token is configured.

Ready to start at WP1.
