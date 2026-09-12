# PR 336 — Run saropa_lints on pull requests

**Branch:** `claude/inspiring-pascal-tjfi2j` → `main` · **Created:** 2026-09-11 · **Updated:** 2026-09-12
**Plan:** `plans/PLAN_ci_automation.md`, implemented in full.
**Supersedes:** `bugs/PR_336_CI_ACTION.md` and `bugs/PR_337_CI_AUTOMATION_REMAINDER.md`, both folded in here. PR 337 was a second pull request for the later half of this work; splitting it was a mistake and its commits were fast-forwarded onto this branch.

---

## Objective

A project could not run saropa_lints against its pull requests without hand-writing a workflow, and nothing in the product pointed anyone at the possibility. The CLI could already do the analysis — `audit` emits SARIF, `scan` honors a project's configured rules, both have real exit-code contracts — but every consumer had to copy roughly twenty-five lines of YAML out of the CLI guide and maintain it themselves. When a flag changed, the fix shipped in documentation nobody re-reads.

This packages that capability so a team can turn it on from the extension, keep control of which of the 2332 rules run, and turn it back off when it misbehaves.

---

## What I did

### A composite action (`action.yml`)

Wraps SDK setup, `pub get`, the analysis, and the SARIF upload. Two inputs carry the design:

**`mode`** decides what a finding does — `annotate` (upload SARIF, stay green), `gate` (fail the build), `both`.

**`command`** decides which rules produce one — `audit` runs every rule with the tier cap bypassed and is the only command that can emit SARIF; `scan` runs only what the project's `analysis_options.yaml` enables and brings `tier`, `fail-on`, `fail-on-tier` and `fail-on-count`. `auto` resolves `gate` to `scan` and the SARIF modes to `audit`.

Three decisions matter more than the rest:

**The audit step never fails the job.** It records the exit code and a single `Evaluate result` step decides. Failing in place would skip the SARIF upload exactly when there is something to annotate.

**Exit code 2 fails the job in every mode, including `annotate`.** Exit 2 means the analysis never examined any code. Reporting green would assert something that was never checked — and this fired for real on this repository's own self-lint job, catching a missing configuration instead of quietly passing.

**Inapplicable inputs are an error, not a no-op.** A `tier` accepted and silently dropped under `audit` would leave a team believing CI honors their rule set while every rule runs.

The two commands also disagree on glob grammar: `audit` takes one comma-separated value, `scan` consumes each following non-flag argument. A comma-joined string reaches `scan` as a single literal glob containing commas — matching nothing, reporting nothing — so the action translates per command rather than passing through.

### `.github/workflows/action-selftest.yml`

Executes the action on a real runner via `uses: ./`, which needs no tag and always tests the version in the pull request. It asserts that annotate produces genuine SARIF (`jq`-verified, not merely a non-empty file), that gate fails exactly when findings exist, that `scan` honors its exit contract with `tier` and `fail-on-tier`, and that four invalid configurations are rejected.

### `init --emit-ci` (`lib/src/init/`)

Writes `.github/workflows/saropa-lints.yml` into a project, mirroring the existing `--emit-composite-plugin-scaffold` flag. The generated file opens with a provenance header carrying `# managed-by: saropa_lints`, which is what lets later tooling tell "we generated this and it is untouched" from "a human has edited it". Unlike the scaffold flag it refuses to overwrite: a workflow governs every contributor's pull requests and frequently carries local customization, and losing that to a re-run of a setup command is not a recoverable surprise.

### A CI card in the System Health panel (`extension/src/systemHealth/`)

A fourth card beside Live Analysis, Scan Daemon and LSP Server, with the same ON/OFF control. `ciWorkflow.ts` holds the file logic and depends only on `fs` and `path`, which is what makes its behavior testable outside an extension host.

Clicking ON does the setup, not just the file: it adds `saropa_lints` to the pubspec when missing, detects whether the project has rule configuration, and writes the workflow. No prompt — `--emit-ci` generates the identical file, and a card that quietly differed from the CLI would be its own bug.

OFF never deletes. It inserts one marked `if: false` line under **every** job, so the change is a one-line reversible diff and any customization survives.

### A deliberate publish step (`ciPublish.ts`, `ciPublishGithub.ts`, `ciPublishHtml.ts`)

Writing the file changes nothing that anyone else can see. CI only starts, or stops, once the change reaches the default branch, so both directions of the toggle now raise a panel section that offers to take it there — new branch, the one file committed, pushed, pull request opened.

