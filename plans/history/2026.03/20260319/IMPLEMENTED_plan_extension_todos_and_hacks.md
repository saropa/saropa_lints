# Implemented: Extension TODOs & Hacks view (2025-03-19)

**Plan:** `bugs/plan/plan_extension_todos_and_hacks.md` — fully implemented and moved here.

## Summary

- **View:** "TODOs & Hacks" in Saropa Lints sidebar; folder → file → line (or tag → file → line when "Group by tag" is on). Click line to open at location. No Dart analyzer or violations.json.
- **Settings:** tags, includeGlobs, excludeGlobs, maxFilesToScan, autoRefresh, groupByTag, customRegex (optional override). Merged with search.exclude.
- **Scanner:** `extension/src/services/todosAndHacksScanner.ts` + pure core `todosAndHacksScannerCore.ts` (regex, exclude pattern). findFiles + batched read (concurrency 30); capped flag when maxFilesToScan hit.
- **Tree:** `extension/src/views/todosAndHacksTree.ts` — cache per folder; ensureAllScanned guarded to avoid duplicate concurrent scans; placeholder nodes for "No workspace folder", "No markers", "Limited to N files".
- **Commands:** Refresh (toolbar + command), Toggle group by tag / folder. "Scanning…" message shown for 4s on refresh/toggle.
- **Auto-refresh:** onDidSaveTextDocument, debounced 600 ms, when autoRefresh is true and doc under a workspace folder.
- **Tests:** `extension/src/test/todosAndHacks/scanner.test.ts` — buildRegex, extractMarkersFromLines, getExcludePattern (12 tests). Run: `npm run test` in extension. Uses core only (no vscode).
- **Code quality:** Core uses `regex.exec()` with `lastIndex` reset when global (Sonar S6594). Tree: concurrency guard in ensureAllScanned; Sonar/TS fixes (node:path, replaceAll, readonly, cognitive complexity refactor, localeCompare, unified capped message).

**Files:** package.json (config, commands, view, menu), extension.ts (tree view, save listener, refresh/toggle handlers), todosAndHacksTypes.ts, todosAndHacksScanner.ts, todosAndHacksScannerCore.ts, todosAndHacksTree.ts, scanner.test.ts, tsconfig.todosAndHacks.test.json. README, CHANGELOG, plan acceptance criteria and completed-optional section updated.
