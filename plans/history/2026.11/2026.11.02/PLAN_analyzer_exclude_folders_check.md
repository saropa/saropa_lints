# PROPOSAL: Check analyzer exclusions and suggest excluding folders for performance

**Status: Implemented and merged to main (2026-11-02). Archived 2026-11-10.**

Created: 2026-11-02
Type: Tooling / Infrastructure
Related rules: none (extension-native check, not a Dart AST rule)

---

## Summary

The VS Code extension should inspect the workspace's analyzer exclusion settings and suggest excluding folders that do not need analysis. Slow quick fixes (Ctrl+.) and high analysis-server memory are the symptoms it addresses.

---

## Motivation

A downstream Flutter app (6,689 files in `lib/`, 2,666 in `test/`, 12 local packages under `dependency_overrides/`, 8 GB RAM) has a very slow "add missing import" quick fix. The analyzer must search every library in the workspace for the missing symbol, so cost grows with the number of analyzed files.

Folders that were not excluded in that project at first: `android/`, `ios/`. Other folders were excluded but only in one of the two places that matter, so exclusions drift out of sync.

The analyzer has two separate exclusion settings. Users often set only one:

| Setting | File | Effect |
|---|---|---|
| `analyzer: exclude:` | `analysis_options.yaml` | Suppresses diagnostics for matching files. Files are still resolved when imported. |
| `dart.analysisExcludedFolders` | `.vscode/settings.json` | Stops the analysis server from analyzing the listed folders. |

---

## Detection / Behavior

This is an extension-native check (see "Rule Sources" in the issue report guide). It reads non-Dart files, so the Dart AST engine cannot do it. Output goes to the Problems panel and the Saropa sidebar only. The web report filters out non-`.dart` diagnostics today.

### Inputs

- `.vscode/settings.json`: `dart.analysisExcludedFolders`.
- `analysis_options.yaml`: `analyzer: exclude:` and the `plugins:` block.
- Workspace folder listing and Dart file counts per top-level folder.
- Presence of worktree or sibling-repo folders inside the workspace.

### Should suggest (candidate folders)

A top-level folder is a candidate when it exists and either holds no first-party Dart code or holds generated or third-party code:

- `android`, `ios`, `macos`, `windows`, `linux`, `web` (platform folders)
- `build`, `.dart_tool`, `coverage`
- `dependency_overrides`, `third_party`, `vendor`
- `docs`, `doc`, `bugs`, `plans`, `reports`, `scripts` (when no imported Dart code is under them)
- `assets`
- agent worktree folders such as `.claude/worktrees`

### Reported findings

1. Candidate folder exists and is missing from `dart.analysisExcludedFolders`.
2. Folder is in `analyzer: exclude:` but not in `dart.analysisExcludedFolders` (diagnostics hidden but still analyzed).
3. Total analyzed Dart file count is above a threshold (suggest 3,000) and system RAM is at or below 8 GB. Message names both numbers.
4. A candidate folder is imported by first-party code (for example a path dependency). Do not suggest excluding it. Say why.

### Quick action

"Add to `dart.analysisExcludedFolders`" edits `.vscode/settings.json` for the selected folders. It never edits `analysis_options.yaml`.

### Should pass (no finding)

- All candidate folders already listed.
- Folder contains first-party code that `lib/` imports.

---

## Proposed Tier

Not applicable. This is a workspace check, not a lint rule. It should be on by default with a setting to turn it off.

---

## Edge Cases

1. **Monorepo with several packages** — check each workspace folder separately.
2. **No `.vscode/settings.json`** — suggest creating it.
3. **Excluded folder holds Dart tests** — `test/` is never a candidate.
4. **Exclusion hides a folder the user is editing** — the quick action only adds folders the user selects.
5. **Memory figure unavailable** — skip finding 3 and report the file count only.

---

## Alternatives Considered

- Dart AST rule: cannot read settings files or folder structure.
- Documentation only: users do not read it, and exclusions drift.

---

## Decision

