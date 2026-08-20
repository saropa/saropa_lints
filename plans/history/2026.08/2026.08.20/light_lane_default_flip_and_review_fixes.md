# Light-lane default flip, review pass, and test-wiring fixes (2026-08-20)

The two-lane daemon architecture (`plans/PLAN_two_lane_daemon_architecture.md`) shipped
this release with `light` as an opt-in `lane:` value defaulting to `full`. RSS
measurement earlier the same day showed the light lane costs +0.6% memory over
the plugin-off baseline (vs +77.2% for full), which made opt-in the wrong
default: a setting this safe that requires hand-editing YAML will not be found
by most users. This report covers flipping the default and a subsequent deep
review pass before the 15.2.0 release commit.

## Default flip

- `lib/src/config/rule_lane.dart`: `_activeLane` initial value and
  `resetRuleLaneForTest()` changed from `RuleLane.full` to `RuleLane.light`.
  `parseRuleLane` now returns `RuleLane.light` for an absent/empty `lane:` key
  (previously `full`); an unrecognized non-empty value (a typo) still falls
  back to `RuleLane.full`, the more conservative reading of a value that was
  clearly meant to say something.
- `extension/src/config/laneConfig.ts`: `projectConfiguresLightLane` updated to
  treat an absent `lane:` key as light (previously not-light), matching the
  Dart-side default. Safety is preserved regardless of this function's answer
  because `resolveExcludeLane` additionally requires `pluginIsLive` before
  ever excluding rules from a scan — a disabled or unresponsive plugin still
  gets a full scan.
- Doc comments and the generated `analysis_options.yaml` template comment
  (`lib/src/init/config_writer.dart`) updated to describe `light` as the
  default rather than `full`.
- `test/integrity/rule_lane_test.dart`'s `parseRuleLane` test renamed and
  updated to assert the new absent-vs-typo split.
- `plans/PLAN_two_lane_daemon_architecture.md` status header and acceptance
  criterion 1 revised to record the default-flip decision and its date.

## Deep review findings (subagent, general-purpose/sonnet)

A full-diff review across the perf + two-lane changes surfaced one real defect
and several test gaps, all addressed:

1. **CHANGELOG accuracy**: the entry for `prefer_moving_to_variable`,
   `prefer_pattern_destructuring`, `avoid_multiple_stream_listeners`, and
   `require_sqflite_transaction` claimed the block-skip fix stopped
   over-counting "across mutually exclusive branches," but the code change
   (skip recursion into any nested `Block`) applies to loop bodies, `try`
   bodies, and single-branch `if`s too — not just `if`/`else` siblings. Those
   are not mutually exclusive with their enclosing scope; a write split across
   such a boundary is now judged as two separate, smaller counts instead of
   one combined one, which can suppress a true positive. Rewrote the
   CHANGELOG entry to describe the actual scope (block-scoped counting, not
   branch-exclusivity) and name the false-negative tradeoff explicitly. No
   code change made — the design tradeoff (double-counting eliminated,
   cross-block sequences no longer summed) was judged acceptable to ship as
   documented rather than requiring a control-flow-aware rewrite before this
   release.
2. **`extension/src/config/laneConfig.ts` and its test file were never wired
   into the extension's TypeScript project.** `laneConfig.ts` was missing from
   `tsconfig.test.json`'s `include` list, and `laneConfig.test.ts` used the
   TDD `suite`/`test` mocha interface while the project runs BDD (`describe`/
   `it`, no `.mocharc`, default UI) — both defects meant the file had never
   actually compiled or run despite existing since the prior session. Fixed by
   adding both files to `tsconfig.test.json`, rewriting the test file to
   `describe`/`it`, adding the `register-vscode-mock` import required by any
   test that transitively imports `vscode` (via `pluginLiveness.ts`), and
   wiring the compiled output into `extension/package.json`'s `test` script
   file list. Also added test coverage for `projectConfiguresLightLane`
   (untested before this session, despite being the function whose default
   just flipped) covering absent/light/full/typo/missing-file cases — 15/15
   passing.
3. **`--exclude-light-lane` scan CLI flag had no test** despite mirroring the
   already-tested `--profile` pattern. Added
   `test/scan/scan_cli_args_test.dart`'s `--exclude-light-lane sets the flag
   and defaults to off` test.
4. Reviewed and confirmed clean: lane-default fail-open behavior (full lane or
   unpublished membership always allows every rule), rule registration/tier
   assignment (untouched, correctly out of scope), the hot-rule perf reorders
   (`config_rules.dart`, `platform_rules.dart`, `firebase_rules.dart`,
   `isar_rules.dart` — cheap syntactic gates moved earlier, no correctness
   change), `ProjectContext._rootByDir` memoization, and the `.saropa_stop`
   abort sentinel.

## Deferred, not fixed this session

- No test added for the 4 nested-block dedup rules' new behavior (neither the
  intended dedup fix nor a guard against the false-negative tradeoff). Flagged
  in the review as the most important remaining test gap; deferred because
  fixing the underlying scope question (should a `try`/loop body sum with its
  enclosing scope?) needs a design decision, not just a test.
- No test added for `bin/scan_daemon.dart`'s `excludeLane` request-field
  handling or `ScanRunner.excludeLightLane` end-to-end — only the underlying
  predicate (`excludeLightLaneRules`) is unit-tested.
- Extension lane-picker UI (plan's remaining gap) not built — still tracked as
  open work in the plan, which was deliberately NOT archived/closed this
  session since that gap is real, unfinished work.

## Verification

- `dart test test/integrity/rule_lane_test.dart test/scan/scan_cli_args_test.dart --reporter compact` — 46/46 pass.
- `cd extension && npx tsc -p tsconfig.test.json --noEmit` — clean.
- `node node_modules/mocha/bin/mocha "out-test/test/config/laneConfig.test.js" "out-test/test/config/tierConfig.test.js" "out-test/test/config/severityConfig.test.js" --timeout 10000` — 30/30 pass.
