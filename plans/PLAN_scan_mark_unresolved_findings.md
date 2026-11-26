# PLAN: mark findings from type-resolution rules as unconfirmed in syntactic scans

**Status: Proposed, not implemented**

Created: 2026-11-26

## Goal

A syntactic scan runs rules that need type resolution without types. Their findings look the same as every other finding. Mark them "unconfirmed; re-run with --resolve".

## Current behavior

- `scan` is syntactic unless `--resolve` is given: `bin/scan.dart` (`useResolve`, line 155). `--check-accepted` forces resolution.
- Syntactic units use `ScanRuleContext`, where `typeProvider` / `typeSystem` throw; resolved units use `ResolvedScanRuleContext` (`lib/src/scan/scan_rule_context.dart`, lines 72 and 105).
- Rules are selected by tier, lane and config only, never by resolution need (`lib/src/scan/scan_runner.dart`, around line 750).
- `SaropaLintRule.usesTypeResolution` (`lib/src/saropa_lint_rule.dart`, line 2545) defaults to `false`. A grep counts 1275 `=> true` overrides under `lib/src/rules/`.
- The flag was built for memory control: balanced mode (`lib/src/native/saropa_context.dart`, line 331), light-lane membership (`lib/src/config/rule_lane.dart`, line 104), pressure shedding (`lib/saropa_lints.dart`, line 3142).
- `test/integrity/uses_type_resolution_test.dart` checks the flag per FILE by regex, not per rule. `test/integrity/rule_lane_test.dart` checks per class, for light-lane rules only.
- `ScanDiagnostic` (`lib/src/scan/scan_diagnostic.dart`) and its JSON (`lib/src/scan/scan_json.dart`) carry no resolution information. Diagnostics are built in `_collectDiagnostics` (`scan_runner.dart`, line 1296), which already looks up per-rule metadata (`_ruleImpactMap`).
- The only warning today is the "Resolution note" in `--help` (`bin/scan.dart`, around line 1245). It covers under-reporting, not unreliable findings.

Syntactic runs a user can hit:

| Caller | Where |
| --- | --- |
| `scan` default, including parallel workers | `bin/scan.dart` |
| Scan-on-save with `saropaLints.scanOnSave.resolveTypes` off, daemon suspended, or low memory | `extension/src/scanOnSave/scanOnSaveController.ts`, lines 966-995 |
| External engine scan | `extension/src/externalEngine/externalEngine.ts`, line 61 (no `--resolve`) |

Scan daemon, language server, `audit` and `accuracy_report` are resolved and never mark anything.

## Design

1. `ScanDiagnostic` gains `final bool unconfirmed` (default `false`). `withFilePath` copies it.
2. `ScanRunner` records the names of loaded rules with `usesTypeResolution == true`, next to `_ruleImpactMap`.
3. `_collectDiagnostics` takes a `resolved` argument from its two callers (lines 1054 and 1290) and sets `unconfirmed = !resolved && typeRules.contains(ruleName)`.
4. Parallel workers send `ScanDiagnostic` objects back to the parent; confirm the field survives with a test.
5. Marking only. Counts, severities, `--fail-on*` and exit codes stay as they are.
6. No new flag or config key.

Out of scope: rules that stay silent without resolution (for example instance-creation visitors). They produce no finding to mark; the `--help` note keeps covering them.

The mark is conservative. `usesTypeResolution` means "touches resolved APIs", not "wrong without them", so some marked findings are correct. The wording is "unconfirmed", never "false positive".

## CLI surfaces

- JSON: `"unconfirmed": true` on affected diagnostics, omitted otherwise. `summary.unconfirmedCount` when above zero. `version` stays 1 (additive).
- Text report (`_writeReport`): append `[unconfirmed]` to the line.
- Console summary (`_printSummary`): one line, `N findings unconfirmed; re-run with --resolve.` Printed only when N is above zero.
- `--format json`: the hint goes to stderr and respects `--quiet`.
- `--help`: extend the "Resolution note".

## Extension UI surfaces

- `ScanOnSaveDiagnostic` (`scanOnSaveRunner.ts`, line 130) gains `unconfirmed?: boolean`.
- `toVscodeDiagnostic` (`scanOnSaveController.ts`, line 273) appends a localized suffix to the message. It serves both scan-on-save and the external engine. `source` and `code` stay unchanged so quick fixes and "Accept {rule} in this file" keep matching.
- New key `scanOnSave.diagnostic.unconfirmed` in `en.json`. The wording must not tell an extension user to type `--resolve`: say "Unconfirmed: found without type resolution" and, when the cause is the setting, name `Resolve Types`.
- Low-memory and daemon-suspended notices already explain the fallback; add no new toast.
- Update the `scanOnSave.resolveTypes` setting description in `package.nls.json`.
- F5 check in both themes: Problems panel row and hover. Translation regeneration is a publish-time step.

## Tests

- `ScanRunner` syntactic run: a finding from a `usesTypeResolution` rule is marked; one from a syntactic rule is not (positive case first).
- Same files with `runResolved`: nothing marked.
- Parallel run: the mark survives the isolate boundary.
- JSON: key present only when true; `unconfirmedCount` matches.
- Text report and stderr hint; `--quiet` silences the hint.
- Exit codes under `--fail-on` and `--fail-on-count` are identical with and without marked findings.
- Mocha: `parseScanOnSaveOutput` keeps the field; `toVscodeDiagnostic` adds the suffix only when set; old output without the field still parses.
- Integrity: a per-rule check that a class using resolved APIs declares the flag. Today's per-file check lets one override cover a whole file, which would leave findings unmarked. Failures it finds are rule fixes, tracked separately.

## Files

`lib/src/scan/scan_diagnostic.dart`, `scan_runner.dart`, `scan_json.dart`, `bin/scan.dart`, `extension/src/scanOnSave/scanOnSaveRunner.ts`, `scanOnSaveController.ts`, `extension/src/i18n/locales/en.json`, `extension/package.nls.json`, `CHANGELOG.md`, `README.md`.

## Open questions

1. How much of a real syntactic scan gets marked? Measure on one large project before shipping. A large share makes the mark noise, and the fix is then a narrower per-rule property (for example `unreliableWithoutResolution`).
2. Is `usesTypeResolution` accurate per rule? Both directions need the per-rule audit above.
3. Should `--fail-on*` get an opt-in to ignore unconfirmed findings? Proposed: no, until someone asks.
4. Does any baseline generator build from a syntactic scan, and should unconfirmed findings be baselined? Not checked.
5. Do any other consumers of scan JSON validate keys strictly (CI scripts, Drift Advisor mapper)?
6. Should the external engine pass `--resolve` instead of marking? Cost: slower, more memory.
