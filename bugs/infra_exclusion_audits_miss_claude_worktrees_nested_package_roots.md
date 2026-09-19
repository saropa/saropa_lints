# BUG: Exclusion audits never flag `.claude/worktrees/`, so nested package copies each become a separate analysis context

**Status: Investigating**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-09-18
Rule: n/a (extension-native checks: Watcher Exclude Audit, Analysis Optimizer)
File: `extension/src/systemHealth/watcherExcludeAudit.ts` (line ~33); `extension/src/analysisOptimizer/scorer.ts` (lines ~10, ~154-178); `extension/src/analysisOptimizer/scanner.ts` (line ~94)
Severity: False negative (High): the analysis server grew to 6.7 GB on an 8 GB machine with no exclusion suggested
Rule version: n/a | Since: extension 16.x | Updated: 16.4.1

---

## Summary

Claude Code (and similar agent tools) create git worktrees under `<workspace>/.claude/worktrees/<name>/`. Each one is a **full copy of the repo with its own `pubspec.yaml` and `analysis_options.yaml`**, so the Dart analysis server analyzes each copy as a separate context. Neither saropa-lints exclusion feature detects this.

- The Watcher Exclude Audit's `RECOMMENDED_EXCLUDES` has no `.claude` entry.
- The Analysis Optimizer has no concept of nested package roots or tool folders, and runs only when opened.

Expected: the extension shows `.claude/` (and nested package roots generally) as an exclusion, with a one-click fix covering `analysis_options.yaml` `exclude`, `dart.analysisExcludedFolders` and `files.watcherExclude`.

---

## Attribution Evidence

Extension-native, so the grep root is `extension/src/`.

```bash
grep -rn "RECOMMENDED_EXCLUDES" extension/src/systemHealth/watcherExcludeAudit.ts
# extension/src/systemHealth/watcherExcludeAudit.ts:33  const RECOMMENDED_EXCLUDES: readonly string[] = [
#   '**/*.hprof', '**/*.log', '**/build/**', '**/.dart_tool/**', '**/reports/**', '**/.vs/**',
#   '**/dependency_overrides/**/build/**', '**/dependency_overrides/**/.dart_tool/**',

grep -n "DEFAULT_EXCLUSION_PATTERNS" extension/src/analysisOptimizer/scorer.ts
# extension/src/analysisOptimizer/scorer.ts:10  (generated suffixes, build/**, .dart_tool/** only)

grep -rn "'\.claude\|\.claude/worktrees\|pubspec.yaml\|analysisExcludedFolders" extension/src/analysisOptimizer/ extension/src/systemHealth/watcherExclude*.ts
# 0 matches: no check knows about .claude, nested pubspecs, or dart.analysisExcludedFolders

grep -rn "\.claude" extension/src/ --include='*.ts' | grep -v "rules/\|skills/\|project notes"
# 0 functional matches (only comments citing .claude/rules/*.md)
```

**Emitter registration:** `auditWatcherExcludes` imported at `extension/src/extension.ts:170`; optimizer via the `saropaLints.openAnalysisOptimizer` command (`extension.ts:2609`), also offered from `processMonitor.ts:418`, which never fires on macOS (see Related).
**Diagnostic surface:** notification or webview, not a Problems-panel diagnostic

---

## Reproducer

1. Open a Flutter workspace whose `files.watcherExclude` already contains every `RECOMMENDED_EXCLUDES` entry. `saropa_contacts` does, so the audit stays silent.
2. `git worktree add .claude/worktrees/a HEAD`, repeated for `b` … `g`. `.claude/worktrees/` is gitignored (`saropa_contacts/.gitignore:282`).
3. Let analysis settle, then run **Saropa Lints: Open Analysis Optimizer**.

**Observed on 2026-09-18:** seven worktrees of 719 MB–1.2 GB each; `dart language-server` at **6726 MB** (`top` MEM) on an 8 GB Mac. The Watcher Exclude Audit showed no prompt, and nothing proactive flagged the folder. Excludes in place at the time: `analysis_options.yaml` (30+ patterns, none `.claude`), `dart.analysisExcludedFolders` (`dependency_overrides, .dev, scripts, docs, bugs, plans, reports`).

