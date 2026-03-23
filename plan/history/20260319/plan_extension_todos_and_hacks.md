# Plan: Extension-only "TODOs & Hacks" view

**Goal:** Add a Todo-Tree-style sidebar view that lists TODO/FIXME/HACK (and similar) comment markers by searching workspace files. No Dart analyzer or `violations.json`; extension-only.

**Scope:** VS Code extension only. No changes to the Dart package or plugin.

**Status:** Fully implemented. See plan_extension_todos_and_hacks_history.md in this folder.

---

## Overview

| Phase | Description |
|-------|-------------|
| **1** | Settings, types, and search service |
| **2** | Tree data provider and view registration |
| **3** | Commands, refresh, and polish |

---

## Phase 1 — Settings, types, and search service

### 1.1 Contribute settings (`extension/package.json`)

Add under `contributes.configuration.properties`:

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `saropaLints.todosAndHacks.tags` | `string[]` | `["TODO", "FIXME", "HACK", "XXX", "BUG"]` | Tags to search for (case-sensitive in regex by default, or document case-insensitive). |
| `saropaLints.todosAndHacks.includeGlobs` | `string[]` | `["**/*.dart", "**/*.yaml", "**/*.md", "**/*.ts", "**/*.js"]` | Glob patterns for files to scan. |
| `saropaLints.todosAndHacks.excludeGlobs` | `string[]` | `["**/node_modules/**", "**/.dart_tool/**", "**/build/**", "**/.git/**"]` | Extra exclude patterns. |
| `saropaLints.todosAndHacks.maxFilesToScan` | `number` | `2000` | Cap number of files scanned; show message in tree when capped. |
| `saropaLints.todosAndHacks.autoRefresh` | `boolean` | `true` | If true, refresh on save (debounced). |