Nothing in that happens on its own. The section is a prompt: the branch is not cut and nothing is pushed until the button in it is pressed. A panel that pushed a branch as a side effect of a toggle would be making a decision for the user that they may not have noticed making, on a file that governs every contributor's pull requests.

The exact commands are rendered in a copyable text control beside a copy button, and they are the literal strings the runner executes — `CiPublishPlan.commands` feeds both, so the two cannot drift into the display being a lie. Someone whose push needs a hardware key, whose team signs commits, or who simply does not want an editor touching their git history copies them and is done. That path is first-class, not a consolation prize.

Three properties are load-bearing, and each has a test that would fail if it broke. Only `.github/workflows/saropa-lints.yml` is ever staged, so pressing the toggle mid-task cannot sweep up the rest of a dirty working tree. The branch is always new and the push is never forced, so no path here can overwrite existing history. And a failure stops at the step that failed and names it, so a push rejected by a protection rule leaves a local commit and a set of commands that still work by hand.

Opening the pull request is the one step git cannot do, so it goes through VS Code's built-in GitHub sign-in — one "Allow" the first time, no personal access token to mint or store. Every failure on that path is non-fatal by construction: the branch is already pushed, so no session, no GitHub remote, or an API refusal all land on the same offer of the compare page.

### A report-only self-lint job (`.github/workflows/ci.yml`)

This repository's own rules had never run against its own pull requests. The committed `analysis_options.yaml` carries no tier `include:` and no `plugins:` section, so `dart analyze` here only ever applied stock Dart rules — the `analyze` job's "Strip self-plugin reference" step deletes lines that are not there.

The new job runs the checkout through the repo's own action. It uses `mode: gate` with an explicit tier, which reports readably to stdout, and carries `continue-on-error` on the step so no finding can fail it.

### Fixing the Package Vibrancy CI generator (`extension/src/vibrancy/services/ci-generator.ts`)

Unrelated to CI automation; found only because it was the closest precedent for the action work. Its generated workflows always passed, two ways: thresholds were interpolated into `print()` calls with no comparison and no non-zero exit, and all three platforms invoked `dart run <<'DART_SCRIPT'`, which does not read a program from stdin, so the checker never executed at all.

The Dart is now written to a real file and run, compares against `maxOutdated`, and exits non-zero on breach. The other four thresholds are deliberately **not** enforced: `pub outdated` carries no abandonment, end-of-life, scoring or vulnerability data, so the generated script says plainly that it cannot enforce them rather than inventing a check.

### Ungating the engines panel (`extension/src/systemHealth/healthPanel.ts`)

`getEngineStatuses()` returned undefined unless `saropaLints.debug.enabled` was on, which hid the sidebar's Engines row and with it the only route to the panel. These are not debug internals: they decide whether analysis runs at all, and one of them is the off switch for a project's CI. A kill switch behind a setting you have to know to enable is not a kill switch.

### Moving the major version tag (`scripts/modules/_git_ops.py`)

Actions consumers write `uses: saropa/saropa_lints@v16` and expect it to track the newest 16.x. The release process only created exact tags, so that reference did not resolve and every guide had to carry a workaround. Step 13 now force-moves the major tag after pushing the exact one. A failure there warns rather than failing the release: by then the package is published and the real tag pushed, and a missing major tag is a papercut for action consumers rather than a broken release.

---

## Considered and rejected

**Wrapping only `audit`.** The original choice, reversed. It weighed whether the command could reach the project rather than whether a team could control it. `audit` bypasses the tier cap by design, so `min-severity` and `min-impact` filter only what is reported after all 2332 rules have run — there was no way to express "run my configured rule set". `scan` is the command built for that, and for CI gating generally.

**`mode: annotate` in the generated workflow.** Annotate resolves to `audit`, so a project on `essential` would have its pull requests papered with findings from rules it never enabled. The generated workflow uses `gate`, which resolves to `scan` and honors the project's own configuration.

**Making the generated workflow enforce by default.** Rejected: a project adopting a strict rule set has a backlog, not a regression, and a check that is red on every pull request from day one trains people to ignore CI. The step carries `continue-on-error` and says in a comment that deleting that line makes it enforce — a decision a project makes when it is clean enough.

**Asking the user which mode they want.** A quick pick offering "annotate the pull request" or "fail the build" was built and removed. It is a question about SARIF semantics dressed as a setup step, most users cannot answer it and would dismiss it, and it let the card produce a workflow that differed from `--emit-ci` for the same project.

