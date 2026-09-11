# PR 336 — Composite GitHub Action for running saropa_lints on PRs

**Branch:** `claude/inspiring-pascal-tjfi2j` · **Created:** 2026-09-11
**Plan:** `plans/PLAN_ci_automation.md` (this PR is WP1 of four)

---

## Objective

Let a consumer project run saropa_lints against its pull requests without hand-maintaining a workflow file.

Before this change, the only route was to copy roughly twenty-five lines of YAML out of `doc/guides/cli.md` into each repository. That has two costs. Consumers carry setup logic they did not write and cannot easily validate, and when the `audit` CLI gains or renames a flag, every copied workflow silently keeps using the old form — the fix ships in documentation that nobody re-reads. Packaging the workflow as an action moves that logic into one versioned place, so a flag change reaches consumers through a tag bump.

Scope is deliberately narrow: this PR wraps the `audit` command only. It does not touch `quality_gate`, `cross_file`, or `baseline`, and it does not change how this repository analyzes itself.

---

## What I did

### `action.yml` (new, repo root)

A composite action wrapping SDK setup, `pub get`, `dart run saropa_lints audit`, and the SARIF upload. Thirteen inputs, three outputs. The consumer-facing surface is two lines of configuration in the common case.

Four design decisions carry most of the weight:

**The audit step never fails the job; a single `Evaluate result` step decides.** The audit step captures the exit code into an output and always succeeds. If the audit step failed directly when findings existed, every step after it would be skipped — including the SARIF upload, which is the entire point of `annotate` mode. Centralizing the decision also means there is exactly one place to read to know what makes the job red.

**Exit code 2 fails the job in every mode, including `annotate`.** The `audit` CLI distinguishes 0 (clean), 1 (findings), and 2 (could not run: bad arguments, `pub get` not run, not a Dart project). Only exit 1 is subject to the mode. Exit 2 means the audit never examined any code, so reporting green would assert something that was never checked. This is the same failure class as the existing vibrancy CI generator, which emits a workflow that always passes; being explicit here is deliberate.

**`install-sdk` defaults to `auto` and skips when `dart` is already on `PATH`.** Flutter projects obtain Dart through `flutter-action`. An unconditional `setup-dart` would install a bare Dart SDK on top of it and shadow the Flutter toolchain. `auto` detects the existing SDK and does nothing, so a Flutter consumer needs no special configuration.

**The `--since` fetch uses an explicit refspec.** `actions/checkout` configures a single-branch fetch refspec. Under it, `git fetch origin main` updates `FETCH_HEAD` without creating `refs/remotes/origin/main`, so `--since origin/main` would still fail to resolve on a default shallow checkout. The step fetches `+refs/heads/<branch>:refs/remotes/origin/<branch>` and warns if the ref still does not resolve afterward, rather than silently auditing the whole project when the consumer asked for changed files only.

The dependency check reads the resolved package graph (`.dart_tool/package_config.json`) rather than grepping `pubspec.yaml`. The original grep matched the substring `saropa_lints` anywhere in the file, so it also accepted a package merely *named* `saropa_lints_self_check` or `saropa_lints_example`, and a passing mention in a comment — turning a precise error message into a misleading one. A tightened regex is retained as a fallback for when the package graph is unavailable.

Inputs are validated in the first step — before any SDK install or audit — so a typo in `mode` or `min-severity` fails quickly with a message naming the offending value.

### `doc/guides/cli.md`

The "GitHub Actions CI with SARIF" section now leads with the action and keeps the hand-written workflow below it under "Doing it by hand." Added a table mapping each mode to its two observable behaviors (upload, fail), a note that exit 2 fails in all modes, and guidance to use `mode: gate` on private repositories without GitHub Advanced Security, where code-scanning upload is unavailable.

### `.pubignore`

Added `action.yml`. It is CI infrastructure for consumers of the repository, not of the package, and has no reason to occupy space in the pub.dev tarball.

