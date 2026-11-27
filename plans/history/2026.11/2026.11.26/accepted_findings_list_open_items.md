# Accepted-findings list: open items

**Status: Closed** (completed work archived here; unchecked items continue in `plans/history/2026.11/2026.11.26/accepted_findings_f5_translations_and_baseline_date.md`)

Created: 2026-11-26
Source: `plans/history/2026.11/2026.11.26/proposal_infra_accepted_findings_list.md`

## F5 check (light and dark themes)

- [ ] "Accept {rule} in this file" lightbulb on a Saropa finding; absent on SDK lints
- [ ] Kind picker
- [ ] Empty reason is refused
- [ ] Confirmation toast and its two buttons
- [ ] "Check Accepted Findings" toolbar button on `saropa_accepted.yaml`
- [ ] Problems markers on the list file (stale = warning, invalid = error)
- [ ] Empty state (no list file) and clean state (no stale or invalid entries)
- [ ] Summary tree shows "N accepted"
- [ ] Screenshot saved to `bugs/`

## Translations

- [ ] (Human: translation pipeline must not be run by an agent.) Regenerate translation catalogs for the new `acceptedFindings.*` and `command.checkAcceptedFindings.title` keys. Locale-parity tests fail until then. `acceptedFindings.info.added` now takes `{list}`; `info.noList` and `error.outsideProject` were reworded.

## Nested packages: one root rule everywhere

Every surface now matches a file against the list beside its nearest `pubspec.yaml`, through one Dart helper (`acceptedRootFor` in `lib/src/accepted/accepted_findings_roots.dart`) and its TypeScript mirror (`findPackageRoot` in `extension/src/acceptedFindingsModel.ts`).