**Frequency:** Always, whenever an agent tool creates worktrees inside the workspace.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | A proactive prompt such as "`.claude/worktrees/` contains 7 nested Dart packages, each analyzed as a separate context", offering to exclude `.claude/` from analysis and file watching. The Optimizer lists it as a high-priority row. |
| **Actual** | The audit is silent (all its fixed patterns are present). The Optimizer only runs on demand. If opened, it would at most list `.claude/worktrees/**` as "100% of files have no recent edits" at medium priority, ranked by line count. |

---

## AST Context

`SKIPPED`: extension-native TypeScript, no Dart AST involved.

---

## Root Cause

### Hypothesis A (confirmed by reading the code): fixed pattern lists with no tool or agent folders

`watcherExcludeAudit.ts:33` `RECOMMENDED_EXCLUDES` and `scorer.ts:10` `DEFAULT_EXCLUSION_PATTERNS` are static lists aimed at build output and generated code. Neither includes `.claude/**`, `.claude/worktrees/**` or other agent/IDE folders (`.cursor/`, `.fvm/`, `.idea/`).

### Hypothesis B (confirmed): the Optimizer scores files, not analysis contexts

`buildExclusionRows` (`scorer.ts:154-178`) suggests a folder only when `recentEditRatio < 0.1` or it is mostly generated. Its cost is a line-count sum (`computeFileCost`). A nested `pubspec.yaml` / `analysis_options.yaml` (a whole extra analysis context, the dominant memory cost) is never detected. Worktree files are untracked, so `queryGitRecency` (`scanner.ts`) has no entry for them and the ratio is 0. That makes the row read "no recent edits" (priority `medium`, `scorer.ts:178`), which misdescribes the problem.

### Hypothesis C (confirmed): the Optimizer's own scan walks the copies

`scanWorkspace` (`scanner.ts:94-97`) calls `findFiles('**/*.dart', '**/build/**', 50_000)`. A string `exclude` replaces the default excludes, so `files.exclude` is not applied, and `.gitignore` is never consulted. Seven repo copies can hit the 50,000 cap and silently truncate the scan.

### Hypothesis D (confirmed, now moot): the root `exclude` does prune nested context roots

`ContextLocatorImpl._createContextRootsIn` → `isExcluded()` checks `excludedGlobs` before descending, so an `analyzer: exclude:` glob stops nested-root discovery. For `.claude/` it is redundant anyway (see E).

### Hypothesis E (confirmed from analyzer source, contradicts the premise): the analysis server never analyzes dot-folders

Checked in analyzer 9.0.0 and 10.1.0 (`~/.pub-cache`):

- `context_locator.dart` `_createContextRootsIn.isExcluded()` returns true for `folder.shortName.startsWith('.')`, so no nested context root is ever created under `.claude/`.
- `context_root.dart` `_isExcluded()` walks up from each file and excludes any path with a `.`-prefixed segment inside the root, so worktree files are not analyzed by the parent root either.
- Nested roots come from `.dart_tool/package_config.json`, `BUILD.gn` or a differing legacy-plugin set, not from `pubspec.yaml`.

So the 6.7 GB `dart language-server` figure is **not explained** by the worktrees being analyzed. Candidates still to rule out:

1. Worktree files open in editors (including Claude Code diff views): open files are analyzed even outside roots.
2. Worktrees added as VS Code workspace folders (a root is not subject to the dot-folder check).
3. Plugin isolate memory counted in the same process.
4. Baseline memory for a project this size.

**Next step:** A/B `top` MEM with and without the worktrees, no worktree files open, after *Dart: Restart Analysis Server* each time. Also confirm whether downstream commit `2213808bb7` changed memory or whether the restart did.