### `plans/PLAN_ci_automation.md`

Recorded a blocker found while writing the docs, described under "Known blocker" below.

### `.github/workflows/action-selftest.yml` (new)

Executes the action on a real runner using `uses: ./`, which references the action straight from the checkout. That works before any tag exists and always tests the version in the pull request rather than a release, so it also sidesteps the major-tag blocker for verification purposes.

It targets `self_check/`, a real package that already depends on saropa_lints by path and contains one Dart file, so the audit is quick.

Four assertions, chosen so that each one fails loudly rather than silently passing:

- **Annotate mode produces a usable result.** Exit code is 0 or 1, a `sarif-file` output is set, the file exists, and `jq` confirms it is a SARIF document rather than an empty or native-format file. Reaching the assertion at all is itself part of the test, since annotate mode must not fail the job on findings.
- **Gate mode honors the exit code.** Asserts the relationship between the two runs rather than a fixed outcome: if the annotate run reported findings, the gate run must have failed; if it reported none, the gate run must have passed. This stays deterministic whether or not `self_check` currently has violations.
- **An invalid mode is rejected.**
- **A directory that is not a Dart project is rejected.**

The last two matter most. A green result there would mean the action reports success without auditing anything, which is the specific failure this design exists to rule out.

The workflow is `paths`-filtered to `action.yml` and itself, so it does not run on unrelated changes, and it needs no `security-events` permission because the self-test sets `upload-sarif: false`.

### What the self-test caught on its first run

It failed immediately, on the bug it was written to catch.

GitHub invokes step shells as `bash --noprofile --norc -e -o pipefail`. `-e` is therefore already active, and the audit step's `set -uo pipefail` does not clear it — it sets `u` and `pipefail` and leaves `e` alone. So when the audit exited 1 because findings existed, the step aborted before `code=$?` ran. The `exit-code` output was never written, the SARIF upload was skipped, and `Evaluate result` correctly reported that the audit step had not run to completion.

The capture-then-evaluate design was right; the shell's `-e` defeated it. The fix is an explicit `set +e` around the audit call, restored to `set -e` afterward.

This is worth spelling out because it is invisible in local testing: a script run as `bash script.sh` has no `-e`, so the logic passes locally and fails on a runner. It was reproduced here by invoking the extracted logic with the runner's exact shell flags, confirming the failure, then confirming the fix under the same flags.

The run also surfaced a smaller reporting flaw. On a validation failure the log carried two errors: the accurate one (`mode must be annotate, gate or both (got 'not-a-real-mode')`) followed by `The audit step did not run to completion`, emitted by `Evaluate result` because it runs under `if: always()` and cannot distinguish a rejected input from a crashed audit. The second line reads as a crash and would send someone hunting for one after a simple typo. It now says `saropa_lints did not run. See the error above for the cause.`, which is true in both cases and asserts nothing it cannot know.

The rest of the action was swept for the same hazard. Every other command whose non-zero exit is expected sits inside an `if` condition or is guarded with `||`, both of which `-e` exempts. The bare `[ -n "$X" ] && args+=(...)` lines are also exempt, because the failing command is not the one following the final `&&` — verified rather than assumed.

---

## Considered and rejected

**Wrapping only `audit`.** ~~Rejected `scan` because anyone setting this up already has the dependency.~~ **Reversed.** That reasoning weighed the wrong axis. The question is not which command can reach the project, it is which one lets a team control the 2332 rules and decide what fails the build — and `scan` wins both decisively:

| Need | `audit` | `scan` |
|---|---|---|
| Per-rule on/off via `analysis_options.yaml` | no | yes |
| `--tier` override | no | yes |
| `--fail-on <severity>` — report all, fail on some | no | yes |
| `--fail-on-tier` — fail only on essential during adoption | no | yes |
| `--fail-on-count <n>` — tolerate a known baseline | no | yes |
| SARIF for PR annotations | yes | no |

