# Tier configuration collapsed onto `analysis_options.yaml`

Lint tier (essential/recommended/professional/comprehensive/pedantic) was configurable from four independent, unsynchronized places — the VS Code `saropaLints.tier` setting, the daemon's `--tier` launch flag, the `SAROPA_TIER` environment variable, and two yaml files (`analysis_options.yaml`'s `plugins.saropa_lints` block and the deprecated `analysis_options_custom.yaml`'s `saropa_tier` key). Drift among these caused a live incident in a user's `contacts` project, where the VS Code setting (`professional`), the yaml file (`essential`, after an accidental regeneration), and git history (`recommended`) all disagreed.

## Root cause

Nothing kept the four tier sources synchronized on read. `lib/src/config/runtime_tier_cap.dart`'s `RuntimeTierCap._reload` resolved `SAROPA_TIER` env first, then `analysis_options_custom.yaml`, then `analysis_options.yaml` last — the opposite of what should have been authoritative. On the extension side, `extension/src/scanOnSave/scanOnSaveController.ts` and `extension/src/setup.ts`'s tier picker both read the `saropaLints.tier` VS Code setting directly rather than the yaml file actually driving the scan, so the setting could silently diverge from what a scan or the in-process plugin actually used.

## Fix

`analysis_options.yaml`'s `plugins.saropa_lints.runtime_tier`/`saropa_tier` is now the sole source of truth:

- `lib/src/config/runtime_tier_cap.dart` — `RuntimeTierCap._reload` resolves the yaml value first. `SAROPA_TIER` remains a dev-only override that still wins when set, but now logs a warning (`PluginLogger.warning`) when it disagrees with the yaml's configured tier, rather than silently masking it. `analysis_options_custom.yaml`'s `saropa_tier` key no longer resolves the tier at all — it is parsed only to emit a one-line deprecation warning pointing at the yaml replacement. `_capLabelFor` was extracted as a shared helper so the disagreement warning and the final resolved-cap log line use one label mapping instead of two independent switch statements.
- `extension/src/config/tierConfig.ts` (new) — a TypeScript mirror of `parseSaropaTierFromPluginBlock`'s regex-based block scan, so both the Dart engine and the extension agree on what counts as a configured tier in the yaml.
- `extension/src/scanOnSave/scanOnSaveController.ts` — both the save-triggered scan and the whole-project baseline scan resolve tier via a new `resolveEffectiveTier(root)` helper: yaml first, `saropaLints.tier` setting only as a fallback for a project with no yaml tier configured yet (i.e. never initialized).
- `extension/src/setup.ts`'s `runSetTier` — the tier picker's "current tier" (used for the checkmark, the placeholder text, and the same-tier no-op guard) now reads the yaml first via the same fallback rule, instead of trusting the VS Code setting.
- `extension/src/extension.ts`'s status bar tier label — same yaml-first resolution, so the status bar can't display a tier that disagrees with what actually gets scanned.

## Verification

- `dart analyze lib/saropa_lints.dart lib/src/config/runtime_tier_cap.dart` — no issues.
- `dart test test/config/runtime_tier_cap_test.dart` — 8/8 passing, unmodified (no precedence-order test existed to break; the new precedence order is a superset-safe change against existing coverage).
- Added `extension/src/test/config/tierConfig.test.ts` (7 new cases: missing file, no plugin block, `runtime_tier`, `saropa_tier` alias, quoted values, invalid tier label, sibling-plugin-block false match).
- `tsc -p tsconfig.test.json` and the full `tsc --noEmit` (real `tsconfig.json`, whole extension source) both clean.
- `mocha out-test/test/config/tierConfig.test.js out-test/test/scanOnSave/**/*.test.js` — 46/46 passing, including the pre-existing `scanOnSaveController`/`baselineScanRunner`/`scanDaemonClient` suites, confirming the tier-source change didn't regress the daemon scan path.

## Hardening pass (same day, after initial handoff review)

The handoff reflection flagged that the Dart and TS block parsers are two independent regex implementations with no mechanism keeping them in sync. Added `test/fixtures/tier_yaml_parser_cases.json` — a single shared set of yaml-input → expected-tier cases loaded by both `test/config/runtime_tier_cap_test.dart` and `extension/src/test/config/tierConfig.test.ts`, so a future change to one parser's behavior that the other doesn't match fails a test on the diverging side instead of drifting silently.

Building this fixture immediately surfaced a real mismatch: `parseSaropaTierFromPluginBlock` (Dart) returned the raw, unvalidated tier string for an invalid label (e.g. `not_a_tier`) — validation happened one layer up, in the private `_parseTierLabel` — while the TS mirror validated inline and returned `null`. Fixed by validating inside `parseSaropaTierFromPluginBlock` itself, matching the TS contract; existing call sites in `_reload` still wrap the result in `_parseTierLabel`, which is now a harmless no-op for an already-valid label. `parseSaropaTierFromCustomYaml` was deliberately left unvalidated — it now only feeds the deprecation-warning message, which should show the user's raw configured value even when it's invalid.

Also checked the other reflection item — whether the `SAROPA_TIER`/yaml disagreement warning could get noisy — by tracing `reloadRuntimeTierCapFromProject`/`reloadRuntimeTierCapForPlugin` call sites (`lib/src/native/config_loader.dart`, `lib/src/scan/scan_runner.dart`): both are config-load/process-start paths, not per-file-save paths, so warning frequency is bounded to once per project (re)load, not once per keystroke or save. No rate-limiting added.

Re-verified after the hardening pass: `dart analyze` clean; `dart test test/config/runtime_tier_cap_test.dart` — 14/14 passing (6 new fixture-parity cases, including the now-fixed invalid-label case); `tsc -p tsconfig.test.json` clean; `mocha out-test/test/config/tierConfig.test.js` — 8/8 passing.

## Deliberately out of scope

The daemon `--tier` CLI launch flag itself was not touched directly — `ScanDaemonManager._ensureClient` already respawns the daemon whenever the tier passed to `scan()`/`listFiles()` differs from what the running daemon was launched with, so fixing the *callers* (`scanOnSaveController.ts`) to pass the yaml-resolved tier was sufficient to make the daemon launch flag track the yaml without touching the daemon-spawn code itself.

Not fixed: the underlying `contacts` project's file (`recommended` tier on disk) still doesn't match its VS Code workspace setting (`professional`) — that mismatch predates this fix and needs a one-time manual reconciliation in that project, now that the extension will stop overriding it with the (possibly stale) setting.
