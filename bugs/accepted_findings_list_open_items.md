# Accepted-findings list: open items

**Status: Open**

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

- [ ] Regenerate translation catalogs for the new `acceptedFindings.*` and `command.checkAcceptedFindings.title` keys. Locale-parity tests fail until then. `acceptedFindings.info.added` now takes `{list}`; `info.noList` and `error.outsideProject` were reworded.

## Nested packages: one root rule everywhere

Every surface now matches a file against the list beside its nearest `pubspec.yaml`, through one Dart helper (`acceptedRootFor` in `lib/src/accepted/accepted_findings_roots.dart`) and its TypeScript mirror (`findPackageRoot` in `extension/src/acceptedFindingsModel.ts`).

- [x] `scan`, scan daemon, language server and `audit` filter each finding by its own package's list (`filterAcceptedByNearestRoot`).
- [x] `scan --check-accepted` checks every list under the target (`discoverAcceptedLists`; dot folders, `build`, `node_modules` and `Pods` skipped, links not followed). JSON is now version 2: one object per list under `lists`. An outer entry naming a nested package's file, and a list with no `pubspec.yaml` beside it, are reported as invalid.
- [x] Extension "Accept {rule} in this file" writes to the list of the file's nearest `pubspec.yaml`.
- [x] Extension "Check Accepted Findings" runs the CLI once per workspace folder that depends on saropa_lints (plus the first folder's project root), merges the results and places markers on every list.
- [ ] Extension check: a second workspace folder whose `pubspec.yaml` sits one level down, or that does not depend on saropa_lints itself, is not checked.
- [ ] F5: Accept in a nested package and in a second workspace folder; Check with lists in two packages (markers on both files, "Open List" opens the first failing one).

Verified 2026-11-26: `dart test test/accepted/` (31 passed), throwaway project with `example/` nested package: `scan` hid each package's own entries only; `--check-accepted` reported 3 lists (nested entry `hides 1`, missing file stale, outer entry into `example/` invalid, stray `tool/` list invalid, `build/` list skipped), exit 1. Daemon and language server compile but are not run against a nested package.

## Not implemented

- [ ] Rule-rename migration of list entries (`saropaLints.migrateRuleNames`)
- [ ] Per-entry maximum count
- [ ] Baseline defect 1: activation location mismatch (CLI writes `analysis_options.yaml`, loader reads `analysis_options_custom.yaml`)
- [ ] Baseline defect 2: manager initialized with `Directory.current.path` instead of the project root
- [ ] Baseline defect 3: `--update` with an active baseline drops still-present entries

## Untested

- [ ] Language server filtering
- [ ] Plugin with several project roots inside a running analysis server. `test/accepted/accepted_findings_test.dart` covers the per-root lookup, not the reporter in a live server.
- [ ] Scan-on-save through the VS Code extension (the daemon itself is verified below)

## Verified by hand

2026-11-26, throwaway two-file project, `--tier pedantic`:

- Scan daemon: an entry hid its rule in the listed file only, other findings were unchanged, and deleting the list restored them on the next request without a daemon restart.
- `scan --check-accepted`: one active entry reported `hides 1`, exit 0.