`audit` bypasses the tier cap by design (`bin/audit.dart:5`), so under audit a project configured for `essential` still gets pedantic-tier findings, and `min-severity`/`min-impact` only filter the report after everything has already run. There was no way to express "run my configured rule set."

Neither command covers both jobs, because SARIF is wired into `audit` alone. So the action now takes a `command` input (`auto`/`audit`/`scan`) with `auto` resolving `gate` to `scan` and the SARIF modes to `audit`, and exposes scan's tier and fail-on-* flags.

**Silently ignoring inapplicable inputs.** Rejected: a `tier` accepted and quietly dropped under `audit` would leave a team believing CI honors their configured rule set while every rule runs. Mismatched inputs are a hard error naming the offenders.

**Passing glob inputs straight through to either command.** Rejected because the two disagree on grammar: `audit` takes one comma-separated value, `scan` consumes each following non-flag argument as its own pattern. A comma-joined string reaches `scan` as a single literal glob containing commas, matching nothing and reporting no error. The action translates per command.

**Exposing `tier` as an audit input.** Still rejected, and it is not possible: `audit` has no `--tier` flag. `tier` is a scan-only input, and passing it with `command: audit` is rejected rather than ignored.

**Always installing the Dart SDK.** Simpler to reason about and makes the minimal example shorter, but breaks Flutter consumers by shadowing the Flutter-provided Dart. The `auto` default costs one small step and one input, and removes an entire class of confusing failure.

**Letting the audit step fail the job directly.** The obvious shape, and wrong: it skips the SARIF upload exactly when there is something to annotate. Rejected in favor of the capture-then-evaluate structure.

**Making the SARIF upload unconditional.** Rejected because upload requires `security-events: write` and, on private repositories, GitHub Advanced Security. Consumers without it need a path that still enforces, which is what `mode: gate` provides. The upload is therefore conditional on both mode and the `upload-sarif` input.

**Treating a findings exit as a flake or warning in `gate` mode.** Never considered seriously, noted for completeness: the point of gate mode is that findings are failures.

---

## Known blocker

`uses: saropa/saropa_lints@v16` — the form GitHub Actions users expect — does not resolve. The release process creates only exact tags (`v{version}`, `scripts/modules/_git_ops.py:660`); there is no moving `v16` tracking the latest 16.x release.

The documentation currently pins `@v16.2.1`, which works but means consumers must bump manually on every release, removing much of the reason to package the action. The fix is to force-move a major tag as part of release step 13. That is a small change, but it is a change to the release process and did not belong in this PR uninvited.

This does not block merging. It blocks the action being pleasant to consume.

---

## What to test

`action-selftest` now covers items 1 through 4 automatically on every run, so the list below is what a human should confirm *beyond* what CI proves. Watch the `action-selftest` check on this PR first: if it is green, the action demonstrably runs, annotates, gates, and rejects bad configuration on a real runner.

**1. The action runs at all.** *(now covered by `action-selftest`)* First execution of a composite action is where context and quoting problems surface. If that check is green, this is proven.

**2. Findings appear as annotations.** *(partially covered)* The self-test proves a valid SARIF file is produced but deliberately does not upload it. A human still needs to confirm that findings render inline on a PR diff in the Files Changed view, with the job staying green. Green with annotations is the intended outcome, not a contradiction.

**3. Gate mode actually fails.** *(now covered by `action-selftest`)* The self-test asserts that gate mode fails exactly when findings exist. This is the specific failure the existing vibrancy generator has, so it is worth confirming the assertion really ran by reading the check's log rather than trusting the green tick.

**4. A broken setup fails loudly.** *(now covered by `action-selftest`)* Both an invalid mode and a non-Dart directory are asserted to fail.

**5. Changed-files-only works on a normal checkout.** With `since: origin/${{ github.base_ref }}` and a plain `actions/checkout@v5` (no `fetch-depth: 0`), confirm the log shows the base ref being fetched and the audit covering only the PR's files. If it silently audits everything, the refspec handling is wrong.