Merge with existing `search.exclude` / `files.exclude` when calling `findFiles` (use VS Code's default search exclude behavior where applicable).

### 1.2 Types (`extension/src/views/todosAndHacksTypes.ts` or inline in provider)

- **`TodoMarker`**: `{ uri: vscode.Uri; lineIndex: number; tag: string; snippet: string; fullLine: string }`
- **`TodoTreeFolderItem`** (by-folder): represents workspace folder or virtual "file" node.
- **`TodoTreeFileItem`**: file with path and list of markers.
- **`TodoTreeLineItem`**: single marker (clickable leaf).

Optional: **by-tag** tree uses `TodoTreeTagItem` → file → line.

### 1.3 Comment syntax and regex strategy

Include globs cover multiple languages: Dart/TS/JS use `//`, YAML uses `#`, and Markdown has no single convention (e.g. `#` in some docs, `<!-- ... -->` in HTML comments, or plain text). A strict `//`-only regex would miss YAML and most Markdown TODOs.

**Recommended: single catch-all regex** (one pattern for all file types, per line):

- **Comment-prefix alternation:** Match lines that start (after optional leading whitespace) with one of:
  - `//` — Dart, JavaScript, TypeScript, C-style
  - `#` — YAML, Shell, Python, many configs; also `#` headers in Markdown (content after `#` can be "TODO: ...")
  - `<!--` — HTML / Markdown HTML comments
- **Pattern (line-based):**  
  `^\s*(?:\/\/|#|<!--)\s*(TODO|FIXME|HACK|XXX|BUG)(\s*:)?\s*(.*)$`  
  Build the tag list from settings (escape for regex), e.g. `(TODO|FIXME|HACK|XXX|BUG)`.
- **Captures:** tag (e.g. `TODO`), optional `:`, and rest-of-line (snippet). For `<!--`, snippet can include text up to `-->`; optionally trim trailing `-->` when displaying.
- **Trade-off:** One regex keeps the scanner simple and avoids per-extension branching. Downside: in Markdown, `# TODO: ...` matches (good); plain prose like "See the FIXME in the doc" does not match (no `//`/`#`/`<!--` prefix), so we avoid most false positives. Matching bare "TODO:" at start of line (e.g. in lists) would require a second pattern and increases false positives in prose; document as future option or leave to user custom regex.

**Optional later:** Setting for a custom regex override (e.g. `saropaLints.todosAndHacks.customRegex`) so users can add syntaxes or bare-Markdown patterns without changing code.

### 1.4 Search service (`extension/src/views/todosAndHacksScanner.ts` or `extension/src/services/todosAndHacksScanner.ts`)

- **`scanWorkspace(workspaceFolder: vscode.WorkspaceFolder, options: ScanOptions): Promise<TodoMarker[]>`**
  - Use `vscode.workspace.findFiles(include, exclude, maxResults)` with `include`/`exclude` from settings + `maxResults` = `maxFilesToScan`.
  - For each file: `vscode.workspace.fs.readFile(uri)` or `vscode.workspace.openTextDocument(uri)`, then run the **catch-all regex** (Section 1.3) over each line. No per-extension branching unless custom regex is added later.
  - Return array of `TodoMarker` (uri, lineIndex 0-based, tag, snippet, fullLine).
- **Excludes:** Combine `excludeGlobs` with `search.exclude` (read from `vscode.workspace.getConfiguration('search').get('exclude')`).
- **Performance:** Single batch of `findFiles`; then read files in parallel with a concurrency limit (e.g. 20–50 at a time) to avoid memory spike.
- **Capping:** When `findFiles` returns `maxResults` files, set a flag so the tree can show "Limited to N files" in the root or in the view message.

**Files to add:**

- `extension/src/views/todosAndHacksTypes.ts` (or types in provider file)
- `extension/src/services/todosAndHacksScanner.ts`

**Files to edit:**

- `extension/package.json` (configuration block)

---

## Phase 2 — Tree data provider and view registration

### 2.1 Tree data provider (`extension/src/views/todosAndHacksTree.ts`)

- **Class `TodosAndHacksTreeProvider implements vscode.TreeDataProvider<TodoTreeNode>`**
  - Node union: root placeholder, workspace folder, file, line item (and optionally tag group for "by tag" mode).
  - **`getChildren(element?: TodoTreeNode): TodoTreeNode[] | Thenable<TodoTreeNode[]>`**
    - No element: return one root per workspace folder (or single "Scanning…" / "Refresh" placeholder when no folders).
    - Folder element: run scanner for that folder, then group results by file path, return file nodes.
    - File element: return line items (markers for that file).
  - **`getTreeItem(element: TodoTreeNode): vscode.TreeItem`**
    - Line item: `TreeItem` with label = snippet (or tag + snippet), description = path, tooltip = full line; `command` to open file at line.
    - File: collapsible, label = file name, description = path or count.
    - Folder: collapsible, label = folder name.
  - **`refresh()`**: clear cache if any, fire `onDidChangeTreeData`, so next `getChildren` re-runs scanner.
  - **Optional:** `groupByTag: boolean` (setting or view state). When true, top-level = tag → file → line.

- **Open at line:** Use `vscode.window.showTextDocument(uri, { selection: new vscode.Range(lineIndex, 0, lineIndex, 0), preview: false })` for line items.

### 2.2 View registration

- **package.json**
  - Under `views.saropaLints` add:
    - `"id": "saropaLints.todosAndHacks", "name": "TODOs & Hacks"` (optional `when` if desired; e.g. always show).
- **extension.ts**
  - Import and instantiate `TodosAndHacksTreeProvider`.
  - `vscode.window.registerTreeDataProvider('saropaLints.todosAndHacks', todosAndHacksProvider)`  
    **or** `vscode.window.createTreeView('saropaLints.todosAndHacks', { treeDataProvider: todosAndHacksProvider, showCollapseAll: true })` so toolbar is available for refresh.
  - If using `createTreeView`, keep a reference to the TreeView to call `refresh()` from a command.

### 2.3 Refresh command

- **package.json:** Add command `saropaLints.todosAndHacks.refresh` (title: "TODOs & Hacks: Refresh").
- **extension.ts:** Register the command; handler calls `todosAndHacksProvider.refresh()` (and optionally focuses the view).

**Files to add:**

- `extension/src/views/todosAndHacksTree.ts`

**Files to edit:**

- `extension/package.json` (view entry, command)
- `extension/src/extension.ts` (provider + command registration)

---

## Phase 3 — Commands, refresh, and polish

### 3.1 Auto-refresh (when `autoRefresh` is true)

- On `vscode.workspace.onDidSaveTextDocument` (and optionally `onDidChangeTextDocument`), debounce (e.g. 500–800 ms) and call `todosAndHacksProvider.refresh()`.
- Only run when the saved/changed document is under a workspace folder that the view shows.

### 3.2 View messaging when capped

- When scanner hit `maxFilesToScan`, either:
  - Add a root-level child node like "Limited to N files (increase maxFilesToScan in settings)", or
  - Use `TreeView.message` (if available) to show the same text.

### 3.3 Optional: "Group by tag" toggle

- Add setting `saropaLints.todosAndHacks.groupByTag` (default `false`).
- Provider branches in `getChildren` by this setting: by-folder vs by-tag.
- Optional: add a title-area command "Group by tag" / "Group by folder" that flips the setting and refreshes.

### 3.4 Tests (optional but recommended)

- Unit test for regex: given a few lines of text, expect correct `TodoMarker` list.
- Unit test for exclude/include globs: mock `findFiles` and config, assert correct args.
- Integration: open a test workspace with a few TODO/HACK comments, run refresh, assert tree items (optional).

### 3.5 Documentation

- README or in-extension help: short description of "TODOs & Hacks" view and list of settings.
- CHANGELOG: add entry for new view and settings when shipping.

**Files to edit:**

- `extension/src/extension.ts` (auto-refresh listener)
- `extension/src/views/todosAndHacksTree.ts` (capped message, group-by-tag if implemented)
- `extension/package.json` (optional groupByTag setting, optional toggle command)
- `extension/README.md` and `CHANGELOG.md` (when feature is complete)

---

## File summary

| Action | Path |
|--------|------|
| Add | `extension/src/services/todosAndHacksScanner.ts` |
| Add | `extension/src/views/todosAndHacksTree.ts` (types can live here or in separate file) |
| Add | `extension/src/views/todosAndHacksTypes.ts` (optional) |
| Edit | `extension/package.json` (views, configuration, commands) |
| Edit | `extension/src/extension.ts` (provider, createTreeView, refresh command, auto-refresh) |
| Edit | `extension/README.md`, `CHANGELOG.md` (documentation) |

---

## Acceptance criteria

- [x] New view "TODOs & Hacks" appears under Saropa Lints sidebar.
- [x] Clicking "Refresh" (or opening the view) scans workspace with configured include/exclude and maxFilesToScan.
- [x] Tree shows by-folder → file → line; each line item shows tag and snippet; click opens file at line.
- [x] Settings for tags, include/exclude globs, maxFilesToScan, and autoRefresh are respected.
- [x] When more than maxFilesToScan files would be scanned, user sees an indication (message or node).
- [x] No dependency on Dart analyzer or violations.json; works in any workspace with supported file types.

## Completed optional items

- **Custom regex** — `saropaLints.todosAndHacks.customRegex` setting; when set, overrides the default comment regex (capture group 1 = tag, optional 2 = snippet). Invalid regex falls back to default.
- **Title-area toggle** — Command "TODOs & Hacks: Toggle group by tag / folder" in the view toolbar; flips `groupByTag` and refreshes.
- **Unit tests** — `extension/src/test/todosAndHacks/scanner.test.ts` tests `buildRegex`, `extractMarkersFromLines`, and `getExcludePattern` (pure core in `todosAndHacksScannerCore.ts`). Run with `npm run test` in the extension directory.

---

## Out of scope (future)

- Inline decorations (highlight lines with TODO/HACK in the editor).
- Status bar item ("X TODOs").
- Export list to file.
- Ripgrep-based backend (optional alternative implementation).