**A "Set up CI" row in the sidebar's Actions section.** Built and reverted. The System Health panel is already the webview that toggles engines, and the sidebar's Status section already opens it. The row duplicated an existing route and split one action across two surfaces that would drift apart.

**Uploading the self-lint SARIF to code scanning.** Would give inline annotations on this repository's own pull requests. Rejected as a default because it posts results to the Security tab, and populating a public repository's security dashboard is a maintainer's decision rather than something to assume.

**Deleting the workflow file on OFF.** Rejected: it discards team customization irreversibly. `if: false` is reversible and reviewable.

**Deriving a green CI status from file presence.** Rejected outright. It is the same class of error as the vibrancy bug being fixed three files away.

**A hardcoded action pin.** Both generators originally wrote `@v16.2.1`, a tag that predates `action.yml` entirely, so every workflow they produced referenced an action that could not resolve. Both now derive the pin from the saropa_lints version in use. The card additionally carries a `MIN_ACTION_VERSION` floor, because the extension and the package version independently and the extension can be several releases ahead of the package a project depends on. That floor is `16.3.0`, the version this work ships as and therefore the first tag that will contain `action.yml` — an exact value, not an estimate.

**Fabricating a vulnerability check for `failOnVulnerability`.** Rejected for the reason the whole vibrancy fix exists.

---

## What to test

**1. Turn CI on from the UI.** Open the Saropa Lints sidebar, click the **Engines** row under Status to open System Health, find the **GitHub Actions CI** card, click **ON**. A workflow file should appear in Source Control. Confirm the card reads active. This is the path that has never run in a live extension host.

**2. Turn it back off.** Click **OFF**. The file must still exist, with one `if: false` line added per job, and the card must read stopped. Click **ON** again and confirm the file returns to exactly what it was.

**3. Break the off switch deliberately.** Hand-edit the generated workflow into a shape with no recognizable `jobs:` map, then click OFF. It must refuse with an error saying CI is still running, and offer to open the file — not silently report success.

**4. The generated workflow honors your configuration.** On a project with a configured tier, confirm the generated file has no `tier:` input. On a project with no saropa_lints configuration at all, confirm it has `tier: recommended` — without it, `scan` exits 2.

**5. The publish step, in both directions.** After clicking ON, the panel must show the publish section with four git commands. Press the copy button and confirm the clipboard holds them with real quote marks, not `&quot;`. Then press the create button and confirm a branch is pushed and a pull request opens containing only the workflow file. Repeat for OFF.

**6. The publish step with a dirty tree.** Edit an unrelated file, leave it uncommitted, then publish. The resulting commit must contain the workflow file and nothing else, and the unrelated edit must still be sitting uncommitted afterwards.

**7. The publish step refusing.** Publish to a branch-protected remote, or with the network down. The error must name the push command specifically, the panel section must stay on screen with its commands intact, and the local commit must still be there.

**8. Declining the GitHub sign-in.** Press the create button and dismiss the sign-in prompt. The branch must still be pushed, and the fallback must offer the compare page rather than reporting a failure.

**9. It does not fail the build.** Push the generated workflow on a project with known findings and confirm the check reports them without turning the pull request red.

**10. `--emit-ci` produces the same file.** Run `dart run saropa_lints:init --emit-ci` on a scratch project and diff it against what the card writes. They should be identical. Run it twice and confirm the second run refuses rather than overwriting.

**11. The engines panel with `saropaLints.debug.enabled` off.** The Engines row must still appear in the sidebar and the panel must still open.

**12. The vibrancy generator actually gates.** Run "Generate CI Pipeline" with `maxOutdated` set to 0 on a project with outdated packages, push the result, and confirm the job fails. Before this it always passed.

**13. The major tag, at release.** After the next release, confirm `v16` exists and points at it, and that `uses: saropa/saropa_lints@v16` resolves in a real workflow.

---

## Verification status

**Ran, passed:**

- **The publish step's git behavior, against real repositories.** 25 tests in `extension/src/test/systemHealth/ciPublish.test.ts`, each against a real working repo with a real bare remote rather than a mocked git — the whole value of the module is what git does with the arguments it is handed, and a mock would only assert my assumptions back at me. Covered: every origin URL shape including the lookalike hosts that must *not* match; a default branch that is neither `main` nor `master`; branch names that never collide with an existing local or remote branch; `buildCiPublishPlan` performing nothing; the commit containing the workflow file and nothing else with an unrelated edit and an untracked file both surviving untouched; the failure path naming the exact step for a missing file and for an unreachable remote, with the local commit intact after a failed push; and two publishes producing two branches. Plus the panel section: nothing rendered with no pending change, every command present, the copy attribute escaped so a quote mark cannot truncate it, and the pull request button hidden — but the commands and the dismiss kept — when the remote is not GitHub.

