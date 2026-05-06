# BUG: Extension — Stale File Paths After File/Directory Rename

**Status:** RESOLVED 2026-03-25
**Created:** 2026-03-25
**Component:** VS Code Extension (`extension/src/views/issuesTree.ts`, `extension/src/extension.ts`)
**Severity:** Medium — broken navigation, confusing UX, "file not found" errors
**Extension version:** Current (post-v10.1.2)

**Resolution:** Implemented Fix 1 (visual indicator) from Suggested Fixes. File existence is now
checked via a cached helper in `pathUtils.ts` at all three tree item types (`file`, `violation`,
`overflow`). Missing files show a warning icon + "(file moved or deleted)"; click-to-open is
disabled; "Fix all in this file" shows a user-friendly warning. Cache is cleared on tree refresh.
Tests added for the cache helper.

---

## Summary

When source files or directories are moved or renamed in a project analyzed by Saropa Lints, the extension's violations sidebar continues to display violations at the **old file paths**. Clicking on these violations opens a VS Code "file not found" error instead of navigating to the actual file. The extension has no mechanism to detect file system renames, moves, or deletes — it only refreshes when `violations.json` is regenerated.

---

## Reproduction Steps

1. Run Saropa Lints analysis on a project (e.g. `contacts`) — violations populate in the sidebar
2. Rename a directory (e.g. `lib/database/isar_middleware/` to `lib/database/drift_middleware/`)
3. Observe the sidebar still shows violations under the old path `isar_middleware/`
4. Click on a violation (e.g. `require_data_encryption` in `provider_auth_io.dart`)
5. VS Code shows: **"The editor could not be opened because the file was not found."**

### Observed Behavior

- Sidebar shows: `lib/database/isar_middleware/system_data/provider_auth_io.dart`
- File actually lives at: `lib/database/drift_middleware/system_data/provider_auth_io.dart`
- The file search correctly finds it at the new path, but the extension still references the old one

### Expected Behavior

Either:
- (a) Violations pointing to non-existent files are visually marked as stale / grayed out, or
- (b) The extension detects file renames and updates paths, or
- (c) Clicking a stale path triggers a re-analysis prompt

---

## Root Cause Analysis

### 1. Violations are stored as raw file paths with no existence validation

`violationsReader.ts` (line 13–23) defines the `Violation` interface with a plain `file: string` field. This path is read from `violations.json` and used verbatim — it is never checked against the file system.

### 2. Tree items use `path.join(wsRoot, v.file)` without existence check

`issuesTree.ts` constructs clickable tree items at three points:

```typescript
// Line 509 — file-level item
item.resourceUri = vscode.Uri.file(path.join(wsRoot, element.filePath));

// Line 529 — violation-level item (opens file at line)
item.resourceUri = vscode.Uri.file(path.join(wsRoot, v.file));
item.command = {
  command: 'vscode.open',
  title: 'Open',
  arguments: [
    item.resourceUri,
    { selection: new vscode.Range(v.line - 1, 0, v.line - 1, 0) },
  ],
};

// Line 571 — overflow item
item.resourceUri = vscode.Uri.file(path.join(wsRoot, element.filePath));
```

None of these check whether the file exists before creating the URI. VS Code's `vscode.open` command fails with a generic "file not found" dialog when the path is invalid.

### 3. File system watcher only watches `violations.json`

`extension.ts` (lines 441–449) sets up a single watcher:

```typescript
const watchViolations = () => {
  const p = violationsPath();   // reports/.saropa_lints/violations.json
  if (!p) return;
  const watcher = vscode.workspace.createFileSystemWatcher(p);
  watcher.onDidChange(debouncedRefresh);
  watcher.onDidCreate(debouncedRefresh);
  context.subscriptions.push(watcher);
};
```

There is **no watcher** for `.dart` file renames, moves, or deletes. The only other watcher in the extension is for `pubspec.lock` in the vibrancy subsystem (`extension-activation.ts:242`).

