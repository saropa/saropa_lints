# Issues Tree Implementation — Completed 2026-03-14

## Summary

The VS Code extension Issues view was reimplemented according to the plan *Issues tree by severity and structure* (Cursor plan). The view now uses a **tree grouped by severity then project structure**, with **filters**, **suppressions**, and **scale-safe behavior** for large violation counts (e.g. 65k+).

## Delivered

- **Tree structure:** Root → Error / Warning / Info (with counts) → folder path tree → file → violations (capped per file; overflow node “and N more…”).
- **Filters:** Text (file path, rule, message), type (severity + impact), rule (multi-select). View message “Showing X of Y” when active.
- **Suppressions (persisted):** Hide folder, file, rule, rule-in-file, severity, impact via context menu; stored in workspace state; “Clear suppressions” in toolbar.
- **Settings:** `saropaLints.issuesPageSize` (1–1000, default 100) for max violations per file.
- **Context menus:** Hide folder/file/rule/rule-in-file/severity/impact, Copy path, Copy message.
- **Fixes:** Root-level folder path prefix corrected; severity/impact suppressions applied in filtered index.

## Files Changed

- `extension/src/suppressionsStore.ts` (new)
- `extension/src/violationsReader.ts` (optional `correction` on Violation)
- `extension/src/views/issuesTree.ts` (rewritten)
- `extension/src/extension.ts` (provider context, filter commands, view message)
- `extension/package.json` (commands, menus, config)
- `CHANGELOG.md`, `extension/README.md`

## Related

- Design: `bugs/discussion/VSCODE_EXTENSION_DESIGN.md`
- Violation schema: `VIOLATION_EXPORT_API.md`