- **The workflow toggle, compiled and executed against real files.** ON→OFF→ON returns the file byte-identical; both directions are idempotent; every intermediate state parses as valid YAML; a heavily customized workflow keeps its added `cron`, `timeout-minutes`, changed `mode` and added `tier` across the round trip; a two-job workflow has **both** jobs suspended by OFF and both restored by ON with the added job intact; a file with no recognizable `jobs:` map is left untouched and the call returns false.
- **The generated workflow's content**, across configured and unconfigured projects: a configured project gets `mode: gate` with no tier override, an unconfigured one gets the `recommended` fallback, both carry `continue-on-error` and request only `contents: read`.
- **The version-derived pin**, both branches: a lockfile at 16.3.0 yields `@v16.3.0`, no lockfile yields `@main` with an explanatory comment and never `@vunknown`. The floor was checked across locked versions — 16.2.1 and 16.2.9 fall back, 16.3.0 and above pin.
- **The vibrancy fix's tests against both versions of the generator** — 12/12 fail before the fix, 12/12 pass after. A test that passes against broken code would have been worthless here.
- **A pathname-expansion bug in the glob translation**, demonstrated against a real directory: with unquoted word splitting `vendor/*` was replaced by the files that happened to match before the CLI saw it; with `read -ra` the pattern survives.
- **The `-e` failure**, reproduced under the runner's exact shell invocation and then shown fixed under the same flags.
- Every flag the action can emit, checked programmatically against the parsers in `bin/audit.dart` and `bin/scan.dart`.
- `tsc --noEmit -p tsconfig.json` for the extension; `scripts/modules` tests (156); `check_doc_links_excluded_paths.py`; `check_dependency_imports.py`; `verify-manifest-nls-keys` (367 keys).
- On CI: `analyze`, `test`, `self-lint`, `selftest`, `extension-manifest-nls` and five CodeQL analyses.

**Did not run:**

- **The extension in a live VS Code host.** The card's rendering, the toggle wiring through the webview, and the error path when disable refuses are typecheck-and-reasoning only. Items 1 through 3 and 7 above are the checks that close this, and none of them has been performed.
- **The SARIF upload path.** The self-test sets `upload-sarif: false` so it needs no `security-events` permission, and the generated workflow no longer requests one, so nothing here has exercised an upload or seen an annotation render on a diff.
- **`--since` against a real shallow checkout.** The refspec reasoning is sound but unproven; the self-test does not pass `since`.
- **`install-sdk: auto` against a Flutter toolchain.** The self-test exercises the skip branch only.
- **The generated workflows executing on a runner** — for `--emit-ci`, for the card, or for the vibrancy generator's three platforms. Their content is verified; their behavior in GitHub Actions and GitLab CI is not.
- **The major tag move.** The code path runs only during a release, and the 16.3.0 release has not been cut yet.
- **The publish step end to end in a live extension host.** The git layer beneath it is covered against real repositories, but the button that triggers it, the progress notification, the clipboard write, and the GitHub sign-in have only been typechecked. Items 5 through 8 of the test list exist to close that.
- **Pull request creation against the GitHub API.** No call has been made. The request shape follows the documented endpoint, and every failure mode falls back to the compare page, but neither the success path nor the fallback has been observed.

**Known follow-ups, not addressed here:**

- No CI job runs the extension's TypeScript tests, and `npm test` currently has 32 failures on `main` that predate this branch — the new tests here were checked against that exact baseline (2188 passing before, 2213 after, the same 32 failing). Those two facts are the same fact: a suite nothing runs is a suite that rots. Nothing invokes `npm test`; the suite is local-only, which is the deeper reason `ci-generator.test.ts` sat unregistered in the mocha file list long enough for assertions on a nonexistent `maxLegacy` field to survive.
- `ci.yml` triggers only on `pull_request: branches: [main]`, so a pull request targeting any other branch gets no CI at all. This PR hit it, and it will catch someone else.
- The `analyze` job commits formatting changes using `GITHUB_TOKEN`; the resulting run comes back `action_required` and never executes, so the final head can carry no `ci` result while an identical tree passed one commit back.
