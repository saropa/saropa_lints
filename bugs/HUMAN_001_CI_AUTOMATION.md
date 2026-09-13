# HUMAN 001 — CI automation

Manual test record for the GitHub Actions CI work merged from [PR #336](https://github.com/saropa/saropa_lints/pull/336). Rationale, alternatives and machine verification live in [`PR_336_CI_AUTOMATION.md`](PR_336_CI_AUTOMATION.md); this file is only the human half.

Everything here needs a person and a running VS Code extension host. None of it can be automated from this repository today, which is exactly why it is written down rather than assumed.

## How to record a result

Fill in the three columns as you go. **Status** is one of `pass`, `fail`, `blocked`, or `-` for not yet attempted. Put the version or commit you tested against in **Build**, and anything surprising in **Notes** — a failure is worth more than a pass here, so write down what you actually saw rather than what was supposed to happen. A test that fails gets an entry in the Findings section at the bottom.

## Extension host — the CI card

| # | Test | Status | Build | Notes |
|---|------|--------|-------|-------|
| 1 | **Turn CI on from the UI.** Saropa Lints sidebar → **Engines** row under Status → **GitHub Actions CI** card → **ON**. A workflow file appears in Source Control and the card reads active. | - | | |
| 2 | **Turn it back off.** **OFF** keeps the file and adds one `if: false` line per job; the card reads stopped. **ON** again returns the file to exactly what it was. | - | | |
| 3 | **Break the off switch deliberately.** Hand-edit the workflow into a shape with no recognizable `jobs:` map, then click OFF. It must refuse with an error saying CI is still running and offer to open the file — never silently report success. | - | | |
| 4 | **The generated workflow honors your configuration.** A project with a configured tier gets no `tier:` input. A project with no saropa_lints configuration gets `tier: recommended` — without it `scan` exits 2. | - | | |
| 11 | **The engines panel with `saropaLints.debug.enabled` off.** The Engines row still appears in the sidebar and the panel still opens. | - | | |

## Extension host — the publish step

| # | Test | Status | Build | Notes |
|---|------|--------|-------|-------|
| 5 | **Both directions.** After ON the panel shows the publish section with four git commands. The copy button puts them on the clipboard with real quote marks, not `&quot;`. The create button pushes a branch and opens a pull request containing only the workflow file. Repeat for OFF. | - | | |
| 6 | **With a dirty tree.** Edit an unrelated file and leave it uncommitted; also `git add` a second one. The commit must contain only the plan's paths, and both of those edits must survive exactly as they were — the staged one still staged. | - | | |
| 7 | **When it refuses.** Publish to a branch-protected remote, or with the network down. The error names the push command specifically, the panel section stays on screen with its commands intact, and the local commit is still there. | - | | |
| 8 | **Declining the GitHub sign-in.** Dismiss the sign-in prompt. The branch is still pushed and the fallback offers the compare page rather than reporting a failure. | - | | |
| 14 | **A project that did not depend on saropa_lints.** Turning CI on adds it to `pubspec.yaml`; that edit must be in the same commit and the same pull request, and that pull request's own CI must pass rather than failing on an unresolved dependency. | - | | |

## Outside the extension

| # | Test | Status | Build | Notes |
|---|------|--------|-------|-------|
| 9 | **It does not fail the build.** Push the generated workflow on a project with known findings; the check reports them without turning the pull request red. | - | | |
| 10 | **`--emit-ci` produces the same file.** Run `dart run saropa_lints:init --emit-ci` on a scratch project and diff against what the card writes — identical. Run it twice; the second run refuses rather than overwriting. | - | | |
| 12 | **The vibrancy generator actually gates.** "Generate CI Pipeline" with `maxOutdated` set to 0 on a project with outdated packages, pushed, must fail the job. Before this work it always passed. | - | | |
| 13 | **The major tag, at release.** After the next release, `v16` exists and points at it, and `uses: saropa/saropa_lints@v16` resolves in a real workflow. | - | | |
| 15 | **SARIF upload.** With `mode: annotate` and `upload-sarif` on a repository that has code scanning, findings render as annotations on the diff. Never exercised — the self-test sets `upload-sarif: false`. | - | | |
| 16 | **`--since` on a real shallow checkout**, and **`install-sdk: auto` against a Flutter toolchain.** The self-test covers neither; it exercises the skip branch only. | - | | |

## Findings

Record anything that failed, with enough detail to reproduce. Link the fix commit or issue once it exists.

_None recorded yet._