**6. A Flutter project does not get a second SDK.** With `subosito/flutter-action@v2` before this step, the log should say it found Dart on `PATH` and skipped the install.

**7. Private repository without Advanced Security.** If one is available, confirm `mode: annotate` fails in a comprehensible way when it cannot upload, and that `mode: gate` works as the documented alternative. This is the scenario most likely to produce a confusing first-time experience, and it is untested.

---

## Verification status

**Ran, passed:**

- Every flag the action can emit (`--format`, `--output`, `--quiet`, `--since`, `--min-severity`, `--min-impact`, `--exclude-globs`, `--include-globs`, `--baseline`, `--baseline-path`) checked programmatically against the argument parser in `bin/audit.dart`. All ten are accepted; `audit` has no `--tier`.
- Argument assembly extracted and exercised for all three modes, with and without optional inputs. Produces the expected command lines.
- The glob-expansion bug in the scan translation, demonstrated against a real directory: with unquoted word splitting, `vendor/*` was replaced by `vendor/a.dart vendor/b.dart` before the CLI saw it; with `read -ra` the pattern survives intact.
- Command resolution and argument assembly for `auto`/`audit`/`scan` across all three modes, including that `audit` receives one comma-joined glob argument while `scan` receives each pattern separately.
- The `-e` failure above, reproduced under the runner's exact shell invocation (`bash --noprofile --norc -e -o pipefail`): before the fix the exit code is never captured and the step exits 1; after it, the code is captured and the step exits 0.
- The tightened dependency check, both branches: the `jq` package-graph branch accepts a real `saropa_lints` entry and rejects a package merely named `saropa_lints_self_check`; the fallback regex accepts `self_check`'s dev dependency and rejects both a comment-only mention and a package named `saropa_lints_example`. The original grep accepted all three false cases.
- The pass/fail decision matrix exercised across all nine mode-by-exit-code combinations. Exit 2 fails in all three modes; exit 1 fails only in `gate` and `both`; exit 0 always passes. An empty exit code (audit step did not complete) fails.
- `action.yml` parses as YAML; structure inspected for expected step and `uses:` shape.
- `scripts/check_doc_links_excluded_paths.py` — passes.
- `scripts/check_dependency_imports.py` — passes.

**Did not run:**

- **The `scan` path against a real project, locally.** `action-selftest` gained four assertions covering it — that `scan` runs and honors its exit contract under `mode: gate` with `tier` and `fail-on-tier`, and that both incompatible combinations (`scan` with a SARIF mode, a scan-only input passed to `audit`) are rejected. Those assertions have not yet reported at the time of writing.
- **The action itself, locally.** There is no Dart SDK in the authoring environment, so nothing about the action was executed here. Its shell logic was tested by extracting it into standalone scripts. `action-selftest` is what actually exercises it, and its first run is on this PR — so at the time of writing, the action's real behavior is asserted by CI but those assertions have not yet reported.
- The SARIF **upload**, and therefore whether annotations render on a PR diff. The self-test deliberately sets `upload-sarif: false` so it needs no `security-events` permission and does not post to code scanning, which means the upload path remains unproven.
- The `--since` fetch against a real shallow checkout. The refspec reasoning is sound but unproven; the self-test does not pass `since`.
- `install-sdk: auto` against a real Flutter runner. The self-test exercises the *skip* branch (dart already on PATH via setup-dart) but not a Flutter toolchain.
- `dart analyze`, `dart test`, and `dart pub publish --dry-run`. No Dart or Python source changed in this PR, so these were judged not to apply; CI will run them regardless.

**One process note:** the first pass of the decision-matrix test was written incorrectly — `if bash script | tr` captures the exit status of `tr`, not of the script, so every case reported as passing. The harness was corrected and re-run, and the results above are from the corrected run. Flagging it because a test that cannot fail is worse than no test, and the same mistake is easy to repeat when reviewing this.
