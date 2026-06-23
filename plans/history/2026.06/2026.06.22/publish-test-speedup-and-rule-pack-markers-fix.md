# Publish Test Speedup + Rule-Pack Markers / Metrics-Resolver Fixes

The additive-pack expansion added concern and platform rule packs to the rule-code
registry without matching pubspec-marker entries, breaking the registry invariant
that every pack has a marker and failing `rule_packs_pubspec_markers_test`. In the
same session the publish test step was halved by tagging the five full-repo scan
integration tests `slow` and excluding them from the local fast pass (CI still runs
the full suite), and a pre-existing Python metrics-test failure for the
`pubspec_constraint` category was resolved.

## Finish Report (2026-06-22)

### 1. Rule-pack pubspec markers (failing Dart test)

**Defect.** `kRulePackRuleCodes` gained 14 generated concern packs
(`accessibility`, `security`, `performance`, …, via `kRuleThemePackCodesGenerated`)
and 6 manually-listed platform packs (`ios`, `android`, `web`, `windows`, `macos`,
`linux`), but none received entries in `kRulePackPubspecMarkers`.
`rule_packs_pubspec_markers_test` asserts the two maps share an identical key set
and that every marker is non-empty, so it failed first on `accessibility`, then on
`ios`.

**Fix.** The codebase convention is that cross-cutting (non-package) packs carry an
advisory `{'flutter'}` marker — the four older thematic packs (`ui_excellence`,
`localization`, `documentation`, `testing`) already do, and the marker only feeds
the "applicable" hint in init / the dashboard, never a hard gate.

- `tool/generate_rule_pack_registry.dart` now emits
  `kRuleThemePackPubspecMarkersGenerated` (`{'flutter'}` per concern pack) so the
  markers stay in sync with the generated rosters on every regeneration.
- `lib/src/config/rule_pack_codes_generated.dart` was regenerated to include that
  map (formatted to keep the diff additive).
- `lib/src/config/rule_packs.dart` spreads the generated concern-pack markers into
  `kRulePackPubspecMarkers` and adds advisory `{'flutter'}` markers for the six
  platform packs (folder-detected at suggestion time, so the marker is advisory
  only).

Platform packs keep folder detection as the real suggestion driver; the marker
exists solely to satisfy the universal-marker invariant and matches the existing
thematic-pack representation in the init listing.

### 2. Metrics resolver for `pubspec_constraint` (failing Python test)

**Defect (pre-existing, from the `pubspec_constraint` rule feature).**
`test_rule_metrics.test_rule_instantiation_stats_see_nested_files` asserts every
rule category resolves to a test file. The `pubspec_constraint` category's coverage
lives in `pubspec_constraint_parser_test.dart` (the rules are thin wrappers over the
constraint parser and can only be exercised through the scan CLI, since custom_lint
analyzes `.dart`, not the `.yaml` they target). The resolver only tries
`{category}_rules_test` / `{category}_test` stems, so it missed the `_parser_test`
file and reported 151 of 152 categories tested.

**Fix.** `scripts/modules/_rule_metrics.py` `_test_category_alias` now maps
`pubspec_constraint` → `pubspec_constraint_parser`, so the resolver finds the
existing test. This mirrors the existing `repo_integrity` → `config` alias.

### 3. Publish unit-test step speedup

**Goal.** The publish script ran the entire suite (~157s locally) with no
concurrency tuning. Measurement showed the cost is dominated by a handful of
integration tests that run the full scanner / cross-file analysis over the whole
repo tree.

**Change (`scripts/modules/_publish_steps.py`).**
- `dart test` now runs with `-j <logical cores>` (was the default ~half).
- The five heaviest integration tests are tagged `@Tags(['slow'])` and the publish
  test step runs a fast pass that excludes them (`-x slow`). Measured fast pass:
  ~89s (down from ~157s).
- The slow tests are NOT dropped overall: `ci.yml` and `publish.yml` both run the
  full `dart test` on every push and release, so the slow integration tests are
  verified in CI before any tag is cut. They run locally on demand with
  `dart test -t slow`.

**Why not a second local slow pass.** A `dart test -t slow` invocation still
compiles all test files to discover the tag, then runs only the tagged five, so a
second local pass costs ~158s — worse than one full run. Splitting only pays off
because CI carries the slow set; running both passes locally would roughly double
the wall time. The two-pass-both-local approach was prototyped, measured, and
discarded in favor of fast-local + slow-in-CI.

**Tagged files** (`@Tags(['slow'])` + `library;` directive added):
`test/scan/scan_runner_test.dart`, `test/scan/fixture_lint_integration_test.dart`,
`test/cli/cross_file_test.dart`, `test/project_health/health_history_test.dart`,
`test/scan/fix_application_dart_fix_dry_run_test.dart`. The `slow` tag is declared
in `dart_test.yaml` so the runner does not warn about an unknown tag.

### 4. Spec authored

`plans/specs/LINT_RULE_CONFIGURATION_SCREEN.md` documents the extension's lint-rule
configuration screen (tier control, rule packs, per-rule overrides). A pre-existing
draft already covered most of the surface; this session added the version-group
control section and an open-gap entry, sourced from
`plans/RULE_PACKS_VERSION_GROUP_UI_PLAN.md`.

### Verification

- `dart test test/config/rule_packs_pubspec_markers_test.dart` — 5/5 pass.
- `dart test test/config/{rule_packs_config,rule_pack_registry,analysis_options_rule_packs,rule_packs_sdk_gates,rule_packs_migration_membership,rule_packs_semver}_test.dart` — pass.
- `python -m unittest scripts.modules.tests.test_rule_metrics` — 9/9 pass;
  full `python -m unittest discover -s scripts/modules/tests` — 96/96 pass.
- Fast pass `dart test -x slow -j 24` — +6333 pass, 1 skipped, exit 0, no
  unknown-tag warning.
