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

Inputs are validated in the first step — before any SDK install or audit — so a typo in `mode` or `min-severity` fails quickly with a message naming the offending value.

### `doc/guides/cli.md`

The "GitHub Actions CI with SARIF" section now leads with the action and keeps the hand-written workflow below it under "Doing it by hand." Added a table mapping each mode to its two observable behaviors (upload, fail), a note that exit 2 fails in all modes, and guidance to use `mode: gate` on private repositories without GitHub Advanced Security, where code-scanning upload is unavailable.

### `.pubignore`

Added `action.yml`. It is CI infrastructure for consumers of the repository, not of the package, and has no reason to occupy space in the pub.dev tarball.

### `plans/PLAN_ci_automation.md`

Recorded a blocker found while writing the docs, described under "Known blocker" below.

---

## Considered and rejected

**Wrapping `scan` instead of `audit`.** `scan` can lint a project that does not declare saropa_lints as a dependency, which would allow one reusable workflow to sweep many repositories across an organization. Rejected as the default because anyone setting this up on their own project already has the dependency, and `audit` is what the existing documentation and SARIF path are built around. Organization-wide scanning of unadopted repositories is a genuinely different use case and can be added later as a `command:` input without disturbing this design.

**Exposing a `tier` input.** This was in the original sketch and turned out not to exist: `audit` deliberately runs every rule regardless of the project's configured tier. Volume control is `--min-severity` and `--min-impact`, which is what the action exposes instead. Worth knowing when reviewing, because a project on the `essential` tier will see comprehensive-tier findings from this action.

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

Everything below is a human check. None of it has been performed.

**1. The action runs at all.** This is the main thing. Point a workflow at the branch — `uses: saropa/saropa_lints@claude/inspiring-pascal-tjfi2j` — in any Dart project that has saropa_lints as a dev dependency, and confirm the job completes rather than erroring on YAML or on an expression that does not evaluate. First execution of a composite action is where context and quoting problems surface.

**2. Findings appear as annotations.** With `mode: annotate` on a pull request touching Dart files, findings should show up inline on the diff in the Files Changed view, and the job should still be green. Green with annotations is the intended outcome, not a contradiction.

**3. Gate mode actually fails.** With `mode: gate` against code you know violates a rule, the job must go red. If it passes, the whole feature is worthless — this is the specific failure the existing vibrancy generator has.

**4. A broken setup fails loudly.** Run it against a directory with no `pubspec.yaml`, or with `mode: nonsense`. Both should fail with a message naming the problem. Neither should report success.

**5. Changed-files-only works on a normal checkout.** With `since: origin/${{ github.base_ref }}` and a plain `actions/checkout@v5` (no `fetch-depth: 0`), confirm the log shows the base ref being fetched and the audit covering only the PR's files. If it silently audits everything, the refspec handling is wrong.

**6. A Flutter project does not get a second SDK.** With `subosito/flutter-action@v2` before this step, the log should say it found Dart on `PATH` and skipped the install.

**7. Private repository without Advanced Security.** If one is available, confirm `mode: annotate` fails in a comprehensible way when it cannot upload, and that `mode: gate` works as the documented alternative. This is the scenario most likely to produce a confusing first-time experience, and it is untested.

---

## Verification status

**Ran, passed:**

- Every flag the action can emit (`--format`, `--output`, `--quiet`, `--since`, `--min-severity`, `--min-impact`, `--exclude-globs`, `--include-globs`, `--baseline`, `--baseline-path`) checked programmatically against the argument parser in `bin/audit.dart`. All ten are accepted; `audit` has no `--tier`.
- Argument assembly extracted and exercised for all three modes, with and without optional inputs. Produces the expected command lines.
- The pass/fail decision matrix exercised across all nine mode-by-exit-code combinations. Exit 2 fails in all three modes; exit 1 fails only in `gate` and `both`; exit 0 always passes. An empty exit code (audit step did not complete) fails.
- `action.yml` parses as YAML; structure inspected for expected step and `uses:` shape.
- `scripts/check_doc_links_excluded_paths.py` — passes.
- `scripts/check_dependency_imports.py` — passes.

**Did not run:**

- **The action itself, on a runner.** Nothing here proves the composite action executes in GitHub Actions. Logic was tested in isolation by extracting the shell into standalone scripts. Expression evaluation, the `inputs` context in step-level `if:` conditions, output passing between steps, and the nested `uses:` steps are all unexercised.
- The SARIF upload, and therefore whether annotations render on a PR diff.
- The `--since` fetch against a real shallow checkout. The refspec reasoning is sound but unproven.
- `install-sdk: auto` against a real Flutter runner.
- `dart analyze`, `dart test`, and `dart pub publish --dry-run`. No Dart or Python source changed in this PR, so these were judged not to apply; CI will run them regardless.

**One process note:** the first pass of the decision-matrix test was written incorrectly — `if bash script | tr` captures the exit status of `tr`, not of the script, so every case reported as passing. The harness was corrected and re-run, and the results above are from the corrected run. Flagging it because a test that cannot fail is worse than no test, and the same mistake is easy to repeat when reviewing this.