Implemented as proposed, per owner: on by default, setting `saropaLints.analyzerExclusions.enabled` turns it off.

Readings chosen where the proposal was ambiguous (simplest reading):

- Diagnostics attach to the workspace folder's `pubspec.yaml` (line 1, Information severity). A workspace folder without `pubspec.yaml` is skipped. Each workspace folder is checked separately.
- "Imported by first-party code" means a local `path:` dependency in `dependencies` or `dev_dependencies` that points into the folder. `dependency_overrides` path entries do not count (they are resolution pins). Dart `import '../x'` statements are not scanned.
- Finding 2 applies to any top-level folder (or `.claude/worktrees`) listed as a plain folder in `analyzer: exclude:`, not only candidates. File globs and nested paths in `analyzer: exclude:` are ignored. When a folder is in both gaps, only finding 2 is reported (no duplicate finding 1).
- `lib`, `test`, `integration_test`, `bin` are never reported.
- Finding 3 counts `.dart` files in folders not covered by `dart.analysisExcludedFolders`. RAM unavailable: report the file count only (edge case 5). RAM is rounded to whole GB; "at or below 8" compares the rounded value.
- Docs-style candidates (`docs`, `scripts`, ...) are protected only through the path-dependency rule (finding 4), not by scanning Dart imports.
- The quick action shows a multi-select list of all addable folders (clicked one preselected), then writes `dart.analysisExcludedFolders` at WorkspaceFolder scope, which creates `<folder>/.vscode/settings.json` if missing and is JSONC-safe. `analysis_options.yaml` is never edited.
- Locale files: only English (`package.nls.json`, `en.json`) was added; other locales fall back to English until the owner's translation pipeline runs. `locale_coverage.json` is generated and was not touched.

Review risks:

- Counting walks every non-excluded top-level folder on each save of `pubspec.yaml`, `analysis_options.yaml` or a `settings.json`, and on setting changes. Large trees (and `.claude/worktrees` copies) cost a few seconds of async IO; no cache.
- `dart.analysisExcludedFolders` is read through the VS Code configuration API, so user-level entries also count as excluded.
- `.claude` is not walked as a whole; only `.claude/worktrees` is.
- Test status: the 13 new unit tests pass. The full `npm test` has 50 failures: `locale parity` (25 locales x 2) and 2 DOM tests. Parity already listed 4 missing keys from earlier work (`command.migrateRuleNames.title`, `command.configureCompatibility.title`, `config.property.watcherExclude.maxFileKb.description` and one more) before this change; this change adds 2 more (`config.section.Analyzer.Exclusions.title`, `config.property.analyzerExclusions.enabled.description`) that clear when the owner's translation pipeline runs.
- Not tested: the vscode-dependent wiring (diagnostics publishing, quick action). Only the pure logic is unit tested.

---

## Implementation Notes

- New standalone module under `extension/src/`, following the existing pattern (own `DiagnosticCollection`, like `pubspec-validation.ts`).
- No shared check registry exists today.
- Surfacing it in the web report needs the `.dart`-only filter in `liveDiagnosticsModel.ts` loosened. Out of scope here.

---

## Commits

- c93fa6f2 feat(extension): analyzer exclusions check with Add to dart.analysisExcludedFolders quick action
- f2dd5a65 fix(extension): analyzer exclusions review fixes

## Review findings and fixes

1. Changelog entry sat under the released `17.0.1-beta.7`; moved to a new `17.0.1-beta.8` section.
2. Removed workspace folders kept stale `_state` and diagnostics. Fixed: `onDidChangeWorkspaceFolders` clears both for `e.removed`.
3. Overlapping `checkAll` runs could let an older result overwrite a newer one. Fixed: a `RunToken`; each run takes an id, and results from a run that is no longer the latest are dropped (test: `RunToken`).
4. The analyzed file count only subtracted top-level excluded folders. Fixed: nested entries such as `lib/generated` are counted (`nestedExcludedCounts`) and subtracted, without double-subtracting entries nested inside another excluded entry (tests: nested excluded folders).
