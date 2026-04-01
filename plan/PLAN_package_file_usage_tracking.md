# Plan: Package File-Usage Tracking in Vibrancy Report

**Created:** 2026-04-01
**Status:** Proposed

## Problem

The vibrancy report currently shows a binary "unused" flag per package, but provides no visibility into *how many files* actually import each package. A package used in exactly one file is a very different risk profile from one used in 50 files:

- **Single-file usage** — trivial to replace or remove; low blast radius
- **Widespread usage** — high replacement cost; migration requires careful sequencing

### Example (from saropa_kykto)

> `auto_size_text` is used in exactly one place: `expandable_panel.dart:116`, where `AutoSizeText` is used as a widget. There's also a commented-out reference in `day_of_the_month.dart:63`.

This kind of insight is currently only available via manual grep. The vibrancy report should surface it automatically.

## Goals

1. Track the **number of files** that import each package
2. Show **specific file paths + line numbers** where each package is imported
3. Surface file-usage counts in the vibrancy report table and detail views
4. Help users identify low-usage packages that are easy replacement candidates

## Current Architecture

### Import Scanner (`services/import-scanner.ts`)

```
scanDartImports(workspaceRoot) → Set<string>
```

- Scans `{lib,bin,test}/**/*.dart` for `import 'package:xxx/...'` and `export 'package:xxx/...'` directives
- Returns a **flat set** of package names (no file locations, no counts)
- Called from `extension-activation.ts` line ~790 during scan

### Unused Detector (`scoring/unused-detector.ts`)

```
detectUnused(declared, imported) → string[]
```

- Pure function comparing declared deps against imported set
- Returns names of packages with zero imports
- No knowledge of import locations or counts

### VibrancyResult (`types.ts`)

```ts
interface VibrancyResult {
    readonly isUnused: boolean;
    // No file-usage data exists
}
```

## Proposed Changes

### Phase 1: Extend Import Scanner

**File:** `services/import-scanner.ts`

Add a new return type and function alongside the existing one (don't break the current API):

```ts
/** A single import/export occurrence of a package. */
export interface PackageUsage {
    /** Relative path from workspace root (e.g. "lib/widgets/panel.dart"). */
    readonly filePath: string;
    /** 1-based line number of the import/export statement. */
    readonly line: number;
    /** Whether this is a commented-out reference. */
    readonly isCommented: boolean;
}

/** Per-package usage map: package name → list of usages. */
export type PackageUsageMap = ReadonlyMap<string, readonly PackageUsage[]>;

/**
 * Scan Dart source files and return per-file import locations for each package.
 * Superset of scanDartImports — also collects file paths and line numbers.
 */
export async function scanDartImportsDetailed(
    workspaceRoot: vscode.Uri,
): Promise<PackageUsageMap>;
```

Implementation approach:
- Reuse the same file glob pattern: `{lib,bin,test}/**/*.dart`
- For each file, split content by lines and match the import regex per line
- Record `{ filePath, line, isCommented }` for each match
- Optionally detect commented-out imports (`// import 'package:...'`)
- Build a `Map<string, PackageUsage[]>` and return it

The existing `scanDartImports` can be reimplemented as a thin wrapper:
```ts
export async function scanDartImports(root: vscode.Uri): Promise<Set<string>> {
    const detailed = await scanDartImportsDetailed(root);
    return new Set(detailed.keys());
}
```

### Phase 2: Add Usage Data to VibrancyResult

**File:** `types.ts`

```ts
export interface VibrancyResult {
    // ... existing fields ...
    readonly isUnused: boolean;
    /** Files that import this package. Empty array if unused. */
    readonly fileUsages: readonly PackageUsage[];
}
```

**File:** `extension-activation.ts`

After calling `scanDartImportsDetailed`:
- Pass the `PackageUsageMap` into the result-building step
- Populate `fileUsages` on each `VibrancyResult`

**File:** `scan-orchestrator.ts`

- Add `fileUsages: []` to the default result (populated later in activation)

### Phase 3: Surface in Report UI

#### 3a. Table Column

**File:** `views/report-html.ts`

Add a new column "Usages" (or "Files") to the table:

| Header | Data attribute | Value | Tooltip |
|--------|---------------|-------|---------|
| Files | `data-usages` | count | "Number of files that import this package" |

Cell display:
- `0` → shown with unused styling (already handled by Status column)
- `1` → shown in muted color (single-use, easy to replace)
- `2-5` → normal
- `6+` → bold (deeply embedded)

Make this a `HidableColumn` — only shown when at least one package has usage data.

#### 3b. Detail View

**File:** `views/package-detail-html.ts`

Add a "File Usages" section listing each file path and line:

```
File Usages (3 files)
  lib/widgets/expandable_panel.dart:116
  lib/screens/settings.dart:4
  test/widget_test.dart:2
```

Each path should be a clickable link that opens the file in the editor at that line.

#### 3c. Summary Card (optional)

Consider adding a "Single-use" summary card showing packages imported in only one file — these are the easiest replacement candidates.

### Phase 4: Export Support

**File:** `views/report-exporter.ts`

Add `fileUsages` to the JSON export and a summary table to the markdown export:

```json
{
  "name": "auto_size_text",
  "fileUsageCount": 1,
  "fileUsages": [
    { "filePath": "lib/widgets/expandable_panel.dart", "line": 116 }
  ]
}
```

Markdown export:
```
| Package | Files | Locations |
|---------|-------|-----------|
| auto_size_text | 1 | lib/widgets/expandable_panel.dart:116 |
```

## Implementation Sequence

1. **Phase 1** — Extend import scanner (low risk, no UI changes)
2. **Phase 2** — Wire usage data into VibrancyResult (backward compatible)
3. **Phase 3a** — Add table column (visible change, easy to validate)
4. **Phase 3b** — Add detail view section
5. **Phase 3c** — Summary card (optional, evaluate after 3a/3b)
6. **Phase 4** — Export support

## Performance Considerations

- The scanner already reads all Dart files; per-line matching adds negligible overhead
- The `PackageUsageMap` is small (one entry per package × a few file refs each)
- No additional filesystem I/O beyond what the current scanner already does
- Consider caching the detailed map alongside existing scan results

## Risks

- **Large monorepos**: Projects with thousands of Dart files could have slower scans. Mitigate by reusing the existing file list and processing in parallel (already done via `Promise.all`).
- **Commented-out imports**: Detecting `// import 'package:...'` adds noise. Make this opt-in or visually distinct.
- **Re-exports**: A package imported once but re-exported might appear as single-use when it's actually foundational. Consider flagging re-exports separately.

## Open Questions

1. Should we count `test/` imports separately from `lib/` imports? (Test-only usage has different implications)
2. Should the column be "Files" (count of importing files) or "Usages" (total import statements, including multiple per file)?
3. Should commented-out imports be included in the count or shown separately?
4. Should we detect *symbol-level* usage (which classes/functions from the package are used) or just import-level? Symbol-level is significantly more complex and may be better as a separate feature.