- [x] `scan`, scan daemon, language server and `audit` filter each finding by its own package's list (`filterAcceptedByNearestRoot`).
- [x] `scan --check-accepted` checks every list under the target (`discoverAcceptedLists`; dot folders, `build`, `node_modules` and `Pods` skipped, links not followed). JSON is now version 2: one object per list under `lists`. An outer entry naming a nested package's file, and a list with no `pubspec.yaml` beside it, are reported as invalid.
- [x] Extension "Accept {rule} in this file" writes to the list of the file's nearest `pubspec.yaml`.
- [x] Extension "Check Accepted Findings" runs the CLI once per workspace folder that depends on saropa_lints (plus the first folder's project root), merges the results and places markers on every list.
- [x] Extension check: a second workspace folder whose `pubspec.yaml` sits one level down, or that does not depend on saropa_lints itself, is not checked. Fixed 2026-11-26: `planCheckRuns` (`extension/src/acceptedCheckRoots.ts`) finds each folder's package root at the folder or one level down (`findProjectRootIn`, split out of `getProjectRoot`); a root without the dependency that has a list or enables the plugin in `analysis_options.yaml` is scanned by launching the CLI from the first root that has the package. Mocha `acceptedCheckRoots.test.ts` (7 cases). Not run in an Extension Development Host.
- [ ] F5: Accept in a nested package and in a second workspace folder; Check with lists in two packages (markers on both files, "Open List" opens the first failing one). Also: a second folder with `pubspec.yaml` one level down, and a folder that only enables the plugin in `analysis_options.yaml` (CLI launched from another folder); "Migrate Renamed Rules" on a list naming a renamed rule.

Verified 2026-11-26: `dart test test/accepted/` (31 passed), throwaway project with `example/` nested package: `scan` hid each package's own entries only; `--check-accepted` reported 3 lists (nested entry `hides 1`, missing file stale, outer entry into `example/` invalid, stray `tool/` list invalid, `build/` list skipped), exit 1. Daemon and language server compile but are not run against a nested package.

## Not implemented

- [x] Rule-rename migration of list entries (`saropaLints.migrateRuleNames`). Done 2026-11-26: `rewriteAcceptedList` (`extension/src/ruleMigration/acceptedListRewriter.ts`) rewrites `rule:` values; the scanner includes `**/saropa_accepted.yaml`. Removed rules are left in place (they carry a reason; `--check-accepted` reports them as unknown). Mocha `acceptedListRewriter.test.ts` (5 cases).
- [ ] Per-entry maximum count. Needs a decision: the proposal marks `max:` as "needs discussion"; adding it changes the version 1 schema (`max` is currently an invalid key), the check JSON and the extension parser.
- [x] Baseline defect 1: activation location mismatch (CLI writes `analysis_options.yaml`, loader reads `analysis_options_custom.yaml`). Confirmed in code (`bin/baseline.dart` inserted under `saropa_lints:` + `tier:`; loader matched `^baseline:` in the custom file). Fixed 2026-11-26: CLI writes a top-level section to `<project>/analysis_options_custom.yaml` via `addBaselineActivation` (`lib/src/baseline/baseline_activation.dart`) and notes a leftover nested entry.
- [x] Baseline defect 2: manager initialized with `Directory.current.path` instead of the project root. Confirmed (`config_loader.dart` `_loadBaselineConfig`). Fixed 2026-11-26: passes the loaded project root and logs a warning when the configured file does not load. Test `test/baseline/baseline_activation_test.dart` loads from a temp root while cwd is the repo.
- [x] Baseline defect 3: `--update` with an active baseline drops still-present entries. Confirmed by reading (the CLI parsed `dart analyze`, which the plugin filters by the baseline). Fixed 2026-11-26: the CLI sets `SAROPA_LINTS_SKIP_BASELINE=1` on its `dart analyze` run and the loader skips the baseline when it is set. Unit-tested (env parsing); not run end to end, because that needs `dart analyze` with the plugin.

## Untested

- [x] Language server filtering. Verified by hand 2026-11-26: throwaway project with nested `pkg/`, driven over stdio (`didSave`): outer list hid `avoid_catch_all` in `lib/a.dart` only (`lib/b.dart` unchanged); nested list hid `avoid_generic_exceptions` in `pkg/lib/c.dart`; an outer entry naming `pkg/lib/c.dart` hid nothing.
- [ ] Plugin with several project roots inside a running analysis server. Needs a human run: requires `dart analyze` or the IDE with the plugin installed. `test/accepted/accepted_findings_test.dart` covers the per-root lookup, not the reporter in a live server.
- [ ] Scan-on-save through the VS Code extension (the daemon itself is verified below). Needs F5.

## Verified by hand

2026-11-26, throwaway two-file project, `--tier pedantic`:

- Scan daemon: an entry hid its rule in the listed file only, other findings were unchanged, and deleting the list restored them on the next request without a daemon restart.
- `scan --check-accepted`: one active entry reported `hides 1`, exit 0.

## Finish Report (2026-11-26)

A review of commit be403f6c7 was closed out. Fixed in the baseline feature: inline lists and trailing comments in the `baseline:` section, activation when the section already exists, the CLI positional project path, `SAROPA_LINTS_SKIP_BASELINE` skipping only the JSON file (this supersedes the "loader skips the baseline" wording under baseline defect 3), and one baseline per project in the plugin. The extension check no longer drops a package nested in a folder that does not run.

Verification: `test/baseline/` and `test/accepted/` passed, `acceptedCheckRoots.test.ts` passed (9 cases), and both extension typechecks passed. One test setup defect in `reporter_multi_root_test.dart` was corrected: the one-time lazy config load reset the reader installed by the test.

Remaining items and blockers:

| Item | Blocker |
|---|---|
| F5 check, all nine boxes including the screenshot | A person with an Extension Development Host |
| Translation catalog regeneration | A person must run the translation pipeline |
| F5 check for nested packages, second folder, plugin-only folder, rule migration | A person with an Extension Development Host |
| Per-entry maximum count | Owner decision on the version 1 schema change |
| Plugin with several project roots in a live analysis server | A person running the IDE or `dart analyze` with the plugin; the new test covers the reporter in the harness only |
| Scan-on-save through the extension | A person with an Extension Development Host |

Not run end to end: `dart run saropa_lints:baseline` against a real project.

### Follow-up (2026-11-26)

A hardening pass added: blame answers survive a config reload; the loader reading the real `SAROPA_LINTS_SKIP_BASELINE` variable and `bin/baseline.dart` with a positional project path are tested in child processes (the CLI's `dart analyze` call is answered by a stub script, so no analysis runs); legacy `only_impacts` names are tested through the loader; the overlay navigation and handler checks were narrowed; a constant list is no longer treated as shadowed by inherited or mixin members, which Dart does not put in lexical scope. `dart run saropa_lints:baseline --explain <file>` was added.

Open items: `plans/history/2026.11/2026.11.26/accepted_findings_f5_translations_and_baseline_date.md`.