What *is* real: VS Code's own file watcher tracks ~7 GB of copies (Code Helper memory, not `dart`), and the Optimizer scan counts files the analyzer ignores (Hypothesis C).

---

## Suggested Fix

1. **Nested-package-root detection**, a new standalone module following the `workspaceHazardScan.ts` pattern (one-shot, deferred after activation). Run `findFiles('**/pubspec.yaml')`. Any hit below the root that is gitignored (`git check-ignore -q`) or under a dot-folder is a candidate. Warn once per workspace, with a one-click fix that adds the folder to `dart.analysisExcludedFolders`, `analysis_options.yaml` `exclude` and `files.watcherExclude`, plus a "Dismiss" option stored in `workspaceState` as `watcherExcludeAudit` does.
2. `RECOMMENDED_EXCLUDES`: add `'**/.claude/worktrees/**'`.
3. `DEFAULT_EXCLUSION_PATTERNS`: add `{ pattern: '.claude/**', reason: 'Agent tool folder (worktrees are full repo copies)' }`.
4. Optimizer: add a nested-root pass whose rows are priority `high`, with the reason "N nested Dart package(s), each analyzed as a separate context". Rank these by context count, not lines.
5. `scanWorkspace`: honor `files.exclude` and `.gitignore` (pass `undefined` as the exclude, or merge the defaults), and report when the 50,000 cap truncates the scan.

---

## Fixture Gap

`extension/src/test/analysisOptimizer/` and `extension/src/test/systemHealth/` should include:

1. A workspace with `.claude/worktrees/a/pubspec.yaml` plus `lib/*.dart` → nested-root warning and a high-priority Optimizer row. **Fails today.**
2. The same folder already in `dart.analysisExcludedFolders` → no warning.
3. A non-ignored `packages/foo/pubspec.yaml` (a legitimate monorepo member) → no warning, or an informational row only. Must not nag real workspaces.
4. `computeMissingExcludes` with every current pattern present plus a `.claude/worktrees` folder on disk → reports `'**/.claude/worktrees/**'` missing. **Fails today.**
5. `scanWorkspace` with a gitignored folder → its files are not counted toward the 50,000 cap.

---

## Changes Made

Scoped to the confirmed parts (A, C). Nested-package-root detection (Suggested Fix 1, 4) is **on hold** pending the A/B reproduction: per Hypothesis E it would warn about folders the analyzer already ignores, and a `pubspec.yaml` trigger would also flag `ios/.symlinks/plugins/*`, `*/flutter/ephemeral/.plugin_symlinks/*` and `.fvm/flutter_sdk` in ordinary Flutter apps.

- Watcher Exclude Audit: recommends `**/.claude/worktrees/**` only when that folder exists on disk; a broader `.claude` entry counts as covered. Dismissal now records the dismissed patterns, so a newly added recommendation can prompt once (legacy dismissals cover the original list).
- Analysis Optimizer: the scan skips dot-folders (matching the analyzer), so they no longer consume the file cap or produce exclusion rows, and a capped scan is reported instead of silently truncated.
- `.gitignore` is not consulted (`findFiles` cannot); skipping dot-folders covers the reported case.

---

## Tests Added

<!-- List new or updated fixture/test files and what they verify. -->

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Environment

- saropa_lints version: VS Code extension `saropa.saropa-lints` 16.4.1 (pub package 8.2.2)
- Dart SDK version: 3.13.3 (Flutter 3.47.4 stable)
- custom_lint version: n/a (extension-native)
- Triggering project/file: `saropa_contacts` workspace, macOS 26.6.2 (Apple silicon, 8 GB RAM)
- Downstream workaround: `saropa_contacts` commit `2213808bb7` (branch `verify/test-slices`) adds `.claude/**` to `analysis_options.yaml`, `.claude` to `dart.analysisExcludedFolders` and `**/.claude/worktrees/**` to `files.watcherExclude`
- Related: `bugs/infra_system_health_monitor_windows_only_no_macos_analysis_server_warning.md`