### 4. Cache is never invalidated by file system changes

`IssuesTreeProvider.cachedIndex` is an in-memory map of `severity -> filePath -> Violation[]`. It is cleared on filter/grouping changes and manual refresh, but **not** in response to any file system event. Stale entries persist until the next `violations.json` regeneration.

---

## Impact

| Scenario | Effect |
|----------|--------|
| Directory rename (e.g. migration from isar to drift) | All violations in the directory become unreachable |
| Single file rename/move | Violations for that file become unreachable |
| File deleted | Violations shown for non-existent file |
| User clicks stale violation | "File not found" error dialog — no actionable guidance |

In large refactors (like a database migration), dozens or hundreds of violations can become stale simultaneously, rendering the sidebar unusable until the next analysis run.

---

## Suggested Fixes

### Fix 1: Validate file existence in `getTreeItem()` (Quick Win)

Before creating the `resourceUri`, check if the file exists. If not, show a visual indicator:

```typescript
const absPath = path.join(wsRoot, v.file);
if (!fs.existsSync(absPath)) {
  item.iconPath = new vscode.ThemeIcon('warning', new vscode.ThemeColor('problemsWarningIcon.foreground'));
  item.description = '(file moved or deleted)';
  item.tooltip = `File not found: ${v.file}\nRe-run analysis to update.`;
  item.command = undefined; // Don't attempt to open
  return item;
}
```

**Pros:** Simple, no architecture changes, immediate UX improvement.
**Cons:** `fs.existsSync` on every tree render could be slow for large violation sets; needs caching or debouncing.

### Fix 2: Watch `.dart` files for renames/deletes and mark violations stale

Add a workspace-wide watcher for Dart file changes:

```typescript
const dartWatcher = vscode.workspace.createFileSystemWatcher('**/*.dart');
dartWatcher.onDidDelete((uri) => {
  issuesProvider.markFileStale(uri.fsPath);
});
dartWatcher.onDidCreate((uri) => {
  // Potential rename target — could attempt path matching
});
```

**Pros:** Reactive, no polling, handles renames and deletes as they happen.
**Cons:** More complex; rename detection (delete + create) requires correlation logic; watcher overhead on large projects.

### Fix 3: Re-validate file paths on `violations.json` load

When `readViolations()` parses the JSON, filter out or flag violations whose file paths don't resolve:

```typescript
const data = readViolations(root);
if (data) {
  data.violations = data.violations.filter(v => {
    const exists = fs.existsSync(path.join(root, v.file));
    if (!exists) log.warn(`Stale violation path: ${v.file}`);
    return exists;
  });
}
```

**Pros:** Single validation point, clean data downstream.
**Cons:** Silently hides violations that might still be relevant (file temporarily missing); doesn't help between analysis runs.

### Fix 4: Prompt user to re-run analysis when stale paths detected

When the user clicks a violation for a non-existent file, show an actionable notification:

```typescript
const action = await vscode.window.showWarningMessage(
  `File not found: ${v.file}. It may have been moved or deleted.`,
  'Re-run Analysis',
  'Dismiss',
);
if (action === 'Re-run Analysis') {
  vscode.commands.executeCommand('saropa-lints.runAnalysis');
}
```

**Pros:** Guides the user to the solution; minimal code.
**Cons:** Reactive (only fires on click), doesn't prevent confusion from seeing stale items in the tree.

### Recommended Approach

Combine **Fix 1** (visual indicator) + **Fix 4** (prompt on click) for immediate UX improvement with minimal complexity. Consider **Fix 2** (file watcher) as a follow-up for proactive staleness detection.

---

## Environment

- Saropa Lints extension: current (post-v10.1.2)
- VS Code: latest stable
- Triggering project: `contacts` (migrating from isar to drift — `isar_middleware/` renamed to `drift_middleware/`)
- OS: Windows 11 Pro
